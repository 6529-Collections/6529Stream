import { isHexString } from "ethers";

/** Equality of bytes32 values, independent of their hexadecimal letter case. */
export function sameHash(left, right) {
  if (!isHexString(left, 32) || !isHexString(right, 32)) throw Error("Expected a bytes32 hash");
  return left.toLowerCase() === right.toLowerCase();
}
