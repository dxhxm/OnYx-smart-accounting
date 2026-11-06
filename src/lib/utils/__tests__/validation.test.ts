import { describe, it, expect } from "vitest";
import { isAmountValid } from "../validation";

describe("Document validation utilities", () => {
  describe("isAmountValid", () => {
    it("returns true when words text is empty or number is 0", () => {
      expect(isAmountValid(150, "")).toBe(true);
      expect(isAmountValid(0, "Fifty Dollars")).toBe(true);
    });

    it("returns true when digits appear in words text", () => {
      expect(isAmountValid(250, "Total: 250 USD")).toBe(true);
      expect(isAmountValid(1200.5, "Amount is 1200 dollars")).toBe(true);
    });

    it("validates large amounts (>= 100) using magnitude words", () => {
      expect(isAmountValid(5000, "Five thousand dollars only")).toBe(true);
      expect(isAmountValid(250, "Two hundred and fifty")).toBe(true);
      expect(isAmountValid(1000000, "One million euros")).toBe(true);
      expect(isAmountValid(200000, "Two lakh rupees")).toBe(true);
      expect(isAmountValid(50000000, "Five crore rupees")).toBe(true);
    });

    it("returns true for small numbers (< 100) by default to prevent false positives", () => {
      expect(isAmountValid(45, "Forty-five")).toBe(true);
      expect(isAmountValid(12, "Twelve")).toBe(true);
    });
  });
});

