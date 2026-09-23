# Burn program warnings before collection closure

`inspectBurnFinalityImpact` joins retained burn-to-mint and redemption programs
to their source and target collections before a proposed collection burn block,
freeze or collection finality action. The report names each affected program,
its role for the collection, current blockers and the proposed action's effect.
It prepares no transactions and establishes no governance authority.

## Supply the exact deployment and discovery range

Pass the chain, concrete block number and hash, and verified runtime code hashes
for Core, the module registry, artwork finality registry and every relevant
`StreamBurnMintGate`, `StreamERC20BurnMintGate` and `StreamBurnRedemption`
deployment. Pin each dedicated ERC20 gate's immutable `StreamERC20BurnMintSale`
carrier separately. Each program host
also needs an explicit `fromBlock`. Use its deployment block when the review
needs its entire history through the pinned block.

```js
import { inspectBurnFinalityImpact } from "@6529/stream-client";

const report = await inspectBurnFinalityImpact(provider, {
  chainId,
  core: { address: core, codeHash: coreCodeHash },
  moduleRegistry: { address: registry, codeHash: registryCodeHash },
  finality: { address: finality, codeHash: finalityCodeHash },
  burnMintDeployments: [{ address: gate, codeHash: gateCodeHash, fromBlock: gateDeploymentBlock }],
  erc20BurnMintDeployments: [{
    address: erc20Gate, codeHash: erc20GateCodeHash, fromBlock: erc20GateDeploymentBlock,
    saleAdapter: { address: erc20Sale, codeHash: erc20SaleCodeHash },
  }],
  redemptionDeployments: [{ address: redemption, codeHash: redemptionCodeHash, fromBlock: redemptionDeploymentBlock }],
  action: { kind: "collection-finality", collectionId },
  blockNumber,
  blockHash,
  limits: { maxBlockSpan: 100_000, maxLogs: 1_000, maxPrograms: 100, maxCollections: 256 },
});
```

Other action kinds are `block-burns` and `freeze`. These are collection actions.
TOKEN, RELEASE, SEASON and VIEW finality are separate scopes; this helper does
not treat them as collection closure and does not accept them as action kinds.

`erc20BurnMintDeployments` is optional for existing callers. Omitting it means
dedicated ERC20 gates are outside the supplied inventory. A supplied gate's
ERC165 declaration must match its inventory kind; putting a dedicated ERC20
gate in `burnMintDeployments` fails inspection. Its program uses the original
config encoding with zero native-sale fields, so those fields alone cannot
identify it as free. Reports label it `erc20-burn-mint` in programs and coverage.
Multiple ERC20 gates may share a carrier with the same address and code hash.

There is no all-program getter. Discovery reads `BurnMintProgramConfigured`
events for mint targets and redemption `SaleConfigured` (kind 9) plus
`RedemptionTermsRecorded` events. It checks their exact emitter, canonical
encoding and immutable fields against current program getters. Each burn-mint
program's `allowedSourceCollections` must agree with its complete stored config.
The report includes the supplied coverage ranges. Missing deployments, earlier
history or omitted RPC logs cannot be proven absent by this helper. Do not
describe a partial range as a complete protocol inventory.

The caller sets finite discovery limits. Excessive ranges, counts, malformed
responses, mismatched dependencies, unknown collections and changed block
hashes fail the inspection. Reads use the same pinned block. Preserve the
returned report with the proposed action, then refresh it before execution.
The report retains its normalized request, including addresses, code hashes,
limits and discovery ranges, so its collection IDs remain tied to the reviewed Core.

The supported read profile requires the supplied module and artwork finality
registries to be Core's current selections. An immutable program whose mint
manager is no longer selected remains in the report with a dependency blocker.
Runtime bytes, immutable Core/registry bindings and event/program commitments
must still agree. For ERC20 programs, the gate's immutable carrier address and
code hash, the carrier's Core/registry addresses and code hashes, and its
Manager address and code hash must also match the pinned environment and
retained program. The dedicated program must have `prepared = false` and
zero native-sale fields. These checks also run for supplied ERC20 deployments
with no discovered programs, except the program-specific Manager comparison.
The client caps each program kind at 16 supplied deployments,
each discovery range at 1,000,000 blocks, total logs at 4,096, programs and joined
collections at 256 each, RPC return data at 8,192 bytes and finality URI text at
2,048 UTF-8 bytes. These are client inspection limits, not new contract rules.

## Interpret the report

Review source and target roles independently; one collection can have both
roles in the same or different programs.

| Fact or action | Source burn path | Target mint path |
| --- | --- | --- |
| Permanent collection burn block | Stops use of every token in that source collection | Does not itself change mint admission; Core requires closure before applying the block |
| Collection freeze | Stops source burns | Core requires the collection to be closed already |
| Collection-scope finality | Requires collection-wide closure and burn restrictions | Requires minting already closed |
| Paused collection | Core's native burn does not use mint status as a burn restriction | Stops current minting; pause alone is reversible |
| CAPPED_OPEN or UNCAPPED_OPEN | Source eligibility still depends on burn restrictions | An open supply mode alone does not close minting |
| Reached finite lifetime cap | Burning does not restore mint capacity | `mintedEver` counts lifetime mints; a capped-open cap may still be governed upward |

Core requires `CLOSED` before `blockCollectionBurns`, and `CLOSED` plus an
existing burn block before `freezeCollection`. Collection finality requires
`CLOSED`, blocked burns and Core freeze for every supply mode, including an
exhausted FIXED collection. The report exposes the relevant Core prerequisites.
It is not a finality preview: artwork evidence, consent,
governance scheduling and other execution conditions require their own checks.

Collection-level finality is read from `collectionFinalityRecord` and the
canonical COLLECTION scope (`scopeType = 0`, token ID zero, scope ID zero).
`finalityStateForScope` belongs to component hosts, not the artwork finality
registry. A finalized token or release does not imply that the whole collection
is finalized. Keep an explicit burn path and suitable scoped finality when the
collection's future burn programs must remain usable.

Program timing and redemption cancellation are reported independently. An
expired or cancelled program remains visible as historical evidence. Blocking
one permitted source collection does not prove that every alternative source
has become unusable. Empty warnings do not establish execution readiness:
token ownership, separate caller and gate approval, phase admission, registry
lifecycle, signatures, payment and gas still apply to actual execution.

## Evidence boundary

The [fixture generator](../scripts/generate-current-burn-finality-fixture.mjs)
extracts exact read/event ABI entries from the retained 2,098-source compiler
capture at `2e0fca1a`. The ten selected source files are byte-identical at
integration `5ae32cdf`. The original [burn-to-mint client](current-burn-mint.md)
continues to own execution preparation.

Dedicated ERC20 reads and the gate interface identifier are checked against
the existing [ERC20 fixture](../test/fixtures/current-erc20-burn-mint-abi.json)
from compiler capture `c717a3e1`, feature source `83c67868`. The dedicated gate,
carrier, gate interface and shared settlement context have identical literal
Git source hashes at this extension's base `c7463363`. No new Solidity
compilation or runtime execution is implied by this client extension. The
[dedicated ERC20 client](current-erc20-burn-mint.md) owns payment and execution
preparation; this warning report does not inspect individual sale records,
asset policy, payer authorization, payment settlement or reveal funding.

Client tests exercise immutable event joins, collection-role warnings,
malformed RPC responses and pinned-block behavior. They do not establish
current-stack execution, real Safe governance, gas, deployment or release
acceptance.
