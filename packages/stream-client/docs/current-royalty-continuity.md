# Current royalty economic continuity caller

`CurrentRoyaltyContinuityClient` prepares the pending current-stack Royalty Resolver continuity workflow from canonical source commit `49364823b9e537a33896346b67639e523b4f31d1`. It does not sign, send, deploy, mutate Core, or claim that the separately owned Core pointer guard has been exercised.

## What capture proves

Construct the client with the actual chain, selected source Resolver, pristine candidate Resolver, Core, split Factory, canonical governance authority, and caller-selected compiler ABIs. `capture(provider, uri, limits, blockTag)` then:

- pins the source, candidate, Core, Factory, and authority runtime hashes at one block;
- requires Core's current `ROYALTY_RESOLVER` pointer to identify that exact source runtime;
- verifies both Resolver constructor identities, the immutable canonical governance authority marker, continuity interface support, and source readiness;
- rejects EIP-7702 delegated authority code, because the contract's canonical authority predicate rejects it;
- reads no more than the explicit route and election bounds, with a hard client ceiling of 4,096 for each inventory;
- preserves each row's first `hashOrigin`, full frozen configuration, immutable mode election, and complete mint snapshot;
- independently reconstructs ordered route/election roots, the header commitment, frozen-state commitment, canonical manifest bytes, manifest hash, and class-1 begin transition; and
- compares the independent transition with `previewEconomicContinuity` on the actual candidate.

The output includes `canonicalManifest`, the exact ABI bytes emitted by a successful begin, so an operator can save the reviewed artifact without rebuilding an internal tuple schema. Public preimage functions require exact tuple fields, booleans, addresses, byte widths, and `bigint` integers; they do not accept ethers-style numeric coercion.

The target contract validates Factory wallet/profile rows and Core collection/token identity while importing. The client records the actual Factory and Core runtimes and simulates the exact CALL, but capture does not independently enumerate those Factory profiles or Core identities. A successful controlled-RPC test is not native contract execution evidence.

## Calls and authority

`begin(plan)` returns the exact candidate target CALL and identifies its required caller, the canonical governance authority contract. The plan's `transition` is the class-1 scope/old/new tuple that must be scheduled and executed through that authority's normal governance workflow. Sending the target call directly from an owner Safe cannot succeed. `safeCall` and ordinary `simulate` therefore reject begin actions; the latter would lack the authority's live executing `currentAction` context. No helper fabricates that context.

After begin executes, `next(provider, plan, caller, chunk)` reinspects runtimes, current Core source selection, both Resolver identities, the canonical authority, source header, candidate state, and saved manifest. It returns:

- an `importEconomicContinuity(maxRoutes,maxElections)` CALL bounded to at most 16 routes and 64 elections;
- `completeEconomicContinuity()` only after both exact cursors reach the saved counts; or
- a completed observation after live `supportsEconomicContinuity(source,frozenStateHash,manifestHash)` succeeds.

The import and completion calls are permissionless, so their supplied `caller` is retained for simulation. A chunk that cannot advance the currently pending elections or routes is rejected. For these calls, `safeCall(action)` produces Safe operation `CALL` (`0`) with decimal value `"0"`; it accepts only actions issued by that client instance. `simulate` uses the same caller, target, value, and calldata.

Every continuation rejects runtime drift, owner/authority changes, a different Core source pointer, a changed source header, another saved source/manifest, cursor overflow, or a stale candidate. Before begin it repeats the exact preview, which also catches otherwise-hidden mutable candidate configuration.

Continuity commonly needs several transactions, so a process restart must not depend on an in-memory plan brand. Save `royaltyContinuityEvidenceJSON(plan)` from the example. A new process passes that text through `parseRoyaltyContinuityPlanJSON` and then `client.restore(provider, parsed)`. Restore bounds JSON size, bigint token width, arrays, and URI/manifest bytes; rejects unknown tuple fields; independently reconstructs every route/election/header/root/manifest/transition commitment; verifies the saved capture block, all five historical runtime pins, the historical Core pointer, both Resolver identities, canonical authority, source header, and pristine preview; and finally performs a fresh live inspection. It returns a newly branded immutable plan only after all checks succeed. It supports pristine, importing, ready-to-complete, and completed candidates.

## Scope limits

Only producer-enumerated frozen default/collection/token routes, full immutable token snapshots, and explicit immutable collection-mode elections are copied. Mutable unfrozen configuration is not migrated. Assignment and policy hashes retain their original Resolver address through multi-hop handoffs; future writes use the new Resolver's origin.

`phase: "completed"` means the candidate reports the exact live Resolver continuity capability while Core still selects the source. The observation deliberately includes `coreStillUsesSource: true`. There is no cutover helper until the separate guarded Core replacement is integrated and demonstrated.

The compiler fixture is generated from an explicitly selected successful standard-JSON input/output pair:

```sh
node scripts/generate-current-royalty-continuity-fixture.mjs INPUT.json OUTPUT.json
node scripts/generate-current-royalty-continuity-fixture.mjs INPUT.json OUTPUT.json --check
```

It accepts only the reviewed ABI-14 compiler input/output SHA-256 pair, then records those digests, exact relevant source hashes, and the canonical source commit. A different successful build is rejected rather than mislabeled. This qualifies encoding only; it is not deployment, native-runtime, Core-cutover, audit, or release evidence.
