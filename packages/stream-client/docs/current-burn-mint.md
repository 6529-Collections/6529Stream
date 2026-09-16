# Current burn-to-mint calls

`current-burn-mint.ts` prepares and inspects the current same-transaction
burn-to-mint paths. It does not approve ERC-721 transfers, burn a token, sign a
native sale authorization, send a transaction, or establish production or Safe
runtime readiness. Burn-to-redeem is a separate product.

The checked ABI fixture is bound to source commit
`9310d6e9865db8ffe83fb53c78801ff4151158e3`, its source tree, and the exact
999-source compiler input, output, and source-binding capture. It establishes
source and encoding provenance only. Client tests use synthetic RPC responses;
actual current-stack and Safe workflow acceptance is separate integration evidence.

## Immutable program configuration

`BurnMintProgramConfig` contains the selected current Manager, target collection,
phase, sorted source-collection set, source-to-mint ratio, optional inclusive
time window, prepared/free selection, and optional native fixed-price adapter.
The allowed collection set contains 1 to 64 strictly increasing IDs. One actual
burn call contains at most 16 strictly increasing token IDs.

`burnMintProgramConfigHash` reproduces:

```text
keccak256(abi.encode(
  keccak256("6529STREAM_BURN_MINT_CONFIG_V1"),
  chainId, gate, core, registry, entireProgramConfig
))
```

`configureProgram` returns an initial-only, zero-value call for the declared gate
owner and the independently computed expected hash. It does not infer ownership
or configure the Manager phase. The Manager phase must separately pin this gate,
runtime, and exact config hash under an approved mint policy.

`captureProgram` reads one pinned block and verifies the stored hash, complete
allowed collection list, gate/Core/registry runtimes, Manager and optional native
adapter runtime pins and identities, current Core Manager/registry pointers,
phase gate pin, and referenced collection existence. Plans are process-local and
must be recaptured after restart. The gate owner is informational and may be the
zero address after ownership is renounced; an already configured program does
not require a live owner to execute.

## Source ownership and burn approval

`inspectSources` rechecks the pinned program and returns each original token's
permanent collection/serial identity, owner, token approval, burn nullifier, and
Manager replay state. It reports two independent permissions:

- `callerAuthorized`: the caller owns the source or has token/operator approval.
- `gateApproved`: the gate has token/operator approval and can call `Core.burn`.

Granting the gate approval does not authorize an unrelated caller. Granting the
caller approval does not authorize the gate to burn. The source list must be
strictly increasing and its length must equal `quantity * sourcesPerMint`.

## Free burn and mint

`prepareFreeBurnMint` accepts the canonical Manager batch, explicit burn caller,
source IDs, and a maximum reveal-fee allowance. Free batches require zero payer
and authorizer, identical initial recipients and beneficiaries, 1 to 10 outputs,
and nonzero authorization and expected policy hashes. The beneficiaries may
differ from the source owners and burn caller.

The client reads `saleRevealQuote(program.configHash)` at the same pinned block,
requires the allowance to cover `liveFee * quantity`, and sends the full maximum
allowance as call value. On successful execution, the live fee is forwarded and
the difference is credited to the actual burn caller/funder under the immutable
program hash. A quote can change before inclusion, so callers choose their own
allowance margin and should simulate or reprepare close to submission.

`readFreeBurnRefund` and `freeBurnRefundClaim` operate on already earned credit.
They intentionally do not reapply the program window, Manager phase, current
pointer, module admission, or source-token checks. Claims survive later program
expiry, revocation, or dependency changes. Only the credited caller, including
a Safe acting as caller, selects the nonzero destination; no delegated claim is
constructed here.

`readFreeBurnCreditState` and `readFreeBurnCreditPage` expose the existing
producer-owned historical key index with a bounded `1..64` page limit. Claimed
zero-balance keys remain enumerable. These reads support reconstruction; one
page or a caller-supplied account list is not evidence of a complete liability
inventory.

## Native fixed-price burn purchase

`prepareNativePurchaseWithBurn` reuses `prepareNativeImmediateSale` and the
existing `NativeSaleAuthorization` EIP-712 domain. It creates no additional
signature domain. The signed payer and executor must be the same buyer/caller.
The function checks the pinned program and sources, current sale record, sale
price/config, and on-chain authorization digest before encoding the adapter's
external `purchaseWithBurn(execution, sourceTokenIds)` call.

The adapter retains the supplied native value and any buyer refund credit. The
gate burns sources only inside the adapter's authenticated callback. This module
does not expose or prepare the internal callback entrypoints. The paid path mints
one token, so its source count equals the immutable `sourcesPerMint` ratio.

## Evidence boundary

`burnMintNullifier` binds the original full-width source token ID to chain and
Core. Inspection is a pinned read, not a reservation: ownership, approvals,
replay state, prices, fees, windows, policies, and runtimes can change before a
transaction is included. A successful transaction must still satisfy current
Core burn/finality rules, Manager/Ledger authorization and counters, signatures,
settlement, reveal funding, and receiver callbacks atomically.
