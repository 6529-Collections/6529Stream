# Bounded exact-source VIEW checkpoint reads

`StreamViewCheckpointServingV2` is a supplemental read-only product for the
[tagged policy VIEW profile](tagged-policy-view-v2.md). It provides exact JSON
and HTML observations for a later onchain checkpoint. It is not a checkpoint,
archived execution, snapshot, reference publication, or finality acceptance.
The original Router methods and `FULL_VIEW_GAS = 60000000` remain unchanged.

## Deployment and bindings

Deploy and link the fixed `StreamViewCheckpointReadsV2` worker, then construct
the adapter with this closed six-word binding:

```solidity
Binding {
    address core;
    bytes32 coreCodeHash;
    address router;
    bytes32 routerCodeHash;
    uint256 chainId;
    uint32 rendererGas;
}
```

The constructor requires the actual selected Router, its immutable original
Core, both runtime hashes and the deployment chain. `rendererGas` is between
50,000 and 14,000,000. This is a new adapter-specific ceiling, not a change to
the Router's limits or proof that every admitted output fits a transaction.
The adapter also retains the fixed compiler-linked worker's actual runtime.
There are no binding setters. `workerBinding()` returns that target and hash.

`configurationHash()` is the Keccak of the canonical ABI encoding of
`keccak256("6529STREAM_VIEW_CHECKPOINT_SERVING_V2")`, deployment chain, adapter
address, complete Binding, fixed worker address and retained worker hash.
A consuming checkpoint must independently pin the actual adapter runtime and
this configuration; a claimed output or caller-provided binding is insufficient.
The adapter advertises `IStreamViewCheckpointServingV2` and ERC165. It does not
occupy or replace one of the canonical genesis roles.

## Reads and original semantics

`currentOutput(scope, tokenId, mode)` returns the current adoption record and
its exact output. It accepts a canonical full VIEW scope with nonzero
collection and membership ID and zero token coordinate. The returned retained
scope must match all four requested coordinates. `historicalOutput(record,
tokenId, mode)` returns the authenticated retained scope and output. Both
accept only mode 2, JSON, or mode 3, HTML. Both are closed to the V2 tag; zero/V1,
unknown tags and unknown records refuse. Original V1 checkpoint support remains
a separate required profile, never an implicit payload cast.

The fixed worker preserves the existing RoutingV2 serving predicates and
RenderRequest. Its explicit Router comes only from the host's constructor
binding. The retained Store carrier, complete canonical record and V2 tag/hash,
source preimage, renderer/version, source set, full policy binding and complete
scope membership are checked as before. Current reads also require the original
current declaration and selected source roster. Historical reads retain the
original version eligibility rules; deprecation is not silently treated as a
new-assignment check. Live Artist attribution remains live.

Actual original token identity, permanent serial, completed/burned lifecycle
and coordinator-at-mint remain mandatory. Current burned output refuses;
historical burned output retains the original identity. Actual status 5 and
terminal statuses 1/2 remain distinct. The actual Renderer independently checks
the complete retained full policy or explicit legacy branch, seed/request
semantics, payload and tokenData. No invented token or finalized seed is used.

The worker reads the original Router's actual `BUNDLE_READ_GAS`. It then makes
the identical renderer call under the adapter's bounded renderer cap, retaining
the original full-cap/EIP150 admission and 262,208-byte ABI / 262,144-byte string
limits. The only execution-budget substitution is this renderer cap in place
of the full-view facade's remaining gas. No authority, cached currentness,
storage mutation, arbitrary target or caller-supplied output is introduced.

## Evidence boundary

The source/type capture has 93 sources. The focused native successor passes all
nine cases. They use the actual adapter, Store, State, Renderer and both fixed routing paths,
with explicit typed Core/factory/set/Coordinator/Artist/Registry responses.
The tests compare all four Router-style output methods and an independently
assembled RenderRequest; cover exact current burned refusal and historical
identity; full-scope and tag substitution; replacement/declaration/source
drift; terminal/finalized/legacy separation; constructor/runtime pins and
restoration. A separate test cools the fixture's actual dependency accounts
and payload carriers and includes calldata intrinsic gas in the original
16,777,216 envelope. That passing test demonstrates only this typed fixture. Its cooled JSON call
uses 1,166,412 gas plus 22,252 calldata intrinsic (1,188,664 total); HTML uses
896,742 plus 22,252 (918,994 total). The measurement includes external call and
return overhead, excludes construction/setup, and is not an actual governed
current-stack transaction.

The retained inverse proof compares the new worker to the immutable original
RoutingV2 body. Its substitutions are the explicit pinned Router, returned
authenticated record/scope, and bounded renderer cap; a formatter-added pair
of braces does not change a predicate. Original Router/Routing/Renderer source
is unchanged. Selected native sizes are 3,068 runtime / 4,937 creation bytes for
the adapter and 10,865 / 10,897 for the worker. All fifteen emitted nonempty
production libraries fit; actual embedded Renderer and adapter construction
returns 20,988 and 3,068 runtime bytes respectively.

The first native capture is retained as eight passes and one failed oracle.
The unknown-tag getter correctly rejected the tag and the bounded reader wrapped
that refusal as `ViewAdoptionRead`; the test had expected bare
`InvalidViewAdoption`. The sole test correction now requires the exact original
wrapped error. Zero-tag rejection still requires the bare error. The successor
keeps all 93 production/source inputs except that test, original compiler/settings,
original production bytecode and all limits. Fresh original-artifact verification
plus strict new native output comparison authenticate the cached artifacts; the
nine EVM tests invoke no compiler and leave source/artifacts unchanged. There is
no merged compiler output, production rewrite, or runtime-equivalence exception.

These results cover the finite actual adapter/Store/State/Renderer with the typed
surrounding dependency graph. Governed renderer admission, original Artist op17
ceremony and complete current-stack/finality acceptance remain separate.

The later checkpoint must bind each output observation to the same exact
adoption/source/membership/policy context and refresh it before sealing. JSON
and HTML may require separate authenticated stages. Repeated browser execution,
archive byte closure, actual scoped snapshot/reference/inventory and the
provider's VIEW finality continuation remain required independent work.
