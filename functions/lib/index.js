"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNotificationCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
const firebase_admin_1 = __importDefault(require("firebase-admin"));
firebase_admin_1.default.initializeApp();
const db = firebase_admin_1.default.firestore();
exports.onNotificationCreated = (0, firestore_1.onDocumentCreated)("notifications/{notificationId}", async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const ref = snap.ref;
    const raw = snap.data();
    if (!raw)
        return;
    if (raw.type !== "admin_message" && raw.type !== "schedule_update") {
        return;
    }
    const title = (raw.title ?? "").trim();
    const body = (raw.body ?? "").trim();
    const target = (raw.target ?? "broadcast");
    const targetUserId = (raw.targetUserId ?? "").trim();
    if (!title || !body) {
        await ref.set({
            status: "failed",
            errorMessage: "Missing title/body",
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return;
    }
    // Guard against duplicate processing.
    const locked = await db.runTransaction(async (tx) => {
        const fresh = await tx.get(ref);
        const status = fresh.get("status") ?? "pending";
        if (status !== "pending") {
            return false;
        }
        tx.set(ref, {
            status: "processing",
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return true;
    });
    if (!locked)
        return;
    try {
        const userIds = await resolveTargetUserIds({ target, targetUserId });
        if (userIds.length === 0) {
            await ref.set({
                status: "failed",
                errorMessage: target === "user" ? "Target user not found" : "No users matched",
                updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            return;
        }
        let totalTokens = 0;
        let successCount = 0;
        let failureCount = 0;
        for (const uid of userIds) {
            const tokens = await loadDeviceTokens(uid);
            if (tokens.length === 0)
                continue;
            totalTokens += tokens.length;
            const result = await firebase_admin_1.default.messaging().sendEachForMulticast({
                tokens,
                notification: { title, body },
                data: raw.data ?? {},
            });
            successCount += result.successCount;
            failureCount += result.failureCount;
            await cleanupInvalidTokens(uid, tokens, result.responses);
        }
        await ref.set({
            status: "sent",
            sentAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
            result: {
                users: userIds.length,
                tokens: totalTokens,
                success: successCount,
                failure: failureCount,
            },
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    catch (e) {
        firebase_functions_1.logger.error("Failed to send notification", e);
        await ref.set({
            status: "failed",
            errorMessage: toErrorMessage(e),
            updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
});
async function resolveTargetUserIds(input) {
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
async function loadDeviceTokens(userId) {
    const snap = await db.collection(`users/${userId}/deviceTokens`).get();
    const tokens = [];
    for (const doc of snap.docs) {
        const token = doc.get("token")?.trim();
        if (token)
            tokens.push(token);
    }
    return tokens;
}
async function cleanupInvalidTokens(userId, tokens, responses) {
    const invalidIndices = [];
    for (let i = 0; i < responses.length; i++) {
        const r = responses[i];
        if (r.success)
            continue;
        const code = r.error?.code ?? "";
        if (code === "messaging/invalid-registration-token" ||
            code === "messaging/registration-token-not-registered") {
            invalidIndices.push(i);
        }
    }
    if (invalidIndices.length === 0)
        return;
    const tokenSet = new Set(invalidIndices.map((i) => tokens[i]));
    const tokenDocs = await db.collection(`users/${userId}/deviceTokens`).get();
    const batch = db.batch();
    for (const doc of tokenDocs.docs) {
        const token = doc.get("token")?.trim();
        if (token && tokenSet.has(token)) {
            batch.delete(doc.ref);
        }
    }
    await batch.commit();
}
function toErrorMessage(e) {
    if (e instanceof Error)
        return e.message;
    return String(e);
}
