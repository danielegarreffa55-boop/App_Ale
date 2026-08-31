import {createHash} from "node:crypto";
import {Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {DateTime} from "luxon";
import {db} from "./core";
import {deleteCalendarEvent, syncCalendarEvent} from "./calendar";
import {
  sendNotificationToAdmins,
  sendNotificationToUser,
} from "./notifications";
import {AppointmentDocument, AppointmentStatus, StudioConfig} from "./types";

function logKey(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function changed(
  before: AppointmentDocument | undefined,
  after: AppointmentDocument,
  key: keyof AppointmentDocument,
): boolean {
  const oldValue = before?.[key];
  const newValue = after[key];
  if (oldValue instanceof Timestamp && newValue instanceof Timestamp) {
    return oldValue.toMillis() !== newValue.toMillis();
  }
  return oldValue !== newValue;
}

export const appointmentNotifications = onDocumentWritten(
  {
    document: "appointments/{appointmentId}",
    region: "europe-west1",
    retry: true,
  },
  async (event) => {
    const before = event.data?.before.exists
      ? (event.data.before.data() as AppointmentDocument)
      : undefined;
    const after = event.data?.after.exists
      ? (event.data.after.data() as AppointmentDocument)
      : undefined;
    if (!after) return;
    if (before?.status === after.status) {
      if (
        after.status === "CONFIRMED" &&
        changed(before, after, "confirmedStartAt")
      ) {
        await sendNotificationToUser(
          db,
          after.clientId,
          `appointment_${event.params.appointmentId}_RESCHEDULED_${logKey(event.id)}`,
          {
            title: "Appuntamento modificato",
            body: "Lo studio ha aggiornato l'orario del tuo appuntamento.",
            data: {
              appointmentId: event.params.appointmentId,
              type: "appointment_rescheduled",
            },
          },
        );
      }
      return;
    }
    const id = event.params.appointmentId;
    const baseLog = `appointment_${id}_${after.status}_${logKey(event.id)}`;
    const data = {appointmentId: id, type: "appointment_status"};

    if (!before && after.status === "PENDING_ADMIN") {
      await sendNotificationToAdmins(db, `${baseLog}_admin`, {
        title: "Nuova richiesta",
        body: `${after.clientName} richiede ${after.serviceName}.`,
        data,
      });
      return;
    }
    switch (after.status) {
    case "CONFIRMED":
      await Promise.all([
        sendNotificationToUser(db, after.clientId, `${baseLog}_client`, {
          title: "Appuntamento confermato",
          body: "Il tuo appuntamento è stato confermato.",
          data,
        }),
        before?.status === "COUNTER_PROPOSED"
          ? sendNotificationToAdmins(db, `${baseLog}_admin`, {
            title: "Controproposta accettata",
            body: `${after.clientName} ha accettato il nuovo orario.`,
            data,
          })
          : Promise.resolve(),
      ]);
      break;
    case "REJECTED":
      await sendNotificationToUser(db, after.clientId, `${baseLog}_client`, {
        title: "Richiesta non accettata",
        body: "Lo studio non ha potuto accettare la tua richiesta.",
        data,
      });
      break;
    case "COUNTER_PROPOSED":
      await sendNotificationToUser(db, after.clientId, `${baseLog}_client`, {
        title: "Nuova proposta",
        body: "Lo studio ti propone un nuovo orario per il tuo appuntamento.",
        data,
      });
      break;
    case "COUNTER_REJECTED":
      await sendNotificationToAdmins(db, `${baseLog}_admin`, {
        title: "Controproposta rifiutata",
        body: `${after.clientName} ha rifiutato il nuovo orario.`,
        data,
      });
      break;
    case "CANCELLED":
      await Promise.all([
        sendNotificationToUser(db, after.clientId, `${baseLog}_client`, {
          title: "Appuntamento annullato",
          body: "Il tuo appuntamento è stato annullato.",
          data,
        }),
        sendNotificationToAdmins(db, `${baseLog}_admin`, {
          title: "Appuntamento annullato",
          body: `L'appuntamento di ${after.clientName} è stato annullato.`,
          data,
        }),
      ]);
      break;
    default:
      break;
    }
  },
);

export const appointmentCalendarSync = onDocumentWritten(
  {
    document: "appointments/{appointmentId}",
    region: "europe-west1",
    retry: true,
  },
  async (event) => {
    const before = event.data?.before.exists
      ? (event.data.before.data() as AppointmentDocument)
      : undefined;
    const after = event.data?.after.exists
      ? (event.data.after.data() as AppointmentDocument)
      : undefined;
    const id = event.params.appointmentId;
    if (!after) {
      if (before?.status === "CONFIRMED") await deleteCalendarEvent(id, before);
      return;
    }
    if (
      after.status === "CONFIRMED" &&
      (!before ||
        before.status !== "CONFIRMED" ||
        changed(before, after, "confirmedStartAt") ||
        changed(before, after, "confirmedEndAt") ||
        changed(before, after, "serviceName") ||
        changed(before, after, "clientName"))
    ) {
      await syncCalendarEvent(db, id, after);
    } else if (before?.status === "CONFIRMED" && after.status === "CANCELLED") {
      await deleteCalendarEvent(id, after);
      await event.data?.after.ref.set(
        {calendarSyncStatus: "DELETED", calendarSyncAt: Timestamp.now()},
        {merge: true},
      );
    }
  },
);

export const sendAppointmentReminders = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Europe/Rome",
    region: "europe-west1",
    retryCount: 3,
  },
  async () => {
    const configSnapshot = await db.collection("studio").doc("config").get();
    const config = (configSnapshot.data() || {}) as StudioConfig;
    const timezone = config.timezone || "Europe/Rome";
    const reminderTime = config.reminderTime || "18:00";
    const match = /^(\d{2}):(\d{2})$/.exec(reminderTime);
    if (!match) {
      logger.error("Orario promemoria non valido", {reminderTime});
      return;
    }
    const now = DateTime.now().setZone(timezone);
    const scheduled = now.set({
      hour: Number(match[1]),
      minute: Number(match[2]),
      second: 0,
      millisecond: 0,
    });
    const differenceMinutes = now.diff(scheduled, "minutes").minutes;
    if (differenceMinutes < 0 || differenceMinutes >= 5) return;

    const tomorrow = now.plus({days: 1}).startOf("day");
    const snapshot = await db
      .collection("appointments")
      .where("status", "==", "CONFIRMED" satisfies AppointmentStatus)
      .where("confirmedStartAt", ">=", Timestamp.fromDate(tomorrow.toUTC().toJSDate()))
      .where(
        "confirmedStartAt",
        "<",
        Timestamp.fromDate(tomorrow.plus({days: 1}).toUTC().toJSDate()),
      )
      .get();
    await Promise.all(
      snapshot.docs.map(async (document) => {
        const appointment = document.data() as AppointmentDocument;
        if (appointment.reminderSent || !appointment.confirmedStartAt) return;
        const localTime = DateTime.fromJSDate(
          appointment.confirmedStartAt.toDate(),
          {zone: "utc"},
        )
          .setZone(timezone)
          .toFormat("HH:mm");
        const logId = `reminder_${document.id}_${tomorrow.toISODate()}`;
        await sendNotificationToUser(db, appointment.clientId, logId, {
          title: "Promemoria appuntamento",
          body: `Promemoria: domani alle ${localTime} hai il tuo appuntamento presso ${
            config.studioName || "lo studio"
          }.`,
          data: {type: "reminder", appointmentId: document.id},
        });
        const log = await db.collection("notificationLogs").doc(logId).get();
        if (log.get("status") === "SENT") {
          await document.ref.set(
            {reminderSent: true, reminderSentAt: Timestamp.now()},
            {merge: true},
          );
        }
      }),
    );
  },
);
