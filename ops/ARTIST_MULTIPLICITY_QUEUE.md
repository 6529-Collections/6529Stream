# Artist multiplicity batch

Base: `ed4d5572`; task-owned branch `codex/artist-multiple-authority-hydration`.

- Implemented source: explicit original living multi-Artist/collection op60,
  complete journal/allocator/nonce/guard proofs, tagged typed owner imports and
  atomic per-lane activation. Original Owner checks/commits and held patches untouched.
- Authored actual-owner/Safe tests: independent/shared identity, complete evidence
  oracle, omissions, drift, revocations, successor signatures/writes/allocator,
  late Archive retry and legacy/advanced refusal.
- Focused ABI capture: `.tmp-artist-multiple-hydration-abi5` has 876 sources,
  zero errors. Exact base comparison retains all 962 original changed-product
  ABI entries and original storage layouts. Ten new test bodies are authored;
  independent source review is pending. No new native or bytecode-size run.
- Independent evidence-size arithmetic for the authored shapes: 23,136 bytes
  for two Artists/two policy-bearing collections, 20,512 for one shared Artist,
  and 24,416 for two Artists with revocations and no policies. These are encoded
  shape estimates, not executed transaction or capacity acceptance.
- Still separate: corrected bindings and pending histories, delegated/collaborator
  profiles, multiple-identity composition with payout/economics/readiness/finding
  profiles, advanced authorities, repeated imports and larger evidence carriers.
