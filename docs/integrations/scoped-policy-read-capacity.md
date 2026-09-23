# Scoped full-policy provider read capacity

The distinct V2 scoped full-policy metadata and input readers exceeded the
24,576-byte runtime limit: 28,114 and 25,981 bytes in the retained native
capture. Fixed compiler-linked payload, selected-root and configuration-pin
workers now hold the original bodies. The existing public library names,
nominal types, complete return tuples and 21 ABI entries are unchanged.

The metadata reader still validates scope, original snapshot, optional current
state, dependency runtimes, complete payload, factory reciprocity and selected
root in that order. Its payload wrapper retains the original caller-memory
normalization. The root worker returns all three changed fields, including the
complete 23-word V2 binding. The pin worker retains every dependency and
self-provider comparison in the calling provider's delegate context. No
publication authority, storage layout, read cap, hash preimage or schema changes.

This profile uses its original full-policy source and dynamic policy rows. It
does not select a preservation-family branch or reinterpret preserved V1 data.
The separate [preservation readers](scoped-preservation-read-capacity.md) retain
their existing implementation.

Seven regression cases cover nonempty dynamic policy payloads, complete root
returns, every binding word, future timestamps, error precedence, dependency
restoration, alternate delegate hosts, and the original historical/current
metadata branches. Typed dependency boundaries authenticate exact calldata and
caller identity; they do not model actual governance or publication authority.
The cases are authored and typechecked; runtime execution remains pending.

The selected native capture uses Solidity 0.8.19, via IR, optimizer 200, Paris,
no CBOR and no metadata hash. All five products have empty storage layouts and
no constructor arguments, so creation-template size is complete-init size.

| Product suffix | Runtime bytes | Complete-init bytes |
| --- | ---: | ---: |
| ProviderMetadataV2 | 20,668 | 20,700 |
| ProviderReadsV2 | 14,469 | 14,501 |
| MetadataPayloadV2 | 9,311 | 9,343 |
| MetadataRootV2 | 11,212 | 11,244 |
| ProviderPinsV2 | 12,286 | 12,318 |

The 93-source capture retains native ASTs, ABI, metadata, storage layout, method
identifiers, creation/runtime bytecode, link references and immutable references
for all five selected products. Readback verifies 348 metadata/source joins,
34 emitted link slots and unchanged captured source bytes. The source proof
compares 31 original function bodies and checks the three explicit wrappers.
The existing `StreamFinalityScopedPolicyMetadataFactsV2` component is unchanged.

Additional delegate frames and full tuple copies require composed gas measurement.
Neither source equivalence nor selected size evidence establishes whole-scope
finality, cold-read gas capacity, production readiness or audit completion.
Production runtime and complete-init limits remain 24,576 and 49,152 bytes.
