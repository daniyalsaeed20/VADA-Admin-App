import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import admin from "firebase-admin";

admin.initializeApp();

type NotificationTarget = "broadcast" | "user" | "admin";
type NotificationStatus = "pending" | "processing" | "sent" | "failed";
type NotificationType =
  | "admin_message"
  | "schedule_update"
  | "fighter_checkin";

type NotificationRequest = {
  type: NotificationType;
  title: string;
  body: string;
  target: NotificationTarget;
  targetUserId?: string;
  data?: Record<string, string>;
  status: NotificationStatus;
  createdAt?: admin.firestore.Timestamp;
  createdBy?: string;
};

type NotificationSettingsDoc = {
  enableFighterCheckinAlerts?: boolean;
  fighterCheckinTitleTemplate?: string;
  fighterCheckinBodyTemplate?: string;
};

const db = admin.firestore();
const META_DOC_ID = "_meta";

const DEFAULT_FIGHTER_CHECKIN_TITLE = "Check-in • {fighterName}";
const DEFAULT_FIGHTER_CHECKIN_BODY = "{time} • {accuracy}";

export const onCheckinCreated = onDocumentCreated(
  "checkins/{checkinId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const checkinId = event.params.checkinId;
    if (checkinId === META_DOC_ID) return;

    const data = snap.data() as Record<string, unknown> | undefined;
    if (!data) return;

    const fighterId = String(data.fighterId ?? "").trim();
    if (!fighterId) {
      logger.warn("Check-in missing fighterId", { checkinId });
      return;
    }

    const settings = await loadNotificationSettings();
    if (settings.enableFighterCheckinAlerts === false) {
      return;
    }

    const fighterName = await loadFighterName(fighterId);
    const time = formatCheckinTime(data);
    const accuracy = formatAccuracy(data.accuracyMeters);
    const label = String(data.label ?? "").trim();

    const values: Record<string, string> = {
      fighterName,
      time,
      accuracy,
      label,
    };

    const title = applyTemplate(
      settings.fighterCheckinTitleTemplate ?? "",
      values,
      DEFAULT_FIGHTER_CHECKIN_TITLE,
    );
    const body = applyTemplate(
      settings.fighterCheckinBodyTemplate ?? "",
      values,
      buildDefaultCheckinBody(time, accuracy, label),
    );

    await db.collection("notifications").add({
      type: "fighter_checkin",
      title,
      body,
      target: "admin",
      targetUserId: "",
      data: {
        screen: "checkins",
        checkinId,
        fighterId,
      },
      status: "pending",
      createdBy: fighterId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

export const onNotificationCreated = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const ref = snap.ref;
    const raw = snap.data() as Partial<NotificationRequest> | undefined;
    if (!raw) return;

    if (
      raw.type !== "admin_message" &&
      raw.type !== "schedule_update" &&
      raw.type !== "fighter_checkin"
    ) {
      return;
    }

    const title = (raw.title ?? "").trim();
    const body = (raw.body ?? "").trim();
    const target = (raw.target ?? "broadcast") as NotificationTarget;
    const targetUserId = (raw.targetUserId ?? "").trim();

    if (!title || !body) {
      await ref.set(
        {
          status: "failed",
          errorMessage: "Missing title/body",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return;
    }

    // Guard against duplicate processing.
    const locked = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      const status = (fresh.get("status") as string | undefined) ?? "pending";
      if (status !== "pending") {
        return false;
      }
      tx.set(
        ref,
        {
          status: "processing",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return true;
    });
    if (!locked) return;

    try {
      const targets = await resolveTargetUsers({ target, targetUserId });
      if (targets.length === 0) {
        const noUsersMessage =
          target === "user"
            ? "Target user not found"
            : target === "admin"
              ? "No admin users found"
              : "No users matched";
        await ref.set(
          {
            status: "failed",
            errorMessage: noUsersMessage,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        return;
      }

      let totalTokens = 0;
      let successCount = 0;
      let failureCount = 0;

      for (const t of targets) {
        const tokens = await loadDeviceTokens(t.uid);
        if (tokens.length === 0) continue;

        totalTokens += tokens.length;
        const personalizedTitle = applyUserPlaceholders(title, {
          uid: t.uid,
          fullName: t.fullName,
        });
        const personalizedBody = applyUserPlaceholders(body, {
          uid: t.uid,
          fullName: t.fullName,
        });
        const result = await admin.messaging().sendEachForMulticast({
          tokens,
          notification: { title: personalizedTitle, body: personalizedBody },
          data: raw.data ?? {},
        });

        successCount += result.successCount;
        failureCount += result.failureCount;

        await cleanupInvalidTokens(t.uid, tokens, result.responses);
      }

      // Mark sent even with zero tokens (in-app alerts still work via Firestore).
      await ref.set(
        {
          status: "sent",
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          result: {
            users: targets.length,
            tokens: totalTokens,
            success: successCount,
            failure: failureCount,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } catch (e) {
      logger.error("Failed to send notification", e);
      await ref.set(
        {
          status: "failed",
          errorMessage: toErrorMessage(e),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  },
);

type TargetUser = { uid: string; fullName: string };

async function resolveTargetUsers(input: {
  target: NotificationTarget;
  targetUserId: string;
}): Promise<TargetUser[]> {
  if (input.target === "admin") {
    const snap = await db
      .collection("users")
      .where("role", "==", "admin")
      .get();
    return snap.docs.map((d) => {
      const rawName = (d.get("fullName") as string | undefined) ?? "";
      return {
        uid: d.id,
        fullName: rawName.trim() || "Admin",
      };
    });
  }

  if (input.target === "user") {
    if (!input.targetUserId) return [];
    const snap = await db.collection("users").doc(input.targetUserId).get();
    if (!snap.exists) return [];
    const rawName = (snap.get("fullName") as string | undefined) ?? "";
    const fullName = rawName.trim() || "Fighter";
    return [{ uid: snap.id, fullName }];
  }

  // Broadcast: enabled fighters only (role == fighter && disabled == false).
  const snap = await db
    .collection("users")
    .where("role", "==", "fighter")
    .where("disabled", "==", false)
    .get();
  return snap.docs.map((d) => {
    const rawName = (d.get("fullName") as string | undefined) ?? "";
    return {
      uid: d.id,
      fullName: rawName.trim() || "Fighter",
    };
  });
}

function applyUserPlaceholders(
  input: string,
  user: { uid: string; fullName: string },
): string {
  return input.replaceAll("{fighterName}", user.fullName);
}

async function loadDeviceTokens(userId: string): Promise<string[]> {
  const snap = await db.collection(`users/${userId}/deviceTokens`).get();
  const tokens: string[] = [];
  for (const doc of snap.docs) {
    const token = (doc.get("token") as string | undefined)?.trim();
    if (token) tokens.push(token);
  }
  return tokens;
}

async function cleanupInvalidTokens(
  userId: string,
  tokens: string[],
  responses: admin.messaging.SendResponse[],
): Promise<void> {
  const invalidIndices: number[] = [];
  for (let i = 0; i < responses.length; i++) {
    const r = responses[i];
    if (r.success) continue;
    const code = r.error?.code ?? "";
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      invalidIndices.push(i);
    }
  }
  if (invalidIndices.length === 0) return;

  const tokenSet = new Set(invalidIndices.map((i) => tokens[i]));
  const tokenDocs = await db.collection(`users/${userId}/deviceTokens`).get();
  const batch = db.batch();
  for (const doc of tokenDocs.docs) {
    const token = (doc.get("token") as string | undefined)?.trim();
    if (token && tokenSet.has(token)) {
      batch.delete(doc.ref);
    }
  }
  await batch.commit();
}

async function loadNotificationSettings(): Promise<NotificationSettingsDoc> {
  const snap = await db.collection("settings").doc("notifications").get();
  if (!snap.exists) return {};
  return (snap.data() ?? {}) as NotificationSettingsDoc;
}

async function loadFighterName(fighterId: string): Promise<string> {
  const snap = await db.collection("users").doc(fighterId).get();
  if (!snap.exists) return "Fighter";
  const rawName = (snap.get("fullName") as string | undefined) ?? "";
  return rawName.trim() || "Fighter";
}

function formatCheckinTime(data: Record<string, unknown>): string {
  const millis = data.timestampMillis;
  if (typeof millis === "number" && millis > 0) {
    return formatDateTime(new Date(millis));
  }
  const createdAt = data.createdAt;
  if (createdAt instanceof admin.firestore.Timestamp) {
    return formatDateTime(createdAt.toDate());
  }
  return formatDateTime(new Date());
}

function formatDateTime(dt: Date): string {
  const y = dt.getFullYear();
  const m = String(dt.getMonth() + 1).padStart(2, "0");
  const d = String(dt.getDate()).padStart(2, "0");
  const hh = String(dt.getHours()).padStart(2, "0");
  const mm = String(dt.getMinutes()).padStart(2, "0");
  return `${y}-${m}-${d} ${hh}:${mm}`;
}

function formatAccuracy(raw: unknown): string {
  if (typeof raw !== "number" || !Number.isFinite(raw)) {
    return "accuracy unknown";
  }
  return `${Math.round(raw)}m accuracy`;
}

function buildDefaultCheckinBody(
  time: string,
  accuracy: string,
  label: string,
): string {
  const parts = [time, accuracy];
  if (label) {
    parts.push(label);
  }
  return parts.join(" • ");
}

function applyTemplate(
  template: string,
  values: Record<string, string>,
  fallback: string,
): string {
  const source = template.trim() || fallback;
  let out = source;
  for (const [key, value] of Object.entries(values)) {
    out = out.replaceAll(`{${key}}`, value);
  }
  return out.trim();
}

function toErrorMessage(e: unknown): string {
  if (e instanceof Error) return e.message;
  return String(e);
}
