# STATIC renderer versions and context producer

`StreamRendererRegistry` records immutable versions using the exact manifest and
request fields in [Renderer Responsibilities](../metadata-router-and-renderer.md#renderer-responsibilities).
`StreamRenderContextV1` provides the pure context/shell encoder. These are producer
components of the selectable STATIC route. This batch does **not** turn the existing
linked-library Router into a conformant STATIC route, select a genesis renderer,
or demonstrate a current-Core renderer call. Source and focused ABI checks exist;
the fourteen authored tests, runtime size, and full routing integration remain pending.

## Registration and evidence

Deploy the registry with the canonical Executor, its actual SchemaRegistry, a
sorted immutable array of named read targets, and host-owned dependency/golden
call gas parameters. Each target pins its address, runtime hash and declared
role. The closed roles are Core, CollectionMetadata, named Metadata companion,
DependencyRegistry, and EntropyCoordinator. Deployment review must identify each
actual source and its role; a role label does not prove the target implements
that role. In particular, OwnerRecords cannot be labeled as a companion to evade
the MARKETPLACE firewall. Extending the genesis target set requires another
explicit registry deployment, not a mutable allowlist edit.

A version is keyed by the renderer family ID and version under
`6529STREAM_RENDERER_VERSION_V1`. The registry saves:

- The exact `RendererManifest`, renderer address and runtime hash.
- Sorted unique `(targetIndex, selector)` reads, each with exact or maximum ABI
  returndata size. The read-set commitment includes the entire immutable target set.
- Active registered schema, context and manifest document IDs. The emitted schema
  and renderer manifest hashes must match their actual registered document bytes;
  the context document ID must equal `contextVersion`.
- An exact ABI-encoded `Analysis` CATALOG and `GoldenVector[]` CATALOG. Their
  complete bytes are read from the pinned SchemaRegistry and checked against its
  actual immutable document length/hash before decoding. Neither an arbitrary
  URI nor a nonzero evidence hash is sufficient.

The analysis report must use `6529STREAM_STATIC_RENDERER_ANALYSIS_ABI_V1` and bind
this runtime, read-set hash, renderer version, context version and output-schema
hash. It preserves the reporting tool and findings commitments. This is the
registered publisher's analysis assertion: Solidity cannot establish arbitrary
program reachability from that report. The genuine opcode/read-set static gate
and its source/tool identity remain mandatory release admission evidence. The
synthetic reports in unit recipes test joins and refusals; they are not reports
of a performed opcode check.

The registry actually calls every supplied golden request and compares the exact
returned URI bytes with its saved expected hash. There must be 1–16 vectors, all
inside the bounded 8 KiB catalog. Those checks establish the supplied vectors only;
release tooling must supply the complete required golden inventory, including
pending/frozen/burned, large IDs, opaque token data and exact script handling.
The renderer's size hints do not override Core's own output limits.

Registration uses class 1 and verifies the original six-field Executor context
against the exact per-version scope and old/new state preimages. Deprecation uses
class 0, is one-way, and closes new mutable assignment only. The original manifest
and all evidence/read declarations remain readable. `requireRetained` continues
to return the original runtime after deprecation or later schema retirement.
Runtime drift is terminal. There is no removal, incident-disable, repointing,
reactivation or recovery shortcut in this producer. Actual finalized-reference
accounting and its Finality consumer integration remain part of the routing batch;
the absence of a removal path must not be described as such accounting.

## Bounded calls and saved configuration

`StreamRendererCalls` compiles internally into its caller. It uses `STATICCALL`
with zero initial returndata copy; failed and oversized returns are never copied.
A fixed outer reserve clips the requested host-governed cap on nested calls.
Canonical ABI is checked before manifest, catalog or URI acceptance. Per-version
read declarations describe the registering renderer's own calls; they do not
silently configure another host's gas parameters. The initial gas values/floors
in the test fixture are test inputs, not measured conformance floors.

All registry state transitions and enumeration are independent of the original
Metadata, Artist, Core, and finality storage. A version record supplies neither
Artist content consent nor a selected rendering config. The planned Router
consumer must join the exact registry runtime/version and original op17/21
family, freeze, consumed-authorization and finality boundaries before assignment.

## STREAM_CONTEXT_V1

The internal pure encoder emits the normative documented key order. IDs and the
saved chain ID are decimal strings; Core token data stays an exact lowercase hex
string, always present and never parsed. Pending contexts omit hash/seed; optional
zero references/provider addresses are omitted. A supplied view name must match
its exact view ID (the zero default is MARKETPLACE). Invalid supply, status or
entropy enum values are rejected.

JSON escaping retains Unicode bytes, escapes controls/quotes/backslashes and
makes `<` plus U+2028/U+2029 safe for a script element. Callers must validate the
UTF-8 of source text before encoding. The JSON context carries the original
unescaped dependency program as a JSON string; executable dependency and artist
script elements separately escape case-insensitive closing-script prefixes.
The shell publishes the context first and declares exactly the four fixed
compatibility names: `stream`, `hash`, `tokenId`, and `tokenData`.

The encoder accepts source facts; it does not authenticate them. Its exact-byte
unit golden and additional controls remain authored, not executed. The real
renderer must supply original Core/entropy and selected Metadata facts under the
version's pinned read set, and keep default compact output distinct from full
executable/reconstruction output.
