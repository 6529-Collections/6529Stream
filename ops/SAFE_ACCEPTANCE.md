# Safe compatibility acceptance

The owner explicitly requires Safe compatibility throughout Stream v1. This is
an implementation and delivery requirement, owned by the integrator across all
feature lanes. The normative wallet-class and material-action requirements in
[ADR 0004](../docs/adr/0004-admin-governance.md) continue to apply.

The owner clarified that this covers **all contract calls**. The acceptance unit
is every public/external ABI function of every supported contract, including
inherited functions and overloads. Workflow examples below do not limit scope.

## Complete call inventory

Build the inventory from the final compiled ABIs and bind it to the source and
deployment configuration. For each contract/function signature/selector, record
its permission class, caller identity, Safe configuration, successful invocation
or intentional rejection, exact state/event/result assertion and test/evidence
reference. Account separately for receive/fallback and ERC-721 callbacks.

- User, artist, administrator and permissionless calls must work with an
  appropriately authorized Safe as the caller, including every setter, lifecycle
  action, cancellation, withdrawal, emergency action and role transition.
- Reads must remain usable by Safe clients and by calling contracts; test any
  caller-sensitive reads using the actual Safe context.
- Protocol-only coordinator, owner-domain and callback methods retain their
  intended caller restrictions. Exercise them through an actual Safe-initiated
  supported workflow where applicable, and prove that direct Safe calls cannot
  bypass those restrictions. A protocol-only classification requires a specific
  authorization rationale and independent review.
- Include invalid-role and owner-EOA negatives. Membership of a Safe is not a
  grant of that Safe's Stream role to its individual owners.
- Reconcile the inventory whenever an ABI changes. Every new selector creates
  a coverage obligation; missing rows or evidence prevent full acceptance.

The integrator owns the combined inventory; each builder supplies its domain's
rows and executable evidence. Final acceptance requires no unclassified or
uncovered supported ABI functions, rather than a sample of wallet workflows.

## Native artist review and complete archive progress

The new public `requireSanctionReviewFacts` selector creates a separate Safe
coverage obligation. The corrected 55-case provider/projection cohort passes
both modes, retaining the existing two named Safe cases below. Original capture
projection uses typed producer boundaries with actual SchemaRegistry/Store;
it does not establish a real Safe call through the complete manifest/Artist flow.
That selector and full ceremony gas remain pending actual assembled evidence.

The preservation builder's complete 547-item bundle flow passes with actual
archive backends and refresh. Its separate reference-stage Safe transaction
still exceeds its measured allowance. The successor's removal of redundant
large-array copies must pass that exact test and an isolated entry measurement
before this stage is accepted. Multi-stage success does not close the complete
selector or transaction-capacity inventory.

## Native provider and estate increments

The native provider's independently reviewed 27-case cohort passes both compiler
modes. A real two-owner Safe 1.4.1 calls `collectionMetadataMode` successfully and
is rejected from `requirePreparedFinalityScopeInputs`, which accepts only the
original Registry after its complete live-state checks. The failed direct Safe
attempt preserves its nonce. This proves those two named paths; complete provider
getter/manifest access, full Registry preparation and all-version/nesting coverage
remain outstanding. Input-source tests use explicit typed producer boundaries.

First estate recovery has five distinct actual outcomes in retained four-plus-one
IR captures; successor-authored guardian recovery has five cases in one IR run.
Both include actual Safe calls and owner/Archive failure/retry assertions. Broad
estate histories and the complete selector matrix remain required.

WORK/RIGHTS sealing additionally has six selector outcomes across retained five-plus-one
IR captures and five separate actual canonical-governance cases, including Safe
selection/reads and class-2 governance. The combined native provider ceremony is
still outstanding; these complementary cohorts do not establish one full deployment.

## Current route increment

The fixed discovery cohort exercises both `requireCurrentRoutes` projections and
the production strict state checker/route reader through a real threshold Safe.
Thirty-two tests pass in both modes. The full Preparation ceremony and complete Safe
selector/version/nesting reconciliation remain separate acceptance requirements.

The separate current entropy-route regression also passes both modes and calls
`requireCurrentRoute` through a threshold Safe using actual source-set/native
policy and inventory contracts. The fixture Core/governance boundaries remain
explicit; this is one selected case, not a rerun of its inherited suites.

## Reference publication and recovery increments

Native reference publication includes actual threshold-Safe publication, grant,
lock, rollback/retry and read paths. The isolated exact `execTransaction` entry
test consumes 16,070,437 gas including 906,616 intrinsic gas for its own calldata.
Its 706,779 margin is a Paris simulation for the retained native collection
profile; raw modern-fork receipts, other sizes and full version/nesting acceptance
remain open. See [the reference guide](../docs/guides/native-reference-render.md).

Guardian restoration and restricted appeals have twelve actual Artist/Safe
IR cases and five separate real governance IR cases. Their joint deployment,
maximum histories and broader recovery remain required. The onboarding oracle
includes the reviewed head-selection and root-appeal profile tags at source level;
this is not a new passing broad onboarding runtime cohort.

## Independent input-manifest increment

The [input-manifest tests](../test/unit/finality/StreamFinalityInputManifestReads.t.sol)
execute five named calls through actual threshold Safe 1.4.1: Store byte retention,
fixture original-Registry staging, encoding, exact validated read and the permanent
scope-input hash read. Fifteen cases pass both compiler modes with actual Schema
and Store and explicit Core/Metadata/Registry/governance/provider-fact boundaries.
This is not complete actual Registry or all-selector acceptance.

## Fixed discovery and native-source composition increment

The [discovery cohort](../test/unit/finality/StreamFinalityCurrentDiscovery.t.sol)
executes three named reads through a real threshold Safe: independent discovery
facts, scoped component-at-index and full discovery hash. Twenty-one discovery and
retained adapter tests pass both modes with explicit producer/Core fixtures.
This does not cover every new configuration, binding or scoped selector.

The [actual native-source cohort](../test/unit/finality/StreamFinalityEntropySourceSetCurrentCore.t.sol)
uses real Safe-initiated Executor/role/module/manifest flows to configure and
replace original coordinators, plus Safe source-set preparation. Four IR cases
pass, including two retained foundation cases. These flows add concrete coverage;
all ABI selectors, supported Safe versions and nesting still require the complete
acceptance inventory above.

## Content-root publication increment

The focused [root-publication tests](../test/unit/metadata/StreamContentRootPublication.t.sol)
use a real two-owner, two-signature Safe 1.4.1 for all five publication-interface
functions: preview, publication, current head, retained record and scoped root.
They also call the extended `artistContentFamilyState`. A separate
[composition test](../test/unit/metadata/StreamContentRootComposition.t.sol)
executes actual preserved-root publication through that Safe. Both classes of
publisher grant are exercised. This is scoped evidence; the complete ABI,
version, nested-wallet and rejection matrix above remains required, including
new constant and deployment-binding getters.

## Entropy finality evidence increment

The [entropy provider tests](../test/unit/finality/StreamFinalityEntropyEvidenceProvider.t.sol)
execute 18 actual threshold-Safe 1.4.1 transactions covering all 17 public
provider selectors and the Coordinator's native `entropyPolicyFrozen` read.
The 48-case focused/retained cohort passes both compiler modes. Core, Metadata,
membership, governance and the external oracle service are explicit boundaries;
this proves the named reads, not the complete deployment or final selector,
version and nested-wallet acceptance matrix.

## Original-coordinator inventory increment

The [inventory tests](../test/unit/finality/StreamFinalityCoordinatorInventory.t.sol)
invoke every one of this host's sixteen public ABI selectors through actual
two-signature Safe 1.4.1 calls: seven operative/history methods, eight public
binding/constant getters and ERC-165. Separate assertions check progress,
source identities, configured bindings and interface answers. The retained
15-case cohort and two added controls pass both compiler modes; the latter
also proves low-parent-gas rollback and retry.

This is complete selector invocation for this one host/version. It does not
capture return bytes inside Safe, exercise nested wallets or complete the
protocol-wide final acceptance matrix. Actual Core/Executor/Safe replacement
composition is captured separately from the focused Core-response fixture.

## Identity recovery and conservation increments

The [initial recovery tests](../test/unit/artist/StreamArtistIdentityRecoveryActual.t.sol)
use actual Artist owners, Archive and Safe authorization for the new principal,
including failed final Archive writes and exact retry, provisional contest and
dismissal. Five cases pass in IR across the retained three plus corrected two
cohorts. [Actual governance tests](../test/unit/artist/StreamArtistRecoveryActualGovernance.t.sol)
separately cover sealed delayed terminal authority, per-call witnesses, global
veto and current arbiter roles through Core/Executor/Safe. The combined real
Artist/governance deployment remains open. Registered guardian preparation/veto
and the complete admitted-history prefix are now integrated in the initial
living-artist profile, with separate reviewed actual Artist and governance
cohorts. Broader lifecycle and complete Safe acceptance remain open.

The [conservation composition tests](../test/unit/artist/StreamConservationActualArtist.t.sol)
pass three IR cases with actual Artist publication, Metadata, Schema, Store and
threshold Safes: rotation and original-voice locking, estate/lifetime separation,
and rejected signature rollback followed by prepared-interview parent adoption.
Their Core and governance remain typed test boundaries. Neither increment
completes all ABI selectors, Safe versions or nested-wallet acceptance.

## Complete original-policy consumer

The [policy tests](../test/unit/finality/StreamFinalityCoordinatorPolicyReads.t.sol)
execute both the fixed consumer and the linked public library through actual
threshold Safe 1.4.1 CALLs. All 16 cases pass both compiler modes, including
256 fuzz inputs per mode. Native coordinator, inventory and Metadata contracts
are actual; Core and governance remain named fixtures. Successful invocation
does not establish captured Safe return bytes, nesting or every protocol call.

## Shared foundation

The [description evidence tests](../test/unit/finality/StreamFinalityDescriptionReads.t.sol)
also execute the fixed consuming boundary and the linked library's sole public
read through actual threshold-Safe 1.4.1 transactions. All 23 cases pass both
compiler modes. This consumes actual WORK/RIGHTS selectors, Metadata, Schema and
Store, with explicit Core/artist/Executor boundaries; it does not complete the
eventual provider's deployment or full-call acceptance matrix.

Use the [pinned official Safe fixtures](../test/fixtures/safe/README.md) and
[shared helper](../test/helpers/OfficialSafeFixture.sol). Baseline versions are
1.3.0, 1.4.1 and 1.5.0 with the appropriate CompatibilityFallbackHandler. Start
with actual 2-of-3 ownership, then measure explicitly named larger thresholds
and nested configurations. Record the exact supported configuration and gas
envelope; do not imply arbitrary handler, guard or nesting support.

The existing legacy MockSafeERC1271Signer and governance SafeRehearsal test
useful contract-wallet boundaries, but neither is official Safe interoperability
evidence. The legacy ForkSmoke name does not establish an actual chain fork.

## Required working flows

| Lane | Owner | Acceptance evidence still required |
| --- | --- | --- |
| Governance/admin | Integrator | Real Safe transaction publishes/schedules/cancels and executes actual governance actions, grants/revokes roles, pauses/unpauses, and performs finality/recovery when implemented; verify actual targets and multisig-compatible time windows |
| Artist | Artist builder | Actual Safe artist completes every required consent floor and a current mint; threshold, signer rotation, domain, state, nonce and expiry negatives; later artist operations retain the same capability |
| Purchases/auctions | Revenue builder + integrator | Safe pays native ETH, approves ERC-20 and buys, signs relayed payment intents, acts as artist/platform signer, bids and receives refunds; account owners and relayers cannot impersonate the Safe payer |
| Claims and releases | Revenue builder | Actual Safe receives native/ERC-20 from 20 split wallets, executes direct payout redirection, and signs/revokes release authorizations with exact entitlement and replay accounting |
| NFT custody | Integrator | Current Core mint/safeTransfer into a real Safe, approval and transfer out through Safe execution, and auction delivery; absent/incompatible receiver handler causes atomic rejection |
| Client/operator | Integrator | Reviewable to/data/value and Safe transaction-builder output, asynchronous threshold signing, exact Safe nonce/hash, complete-envelope simulation, and confirmation of Safe plus protocol outcomes |

## Source and test obligations

The additive sale-domain getters have focused
[actual Safe read and purchase tests](../test/unit/revenue/StreamSaleSigningDomains.t.sol).
They cover all three published domains, exact digest reconstruction, fixed and
price-program native purchases, and chain/address fuzzing. Core, Manager and
artist providers in that suite are explicit domain fixtures. These results
establish the named discovery paths; complete current-contract composition and
the final selector inventory remain required. Client selection is documented in
the [sale-domain guide](../docs/integrations/sale-signing-domains.md).

- Verify contract-wallet signatures through the actual configured ERC-1271
  handler, with opaque variable-length bytes. SafeMessage wrapping, threshold
  ordering, nested dynamic offsets and real onchain message approvals need tests.
- Keep direct Safe execution distinct from relayed signatures. No tx.origin,
  EOA-only recipient checks, owner-address substitution or assumed contract-wallet
  support for ordinary ERC-20 permits. Safe-origin approve must remain usable.
- Exercise actual ERC-721 receiver callbacks and native ETH receipt. Record
  exact token ownership, recipient balances and payment conservation.
- Check Safe execution success and the intended protocol event/state. A mined
  outer transaction alone does not prove the enclosed protocol call succeeded.
- Measure each actual verifier with cold transaction access and supported nested
  configurations. Reconcile governed floors and genesis caps with measured
  requirements; do not label a fixture-warm measurement all-cold.
- Retain existing malformed-signature, gas-exhaustion and returndata tests.
  Add real Safe happy paths and state-changing negative cases alongside them.
- Preserve the other normative supported wallet classes: governor contracts,
  P-256/WebAuthn and the specified EIP-7702 behavior. Safe work does not narrow
  that class or justify unrestricted external-call gas.

Current source work includes replacing/reconciling StreamSaleSignatures' fixed
100,000-gas cap and delegated-EOA handling across native sales and auctions,
and moving payment/release verification to the correct governed host. The new
artist implementation must consume its real governed cap. These are explicit
unfinished obligations, even if a small Safe passes existing verification.

Safe acceptance is complete only when the actual integrated flows above, their
supported configurations, independent review, developer guidance and matching
candidate evidence are retained. The shared foundation is the first increment.

## Original-entropy source-set and historical-recovery increments

The [source-set tests](../test/unit/finality/StreamFinalityEntropySourceSet.t.sol)
use a real two-signature Safe 1.4.1 for permissionless preparation, current
component discovery, source-set validation, finality state, retained policy and
token output reads. The source-set/policy cohort has 31 passing cases in both
compiler modes. This covers the named calls; new binding/constant getters, every
ABI selector, other Safe versions and nested-wallet acceptance remain tracked
by the complete inventory requirement above.

The [historical recovery tests](../test/unit/artist/StreamArtistRecoveryHistoricalActual.t.sol)
pass four IR cases with actual Artist owners, Archive and Safe authority,
including earlier ordinary rotations, resolved contests, discarded guardian veto
and atomic failure/retry. Core and Executor remain typed boundaries; complete
real governance composition and the broader recovery profiles remain required.
