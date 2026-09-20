# Typed native dossier joins

The V2 partial assembler replays concrete native readers against the original
source state of a verified [V1 partial assembly](museum-object-dossier.md).
It preserves that entire assembly unchanged under `base/`, retains every new
anchor, transcript and snapshot, and reports checked facts and unresolved
coverage separately. It does not emit full `OBJECT_DOSSIER_V1` conformance.

## Source adapters

| Kind | Reader | Scope |
| --- | --- | --- |
| `owner` | `OwnerCatalogSource` | All native/admitted types and complete history for one host and token. |
| `independent` | `IndependentCatalogSource` | All eight native types for one host and exact collection, or separate deployment scope `0`. |
| `ownership` | `OwnershipSource` | Complete bounded Core Transfer history reconciled with the token's source-block identity, lifecycle and owner. |
| `metadata` | `MetadataCatalogSource` | Native `recordTypeCount/At`, policies, complete generic record lanes and payload-pointer inventory for one host and nonzero collection. |
| `hosts` | `DossierHostsSource` | Every module in Core's current registry, plus its selected Metadata pointer, retaining all lifecycle statuses. |

The classes live in `tools.museum.owner_catalog_source`,
`independent_catalog_source`, `ownership_source`, `metadata_catalog_source`
and `dossier_hosts_source`. Each exposes `snapshot()` and `transcript()`, and
provides bounded capture/replay and profile-definition commands.

MetadataV1 scope `0` is a writer-grant scope, not a generic record scope.
Its native type catalog can be empty before types are admitted. The reader
retains all original subject hashes, historical receipts and schema-definition
commitments. It neither invents unknown token-subject preimages nor rechecks
today's writer permissions. Repeated content under different families retains
each record occurrence and native `(family, content hash)` pointer identity.
Typed script/media manifests and bundles remain separate native surfaces.

## Host and scope coverage

The host reader binds Core's registry and selected Metadata pointer, reads
the registry's complete append-only enumeration, and retains deprecated and
incident-revoked rows. Supported same-Core hosts yield explicit expected scopes:
owner token; independent deployment `0` and collection; Metadata collection.
Independent and Metadata head/count observations are compared with the
corresponding complete source snapshots. The owner reader supplies its own
event-derived type catalog because that host has no native type enumerator.

Unknown successor versions and changed runtimes remain unresolved rows. The
reader does not call a successor through an assumed V1 ABI. A selected Metadata
host outside the current registry remains visible. A foreign Core binding is
reported and excluded from this token's scope reads.

The registry is the set of modules registered through that registry instance.
It does not enumerate alternate historical registries or all compatible
unregistered deployments. Owner and independent writes do not require Core
selection or registry membership. Therefore even complete current-registry
coverage leaves the global applicable-host denominator unresolved. A missing
source is not an authenticated empty lane.

## Exact source agreement

`tools.museum.object_dossier_native` accepts only the five known reader kinds.
It reconstructs each snapshot using its retained transcript and compares the
exact result. Assertions inside a supplied snapshot cannot replace replay.

Every source must agree with the verified original chain, Core, block hash,
block number, timestamp, state root, environment and deployment-evidence hash.
Token, collection and observed serial/lifecycle/burn/owner facts are joined
where the reader observes them. Core runtime and all shared address pins must
agree, including the original capture's pins and dynamically read chunk/module
code. Identical RPC requests cannot return different results across retained
original evidence and new readers. Distinct legitimate schema/store addresses
keep their own bindings; the assembler does not force them into one registry.

Records are preserved by host, scope, record type, index and record hash.
The report references every original record and whole native lane, including
other-subject records that establish its denominator. A collection head is
never relabeled as a token-filtered head. Reused payload bytes do not merge
record occurrences.

Synthetic inputs retain `synthetic_only` status. Caller-admitted RPC inputs can
establish `verified_within_source_profile` facts, with complete registered-scope
coverage separately reported. These statuses do not assert genuine native
capture acceptance, consensus, legal title or full dossier completeness.

## Input and commands

The new input directory contains `inputs.json` and exactly the files it names
under `data/`. The canonical input envelope has these fields:

- `profile`: `STREAM_MUSEUM_OBJECT_DOSSIER_NATIVE_INPUTS_V1`
- `version`: `1`
- `disclosure`: `public`, an explicit caller declaration
- `sourceState`: exactly the original V1 manifest's source state
- `sources`: rows sorted by unique `id`

Each row has `id`, `kind`, `provenance`, `anchorPath`, `anchorHash`,
`transcriptPath`, `transcriptHash`, `snapshotPath` and `snapshotHash`. Paths are
relative to `data/`; hashes are external Keccak-256 commitments to exact bytes.
`provenance` is `synthetic_fixture` or explicit `trusted_rpc` admission. The
snapshot must replay with that same provenance. Repeated logical host/scope
sources, unknown fields, unsafe paths, extra files and inconsistent pins fail.
The caller also supplies the envelope's external commitment.

```powershell
python -m tools.museum.object_dossier_native_assembly build --base work/object-dossier-partial --base-hash <external-v1-manifest-hash> --native work/native-inputs --native-hash <external-input-hash> --output work/object-dossier-v2
python -m tools.museum.object_dossier_native_assembly verify work/object-dossier-v2 --manifest-hash <returned-v2-manifest-hash>
python -m tools.museum.object_dossier_native_assembly definitions --output schemas/museum/object-dossier --check
```

Verification reconstructs the original V1 assembly and every typed source, then
compares the complete V2 directory. Retained implementation files are inert
provenance, not executed reconstruction tools or a complete runtime archive.
V1 profiles, schema files, outputs and retained fixtures remain unchanged.

## Coordinated read-only capture recipe

`tools.museum.native_dossier_capture` captures the six minimum sources below,
replays their exact transcripts through the V2 assembler, and retains the plan,
result and unchanged V1 base. It takes an existing RPC endpoint through an
environment variable. It does not launch Anvil, deploy contracts, publish
records, fund accounts, select a latest block or manufacture runtime pins.

The Coordinator must first supply a current native product composition and
one actual RPC graph. A Foundry fixture backed by typed Core/Artist stand-ins
cannot supply this evidence. The smallest graph has one actual minted
token, one OwnerRecords host, one CollectionAttestations host, one MetadataV1
host and Core's registered module roster. The existing token flow already
publishes collection-scoped independent records. Owner and generic Metadata
catalogs may be authentically empty for this minimum reader exercise. Deployment
scope `0` may also be genuinely empty; the reader still captures all eight lanes.
To additionally exercise populated Owner and Metadata receipt paths, publish
one record through each host's real authorization path. Empty-catalogue capture
does not establish those positive write cases. Additional registered compatible
hosts require their own complete source rows.

Complete the writes **before** choosing a single final block. Generate a fresh
actual-token capture, retained fixture and V1 partial assembly at that block,
reusing the `CurrentTokenFixture` source path, then `token_fixture retain` and
`object_dossier build`. The existing token-capture CLI owns its own Anvil
process; do not invoke it alongside a coordinated running chain. The original
token capture needs its actual paid mint, Safe consent, semantic/media records,
original deployment evidence and six
Core source-block views. Its source state cannot be replaced with a newer block
in a JSON file. The capture hook must include owner/Metadata publications before
`CurrentTokenFixture.build_media` freezes its views and deployment evidence.
Keep the original typed-authority publications and export steps when extending
that hook; the existing retained base verifier depends on those original inputs.

The older publication helpers do not yet compose this complete recipe in one
call. `token_native_manifest.EXTENSIONS` only adds the two independent-host
products; OwnerRecords and its current dependency closure must be explicitly
pinned. `publish_owner_records` expects an already deployed host and a real
Safe owner, while `TokenMintFlowMixin` currently mints to an unlocked local EOA.
For the smallest populated-owner recipe, publish directly from that actual buyer;
transferring to a Safe would also require a versioned extension of the retained
token fixture, which currently checks that the final owner is the original buyer.
Use the owner record's empty optional URI or a valid content URI. The rights
helper deploys a separate partial Artist graph with an unfulfilled Coordinator
reservation: reuse its policy/grant/publication pattern against the token graph's
existing Metadata/Artist bindings instead of running its graph builder. These
constraints are addressed by the versioned populated recipe below. Its native
execution remains pending; the read-only runner does not perform the writes.

The current token flow registers/selects Metadata but does not register its
independent host or an OwnerRecords host. The new recipe has a registration-only
helper using `TokenGovernanceMixin._register_token_module`'s transition pattern
and the hosts' self-described module fields, without requiring separate
interface artifacts. Its plan builder derives the six anchors from the final
original capture and its reviewed deployment bindings.

For that graph, the Coordinator supplies these prerequisites:

| Input | Required evidence |
| --- | --- |
| Native composition | Exact compiler products and linked-library closure for the current Core, schema/store, Artist, module registry, MetadataV1, OwnerRecords and CollectionAttestations implementations, plus the existing actual mint/governance graph. Record the source revision and native input manifest SHA-256. The runner checks that manifest pin against original deployment evidence; the revision remains declared provenance, not a build-equivalence proof. |
| Host authorization | Actual Executor/Safe schema admissions, record policies, family-writer grants and any required Core selection. The actual NFT owner authorizes OwnerRecords. Independent publication retains its original signer, subject and nonce. Metadata scope is the nonzero collection, never writer-grant scope `0`. |
| Host membership | Register the relevant modules through the actual registry governance path. Retain Core's real MODULE_REGISTRY and selected COLLECTION_METADATA pointers. An independently supplied unregistered host may be read, but it does not expand the registry's completeness claim. |
| Runtime commitments | Externally reviewed host/Core/schema/store code hashes and Metadata's Artist registry pin. Preserve distinct dependencies per host. All shared-address pins must agree with the original base and each other. |
| Original state | Verified V1 manifest hash, exact chain/Core/token/collection/serial, block hash/number/timestamp/state root, environment and deployment-evidence Keccak-256 from the new original capture. |
| Historical RPC | `eth_chainId`, EIP-1898 `eth_call` and `eth_getCode` at the pinned hash, `eth_getBlockByHash(hash, false)` for every parent back to genesis, and `eth_getTransactionReceipt` for every transaction in every block, including failures. Headers must retain ordered transaction hashes; receipts must retain status and complete ordered logs. |
| Bounds | Final height at most 4095 (4096 blocks including genesis); each reader at most 100,000 calls and 64 MiB transcript; each RPC response at most 1 MiB; combined output at most the existing 96 MiB package bound. Bounds reject the capture rather than truncate it. |

A state dump that lacks the original headers and receipts does not meet the
historical RPC requirement. Keep the coordinated chain and its history available
until capture and offline verification finish. The runner has no dependency on
transaction-hint lists or `eth_getLogs` filtering for the history denominator.

### Plan and execution

Create a canonical UTF-8 JSON plan using `tools.museum.canonical.dumps`. Its
closed fields are `profile` (`STREAM_MUSEUM_NATIVE_DOSSIER_CAPTURE_PLAN_V1`),
`version` (`1`), `disclosure` (`public`), `baseManifestHash`, `sourceRevision`
(40 lowercase hexadecimal digits), `nativeInputManifestSha256` (64 lowercase
hexadecimal digits) and `sources`. The base hash pins the entire independently
verified original assembly. Commit the exact plan bytes externally with
Keccak-256 before running it. Endpoint URLs and credentials are not plan fields.

Each source row contains only `id`, `kind` and an inline `anchor` object. IDs use
ASCII letters/digits, `_` or `-` and must be unique and sorted. Use each reader's
documented anchor profile, with the common original state above:

| Minimum row | Kind | Anchor additions to the common state |
| --- | --- | --- |
| `hosts` | `hosts` | `coreRuntimeHash`, `tokenId`, `collectionId` |
| `independent-collection` | `independent` | `host`, `schemas`, `store`, `codePins`, `scopeKey` equal to collection |
| `independent-deployment` | `independent` | Same host/dependencies, `scopeKey: "0"` |
| `metadata` | `metadata` | `host`, `schemas`, `store`, `artistRegistry`, `codePins`, `collectionId` |
| `owner` | `owner` | `host`, `schemas`, `store`, `codePins`, `tokenId` |
| `ownership` | `ownership` | `coreRuntimeHash`, `tokenId`, `collectionId` |

Each `anchor` also includes its reader's `profile`. Common fields are `chainId`,
`core`, `blockHash`, `blockNumber`, `timestamp`, `stateRoot`, `environment` and
`deploymentEvidenceHash`. Each `codePins` entry is `{address, runtimeHash}`;
include every host dependency required by that reader. Decimal quantities are
strings. Include both scopes for **every** independent host in the plan.

```powershell
python -m tools.museum.native_dossier_capture check-plan --plan work/native-plan.json --plan-hash <external-plan-keccak256> --base work/new-v1-base
python -m tools.museum.native_dossier_capture capture --plan work/native-plan.json --plan-hash <external-plan-keccak256> --base work/new-v1-base --rpc-env STREAM_MUSEUM_RPC --output work/new-native-capture
python -m tools.museum.native_dossier_capture verify work/new-native-capture --result-hash <returned-result-keccak256>
```

`check-plan` is entirely offline. It validates all reader anchors and cross-source
pins before RPC, but does not check node availability. Capture requires all five
reader kinds, paired independent scopes and no duplicate logical source. The
completed assembly must cover every supported same-Core host/scope observed in
its roster; unsupported versions remain visible and unresolved. Add externally
reviewed anchors for any missing supported hosts and retry into a new output
directory. Supplied hosts outside the roster remain separately qualified.

The output contains `plan.json`, `result.json` and `assembly/`. Save the printed
result hash externally. `verify` checks the closed output, replays the base and
native sources offline, and reconstructs the result. The regular V2 verifier can
also inspect `assembly/` using the returned assembly manifest hash. No RPC URL
is retained. Successful execution checks source consistency; acceptance of the
actual deployed binaries and the positive publication recipe is a separate
review. The runner does not silently convert an empty lane into a positive record
case or assert global completeness.

## Versioned populated-token recipe

`tools.museum.current_token_dossier_capture` extends the original actual-token
flow with a separate recipe version. It preserves the existing source classes,
capture8 bytes, V1 retention format and V1/V2 assembly profiles. The new flow:

1. Admits an explicit, fresh `http://127.0.0.1:<port>` chain at chain ID 31337,
   its externally supplied genesis hash, empty genesis transaction list and an
   unused fixture deployer. It creates or stops no node process.
2. Runs the original actual paid-token, Safe media and typed-authority flow.
3. Deploys the pinned OwnerRecords product and registers that host and the
   existing independent host in the actual module registry through delayed
   governance. Metadata keeps its existing registration and selected pointer.
4. Registers three exact schema documents. The actual buyer submits a direct
   Owner CONDITION_REPORT with embedded bytes and an empty optional URI. The
   attestor Safe receives an actual CURATOR/class-3 Metadata family-writer grant
   and publishes a distinct generic Metadata record. That Safe also publishes
   one independent record in deployment scope `0` with a fresh nonce.
5. Checks each original event, receipt, payload, hash and lane head. It retains
   the direct-owner signature bundle and independent authorization bundle.
   The original collection-scoped independent semantic lane remains unchanged.
6. Freezes the original six Core views and all reader dependency runtimes at
   one final block. The new deployment evidence records the additional
   transactions, module registrations, records, source composition and genesis.
7. Retains and reconstructs the original-format token package, builds a fresh
   V1 base, constructs six anchors, then runs the read-only native capture and
   V2 assembly. The joined report must contain each newly published hash at
   its exact host/scope and all four registered catalog scopes. Missing positive
   records cannot be replaced by an empty catalog or an outside-roster source.

These are implemented execution steps, not a report of a completed native run.
The schemas describe explicit local test statements; they establish no
professional condition assessment, legal title or institutional endorsement.
The original synthetic authority snapshot and controlled entropy remain explicit.

### Source-bound compiler products

`tools.museum.token_dossier_manifest` prepares a new composition from two
externally SHA-256-pinned native manifests: the original token base and supplied
native products. It inspects only the selected base products, the additional
`StreamOwnerRecords` root, and their recursive creation/runtime library links.
There is no compiler invocation or artifact-directory discovery.

Every selected artifact must match its source/contract identity and its original
compiler metadata source hashes at the exact supplied Git revision. Original
base products are reused only when those checks match. A supplied replacement
for an existing product requires an explicit `--replace <contract-name>`; a
stale original is never silently replaced. New and replaced rows carry distinct
provenance rather than inheriting the base's acceptance label. Optional
`--lf-transport` permits only recorded line-ending conversions, without changing
tracked source bytes or accepting other whitespace changes.

```powershell
python -m tools.museum.token_dossier_manifest audit --base work/original-native-inputs.json --base-sha256 <base-sha256> --products work/supplied-native-products.json --products-sha256 <products-sha256> --repository . --source-revision <full-source-sha> --lf-transport --output work/dossier-product-audit.json
python -m tools.museum.token_dossier_manifest prepare --base work/original-native-inputs.json --base-sha256 <base-sha256> --products work/supplied-native-products.json --products-sha256 <products-sha256> --repository . --source-revision <full-source-sha> --lf-transport --output work/dossier-native-inputs.json
```

Add reviewed `--replace` arguments when the audit requires them. The audit names
missing and stale products and graph-projection mismatches. A missing OwnerRecords
artifact can conceal additional linked products; the tool reports that unresolved
closure instead of guessing a minimum compilation set. Preparation refuses an
incomplete or stale composition. It also checks the graph projection's exact
executable templates and immutable offset groups before the recipe can reuse it.
For a replaced graph product, supply a reviewed fresh projection with both
`--projection-directory <directory>` and `--projection-manifest-sha256 <sha256>`.
The selected projection must pass the same exact template/link/offset checks;
the original projection remains retained as lineage. No projection is discovered
or regenerated by this tool.
Compiler metadata correspondence does not prove reproducible compilation or
successful deployment. The original accepted base remains historical lineage.

### Coordinator-owned execution

After reviewing the exact artifact audit, constructors and receipt prerequisites,
the Coordinator supplies the one fresh chain. Configure its credential-free
loopback URL in `STREAM_MUSEUM_RPC`, then invoke the mutating recipe only on that
owned chain:

```powershell
python -m tools.museum.current_token_dossier_capture --native-manifest work/dossier-native-inputs.json --native-manifest-sha256 <prepared-sha256> --source-revision <full-source-sha> --rpc-env STREAM_MUSEUM_RPC --genesis-hash <fresh-chain-genesis-hash> --disclosure public --output work/current-token-dossier
python -m tools.museum.native_dossier_capture verify work/current-token-dossier/native-dossier --result-hash <nativeCaptureResultHash>
```

The output keeps the original capture, retained token, V1 base, native plan,
native capture/assembly, recipe result and public local execution journal in
separate directories/files. A failed execution also retains its journal. Save
the printed hashes externally. This command sends fixture transactions but does
not fund accounts, launch/stop Anvil, impersonate an owner, load saved chain state,
replace code/storage or broadcast to a remote chain. The read-only verifier needs
neither the RPC endpoint nor compiler products. Keep full original chain history
available until capture finishes; a newer V1 base is never joined to capture8's
old source block by token-ID coincidence.

## Remaining acceptance

The broad owner, independent and token COMPLETE/HEADS requirements remain
unresolved until applicable host, family and scope completeness is established.
MetadataV1 alone does not cover every token attestation host. Transfer
provenance additionally needs its covering LTA-EVENT-HISTORY archive and all
applicable accession/deaccession title-binding correspondence. A recorded title
binding does not establish legal validity or physical custody.

Capture8 does not contain these complete source transcripts. An empty new input
set can demonstrate preservation and missing-source reporting, but cannot
upgrade its original requirement coverage. Genuine native source captures,
full typed evidence integration, the acquisition packet and institutional
acceptance remain separate outstanding work.

The capture8 empty-input V2 diagnostic built and reconstructed with network
access disabled: 534 files, 30,944,232 bytes, manifest
`0x3451c2250bca5681a5fe1a650fb148691144aa3f2e1719c70be14e945100d8b1`.
It retains all original V1 files, reports zero new native checks and leaves
the native source/host/archive requirements unresolved. This result is not a
positive native-capture or complete-dossier acceptance case.
