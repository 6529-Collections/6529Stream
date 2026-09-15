# Recorded preservation activities in the museum graph

The versioned `STREAM_MUSEUM_PRESERVATION_ACTIVITY_GRAPH_V1` crosswalk adds
Linked Art activities and named-agent resources beside the complete recorded
PREMIS package. It implements the explicit correspondence required by
[MSM-MAPPING](museum-semantic-mapping.md), especially rule 6. Existing file-only,
preservation-event, object/rights and multi-format packages retain their bytes
and meanings.

`preservation_graph_package` first verifies the exact recorded preservation
package using its external manifest hash. It preserves every source file and
manifest literally beneath `source/`, then derives the graph. Verification
replays that same source verifier and reconstructs every output. It performs no
network fetch, publication, registry admission or new capture. The public builder
cannot accept a synthetic event-control object as recorded evidence.

| Original evidence | New projection | Preserved boundary |
| --- | --- | --- |
| Explicitly completed, supported PREMIS event | `Activity` with its original event IRI and profile-local event type | Its reported outcome does not prove that the operation occurred or succeeded |
| Recorded event timestamp | A point `TimeSpan` with equal outer bounds | No substitution of publication, export or file timestamps |
| Explicit person / organization agent and original name | `Person` / `Group`, with a separate `Name` | No verified human identity, account equivalence or performance claim |
| Software agent | Exact typed Stream/PREMIS sidecar | Software does not become a person or organization |
| Planned, cancelled or unknown event | Original source disposition and evidence | No performed `Activity` or promoted participant |
| Original agent/object roles | Exact sidecar links, including absent fixity object roles | Opaque codes do not imply `carried_out_by`, object use, ownership or custody |
| Complete PREMIS XML | A derived `DigitalObject` identified by the exact byte hash | Structured XML is not forced into a linguistic-content relationship |

`graph/index.json` resolves every activity, named agent, local event type and
PREMIS document. Its correspondence entries identify the complete XML path and
original event/agent/object identifiers. The XML is available at
`source/premis-preservation/premis.xml`. Agent-document selectors, event selectors,
original seconds and outcomes remain alongside the index and per-property
provenance. The original PREMIS sidecars and captured source records remain
intact; the graph cannot replace their evidence. Labels are display aids, while
source-selected person/group names are also emitted through `identified_by`.

Each graph resource is shape-validated and expanded with the already pinned
Linked Art v2 schema/context closure. New definitions are in
[the graph profile](../schemas/museum/preservation-graph/profile.json); it includes
source/target paths, cardinality, authority, reverse correspondence and named
test vectors. It is a prospective export profile, not an onchain registration.
URN resources are archival entities, not a claim of a Linked Art HTTP API.
An unsupported source PREMIS projection produces an explicit unsupported report
with its original dispositions and no invented activity resources.

Run with the existing museum Python environment:

```text
python -m tools.museum.preservation_graph_package build <verified-preservation-package> <new-directory> --source-manifest-hash <external-source-hash> --profile-hash 0xbdfd9f50b4d94112731420d82793a6c5351e371c4e28c4d8add2759da812e6b1 --disclosure public
python -m tools.museum.preservation_graph_package verify <new-directory> --manifest-hash <external-graph-hash>
python -m unittest tools.museum.test_preservation_graph -v
```

The focused positive unit controls remain explicitly synthetic. The retained
actual local capture can also be projected entirely offline: it already contains
two reported fixity events and one ingest event with their original Safe-published
reports and observations. Reusing those bytes does not establish public-chain
acceptance, independently prove their historical assertions, authenticate named
agents, grant rights, or establish institutional conformance. Full source-family
mapping, role-specific relations and external institutional review remain
separate full-v1 obligations.
