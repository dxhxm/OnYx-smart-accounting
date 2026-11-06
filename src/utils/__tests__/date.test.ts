import { describe, it, expect } from "vitest";
import { parseISODateOnly, isoDateOnly, parseISOMonth, addDaysUTC } from "../date";

describe("date utils", () => {
  describe("parseISODateOnly", () => {
    it("parses valid YYYY-MM-DD into UTC midnight Date", () => {
      const dt = parseISODateOnly("2024-03-15");
      expect(dt.toISOString()).toBe("2024-03-15T00:00:00.000Z");
      expect(dt.getUTCFullYear()).toBe(2024);
      expect(dt.getUTCMonth()).toBe(2); // 0-indexed: March
      expect(dt.getUTCDate()).toBe(15);
    });

    it("throws an error for non-YYYY-MM-DD format", () => {
      expect(() => parseISODateOnly("15-03-2024")).toThrow("Invalid date format. Use YYYY-MM-DD");
      expect(() => parseISODateOnly("2024/03/15")).toThrow("Invalid date format. Use YYYY-MM-DD");
      expect(() => parseISODateOnly("invalid")).toThrow("Invalid date format. Use YYYY-MM-DD");
    });
  });

  describe("isoDateOnly", () => {
    it("formats Date instance to YYYY-MM-DD string", () => {
      const dt = new Date(Date.UTC(2024, 0, 5, 14, 30, 0));
      expect(isoDateOnly(dt)).toBe("2024-01-05");
    });
  });

  describe("parseISOMonth", () => {
    it("correctly parses month boundaries and leap year days", () => {
      // 2024 is a leap year (February has 29 days)
      const feb2024 = parseISOMonth("2024-02");
      expect(feb2024.start.toISOString()).toBe("2024-02-01T00:00:00.000Z");
      expect(feb2024.end.toISOString()).toBe("2024-03-01T00:00:00.000Z");
      expect(feb2024.daysInMonth).toBe(29);

      // Non-leap February
      const feb2023 = parseISOMonth("2023-02");
      expect(feb2023.daysInMonth).toBe(28);

      // 31-day month
      const jan = parseISOMonth("2024-01");
      expect(jan.daysInMonth).toBe(31);
    });

    it("throws error for invalid month format", () => {
      expect(() => parseISOMonth("2024-2")).toThrow("Invalid month format. Use YYYY-MM");
      expect(() => parseISOMonth("2024/02")).toThrow("Invalid month format. Use YYYY-MM");
    });
  });

  describe("addDaysUTC", () => {
    it("adds days forward and crosses month/year boundaries", () => {
      const base = new Date(Date.UTC(2024, 1, 28)); // Feb 28, 2024 (leap year)
      const nextDay = addDaysUTC(base, 1);
      expect(isoDateOnly(nextDay)).toBe("2024-02-29");

      const twoDays = addDaysUTC(base, 2);
      expect(isoDateOnly(twoDays)).toBe("2024-03-01");

      const yearEnd = new Date(Date.UTC(2024, 11, 31)); // Dec 31, 2024
      const newYear = addDaysUTC(yearEnd, 1);
      expect(isoDateOnly(newYear)).toBe("2025-01-01");
    });

    it("handles negative days (subtraction)", () => {
      const base = new Date(Date.UTC(2024, 2, 1)); // Mar 1, 2024
      const prevDay = addDaysUTC(base, -1);
      expect(isoDateOnly(prevDay)).toBe("2024-02-29");
    });
  });
});

