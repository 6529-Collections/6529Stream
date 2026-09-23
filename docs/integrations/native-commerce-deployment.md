# Deploy and activate native commerce

Use [DeployNativeCommerce](../../script/current/DeployNativeCommerce.s.sol) to add
the official recorder and native auction house to an existing current Stream
contract graph. It supports local Anvil (31337) and Sepolia (11155111). These new
products are separate from the immutable RC1 release.

## Required inputs

Keep the original deployment manifest hash and the module manifest with the
operator's source, compiler and transaction records. Supply the actual selected
Core/Registry and Manager, resolver, escrow, factory, asset policy, Artist,
entropy, role registry and governance authority. The house configuration also
contains the platform address, optional delegation registry and explicit read,
signature, reveal and NFT-delivery budgets.

The Manager must not already have a prepared-native recorder. The configuration's
recorder field must be zero: `run` creates the recorder and uses that same address
when creating the house. An existing binding cannot be replaced by running this
script again.

Set `STREAM_DEPLOYER` to the public broadcaster address. Supply the signer through
Foundry's normal account or unlocked-node options. The script does not read signer
material. Use the function's compiled ABI for the configuration tuple; do not pass
an older deployment checkpoint tuple to this entrypoint.

Retain the returned `StreamNativeCommerceDeployment.Products`:

| Field | Meaning |
| --- | --- |
| `chainId` | Chain on which the pair was constructed |
| `recorder`, `house` | Original product addresses |
| `recorderCodeHash`, `houseCodeHash` | Their runtime commitments |
| `deploymentManifestHash` | Original deployment identity |
| `moduleManifestHash` | Recorder module identity |
| `houseModuleManifestHash` | House identity, including its declared delegation manifest when configured |

The returned coordinates must be checked against the actual transaction receipts
and original deployment inputs. A caller-supplied runtime hash is not independent
source verification. Resume an interrupted broadcast using its original Foundry
transaction journal. A fresh `run` creates a fresh pair; it is not a lookup or a
replacement for the original journal.

## Activate through the existing governance root

Deploying the pair grants no module admission, escrow permission, phase authority
or Artist consent. Prepare each next stage after the previous stage's confirmed
execution, using the same original product coordinates.

1. Read the original genesis catalog and executed catalog extensions. Pass that
   verified inventory to `prepareCatalogAdditions(products, knownEntries)`. The
   helper returns missing exact intents and preserves compatible existing profile
   hashes. The inventory argument is operator evidence; the helper does not
   reconstruct its history. Use `StreamGovernanceCatalogStagePlan` for ordinary
   class-three catalog chunks and their matching SystemManifest updates. If the
   returned additions are empty, verify the already-admitted catalog and skip
   extension; the catalog planner does not accept an empty inventory.
2. Call `prepareAdmission(products)` and retain its exact three-call batch: ACTIVE
   recorder registration, ACTIVE house registration and recorder credit-producer
   admission in the original escrow. Execute the class-one batch through the
   original Executor after its normal delay. Its returned four base intents omit
   the custody binding; use `prepareCatalogAdditions` for the full five-intent set.
3. Read the Manager's actual owner. If it is the original Executor, use
   `prepareGovernedManagerBinding(products)` for a class-one delayed batch. If a
   Safe directly owns the Manager, use `prepareManagerBinding(products)` and have
   that Safe call the returned target and calldata. Read back
   `preparedNativeRecorder()` and its binding event.
4. Call `prepareCustodyBinding(products)` after both modules are ACTIVE. This
   produces the original recorder's exact class-one, zero-value house binding.
   Schedule and execute through the original Executor, then read back
   `canonicalCustodyHouse()` and `CanonicalCustodyHouseBound`. The stored times
   are observations at execution, not the earlier scheduling time. Binding is
   one-time.

[StreamGovernanceStagePlan](../../script/current/StreamGovernanceStagePlan.sol)
prepares publication and scheduling calldata. A Safe governance root uses its
ordinary threshold transaction to submit the returned calls. Keep the saved plan
and action ID; verify confirmed execution and the actual postconditions before
resuming. Skip completed admission or binding stages instead of rebuilding their
one-time calls. A catalog extension
invalidates actions scheduled under its previous catalog epoch, so schedule the
later admission and binding batches after that extension completes.

The Safe root proposes governance actions; it is not automatically the owner or
Executor of every target. Directly calling the recorder's custody binding from
the root Safe fails when the original Executor is its authority.

Finally configure the phase executor and obtain the exact Artist consent using
the [mint setup guide](current-mint-setup.md). Follow the
[auction guide](native-deferred-auctions.md) for signing, curated publication or
custody acquisition. Module registration does not substitute for these steps.

## Validation boundary

The deployment helper has independently reviewed actual-contract admission and
Safe owner retry coverage. The actual Safe/Executor activation test is
[StreamNativeCommerceGovernanceTest](../../test/current/StreamNativeCommerceGovernance.t.sol).
Its four actual governance cases pass alongside twelve deployment and nine
custody regressions, including three 256-input properties. The capture uses real
Core, Safe, Executor, Registry and commerce contracts with typed Artist/entropy
boundaries; it precedes the later template-rights and consent-provider increments.
Local test evidence, actual broadcast capacity and a newly frozen testnet
candidate are tracked separately in the
[delivery ledger](../../ops/V1_DELIVERY.md).
