# Artist dormancy and steward appointment

This source batch implements the original operation 19 steward sanction grant,
41 notice, 42 cancellation and 43 completion. Dismissal remains the separately
adopted operation 58. The original 1–57 operation prefix is unchanged.

The public additive interfaces are `IStreamArtistDormancy`,
`IStreamArtistDormancyEvidence` and `IStreamArtistStewardSanctionGrant`.
The registry retains its existing selectors and interface IDs. Its fixed writer,
Coordinator and Identity owner execute the new recipes; each recipe uses the
Identity snapshot bit `0x04` and appends the original atomic Archive evidence.

## Initiate, observe and cancel

Read `dormancyInitiationContext` for the exact per-call governance transition.
The current living artist must have no active authority window or pending estate
request and must have been inactive for the configured interval. The default is
730 days, with an immutable 365-day floor. The notice defaults to 365 days with
an immutable 180-day floor. The original seconds-window governance configuration
surface exposes both parameters and preserves its revision and delay rules.

The current immutable Executor must be executing the exact class-1 transition;
the stored action evidence must match, and its proposer must hold
`ROLE_ARTIST_DORMANCY_ADMIN` in the pinned RoleRegistry. Initiation stores the
notice, incumbent, clock, timing configuration and governance witness before
changing identity status to 2. The evidence hash commits to the operator's
contact-attempt document; this interface does not investigate its truth.

An authenticated ordinary living-artist write, delegated write or estate request
by the operative designee cancels a pending notice in the same owner transaction.
Explicit cancellation also accepts the current artist, a current active delegate
with the exact grant hint, or the operative designee. It records the cancelling
authority class and refreshes the inactivity clock. Explicit delegate liveness
does not fabricate a delegated operation or consume its use counter.

The original guardian/prior-address/arbiter compromise route accepts a pending
notice. Completion then refuses status 4. Dismissal authenticates the cause's
saved notice and its current phase/terminal in the governed cohort. An uncancelled
notice restores status 2 and its original deadline; authenticated cancellation
while contested preserves status 4 until dismissal, then restores status 1.
Cancellation changes the cohort, so an earlier staged dismissal cannot resurrect
the cancelled notice. Non-notice dismissal context and record preimages remain
unchanged.

## Complete and retain authority history

After the notice deadline, read `dormancyCompletionContext` and
`dormancyCompletionEvidence`. The second class-1 governed call must commit to the
hash of those exact evidence bytes. That typed document contains the completion
terms and selected plan, including the operative original grant record. Its
embedded evidence hash is a document commitment, not independent proof of an
external narrative. The Archive retains the complete typed wrapper.

An operative designation installs its exact successor and allowed class-3 mask.
Otherwise the proposed steward is installed as class 4 with the default mask
369: attest, royalty freeze, dispute, intent records and guardian-set maintenance.
The appointment block is recorded from the executing transaction. Policy and
economics consent are excluded; sanction is added only by an operative original
artist-signed operation 19 grant. A directive may pre-grant guardian displacement;
its forbidden mask overrides every included permission. The separate later
TERMINAL_FREEZE grant recipe is the next additive operation 59 batch, not an
implicit power of operation 19 or 43.

Completion records the actual operation-43 guardian vesting snapshot, complete
history prefix, prior address and immutable transition. It advances the delegation
epoch, preserving old records while ending old delegates' authority. Original
rotation supports the same class and capability origin after appointment.
Default steward guardian maintenance retains the living artist's recorded
lifetime guardians unless their explicit directive granted displacement.

Bindings and admitted policy/economics/attestation records are not rewritten by
appointment. Previously approved phases retain their mint authorization. A
steward may attest current subjects but cannot approve a new policy. A sanction
or recovery approval additionally requires sanction capability and an actual
collection burn-block activation at or before the appointment block. Token and
other scoped steward sanctions remain prohibited.

## Validation scope

The new lifecycle file contains twelve actual Artist, Safe and Archive scenarios,
with explicit typed governance/role and unit Core boundaries. The six original
grant-state scenarios exercise actual Identity nonce/signature and Rotation state
with a typed Coordinator verdict. Both files typecheck. These tests have not yet
run in this feature batch; current product sizes, full graph composition and
transaction capacity also remain pending consolidated validation.

After the feature source stabilizes, run the focused aggregate fixture profile:

```powershell
python scripts/dev.py test --suite unit --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824 --match-path test/unit/artist/StreamArtistDormancyLifecycle.t.sol
python scripts/dev.py test --suite unit --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824 --match-path test/unit/artist/StreamArtistStewardSanctionState.t.sol
```

The monolithic unit fixture relies on aggregate CREATE ordering. Copy all reached
fixture JSON files, including the original Arweave fixtures, into any frozen
capture at preparation time. Do not interpret the large unit harness gas/code
limits as deployable product or transaction-capacity evidence.

The earlier recovery-history consumers retain their documented estate/op35
profiles; this batch does not add dormancy-origin elected recovery or guardian
supersession histories. Those follow-ups must authenticate the new admitted
operation-43 origin explicitly.
