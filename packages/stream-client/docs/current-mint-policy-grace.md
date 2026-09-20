# Mint executor policy grace callers

The additive `setPhaseExecutorWithGrace` method changes one phase executor and
can retain the immediately preceding policy hash until an absolute timestamp.
The client prepares its original zero-value call, policy hash and delayed
governance workflow. The permanent Manager interface and ordinary
`setPhaseExecutor` method remain unchanged. The additive selector and interface
ID are both `0xdef72e30`.

## Original policy identity

`mintPhasePolicyHash` reproduces the original Manager policy preimage:

- Chain, Manager, Ledger, module registry, schema version 1, collection and phase.
- Phase timing, maximum batch quantity, configuration hash and metadata hash.
- The complete original gate tuple.
- Counter IDs and configurations in their original order.
- The numerically sorted executor set.

Core, the phase's paused flag and the grace deadline are absent from this hash.
Counter order matters. Executor order does not. Returning to an earlier executor
set restores that set's deterministic policy hash.

`normalizeMintPhasePolicyInput` preserves the original preview's structural
semantics. A computable hash does not establish that a configuration can be
admitted. `normalizeMintPolicySnapshot` additionally checks configured-state
constraints and the supplied current hash. Integers use bigint with the original
ABI widths; inputs and derived plans are copied and frozen.

## Capture and prepare

`captureMintPolicyGrace` uses an explicit block number and independently reviewed
runtime pins. Supply the complete executor inventory, bounded to 64 distinct
nonzero addresses. The Manager has no executor enumeration getter. Capture
reconstructs the current hash and compares it with both the stored hash and
original preview; individual membership reads alone do not establish completeness.
It also checks the original phase, gate, ordered counters, Ledger policy and
three-field grace record.

`prepareMintPolicyGraceChange` changes only the requested executor. The returned
plan retains the snapshot, request, prospective executors and policy hash,
original preview call, exact Manager target call and class-1 governance call.
Its `factsVerified: false` distinguishes pure construction from live observation.

`inspectMintPolicyGraceChange` refreshes the captured facts and checks the
prospective consent. Missing consent returns `registrationReady: false`, so
the caller can prepare consent while scheduling the change. Execution simulation
requires consent to be ready. By default, registration admits mode 1 Artist
consent or mode 3 platform declaration evidence, matching the historical ABI52
source. Its Manager rejects mode 2 even though the Artist Registry has delegated
policy-consent producers.

For an independently reviewed Manager that includes the ABI56 mode-2 change, set
`deployment.supportsDelegatedPolicyConsent: true`. This strict boolean is part of
the captured deployment and review commitment. Omitted or false retains the
original behavior. It describes the current consuming Manager, including when
the Artist retains an earlier signing Manager. The unchanged selector and
interface ID cannot discover this capability; setting the flag is a source-review
assertion under the supplied runtime pin, not proof that a deployment supports it.
Exact governance simulation still checks actual admission.

With that capability enabled, mode 2 requires the exact retained policy record,
nonzero evidence and the original `requireMintConsent` checks. Grant expiration,
revocation or exhausted uses after recording consent do not independently revoke
that record. The client does not add a live-grant check. Current Artist, payout,
content and other mint prerequisites still apply. A mode-2 receipt event is
accepted only with the reviewed capability enabled.

Artist signatures retain the Registry's original immutable Manager coordinate.
When the current consumer differs, the optional original Manager/Ledger pair
must satisfy the source's current Core selection and completed descendant checks.
An executor change does not alter any signing domain.

## Governance and Safe steps

The Manager owner is the configured Governance Executor. An authorized proposer,
including an eligible Governor Safe, schedules the original governance action.
The Manager setter is not an ordinary direct Governor call.

1. Prepare the exact one-call governance batch with its current nonce, reason,
   manifest and execution window.
2. Publish the original call-data bundle and verify its retained bytes.
3. Simulate, schedule and verify the original action identity.
4. After the delay, refresh and simulate the exact execution call.
5. Execute and inspect governance, Manager and Ledger receipts and state.

The class-1 schedule requires at least 48 hours of delay, at least seven days
between `notBefore` and `expiresAfter`, and expiry no later than one year after
scheduling. Execution admits both endpoints of the saved window. Use the
operation's exact call with [ordinary Safe CALL plans](safe-call-plans.md),
preserving its intended caller and zero transaction value. Helpers do not sign,
submit or pay for transactions.

The root deployment's exact catalog row admits the actual Manager, selector
`0xdef72e30`, live target code hash, deployment-derived target profile, class 1,
direct CALL and zero value. The contract exposes only aggregate catalog state.
The client records that state and treats individual row admission as requiring
exact schedule/execute simulation. Aggregate catalog equality is not a row proof.

The raw Manager setter has no expected-current-policy argument. A pinned capture
and successful simulation cannot prevent another transaction from changing the
executor set before mining. Refresh before execution; receipt inspection checks
the actual outcome against the reviewed plan.

## Grace and unchanged requests

| Request | Original behavior |
| --- | --- |
| Real executor change, nonzero grace | Retain the immediate predecessor until the supplied deadline. |
| Real executor change, zero grace | Clear predecessor grace. |
| Unchanged authorization, zero grace | Successful no-op; preserve the existing grace record. |
| Unchanged authorization, nonzero grace | Revert; an unchanged request cannot extend grace. |

The deadline is an absolute Unix timestamp in seconds. At execution it must be
no later than `block.timestamp + 2_592_000`. Past nonzero deadlines are accepted
as already expired. A predecessor remains usable at equality with `graceUntil`
and expires one second later. A further rotation replaces the predecessor even
when its former deadline has not elapsed.

Keep the old mint batch's `expectedPolicyHash`, ticket, signature and authorization
ID unchanged. Grace affects only policy matching. Current executor membership,
Artist authority, gate checks, pause/timing, counters, replay protection and the
ticket's own deadline still apply. A removed executor loses admission immediately.
Returning to an earlier hash does not restore consumed or revoked authorizations.

## Receipt evidence and limits

A real rotation joins the original Manager consent and executor-update events,
Ledger grace, phase and counter-registration events, and the exact governance
action. Although catalog validation runs first, its event follows the original
scheduled or executed event. The legitimate zero-grace no-op emits none of those rotation events;
inspection verifies state preservation. Manager's grace getter has two fields;
Ledger's has three, including the predecessor revision. There is no active
policy-revision getter, and a cleared grace record cannot reveal that revision.
When the prior grace has a nonzero predecessor revision, a new retained
predecessor must have a strictly greater revision; the client does not invent an
exact active revision.

Receipt inspection requires the expected policy at the end of the receipt's
block. A later same-block rotation fails this inspection even if the reviewed
transaction succeeded. The no-op additionally requires the same policy and
grace in the previous block. Publication retries without an event require the
same retained publication in the previous block, under the pinned Governance
Executor runtime. A retry after an initial publication in the same block is
outside this evidence profile.

The inspection limits are 64 executors, 16 counters, 2,048 UTF-8 bytes for the
reason URI, 32,768 bytes per RPC return, 65,536 bytes per component runtime,
24,576 bytes for publication runtime, 262,144 bytes of transaction calldata,
256 receipt logs and 16,384 data bytes per log. These are client bounds, not
additional protocol limits.

The matching source tree's `docs/integrations/mint-policy-grace.md` describes the
contract behavior. The preserved historical client fixture uses retained
`parallel-feature-batch52-20260920` at
`44af244ed576cc4b26632b800fe70a068d577940`. All 2,212 literal input sources were
independently verified byte-for-byte against that commit. The projection retains
530 closure hashes, ten original source texts and selected compiled interfaces.
Regenerate or check using the retained capture, without compiling Solidity:

```sh
node scripts/generate-current-mint-policy-grace-fixture.mjs \
  /path/to/abi-input.json /path/to/abi-output.json --check
```

The separate mode-2 fixture uses `parallel-feature-batch56-20260920` at
`ed4d557246a98698167d6986bc4266d9e375d558`. All 2,241 literal sources match that
commit byte-for-byte. It retains 543 closure hashes and 15 original source texts;
all 197 selected ABI entries equal the preserved ABI52 projection. The fixed
linked policy worker preserves Manager storage, caller and event identity. The
original policy hash, Ledger grace and governance preimages remain unchanged.
The updated Artist's `requireMintConsent` also uses its current personhood read;
the caller invokes that exact prerequisite without claiming C2PA authoring support.

```sh
node scripts/generate-current-mint-policy-grace-mode2-fixture.mjs \
  /path/to/abi56-input.json /path/to/abi56-output.json --check
```

Client encoding, source/ABI and mocked RPC checks do not establish native current
stack execution, actual Safe execution, gas, genesis or release acceptance.
