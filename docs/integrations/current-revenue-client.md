# Current revenue setup and Artist Safe approval

`packages/stream-client/src/current-revenue.ts` prepares the existing Resolver and Artist calls for token/collection PROFILE overrides, configured-zero royalties, collection/default royalty snapshots, and primary templates. It uses caller-selected compiled ABIs. The retained generated contract catalog is unchanged. All setup calls carry zero native value and Safe operation `CALL` (`0`); this module has no signer or broadcaster.

## Compile and select the actual ABI

Run the existing client build from `packages/stream-client` with `npm run build`. Supply the ABI of the actual current Primary Resolver, Royalty Resolver, Artist facade, Core pointers and Mint Manager as `{ primary, royalty, artist, core, manager }` to `CurrentRevenueClient`. The focused fixture generator accepts explicit Solidity input/output files:

```text
node scripts/generate-current-revenue-fixture.mjs INPUT.json OUTPUT.json --check
```

The checked fixture records its compiler inputs, source hashes and original preimage literals. It is an encoding oracle, not a deployed-address list or an execution capture. A deployment must supply its own verified addresses, network and selected compiled interfaces. The RPC remains a trust boundary.

## One complete approval and installation sequence

1. Select the actual transaction caller. For a direct Artist Safe call this is the accepted Artist Safe. A relayer uses its own address and carries the Artist's original EOA/1271 signature. `quote` pins one block, reads code and actual Core/Artist bindings, requests the original candidate preview, and records the complete existing assignment key. A token ID always stays `bigint`; the contract validates its actual collection.
2. Call `assertFresh`, then `prepareArtistApproval`. Compare its original digest through `assertApprovalDigest` and simulate from that exact caller. `toSafeCall(approval.call)` preserves the zero value, target and calldata. Submit through the independently operated Safe. The op15 domain, field order, nonce and deadline remain unchanged. Empty signature requires the actual accepted Artist caller.
3. Check the exact Safe `ExecutionSuccess` using the independently known Safe transaction hash, then `assertApproved`. This admission read uses the Resolver as `eth_call.from`, matching the existing contract caller check. It submits no transaction and grants no ability to sign as that Resolver.
4. The quoted `ownerCall` is a **separate owner operation**, usually a delayed GovernanceExecutor action. Feed its target/data/value into the existing governed stage-plan flow. An Artist Safe approval does not confer Resolver ownership. Simulate this owner call only when its original execution context and prerequisites are available. After execution call `assertInstalled` against the original observed plan.

The exact-key readback proves that assignment's installed hash; it does not prove every token's effective precedence or a subsequent sale. The actual commerce entrypoints retain current consent, payout, policy and callback checks. Changed state requires a new reviewed quote. A failed unchanged Safe call can retry the original authorization and byte-identical call after the failing prerequisite is repaired; a successful nonce must never be reused. `assertFresh` compares the original caller, current Artist, code, election and complete prior key and refuses to silently regenerate terms.

The runnable read-only recipe is `packages/stream-client/examples/current-revenue-safe.mjs`. Its RPC provider disables caching so repeated preparation and retry reads request fresh observations. Its exported preparation/retry/confirmation functions retain the immutable plan in an application session. The CLI prints a proposal and requires a fresh preparation before submission; it is not a durable resumable journal. After restarting an application, quote again and review any revision/hash changes instead of treating parsed JSON as an authenticated plan.

```powershell
$env:STREAM_RPC_URL = '<your read-only RPC URL>'
node examples/current-revenue-safe.mjs revenue-config.json selected-revenue-abi.json
```

Example `revenue-config.json` for a token override (replace addresses, profile, nonce and deadline with the actual current facts):

```json
{
  "chainId": "31337",
  "addresses": {
    "core": "0x0000000000000000000000000000000000000001",
    "artist": "0x0000000000000000000000000000000000000002",
    "primary": "0x0000000000000000000000000000000000000003",
    "royalty": "0x0000000000000000000000000000000000000004",
    "manager": "0x0000000000000000000000000000000000000005"
  },
  "caller": "0x0000000000000000000000000000000000000006",
  "intent": {
    "kind": "primary-profile", "collectionId": "7", "scope": "2",
    "scopeId": "9007199254740993",
    "profileId": "0x1111111111111111111111111111111111111111111111111111111111111111"
  },
  "authorization": { "nonce": "0", "deadline": "1900000000", "signature": "0x" }
}
```

These are illustrative coordinates; no transaction has been executed against them. Never coerce identifiers, amounts, shares, nonces or deadlines through JavaScript `number`.

## Configured-zero and inherited snapshot royalties

Use `royalty-set` with a zero profile and `royaltyBps: 0n` for a configured-disabled SET. It has a nonzero assignment hash and differs from a missing key or CLEAR. Positive profiles require nonzero basis points up to 1000. The old token > collection > default precedence remains; a configured-disabled collection suppresses a positive default.

Before the first mint, prepare the existing owner-only `election(owner, collectionId, 2n)` and execute it through the existing governed route. For a new collection source, quote its `royalty-set` after election: the helper selects the existing prospective mode-bound preview and original op15, followed by the separate collection SET. A mode2 token mutation is refused.

For an inherited default, install scope0/id0 via governance first. The helper deliberately prepares **no global Artist royalty approval** for that mutation. Each consuming collection then quotes `snapshot-current`, signs the original current op15 over scope1/that collection and its election, and checks the current source. The source's original default assignment stays scope0/id0, including configured-zero or a frozen default. The collection approval wraps that raw hash; neither collection can reuse another's wrapper. Default drift or freeze requires fresh consent and phase authorization. A collection override still takes precedence.

After consent/source admission succeeds, `snapshotPhase` reads the exact current source and returns the owner-only `registerPhaseRoyaltyPolicy` call, its full policy and Manager `phaseRoyaltyConfigHash`. Supply the actual application's configuration hash and a new phase ID, execute policy registration before the original phase registration, then use the returned wrapped configuration hash where the existing prepared-mint route requires it. The policy distinguishes `expectedModeAssignmentHash` from `expectedSourceRoyaltyPolicyHash`. This helper does not configure or open an auction itself. Use the existing custody/native auction helpers with the resulting policy and original sale authorization. Already frozen token disclosures remain separate from new mint admission.

## Dynamic poster and collaborator templates

Start with the original accepted binding, current primary payout, every accepted collaborator row and that collaborator's current payout designation. Build references from the **original row account, exact bytes32 role (zero is valid), and share-label ID**. `primaryCollaboratorSource` reconstructs the canonical source hash; do not hash a rotated payout or signing authority instead.

Call `previewTemplateRegistration(provider, actualOwner, entries, metadataHash, references)`. It validates the template grammar, simulates the actual owner call and independently reconstructs the canonical sorted entries hash/template ID. Submit `registration.ownerCall` using the owner governance route. `assertTemplateRegistered` reads all saved canonical rows and metadata after execution, including an idempotent registration that emitted no new event. Use the resulting `templateId` in `primary-template` with scope1 collection, scope2 token, or scope0 default. Default TEMPLATE op15 remains a collection-specific interpretation of the original scoped payload; it grants no global mutation authority.

Every template totals 1,000,000 ppm, has at most 64 entries and at most eight dynamic sources. Artist + poster leaves at most six distinct collaborator sources. Each declared collaborator source must have its own entry, even when rows share a label or payout. Dynamic collaborator grammar requires the positive `COLLECTION_ARTIST` / `artist` entry and forbids static/poster substitution for artist or paid labels. Static templates and original strict routes remain available.

The original template op15 approves symbolic `SALE_POSTER` allocation. It has **no poster argument**. Pass the original signed auction poster explicitly to `previewMaterialization` / `materialize`; never substitute a later executor. Read current profile/wallet/entries and beneficiary witness immediately before use. The Resolver resolves current designations, verifies actual row coverage and consent, and the commerce route repeats its materialization/funding checks. Payout rotation can change the concrete profile without rewriting the original source identities or signing domain. Installing a template does not itself settle a sale.

This Artist recipe refuses fabricated Artist0 consent. Declaration-aware PLATFORM_WORKS commerce, old custody activation families, existing signing helpers and owner controls remain in their respective contract/client workflows. This batch introduces no CLEAR/FREEZE mutation, payment change or new signing schema.

## Validation boundary

Focused tests use selected compiler ABIs, literal original Solidity hash declarations, synthetic RPC responses and actual client/Safe encoders. They cover exact hashes, full-width integers, current-state drift, malformed responses, wrong callers, registration readback, canonical zero/default distinctions and original row/poster identity. These client tests do not execute new Solidity or claim live deployment, gas conformance or full current-stack native acceptance. Root's separate frozen native campaign owns that evidence.
