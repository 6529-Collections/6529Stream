# Permit capability attestations

`StreamAssetPolicyRegistry` now has an independent, governed permit-capability
record. This is a prerequisite for the universal payment adapter. It does not
itself execute permits or change the existing allowance-pulling sale adapters.
An ACTIVE token is not automatically approved for any permit path.

Use [IStreamAssetPermitPolicy](../../smart-contracts/interfaces/stream/revenue/IStreamAssetPermitPolicy.sol)
to read `assetPermitPolicy(asset)`. Its eight words contain capabilities,
Permit2 allowance mode, Permit2 address/runtime hash, asset runtime hash,
asset policy hash/revision, and the attestation's own revision.

| Field | Supported values |
| --- | --- |
| `capabilities` | 0 revoked; bit 1 canonical EIP-2612; bit 2 single Permit2 SignatureTransfer; 3 both |
| `permit2AllowanceMode` | 0 without Permit2; 1 every allowance decrements; 2 uint256.max stays unchanged, finite allowances decrement |
| `permit2`, `permit2CodeHash` | Both zero without Permit2; otherwise deployed nondelegated code and its exact expected hash |

A consumer must independently require current ACTIVE asset status, matching
asset runtime, policy hash and revision, the selected capability, and matching
its own immutable supported Permit2 target/runtime/chain. A returned nonzero
record alone proves none of those current facts. Code hashes do not discover
implementation changes hidden behind a proxy; approving such a token requires
an asset-policy model that can account for that limitation.

Configure the record through the canonical Governance-V2 authority's class-1
action, using `assetPermitPolicyTransitionHashes(asset,capabilities,mode,
permit2,expectedPermit2CodeHash)` to bind the reviewed transition. The target
checks the exact scope, previous state, proposed state, class and nonzero action
ID. It has no owner, allowlist or emergency bypass. The constructor is unchanged.
The new mutation selector must be included in the relevant governance catalog.

The scope is `keccak256(abi.encode(keccak256("6529STREAM_ASSET_PERMIT_SCOPE_V1"),
chainId,registry,asset))`. Each state hash encodes
`keccak256("6529STREAM_ASSET_PERMIT_STATE_V1")`, that scope and the entire
eight-word record. The proposed record captures the current asset runtime and
current asset-policy hash/revision. Code or policy drift while an action waits
therefore changes its required new-state hash and makes the old action fail.

After execution, any new asset-policy revision leaves the permit record stale.
It is never silently renewed, even if status and evidence later return to their
old values. Reattesting those new facts requires a new exact action and advances
the permit revision. An identical no-op rejects. Capability zero revokes permit
admission and remains available while an asset is inactive or deprecated.
Neither attestation nor revocation changes asset status, release grace, wallet
observation or already owed balances.

`AssetPermitPolicyUpdated` emits the asset, exact `keccak256(abi.encode(record))`,
schema version 1, revision and action ID. The complete record can be recovered
from the transaction and readback. Existing asset-policy ABI objects and storage
roots remain unchanged; the permit records and last-action IDs append two maps.

Focused tests exercise exact transition/event preimages, stale runtime and ABA
policy revisions, revoked and malformed capabilities, delegated-code rejection,
and a real Safe's reads, direct authority rejection and authorized forwarding.
The governance authority in those tests is an explicit action-context fixture;
it does not establish the full Executor timelock/catalog integration. The
Permit2-shaped target there tests identity attestation only. Actual permit
execution and official Permit2/Safe transfer behavior belong to the universal
settlement consumer tests.
