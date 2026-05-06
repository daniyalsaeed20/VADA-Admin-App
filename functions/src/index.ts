import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import admin from "firebase-admin";

admin.initializeApp();

type NotificationTarget = "broadcast" | "user";
type NotificationStatus = "pending" | "processing" | "sent" | "failed";

type AdminMessageNotification = {
  type: "admin_message";
  title: string;
  body: string;
  target: NotificationTarget;
  targetUserId?: string;
  data?: Record<string, string>;
  status: NotificationStatus;
  createdAt?: admin.firestore.Timestamp;
  createdBy?: string;
};

const db = admin.firestore();

export const onNotificationCreated = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      return;
    }

    const ref = snap.ref;
    const raw = snap.data() as Partial<AdminMessageNotification> | undefined;
    if (!raw) {
      return;
    }

    if (raw.type !== "admin_message") {
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
    if (!locked) {
      return;
    }

    try {
      const userIds = await resolveTargetUserIds({ target, targetUserId });
      if (userIds.length === 0) {
        await ref.set(
          {
            status: "failed",
            errorMessage:
              target === "user" ? "Target user not found" : "No users matched",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        return;
      }

      let totalTokens = 0;
      let successCount = 0;
      let failureCount = 0;

      // Process sequentially to keep logic simple and avoid rate spikes.
      for (const uid of userIds) {
        const tokens = await loadDeviceTokens(uid);
        if (tokens.length === 0) {
          continue;
        }
        totalTokens += tokens.length;

        const result = await admin.messaging().sendEachForMulticast({
          tokens,
          notification: { title, body },
          data: raw.data ?? {},
        });

        successCount += result.successCount;
        failureCount += result.failureCount;

        // Cleanup invalid tokens.
        await cleanupInvalidTokens(uid, tokens, result.responses);
      }

      await ref.set(
        {
          status: "sent",
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          result: {
            users: userIds.length,
            tokens: totalTokens,
            success: successCount,
            failure: failureCount,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } catch (e) {
      logger.error("Failed to send admin message notification", e);
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

async function resolveTargetUserIds(input: {
  target: NotificationTarget;
  targetUserId: string;
}): Promise<string[]> {
  if (input.target === "user") {
    return input.targetUserId ? [input.targetUserId] : [];
  }

  // Broadcast: enabled fighters only (role == fighter && disabled == false).
  const snap = await db
    .collection("users")
    .where("role", "==", "fighter")
    .where("disabled", "==", false)
    .get();
  return snap.docs.map((d) => d.id);
}

async function loadDeviceTokens(userId: string): Promise<string[]> {
  const snap = await db.collection(`users/${userId}/deviceTokens`).get();
  const tokens: string[] = [];
  for (const doc of snap.docs) {
    const token = (doc.get("token") as string | undefined)?.trim();
    if (token) {
      tokens.push(token);
    }
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

function toErrorMessage(e: unknown): string {
  if (e instanceof Error) {
    return e.message;
  }
  return String(e);
}

