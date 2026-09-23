# Retained VIEW locator correspondence

This separate offline consumer checks the bounded VIEW image-locator semantics
at native source `0ab0cf308894afb2c80d10fe0b1a4da8db9ca615`. It preserves the
older retained inventory, export and archival-package profiles unchanged.

The input joins the actual adopted image URI and declaration record to the
original external Archive object and its same receipt pair. The complete
supplied media bytes must match the object's Keccak, SHA-256 and nonzero size.
No URL is treated as a file digest, and verification does not fetch URLs.

## Supported correspondence

| Adopted URI | Required original evidence |
| --- | --- |
| Institutional `https://` locator | Exact URI bytes equal the second receipt's storage identifier |
| Canonical `ar://` transaction | Exactly 32 decoded transaction bytes equal the first receipt's identifier and its original checkpoint |

HTTPS uses the native Archive grammar: lowercase hostname labels, a nonempty
path, printable ASCII and no percent escapes, credentials, fragment or
backslash. The complete URI is bounded to 2,048 bytes. Ports and uppercase
hostnames fail; query characters in the path are retained exactly where the
native grammar permits them. No URL normalization is performed.

Arweave locators contain exactly 43 unpadded base64url characters after `ar://`.
The decoded transaction must be nonzero and padding bits canonical. Subpaths,
queries and fragments fail. Redirects, origin-to-mirror mappings and manifest
resolution require a separate general retrieval witness, which this profile
does not accept. Empty and raw-CID rows keep their previous native semantics;
this entrypoint specifically requires a locator obligation.

## Required input

The closed canonical JSON envelope contains:

- `profileHash`, matching the exact `profiles` output below;
- `context` and the exact `graph` role set declared by the profile;
- `sourceProof`, with the complete original preservation `bundle` and `events`;
- the six-role native Archive `dependencies` tuple;
- the original locator `item`, `admission` and `sourceEvidence`;
- `sourceBindings`, containing the source block hash, explicit provenance and
  ordered original dependency getter transcript;
- `mediaBytes`, containing all media bytes as lowercase `0x` hexadecimal.

Source validation replays original adoption, full-scope membership, complete
output commitments, snapshot, root and publication events. The item is derived
from that selected adoption's exact payload, rather than a supplied URI field.
The original row retains algorithm zero, empty digest and size zero. Only a
local copy supplies the Archive object's content digest and size to the
unchanged original-admission verifier.

Admission validation checks object/coverage domains, chain and Archive host,
both receipt and fixity preimages, the original checkpoint and exact selected
receipt locator. A matching locator belonging to a different object or receipt
pair fails. All canonical ABI records and original signatures remain in the
input; the consumer does not validate historical signatures or consensus.

Bounds are 128 MiB for canonical input, 64 MiB for the complete source proof,
16 MiB for media bytes and the existing 64 MiB aggregate Archive-original bound.
Each receipt, fixity and checkpoint keeps its original ABI byte bound. Inputs
outside a bound fail as a whole.

## Commands

Use the isolated Python environment described in the
[Museum tooling guide](../tools/museum/README.md).

```text
python -m tools.museum.view_preservation_locator_v1 profiles
python -m tools.museum.view_preservation_locator_v1 verify locator-evidence.json
python -m unittest tools.museum.test_view_preservation_locator_v1 -v
```

The report records exact source, item, dependency and input hashes, media
digests, selected records and `synthetic_fixture` or `externally_admitted_rpc`
provenance. The consumer profile is a local interpretation, not a registered
native sanction document. Revised native Profile 3 catalog registration remains
a separate requirement.

## Meaning and limits

Passing means the supplied original commitments and media bytes correspond.
Retained RPC facts cannot authenticate their own provenance. Original receipt
signatures, writer authority, archive consensus, current receipt-pair liveness,
browser execution and finality remain unverified. The source proof contains
complete output commitments; it does not supply every member's output bytes.

This check is not the twelve-stage inventory, a completed Bundle coverage
transaction, a current refresh or general retrieval admission. Those surfaces
need their own exact source-qualified evidence. Earlier retained profiles and
test results do not acquire this successor's semantics.
