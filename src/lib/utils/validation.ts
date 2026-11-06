/**
 * Cross-validates numeric amount against words extracted from an invoice/receipt.
 */
export function isAmountValid(num: number, words: string): boolean {
  if (!words || num === 0) return true;
  const lowerWords = words.toLowerCase();
  const numStr = Math.floor(num).toString();

  // Check if the actual digits exist in the text
  const digitsInText = words.replace(/[^0-9]/g, "");
  if (digitsInText.includes(numStr)) return true;

  // Fallback: Check for at least ONE magnitude word if the number is large (>100)
  // This is a rough heuristic to avoid flagging everything
  const bigWords = ["million", "thousand", "hundred", "lakh", "crore"];
  if (num >= 100) {
    return bigWords.some((word) => lowerWords.includes(word));
  }

  // For small numbers or no digits found, we assume valid to avoid false positives unless we have better logic
  return true;
}

