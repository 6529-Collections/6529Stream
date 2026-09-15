# Native sale surplus recovery

This source increment implements the native-asset portion of SSA-ADAPTER rule
15 and the emergency accounting rules in ADR 0004. It is local implementation
with authored regression tests and targeted type/size checks; native execution,
joined release acceptance and transaction-capacity evidence remain pending.

## Supported hosts and accounting

The fixed/open/free/pay-what-you-want, Dutch, clearing, refund-window, native
English/custody auction, and private/offer/inventory hosts advertise the additive
`IStreamNativeSurplus` capability. Original selectors, signature domains, storage
roots, credit getters and withdrawal exits remain intact. No constructor or
payable receive/fallback is added.

| Host | Existing aggregate excluded from surplus |
| --- | --- |
| Native fixed and price programs | `refundLiability` |
| Native Dutch | `refundLiability` |
| Native clearing | `totalBuyerLiabilities()` |
| Native refund window | `totalBuyerLiabilities()`, including pending deposits |
| Native English and custody | `totalBuyerLiabilities()`, already including live bids |
| Native private/offer/inventory | Original accounting `totalLiabilities`, including consignor proceeds, buyer excess and undelivered royalties |

`nativeSurplusState()` reports balance, liabilities, available native surplus,
sweep revision, cumulative swept value and last action ID. It remains readable
without mutable provider admission. An insolvent host reports zero available
and retains the actual balance and owed total for diagnosis. Forced ETH is
included in available surplus; it never creates a credit or official revenue.
No ERC-20 balance, transfer, fee conversion or NFT transfer is part of this API.

## Exact governance workflow

1. Admit the exact host runtime and `sweepNativeSurplus(uint256,bytes32)` selector
   as a zero-value delayed class-1 operating-policy call through the existing
   governed catalog process. Deployment of a host does not grant this policy.
2. Resolve `ROLE_EMERGENCY_RECIPIENT` to one nonzero current address in the actual
   Executor-owned RoleRegistry. The host itself cannot be its own recipient.
3. Call `nativeSurplusQuote(amount, reasonHash)` for a positive amount and nonzero
   incident/reason commitment. The amount must fit `balance - liabilities`.
4. Use its exact `scopeHash`, `oldValueHash` and `newValueHash` as the original
   Governance-V2 **per-call** commitments. Schedule the unchanged call bytes
   with zero ETH. A batch wrapper must derive its separate aggregate hashes
   through the existing batch helper, not reuse these per-call hashes.
5. Execute after the actual delayed window. The host independently requires the
   immutable canonical Executor caller, executing class 1, nonzero action ID,
   and exact three commitments. It resolves the recipient again; no caller may
   supply an arbitrary recipient or substitute an asset.

The fixed worker reads only the actual host's original immutable getters via
exact fixed-size self-staticcalls. It authenticates the original Core's current
ModuleRegistry pointer, original registry/runtime, its canonical Executor, the
Executor marker and current role registry ownership/capability. The quote binds
the selected recipient, role registry/code hash, role-specific mutation chain
and revision, and Executor code hash. A recipient round trip A → B → A changes
the authority commitment. No Artist signature or sale admission substitutes for
this governance authorization. Hosts with no immutable governance authority
cannot sweep; their old claims remain usable.

Scope is `keccak256(abi.encode(keccak256("6529STREAM_NATIVE_SURPLUS_SCOPE_V1"),
chainId, host, Context(core, coreCodeHash, registry, registryCodeHash, authority)))`.
The request hash binds `keccak256("6529STREAM_NATIVE_SURPLUS_REQUEST_V1")`, amount,
reason and the complete returned authority tuple. Each old/new state hash binds
`keccak256("6529STREAM_NATIVE_SURPLUS_STATE_V1")`, scope, request hash, unchanged
liabilities, revision and cumulative swept total. The new revision increases by
one and the new total increases by the requested amount. Same-action replay is
an auxiliary append-only guard. A batch may sweep different hosts, but cannot
sweep the same host twice under one action ID.

Physical balance is a live solvency bound, not the state commitment. This lets
unsolicited donations before execution or during the recipient callback remain
surplus. Changed liabilities or an intervening sweep require a fresh quote and
new governance action. Nothing can sweep an owed balance to make a quote fit.

## Callback, receipts and withdrawal liveness

The original host guard surrounds the entire sweep and returns normally, so
guard cleanup executes. Before the transfer, the worker records the revision,
total and used action. A failed recipient call reverts that state together with
the transfer and Executor/Safe execution. Retrying the exact scheduled action
and serialized Safe transaction is possible after the recipient is repaired.

After payment the worker repeats canonical authority, current recipient/role
history, and exact in-flight action checks. It requires unchanged persistent
sweep state, unchanged owed total and sufficient balance. Extra ETH received
during the callback is allowed and remains surplus. Existing credited accounts,
live bid deposits, pending purchase deposits, royalties and NFT custody are
untouched. Own-account withdrawals keep their original authorization and remain
independent of surplus and mutable provider availability.

The canonical `AdapterSurplusSwept(uint16,address,address,uint256,bytes32)` event
retains its original indexing and schema-1 payload, with native asset zero.
`NativeSurplusSweepRecorded` additionally records host, actual caller, action ID,
recipient, scope domain, reason, amount, actual resulting surplus, revision and
cumulative total. No event relabels surplus as official sale revenue.

## Verification scope and remaining export work

The new test source covers actual governance/Safes and real current ledger
credits in fixed, Dutch, clearing and refund-window flows; it also exercises
donation-only recovery on actual-graph English and private hosts before sale
admission. The latter cases do not claim a new paid custody or inventory join.
Assertions cover forced ETH, canonical event coordinates, original withdrawals,
pending-deposit deadline escape, callback reentry, callback donation, stale role
and state commitments, underfunding, and a byte-identical failed/successful Safe
execution with an exact two-transfer-call witness. Native tests are authored,
not claimed executed by this source handoff.

Complete LTA-EXPORT sale-credit publication is separate remaining work. The
existing StateExport host publishes authenticated snapshot commitments; it does
not enumerate sale creditors or prove complete ledger coverage. Several sale
ledgers still need append-only key enumeration at their original credit-creation
sites and a pinned transcript/export producer reading those ledgers. A supplied
account list or aggregate total alone is insufficient. Retired adapters with
outstanding debt must remain in that historical export scope.
