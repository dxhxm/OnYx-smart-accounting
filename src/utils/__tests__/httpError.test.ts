import { describe, it, expect } from "vitest";
import { HttpError, isHttpError } from "../httpError";

describe("HttpError", () => {
  it("initializes with given properties correctly", () => {
    const error = new HttpError({
      status: 404,
      code: "NOT_FOUND",
      message: "Company not found",
      notification: {
        type: "error",
        title: "Missing entity",
        message: "The requested company does not exist",
      },
      details: { companyId: "test-123" },
    });

    expect(error.name).toBe("HttpError");
    expect(error.status).toBe(404);
    expect(error.code).toBe("NOT_FOUND");
    expect(error.message).toBe("Company not found");
    expect(error.notification?.type).toBe("error");
    expect(error.details).toEqual({ companyId: "test-123" });
    expect(error instanceof Error).toBe(true);
  });

  describe("isHttpError", () => {
    it("returns true for instances of HttpError", () => {
      const error = new HttpError({
        status: 400,
        code: "BAD_REQUEST",
        message: "Invalid payload",
      });
      expect(isHttpError(error)).toBe(true);
    });

    it("returns false for standard Error or other values", () => {
      expect(isHttpError(new Error("Standard error"))).toBe(false);
      expect(isHttpError(null)).toBe(false);
      expect(isHttpError(undefined)).toBe(false);
      expect(isHttpError("error string")).toBe(false);
      expect(isHttpError({ message: "error" })).toBe(false);
    });
  });
});

