# Scoped preservation provider read capacity

The original scoped preservation provider metadata and input readers exceeded
the EIP-170 runtime limit in the Provider131 native capture: 48,292 and 26,120
bytes respectively. Fixed compiler-linked workers now hold the original payload,
root, root-facts orchestration and configuration-pin bodies. The public nominal
types and complete return tuples stay on their original libraries.

The root-facts path retains scope and runtime checks, original snapshot record
validation, optional full current/lock validation, complete immutable payload,
factory reciprocity and the selected Router root in the original order. The
payload wrapper preserves the original caller-memory normalization; the root
worker returns all three modified fields. The pin worker still runs in the
calling provider's delegate context, including every self-provider comparison.
All original gas arguments, errors and canonical encoding checks remain.
The existing component library named `StreamFinalityScopedPreservationPolicyMetadataFactsV1`
is unchanged; the new orchestration library has the distinct `MetadataRootFactsV1`
suffix.

The final six-product native capture uses Solidity 0.8.19, via IR, optimizer 200,
Paris, no CBOR and no metadata hash. Runtime / creation-template bytes are:

| Product suffix | Runtime | Creation |
| --- | ---: | ---: |
| ProviderMetadataV1 | 22,590 | 22,623 |
| ProviderReadsV1 | 14,538 | 14,570 |
| MetadataRootFactsV1 | 13,833 | 13,865 |
| MetadataPayloadV1 | 9,758 | 9,790 |
| MetadataRootV1 | 12,169 | 12,201 |
| ProviderPinsV1 | 12,332 | 12,364 |

All six are libraries with no constructor arguments. All 27 original ABI
entries remain exact and all six storage layouts are empty. The preservation
proof compares 35 original/moved function bodies; native metadata source hashes
and every emitted compiler link slot are checked against the captured source.

Seven focused tests are authored and typechecked. They exercise both preservation
families, complete payload/root tuples, every root-binding word, error precedence,
delegate-host reciprocity, exact restoration, and the original metadata entrypoint's
historical/current branch. Snapshot, Router, factory, membership and inventory
responses are explicitly typed boundaries with exact calldata/caller checks.
These tests have not been executed in this source handoff.

Added delegate frames and complete tuple copies still require actual composed
gas measurement. This selected size result does not establish an actual governed
publication, sanction/finality ceremony, cold-read budget or whole-scope transaction
capacity. Existing 24,576/49,152-byte production limits and transaction budgets
remain unchanged. Earlier failed and intermediate captures remain source-qualified
historical evidence; only the final six-product capture names the adopted workers.
