# Additive ERC20 commerce deployment and activation

The three helpers in `script/current` construct and plan admission for four
products against an existing current contract graph. They do not change the
37-product genesis list or broadcast merely by preparing a plan.

| Position | Product | Original Registry role |
| --- | --- | --- |
| 0 | `StreamERC20PrimarySettlementAdapter` | `ERC20_PRIMARY_SETTLEMENT_ADAPTER` |
| 1 | `StreamUniversalFixedPriceSaleAdapter` | `FIXED_PRICE_SALE_ADAPTER` |
| 2 | `StreamUniversalAllowlistPriceSale` | `FIXED_PRICE_SALE_ADAPTER` |
| 3 | `StreamERC20DutchSale` | `DUTCH_AUCTION_ADAPTER` |

All four use the original `6529STREAM_UNIVERSAL_SETTLEMENT_V1` module version.
Payment registers its original Payment interface; each carrier registers the
original ERC20 sale-execution interface. The Dutch-specific capability and
profile are additional predicates in its existing admission path. The Price
carrier supports same-leaf fixed or explicitly declared zero prices. Dutch
supports the separate standard schedule profile; clearing rebates remain outside
these helpers.

## Construction record

`StreamERC20CommerceDeployment.Configuration` supplies the actual Recorder,
Manager, Artist, RoleRegistry, governance authority, carrier owner, platform
signer, optional Permit2 pair and original gas configurations. Permit2 address
zero requires hash zero. A configured Permit2 must be actual pinned contract
code. The three carriers transfer ownership to the supplied owner. Payment has
no owner, approval writer or new administrative path.

`constructorArguments` returns the exact four original ABI argument encodings.
`deploy` uses ordinary CREATE and returns `Products`: chain, full configuration
and hash, addresses, runtime hashes, constructor-argument hashes, four dependency
runtime hashes and the two manifest commitments. `validate` rechecks those pins,
original Core/Registry and Recorder reciprocals, Permit2, owner/authority,
Artist/Manager and constructor gas facts. Authorized monotonic gas raises are
permitted while original floors and failure classes stay exact.

These saved coordinates are operator-verified deployment metadata, not proof
that arbitrary code implements the products. Pin and verify the exact compiler
input, creation artifacts, linked libraries and runtime before accepting a
construction record. The helper rejects empty/delegated code and runtime sizes
over 24,576 bytes. It does not replace the normal creation-size admission gate.

`DeployERC20Commerce.run` is restricted to Anvil or Sepolia. It obtains only
`STREAM_DEPLOYER` as an address; Foundry receives signer material independently.
No broadcast has been performed for this feature. Actual broadcast consists of
separate CREATE/ownership transactions, so record receipts and confirmed
addresses and inspect any partial execution before retrying.

## Dependent activation steps

1. Verify the existing Core/Registry, current Manager and Artist, Recorder,
   resolver, split factory, asset policy registry, RoleRegistry and governance
   authority. Complete original revenue runtime admission and both factory and
   escrow opt-ins. `requireRuntimeActivated` checks their actual common binding.
2. Construct the four products and retain the exact `Products` record. Obtain
   `policies` and use `catalogAdditions` against the operator's authenticated
   original catalog plus executed extensions. The returned entries are strictly
   sorted class-one, zero-value CALL policies: original Registry registration,
   Manager executor admission and the three carrier gas-raise selectors. Existing
   compatible profile hashes are retained. No sale-owner authority is granted.
3. Use `admission` to obtain four exact original Registry transition calls. The
   plan commits their sequential registration chain/count. It requires all four
   addresses unregistered. Complete original catalog, scheduling, delay,
   execution and any required manifest tail through the existing governance
   tooling. Reobserve after dependent actions; preserve scheduled calldata.
4. Once products are ACTIVE, use `phasePolicy` for one carrier and one actual
   phase. It reads all current config, gate, counters and executor order, proves
   that their preview equals the stored policy hash, then appends the carrier
   exactly as the original Manager does. It refuses frozen phases, existing
   executors, noncurrent Core selections and inactive product/Payment records.
5. Obtain original Artist consent for that exact prospective hash. `phaseCall`
   requires both a retained nonzero consent record and the original current
   `requireMintConsent` check. It returns the actual Manager owner and ordinary
   zero-value call. A Safe owner executes a Safe CALL. If the owner is the bound
   Executor, `governedPhase` supplies the class-one governance plan. A different
   owner is never silently treated as the Executor.
6. Execute and reobserve the actual phase. Admit an asset and any supported
   permit policy through the existing asset-registry procedures; create sale
   programs through each carrier's actual owner/current signer route and obtain
   the original Artist sale/economics consent. These helpers do not fabricate
   signatures, approve token spending, normalize a free outcome into revenue,
   or grant entropy requester authority. Existing reveal/refund and floor checks
   still apply during purchases.

Each prospective phase hash describes the observed state. An intervening phase,
rights, pointer or consent change may invalidate the saved plan; the original
Manager rechecks its actual policy and consent when the call executes. Catalog
inventory supplied to the planner is not new onchain authority; the original
Executor remains the authority for admission and execution.

## Validation boundary

Thirteen focused cases passed on the frozen helper source using actual four-product artifacts, Core,
Manager/Ledger, Registry/Recorder and an upstream threshold Safe. They check
literal constructor arguments and roles, registration transitions, sorted and
conflicting catalogs, complete phase hashes, consent refusal/retry, actual owner
versus Executor routing, runtime/chain/Permit2/gas faults and missing runtime
activation. Artist, entropy and target-side governance remain explicit inherited
typed boundaries. Product construction in this suite uses the original literal
arguments with genuine artifact CREATE; the script's broadcast entry has not been
executed. The unchanged production code-size gate is retained.

The source passes the 517-source Solidity ABI/type check. The separate native
capture at `3cc3091d` (helper `3357af3e` plus the existing metadata-URI fixture
correction) passes all thirteen cases in 3.48 seconds. Its 525 retained source
files match Git; all 199 artifacts are authenticated against genuine native
compiler outputs, with every one of the 196 production products below the
original runtime and creation limits. The four product runtimes are Payment
19,589, fixed carrier 23,708, Price carrier 22,005 and Dutch carrier 24,538 bytes.

The isolated build reuses the closed Dutch capture only where source and artifact
bytes match. Original production bytecode and raw metadata remain exact; new
selected artifacts are verified against one genuine final compiler output and
its complete linked-library closure. Testing invokes no compiler and changes no
artifacts. An actual delayed-governance/current-stack activation ceremony and
the broadcast script remain unexecuted. Earlier sale tests remain evidence only
for their own captured source.
