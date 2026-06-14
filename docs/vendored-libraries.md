# Vendored Libraries

This repository currently keeps a small set of OpenZeppelin utility libraries
under `smart-contracts/` instead of importing them from a package manager.
Vendored files are allowed only when their provenance, local deltas, and
static-analysis disposition are recorded here.

## Manifest

| Local file | Upstream source | Upstream SHA-256 | Local SHA-256 | Local delta |
| --- | --- | --- | --- | --- |
| `smart-contracts/Base64.sol` | [OpenZeppelin Contracts v4.7.0 `contracts/utils/Base64.sol`](https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.7.0/contracts/utils/Base64.sol) | `9FBD7A4462F54BBB6B0BD03231738E5F081A092E9A8FD789FB4D1AECA3758AEC` | `3735F85C6E229E85144FBB306CD46F83BCD6965DF4705A97D06AA22F2AB8261E` | Local pragma is `^0.8.19` instead of upstream `^0.8.0`; encoding logic is unchanged. |
| `smart-contracts/Math.sol` | [OpenZeppelin Contracts v4.8.0 `contracts/utils/math/Math.sol`](https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/utils/math/Math.sol) | `8059D642EC219D0B9B62FBC76912079529CF494CAC988ABE5E371F1168B29B0F` | `D684AE61F88D564DE2D0515BC6356D0972C3CF9421F185A862D30662B7E1AD21` | Local copy keeps equivalent arithmetic with formatting deltas, an added denominator-zero comment, an overflow revert string, and `1 << (result << 3)` instead of upstream `1 << (result * 8)`. The arithmetic result is unchanged; overflow revert data differs. |
| `smart-contracts/SignedMath.sol` | [OpenZeppelin Contracts v4.8.0 `contracts/utils/math/SignedMath.sol`](https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.8.0/contracts/utils/math/SignedMath.sol) | `420A5A5D8D94611A04B39D6CF5F02492552ED4257EA82ABA3C765B1AD52F77F6` | `AEECC7E5AD0F981B63B486E2F296BB12439CA6C500FA1E62C7471AD7F72CA429` | Content matches upstream except local file ending. |
| `smart-contracts/Strings.sol` | [OpenZeppelin Contracts v4.9.0 `contracts/utils/Strings.sol`](https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.0/contracts/utils/Strings.sol) | `CB2DF477077A5963AB50A52768CB74EC6F32177177A78611DDBBE2C07E2D36DE` | `FD2B96FEACEA647D67A888537B75C4673C4193F444FAAE892634E5FC11C922D2` | Local imports point at sibling files in `smart-contracts/`; code behavior is otherwise unchanged. |

## Slither Disposition

The current high/medium Slither findings against these libraries are treated as
false positives for `P0-LIB-001`:

- `incorrect-exp` in `Math.mulDiv(...)`: Solidity uses `^` for bitwise XOR, not
  exponentiation. The expression `(3 * denominator) ^ 2` is the OpenZeppelin
  modular-inverse seed used by the full-precision `mulDiv` algorithm.
- `divide-before-multiply` in `Math.mulDiv(...)`: the flagged operations are
  part of the OpenZeppelin 512-bit multiplication/division algorithm and are
  not lossy reorderable payment or accounting arithmetic.
- `divide-before-multiply` in `Base64.encode(...)`: the flagged length formula
  intentionally computes `4 * ceil(data.length / 3)` for Base64 output sizing;
  padding golden vectors cover the non-multiple-of-three cases.

Regression coverage lives in `test/StreamVendoredLibraries.t.sol` and covers
Base64 golden vectors, binary padding, `mulDiv` full-precision boundaries,
rounding-up behavior, overflow, and zero-denominator reverts.

## Verification Commands

Use these commands when updating a vendored file:

```powershell
Get-FileHash smart-contracts\Base64.sol -Algorithm SHA256
Get-FileHash smart-contracts\Math.sol -Algorithm SHA256
Get-FileHash smart-contracts\SignedMath.sol -Algorithm SHA256
Get-FileHash smart-contracts\Strings.sol -Algorithm SHA256
forge test --match-path test\StreamVendoredLibraries.t.sol -vvv
```

When a vendored file changes, update this manifest, rerun the focused
regressions, and refresh `ops/SLITHER_BASELINE.md` if static-analysis status or
counts change.

## Formatting

The scoped Solidity formatting gate intentionally defers provenance-sensitive
vendored files that already differ from upstream formatting. The deferred list
lives in `scripts/check_solidity_formatting.py`; new files must not be added to
that list without a focused provenance note. When retiring a deferred vendored
file, update this manifest, rerun `make fmt-check`, rerun the focused vendored
library regressions above, and refresh source-verification or release metadata
if source hashes change.
