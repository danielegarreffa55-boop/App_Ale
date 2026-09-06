import {setGlobalOptions} from "firebase-functions/v2";

setGlobalOptions({region: "europe-west1", maxInstances: 20});

export {
  ensureUserProfile,
  ownerSetUserRole,
  registerDeviceToken,
  requestAccountDeletion,
} from "./auth";
export {
  adminAcceptAppointment,
  adminCompleteAppointment,
  adminCounterPropose,
  adminCreateAppointment,
  adminCreateBlock,
  adminRejectAppointment,
  adminRescheduleAppointment,
  cancelAppointment,
  clientRespondToCounterProposal,
  createAppointmentRequest,
  getAvailability,
} from "./appointments";
export {
  appointmentCalendarSync,
  appointmentNotifications,
  sendAppointmentReminders,
} from "./triggers";
