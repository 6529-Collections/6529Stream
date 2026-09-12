# ADR 0028: Reveal-fee custody and role activation

## Status

Accepted for the undeployed full-v1 implementation on 12 September 2026.
This records the implementation boundary for EC-REVEAL. It does not declare
the complete entropy lifecycle or a new release candidate finished.

## Problem

Refund-window sales must read a declared collection fee and fund the coordinator
that actually registered their token. A missing declaration cannot mean zero.
Collection funding and a requester's excess payment have different owners and
must remain independently withdrawable and solvent.

The coordinator previously had no collection reveal-fee account. Its provider
quote accepted request context, so a synthetic context or provider-family label
could not establish a collection-wide fee. Its general configuration authority
also did not provide the current operational role checks required by EC-REVEAL.

## Decision

Keep the sale-facing read/fund surface in `IStreamRevealFeeEscrow` and the three
administrative calls and five normative events in `IStreamRevealPolicyAdmin`.
The coordinator holds the funds. Registration requires an explicit policy;
policy promises lock at first token or scope registration, or collection freeze.
The operational fee can change afterward without rewriting those promises.

Providers may advertise `IStreamEntropyProviderFeeQuote`. Its single getter
promises the same quote as every request context in the same provider state.
ARRNG and VRF use the same implementation for both quote methods. Admission
still needs source and dependency review: ERC-165 alone cannot prove the promise.
Policy configuration requires this capability and exactly one ABI word in its
return. Missing, reverting and malformed quotes fail. Provider replacement
revalidates a previously declared fee against the replacement's live quote.

For token requests, let `q` be the actual request quote and `e` the collection
balance. Draw `min(e, q)` from that collection; the caller supplies the rest.
Only excess caller value becomes the caller's existing pull credit. Scope
requests remain entirely caller-funded. Provider failure or a duplicate request
ID rolls back both ledgers and the request. Top-ups, historical completions and
withdrawals do not require the provider's quote service to be available.

Count every registered token as an unfinished obligation. The first FINALIZED,
STALE or FAILED transition removes it. Duplicate callbacks cannot remove it
again. A burned registration remains unfinished until a supported entropy
terminal transition occurs; burning does not invent a settlement event. Residual
escrow is withdrawable only when that collection has no unfinished tokens, and
only to the uniquely resolved current `ROLE_TREASURY` holder.

New administration checks the live `ROLE_ENTROPY_ADMIN` membership of the calling
contract. The constructor pins the RoleRegistry and its code. Each check follows
Core's canonical ModuleRegistry to its Executor, verifies that Executor still
selects the pinned RoleRegistry, and verifies registry ownership. A Safe acts as
the principal; its individual signers do not inherit its role. This changes the
coordinator constructor ABI for new deployments. Existing deployed coordinators
and their release evidence remain unchanged.

## Deployment and resumption

The initial deployment planner joins artist activation and the three reveal
grants in one five-call, delayed, root-proposed batch. It carries the exact
global role-mutation chain through the artist grant and subsequent reveal
grants. The Manager gas change does not mutate that chain. An existing modular
deployment may instead prepare the three reveal grants from confirmed current
state. Neither path uses a genesis role exception.

The fixed grant plan requires an empty reveal-owner and treasury role. It is
not a role-rotation tool. Execution and resumption require those roles to resolve
uniquely to the saved principals; administrators may be multiple. Every resumed
plan still authenticates its exact calls and stored action commitment. The
administrator declares the collection policy after activation and before
registration. Default development deployment uses a controller-owned contract
actor; Safe deployments use their selected Safe principals and exact CALL data.

## Alternatives and release impact

A synthetic provider quote, a family allowlist and a hardcoded zero quote were
rejected because none establishes the required context-independent price.
Combining escrow with requester credit would obscure ownership. A separate
custodian would add a second routing and reconciliation boundary without a
needed product capability. The coordinator still fits the deployed-code limit
in both compiler profiles.

The 44-case domain suite and both production profiles received independent
review. Tests cover real Safe calls, exact events, accounting fuzzing, callback
rollback, historical coordinator obligations, terminal counts, failed-payment
retry and typed-quote parity. Actual current-stack role/deployment composition
and the planner's distinct regression tests have their own acceptance results.
New client exports, constructor records and final release artifacts must be
generated from the completed integration, not reused from RC1.

## Remaining lifecycle work

This increment stores the request mode and SLO promise. Automatic AT_MINT
attempts, the governed SLO and permissionless fallback, the complete recovery
lifecycle and legacy entropy administration's EC-ROLES migration remain separate
implementation work. Existing collection/provider configuration and terminal
administration retain their Executor authority path in this increment.
