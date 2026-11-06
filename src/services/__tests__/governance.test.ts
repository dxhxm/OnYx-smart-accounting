import { describe, it, expect } from "vitest";
import { computeStatus, isValidMonth, isValidDate } from "../governance.service";

describe("Governance Service Helper Logic", () => {
  describe("isValidMonth", () => {
    it("returns true for YYYY-MM format", () => {
      expect(isValidMonth("2024-01")).toBe(true);
      expect(isValidMonth("2026-12")).toBe(true);
    });

    it("returns false for invalid month strings", () => {
      expect(isValidMonth("2024-1")).toBe(false);
      expect(isValidMonth("2024/01")).toBe(false);
      expect(isValidMonth("2024-01-15")).toBe(false);
      expect(isValidMonth("invalid")).toBe(false);
    });
  });

  describe("isValidDate", () => {
    it("returns true for YYYY-MM-DD format", () => {
      expect(isValidDate("2024-01-15")).toBe(true);
      expect(isValidDate("2026-12-31")).toBe(true);
    });

    it("returns false for invalid date strings", () => {
      expect(isValidDate("2024-1-15")).toBe(false);
      expect(isValidDate("15-01-2024")).toBe(false);
      expect(isValidDate("2024/01/15")).toBe(false);
      expect(isValidDate("")).toBe(false);
    });
  });

  describe("computeStatus", () => {
    it("returns BLUE and unblocked when limit is 0 or negative", () => {
      const res = computeStatus(0, 500);
      expect(res.status).toBe("BLUE");
      expect(res.blocked).toBe(false);
      expect(res.usedPercent).toBe(0);
      expect(res.remaining).toBe(0);

      const negativeRes = computeStatus(-100, 50);
      expect(negativeRes.status).toBe("BLUE");
      expect(negativeRes.blocked).toBe(false);
    });

    it("returns BLUE when spending is under 80% of limit", () => {
      // 50% spend
      const res = computeStatus(1000, 500);
      expect(res.status).toBe("BLUE");
      expect(res.blocked).toBe(false);
      expect(res.usedPercent).toBe(50);
      expect(res.remaining).toBe(500);
    });

    it("returns YELLOW (warning) when spending is between 80% and 100% of limit", () => {
      // 80% threshold
      const res80 = computeStatus(1000, 800);
      expect(res80.status).toBe("YELLOW");
      expect(res80.blocked).toBe(false);
      expect(res80.usedPercent).toBe(80);
      expect(res80.remaining).toBe(200);

      // 95% spend
      const res95 = computeStatus(1000, 950);
      expect(res95.status).toBe("YELLOW");
      expect(res95.blocked).toBe(false);
      expect(res95.remaining).toBe(50);
    });

    it("returns RED and blocked when spending exceeds limit", () => {
      // 101% spend
      const res = computeStatus(1000, 1050);
      expect(res.status).toBe("RED");
      expect(res.blocked).toBe(true);
      expect(res.usedPercent).toBe(105);
      expect(res.remaining).toBe(0); // remaining never goes negative
    });
  });
});
