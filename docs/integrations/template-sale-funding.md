# Template funding in native and ERC20 sales

The current fixed-price adapters accept the supported explicit collection
`PRIMARY_SALE` template profile described in [artist template economics](artist-template-economics.md).
They resolve a concrete profile, register it through the actual factory, and
fund its verified wallet or escrow the exact amount before mint completion.
This closes the sale-side materialization path; actual artist consent admission
and current-Core deployment composition still require their corresponding
integration evidence. The domain tests use explicit artist/Core/manager seams.

## Signatures and stale quotes

Native version 2 and the ERC20 sale/PaymentIntent ABI and domains are unchanged.
`profileId` always means a concrete immutable split profile, never a template ID.
The canonical `expectedPrimaryPolicyHash` includes the actual template ID,
concrete profile, predicted wallet and full assignment hash:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_PRIMARY_POLICY_V1"), block.chainid,
    address(resolver), keccak256("PRIMARY_SALE"), collectionId, uint256(0),
    templateId, profileId, wallet, assignmentHash
))
```

For fixed profiles, `templateId` remains zero and the previous policy preimage
is unchanged. `primaryPolicy` previews the current concrete template rights.
The resolver's `previewCollectionPrimaryProfile(templateId, collectionId,
salePoster)` uses the same derivation as materialization but makes no factory
writes. Previewing an address does not register a profile or prove deployment.
The sale adapter supplies a zero poster: this initial economics profile accepts
dynamic COLLECTION_ARTIST entries and static nonartist entries, not SALE_POSTER
or paid collaborator sources.

A lawful payout revision before execution changes the current concrete profile
and invalidates an outstanding strict quote. Native creator/platform signatures
must be refreshed. An immutable ERC20 sale configuration with the old policy
must be replaced by a newly registered sale and fresh authorizations/intents.
The artist's immutable template economics consent remains separate: a lawful
payout revision does not itself require that consent to be recorded again.
There is no permissive drift fallback.

## One payout moment and atomic funding

Commercial authority and the manager's operation-root preview precede effects.
ERC20 payer intent is verified before template registration or any token pull.
The adapter then materializes once and checks its exact profile, wallet and
entry hash against the earlier preview and signed commitment. Every
COLLECTION_ARTIST entry uses that materialization call's one explicit payout
observation. The adapter never substitutes the authority address.

Materialization registers the profile with deployment deferred. If its wallet
is already verified and deployed, the ordinary governed deposit attempt runs.
If the canonical predicted address is empty, no native/token deposit is sent
there: the admitted producer credits escrow with template-origin evidence.
A fixed assignment with an empty wallet, an unknown profile, a mismatched
prediction or unexpected code cannot use that path. The internal template flag
comes only from the actual validated resolver assignment, never caller input.

After payment callbacks, the adapters check current provider/artist binding,
assignment identity and ACTIVE asset status while retaining the materialized
profile. A callback that records a later lawful payout designation cannot
redirect this execution. It changes future previews instead. Wrong provider or
assignment state, rejected mint recipient, operation mismatch, token accounting
failure or escrow failure rolls the entire transaction back, including a
first registration, payer intent nonce and official proceeds. Existing escrow
credits and old wallets keep their original payees.

The source `SaleRevenueFunded` event, including schema version 1 and exact
operation/authorization identities, is emitted only after successful mint.
Its concrete profile links the public materialization event to official revenue;
a public cache event alone is not a sale. Passive funds at a predicted address
are excluded from official proceeds and escrow debt. After permissionless
deployment/flush they join ordinary cumulative wallet receipts.

## Evidence and limits

`StreamTemplateSaleFundingTest` covers native and ERC20 escrow before mint,
actual factory deployment/flush and wallet payouts, retained donations,
predeployed direct funding, invalid intent before registration, stale quote
rejection, callback payout/pointer changes, wrong-code and fixed-empty rejection,
recipient rollback/retry, explicit Safe execution/threshold intent and Safe
payouts. The existing fixed funding tests run alongside it, including independent
fixed policy/V2 digest reconstruction and callback/replay failures. These are
source-bound isolated tests, not fully cold gas or full-current integration.

The factory's WALLET_DEPOSIT_GAS_LIMIT still governs token pulls, transfers,
approvals and balance reads. Materialization uses the resolver's separate
ARTIST_BENEFICIARY_READ_GAS. All outer transaction budgets must accommodate the
actual registration/deployment/flush work; fixture values are planning values.
No constructor configuration was added in this extension.

This increment does not migrate template auctions: their settlement-time payout
semantics need a separate authorization design. Fixed auctions retain their
creation-time concrete rights. It also does not implement universal contract
20/9 settlement orchestration, permits, paid collaborator templates, template
prospective replacement, royalty templates or token-scope prepared settlement.
The bounded combined adapter decision and proposed ADR-0019 status remain as
stated in [sale funding](sale-funding.md).
