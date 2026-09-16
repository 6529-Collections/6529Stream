# Exact primary-template CLEAR and FREEZE

`CurrentRevenueClient.quote` supports `primary-template-clear` and
`primary-template-freeze` at collection scope `1n` and token scope `2n`.
The intent must name the exact currently installed `templateId` as well as its
collection and scope coordinates. Default/global and inherited freezes are
outside these recipes. No production Solidity changes are required.

```typescript
const plan = await client.quote(provider, artistSafe, {
  kind: "primary-template-clear", // or "primary-template-freeze"
  collectionId, scope: 2n, scopeId: tokenId, templateId,
});
const approval = client.prepareArtistApproval(plan, { nonce, deadline, signature: "0x" });
await client.assertApprovalDigest(provider, approval, artistSafe);
await client.simulate(provider, approval);
const artistCall = toSafeCall(approval.call);
// Submit through the Artist Safe, verify its exact ExecutionSuccess and receipt.
await client.assertApproved(provider, plan);
const installation = plan.ownerCall; // actual Resolver owner, possibly GovernanceExecutor
// Schedule/execute installation.call through that owner's actual authority path.
await client.assertInstalled(provider, plan, artistSafe);
```

The runnable [current-revenue-safe example](../examples/current-revenue-safe.mjs)
accepts these intent kinds, keeps reviewed authorization bytes for failed-call
retry, and verifies the original Artist digest. For relayed authorization, use
the actual relayer as `caller`, the Artist's signature bytes, and its actual
transaction receipt. Never turn a GovernanceExecutor owner address into a
pretend Safe caller; follow its scheduling/action workflow.

| Mutation | Artist call before owner mutation | Signed result | Owner call |
| --- | --- | --- | --- |
| CLEAR | `recordProspectiveEconomicsConsent` with zero fixed candidate | Zero exact-key assignment hash | `clearPrimaryAssignment` |
| FREEZE | `recordProspectiveTemplateFreezeConsent` | Current exact template hash with `frozen=true` | `freezePrimaryAssignment` |

Both use the original `StreamArtistEconomicsConsent` EIP-712 message and facade
domain. The supplemental collection context is checked separately onchain.
The client requires an accepted Artist for this approval recipe; it does not
fabricate Artist-zero consent for PLATFORM_WORKS. Registry authority, payout,
collaborator, nonce, replay and deadline admission still apply when the real
call executes. Original denied global/inherited freeze work is unaffected.

## What the quote checks

At one pinned block, the quote checks chain, code, Core bindings and the selected
Artist facade, then reads the exact installed assignment. It requires a mutable
TEMPLATE key, zero fixed profile/policy fields and the reviewed template ID.
`primaryTemplateAssignmentHash` independently reconstructs the Solidity
`StreamPrimaryAssignmentHash` preimage from the observed factory, asset policy,
wallet runtime hash, template entries/metadata, scope and frozen flag.

CLEAR reads immutable `primaryTemplate` hashes. It intentionally does not
require the old template's beneficiaries to remain usable after a corrected
Artist binding: removal is a supported recovery path. The clear preview must
return that exact previous hash and a zero result. Postcondition checking
requires that the exact key no longer exists; inherited effective economics may
still resolve to a nonzero assignment and are not the clear result.

FREEZE reads current template beneficiary facts and includes any dynamic
beneficiary witness in the freshness fingerprint. It checks previous and frozen
previews against independent reconstruction. A changed collaborator/payout
witness requires fresh review even when the template assignment hash is stable.
The installed result must contain the same template, frozen flag and approved
hash. This freezes the exact assignment only.

Call `assertFresh` before authorization submission and before owner execution.
No quote reserves chain state. Once the owner mutation has succeeded, its old
quote will naturally be stale; use `assertInstalled` for confirmation instead.
The [Safe plan guide](safe-call-plans.md) explains call ordering and the separate
Safe-envelope nonce needed after a failed target execution.

## Evidence and catalog boundary

The updated revenue fixture was generated from successful Solidity 0.8.19 ABI
output bound to `0d7c1b57` (relevant production source unchanged at `738314e6`).
It records exact compiler input/output/source hashes and adds the existing
prospective-freeze selector and two factory getters. Older selected catalogs
without `recordProspectiveTemplateFreezeConsent` fail closed at preparation.
Use the generator with your exact successful compiler input/output for a newer
deployment; retained RC1 generated bindings remain unchanged.

Client tests cover ABI encoding, zero clearing, independent preimages, stale
witnesses, malformed readbacks and corrected-binding removal with synthetic RPC
boundaries. They do not execute contracts or establish current full-graph/Safe
runtime acceptance. The normative homes remain
[revenue economics](../../../docs/revenue-splits-and-royalties.md) and
[Artist authority](../../../docs/stream-artist-authority.md), with
[ADR 0034](../../../docs/adr/0034-economics-consent-binding-associations.md)
governing binding associations.
