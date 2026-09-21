# Full-policy provider read dispatch capacity repair

The original full-policy V2 provider exceeded EIP-170 at 31,070 runtime bytes in the recorded current-assembly capture. Its policy read branches now execute in the compiler-linked `StreamFinalityFullPolicyDispatchV2` worker using the provider's original typed storage contexts. Constructor validation, profile precedence, original Registry-first prepared guards, metadata attribution and inherited fallback behavior remain in their original order. No write path, read budget or evidence predicate is removed.

The worker is an additional fixed deployment/link dependency. Link the provider to its genuine deployed worker and link that worker to its compiler-declared dependencies. It accepts no caller-selected worker target. Existing constructor arguments, 71 ABI entries and six recursive storage roots remain equal to the prior provider.

The raw dispatcher and terminal return helpers are external-entry plumbing: they forward the original `msg.data` and return the complete original ABI envelope. The current inheritance hierarchy has no cross-selector internal caller of these methods. New internal callers must not treat these methods as ordinary reusable Solidity subroutines; they must use typed worker methods or make an explicit external call.

## Recorded validation

The selected native 0.8.19 build uses the existing via-IR optimizer-200 Paris profile with no CBOR or metadata hash. The provider is 22,588 runtime bytes and 34,958 creation-template bytes; its complete static constructor tuple is 3,520 bytes, giving 38,478 initcode bytes. The new worker is 15,512 runtime and 15,544 creation bytes. Both satisfy the unchanged 24,576/49,152-byte product limits. Metadata source hashes and every compiler-declared link slot were checked against the captured input. These are selected-product size results, not deployment or execution results.

Six authored, typechecked parity cases cover complete binding/catalogue bytes, two compiler-owned storage roots, external calldata/caller transport, preserved leaf read ceilings, exact refusal order and restoration, and scope fuzzing. They execute the actual fixed worker against explicitly seeded contexts and a typed Router boundary. The fallback sentinel and copied Registry guard isolate transport; they do not establish the complete original provider, policy-positive evidence, current finality or sanction ceremony. Native execution of those six cases and the actual retrieval ceremony remains separate.

The saved actual retrieval measurement still targets the distinct 6m checkpoint / 7m Witness / 8m Bundle test configuration. Original diagnostic defaults, production limits and the 16,777,216 transaction ceiling remain unchanged; the additional worker frame requires measured gas acceptance in the actual graph.
