# Ordered Safe CALL plans

Use `createSafeCallPlan` with prepared calls and the exact ABIs selected from
your compiler output. It accepts any state-changing selector in those ABIs,
including ownership and admin actions, ERC-20/ERC-721 approvals, claims, custody
activation, bids and value-bearing purchases. The caller provides a short intent
for each step; the client independently decodes its actual arguments. Integer
arguments and native values remain exact decimal strings in the readable plan.

```typescript
import { createSafeCallPlan, verifySafeCallPlan, simulateSafePlanStep,
  safeCallInventory } from "@6529/stream-client";

const plan = createSafeCallPlan(chainId, "Approve then acquire", [
  { safe: collectorSafe, intent: "Approve the exact payment allowance",
    call: tokenApproval, abi: compiledERC20ABI },
  { safe: collectorSafe, intent: "Buy this work for the reviewed total price",
    call: purchase, abi: compiledSaleABI },
]);
const catalog = [compiledERC20ABI, compiledSaleABI];
verifySafeCallPlan(plan, catalog);
await simulateSafePlanStep(provider, plan, catalog, 0);
// Present plan.steps[0].transaction to the collector's Safe integration.
// After its confirmed execution and allowance readback, simulate step 1.
```

Every transaction has `operation: 0`, the exact target, calldata and native value.
The client rejects unknown selectors, reads presented as transactions, trailing
ABI bytes, unsafe numbers and value attached to a nonpayable method. It does not
create a MultiSend batch. Different steps may require different Safes; never
submit an owner action from the Artist Safe merely because that Safe signed the
Artist approval. If the target owner is a GovernanceExecutor, wrap the target
call using that executor's governed scheduling workflow. Its address is not a
Safe and cannot be impersonated by a Safe plan.

For Solidity's non-function entry points, set `route: "receive"` or
`route: "fallback"` on that step. The selected compiler ABI must contain the
corresponding handler. Receive requires empty calldata. Fallback preserves all
calldata as its reviewed argument, rejects any known function selector, and
rejects empty calldata when the ABI also declares receive because Solidity will
dispatch that call to receive. Fallback calls may carry value only when the ABI
marks fallback payable; receive is payable by Solidity definition. Raw calldata
is never inferred to be fallback when `route` is omitted. Mixed function,
receive and fallback steps keep their order and use ordinary Safe `CALL`.

`safeCallInventory(abi)` lists **all** supplied state-changing signatures,
selectors and payable flags. It is a caller inventory, not proof that each
selector has run through Safe 1.4.1 or that the deployed contract matches the ABI.
The package tests use retained compiler-derived interfaces; current full-graph
Safe acceptance remains the integration task's responsibility.

## Independent reconstruction

`verifySafeCallPlan` re-decodes the executable bytes and reconstructs arguments,
method signatures, step hashes and the final plan hash. It returns a new frozen
plan. A changed argument display, caller, target, method, order, value or intent
fails comparison. The plan hash is an application review commitment, **not a Safe
transaction digest**, contract authorization or a signature request.

The step preimage uses `abi.encode` of:

```text
bytes32 keccak256("6529STREAM_SAFE_CALL_PLAN_STEP_V1"),
uint256 chainId, uint256 index, address safe, address target,
uint256 value, bytes32 keccak256(calldata),
bytes32 keccak256(UTF8(functionSignature)), bytes32 keccak256(UTF8(intent))
```

The plan preimage uses `abi.encode(bytes32 domain, uint256 chainId,
bytes32 titleHash, bytes32[] stepHashes)`, with domain
`keccak256("6529STREAM_SAFE_CALL_PLAN_V1")` and titleHash `keccak256(UTF8(title))`.
These versioned application hashes grant no onchain authority.

## Ordering, receipts and retry

`simulateSafePlanStep` checks chain identity and performs one target-level
`eth_call` from the exact selected Safe. It returns raw target bytes. It does not
establish Safe owners, threshold, signature validity, target code identity, ERC-20
return-value success or mined state, and it does not apply earlier calls. Simulate
dependent steps only after required predecessor effects exist, or use an actual
Safe/current-component integration rehearsal with transaction rollback.

For each submitted step, journal its chain, Safe, exact call, Safe transaction
hash, Safe nonce and outer transaction hash. Use `requireSafeExecution` with the
independently verified Safe transaction hash and confirm target events/readback.
A successful outer receipt alone can contain `ExecutionFailure`.

After a failed target call, reread the original protocol nonce/domain and current
state and re-simulate the retained plan step. The target bytes/value remain
identical. Safe `execTransaction` can consume its own nonce even when the target
fails; the retry may therefore need a new Safe envelope and new Safe signatures.
Never claim the outer Safe transaction itself is byte-identical. If the target
actually succeeded, determine its effects before attempting any retry.

Native value comes from the executing Safe's balance. ERC-20 allowances belong
to that Safe and must name the actual spender for the current flow. ERC-721
approval must cover the currently owned token and intended custody contract.
Read balance, allowance, ownership and the selected contracts before signing;
simulation cannot reserve any of those facts until mining.
