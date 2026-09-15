# Original authority event reconstruction

The permanent rotation (32), identity recovery (35) and estate activation (40)
hash inputs already appear in their original events. This increment preserves
those events and preimages. It adds only the missing execution context for
rotation and estate activation; it makes no recovery source or eligibility change.

| Authority record | Original preimage evidence | Additional execution evidence |
| --- | --- | --- |
| 32 rotation | `ArtistRotationStaged`: artist, old/new addresses, nonce, reason, staged time and contest deadline | `ArtistAddressRotated` followed by `ArtistRotationExecutionContext`: exact executed transition, actual post-window end, preserved authority class and captured emitter context |
| 35 recovery | Schema-2 `ArtistIdentityRecovered`: all nine permanent RecordFields and the exact superseded-record list | No new event required for its permanent hash; the independent reader uses the original complete event |
| 40 estate | `ArtistEstateActivationRequested`: artist, successor, evidence, nonce, request time and notice deadline | `ArtistSuccessionActivated` followed by `ArtistEstateExecutionContext`: explicit activation-record backlink, incumbent, exact transition and saved ExecutionFacts |

The schema-1 companions follow the original event without moving original state
writes or events. They execute through a fixed linked event worker and retain
the Identity owner's emitter. Their context carries captured deployment chain,
Registry, Identity owner and actual execution caller. Recorder class 0 means
permissionless/governed execution rather than an Artist signature. The separately
recorded vested class remains the original actual class.

Rotation and estate hashes describe their original staged/requested records.
The independent reader can reconstruct those hashes before execution but does
not label them executed, vested or present in the authority-preimage catalog.
Execution requires the original successful execution event and matching context.
Estate coverage, governance witness, execution time and delegation epoch are
saved execution facts; they are not inserted into the old request hash. Early
estate execution retains both original nonzero governance commitments, while
ordinary execution retains their original zero values.

For operation 35, reconstruct the exact original supersession-list hash and
the twelve-word record preimage from the nine event fields plus the pinned
record domain, deployment chain and Registry. No current state, authority
classification guess, storage lookup or additional eligibility branch is needed.
This proves the contents of an admitted event; it does not independently replay
the historical governance, guardian, acceptance or capability authorization.

`ArtistAuthorityEventReader` is a bounded single-transition test reader. It
accepts explicitly pinned deployment constants and authenticated log source
boundaries; its caller-supplied emitter fields are not receipt authentication.
It rejects missing prior stage/request events, duplicate executions, missing
or foreign companions, bad activation backlinks, noncanonical supersession
lists and mismatched permanent hashes. Final ordinary reads and immutable
carrier reads are used only after reconstruction as the independent oracle.
Complete log-prefix authenticity and broader multi-transition/dismissal/contest
timeline reconstruction remain separate requirements.

Five new authored cases cover actual rotation and successor-Safe estate request
through execution, stage/request-only refusal to claim execution, malformed log
histories, and an existing accepted class-3 recovery with exact late-Archive
failure and byte-identical new-side authorization retry. An exact two-call
Archive witness distinguishes the failed attempt from its retry. Reverted
inspector observations are discarded; original owner roots and acceptance
nonce prove rollback, and only successful execution logs are reconstructed.

These are actual Artist/Safe/Archive fixtures with typed Core/governance
boundaries. ABI/type checks are separate from native execution, linked product
sizes, current-stack integration and transaction capacity. No complete AA-RECON
or release acceptance is claimed.

```powershell
python scripts/dev.py test --suite unit --via-ir --match-path test/unit/artist/StreamArtistAuthorityEventReconstruction.t.sol --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824
```

This is the existing aggregate unit fixture and CREATE order. Include its
original Arweave fixture JSONs in an isolated runtime capture. Link the new
`StreamArtistAuthorityRecordEvents` library as an actual dependency.
