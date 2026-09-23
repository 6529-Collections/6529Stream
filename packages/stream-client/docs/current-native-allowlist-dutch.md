# Current native allowlist Dutch sales

`current-native-allowlist-dutch.ts` prepares the additive proof-bearing Dutch
calls introduced at source commit `2dc3ea7e`. It retains the original Dutch
configuration, `DutchAuthorization` fields, EIP-712 domain, replay lanes and
refund ownership. The module performs no broadcasts.

## Registration and hashes

`prepareNativeAllowlistDutchRegistration` produces the owner CALL and exact
sale, schedule, original configuration and wrapped allowlist configuration
hashes. The original configuration includes the live registration primary
policy baseline and primary assignment, so the caller must supply those as
`hashFacts`.

Before registration, `inspectNativeAllowlistDutchRegistration` verifies the
current owner, `nextSaleNonce`, canonical sale ID, and configured Core, Manager
and entropy coordinator addresses. The supplied baseline and assignment are
still expectations at this point. Simulation returning the sale ID does not
attest the resulting configuration hash.

After the registration transaction, run
`inspectRegisteredNativeAllowlistDutchSale`. It reconstructs the sale ID and
compares the stored configuration, schedule hash, wrapped hash, selected
counter, baseline and assignment. Complete this readback before asking the
platform and Artist to sign.

## Price and proofs

`nativeDutchSchedulePrice` reproduces LINEAR0 and STEPPED1 pricing. An enabled
selected leaf changes the charge to:

```text
min(current schedule price, leaf price)
```

The original signed `unitPrice` remains an additional maximum. A ceiling above
the schedule still charges the schedule. A zero leaf requires the immutable
`declaredFree` flag, including when the resting schedule price is positive.

Purchase input contains one proof per caller-described Merkle group, up to the
protocol limit of 16. Supply groups in the phase's filtered `MERKLE_STATIC`
order. Only the selected group may enable a price. Group `counterId` values are
unchecked caller labels used for local price selection; they are not encoded.
The exact payable simulation validates positional witnesses against live
Manager definitions and roots.

## Funding and inspection

`saleFundingMaximum` and `revealFeeAllowance` are added to form the exact CALL
value. At execution, the contract captures the live reveal fee first. The
amount left after that fee is the effective sale funding maximum. Both that
maximum and the signed `unitPrice` must cover the actual charge. Any unused
native value becomes a pull credit owned by the payer.

Read-only purchase inspection uses a concrete block to verify the stored
record and allowlist counter, schedule quote, authorization digest, reveal
policy, configured dependencies, signed maximum and attached funding. Dutch
has no preview entrypoint. Inspection therefore does not validate proofs,
signatures, Artist consent, runtime identity or live admission.
`simulateNativeAllowlistDutchPurchase` performs the exact payable call from the
actual payer and checks the returned charge, forwarded fee and credited excess.

Numeric block pins have no reorg hash check. Simulation does not prove Safe
threshold authority, transaction inclusion or future state. The ABI fixture is
source and encoding evidence; moving-price runtime and full-stack acceptance
remain separate.

## Refunds

`prepareNativeDutchRefund`, `inspectNativeDutchRefund` and
`simulateNativeDutchRefund` operate only on the credited payer's per-sale
balance and exact `claimRefund` call. They deliberately do not reapply current
sale availability, Artist, proof, phase or mint admission. The credited payer
remains the caller and chooses a nonzero recipient other than the adapter.
