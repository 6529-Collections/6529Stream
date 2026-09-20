# Recovery after cancelled staging records

Recovery contexts retain the original authority history when a staged rotation
or estate request was cancelled before execution. This extends first living
recovery and class3 recovery after original estate activation40 or designated
dormancy43, and composes those histories with repeated35 and ordinary32.

## Supported combinations

`E` is the actual executed authority head. `P` is an original rotation staged by
operation29 and aborted before operation32. `S` is an original operation38
estate request cancelled before40. A superscript or synthetic vesting record
is never assigned to either unexecuted record.

| Authority history | Current cause | Retained staging history |
| --- | --- | --- |
| Initial living, E genuinely zero or one or more32 | Original33 compromise or original31 standing veto capturing P | Earlier dismissed P, cancelled notices and cancelled S |
| Latest living35, optionally followed by32 | Original33 or31 capturing P | The exact saved35 cause/resolution baseline and all later staging records |
| Original40 or43, optionally followed by32 | Original33 or31 capturing P | Original capability origin, pre-origin living history and post-origin staging records |
| Latest class3 35 after40/43, optionally followed by32 | Original33 or31 capturing P | Original capability origin and exact latest35 baseline |
| Living E zero,32 or35 | Original33 with S as the latest staging head | Explicit cancellation39, living-action cancellation, or cancellation by the current or a dismissed33 |

First40 after a living35 retains that actual35 as its history root. Completed43
can retain dismissed challenges from its active notice period. Its completed
phase3 notice is distinct from earlier phase2 cancelled notices.

Original class3 rotation admission does not require a nonzero capability mask.
Recovery preserves the original40/43 capability source and each ordinary32
preserves the delegation epoch. Each successful35 advances it exactly once.

## Original evidence and ordering

The current compromise uses its exact operation33 Contest. A current standing
veto uses its original operation31 cause and permanent veto replay; it has no
Contest, and its original evidence and reason may be zero. The new recovery
request still supplies its own required governance evidence and acceptance.

Current P is phase3 with no execution, no post-execution window, cleared live
pending state and a wholly empty dismissal closure. Current33 may instead have
cancelled S; its original cancellation replay shares the exact33 revision and
its dismissal closure is also empty. Older compromise-aborted P or S requires
its actual cause, dismissal and abandoned closure. A plain cancelled S has no
invented compromise or dismissal.

The reader follows every actual executed vesting link to the latest35 or the
genuinely empty first-living baseline. The saved cause/resolution links select
each episode and each execution's immutable first closure. Original native
receipt order and replay revisions identify the actual staging predecessor;
the saved rotation pointer cannot omit a cancelled request or aborted rotation.
An estate cancellation can share the next rotation stage's revision because
the original living-action hook cancels it in that same operation.

Each execution must have been eligible at the next original staging boundary.
For43, notice-entry eligibility is checked separately from challenges dismissed
during the notice before completion. A later historical subject marker cannot
substitute for an unresolved early compromise. No elapsed-time workaround
changes the original contest timing.

## Contexts and guardians

Previously supported histories retain their existing reader and context bytes,
including plain cancellations already absorbed by an admitted later authority
origin. Newly admitted profiles bind a tagged family proof. Proofs include the
relevant original records and replay cells, not the growing owner revision or
native receipt count. Later registration and unrelated native receipts leave a
prepared context unchanged.

Guardian selection uses the actual executed32/35/40/43 cutoff. An unexecuted P
or S never supplies a cutoff. First recovery with genuinely zero execution
therefore retains the existing exclusion of nonempty guardian supersession.
For original33 causes, ARBITER/APPEAL evidence remains joined to the original
Contest, independently of the new recovery request's document reference.

Current standing-veto recovery supports an empty supersession list. Nonempty
supersession for that cause remains outside the implemented evidence profile:
the existing supersession/Appeal reader requires an original33 Contest. This
is an implementation boundary, not a prohibition inferred from the authority
specification. No synthetic Contest is created to bypass it.

## Validation and limits

`StreamArtistRecoveryStagingFamilyActual.t.sol` uses actual Artist owners,
threshold Safes and Archive with the inherited typed unit Core and governance
boundaries. Authored cases exercise the family combinations, original receipts,
epoch changes, current versus historical guardians, cancellation ordering,
source corruption/restoration, registration stability and Archive rollback
followed by an identical-request retry. The existing repeated-living cohort
remains a separate compatibility regression host.

```powershell
python scripts/dev.py test --suite unit --via-ir --code-size-limit 2000000 --gas-limit 1000000000 --memory-limit 1073741824 --match-path test/unit/artist/StreamArtistRecoveryStagingFamilyActual.t.sol --match-test '^testStagingFamily'
```

Source and ABI checks do not establish runtime acceptance. Native execution,
full current-stack tests, linked product sizes, gas/capacity, full CI and release
artifacts remain pending. The owner-wide native receipt scans also require
capacity measurement. Fixture gas and size limits are not deployment evidence.
