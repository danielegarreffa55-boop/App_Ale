import {createHash} from "node:crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {z} from "zod";
import {callableOptions, db, rateLimit, requireAuth, requireOwner} from "./core";

const profileSchema = z.object({
  firstName: z.string().trim().min(1).max(80),
  lastName: z.string().trim().min(1).max(80),
  phone: z.string().trim().min(5).max(30),
  privacyAccepted: z.literal(true),
});

const tokenSchema = z.object({
  token: z.string().min(20).max(4096),
  platform: z.enum(["android", "iOS", "macOS", "web", "windows", "linux"]),
});

const roleChangeSchema = z.object({
  uid: z.string().trim().min(1).max(128),
  role: z.enum(["client", "manager", "owner"]),
});

export type AccountRole = z.infer<typeof roleChangeSchema>["role"];

export function claimsForRole(
  currentClaims: Record<string, unknown> | undefined,
  role: AccountRole,
): Record<string, unknown> {
  const claims = {...(currentClaims || {})};
  delete claims.admin;
  delete claims.owner;
  delete claims.role;
  claims.role = role;
  if (role === "manager" || role === "owner") claims.admin = true;
  if (role === "owner") claims.owner = true;
  return claims;
}

export const ensureUserProfile = onCall(callableOptions, async (request) => {
  const uid = requireAuth(request);
  await rateLimit(uid, "profile", 5);
  const data = profileSchema.parse(request.data);
  const email = String(request.auth?.token.email || "").toLowerCase();
  const reference = db.collection("users").doc(uid);
  const existing = await reference.get();
  await reference.set(
    {
      uid,
      firstName: data.firstName,
      lastName: data.lastName,
      email,
      phone: data.phone,
      notificationEnabled: existing.get("notificationEnabled") || false,
      privacyAcceptedAt: existing.get("privacyAcceptedAt") || Timestamp.now(),
      createdAt: existing.get("createdAt") || Timestamp.now(),
      updatedAt: Timestamp.now(),
      // Only trusted Admin SDK flows can change role fields.
      isAdmin: existing.get("isAdmin") === true,
      isOwner: existing.get("isOwner") === true,
      role: existing.get("role") || "client",
    },
    {merge: true},
  );
  return {ok: true};
});

export const registerDeviceToken = onCall(callableOptions, async (request) => {
  const uid = requireAuth(request);
  await rateLimit(uid, "device", 20);
  const data = tokenSchema.parse(request.data);
  const id = createHash("sha256").update(data.token).digest("hex");
  await db.collection("users").doc(uid).collection("devices").doc(id).set(
    {
      token: data.token,
      platform: data.platform,
      updatedAt: Timestamp.now(),
      createdAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  await db.collection("users").doc(uid).set(
    {notificationEnabled: true, updatedAt: Timestamp.now()},
    {merge: true},
  );
  return {ok: true};
});

export const ownerSetUserRole = onCall(callableOptions, async (request) => {
  const ownerUid = requireOwner(request);
  await rateLimit(ownerUid, "setUserRole", 30);
  const data = roleChangeSchema.parse(request.data);
  if (data.uid === ownerUid && data.role !== "owner") {
    throw new HttpsError(
      "failed-precondition",
      "CANNOT_CHANGE_OWN_OWNER_ROLE",
    );
  }

  const auth = getAuth();
  const target = await auth.getUser(data.uid);
  const claims = claimsForRole(target.customClaims, data.role);
  await auth.setCustomUserClaims(target.uid, claims);
  await auth.revokeRefreshTokens(target.uid);

  const isOwner = data.role === "owner";
  const isAdmin = data.role === "manager" || isOwner;
  await db.collection("users").doc(target.uid).set(
    {
      role: data.role,
      isAdmin,
      isOwner,
      roleUpdatedAt: Timestamp.now(),
      roleUpdatedBy: ownerUid,
      updatedAt: Timestamp.now(),
    },
    {merge: true},
  );
  return {ok: true, role: data.role};
});

export const requestAccountDeletion = onCall(callableOptions, async (request) => {
  const uid = requireAuth(request);
  await rateLimit(uid, "deleteAccount", 2, 3600);
  if (request.auth?.token.owner === true) {
    throw new HttpsError(
      "failed-precondition",
      "OWNER_ACCOUNT_CANNOT_BE_DELETED",
    );
  }

  const [appointments, devices] = await Promise.all([
    db.collection("appointments").where("clientId", "==", uid).get(),
    db.collection("users").doc(uid).collection("devices").get(),
  ]);
  const writer = db.bulkWriter();
  appointments.docs.forEach((document) => {
    writer.update(document.ref, {
      clientName: "Cliente eliminato",
      clientPhone: FieldValue.delete(),
      updatedAt: Timestamp.now(),
    });
  });
  devices.docs.forEach((document) => writer.delete(document.ref));
  writer.set(
    db.collection("users").doc(uid),
    {
      uid,
      firstName: "",
      lastName: "",
      email: "",
      phone: "",
      notificationEnabled: false,
      deletedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      isAdmin: false,
      isOwner: false,
      role: "client",
    },
    {merge: false},
  );
  await writer.close();
  await getAuth().deleteUser(uid);
  return {ok: true};
});
