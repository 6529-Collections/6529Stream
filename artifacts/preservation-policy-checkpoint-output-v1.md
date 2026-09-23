# Preservation checkpoint/output source checkpoint

Base: `8a00d66e7ede04a34d18f6d2931684b07813a56d`.
Implementation follows accepted ADR0054 and the integrator's per-member producer
decision. This batch does not change any existing full-output consumer.

## Authored scope

- Shared preservation binding and original scoped source/factory readers.
- Complete COLLECTION and TOKEN/RELEASE/SEASON checkpoint hosts with the actual
  selected Registry's governed admission for each member-specific producer.
- Explicit producer binding and admission in every 1,152-byte output row;
  complete currentness reuses that saved producer and observes every row again.
- Covered canonical manifest with common Core, Router and preservation profile,
  exact 640-byte header, 1,152-byte rows and new schema bytes.
- Fifty-nine authored cases: checkpoint 13, producer binding 15, covered
  manifest 21 (including two fuzz methods), scoped factory binding 10.

The domain fixtures identify their typed boundaries. They use actual original
selection, scope/source factory, storage/schema/coverage or publication helpers
as applicable; the new producer/admission boundary does not prove execution of
B's actual producer and class-1 Registry admission. The existing complete
full-policy ceremony remains unchanged and its sanction-cycle failure remains
an acceptance requirement for the composed successor.

## Independent source dependency

B owns `IStreamPreservationRegistryV1.sol`. The agreed interface was borrowed
byte-for-byte for the type check and deliberately excluded from this builder's
commit pending B's handoff. Its raw SHA-256 is:

`ca12e63188ef8874a60ddfe488d62ca42a7eeba2d21dc4090490d265e173df5f`.

`requirePreservation(versionKey, producer, profile)` returns exactly the
nine-word ProducerBinding and seven-word Admission, 512 bytes in total. The
consumer uses its typed selector, exact return size and canonical re-encoding.
Integration must include B's matching interface and governed implementation.

## Validation

Final checkpoint/output ABI-only capture:
`artifacts/art27-gap3/preservation-policy-checkpoint-output-index`.

- Solidity 0.8.19; 464 imported sources; zero compiler errors.
- Input SHA-256:
  `6f49e492f3da3cb0a797b1affa263f4e3ba7936166c2dc0273a9d2d814430524`.
- Output SHA-256:
  `9623ff549f743d8f57b4ff028aa86e7eef4f2b1d2f74a70a5e5eeb9841057b43`.
- ABI inventory confirms all 59 authored test methods above.
- All 463 non-borrowed captured sources match staged Git blobs exactly; the
  remaining source is B's explicitly pinned interface above.
- Independent source review covered the binding, scoped source joins,
  checkpoint and manifest. The identified Core/Router selected-runtime gap in
  the first binding draft was corrected and covered by a regression.
- Scoped formatting, exact schema-byte parity and Windows whitespace checks
  pass. Markdown link tests (17), link checker and changelog checker pass.

ABI-only compilation generates no executable bytecode. Native tests, fuzz
execution, linked product sizes, transaction gas and actual complete
sanction/archive/finalization/confirmation parity remain pending. No additional
native compiler was started alongside the separately frozen `71ff` 27-case
predecessor run. Its outcome cannot validate this new source.

## Continuation

The [consumer guide](../docs/integrations/preservation-policy-consumers-v1.md)
records the stable sizes and remaining root, snapshot, reference, inventory,
provider and actual ceremony joins. Shared Router and CONTENT_ROOT changes are
owned by the integrator. Scoped snapshots remain before their root; COLLECTION
snapshots remain after their root. No deployment or broadcast is included.
