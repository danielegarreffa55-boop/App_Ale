import {createHash} from "node:crypto";
import {getMessaging} from "firebase-admin/messaging";
import {FieldValue, Firestore, Timestamp} from "firebase-admin/firestore";

const CLAIM_TIMEOUT_MS = 2 * 60_000;

interface NotificationContent {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export async function sendNotificationToUser(
  db: Firestore,
  uid: string,
  logId: string,
  content: NotificationContent,
): Promise<boolean> {
  const logRef = db.collection("notificationLogs").doc(logId);
  const claimed = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(logRef);
    if (snapshot.exists) {
      const status = snapshot.get("status") as string;
      const claimedAt = snapshot.get("claimedAt") as Timestamp | undefined;
      if (status === "SENT" || status === "SKIPPED") return false;
      if (
        status === "CLAIMED" &&
        claimedAt &&
        Date.now() - claimedAt.toMillis() < CLAIM_TIMEOUT_MS
      ) {
        return false;
      }
    }
    transaction.set(
      logRef,
      {
        uid,
        status: "CLAIMED",
        claimedAt: Timestamp.now(),
        attempts: FieldValue.increment(1),
        type: content.data?.type || "generic",
      },
      {merge: true},
    );
    return true;
  });
  if (!claimed) return false;

  try {
    const devices = await db.collection("users").doc(uid).collection("devices").get();
    const tokens = devices.docs
      .map((document) => document.get("token") as string | undefined)
      .filter((token): token is string => Boolean(token));
    if (tokens.length === 0) {
      await logRef.set({status: "SKIPPED", reason: "NO_TOKENS"}, {merge: true});
      return false;
    }
    const result = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title: content.title, body: content.body},
      data: content.data,
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });
    const invalidCodes = new Set([
      "messaging/registration-token-not-registered",
      "messaging/invalid-registration-token",
    ]);
    const cleanup = db.batch();
    result.responses.forEach((response, index) => {
      if (!response.success && invalidCodes.has(response.error?.code || "")) {
        const id = createHash("sha256").update(tokens[index]).digest("hex");
        cleanup.delete(db.collection("users").doc(uid).collection("devices").doc(id));
      }
    });
    await cleanup.commit();
    await logRef.set(
      {
        status: result.successCount > 0 ? "SENT" : "FAILED",
        sentAt: result.successCount > 0 ? Timestamp.now() : null,
        successCount: result.successCount,
        failureCount: result.failureCount,
      },
      {merge: true},
    );
    return result.successCount > 0;
  } catch (error) {
    await logRef.set(
      {status: "FAILED", error: String(error).slice(0, 500)},
      {merge: true},
    );
    throw error;
  }
}

export async function sendNotificationToAdmins(
  db: Firestore,
  logPrefix: string,
  content: NotificationContent,
): Promise<void> {
  const admins = await db.collection("users").where("isAdmin", "==", true).get();
  await Promise.all(
    admins.docs.map((admin) =>
      sendNotificationToUser(db, admin.id, `${logPrefix}_${admin.id}`, content),
    ),
  );
}
