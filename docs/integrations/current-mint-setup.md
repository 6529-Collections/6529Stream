# Complete phase setup with an EOA or Safe

This helper belongs to the developing full-v1 stack. Use its matching source and
compiled artifact; the published RC1 has a different operator workflow.

After [artist activation and onboarding](current-artist-activation.md),
`PrepareCurrentMintSetup` prepares each next transaction for an explicit list of
new phases. It owns no authority and sends no transaction. The artist and initial
Manager owner can each be an EOA or a Safe.

For each phase, the saved plan contains the collection, phase ID, expected artist,
artist identity and accepted binding hash, one executor, complete phase and gate
configuration, ordered counters, and two
distinct artist authorization nonces and deadlines. The plan also records the
chain, Manager and artist-facade addresses and runtime hashes, Core, canonical
governance Executor and initial Manager owner. Use public JSON values; encode
large integers as decimal strings and bytes as `0x`-prefixed hex. Authorization
signatures are `"0x"` because the artist wallet submits its own call.

The exact tuple is [`StreamMintSetupPlan.Plan`](../../script/current/StreamMintSetupPlan.sol).
Build the matching `PrepareCurrentMintSetup.s.sol` artifact using the current
profile. With the optional [TypeScript client dependencies](typescript-client.md)
installed, encode a JSON plan using that artifact's ABI:

```powershell
node packages/stream-client/examples/encode-mint-setup.mjs plan.json out/current/PrepareCurrentMintSetup.s.sol/PrepareCurrentMintSetup.json
```

Save the returned `STREAM_MINT_SETUP_PLAN` value with the original JSON and exact
source identity. Read the live next step:

```powershell
$env:FOUNDRY_PROFILE = 'current'
forge script script/current/PrepareCurrentMintSetup.s.sol:PrepareCurrentMintSetup --rpc-url $env:STREAM_RPC_URL --skip test
```

This invocation is read only. The result names the required `actor`, `target`,
zero `value`, exact `data`, phase and expected policy hash. Submit those bytes
through that actor's wallet. For a Safe, use operation `CALL` (`0`), confirm its
actual `ExecutionSuccess`, and then run the planner again against confirmed
state. A successful outer receipt containing `ExecutionFailure` does not advance
the workflow. Existing [Safe client helpers](typescript-client.md) prepare the
outer transaction and inspect execution receipts.

| Step | Actual actor and result |
| --- | --- |
| `RECORD_INITIAL_CONSENT` | Artist records consent to the exact prospective phase with no executors |
| `CONFIGURE_PHASE` | Initial Manager owner configures the phase; all mandatory artist records must be valid |
| `RECORD_EXECUTOR_CONSENT` | Artist records consent to the prospective policy containing the selected executor |
| `ADMIT_EXECUTOR` | Initial Manager owner admits that executor |
| `HANDOFF_MANAGER` | Initial owner transfers Manager ownership to its canonical governance Executor |
| `COMPLETE` | All listed phases and their live consent pass readback; ownership is already with the Executor; no call is returned |

Retain the same plan on resumption. Confirmed steps are skipped from actual
contract state. The helper rejects changed chain or pinned runtime, mismatched
selected modules, a different accepted artist or owner, changed phase policy,
changed pause/configuration, duplicate phases and reused consent nonces within
one artist's plan. Expired consent must be replaced deliberately before use;
the helper never silently chooses a new nonce or extends a deadline.

Read `artistAuthorizationState(artistId, digest, nonce)` on the artist facade.
The selected direct consent must use its actual `nextUnusedNonce`; the planner
also checks that nonce and digest are neither consumed nor revoked. Do not assume
the next hint is the preceding hint plus one: a prior relayed signature may have
consumed a later nonce. If intervening activity changes the hint, explicitly
update that pending authorization in the saved plan and retain the previous
version. Completed phase configuration and recorded consent remain unchanged.

The phase list is the operator's explicit inventory. It does not enumerate every
phase ever registered in Manager. Final readback checks all listed phases and
live mint eligibility before preparing handoff, including rows completed earlier.
These checks are a preflight observation: another transaction before the returned
CALL executes can change state. Re-read immediately before submitting and confirm
the result afterward. The helper does not add an onchain ownership-transfer guard.

This completes the phase-planning surface. Identity proposals, binding acceptance,
payout, economics, content ratification and attestations precede it; their complete
operator consumer is still being migrated. Seven actual-current Safe tests pass,
including multiple phases, sparse nonce use, failed target execution, ownership
handoff and an actual paid mint and reveal. These are scoped integration tests;
no new candidate or complete deployment rehearsal is claimed by this guide.
