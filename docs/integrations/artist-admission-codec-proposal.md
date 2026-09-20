# Artist admission and codec sharing

The exact reviewed 01/02 successor was permitted by renewed automatic review and
applied locally to isolated base `ceba25d6ba7595c09bc4b32331f7359d84b4b66d`.
The original denied artifacts remain preserved. This permission is specific to
that local repair; personhood and unrelated held changes remain separate.
No integration, push or deployment is implied by this source handoff.

The applied patch is SHA256
`819814dcaf29f72c6d4fbab7e0acb6e332c5249f78263d1b11dc0712135d65cd`.
All eight initial file texts matched its frozen packet after line-ending
normalization. Three new helpers were then formatted with identical tokens.
Original error declarations are retained once in the common Owner, removing
only five duplicate concrete-host declarations to preserve all compiler ABIs.
Later recovery, imports, C2PA, creation and terminal-read work is retained.

## Original admission predicate

Only `StreamArtistOwner._check` changes its implementation location. The fixed
linked `StreamArtistOwnerCheck.check` receives the existing declared accumulator
prefix, immutable Coordinator and domain, original calldata context and original
operation literal. Its checks remain, in order:

1. Original `msg.sender` must equal the immutable operation Coordinator, otherwise
   `Unauthorized(msg.sender)`.
2. The action actor must be nonzero, otherwise `Unauthorized(actor)`.
3. The supplied operation must equal the required operation, otherwise
   `InvalidOperation(context.operationId)`.
4. Original domain, revision, state root and record-chain tip must match, in that
   short-circuit order, otherwise `StaleOwnerSnapshot(domainId)`.

The existing `_commitPrefix()` returns the compiler-declared `_revision.slot`.
Its original Prefix type still contains packed uint64 revision and sequence,
then state root and record tip. No new storage alias, caller-selected location,
mutation, generic call target, grant, writer or signed domain is introduced. The
library executes in the owner delegate context and reads only. Original external
ABI decoding still occurs before `_check`, including malformed-tuple refusal.
The added fixed library call consumes gas; its effect on governed write budgets
remains to be measured on the actual Artist graph; source parity alone does not
prove those budgets.

All existing callers of the common check, including later recovery and op60
imports, remain byte-identical. No previous validation, epoch, replay update,
hydration guard, source reread, revision observer or Archive operation is removed.

## Original post-check tails

Five Attribution op24 entries keep their complete original declaration and
`_check(c, 24)` in place. They invoke one private routine with the exact original
artist ID and collection ID. The routine forwards original `msg.data` to a
closed five-selector function in the existing fixed AttestationTransport, calls
the same typed decoder/body, commits the same mutation, appends the same native
receipt, and normally returns `m.record`, in that order. The current original
compiled ABI independently defines all five literal signatures. Unknown worker
selectors refuse with `InvalidOperation(24)`.

Eleven Identity writer entries retain `onlyHost`, their complete declarations,
and their original operation literals: acceptance 2, refusal 3, sale 16, policy
14, economics 15, payout 18, attestation 24, ratification 52, royalty freeze 20,
content consent 17 and content freeze 21. Their shared private tail receives the
same `b.artistId` (or `p.artistId` for payout) and `proof.signer`, calls the original
consent worker with the same `c.operationId` and `msg.data[4:]`, notes original
activity, then commits. The returned consent record remains separate from
`m.record`; a zero Identity record delta is not replaced with the returned hash.
The newly shared mutation tails use normal Solidity returns and preserve modifier
epilogues. Existing unrelated forwarding paths are unchanged.

Later delegated endpoints, recovery operations, C2PA credentials and original
personhood heads, record-family import workers, STATIC reads, creation carriers,
constructor arguments and factory CREATE/nonce semantics remain unchanged.
The proposal does not add any consent eligibility or freeze authority.

## Regression sources and retained oracles

`StreamArtistAdmissionCodecOwner.t.sol` calls the real Owner methods through a
small unit harness. Seven executed tests pass and cover exact error precedence, each
snapshot field independently, the original flat-word state/record/replay
preimages, rollback of the original checkpoint/replay state, and truncated/dirty
canonical calldata. The unit late-failure control restores the same state and
replay inputs; its explicit failure flag changes on the successful call. It is
not described as identical calldata or as an actual Archive transaction.

`StreamArtistAdmissionCodecSafe.t.sol` retains thirteen exact existing test
function bodies in a bounded class using the unchanged ArtistOnboardingFixture.
They cover original Safe/direct/relayed acceptance and refusal, policy/economics,
payout and attestations, native sale consent, publication record/event/receipt
bytes and consumption, existing royalty/content freeze, malformed publication
providers, and late Archive retries. One additional case sends the exact same
original signed op24 calldata through the actual threshold Safe: late Archive
failure must restore all seven owner snapshots, original nonce hint, saved
publication evidence and Safe nonce; the identical retry succeeds once, and
repetition refuses. The old generic Metadata consumed-authorization map remains
the authority for publication consumption.

These fixtures use actual Artist owners/facade, threshold Safe, Archive and
Manager/Resolver components, and actual Metadata where the specific original
test constructs it. Core, governance, finality and some subject hosts remain
their explicit original typed boundaries. They are not full current-graph or
launch acceptance. All copied bodies are pinned to the base source by hash.
The seven Owner-only cases passed against 20 frozen sources with the actual
fixed check and common Owner. Their harness is 6,385 runtime bytes and the test
contract 16,089; the run retained the 24,576 size limit. The fourteen Artist/Safe
cases are ABI-clean but remain unexecuted because Attribution still exceeds
production deployment admission.

The following existing suites are also required, without changing
their original oracles: OwnerCommit (flat hashes and class1/class3 Acceptance),
DelegatedReturn (nonzero return versus zero Identity record), SubjectAttestation
(all scoped/delegated original records and malformed host controls), current
publication/C2PA, original dispute/repudiation, every supported op60 import family,
and CreationCarriers. Those are regression obligations, not completed evidence.

## Measured capacity and remaining admission blocker

Paired ABI-only captures cover 985 exact sources. All 9,589 original ABI entries
across 1,120 production definitions and every recursive storage layout are
retained. All five dispatcher literals match the original compiler ABI. The
seven Owner cases passed with Solidity 0.8.19/viaIR/optimizer 200/Paris/noCBOR.

One 27-product selected capture uses the same production settings. Attribution
still fails: 29,261 runtime bytes,4,685 above24,576. An exact same-source baseline
measurement is 28,996, so this approved combination increases that host by 265
bytes despite reducing other owners. Actual Artist/Safe execution is not claimed
and must not bypass that admission failure.

| Product | Runtime bytes |
| --- | ---: |
| Identity |23,822 |
| Identity Writer |23,613 |
| Identity Estate |21,607 |
| Payout |23,879 |
| Consent Writer |23,833 |
| Coordinator |24,516 |
| Registry |24,223 |
| Factory |3,775 |
| Original fixed check |433 |

All other selected ordinary runtimes fit. Fixed constructor arguments are
included separately in retained initcode totals. The Registry includes a
caller-supplied manifest string: complete initcode is 31,719 + 416 + 32-rounded
UTF-8 URI length, so its final concrete configuration still needs its own check.
The two creation-part contracts return compiler-derived bytes from constructors;
the compiler's four-byte nominal runtime is not their deployed image. Exact
returned part sizes derive from child creation lengths: Identity 16,385/9,008,
Estate 16,385/6,974 bytes. Those four runtime images fit, but this batch has not
rerun actual Factory creation or established deployment transaction gas.

The retained local evidence directory is `.tmp-artist-admission-reviewed-evidence`.
It records approved-packet hashes, renewed review's root-reported tool-result
identifier, original denial preservation, token/ABI/storage checks, links,
selected codegen and the Owner run. No regenerated release artifacts, changed
caps, higher defaults, full current-graph acceptance or launch claim is included.
