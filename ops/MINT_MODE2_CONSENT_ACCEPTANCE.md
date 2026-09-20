# Mode-2 mint policy consent consumer

## Scope

This separate batch follows the frozen size repair `f401600e`. The original
ART42 producer could record mode-2 policy consent, but Manager registration
rejected every mode except 1 and 3 before reading that record. The only
production edit is the supported-mode guard in
[StreamMintArtistConsent](../smart-contracts/domains/mint/StreamMintArtistConsent.sol):
accept 1, 2 and 3; reject zero and unknown modes.

Modes 1 and 2 still require the exact nonzero record from `isPolicyConsented`
and a successful current `requireMintConsent` read. Core/Artist/Manager binding,
runtime pins, bounded reads and current prerequisites are unchanged. Mode 3
still requires its original capability and matching nonfuture immutable
platform declaration. No signature, record, grant, storage or public interface
changes. Revoked or exhausted grants cannot make new consent records; already
recorded consent retains the original durable semantics.

## Authored acceptance

The [new current suite](../test/current/StreamCurrentDelegatedMintGrace.t.sol)
uses actual Artist owners, facade, Coordinator, Archive, Core, Manager, Ledger,
ticket gate and delayed governance. Artist principal, delegate, ticket signer,
mint executor and Governor are distinct official threshold-two Safes. Only the
inherited external entropy service and deliberate delivery-failure recipient
are test boundaries. Both initial grace-phase registrations and later rotations
use the original delegated operation 14. The original record formula and
delegate class are reconstructed independently; Manager's exact consent event
retains mode 2 and that record.

Four cases cover:

1. Actual delegated initial registration and delayed grace rotation, followed
   by an unchanged previously signed predecessor ticket and exact Ledger receipts.
2. Revocation after recording but before Manager registration and minting.
   A new consent is denied while the original record still registers and mints.
3. Consent for a different prospective executor policy cannot authorize the
   requested rotation. The failed Governor action leaves Manager, Ledger,
   governance status and grant uses intact. Recording the exact policy permits
   the identical original signed Governor transaction.
4. Late second-recipient failure under grace rolls back both tokens,
   preparation, counters, roots, replay and Safe nonce. Revoking the grant and
   repairing the external recipient permits the identical signed batch using
   its existing records.

The inherited grace helper gains only a virtual policy-producer hook. Its
default still records the original principal consent, so existing mode-1
scenarios retain their inputs. The existing ART42 current suite remains owned
by its original author and is included in the combined type check.

The [focused boundary suite](../test/unit/mint/StreamMintArtistConsentModes.t.sol)
adds 11 cases using actual Manager and Ledger with an explicitly typed Artist authority.
It checks supported modes, exact-record and current-authority failures, and
the separate platform-declaration requirements. It does not claim actual
Artist authority implementation coverage; the current suite supplies that join.

## Validation boundary

The combined type/ABI capture is
`artifacts/native-assembly/counter-scopes/mint-mode2-combined-abi-1/`:

- 1,131 sources match the working checkout after newline normalization; no
  compiler errors. All 63 authored test ABIs are present: 11 new boundary and
  four new current cases, 28 existing grace/subject cases, and 20 existing
  ART42 unit/current cases. This is not execution of those tests.
- Input SHA-256:
  `6fb083c4e25e51db7f50248b8da6e0230efa6bb6bac7e48cccd0eca52afd100a`.
- Output SHA-256:
  `1cc9588883b0eff51303ebadbbfb4c3be326a78eb1cf306dc080c9c7af6032b5`.
- `mint-mode2-compatibility-1/result.json` compares the exact preceding size
  repair with the single changed production file. Manager, fallback and
  ArtistConsent ABIs match exactly (183, 185 and eight entries); both host
  layouts retain all 19 storage entries and recursive types. ArtistConsent
  still has no storage.

Independent source review found no blocker in the narrow production guard,
actual delegated producer/record formula, replay lanes, Governor/Safe retry,
mode-2 receipt or default direct-producer hook. The seven-suite ABI capture
uses Solidity 0.8.19, via IR, optimizer 200, Paris and no CBOR/hash metadata.

Native test execution, gas/fuzz checks, broad native/CI validation and release
evidence remain pending the coordinator's matched-source run. The preceding
`f401600e` size capture remains immutable evidence for that exact source; this
consumer change is not silently included in those measurements.
