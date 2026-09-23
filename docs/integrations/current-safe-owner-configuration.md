# Current Safe owner-configuration recipes

## Scope and evidence

The [nine named cases](../../test/current/StreamCurrentSafeOwnerConfiguration.t.sol)
use one [reusable helper](../../test/helpers/CurrentSafeOwnerConfigurationFixture.sol)
on the actual [current stack](../../test/helpers/StreamCurrentStackFixture.sol).
They deploy the pinned upstream Safe 1.3.0, 1.4.1 and 1.5.0 creation bytecodes,
check their runtimes and initialize actual proxies through the original factory.
See the [fixture provenance](../../test/fixtures/safe/README.md).

The initial recipes have source review and an ABI-only capture. The subsequent
independent-review correction isolates signer failures and requires exact Safe
signature errors; its joined compiler check remains pending. Native execution,
gas acceptance and joined release validation remain pending. The source base is
`e7b509ca524578da5e3a43db8acab228f720833b`. No production code, shared fixture,
runner, acceptance catalog, deployment guard or release artifact changes here.

## Existing coverage inventory

The new matrix extends the following existing recipes without counting them as
new owner-configuration cases:

| Existing surface | Actual Safe coverage already authored |
| --- | --- |
| [Current Safe](../../test/current/StreamCurrentSafe.t.sol) | 1.4.1 Artist and buyer paid mint, reveal, custody, approvals, revenue and governed configuration |
| [Current Safe batch](../../test/current/StreamCurrentSafeBatch.t.sol) | Seven 1.4.1 cases including late failure and identical retry with original nonces |
| [Current private sale](../../test/current/StreamCurrentNativeCuratedPrivateSafe.t.sol) | 1.4.1 buyer; 1.5.0 seller ERC-1271 over the full private-sale authorization; 1.5.0 buyer late-Core-failure exact retry and refund credit |
| [Official Safe foundation](../../test/unit/revenue/StreamOfficialSafe.t.sol) | All three versions' threshold execution and claims; one nested 1.4.1 signature probe |
| [Artist onboarding](../../test/unit/artist/StreamArtistOnboarding.t.sol) | Actual 1.4.1 owner replacement and refusal of an unused policy proof from the removed signer |

Authored coverage in this inventory is not a claim that each case has passed a
new native run at this source base.

## Finite matrix

Each row below has one named case for each of 1.3.0, 1.4.1 and 1.5.0: nine cases
total. Flat Artist and buyer Safes initially have two-of-three EOA owners.
Public deterministic test keys have no real funds or operational authority.

| Family | Actual transitions and negative cases | Successful continuation |
| --- | --- | --- |
| Threshold change | Buyer changes two-of-three to three-of-three by authorized self-CALL. Its old-nonce payload retains three signatures, isolating stale-nonce refusal. A fresh-nonce two-signature payload is also refused. Artist changes two-of-three to three-of-three, invalidating its unused two-signature sale proof. | Artist changes back by a three-signature self-CALL. The byte-identical saved buyer transaction succeeds with its original nonce and original sale proof. |
| Owner replacement | Artist and buyer each execute `swapOwner`; both actually remove the old owner and admit the replacement. Old-nonce, fresh-nonce removed-buyer signatures carrying a valid current Artist proof, and current-buyer signatures carrying the removed-Artist proof are refused. | Current owners sign the same sale authorization, then execute paid mint and custody transfer. The removed Artist's separately saved payout proof is refused; new owners sign the same payout fields and original unused Artist nonce, producing the original record and receipt. |
| Nested owner revocation | Buyer is two-of-two: one EOA plus an actual two-of-three Safe. A signature using the other version's contract-owner wrapper is refused. Inner Safe executes `removeOwner`, invalidating the saved outer proof without consuming its outer nonce. | Remaining inner owners execute `addOwnerWithThreshold`. The byte-identical saved outer transaction succeeds. The inner nonce remains at two through paid mint and custody transfer; contract-signature validation does not execute an inner transaction. |

Every family uses an original payable `sale.buy` CALL for 0.01 ETH and an
original zero-value `safeTransferFrom` CALL from buyer to Artist. Both use
operation zero. Before purchase, independent attempts change value to zero,
operation to one, or append a byte to calldata without replacing signatures;
each must return the original `Error(string)` with `GS026`, before executing the
target. Stale-nonce, removed-signer and wrong nested-wrapper probes require the
same error; insufficient quorum requires `GS020`. Completed purchase and
transfer payloads cannot replay.

## Original encoding and independent assertions

The helper independently constructs the literal Safe EIP-712 domain and full
`SafeTx` preimage, including calldata hash, value, operation and nonce. It checks
that digest against the original Safe getter, signs sorted owner signatures and
calls the original `execTransaction` ABI. Safe transaction gas, base gas, gas
price, gas token and refund receiver are zero. Under that envelope an inner
failure must revert the outer transaction, restoring its nonce and value.
Versions 1.3.0 and 1.4.1 wrap target failure as `GS013`; 1.5.0 propagates target
revert data. Neither substitutes for signature-error assertions. These rollback
claims do not describe envelopes with a nonzero `safeTxGas`.

Nested signatures use the original contract-signature header, sorted with the
EOA signature, with dynamic inner signatures at byte offset 130. For 1.3.0 and
1.4.1 the inner Safe signs `SafeMessage` over the full outer transaction
preimage. For 1.5.0 it signs `SafeMessage` over the ABI-encoded outer hash. The
opposite encoding is a separate negative case in each version. See the original
[1.4.1 Safe validator](https://github.com/safe-fndn/safe-smart-account/blob/bf943f80fec5ac647159d26161446ac5d716a294/contracts/Safe.sol)
and [1.5.0 Safe validator](https://github.com/safe-fndn/safe-smart-account/blob/dc437e8fba8b4805d76bcbd1c668c9fd3d1e83be/contracts/Safe.sol).

Successful calls require exactly one original `ExecutionSuccess` with the
signed transaction hash and zero refund. The 1.3.0 hash is in event data;
1.4.1 and 1.5.0 index it. Mint and custody transfer require exact original Core
`Transfer` receipts, token identity, owner and token bytes.

Denied purchases preserve the original sale authorization, Manager operation
nonce, literal Ledger counter key and authorization key, supply and serial
allocation, pending/prepared mint state, token data, entropy registration,
provider request count, payment balances and liabilities. Failed Safe calls
also preserve its owner configuration and all seven Artist owner snapshots.
Successful purchase consumes the original sale and Ledger authorization once,
advances the original supply counter once, settles exactly to the original split
wallet and leaves deferred entropy registered without requesting randomness.

Payout replacement uses independently written original EIP-712 type/domain and
record preimages. It verifies the original payout owner's readback and receipt,
the separate Artist unordered nonce, unchanged Artist Safe transaction nonce,
and replay refusal with all seven retained owner snapshots unchanged.

## Limits and next validation

Only the inherited external entropy service is a test double. Safe owners,
handlers, signature validation, self-CALL transitions, Artist authorization and
the paid mint graph are actual contracts. Nested ownership is exercised on the
buyer; the Artist uses flat threshold signatures. The fixed-price adapter's
existing signature-gas cap is unchanged, so these cases do not establish nested
Artist support under that cap.

The matrix does not claim every Stream selector, arbitrary Safe version,
threshold, handler, guard, module or nesting depth. It does not cover all-cold
gas envelopes, complete full-37 activation, genesis or capacity acceptance.
The integrator must freeze the joined source and run the named host with the
original production size and gas guards before recording native acceptance.
