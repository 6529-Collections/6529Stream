# Current Safe INSTANT entropy recipes

These eight source-authored recipes join the current Core, Artist suite,
Governance Executor, Mint Manager/Ledger, native FixedPrice adapter, primary
settlement and production `StreamEntropyProviderInstant`. They extend the
[INSTANT provider contract](instant-entropy.md) and
[explicit collection policy](explicit-entropy-collection-policy.md) into actual
current-stack flows. They are separate from the
[terminal ASYNC/DISABLED recipes](current-terminal-entropy.md).

The authoring base is integration `78fd429f`, including the INSTANT implementation
`4010ec2a`, commerce integration `128c8378` and committed Artist changes. This
batch changes only its own helper, host and guide. **Compilation, code generation
and native execution of these eight cases remain pending.** The integrator owns
the joined checks; source assertions below describe intended acceptance, not
observed runtime passes.

## Actual contracts and controlled inputs

- Each case deploys a fresh current graph through the existing
  `StreamCurrentSafeGovernanceFixture`. Its production runtime/initcode guards,
  shared gas configuration and original Safe fixtures remain unchanged.
- Artist, payer and governor are separate real upstream Safe 1.4.1 proxies with
  two required EOA signatures. Their deterministic fixture keys are public test
  material. Safe EIP-712, `SafeTx` and `SafeMessage` preimages use their original
  literal domains and are compared with the upstream read surfaces.
- The production INSTANT provider is deployed from its actual artifact, pins
  the real Coordinator and enters ACTIVE through the original class-1 lifecycle
  action executed by the governor Safe. The inherited ASYNC service double is
  present during shared setup but receives no request or value in these flows.
- Policy configuration and its separate freeze use actual Artist operation-17
  consent and executing governance actions. The provider change increments the
  inherited collection epoch. LOW_SECURITY and REQUIRED or NOT_REQUIRED are
  explicit, while all ASYNC reveal, timeout and recovery fields remain zero.
- Native-sale price is 1,000 wei. The sale overpayment is 37 wei, and a later
  request supplies 91 wei. Both overpayments use the original payer-owned pull
  credit mechanisms. INSTANT charges no entropy fee.
- Time/block advancement and balances use ordinary Foundry cheatcodes. The
  provenance oracle uses `blockhash` from that local EVM context, which may be
  zero for a synthetic prior block. It is not public-chain historical evidence.
  One explicit receiver controls acceptance of actual Core mint delivery.

## Finite acceptance matrix

The host is
[`StreamCurrentInstantEntropy.t.sol`](../../test/current/StreamCurrentInstantEntropy.t.sol),
backed by
[`CurrentInstantEntropyFixture.sol`](../../test/helpers/CurrentInstantEntropyFixture.sol).

| Case | Original behavior asserted |
| --- | --- |
| Consent and freeze | Missing configuration consent and reuse of configuration consent for freeze fail with the exact Artist dependency error. New Safe consent permits each distinct action. Original policy/consent hashes, all receipt fields and action replay refusal are checked. |
| Paid registration | A real Safe native purchase creates the original token and settles 1,000 wei to its assigned split wallet. REQUIRED stays REGISTERED, retains its mint commitment and creates no request/finalization or immediate-reveal event. The entire 37 wei sale surplus is credited and claimed. |
| Same-block refusal and later request | The direct Coordinator call returns `InstantEntropyBeforeDelivery(1)`. The saved signed Safe transaction fails with `GS013` and preserves captured state. The identical envelope succeeds after one block, finalizes synchronously and credits then returns all 91 wei. |
| Private request authority | With public requests disabled, the payer gets exact `Unauthorized(payer)` and Safe `GS013`. Actual delayed requester admission changes authority; the identical saved Safe envelope then succeeds. |
| Safe authorization | An otherwise affordable value change and a wrong transaction nonce each fail with exact `GS026`, preserving the original paid mint authorization. The saved valid envelope succeeds; replaying it then fails with exact `GS026` for its stale nonce. |
| Finalized request replay | After successful finalization and credit claim, another block gives a different candidate raw value. A fresh valid Safe envelope reaches exact `InvalidStatus(FINALIZED)` and preserves the original request, raw value, seed and closed liabilities. |
| NOT_REQUIRED | The explicit INSTANT NOT_REQUIRED policy produces a real paid terminal token with zero fee, no seed, no request and no finalized claim. Sale credit remains fully claimable; direct and Safe requests refuse without changing state. |
| Delivery rollback and retry | The receiver's exact rejection reaches the native adapter and causes Safe `GS013`. Core identity, prepared mint, Manager/Ledger replay lanes, settlement, balances, entropy registration and receiver state roll back. Changing only receiver acceptance permits the identical signed transaction to register the token. |

## Independent request and payment oracles

The helper reconstructs the original `6529STREAM_ENTROPY_REQUEST_V1` request key,
INSTANT allocated provider ID, nine-field encoded context, production
previous-block raw value, provenance and original `6529STREAM_ENTROPY_SEED_V1`
seed. It does not call the provider to produce the expected answer. Configuration
and assumptions use the provider's original literal preimages.

The complete request snapshot binds provider address/runtime/configuration,
epoch, collection salt, attempt one and zero normalized inputs. The original
subject still retains the signed mint commitment. Both request-ID directions,
all original request fields, terminal counters and the full requested/produced/
finalized receipt sequence are checked. The production provenance and its
LOW_SECURITY assumptions hash are checked in the Coordinator receipt.

Negative request and signature paths compare captured Core/mint state, all seven
Artist owner snapshots, policy, request identity, entropy counters, credit/escrow
liabilities and balances. Mint denial also checks unused original authorization
and operation-root lanes. Successful mints check their corresponding consumption,
the official settlement receipt record and original Core Transfer receipt.

## Evidence boundaries

Source review, formatting and documentation checks cannot establish that this
large joined deployment executes or fits. No compiler, native run, gas benchmark,
provider opcode proof or artifact regeneration was performed for this batch.
The original deployment and gas guards remain in force for the integrator's run.

These cases do not implement successor relays, STATIC consumers, metadata
disclosure, public-chain provenance authentication, provider failure doubles,
new deployment inventory, audit or release acceptance. The production adapter
is explicitly predictable and allows validator influence and block-to-block
request timing selection. Matching its provenance does not make it VRF or
HIGH_ASSURANCE randomness.
