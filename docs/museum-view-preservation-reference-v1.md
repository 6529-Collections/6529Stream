# Retained VIEW preservation reference evidence

The bounded offline consumer checks original reference observations against
native source `df6363e571dbff8fb61c192b2282733ccb3f1af8`. It preserves the exact
VIEW schema, profile, canonicalization, domains and tuple layouts. The earlier
[preservation capture](museum-view-preservation-v1.md) retains its own profile.

## Required evidence

Each reference original includes the exact Publication and Receipt getter
return, saved SourceFacts getter return, canonical payload, environment bytes,
Archive object identities and complete preservation source proof. The verifier
reconstructs the source, record and history hashes, including the different
normalization rules for payload and receipt. Current gas observations are
bounded dependency facts; they are not committed historical gas evidence.

The source proof contains the complete adopted VIEW preservation bundle:
producer admission, membership and entropy policies, every checkpoint output,
covered output parts/index, saved snapshot and Router root history. The verifier
joins the exact snapshot receipt/source and 28-word root binding. It requires
the snapshot, root and adoption selected immediately before the reference log,
using block, transaction and log positions. Later supersession is allowed.

One-token scopes require one sample. Larger scopes require the first and last
membership ordinals, in order. Every sample must equal its complete 31-word
checkpoint row, including burned identity and terminal or finalized entropy.
The saved HTML must match its original hash, length and SHA-256 commitment.
Repeated PNG declarations bind the same hash and exact Archive object role.
These samples never replace the complete output denominator.

The complete per-scope reference history must agree with its publication logs,
head, predecessor chain, unused IDs and optional terminal lock. CURATOR class 3
or global class 8 and original grant revision remain receipt provenance. The
class-2 lock and its derived component hash are commitments; the verifier does
not execute governance or establish finality.

## Environment file inventories

Both environment lists retain original PackageFile rows and canonical JSON:
package paths and platform prerequisites. Their whole-inventory identities bind
chain, original reference host, relative-path flag and every typed row. Optional
parts must cover the complete fixed 64-row partition, preserving global UTF-8
byte order and exact part/whole bytes. Whole-only preparation uses `parts: null`;
the verifier does not invent a history of prepared parts.

This support covers the existing permissionless environment preparation. The
unfinished full-scope render-critical inventory is a separate native feature.
File declarations and hashes do not prove ZIP membership, actual executable
contents or browser execution.

## Commands and limits

Use the isolated Python environment from the [Museum tooling guide](../tools/museum/README.md):

```bash
python -m tools.museum.view_preservation_reference_v1 profiles
python -m tools.museum.view_preservation_reference_v1 verify retained-reference.json
python -m unittest tools.museum.test_view_preservation_reference_types_v1 \
  tools.museum.test_view_preservation_reference_inventory_v1 \
  tools.museum.test_view_preservation_reference_wire_v1
```

The canonical JSON input contains `profileHash`, `context`, `graph` and
`evidence`. The graph adds `viewReference` and `externalCoverage` to the original
preservation graph; external object coverage is distinct from output-part
coverage. Source proofs are mandatory for every original. The two independent
native trace cases are not a substitute for this joined evidence.

The consumer bounds history to 16 records, the complete input to 64 MiB,
aggregate reference payloads to 8 MiB, each native payload to 524,288 bytes,
each sample HTML to 262,144 bytes and each environment file list to 4,096 rows.
Native retained inventory JSON is also limited to 524,288 bytes. These are
supported consumer bounds, not universal gas or native capacity guarantees.

Verification performs no RPC, compiler or EVM work. ACTIVE definition facts,
runtime pins and logs are supplied evidence; this command does not authenticate
their chain provenance. It does not reauthorize historical writers, prove fresh
native observations, reproduce transient Archive current pairs, prove archive
availability or consensus, execute a browser, or complete acquisition/finality.
