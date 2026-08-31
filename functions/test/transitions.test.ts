import {describe, expect, it} from "vitest";
import {canTransition} from "../src/types";

describe("appointment state machine", () => {
  it("non conferma direttamente una controproposta rifiutata", () => {
    expect(canTransition("COUNTER_REJECTED", "CONFIRMED")).toBe(false);
  });

  it("consente al cliente di accettare una controproposta", () => {
    expect(canTransition("COUNTER_PROPOSED", "CONFIRMED")).toBe(true);
    expect(canTransition("COUNTER_PROPOSED", "COUNTER_REJECTED")).toBe(true);
  });

  it("rende terminali rifiuto, cancellazione e completamento", () => {
    expect(canTransition("REJECTED", "CONFIRMED")).toBe(false);
    expect(canTransition("CANCELLED", "CONFIRMED")).toBe(false);
    expect(canTransition("COMPLETED", "CONFIRMED")).toBe(false);
  });
});
