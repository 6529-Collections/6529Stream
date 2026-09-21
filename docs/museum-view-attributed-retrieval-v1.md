# Retained VIEW attributed retrieval evidence

This offline consumer joins the frozen native attributed-retrieval API to the
complete original preservation proof, the retrieval-enabled inventory and
received media bytes. It uses a separate Museum profile. Existing exact-locator
and inventory profiles retain their original meaning.

The native source is frozen at
`666331709d590ce680b52cc9fd2c1f0c43561ac6`, integrated by the root at
`0c14acde766b65f791de9930bc7e9575078eaae4`. The `profiles` command reports
the exact source-file fingerprints and the separate Museum profile hash.

## What is checked

The consumer reconstructs the actual retrieval-enabled inventory, including its
changed image obligation, complete ordered source stages, items and segments.
It binds the selected inventory's immutable witness address and runtime, then
checks each operative item's plan, index and dedicated witness-record getter.
The witness identifier remains separate from a generic Archive proof.

Each retained witness includes its original canonical observation, signature
bytes, receipt, publication event and optional revocation event. Receipt,
observation, configuration, payload and record hashes use the exact native ABI
domains. Historical signature material is retained without reauthorizing it
against a current Safe. Retained history is an explicit subset; it does not
establish that every global publication or revocation was captured.

Operative evidence must join the complete current Source, including checkpoint
context, original adopted payload and its image URI. The selected adoption must
remain current, and its adoption event must precede witness publication. The
full locked Artist presentation and registry runtime must match. Original
Archive object, receipt, checkpoint, fixity and institutional-family evidence
must correspond at the captured block. Scope-specific revocation epochs participate in the native
environment commitment. Changing only an outer hash cannot repair a
contradictory source, item, original receipt or runtime.

## Routes and received bytes

The native route vocabulary contains direct retrieval, observed HTTP redirects,
attributed byte-identical mirrors and attributed Arweave manifest-path steps.
Literal URI order, redirect status, step fields and the exact final URI are
checked. Paths are never normalized into a different claim.

Every manifest occurrence requires its own original Archive evidence and full
manifest bytes. Keccak-256, SHA-256, size and Artist must agree with the admitted
object. Each Arweave manifest root joins that manifest's original transaction
receipt; a final Arweave root joins the final object's receipt. Repeated
manifest occurrences stay separate in the denominator.

The native protocol treats the path interpretation as an attributed
declaration. The consumer retains that limit: it does not parse a manifest into
an independently proven path mapping, infer a URI content digest or perform a
network request. Every operative witness nevertheless requires complete
received media bytes matching the admitted object's hashes and byte size.

## Input and commands

Use the isolated environment from the
[Museum tooling guide](../tools/museum/README.md).

```text
python -m tools.museum.view_preservation_retrieval_v1 profiles
python -m tools.museum.view_preservation_retrieval_v1 verify INPUT.json
```

The canonical input has these closed top-level fields:

| Field | Evidence |
| --- | --- |
| `profileHash` | Exact Museum consumer profile returned by `profiles` |
| `context`, `graph` | Bound source block and complete dependency/runtime identities |
| `sourceProof` | Unchanged original preservation `bundle` and `events` |
| `inventory` | Actual new inventory `value` and immutable companion `binding` |
| `retrieval` | Native witness/configuration, retained records, scope epochs, item bindings and exact shared source calls |
| `materials` | One `{recordHash, mediaBytes}` row for every operative witness |

`mediaBytes` contains the full hexadecimal byte string. Missing, duplicate or
extra material rows fail. The consumer bounds each media object at 16 MiB,
total media at 64 MiB and the canonical input at 256 MiB. Exceeding a bound
fails instead of truncating evidence.

Witness payloads are bounded at 524,288 bytes, signature material at 4,096
bytes and each URI at 2,048 UTF-8 bytes. This offline reader also limits a
route to 256 steps; that reader limit is separate from the native payload cap.

One runtime/getter map reconciles source carriers, policy and Registry pins,
the witness, inventory, primary Archive and every manifest Archive observation.
Repeated reads must agree. The report includes hashes and counts of the exact
source inputs and calls, alongside compact material and route results.

## Evidence limits

Successful verification means the supplied native observations, preimages and
received bytes correspond. It does not authenticate their RPC provenance,
prove EVM execution, repeat a network retrieval, establish current availability
beyond the captured block, complete every Archive admission in the inventory,
prove browser rendering or establish finality. Actual source capture,
institutional conformance and profile registration remain separate work.
