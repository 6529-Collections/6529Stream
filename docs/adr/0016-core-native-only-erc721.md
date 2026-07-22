# ADR 0016: Core-Native-Only ERC-721 Launch Line

## Status

Accepted for the pre-genesis production target on 2026-07-22 after the Core
interface red-team review. This ADR supersedes ADR 0015 decisions W3, W4, and
W5 for the launch Core. ADR 0015 decisions W1 and W2 remain in force: the
collection-identity reads/JSON signal and marketplace-commitment gate are not
weakened.

## Problem

ADR 0015 attempted to preserve a dormant per-collection facade option inside
the shared launch Core. For an `EXTERNAL_FACADE` token, Core would continue to
store and return the owner through `ownerOf`, include the token in `balanceOf`
and supply, and advertise ERC-721 through ERC-165, while deliberately rejecting
Core's standard approval and transfer entries and substituting a private
controlled-mutation event for Core's `Transfer` event.

ERC-721 conformance is contract-wide, not selectable per token. A contract that
advertises ERC-721 and exposes an owned token cannot turn off the standard
approval/transfer behavior or omit `Transfer` when that ownership changes. A
facade-side `Transfer` does not repair the Core contract's nonconformance. The
dormant mode would also spend permanent Core bytecode and storage branches on a
first-of-kind path that is not deployed at genesis.

## Decision

1. The launch Core is `CORE_NATIVE` only. Every Core token follows the same
   ERC-721 ownership, approval, transfer, safe-transfer, mint-event, and
   burn-event semantics for the life of this deployment line.
2. The target Core ABI contains no identity-mode or transfer-controller state
   or mutation surface. The pre-genesis target removes
   `collectionIdentityMode`, `collectionTransferController`,
   `declareCollectionIdentityMode`, `registerCollectionTransferController`,
   and `controlledOwnershipChange`.
3. The target event surface removes `CollectionIdentityModeDeclared`,
   `CollectionTransferControllerRegistered`, and
   `ControlledOwnershipChanged`. Core emits the standard ERC-721 `Transfer`
   event for every mint, transfer, and burn.
4. The facade profile is successor-line research, not a deployable extension
   of the launch Core. Any future address-per-collection design requires a new
   accepted ADR and threat model. It must choose a standards-conformant asset
   model explicitly—for example a custody/wrapper model with two explicit
   assets, or a new Core line—rather than presenting one state-authoritative
   token as two selectively conformant ERC-721 contracts.
5. ADR 0015's W1 collection-identity signal remains Permanent. W2 remains a
   release-evidence gate. Failure to secure the required marketplace/indexer
   commitments is a go/no-go and risk-acceptance decision; it no longer
   activates dormant launch-Core ownership machinery.
6. This is an intentional pre-genesis MAJOR cutover. No production token or
   collection used the removed surfaces. The permanent-interface manifest,
   selector/event goldens, conformance matrix, deployment profile, release
   artifacts, and implementation must all agree before a release candidate.

## Alternatives Rejected

- Emit Core `Transfer` while retaining the controller-only path: insufficient,
  because Core's standard approval and transfer entries would still be closed
  for an advertised ERC-721 token.
- Keep both Core-native and facade mutation paths live: creates two approval,
  transfer, safe-receiver, and marketplace identity surfaces for one ownership
  record and defeats the single-authority premise.
- Custody-wrapper facade in the launch line: potentially standards-conformant,
  but it creates two explicit asset identities and needs a fresh product,
  finality, royalty, sale, export, and threat-model decision. It is not a
  dormant readiness hook.

## Security And Bytecode Impact

The change removes an unaudited standing ownership authority, an external
callback from Core ownership mutation, per-token mode branches across mint,
transfer, approval, and burn, and five functions/three events from the target
interface. It therefore both restores ERC-721 conformance and contributes real
Core headroom. The exact runtime saving remains implementation-measured; this
ADR does not count source deletions as bytecode evidence.

## Test Plan

- `supportsInterface` advertises ERC-721 and every allocated Core token obeys
  the standard approval, transfer, safe-transfer, mint-event, and burn-event
  behavior.
- Target-interface validation proves all five facade-readiness functions and
  three events are absent.
- Repository-wide ABI/call-graph checks find no launch dependency on an
  identity-mode or controlled-mutation selector.
- Full state export and event replay use the single Core `Transfer` stream.
- The marketplace collection-identity signal and W2 evidence gate remain
  covered independently.

## Rollout

Apply this decision in the permanent-interface lock before any target Core
implementation. Mark the prior facade profile as successor-line research,
remove facade-readiness rows from launch gates and manifests, and keep W1/W2
collection identity work intact.
