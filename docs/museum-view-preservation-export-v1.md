# VIEW source export and retained inventory correspondence

The offline adapter joins an original local VIEW ceremony source export to a
separately supplied [complete inventory packet](museum-view-preservation-inventory-v1.md).
It validates every exported member and the full retained inventory before
reporting correspondence. It does not construct an inventory from the shorter
source export.

## Required inputs

Use the original `tools.preservation.view_ceremony_inputs` loader introduced at
`6a960cdbca7e951a061a724d6a2930d749cad48c`. The adapter imports that loader
directly; an installation without it fails with an explicit dependency error.
The source schema is `STREAM_VIEW_CEREMONY_SOURCE_EXPORT_V1`, whose original
schema Git blob SHA-256 at that revision is
`afa2776fc63bf96270d68f9f0800c0424a4bc9fddbfb76f4d53f99fbc5684d0b`.

Supply all of these independently:

- The export directory: original `source.json` and four files per member.
- Expected SHA-256 of the complete exact `source.json`, as 64 lowercase hex
  digits without `0x`.
- Expected export source revision, as `0x` followed by 40 lowercase hex digits.
- The complete canonical inventory envelope, including its source histories,
  original records, runtime bytes, registered documents, getter observations
  and events. Original bundle coverage may be explicitly `null`.
- Expected SHA-256 of that entire envelope, also without `0x`.

Pins detect differences from the supplied expected bytes. Their authenticity
depends on the caller's provenance for those expectations. Computing a new pin
after changing a file does not authenticate the changed file.

The export revision identifies its producer. The inventory interpretation
remains pinned to native source `fd861f3fd79dccc87646412603b6907d020c2917` and
consumer profile
`0x65fcf2d070984ddaae0930716990bd26ce67de69f1e946779be6050924c720b2`.
These revision identities may differ. Exact original ABI and byte joins must
still pass. The export deployment hash and retained deployment-evidence hash
also retain their separate domains.

## Checks performed

The original loader checks exact emitted JSON property order, its `sourceHash`
preimage, schema fields, bounds, member identities, paths and both file digests.
The emitted source encoding is compact UTF-8 in the producer's property order.
It is distinct from the canonical inventory envelope encoding.

The adapter then runs the entire inventory consumer and checks:

- Matching chain and scope, with export initial coordinates no later than the
  retained evidence anchor. VIEW ID and scope ID remain distinct.
- Exact adoption, checkpoint, output manifest, snapshot and Router root
  identities and original ABI bytes; exact reference and inventory dependency
  tuples, and bundle dependencies when bundle evidence is present.
- All 25 corresponding export graph roles, including Archive and both
  governance/Snapshot authority roles, against retained addresses and runtimes.
- Every member in order, including its identity, token data, full 992-byte
  output row, original JSON and original HTML. Sampling cannot replace the
  full denominator.
- Native basic and complete binding receipt hashes, their shared action/time,
  exact adopted route binding, snapshot dependency identities and nondecreasing
  gas, complete source selection and immutable dependency hashes.

The adapter reads the inputs without rewriting them. It does not execute
Solidity, call RPC, unpack an archive or run a browser.

## Provenance and limits

`sourceExport.kind` is always `local_fixture_export`. The retained packet keeps
its own `synthetic_fixture` or `externally_admitted_rpc` provenance and its
original environment. Passing byte correspondence cannot promote the export
to RPC evidence or authenticate the retained RPC admission.

The report preserves four export-only graph pins: Discovery, Role Registry,
Root Safe and Artist Safe. They lack a matching retained runtime proof in this
profile. The source fixture host/runtime and deployment identity are also
retained inputs, not proof that the fixture ran.

Basic/complete receipt checks establish deterministic hash correspondence.
Original snapshot admission gas may be lower than the retained current tuple;
its immutable dependency identities must match. The exact source-export
recipe requires the reference getter tuple to match its saved admission hash,
so this adapter retains that equality check. The underlying provider's wider
support for later reference-gas increases does not broaden this export profile.
Inventory and bundle dependency tuples are immutable and retain exact hash joins.
The original capability configuration preimage and full worker set are absent;
their commitments remain explicitly unverified. Governance action and time
fields do not establish transaction or governance execution. If bundle evidence
is absent, its exported dependency tuple has only an export-side commitment,
and no bundle-coverage result is inferred.

The report leaves native execution, current archive authority, browser
execution and finality unproven. All limits of the underlying inventory and
original bundle consumer continue to apply.

## Commands

Use the [museum Python environment](../tools/museum/README.md):

```text
python -m tools.museum.view_preservation_export_v1 profiles
python -m tools.museum.view_preservation_export_v1 verify EXPORT_DIRECTORY INVENTORY_JSON --source-sha256 SOURCE_SHA256 --source-revision 0xSOURCE_REVISION --inventory-sha256 INVENTORY_SHA256
python -m unittest tools.museum.test_view_preservation_export_v1 -v
```

The adapter bounds `source.json` at 16 MiB and the inventory envelope at
256 MiB. Each member file keeps the original source transport's bounds.
Successful output is one canonical JSON report. Missing original evidence or
any inconsistent byte, identity, commitment or external pin fails verification.
