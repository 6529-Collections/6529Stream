# Scoped full-policy output handoff

Base: `c686a29f4ba6031cccfe8fd60a0b0aef296aa85a`.
Branch: `codex/scoped-policy-output-v2`.

## Exact batch

The integrator authorized five additive production files: scoped policy content
checkpoint, output manifest, schema definitions and their two companion
interfaces. The new profile covers TOKEN, RELEASE and SEASON. Original COLLECTION
and scoped V1 products remain unchanged; VIEW belongs to its separate adopted
profile. The [integration guide](../docs/integrations/scoped-policy-output-v2.md)
describes construction and the remaining assembly.

The first missing prerequisite was the COLLECTION guard in the original policy
checkpoint. The original policy manifest likewise pins that COLLECTION profile.
This batch adds distinct capabilities and profile/schema/ordered-chain domains
while retaining the original six-field content tree and 20-word output rows.

The checkpoint binds the real scoped factory profile/runtime and canonical
352-byte dependency tuple to the selection's actual Core, Metadata and membership.
Every current read rechecks the factory-owned inventory plan, source-set identity,
runtime and complete current scoped route. It then joins the exact scope and
membership to the original source policies and rendered output. Terminal rows
retain zero seed and false finalization; randomized rows require true status 5
and the original native seed. No synthetic policy/source set is used in positive
checkpoint or joined-manifest cases.

## Authored test boundary

The checkpoint fixture uses actual native entropy Coordinators, policy
configuration and asynchronous fulfillment, real scoped factory CREATE, full
Coordinator Inventory, Metadata/Schema/Store, sealed scope membership, selection,
Router, Renderer and terminal-readiness components. Core identity and pointer
reads, Artist authorization, governance execution, module/renderer admission and
external entropy delivery are named test boundaries. These are focused component
tests, not the complete current-stack or Artist/governance finality ceremony.

Thirteen checkpoint cases cover all three supported canonical scopes, full original
source joins, terminal DISABLED and ASYNC NOT_REQUIRED output, actual finalized
random output, pending batch rollback and fulfillment retry, retained burned
identity and prepared refusal, exact payload ordering/bytes, currentness and
runtime drift, factory/dependency substitutions, distinct source sets for different
scopes, COLLECTION/VIEW refusal, full original policy-receipt drift, and exact
start/append/completion events across partial batches. They compare content and
output commitments to independent ordered hashes.

Eleven manifest verifier cases include two fuzz properties over every header and
output-row word, exact scope and token count, distinct capabilities, chunk and
partition handling, archive/schema drift, historical retention, and a real
threshold Safe late-failure/byte-identical retry. That host names its checkpoint
and original archive-family receipt boundaries. Two additional joined cases use
the actual factory-created source set and rendered checkpoint through the real
schema/store/archive aggregator and manifest verifier, including historical
retention after factory runtime drift.

The inherited checkpoint dependency/render budgets are unchanged. The joined
two-row verifier uses an explicit 32-million-gas read budget to reserve the
original 16-million render budget plus full policy and selection work. This is
fixture configuration, not production or transaction-gas acceptance.

## Required follow-on work

The factory and these outputs do not complete scoped full-policy finality.
Remaining incompatible consumers are:

- `StreamPolicySnapshotSourceReadsV2`: COLLECTION-only source/types.
- `StreamMetadataScopedContentSource`: original scoped V1 snapshot decoding and
  provider binding. Its COLLECTION V2 counterpart also refuses scoped roots.
- `StreamPolicyReferenceSourceReadsV2`: COLLECTION-only; old scoped V1 samples
  cannot represent terminal full-policy output.
- `StreamPolicyRenderCriticalSourceReadsV2` and its stage/context readers:
  COLLECTION V2 snapshot/reference/profile joins.
- `StreamFinalityPolicyInputManifestReadsV2`, provider and profile discovery:
  original COLLECTION/scoped V1 interpretation and dispatch.

A joined scoped profile must retain original op17 root authority and an acyclic
publication order. Old scoped snapshots precede roots; COLLECTION V2 snapshots
include a previously admitted root. The eventual ceremony must also include real
archive coverage, Artist content-root/sanction records and canonical delayed
governance. No old factory slot, COLLECTION scope ID, typed finality record or VIEW
profile is substituted here.

## Validation boundary

Independent production review checked exact factory and scope admission, distinct
capabilities/domains and mechanical preservation of the original source-read,
rendering, terminal/finalized, tree and bounded-read bodies. Independent test review
checks setup and failure ordering. All runtime execution, deployment fit, cold
gas/capacity, combined current graph, fuzz execution and full release evidence
remain pending under the integrator's source-first sequencing. No native compile
or runtime result is claimed for this batch.

Final ABI-only capture under Solidity 0.8.19:
`artifacts/art27-gap3/scoped-policy-output-v5`, 406 sources, zero errors.
Input SHA256:
`eb561f9308e3f3a62a5656c6a216f5d2388e70dc6b31399bfafe50abba75a3d9`.
Output SHA256:
`db2128ad4816a279d626dfe66cf194fd650ffdfac2d26c84a6cef4cca6b21658`.

Final independently reviewed checkpoint-test SHA256:
`3c6611fd4c4c383f187035db802848d797c38a8d304163bddee2715bedeaa332`.
Final independently reviewed manifest-test SHA256:
`d167e1981f336be836b8fc02d7d155e4cec1cc73ec57c8d4510a8a6d6513a334`.
The authored total is 26 tests: 13 checkpoint, 11 manifest verifier (including two
fuzz properties), and two joined factory/checkpoint/manifest cases. ABI compilation
does not execute those cases or their fuzz budgets. Scoped formatting, 17 Markdown
checker tests, Markdown links, changelog and Windows-aware whitespace checks pass.
