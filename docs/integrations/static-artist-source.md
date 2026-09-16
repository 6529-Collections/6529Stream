# STATIC Artist display source transport

This is the additive producer interface required by the current STATIC Metadata renderer.
It is an implementation proposal for the Artist owner, not an existing Artist capability
or a conformance claim. The original Artist methods and their hash/state semantics stay intact.

`IStreamStaticArtistSource.staticDisplayRead(bytes originalCalldata)` returns `bytes originalAbiResult`.
The inner input is an original method selector and its original canonical ABI arguments;
the returned inner bytes are exactly that original method result, not a new truth source.
The registry admits only the following selectors. Every transitive source read must use a
bounded STATICCALL to a constructor-authenticated fixed owner or a direct internal storage
read. A delegatecall decoder anywhere along this path fails STATIC acceptance. A missing,
failed or malformed new transport fails the optional display frame; C does not call the
old facade as fallback. Writes, arbitrary target addresses, arbitrary slots and unknown
selectors are rejected. `core()` remains its existing direct immutable getter.

| Original method | Inner ABI bytes |
| --- | ---: |
| `collectionArtistState(uint256)` | 160 |
| `displayBinding(uint256)` | 320 |
| `platformWorksState(uint256)` | 640 |
| `attribution(uint256)` | 224 |
| `attributionClaims(uint256)` | 64 |
| `deploymentAttestation(uint256)` | 96 |
| `artistDisplayName(bytes32)` | at most 352 |
| `operativeIdentityRecord(bytes32)` | 32 |
| `collaboratorCount(uint256,uint64)` | 32 |
| `collaboratorAt(uint256,uint64,uint256)` | 192 |
| `artistAttestationStatus(uint256,uint8,bytes32,bytes32)` | 160 |
| `displaySanction((uint8,uint256,uint256,bytes32))` | 512 |
| `verifySanctionForSubject(uint8,uint256,uint256,bytes32,bytes32)` | 128 |

The exact Solidity selectors come from the original imported interfaces, including the
scope enum and snapshot identifier types; text signatures above are explanatory only.
Fixed lengths are exact; the one dynamic result must be canonical ABI and retains the
original 256-byte name bound. The outer bytes envelope is separately capped at
`64 + ceil32(innerMaximum)` and canonicalized. Reverts stay failures, including disputed,
revoked, failed finality membership or mismatched current-source joins; none turns into
an accepted attribution. Current attribution states 4/5 remain visible through the
original complete display serializer.

C owns the consumer and this interface proposal; A owns Registry/owner production.
The Metadata consumer still independently verifies the selected Core Artist pointer,
binding generation, original identity/claims/attestations/sanctions, and the original
finality source bindings. Those finality/snapshot source paths also need a transitive
STATIC check; an ABI-only pass does not establish it.
