# Current burn-redemption acceptance source

Base: `00a89d8c648f86028f2002e1572ca7668e06ea5e`.
Branch: `codex/current-burn-redemption`.

## Required profile and scope

The feature register records `sales.burn-redeem` as source-built, with 17 scoped
tests passing at their retained source. Those tests use typed Core identity,
registry and governance boundaries. The remaining required profile is execution
with the actual current components and operator/governance principals.

This batch authors that distinct current-stack host under SSA-REDEEM rules 1–3
and SSA-BURN rule 1. It does not add a new redemption implementation or alter the
original hash domains, event schemas, approval rules, record semantics or gas
parameters. The shared fixture and production sources remain unchanged.

The host uses the real Core, Manager, Ledger, Artist suite, module registry and
Governance Executor. Source tokens are minted through the actual Manager.
Separate official threshold Safes act as holder, operator and governor. The
inherited external entropy service remains a test boundary. Source code is
not evidence of a passing current-stack execution.

## Original semantic boundaries

- Caller authority and the redemption host's ERC-721 approval are separate.
  Neither a fulfillment operator nor an individual Safe signer gains token
  authority merely by holding that role.
- Kind 9 registration commits the original immutable terms before use. A
  redemption burns the existing token and retains its collection and serial;
  it does not mint, charge a price or create a revenue settlement.
- Fulfillment updates append operator assertions. They preserve the original
  redemption and do not prove physical delivery.
- Cancellation stops new redemption but permits fulfillment of an existing
  record. Eligible pre-deprecation programs can continue under the original
  registry policy. Incident revocation blocks both redemption and fulfillment
  mutations while retaining historical reads and cancellation.
- A genuine Core burn block provides a late burn-refusal rollback oracle. It
  does not establish artwork-finality or frozen-manifest acceptance. An early
  missing-approval Safe retry must not be described as a late Core failure.

## Authored cases

The new host contains 12 distinct tests:

1. Actual delayed Safe admission, original kind-9 configuration, canonical
   redemption/Core events, retained identity and unchanged allocation high-water marks.
2. Independent redemption caller and host approvals.
3. Token-specific and blanket approval combinations.
4. Exact committed terms and nonzero fulfillment references, with retry.
5. Byte-identical signed Safe retry after repairing the host approval.
6. Pre-burn and cross-program duplicate rejection.
7. Inclusive start/end times, expiry and later fulfillment.
8. Cancellation with unchanged original redemption and append-only fulfillment.
9. Pre-deprecation program continuity with new registration rejected.
10. Incident revocation refusing redemption and fulfillment while retaining history.
11. Actual terminal Core burn-block rejection with record/index rollback.
12. Operator-only configuration, cancellation and fulfillment.

The registry and Core transition hashes are independently constructed from
original domains and state. Governance executes real delayed actions. A direct
Safe-address prank in the late-failure case is only a diagnostic for the wrapped
Core error; the case also executes the actual signed threshold Safe envelope and
checks unchanged Safe nonce and state. No artwork-finality record is fabricated.

## Delivery and validation boundary

The integrator owns the next combined native cohort, native graph preparation,
complete deployment fit, gas and full-v1/testnet acceptance. This host stays
outside the frozen current47 cohort and the earlier Content35 capture.
Only source review, ABI compilation and normal documentation/format checks are
part of this authored batch unless separately recorded below.

The dedicated ERC20 burn nonzero-native-fee extension remains held separately.
The shared ADR 0045 implementation explicitly preserves its zero-value callback;
this batch does not infer broader approval or apply any held artifact.

## Source validation

Independent review is clear for the complete 12-case host at SHA256
`f2288eb2e2c299c97ae1ddd95aec948a755d2fb9a5b47b0f349cb28a5d56ab57`.
The lifecycle tests retain the actual mandatory status-plus-manifest publication
batch, original module transition hashes and manifest revision advance. The late
burn refusal checks exactly two actual zero-value Core burn calls across the
diagnostic call and real threshold Safe transaction. Constructor URI, original
event layout, fresh fixture clocks and saved Safe envelope semantics were checked.

The final ABI-only capture covers 1,293 sources with zero errors:
`artifacts/art27-gap3/current-burn-redemption-v2`.
Input SHA256:
`6aa5470fd88f7753b9b4015507c71f5aec4876afeb124a012ad23576dff39a84`.
Output SHA256:
`0536fd97891ce5d82ea2bc86591a26fe88ef456523cb85a060ee8751466621d2`.
Scoped Solidity formatting, 17 Markdown-checker tests, link/changelog checks and
Windows-aware whitespace checks pass. Production and shared fixture sources
are unchanged. No native code generation or runtime execution was performed for
this batch; the earlier 17-case typed cohort retains its separate evidence.
