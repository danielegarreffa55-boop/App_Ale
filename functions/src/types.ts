import {Timestamp} from "firebase-admin/firestore";

export type AppointmentStatus =
  | "PENDING_ADMIN"
  | "COUNTER_PROPOSED"
  | "COUNTER_REJECTED"
  | "CONFIRMED"
  | "REJECTED"
  | "CANCELLED"
  | "COMPLETED";

export interface AppointmentDocument {
  clientId: string;
  clientName: string;
  clientPhone?: string;
  serviceId: string;
  serviceName: string;
  durationMinutes: number;
  bufferMinutes: number;
  status: AppointmentStatus;
  requestedStartAt: Timestamp;
  requestedEndAt: Timestamp;
  originalStartAt?: Timestamp;
  proposedStartAt?: Timestamp;
  proposedEndAt?: Timestamp;
  confirmedStartAt?: Timestamp;
  confirmedEndAt?: Timestamp;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  confirmedAt?: Timestamp;
  rejectedAt?: Timestamp;
  adminReason?: string;
  googleCalendarEventId?: string;
  reminderSent: boolean;
  reminderSentAt?: Timestamp;
  history: Array<{
    from: AppointmentStatus | null;
    to: AppointmentStatus;
    at: Timestamp;
    actorUid: string;
  }>;
}

export interface ServiceDocument {
  name: string;
  description?: string;
  durationMinutes: number;
  bufferMinutes?: number;
  priceCents?: number;
  active: boolean;
  displayOrder: number;
}

export interface OpeningDay {
  enabled: boolean;
  open: string;
  close: string;
  breaks?: Array<{start: string; end: string}>;
}

export interface StudioConfig {
  studioName?: string;
  timezone?: string;
  reminderTime?: string;
  openingHours?: Record<string, OpeningDay>;
}

export function canTransition(
  from: AppointmentStatus,
  to: AppointmentStatus,
): boolean {
  const allowed: Record<AppointmentStatus, AppointmentStatus[]> = {
    PENDING_ADMIN: ["CONFIRMED", "REJECTED", "COUNTER_PROPOSED", "CANCELLED"],
    COUNTER_PROPOSED: [
      "CONFIRMED",
      "COUNTER_REJECTED",
      "COUNTER_PROPOSED",
      "CANCELLED",
    ],
    COUNTER_REJECTED: ["COUNTER_PROPOSED", "REJECTED", "CANCELLED"],
    CONFIRMED: ["CANCELLED", "COMPLETED"],
    REJECTED: [],
    CANCELLED: [],
    COMPLETED: [],
  };
  return allowed[from].includes(to);
}
