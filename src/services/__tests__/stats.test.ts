import { describe, it, expect } from "vitest";
import { extractConfidenceAvg } from "../stats";

describe("Stats Service Helper Logic", () => {
  describe("extractConfidenceAvg", () => {
    it("returns null for non-object or null input", () => {
      expect(extractConfidenceAvg(null)).toBeNull();
      expect(extractConfidenceAvg(undefined)).toBeNull();
      expect(extractConfidenceAvg("string")).toBeNull();
      expect(extractConfidenceAvg(123)).toBeNull();
      expect(extractConfidenceAvg([])).toBeNull();
    });

    it("extracts and averages flat confidence score map (0-1 scale converted to 0-100)", () => {
      const scores = {
        vendor_name: 0.9,
        invoice_date: 0.8,
        total_amount: 1.0,
      };
      // Avg: (0.9 + 0.8 + 1.0) / 3 = 0.9 -> scaled: 90
      expect(extractConfidenceAvg(scores)).toBe(90);
    });

    it("correctly handles nested intelligence.confidence_score structure", () => {
      const payload = {
        intelligence: {
          confidence_score: {
            date: 0.85,
            amount: 0.95,
          },
        },
      };
      // Avg: (0.85 + 0.95) / 2 = 0.9 -> 90.0
      expect(extractConfidenceAvg(payload)).toBe(90);
    });

    it("preserves scores that are already on a 0-100 scale", () => {
      const scores = {
        item1: 85,
        item2: 95,
      };
      expect(extractConfidenceAvg(scores)).toBe(90);
    });

    it("parses numeric strings and ignores NaN / empty values", () => {
      const scores = {
        field1: "0.80",
        field2: 0.90,
        field3: "not_a_number",
      };
      // Valid values: 0.8, 0.9 -> Avg 0.85 -> 85
      expect(extractConfidenceAvg(scores)).toBe(85);
    });

    it("returns null if no numeric confidence values are found", () => {
      const empty = {};
      expect(extractConfidenceAvg(empty)).toBeNull();

      const nonNumeric = { a: "foo", b: null };
      expect(extractConfidenceAvg(nonNumeric)).toBeNull();
    });
  });
});

