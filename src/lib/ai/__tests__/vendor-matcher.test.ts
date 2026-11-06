import { describe, it, expect } from "vitest";
import { levenshteinDistance } from "../vendor-matcher";

describe("Vendor matcher algorithms", () => {
  describe("levenshteinDistance", () => {
    it("returns 0 for identical strings", () => {
      expect(levenshteinDistance("Amazon Web Services", "Amazon Web Services")).toBe(0);
      expect(levenshteinDistance("", "")).toBe(0);
    });

    it("detects single-character insertion, deletion, and substitution", () => {
      expect(levenshteinDistance("Google", "Gooogle")).toBe(1); // insertion
      expect(levenshteinDistance("Google", "Googl")).toBe(1);   // deletion
      expect(levenshteinDistance("Google", "Googke")).toBe(1);  // substitution
    });

    it("calculates edit distance for fuzzy vendor names", () => {
      expect(levenshteinDistance("Microsoft", "Micro soft")).toBe(1);
      expect(levenshteinDistance("GitHub Inc", "Github Inc")).toBe(1);
      expect(levenshteinDistance("Stripe", "Strpe")).toBe(1);
    });

    it("returns correct distance when one string is empty", () => {
      expect(levenshteinDistance("", "Apple")).toBe(5);
      expect(levenshteinDistance("Apple", "")).toBe(5);
    });
  });
});

