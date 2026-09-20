# Artist extension creation carriers

The candidate Factory receives four independently deployed creation-code parts:
Identity prefix, Identity tail, Estate prefix, Estate tail. Deploy each named
`StreamArtistIdentityCreationPart` / `StreamArtistEstateCreationPart` with index
zero and one, then pass their ordered addresses to the Factory constructor.
Each part constructor obtains the actual compiler-linked child `creationCode`,
slices at 16,384 bytes, and returns a STOP-prefixed byte carrier. These are data
contracts; the compiler's nominal deployed-code stub is **not** their actual
returned runtime. Record each actual address, code hash and code length.

The Factory reconstructs both images and compares their hashes with source-derived
canonical values. Identity's value is computed only in its constructor; Estate's
value comes from the fixed linked `StreamArtistEstateCreationHash` library to
keep the Factory's complete initcode below EIP-3860. No deployer-provided hash
is trusted. The existing birth mapping remains at slot zero; write-once creation
pins follow it. There is no setter or replacement route. `creationImage(kind)`
exposes the saved configuration, and `extensionCreationCode(kind)` verifies
both current part runtimes and the reconstructed image again before returning it.

The linked wrappers retain their original six-address ABI. They append exactly
`abi.encode(host, registry, coordinator, archive, core, manager)` and perform
zero-value CREATE under the original delegatecall Factory context. Child
constructor code, immutables, revert bytes, birth hashes and events are unchanged.
The Factory constructor performs no CREATE; its first child still uses nonce one.
Part deployments consume the external deployer's nonces before Factory deployment.
Current assemblies either predict later addresses after that point or use the
existing reserved Coordinator slot. No previously deployed RC1 product is changed.

Factory admission still checks the exact compiler-linked Factory runtime. Its
constructor-pinned data uses ordinary private write-once storage, so that runtime
does not vary by chosen part addresses. Invalid, reordered, duplicate, foreign,
non-STOP, changed-length or changed-byte images fail closed. A failed child
constructor reverts the complete Factory call, retaining neither nonce nor birth.

## Scoped evidence

The first selected capture uses Solidity 0.8.19, via IR, optimizer 200, Paris,
and no CBOR/bytecode-hash metadata, based on `7ee02903`. Both former oversized
deployment wrappers measure 693 runtime bytes. Factory runtime is 3,775 bytes;
its creation object plus the 128-byte argument tuple is 31,224 bytes. The
fixed Estate hash library is 24,519 bytes, only 57 below the runtime limit;
any child or compiler-input change requires remeasurement.

The original Identity image remains 25,601 bytes and its child runtime 23,886;
Estate remains 24,382 / 22,625. With the original 192-byte constructor arguments,
their actual initcode lengths are 25,793 and 24,574. The actual returned carrier
runtimes are 16,385 / 9,218 for Identity and 16,385 / 7,999 for Estate. Part
creation objects plus their 32-byte index arguments are 26,099 and 24,880.
All these measured products fit the original 24,576 / 49,152 limits.

`StreamArtistCreationCarriers.t.sol` authors independent compiler-image, exact
constructor, CREATE address/nonce, immutable, birth/event, canonical-runtime,
constructor-failure, fragment-corruption and identical-retry checks. The existing
split-deployment recipe measures every new part as an independent transaction
envelope before Factory and child deployment. Source/ABI and selected codegen
are separate from execution: focused native tests, cold deployment envelopes,
and the final complete current-graph constructor profile remain pending until
run against the final linked candidate. No general deployability or release
acceptance follows from these selected measurements alone.
