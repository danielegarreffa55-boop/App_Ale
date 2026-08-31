import {DateTime} from "luxon";
import {describe, expect, it} from "vitest";
import {
  ensureWithinOpeningHours,
  localDayBounds,
  lockBucketIds,
} from "../src/schedule";

describe("lockBucketIds", () => {
  it("genera bucket comuni per intervalli sovrapposti", () => {
    const first = lockBucketIds(
      new Date("2026-09-01T08:00:00Z"),
      new Date("2026-09-01T08:35:00Z"),
    );
    const second = lockBucketIds(
      new Date("2026-09-01T08:30:00Z"),
      new Date("2026-09-01T09:00:00Z"),
    );
    expect(first.filter((key) => second.includes(key))).toHaveLength(1);
  });

  it("non sovrappone intervalli adiacenti", () => {
    const first = lockBucketIds(
      new Date("2026-09-01T08:00:00Z"),
      new Date("2026-09-01T08:30:00Z"),
    );
    const second = lockBucketIds(
      new Date("2026-09-01T08:30:00Z"),
      new Date("2026-09-01T09:00:00Z"),
    );
    expect(first.some((key) => second.includes(key))).toBe(false);
  });
});

describe("Europe/Rome", () => {
  it("gestisce il giorno corto al passaggio all'ora legale", () => {
    const bounds = localDayBounds("2026-03-29");
    expect(bounds.end.diff(bounds.start, "hours").hours).toBe(23);
  });

  it("gestisce il giorno lungo al ritorno all'ora solare", () => {
    const bounds = localDayBounds("2026-10-25");
    expect(bounds.end.diff(bounds.start, "hours").hours).toBe(25);
  });

  it("rifiuta una prenotazione durante la pausa", () => {
    const config = {
      timezone: "Europe/Rome",
      openingHours: {
        monday: {
          enabled: true,
          open: "09:00",
          close: "18:00",
          breaks: [{start: "12:30", end: "14:00"}],
        },
      },
    };
    const start = DateTime.fromISO("2026-08-31T12:15", {
      zone: "Europe/Rome",
    }).toUTC();
    expect(() =>
      ensureWithinOpeningHours(
        start.toJSDate(),
        start.plus({minutes: 30}).toJSDate(),
        config,
      ),
    ).toThrow("OVERLAPS_BREAK");
  });
});
