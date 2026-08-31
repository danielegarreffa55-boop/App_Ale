import {createHash} from "node:crypto";
import {Firestore, Timestamp} from "firebase-admin/firestore";
import {defineString} from "firebase-functions/params";
import {logger} from "firebase-functions";
import {google} from "googleapis";
import {AppointmentDocument} from "./types";

const calendarId = defineString("GOOGLE_CALENDAR_ID", {default: ""});

function deterministicEventId(appointmentId: string): string {
  return createHash("sha256").update(appointmentId).digest("hex").slice(0, 64);
}

export async function syncCalendarEvent(
  db: Firestore,
  appointmentId: string,
  appointment: AppointmentDocument,
): Promise<void> {
  const configuredCalendarId = calendarId.value();
  if (!configuredCalendarId) {
    logger.warn("Calendar non configurato", {appointmentId});
    await db.collection("appointments").doc(appointmentId).set(
      {calendarSyncStatus: "NOT_CONFIGURED", calendarSyncAt: Timestamp.now()},
      {merge: true},
    );
    return;
  }
  if (!appointment.confirmedStartAt || !appointment.confirmedEndAt) return;
  const auth = await google.auth.getClient({
    scopes: ["https://www.googleapis.com/auth/calendar"],
  });
  const calendar = google.calendar({version: "v3", auth});
  const eventId = appointment.googleCalendarEventId ||
    deterministicEventId(appointmentId);
  const requestBody = {
    summary: `${appointment.serviceName} - ${appointment.clientName}`,
    description: [
      `Cliente: ${appointment.clientName}`,
      appointment.clientPhone ? `Telefono: ${appointment.clientPhone}` : null,
      `Servizio: ${appointment.serviceName}`,
      `ID appuntamento: ${appointmentId}`,
    ]
      .filter(Boolean)
      .join("\n"),
    start: {
      dateTime: appointment.confirmedStartAt.toDate().toISOString(),
      timeZone: "Europe/Rome",
    },
    end: {
      dateTime: appointment.confirmedEndAt.toDate().toISOString(),
      timeZone: "Europe/Rome",
    },
    extendedProperties: {private: {appointmentId}},
  };
  try {
    try {
      await calendar.events.update({
        calendarId: configuredCalendarId,
        eventId,
        requestBody,
      });
    } catch (error: unknown) {
      const status = (error as {code?: number; response?: {status?: number}}).code ||
        (error as {response?: {status?: number}}).response?.status;
      if (status !== 404) throw error;
      try {
        await calendar.events.insert({
          calendarId: configuredCalendarId,
          requestBody: {id: eventId, ...requestBody},
        });
      } catch (insertError: unknown) {
        const insertStatus = (insertError as {code?: number}).code;
        if (insertStatus !== 409) throw insertError;
        await calendar.events.update({
          calendarId: configuredCalendarId,
          eventId,
          requestBody,
        });
      }
    }
    await db.collection("appointments").doc(appointmentId).set(
      {
        googleCalendarEventId: eventId,
        calendarSyncStatus: "SYNCED",
        calendarSyncAt: Timestamp.now(),
      },
      {merge: true},
    );
  } catch (error) {
    logger.error("Sincronizzazione Calendar fallita", {appointmentId, error});
    await db.collection("appointments").doc(appointmentId).set(
      {
        calendarSyncStatus: "ERROR",
        calendarSyncError: String(error).slice(0, 500),
        calendarSyncAt: Timestamp.now(),
      },
      {merge: true},
    );
    throw error;
  }
}

export async function deleteCalendarEvent(
  appointmentId: string,
  appointment: AppointmentDocument,
): Promise<void> {
  const configuredCalendarId = calendarId.value();
  if (!configuredCalendarId) return;
  const eventId = appointment.googleCalendarEventId ||
    deterministicEventId(appointmentId);
  const auth = await google.auth.getClient({
    scopes: ["https://www.googleapis.com/auth/calendar"],
  });
  const calendar = google.calendar({version: "v3", auth});
  try {
    await calendar.events.delete({calendarId: configuredCalendarId, eventId});
  } catch (error: unknown) {
    const status = (error as {code?: number}).code;
    if (status !== 404 && status !== 410) throw error;
  }
}
