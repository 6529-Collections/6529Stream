# Router evidence provider

`StreamFinalityRouterEvidenceProvider` derives six serving components from the
actual, constructor-fixed `StreamMetadataRouter`. It is a concrete serving base
for the developing full typed provider. Entropy, the ten finality input
references, complete discovery and finality execution remain separate work.
Its ERC-165 declarations expose only the implemented serving and binding reads.

## Construction and calls

Construct with `(core, metadataHost, metadataRouter, scopeMembershipHost,
readGas, sourceGas)`. Each source must already have code and the expected
reciprocal Core/metadata binding. Addresses, runtime hashes and deployment chain
are immutable. `componentHost(family)` returns the fixed Router for the six
supported families and rejects other keys. The membership getters identify the
same fixed scope authority that the complete provider and historical Router
must share.

The provider reads the actual Router's module version and module manifest hash
once during construction. It copies the manifest's 96-byte ABI header, checks
the URI's encoded length, and retains the hash. It does not copy the informational
URI into provider memory or invent a 2,048-byte universal URI bound. The explicit
construction read budget still limits the amount of host work it can admit.

`finalityComponentFacts(family, scope)` checks fixed runtimes and validates the
scope through `requireScopeMembership`. It then returns the actual frozen flag,
module version, manifest hash and data commitment. It does not call an adapter,
another provider, or a routed `tokenURI`.

| Family | Committed source | Frozen condition |
| --- | --- | --- |
| `METADATA_ROUTER` | Exact name/description hashes, mode, configured flag and retained artist presentation | Configured, display locked and artist presentation locked |
| `MEDIA_MANIFEST` | Original image and animation-base URI hashes | Both explicit media and base-URI locks |
| `SCRIPT_SOURCE` | Original script hash and byte length | Explicit script lock |
| `RENDERER` | Actual linked renderer address and current runtime hash | Immutable dependency assignment and renderer code present |
| `RENDER_CONTEXT` | Exact accepted presentation/context profile | Fixed supported context profile |
| `DEPENDENCY_SOURCE` | Exact accepted no-external-read profile | Fixed supported dependency profile |

Each data hash is `keccak256(abi.encode(domain, chainId, core, router, family,
scope, payloadHash))`, using domain `6529STREAM_ROUTER_COMPONENT_EVIDENCE_V1`.
The source specifies each payload's exact ABI preimage. A mutable collection
inventory head is not part of a Router source commitment. Scope completeness is
validated separately; this does not create a historical membership cache.

Changing one source family leaves unrelated families' commitments unchanged.
In particular, missing renderer code changes renderer evidence without making
media, script or retained display unreadable. Core's collection freeze never
substitutes for an explicit metadata lock. A profile name alone does not prove
arbitrary code deterministic: these profiles apply to the admitted, pinned
Router implementation.

## New candidates and original history

`requireCurrentRouterCandidate(collectionId, registry)` is a separate admission
gate. It checks the actual Core-selected Router, generic metadata and Finality
Registry against the live ModuleRegistry's eligibility, then joins the Registry's
Core, metadata, provider, provider runtime and sanction source. The Router must
have a locked artist presentation and its saved original-Finality anchor must
match that exact Registry and runtime. A later eligible Registry cannot adopt
an older Router's saved history merely by becoming the current pointer.

These checks occur after the deployment graph is complete. The constructor does
not read the not-yet-deployed Coordinator, demand collection locks or require
current product pointers. Historical component reads retain original fixed
sources independently of current pointer eligibility. They still require the
fixed source runtimes and the scope authority's applicable validation; they are
not a promise to survive every dependency failure.

## Evidence and limits

Eighteen focused tests pass in both compiler modes, including 256 scope fuzz
inputs. They use the actual Router, linked renderer, provider, specialized
serving adapters and threshold Safe. Core, generic metadata, membership, artist,
Finality and ModuleRegistry are explicit fixtures in this cohort. Checks include
all six families, independent preimages, scope fuzzing, changed runtime rejection,
candidate-anchor mismatch, current eligibility changes, all supported provider
selectors through Safe, and maximum Router source fields with a long module URI.
Safe transactions establish call compatibility; their internal return bytes are
not decoded as part of those transactions.

The test profile uses 500,000 gas for small reads and 2,000,000 for source and
outer membership reads. Those limits are distinct because the membership host
has its own nested reads. The maximum-source measurement uses 1,328,267 gas in
default compilation and 1,337,443 via IR. It cools the Router, Core, metadata and
membership contracts, not every linked library account. Adapter consumption
uses uncapped caller gas; it does not establish the Registry or companion's
governed component budget. Complete
actual scope-host composition, whole frozen Core serving under its aggregate gas
limit, full Safe acceptance and complete finality evidence remain required.

See [the typed-provider decision](../adr/0041-typed-finality-evidence-provider.md)
and [active delivery](../../ops/V1_DELIVERY.md) for the remaining scope.
