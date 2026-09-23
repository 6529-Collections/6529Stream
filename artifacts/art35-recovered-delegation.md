# Recovered delegation composition

Base: `b12ee710211ceb47be9d5bbc2ab7b83d58d639c9`.
Branch: `codex/artist-recovered-delegation`.

This source batch extends the recovered singleton generation-one graph with
complete original delegation and mixed direct/delegated policy, economics and
sale consents. Source/type checks and authored tests do not establish runtime,
Safe execution, gas, deployment capacity or release acceptance. The integrator
owns joined capacity work and subsequent native validation.

## Scope and original authority

- Actual retained grants, mode-2 binding or native16 select explicit feature64.
  Actual native15 additionally requires economics feature32. Concrete capability
  mask127 is activated following independent source review; abstract Owner stays
  disabled.
- The existing Identity export already carries original grants, current heads,
  recorded epochs, revocation records and complete principal/delegate history.
  Its kind2 selector now uses the original tagged delegate nonce key. Previously
  the untagged current-grant key omitted used lanes, and the complete nonce check
  correctly rejected preparation. No omitted tree was silently admitted.
- New structural checks authenticate original26 hashes and authorization guards,
  unique ordered27 occurrences and one-way cells, final heads, epoch ordering,
  and consumed kind2 bits versus uses. The existing full nonce-word correlation
  remains in force.
- The Consent worker reads the fixed source's original getters using the complete
  flattened14/15/16 journal. It preserves policy/grant links, all three economics
  maps and associations, sale versions/latest lookups and original replay points.
- The Coordinator reconciles every recorded grant use against complete mixed
  consent history. Sale nonce admissions use Identity's original clock; different
  owner revisions are never compared. Policy/economics missing signer/nonce/time
  fields and revocation missing reason/time fields are not fabricated.
- Fresh grants/delegated use remain class1-only. Historical living grants may
  survive under class3 without becoming usable. Original recovery epochs,
  current-domain signatures, old-grantor revocation and replacement restrictions
  remain unchanged. No original producer or current consumer is reauthorized.
- Corrected/multiple/collaborator graphs, broader records and held ART26 remain
  outside this bounded extension, as required future work.

## Validation evidence

Initial ABI-only capture `recovered-delegation-production-v1`: 267 sources,
zero errors; input `7f6b31305b69aa20b9afb2000438aaeed5861e7ad5ea10356d523ba09740fd19`,
output `21148d4f40dacd9c4471e83909547fc6952bbcf6a1c8be3912b3dad11d1530f1`.
Solidity0.8.19, optimizer200, via IR, Paris and no CBOR, ABI output only.

Joined ABI-only capture `recovered-delegation-joined-v2`: 1,055 sources, zero
errors; input `d2702e4d3dfd893a7941e9cf0827277c53334d3ed6df546086c8ffcb75eb2695`,
output `5da5d452032a65bdd4afd43bf5e51cd5b199c2b0ab7c7c2414ceb68fc9564559`.
This includes the activated production graph, twelve Identity component cases,
nine cross-owner component cases and explicit capability/mode-2 controls. It
predates the actual delegated-host and Consent component fixtures.

Actual-host ABI-only capture `recovered-delegation-actual-v3`: 1,025 sources,
zero errors; input `566f17aff951ea682f17372fd4f90d110c6457c51cd84917efd129d6717363ab`,
output `0e62ff390f2833f43823c71884467f03b4be2558b4399dc894b0cda38b6ed1b8`.

Final complete ABI-only capture `recovered-delegation-complete-v5`: 1,057
sources, zero errors; input
`9c6655eca334637cea8203e44984f9f19b9483762444f2f06df9bf2f40597e22`,
output `7782d333e8c1dad5a01b289f8a5e41d17bfbce5950494a3c1088f50860b41bb5`.
This capture follows the final scoped formatting correction; v4 produced the
same ABI output before that whitespace-only correction. Every changed Solidity
source is checked against this final input before committing.

Independent production reviews cleared Identity, Consent, the cross-owner join,
feature selection and mode-2 admission. The twelve Identity and nine cross-owner
cases are explicitly synthetic component boundaries. Their valid baseline and
malformed input controls do not establish actual producer authorization.

The source batch adds 43 test declarations: twelve Identity, nine cross-owner,
sixteen Consent component, four actual-owner, one seven-owner capability and one
mode-2 admission case. The actual cases use original owners, Registry, Coordinator,
Archive and Safe with explicit typed Core/governance boundaries. They cover mixed
14/15/16 grants, exhausted/revoked/old-epoch grants, retained sparse delegate nonce
257, fresh B/C domain signatures, stale-domain rejection, A-to-B-to-C imports,
complete witness rejection and late Archive/Safe rollback with identical retry.
An independent source review found no remaining issue at fixture SHA256
`6f8bdd536f1108c81b7f7043aa00a013ea908375ab8c8859fed1389fdbfbe8e1`.
During authoring, source snapshots were corrected to freeze each predecessor's
own inventory, preventing successor appends from changing the predecessor oracle.
No new class-3 delegated or operation-54 actual execution is claimed.

The Consent component fixture uses actual Consent writers behind a typed
Coordinator and explicitly synthetic second-era provenance. It covers exact maps,
associations, per-row origins, replay points, malformed complete inventory and
all-map rollback/retry. Its independent source review found no concrete issue at
SHA256 `7044ac6d322339e835b71c39271adb2f98abdac9fe8de748b8f729fb584fb19a`.
These component cases do not establish Identity
signatures, use reconciliation or full seven-owner operation60 execution.

Scoped Solidity formatting, staged whitespace and exact ABI-source checks pass.
Markdown-link unit tests pass17/17; link and changelog checks pass. No bytecode
output, native test run, gas/capacity measurement or release regeneration was
started. A's declaration-only memory-to-calldata return changes in the three
existing abstract Owner recovered getters must remain intact during integration;
this batch does not edit that Owner file.

## Next required composition

The integrator explicitly assigned complete recovered attestation/personhood/C2PA
transport after this batch. It must carry the original summaries/C2PA note and
full ordered witnesses through real35, successor and repeated import, with
current/stale truth and late rollback/retry. Original registration identity and
operative identity hash are distinct. The integrator's conservation consumer and
A's host-capacity factoring remain separate ownership.
The next base must contain the integrated original personhood dependency
`8972da42da396bdc3c0a2f7604d40f5db07946e5`, absent from this batch's base, plus
this delegation batch. The integrator will supply the exact joined base.
