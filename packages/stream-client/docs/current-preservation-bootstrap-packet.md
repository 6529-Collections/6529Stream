# Offline preservation bootstrap packet decoder

`scripts/current-preservation-bootstrap-packet.mjs` reads an explicit set of
eight raw file buffers and returns immutable decoded facts and hash checks.
It performs no RPC, signing, state generation, import or deployment operation.

The fixed source profile is
`06a361af3f2aee053652b7d1d331480b439f1966`, tree
`45eadcea1043f24d389b781dfa260285bd5da754`. The
[portable schema witness](../test/fixtures/current-preservation-bootstrap-packet-source.json)
retains exact helper sources and selected complete compiler ABIs. The compiler
captured an earlier working source; the final Bootstrap helper differs by one
comment phrase. The witness records both identities and the exact substitution.
Earlier unchanged tuple evidence keeps its original source identity.

## Supply the exact original files

```js
import { readFileSync } from "node:fs";
import {
  PRESERVATION_BOOTSTRAP_FILES,
  decodePreservationBootstrapPacket,
} from "./scripts/current-preservation-bootstrap-packet.mjs";

const prefix = "/reviewed/path/to/export-prefix";
const files = Object.fromEntries(PRESERVATION_BOOTSTRAP_FILES.map(name =>
  [name, readFileSync(`${prefix}.${name}`)]));
const decoded = decodePreservationBootstrapPacket(files);
```

The required keys are:

| File | Encoding |
| --- | --- |
| `initial-dump.json` | Unchanged raw dump bytes |
| `final-dump.json` | Unchanged raw dump bytes |
| `prestate.abi` | Canonical ABI encoding of the supplied account array |
| `snapshot.abi` | Canonical ABI encoding of one Snapshot tuple |
| `preparation.abi` | Exact Scenario `preparation()` return bytes |
| `writer.abi` | Canonical ABI encoding of one WriterState tuple |
| `cut.abi` | Canonical ABI encoding of one Cut tuple |
| `complete.abi` | Two static words: profile and hash of raw `cut.abi` |

The `.abi` files are binary bytes, not textual hex. WriterState is one dynamic
tuple, not four top-level getter outputs. The decoder checks complete canonical
decode/re-encode equality, including offsets, padding and absence of trailing
bytes. It checks sizes and cumulative nested allocations before ABI decoding.
The exported limits are client resource bounds, not protocol limits.

The initial dump was captured **after Scenario preparation**. It must not be
treated as the admitted prestate. Dump bytes remain opaque and are hashed
without JSON reserialization. Parsing and bidirectional dump parity belong to
the separate native-state verification procedure.

## What the result establishes

The decoder checks the fixed profile and Scenario artifact name, the completion
marker's Cut hash, and all six raw file hashes committed by Cut. It checks
duplicate snapshot/prestate accounts and slots, created-account consistency,
required seed accounts, allowed declared dump omissions, and supplied-account
closure relationships. These are checks of supplied facts, not proof of the
native trace that produced them.

The writer must match the prepared collection writer. Its setup Safe nonce can
precede the final writer nonce because scoped preparation occurs later. This
Safe nonce is distinct from the EVM account nonce. Preparation checks retain
the original collection/token/scoped profiles, completed STATIC selections,
seven-child graphs and unfinished caller-publication identifiers. Optional
tuple fields are preserved without invented nonzero requirements.

An absent account's zero `codeHash` and the Foundry VM's special observed hash
remain decoded facts. The decoder does not replace them with the empty-code
hash or claim runtime hash verification. Exact native library provenance and
the complete actual execution environment remain external evidence.

Inputs are copied before parsing. Returned facts contain no mutable byte-buffer
references and include per-file byte counts, SHA-256 and keccak256 digests.

## Evidence still required

A completion marker can survive a later outer revert. A self-consistent packet
therefore does not prove that the outer TEST succeeded. The result explicitly
leaves outer execution, baseline admission, dump grammar/parity, native closure,
native library traces, runtime hashes, independent protocol preparation, import
and deployment admission unverified.

The decoder's tests use synthetic packet bytes. No actual exported packet or
admitted runtime graph is implied by those tests. Candidate-baseline capture
and native TEST/library-trace verification are separate tools and evidence.

## Reproduce the schema witness

The generator consumes the exact retained compiler artifacts, historical tuple
witness and handoff, validates their pinned hashes, and joins the selected source
files to the fixed Git commit. Pass explicit local artifact paths; `--check`
compares the deterministic witness without writing it. This operation does not
compile Solidity, execute an EVM or create a bootstrap packet.

```sh
node scripts/generate-current-preservation-bootstrap-packet-fixture.mjs --artifact-dir /reviewed/caller-baseline-abi-v1 --historical-tuple-witness /reviewed/caller-bootstrap-source-packet-abi.json --handoff /reviewed/caller-baseline-2825-handoff.json --check
```
