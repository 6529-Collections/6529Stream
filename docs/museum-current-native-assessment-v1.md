# Reassess current native dossier evidence

The current assessment adapter adds a separate forty-nine-row assessment to a
verified [unified V4 dossier](museum-unified-dossier-v4.md). It retains every V4
byte, including the original nineteen packet-group report and forty-nine
requirement decisions. Only five codes are eligible in this first native-state
batch: `identity`, `OD-FINALITY-STATUS`, `OD-CONTENT-ROOT-PROOF`,
`OD-ENTROPY-PROVENANCE` and `OD-ATTRIBUTION`. Every other code keeps its original
unresolved status. The work class stays `unknown`, including the two conditional
script requirements.

The adapter replays the entire V4 dossier, including its original current
attribution capture. The optional current scoped-policy finality V2 capture
supplies the finality record and native token content-root proof. The optional
public mint/entropy capture supplies the request, provider, terminal outcome,
events and leaf preimage. Each optional capture requires an external manifest
pin. The adapter replays its original transcript and checks exact chain, Core,
collection, token and source block against V4. Same-block positive observations
must agree. A package hash or packet field alone does not produce a verified
requirement reference.

An unresolved or absent optional capture leaves its codes unresolved. A capture
for a different token or source state, or one whose replayed observations
contradict V4, rejects assembly. The new assessment is under
`assessment/current-requirements.json`; `assessment/original-comparison.json`
locates each original decision and shows the new state. It does not alter V4's
decisions or let one source family stand in for another.

## Assemble and verify

Use the [Museum Python environment](../tools/museum/README.md) and supply the
original external pins:

```powershell
python -m tools.museum.canonical_current_assessment_v1 assemble --v4 <v4-directory> --v4-hash <v4-manifest-hash> --finality <finality-capture-directory> --finality-hash <finality-manifest-hash> --entropy <entropy-capture-directory> --entropy-hash <entropy-manifest-hash> --disclosure public --output <new-directory>
python -m tools.museum.canonical_current_assessment_v1 verify <new-directory> --manifest-hash <current-assessment-manifest-hash>
```

Omit either optional capture and its pin together when unavailable. Source
provenance remains explicit: a replayed `synthetic_fixture` proves only fixture
behavior; a `trusted_rpc` capture carries the reader's provider-completeness
assumptions. Neither mode proves chain consensus, source origin independently,
global history, institutional acceptance or physical performance. This adapter
has no `complete` command and makes no complete dossier claim.
