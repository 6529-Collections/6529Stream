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

## Shared foundation

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
