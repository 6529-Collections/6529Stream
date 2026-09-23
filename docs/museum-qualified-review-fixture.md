# Qualified-account review: retained local originals

This fixture publishes one mapping from account A, two later exact reviews
from account B (`reviewed` and `rejected`), and a later SELF-review control from
account A. It uses the separately registered qualified-account profile and the
original review body format. Each review binds the original assertion selector,
revision hash, profile hash and mapping rule.

Distinct accounts establish account distinction only. They do not establish
independent people, professional qualifications, museum authority or an
institutional decision. The capture retains competing reviews without choosing
an effective result. Selection policy is a separate input to the separately
owned qualified review selector.

## Actual execution and offline replay

The driver uses an isolated local Anvil process, real governance contracts,
official Safe 1.4.1 components and registered schema bytes. It publishes records
through the actual independent attestation host. Account A and B are public,
unlocked local fixture accounts. The records use typed V2 entity layouts with
explicit null continuations. All four semantic records deliberately share one
claimed `createdAt`; original block, transaction and log positions establish
publication order.

The retained bundle contains 13 original files: the source anchor, deployment
evidence, native artifact manifest, native reuse audit, source capture and
transcript, publication hints/capture/transcript, interpretation capture and
transcript, exact case selectors, and file pins. External manifest and archive
commitments protect the retained bundle. Offline verification replays the
actual native source, publication and registered interpretation adapters with
their exact recorded responses. It also verifies the review targets and
historical attestors. No running node or compiler is needed to reopen it.

Deployment checks join the 19 original artifact names, paths, source paths and
SHA-256 hashes to the audit; join deployed addresses and runtime hashes to
observed code at the source anchor; and join deployment creation data and the
original publication receipts to the execution journal. Official Safe component
creation/runtime hashes are retained and checked. The live capture checks Safe
owners and thresholds. The offline bundle retains those owner declarations;
it does not independently replay Safe owner getter calls or all governance
execution. Compiler provenance and local execution origin remain externally
admitted evidence, not a consensus or cryptographic receipt proof.

## Historical product qualification

The capture reuses previously built, explicitly SHA-256-pinned native products.
It does not rebuild contracts or claim acceptance of the latest full stack.
The retained audit records all 19 artifact checks, official Safe fixture checks,
185 source metadata commitments and historical runtime comparisons.

Its source comparison is against checkout
`32c9afc9fbb39260293a586757c0462f1721b8f2`. Three product source files differ:
`StreamCore`, `StreamCoreExternalReads` and `StreamMetadataRenderer`. The audit
retains the original and comparison source hashes. Source roots are retained
build copies, not Git worktrees; they are not represented as one invented
source commit. Fresh deployment evidence contains the new runtime hashes and
addresses, including constructor-dependent values.

Earlier account V1 and typed-authority V2 fixtures and registered documents
remain unchanged. General and Artist account-review adapters are separate
work: their receipt qualifications, selector forms and publication-order
evidence cannot be replaced with an independent-account profile hash.

## Commands

Use the [Museum Python environment setup](../tools/museum/README.md#environment)
before these PowerShell commands.

The [retained fixture manifest](../schemas/museum/qualified-account-review-profile/local-fixture/manifest.json)
from 22 September 2026 has external commitment
`0x618ade1b0c337fef6f4cfb5d85d4a6fb0191f6e323db30087d4b57f57202f88a`.
Its profile commitment is
`0x63a33f0805969f5035045b6b42c400bb7bf33d16b715b5e2005f476fa4275755`.
The successful local run registered all 49 profile documents and published the
five original records. Replay checks all three captures exactly.

```powershell
.\.venv-tools\museum\Scripts\python.exe -m tools.museum.qualified_review_fixture_v1 verify schemas/museum/qualified-account-review-profile/local-fixture --manifest-hash 0x618ade1b0c337fef6f4cfb5d85d4a6fb0191f6e323db30087d4b57f57202f88a
```

The capture requires a sealed profile hash, a verified native product manifest
and an externally pinned reuse audit. It starts only its own fresh loopback
node and terminates that process when finished. It never uses a remote chain.

```powershell
.\.venv-tools\museum\Scripts\python.exe -m tools.museum.qualified_review_capture_v1 --native-manifest NATIVE_MANIFEST --native-manifest-sha256 SHA256 --native-reuse-audit AUDIT --native-reuse-audit-sha256 AUDIT_SHA256 --profile-hash PROFILE_HASH --output NEW_CAPTURE --disclosure public
.\.venv-tools\museum\Scripts\python.exe -m tools.museum.qualified_review_fixture_v1 retain NEW_CAPTURE NEW_RETAINED --capture-pins-hash CAPTURE_PINS_HASH
.\.venv-tools\museum\Scripts\python.exe -m tools.museum.qualified_review_fixture_v1 verify NEW_RETAINED --manifest-hash MANIFEST_HASH
.\.venv-tools\museum\Scripts\python.exe -m unittest tools.museum.test_qualified_review_fixture_v1
```

The focused tests cover offline native replay, exact registered documents and
predecessors, review account attribution and order, immutable original mapping
content, external pins, artifact/runtime/Safe mismatches, changed journal
receipts and malformed native manifests. They do not replace full-stack or
public-testnet acceptance.
