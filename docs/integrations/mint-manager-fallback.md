# Standing mint Manager fallback

`MINT_MANAGER_FALLBACK` is a distinct, pre-admitted Manager in the genesis
inventory. It uses the original Core and authoritative Ledger. It is registered
under the existing `MINT_MANAGER` module type and interface; it does not create
another Core pointer family. Activation replaces the existing Manager pointer.

This implementation consists of the dedicated
[`StreamMintManagerFallback`](../../smart-contracts/domains/mint/StreamMintManagerFallback.sol),
its fixed linked
[`StreamMintFallbackRecovery`](../../smart-contracts/domains/mint/StreamMintFallbackRecovery.sol)
worker, and the stateless
[`StreamMintFallbackPlan`](../../script/current/StreamMintFallbackPlan.sol)
planning library. The ordinary Manager is unchanged. Full-genesis composition,
actual-current/Safe native acceptance and release evidence remain separate
integration work; the focused acceptance below does not establish deployment readiness.
The recovery interface is an explicit ABI for the pinned fallback runtime;
inherited Manager ERC-165 interface advertisement is unchanged.

## Genesis configuration

Deploy the fallback with `(core, canonicalLedger, moduleRegistry)`, grant its
Ledger writer permission, and transfer its owner to the same GovernanceExecutor
used by the primary Manager and registry. Pin all addresses, runtime hashes,
chain ID and module metadata in `StreamMintFallbackPlan.Configuration`.
`validate` checks these bindings and both Managers' independent gate and Artist
gas registrations. Each host starts with its own registered gas values;
raising one host's value does not change the other.

Use `fallbackRegistration` to construct the existing registry registration.
Complete that admission before operational exposure and verify
`requireReserveReady`: the reserve must be ACTIVE, have the exact reviewed
catalog facts, and remain a non-retired writer. The canonical Ledger pointer
must still identify the same Ledger. The full genesis inventory assigns the
distinct Manager to role 35.

For prepared native settlement, bind the original contract-9 recorder to the
fallback with its existing owner-only `bindPreparedNativeRecorder` call after
recorder catalog admission. Supply its address and runtime hash in the plan
configuration: readiness then checks both Managers' recorder bindings, the
recorder's Core/registry pins and its admission lifecycle. A zero recorder pair
is an explicit ordinary-mint-only planning mode; it is not evidence that the
full paid genesis surface is configured.

Mirror the primary Manager's applicable operating policies for the reserve,
with the reserve's actual target and runtime hash. The fallback ceremony also
needs these exact targets and selectors in its action catalog:

| Target | Selector | Class |
| --- | --- | --- |
| Ledger | `retireLedgerWriter` | 0, permanent tightening |
| Ledger | `commitCounterImportRoot` | 1 |
| Ledger | `importCounterDefinitions`, `importMintAncestors`, `completeCounterImport` | 1 for the planned import batch |
| Fallback Manager | `importMintState` | 1 |
| Core | Existing Manager `updateSatellitePointer` call | 3 |
| Fallback Manager | `recoverPreparedMint` | 3, incident only |
| SystemManifest | Existing publication tail | 3 with the pointer batch |

The definition/ancestry copying and import-completion entrypoints remain
permissionless. Catalog entries allow their inclusion in the same auditable
GovernanceExecutor batch. They do not replace the Ledger's own checks. The
ordinary retirement selector retains its owner check; class 0 is the explicit
genesis catalog policy for this irreversible tightening action.

Also execute `retirementClassificationCall` during genesis, as an isolated
class-1 `GovernanceExecutor.setTighteningCall(ledger, retireLedgerWriter, true)`
action with its ordinary delay. A class-0 catalog row alone is insufficient:
Executor checks its separately pinned tightening configuration. The helper
derives the exact configuration transition and `retirementCall` rejects a
missing or stale classification. Finish this prerequisite before incident
response; it must not consume the four-hour incident scheduling window.

## Incident scheduling and real accounting import

1. Record the primary's actual `INCIDENT_REVOKED` transition through a class-0
   governance batch with its required SystemManifest publication tail. The
   genesis registry-status trigger requires that tail even for immediate
   tightening. The replacement is already ACTIVE, so no new incident-time
   admission cycle is needed.
2. Resolve old mint obligations or establish their supported cancellation and
   refund exits. Execute the class-0 retirement call produced by
   `retirementCall`. A disabled writer is insufficient: retirement is permanent.
3. Snapshot after retirement. Publish and review the complete actual counter
   and raw-nullifier manifest, including its descriptor. Follow the original
   [mint continuity proof format](mint-continuity.md#commitment-and-tree).
   A shared Ledger still namespaces accounting by Manager, so a real import is
   required. An empty placeholder import is not a substitute.
4. Schedule the class-1 import and class-3 activation in parallel, with the
   activation scheduled within four hours of the incident. Both retain the
   ordinary 48-hour minimum delay; there is no emergency delay bypass.
5. At readiness, execute the original root commitment, complete profile and
   ancestry copying, every actual leaf import, and descriptor completion before
   executing the pointer action. Larger inventories need bounded repeated
   copying/import calls. The five-call small fixture is not an inventory limit.
6. Execute the already scheduled class-3 activation. Core requires completed
   import for this exact predecessor Ledger/Manager and successor. Execution
   is permissionless once authorized and ready. Premature execution fails
   atomically and leaves the same scheduled action retryable.
7. Record fresh Artist consent, configure the successor's phases and executors,
   and establish explicitly successor-bound sale routes. The retained Artist
   suite keeps its original Manager signing anchor and verifies completed
   ancestry. Neither old consent nor an old adapter is silently rebound.

The helper supplies original calls and exact transition hashes. It does not
broadcast, enumerate the historical snapshot, approve completeness, fabricate
proofs or grant authority. Schedule it against the actual target action catalog.
Use `activationCalls` for the normal two-call Manager-pointer/manifest batch.
The canonical Ledger address and pointer revision remain unchanged.

Original authorization IDs, operation roots, receipts, counters and wallet
proceeds remain in their original domains. Imported counter floors and raw
nullifiers govern new operations in the fallback's domain. New authorization
IDs cannot make an imported spent claim fresh. A return to the retired Manager
is unsupported: address swapping cannot undo retirement or reverse ancestry.
A later replacement needs another distinct live writer and a genuine import.

## A stranded preparation

Normal Manager mint entrypoints prepare and complete atomically. They do not
expose a prepare-only, complete-only or abort forwarding API. A persistent
prepared record therefore represents an incident involving a nonconforming
predecessor, not an ordinary pending mint workflow.

For that incident, `incidentActivationCalls` constructs three class-3 calls:
the admitted Manager pointer replacement, exact `recoverPreparedMint(tokenId,
operationId)` on the dedicated fallback, and the original manifest tail. Its
configured runtime must be the reviewed recovery-capable Manager. The whole
batch rolls back if recovery or manifest publication fails.

Recovery accepts only the Manager's immutable GovernanceExecutor, while that
address is also its owner and the selected registry's executor. It verifies
the actual Core Manager and registry pointer runtime pins, the exact pending
token/operation, and a canonical executing class-3 per-call context. The
inherited reentrancy guard also protects this facade. Its only state-changing
external operation is the existing Core abort hook; it cannot prepare, complete
or redirect a mint.

The independently reproducible commitments are:

```text
scope = keccak256(abi.encode(
  keccak256("6529STREAM_MINT_FALLBACK_RECOVERY_SCOPE_V1"),
  chainId, core, fallbackManager, tokenId, operationId))

retained = keccak256(abi.encode(
  collectionId, collectionSerial, lastAllocatedTokenId,
  collectionNextSerial, collectionMintedEver, totalSupply))

stateDomain = keccak256("6529STREAM_MINT_FALLBACK_RECOVERY_STATE_V1")
old = keccak256(abi.encode(
  stateDomain, scope, true, retained, keccak256(tokenData), coordinatorAtMint))
new = keccak256(abi.encode(
  stateDomain, scope, false, retained, keccak256(bytes("")), address(0)))
```

Read these facts from the incident state with `StreamMintFallbackRecovery.transition`
before scheduling. An intervening change to committed facts, including live
supply, makes that proposal stale and requires a newly authorized proposal.
Execution never silently refreshes its commitments.

Core clears the exact prepared record, identity, token bytes and coordinator
binding. Global and collection allocation frontiers remain unchanged: the
abandoned token ID and serial become permanent gaps. Completed and burned NFT
history, lifetime minted count, live supply and Ledger replay evidence remain
intact. The facade checks those local postconditions and emits
`MintFallbackPreparedRecovered` with the governance action and incident IDs.
The next mint allocates beyond the gap.

## Existing liabilities and evidence boundaries

Already-minted auction custody, pull-refund credits and settlement receipts
retain their original contracts and identities. Their ordinary settlement and
refund APIs handle those obligations. Products that still require the old
Manager to mint must use their documented cancellation/refund exit; recovery
does not give an immutable old adapter a route through the replacement.

The authored acceptance files are:

- [`StreamCurrentMintFallback.t.sol`](../../test/current/StreamCurrentMintFallback.t.sol):
  actual current Core, Artist, Managers, Ledger, registry, manifest and threshold-two
  Safe; standing reserve admission, genuine import, delayed activation, fresh
  consent, replay/caps, exact Safe retry, and old auction custody/refund liability.
- [`StreamCurrentMintFallbackIncident.t.sol`](../../test/current/StreamCurrentMintFallbackIncident.t.sol):
  the actual Safe incident composition, including an explicitly nonconforming
  test predecessor and subsequent genuine ancestry import. Additional authored
  cases burn a completed token during the ordinary delay, reject the stale
  recovery commitments, and require a newly authorized proposal; a separate
  late manifest-tail failure restores the already-aborted preparation, pointer,
  manifest and Safe envelope before a new valid proposal succeeds. These cases
  distinguish reverted execution-trace logs from committed recovery receipts.
- [`StreamMintFallbackRecovery.t.sol`](../../test/unit/mint/StreamMintFallbackRecovery.t.sol):
  production Core/Ledger/fallback with typed governance and dependency fixtures;
  independent hash reconstruction, rejection contexts, runtime drift, event
  identity, callback reentry, rollback and retained completed/burned history.

The 13 focused recovery cases passed native execution on exact source
`d1a58e4403cfbb80d921e117e0a7ac9b90ff61c7`. The capture contains 180 sources,
175 production source files, 192 artifact metadata records and 2,676 matching hash
checks, with no oversized production product. Its ignored local path is
`artifacts/native-assembly/counter-scopes/fallback-recovery-native-d1a58e44-1`;
native JSON SHA-256 is
`2d65bfe3b17d18cc265d72de791c43d14c6c4feeee79a2b8897772d2f56ae62d`.
The nine authored actual-current/Safe cases remain native-execution pending.

The current fixture uses the stated external entropy provider and a typed
lifetime-entitlement gate. It does not establish a first-party migration-stable
eligibility product or the full 37-role genesis composition. ABI/type and selected
production-size checks are separate from native runtime acceptance. The
coordinator must include the exact source and linked artifacts in its frozen
current/Safe capture before marking these cases accepted.
