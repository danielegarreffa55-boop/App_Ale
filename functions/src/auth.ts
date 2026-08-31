import {createHash} from "node:crypto";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {onCall} from "firebase-functions/v2/https";
import {z} from "zod";
import {callableOptions, db, rateLimit, requireAuth} from "./core";

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
      // Only the set-admin script can change these fields.
      isAdmin: existing.get("isAdmin") === true,
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

export const requestAccountDeletion = onCall(callableOptions, async (request) => {
  const uid = requireAuth(request);
  await rateLimit(uid, "deleteAccount", 2, 3600);

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
    },
    {merge: false},
  );
  await writer.close();
  await getAuth().deleteUser(uid);
  return {ok: true};
});
