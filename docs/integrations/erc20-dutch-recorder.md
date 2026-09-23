# Closed ERC20 Dutch recorder entries

The recorder exposes separate signed and public standard-Dutch entries through
`IStreamERC20DutchPrimarySaleSettlement` and
`IStreamERC20PublicDutchPrimarySaleSettlement`. Both accept the existing
`ERC20SettlementCandidate` plus the original Payment adapter address, and
return the unchanged 384-byte `PrimarySettlementResult`.

Signed candidates require authority mode `1` and a nonzero original Sales
digest. Public candidates require mode `2` and a zero digest. Both entries
require a positive amount, original mint operation identities and strict
primary rights. Original fixed-price admission and recorder entries retain
their prior semantics.

The additive admission path is closed to the registered
`DUTCH_AUCTION_ADAPTER` role, original ERC20 execution capability and the exact
standard-Dutch resolution profile. It retains the original immutable sale and
Payment lifecycle checks. The public producer additionally exposes:

- `publicERC20SaleBinding(saleId)`: exact collection, phase, configuration hash
  and public authority mode, returned as four words.
- `activePublicERC20Candidate(executionId)`: the exact
  `candidateCommitment(paymentAdapter, recorder, candidate)`, returned as one
  word during the in-progress call.

The public recorder authenticates those reads at entry and after both funding
and routing. Changed or malformed records and witnesses revert atomically.
The original funding callback, exact token balance deltas, replay map,
official totals, revenue routing, result and permanent conservation floor
remain in the path. Zero outcomes do not enter either paid recorder method.

The recorder-only regression suite uses actual Core, Manager, Ledger, Registry,
Resolver, wallets, escrow and Floor with explicit typed sale and funding
boundaries. It establishes no runtime acceptance for the production Dutch
price resolver or Payment authorization path; their combined integration and
the shared current-stack capture are separate evidence.
