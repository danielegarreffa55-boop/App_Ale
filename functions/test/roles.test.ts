import {describe, expect, it} from "vitest";
import {claimsForRole} from "../src/auth";
import {requireOwner} from "../src/core";

describe("account roles", () => {
  it("grants both operational and owner permissions to an owner", () => {
    expect(claimsForRole({featureFlag: true}, "owner")).toEqual({
      featureFlag: true,
      role: "owner",
      admin: true,
      owner: true,
    });
  });

  it("keeps operational permissions but removes owner access from a manager", () => {
    expect(
      claimsForRole({admin: true, owner: true, role: "owner"}, "manager"),
    ).toEqual({role: "manager", admin: true});
  });

  it("removes every administrative permission from a client", () => {
    expect(
      claimsForRole({admin: true, owner: true, role: "owner"}, "client"),
    ).toEqual({role: "client"});
  });

  it("requires the dedicated owner claim", () => {
    expect(() =>
      requireOwner({
        auth: {uid: "manager-uid", token: {admin: true}},
      } as never),
    ).toThrow("OWNER_REQUIRED");

    expect(
      requireOwner({
        auth: {uid: "owner-uid", token: {admin: true, owner: true}},
      } as never),
    ).toBe("owner-uid");
  });
});
