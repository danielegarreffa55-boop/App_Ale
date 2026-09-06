import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {DateTime} from "luxon";
import {z} from "zod";
import {
  callableOptions,
  db,
  parseDate,
  rateLimit,
  requireAdmin,
  requireAuth,
  scheduleError,
} from "./core";
import {
  acquireLocks,
  defaultOpeningHours,
  ensureWithinOpeningHours,
  localDayBounds,
  lockReferences,
  openingDayFor,
  replaceLocks,
  releaseLocks,
} from "./schedule";
import {
  AppointmentDocument,
  AppointmentStatus,
  ServiceDocument,
  StudioConfig,
} from "./types";

const appointmentIdSchema = z.object({appointmentId: z.string().min(1).max(200)});
const createSchema = z.object({
  serviceId: z.string().min(1).max(200),
  requestedStartAt: z.string().datetime({offset: true}),
});
const availabilitySchema = z.object({
  serviceId: z.string().min(1).max(200),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
});
const counterSchema = appointmentIdSchema.extend({
  proposedStartAt: z.string().datetime({offset: true}),
});
const rejectSchema = appointmentIdSchema.extend({
  reason: z.string().trim().max(500).nullish(),
});
const responseSchema = appointmentIdSchema.extend({accept: z.boolean()});
const manualSchema = z.object({
  clientId: z.string().min(1).max(200),
  serviceId: z.string().min(1).max(200),
  startAt: z.string().datetime({offset: true}),
});
const rescheduleSchema = appointmentIdSchema.extend({
  startAt: z.string().datetime({offset: true}),
});
const blockSchema = z.object({
  startAt: z.string().datetime({offset: true}),
  endAt: z.string().datetime({offset: true}),
  reason: z.string().trim().max(300),
});

async function studioConfig(): Promise<StudioConfig> {
  const snapshot = await db.collection("studio").doc("config").get();
  return (snapshot.data() || {
    timezone: "Europe/Rome",
    openingHours: defaultOpeningHours,
  }) as StudioConfig;
}

function boundedSetting(
  value: number | undefined,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  if (!Number.isInteger(value) || value! < minimum || value! > maximum) {
    return fallback;
  }
  return value!;
}

function historyEntry(
  from: AppointmentStatus | null,
  to: AppointmentStatus,
  actorUid: string,
) {
  return {from, to, at: Timestamp.now(), actorUid};
}

async function confirmExistingAppointment(
  appointmentId: string,
  candidate: "requested" | "proposed",
  actorUid: string,
  isAdmin: boolean,
): Promise<void> {
  const reference = db.collection("appointments").doc(appointmentId);
  try {
    await db.runTransaction(async (transaction) => {
      const appointmentSnapshot = await transaction.get(reference);
      if (!appointmentSnapshot.exists) {
        throw new HttpsError("not-found", "APPOINTMENT_NOT_FOUND");
      }
      const appointment = appointmentSnapshot.data() as AppointmentDocument;
      if (isAdmin) {
        if (candidate !== "requested" || appointment.status !== "PENDING_ADMIN") {
          throw new HttpsError("failed-precondition", "INVALID_TRANSITION");
        }
      } else if (
        appointment.clientId !== actorUid ||
        candidate !== "proposed" ||
        appointment.status !== "COUNTER_PROPOSED"
      ) {
        throw new HttpsError("permission-denied", "INVALID_TRANSITION");
      }
      const startTimestamp = candidate === "requested"
        ? appointment.requestedStartAt
        : appointment.proposedStartAt;
      if (!startTimestamp) {
        throw new HttpsError("failed-precondition", "MISSING_PROPOSAL");
      }
      const startAt = startTimestamp.toDate();
      const endAt = new Date(
        startAt.getTime() + appointment.durationMinutes * 60_000,
      );
      const lockEndAt = new Date(
        endAt.getTime() + appointment.bufferMinutes * 60_000,
      );
      const configSnapshot = await transaction.get(
        db.collection("studio").doc("config"),
      );
      const config = (configSnapshot.data() || {
        timezone: "Europe/Rome",
        openingHours: defaultOpeningHours,
      }) as StudioConfig;
      ensureWithinOpeningHours(startAt, lockEndAt, config);
      await acquireLocks(
        db,
        transaction,
        appointmentId,
        "appointment",
        startAt,
        lockEndAt,
      );
      transaction.update(reference, {
        status: "CONFIRMED",
        confirmedStartAt: Timestamp.fromDate(startAt),
        confirmedEndAt: Timestamp.fromDate(endAt),
        confirmedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        reminderSent: false,
        history: FieldValue.arrayUnion(
          historyEntry(appointment.status, "CONFIRMED", actorUid),
        ),
      });
    });
  } catch (error) {
    scheduleError(error);
  }
}

export const getAvailability = onCall(callableOptions, async (request) => {
  const uid = requireAuth(request);
  await rateLimit(uid, "availability", 60);
  const data = availabilitySchema.parse(request.data);
  const [serviceSnapshot, config] = await Promise.all([
    db.collection("services").doc(data.serviceId).get(),
    studioConfig(),
  ]);
  if (!serviceSnapshot.exists || serviceSnapshot.get("active") !== true) {
    throw new HttpsError("not-found", "SERVICE_NOT_FOUND");
  }
  const service = serviceSnapshot.data() as ServiceDocument;
  const timezone = config.timezone || "Europe/Rome";
  const now = DateTime.now().setZone(timezone);
  const slotMinutes = boundedSetting(config.slotMinutes, 30, 5, 120);
  const minimumLeadMinutes = boundedSetting(
    config.minimumLeadMinutes,
    120,
    0,
    43_200,
  );
  const bookingHorizonDays = boundedSetting(
    config.bookingHorizonDays,
    90,
    1,
    730,
  );
  const bounds = localDayBounds(data.date, timezone);
  const maximum = now.startOf("day").plus({days: bookingHorizonDays + 1});
  if (bounds.start < now.startOf("day") ||
      bounds.start >= maximum) {
    throw new HttpsError("invalid-argument", "DATE_OUT_OF_RANGE");
  }
  const {day} = openingDayFor(bounds.start.toUTC().toJSDate(), config);
  if (!day.enabled) return {slots: []};
  const open = DateTime.fromISO(`${data.date}T${day.open}`, {zone: timezone});
  const close = DateTime.fromISO(`${data.date}T${day.close}`, {zone: timezone});
  const slots: Array<{startAt: string; endAt: string}> = [];
  const duration = service.durationMinutes;
  const buffer = service.bufferMinutes || 0;
  for (
    let cursor = open;
    cursor < close;
    cursor = cursor.plus({minutes: slotMinutes})
  ) {
    const end = cursor.plus({minutes: duration});
    const lockEnd = end.plus({minutes: buffer});
    if (
      lockEnd > close ||
      cursor.toUTC() < now.toUTC().plus({minutes: minimumLeadMinutes})
    ) {
      continue;
    }
    try {
      ensureWithinOpeningHours(
        cursor.toUTC().toJSDate(),
        lockEnd.toUTC().toJSDate(),
        config,
      );
    } catch {
      continue;
    }
    slots.push({
      startAt: cursor.toUTC().toISO()!,
      endAt: end.toUTC().toISO()!,
    });
  }
  return {slots};
});

export const createAppointmentRequest = onCall(
  callableOptions,
  async (request) => {
    const uid = requireAuth(request);
    await rateLimit(uid, "createAppointment", 10, 3600);
    if (request.auth?.token.email_verified !== true) {
      throw new HttpsError("failed-precondition", "EMAIL_NOT_VERIFIED");
    }
    const data = createSchema.parse(request.data);
    const startAt = parseDate(data.requestedStartAt);
    const [serviceSnapshot, profileSnapshot, config] = await Promise.all([
      db.collection("services").doc(data.serviceId).get(),
      db.collection("users").doc(uid).get(),
      studioConfig(),
    ]);
    const minimumLeadMinutes = boundedSetting(
      config.minimumLeadMinutes,
      120,
      0,
      43_200,
    );
    const bookingHorizonDays = boundedSetting(
      config.bookingHorizonDays,
      90,
      1,
      730,
    );
    if (startAt.getTime() < Date.now() + minimumLeadMinutes * 60_000) {
      throw new HttpsError("invalid-argument", "DATE_TOO_SOON");
    }
    const timezone = config.timezone || "Europe/Rome";
    const maximum = DateTime.now()
      .setZone(timezone)
      .startOf("day")
      .plus({days: bookingHorizonDays + 1});
    const requestedLocal = DateTime.fromJSDate(startAt, {zone: "utc"})
      .setZone(timezone);
    if (requestedLocal >= maximum) {
      throw new HttpsError("invalid-argument", "DATE_OUT_OF_RANGE");
    }
    if (!serviceSnapshot.exists || serviceSnapshot.get("active") !== true) {
      throw new HttpsError("not-found", "SERVICE_NOT_FOUND");
    }
    if (!profileSnapshot.exists) {
      throw new HttpsError("failed-precondition", "PROFILE_REQUIRED");
    }
    const service = serviceSnapshot.data() as ServiceDocument;
    const endAt = new Date(startAt.getTime() + service.durationMinutes * 60_000);
    const lockEndAt = new Date(
      endAt.getTime() + (service.bufferMinutes || 0) * 60_000,
    );
    try {
      ensureWithinOpeningHours(startAt, lockEndAt, config);
    } catch (error) {
      scheduleError(error);
    }
    const reference = db.collection("appointments").doc();
    const name = `${profileSnapshot.get("firstName") || ""} ${
      profileSnapshot.get("lastName") || ""
    }`.trim();
    const now = Timestamp.now();
    const appointment: AppointmentDocument = {
      clientId: uid,
      clientName: name || "Cliente",
      clientPhone: profileSnapshot.get("phone") as string | undefined,
      serviceId: serviceSnapshot.id,
      serviceName: service.name,
      durationMinutes: service.durationMinutes,
      bufferMinutes: service.bufferMinutes || 0,
      status: "PENDING_ADMIN",
      requestedStartAt: Timestamp.fromDate(startAt),
      requestedEndAt: Timestamp.fromDate(endAt),
      createdAt: now,
      updatedAt: now,
      reminderSent: false,
      history: [historyEntry(null, "PENDING_ADMIN", uid)],
    };
    await reference.create(appointment);
    return {appointmentId: reference.id};
  },
);

export const adminAcceptAppointment = onCall(callableOptions, async (request) => {
  const uid = requireAdmin(request);
  const data = appointmentIdSchema.parse(request.data);
  await confirmExistingAppointment(data.appointmentId, "requested", uid, true);
  return {ok: true};
});

export const adminRejectAppointment = onCall(callableOptions, async (request) => {
  const uid = requireAdmin(request);
  const data = rejectSchema.parse(request.data);
  const reference = db.collection("appointments").doc(data.appointmentId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) throw new HttpsError("not-found", "APPOINTMENT_NOT_FOUND");
    const appointment = snapshot.data() as AppointmentDocument;
    if (!["PENDING_ADMIN", "COUNTER_PROPOSED", "COUNTER_REJECTED"].includes(
      appointment.status,
    )) {
      throw new HttpsError("failed-precondition", "INVALID_TRANSITION");
    }
    transaction.update(reference, {
      status: "REJECTED",
      rejectedAt: Timestamp.now(),
      adminReason: data.reason || FieldValue.delete(),
      updatedAt: Timestamp.now(),
      history: FieldValue.arrayUnion(
        historyEntry(appointment.status, "REJECTED", uid),
      ),
    });
  });
  return {ok: true};
});

export const adminCounterPropose = onCall(callableOptions, async (request) => {
  const uid = requireAdmin(request);
  const data = counterSchema.parse(request.data);
  const proposedStartAt = parseDate(data.proposedStartAt);
  const reference = db.collection("appointments").doc(data.appointmentId);
  try {
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new HttpsError("not-found", "APPOINTMENT_NOT_FOUND");
      const appointment = snapshot.data() as AppointmentDocument;
      if (!["PENDING_ADMIN", "COUNTER_PROPOSED", "COUNTER_REJECTED"].includes(
        appointment.status,
      )) {
        throw new HttpsError("failed-precondition", "INVALID_TRANSITION");
      }
      const endAt = new Date(
        proposedStartAt.getTime() + appointment.durationMinutes * 60_000,
      );
      const lockEndAt = new Date(
        endAt.getTime() + appointment.bufferMinutes * 60_000,
      );
      const configSnapshot = await transaction.get(
        db.collection("studio").doc("config"),
      );
      const config = (configSnapshot.data() || {
        timezone: "Europe/Rome",
        openingHours: defaultOpeningHours,
      }) as StudioConfig;
      ensureWithinOpeningHours(proposedStartAt, lockEndAt, config);
      const lockSnapshots = await transaction.getAll(
        ...lockReferences(db, proposedStartAt, lockEndAt),
      );
      if (lockSnapshots.some(
        (lock) => lock.exists && lock.get("holderType") !== "block",
      )) {
        throw new Error("SLOT_UNAVAILABLE");
      }
      transaction.update(reference, {
        status: "COUNTER_PROPOSED",
        originalStartAt: appointment.originalStartAt || appointment.requestedStartAt,
        proposedStartAt: Timestamp.fromDate(proposedStartAt),
        proposedEndAt: Timestamp.fromDate(endAt),
        counterProposedAt: Timestamp.now(),
        counterProposedBy: uid,
        updatedAt: Timestamp.now(),
        history: FieldValue.arrayUnion(
          historyEntry(appointment.status, "COUNTER_PROPOSED", uid),
        ),
      });
    });
  } catch (error) {
    scheduleError(error);
  }
  return {ok: true};
});

export const clientRespondToCounterProposal = onCall(
  callableOptions,
  async (request) => {
    const uid = requireAuth(request);
    await rateLimit(uid, "counterResponse", 10, 3600);
    const data = responseSchema.parse(request.data);
    if (data.accept) {
      await confirmExistingAppointment(data.appointmentId, "proposed", uid, false);
      return {ok: true, status: "CONFIRMED"};
    }
    const reference = db.collection("appointments").doc(data.appointmentId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new HttpsError("not-found", "APPOINTMENT_NOT_FOUND");
      const appointment = snapshot.data() as AppointmentDocument;
      if (appointment.clientId !== uid || appointment.status !== "COUNTER_PROPOSED") {
        throw new HttpsError("permission-denied", "INVALID_TRANSITION");
      }
      transaction.update(reference, {
        status: "COUNTER_REJECTED",
        counterRejectedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        history: FieldValue.arrayUnion(
          historyEntry("COUNTER_PROPOSED", "COUNTER_REJECTED", uid),
        ),
      });
    });
    return {ok: true, status: "COUNTER_REJECTED"};
  },
);

export const cancelAppointment = onCall(callableOptions, async (request) => {
  const uid = requireAuth(request);
  const data = appointmentIdSchema.parse(request.data);
  const admin = request.auth?.token.admin === true;
  const reference = db.collection("appointments").doc(data.appointmentId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (!snapshot.exists) throw new HttpsError("not-found", "APPOINTMENT_NOT_FOUND");
    const appointment = snapshot.data() as AppointmentDocument;
    if (!admin && appointment.clientId !== uid) {
      throw new HttpsError("permission-denied", "NOT_OWNER");
    }
    if (["REJECTED", "CANCELLED", "COMPLETED"].includes(appointment.status)) {
      throw new HttpsError("failed-precondition", "INVALID_TRANSITION");
    }
    if (!admin && appointment.status === "CONFIRMED" && appointment.confirmedStartAt) {
      const configSnapshot = await transaction.get(
        db.collection("studio").doc("config"),
      );
      const config = (configSnapshot.data() || {}) as StudioConfig;
      const noticeHours = boundedSetting(
        config.cancellationNoticeHours,
        24,
        0,
        720,
      );
      if (
        appointment.confirmedStartAt.toMillis() <
        Date.now() + noticeHours * 3_600_000
      ) {
        throw new HttpsError(
          "failed-precondition",
          "CANCELLATION_WINDOW_CLOSED",
        );
      }
    }
    if (appointment.status === "CONFIRMED" && appointment.confirmedStartAt) {
      const startAt = appointment.confirmedStartAt.toDate();
      const lockEndAt = new Date(
        startAt.getTime() +
          (appointment.durationMinutes + appointment.bufferMinutes) * 60_000,
      );
      await releaseLocks(db, transaction, data.appointmentId, startAt, lockEndAt);
    }
    transaction.update(reference, {
      status: "CANCELLED",
      cancelledAt: Timestamp.now(),
      cancelledBy: uid,
      updatedAt: Timestamp.now(),
      history: FieldValue.arrayUnion(
        historyEntry(appointment.status, "CANCELLED", uid),
      ),
    });
  });
  return {ok: true};
});

export const adminCompleteAppointment = onCall(
  callableOptions,
  async (request) => {
    const uid = requireAdmin(request);
    const data = appointmentIdSchema.parse(request.data);
    const reference = db.collection("appointments").doc(data.appointmentId);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new HttpsError("not-found", "APPOINTMENT_NOT_FOUND");
      const appointment = snapshot.data() as AppointmentDocument;
      if (appointment.status !== "CONFIRMED") {
        throw new HttpsError("failed-precondition", "INVALID_TRANSITION");
      }
      transaction.update(reference, {
        status: "COMPLETED",
        completedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        history: FieldValue.arrayUnion(
          historyEntry("CONFIRMED", "COMPLETED", uid),
        ),
      });
    });
    return {ok: true};
  },
);

export const adminRescheduleAppointment = onCall(
  callableOptions,
  async (request) => {
    const uid = requireAdmin(request);
    const data = rescheduleSchema.parse(request.data);
    const newStartAt = parseDate(data.startAt);
    const reference = db.collection("appointments").doc(data.appointmentId);
    try {
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(reference);
        if (!snapshot.exists) {
          throw new HttpsError("not-found", "APPOINTMENT_NOT_FOUND");
        }
        const appointment = snapshot.data() as AppointmentDocument;
        if (appointment.status !== "CONFIRMED" || !appointment.confirmedStartAt) {
          throw new HttpsError("failed-precondition", "INVALID_TRANSITION");
        }
        const newEndAt = new Date(
          newStartAt.getTime() + appointment.durationMinutes * 60_000,
        );
        const newLockEndAt = new Date(
          newEndAt.getTime() + appointment.bufferMinutes * 60_000,
        );
        const oldStartAt = appointment.confirmedStartAt.toDate();
        const oldLockEndAt = new Date(
          oldStartAt.getTime() +
            (appointment.durationMinutes + appointment.bufferMinutes) * 60_000,
        );
        const configSnapshot = await transaction.get(
          db.collection("studio").doc("config"),
        );
        const config = (configSnapshot.data() || {
          timezone: "Europe/Rome",
          openingHours: defaultOpeningHours,
        }) as StudioConfig;
        ensureWithinOpeningHours(newStartAt, newLockEndAt, config);
        await replaceLocks(
          db,
          transaction,
          data.appointmentId,
          oldStartAt,
          oldLockEndAt,
          newStartAt,
          newLockEndAt,
        );
        transaction.update(reference, {
          confirmedStartAt: Timestamp.fromDate(newStartAt),
          confirmedEndAt: Timestamp.fromDate(newEndAt),
          rescheduledAt: Timestamp.now(),
          rescheduledBy: uid,
          updatedAt: Timestamp.now(),
          history: FieldValue.arrayUnion({
            action: "RESCHEDULED",
            fromStartAt: appointment.confirmedStartAt,
            toStartAt: Timestamp.fromDate(newStartAt),
            at: Timestamp.now(),
            actorUid: uid,
          }),
        });
      });
    } catch (error) {
      scheduleError(error);
    }
    return {ok: true};
  },
);

export const adminCreateAppointment = onCall(
  callableOptions,
  async (request) => {
    const uid = requireAdmin(request);
    const data = manualSchema.parse(request.data);
    const startAt = parseDate(data.startAt);
    const appointmentRef = db.collection("appointments").doc();
    try {
      await db.runTransaction(async (transaction) => {
        const serviceRef = db.collection("services").doc(data.serviceId);
        const clientRef = db.collection("users").doc(data.clientId);
        const configRef = db.collection("studio").doc("config");
        const [serviceSnapshot, clientSnapshot, configSnapshot] =
          await transaction.getAll(serviceRef, clientRef, configRef);
        if (!serviceSnapshot.exists || !clientSnapshot.exists) {
          throw new HttpsError("not-found", "CLIENT_OR_SERVICE_NOT_FOUND");
        }
        const service = serviceSnapshot.data() as ServiceDocument;
        const endAt = new Date(startAt.getTime() + service.durationMinutes * 60_000);
        const lockEndAt = new Date(
          endAt.getTime() + (service.bufferMinutes || 0) * 60_000,
        );
        const config = (configSnapshot.data() || {
          timezone: "Europe/Rome",
          openingHours: defaultOpeningHours,
        }) as StudioConfig;
        ensureWithinOpeningHours(startAt, lockEndAt, config);
        await acquireLocks(
          db,
          transaction,
          appointmentRef.id,
          "appointment",
          startAt,
          lockEndAt,
        );
        const clientName = `${clientSnapshot.get("firstName") || ""} ${
          clientSnapshot.get("lastName") || ""
        }`.trim();
        const now = Timestamp.now();
        const appointment: AppointmentDocument = {
          clientId: data.clientId,
          clientName: clientName || "Cliente",
          clientPhone: clientSnapshot.get("phone") as string | undefined,
          serviceId: data.serviceId,
          serviceName: service.name,
          durationMinutes: service.durationMinutes,
          bufferMinutes: service.bufferMinutes || 0,
          status: "CONFIRMED",
          requestedStartAt: Timestamp.fromDate(startAt),
          requestedEndAt: Timestamp.fromDate(endAt),
          confirmedStartAt: Timestamp.fromDate(startAt),
          confirmedEndAt: Timestamp.fromDate(endAt),
          createdAt: now,
          updatedAt: now,
          confirmedAt: now,
          reminderSent: false,
          history: [historyEntry(null, "CONFIRMED", uid)],
        };
        transaction.create(appointmentRef, appointment);
      });
    } catch (error) {
      scheduleError(error);
    }
    return {appointmentId: appointmentRef.id};
  },
);

export const adminCreateBlock = onCall(callableOptions, async (request) => {
  const uid = requireAdmin(request);
  const data = blockSchema.parse(request.data);
  const startAt = parseDate(data.startAt);
  const endAt = parseDate(data.endAt);
  if (!endAt || endAt <= startAt || endAt.getTime() - startAt.getTime() > 14 * 86_400_000) {
    throw new HttpsError("invalid-argument", "INVALID_BLOCK_INTERVAL");
  }
  const reference = db.collection("blocks").doc();
  try {
    await reference.create({
      startAt: Timestamp.fromDate(startAt),
      endAt: Timestamp.fromDate(endAt),
      reason: data.reason,
      active: true,
      createdBy: uid,
      createdAt: Timestamp.now(),
    });
  } catch (error) {
    scheduleError(error);
  }
  return {blockId: reference.id};
});
