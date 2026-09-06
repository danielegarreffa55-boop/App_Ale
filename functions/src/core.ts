import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {CallableRequest, HttpsError} from "firebase-functions/v2/https";

if (getApps().length === 0) initializeApp();

export const db = getFirestore();
db.settings({ignoreUndefinedProperties: true});

export const callableOptions = {
  region: "europe-west1",
  enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true",
  consumeAppCheckToken: process.env.FUNCTIONS_EMULATOR !== "true",
};

export function requireAuth(request: CallableRequest<unknown>): string {
  if (!request.auth) throw new HttpsError("unauthenticated", "AUTH_REQUIRED");
  return request.auth.uid;
}

export function requireAdmin(request: CallableRequest<unknown>): string {
  const uid = requireAuth(request);
  if (request.auth?.token.admin !== true) {
    throw new HttpsError("permission-denied", "ADMIN_REQUIRED");
  }
  return uid;
}

export function requireOwner(request: CallableRequest<unknown>): string {
  const uid = requireAuth(request);
  if (request.auth?.token.owner !== true) {
    throw new HttpsError("permission-denied", "OWNER_REQUIRED");
  }
  return uid;
}

export function parseDate(value: string): Date {
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) {
    throw new HttpsError("invalid-argument", "INVALID_DATE");
  }
  return date;
}

export function scheduleError(error: unknown): never {
  const message = error instanceof Error ? error.message : String(error);
  if (
    message === "SLOT_UNAVAILABLE" ||
    message === "OUTSIDE_OPENING_HOURS" ||
    message === "OVERLAPS_BREAK"
  ) {
    throw new HttpsError("failed-precondition", message);
  }
  if (message.startsWith("INVALID_")) {
    throw new HttpsError("invalid-argument", message);
  }
  throw error;
}

export async function rateLimit(
  uid: string,
  action: string,
  maximum: number,
  windowSeconds = 60,
): Promise<void> {
  const reference = db.collection("rateLimits").doc(`${uid}_${action}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const now = Timestamp.now();
    const start = snapshot.get("windowStart") as Timestamp | undefined;
    const expired = !start || now.toMillis() - start.toMillis() > windowSeconds * 1000;
    const count = expired ? 0 : ((snapshot.get("count") as number | undefined) || 0);
    if (count >= maximum) {
      throw new HttpsError("resource-exhausted", "RATE_LIMITED");
    }
    transaction.set(reference, {
      windowStart: expired ? now : start,
      count: count + 1,
      expiresAt: Timestamp.fromMillis(now.toMillis() + windowSeconds * 2000),
    });
  });
}
