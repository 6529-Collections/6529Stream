# Delegated minting to a vault

`StreamDelegateRegistryGate` implements the deliver-to-vault pattern in
[SSA-DELEGATE](../stream-sales-and-auctions.md#delegated-minting).
It uses the unchanged `IStreamMintGate.validateMint` ABI. Its storage holds
the governed registry-read gas parameter; Manager/Ledger own mint replay,
nullifiers, and allowance consumption.

## Pinned registry profile

Deploy with `(core, registry, usecase, governanceAuthority)`. Core and registry
must have code and the `bytes32` usecase must be nonzero. The address and runtime
code hash of the registry are immutable. Every eligibility read rechecks both
the runtime hash and deployment chain. A proxy whose implementation can change
behind stable runtime bytecode is unsuitable for this profile.

This profile uses the
[delegate.xyz v2 contract getter](https://github.com/delegatexyz/delegate-registry/blob/main/src/DelegateRegistry.sol).
It calls `checkDelegateForContract(hotWallet, vault, core, rights)`. That getter
accepts wallet-wide or contract-wide grants, including explicit zero-rights
wildcard grants. The gate first checks its base `delegationUsecase()`. If the
answer is false, it checks `collectionDelegationRights(collectionId)`:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_DELEGATE_COLLECTION_RIGHTS_V1"),
    deploymentChainId,
    core,
    delegationUsecase,
    collectionId
))
```

For a collection-only grant, the vault grants that derived right for Core.
A grant for collection 42 does not authorize collection 43. Existing broad
grants remain broad; removing a collection grant while retaining a Core-wide
grant does not revoke Core-wide authority. Collection IDs are never passed as
ERC-721 token IDs. This contract does not implement the NFTDelegation retained
row profile used by some sale adapters.

Each registry read uses a bounded `staticcall`, checks EIP-150 forwarding headroom,
copies only 32 bytes, and requires exactly 32 bytes containing canonical `0` or
`1`. A revert, gas exhaustion, malformed response, or changed runtime fails
closed. An absent grant returns false from `isDelegated`; gated mint validation
then reverts. The live `DELEGATE_REGISTRY_GAS_LIMIT` starts at 150,000 with the
same floor and failure class 2. Governance uses the existing monotonic delayed
GGP raise path. A zero governance authority permanently disables raises.

The caller must provide enough gas for up to two registry reads. Module admission
and the Manager's independently governed gate-call budget must accommodate this
nested call chain, including the second read's forwarding precheck after the
first read. Raising only the registry budget can require raising the Manager
gate budget as well.

## Module and phase registration

Register this module through the canonical module registry with:

- Mint-gate module type `keccak256("6529STREAM_MINT_GATE_V1")`.
- Interface `type(IStreamMintGate).interfaceId`.
- Version `gate.MODULE_VERSION()`.
- Runtime hash `address(gate).codehash`.
- Manifest hash `gate.moduleManifestHash()`.

The manifest bytes commit the module version, deployment chain, gate address,
Core, registry address, registry runtime hash, usecase, and `gateConfigHash()`.
The gate config hash commits the profile version, chain, Core, registry address,
registry runtime hash, and usecase. The phase must select that exact gate and
config hash. Manager admission projects its canonical module record into
`phaseGate.gateMetadataHash` as
`keccak256(abi.encode(MODULE_VERSION, moduleManifestHash))`; the gate verifies
this commitment and its own code hash at validation time. Registering arbitrary
metadata does not satisfy this gate's manifest check.

Only the passed Manager may call `validateMint`, and its `core()` and
`phaseGate(collectionId, phaseId)` must match the gate. The Manager remains
responsible for executor authorization, active module checks, policy selection,
phase timing, revocations, and atomic mint accounting.

## Request and identity

Keep the participants separate:

- `payer`: the hot wallet with live delegated authority.
- `executor`: the authorized caller or sale adapter; it may differ from payer.
- `authorizer`: zero, with returned kind `NONE`; registry eligibility is not an
  EOA or Safe signature.
- Every `initialRecipients[i]` and `beneficiaries[i]`: the same vault, distinct
  from payer. Mixed vaults require separate mint requests.
- `gateData`: exactly `abi.encode(vault, nonce)` where `nonce` is a `bytes32`.

The gate returns an authorization ID committing the entire request plus
deployment chain, gate address, and config hash. `MintRequest` in the concrete
contract lists the fields in their encoding order. For client computation:

```solidity
authorizationId = keccak256(abi.encode(
    keccak256("6529STREAM_DELEGATE_MINT_AUTHORIZATION_V1"),
    deploymentChainId,
    gateAddress,
    gateConfigHash,
    mintRequest
));
```

The returned nonce nullifier commits its own domain, chain, gate, Manager,
collection, phase, payer, vault, and nonce. Changing quantity, executor, context,
or policy changes the authorization ID but retains that nullifier. Reusing it
must revert through Manager/Ledger. A fresh nonce allows another eligible mint
only within the remaining counter limits. Registry authority is rechecked on
every mint, including a fresh nonce after revocation.

## Allowance policy and acceptance boundaries

Configure per-holder counters with `RECIPIENT` keys, which resolve to the vault.
The gate alone supplies no allowance cap. `PAYER` keys would count separate hot
wallets independently and are unsuitable for vault-holder limits. Collection
and GLOBAL cap policy belongs to the counter engine; the gate does not change
scope domains or consume counters itself.

The focused unit suite uses real Safe 1.4.1 factory/proxy/handler bytecode and
threshold-signed Safe transactions to grant and revoke registry authority. It
also delivers an ERC-721 receipt to that Safe and checks ownership. Its registry
is an explicitly typed delegate.xyz ABI fixture; Manager, replay consumption,
and ERC-721 minting are focused boundary fixtures. These cases do not prove
current StreamCore/Manager/Ledger integration, deployed upstream registry
conformance, collection/GLOBAL cap enforcement, or replacement continuity.
Those acceptance joins belong in the combined current-stack suite.
