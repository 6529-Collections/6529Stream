# Token-specific PROFILE custody proceeds

An acquired custody token can use an explicitly approved token-specific primary
PROFILE for its later paid transfer. The token must already exist in the actual
Core and remain in uninterrupted custody. This route adds no mint, ledger
consumption or royalty snapshot at payment.

The original custody acquisition, auction configuration, creation authorization,
sale ID, sale nonce and origin stay unchanged. Before the first bid, the poster
calls `activateTokenProfileCustody` with a new authorization signed by the
original platform and the currently accepted Artist. It commits the auction,
base configuration, full origin hash, actual token, exact scope-2 assignment and
actual-token `PRIMARY_POLICY_V1` hash, Artist, nonce and deadline. The new EIP-712
domain is `6529StreamTokenProfileCustodyAllowCurrent`, version `1`. Its only
supported `primaryPolicyMode` is `1` (`ALLOW_CURRENT`). The authorization and
its resulting effective configuration are retained as an append-only record.

The Artist's original economics approval is separate from that sale activation:
the selected Revenue Resolver must authenticate the exact token-scope assignment
against the current accepted binding. A collection approval cannot authorize a
token key. A subsequent independently approved token PROFILE may replace the
opening selection before execution under `ALLOW_CURRENT`; every selection must
remain stable throughout one payment. Missing token keys, inherited collection
or default terms, and token TEMPLATE assignments are refused by this route.

Activated auctions use `bidTokenProfileCustody`,
`bidSignedTokenProfileCustody` and `settleTokenProfileCustody`. Signed bids retain
the original bid type and domain, but commit the new effective configuration.
The old bid and paid-settlement entrypoints reject activated auctions, including
old bids signed before activation. Both entry families use the original shared
bid replay and official sale-consumption state. The new bid methods support
the payer's own recipient and existing delivery bindings; they do not introduce
a new delegation proof method.

The official recorder's additive `settleTokenProfileCustodyPrimarySale` entry
reads the actual house, retained origin, activation and current token rights
before and after payment. It uses the existing native PROFILE funding and
escrow fallback, accounting, sale-consumption and result storage. The new
schema-1 `TokenProfileCustodyRevenueRecorded` receipt retains the full original
custody facts, full activation and unchanged settlement result. Its facts,
execution and candidate commitment domains are explicitly versioned for this
route; original receipts and result ABIs are unchanged.

Original no-bid return, poster cancellation, deadline refund and own NFT/refund
claims retain their current-authority exemptions. Failed NFT delivery retains
the claimant after official payment. Losing current token approval blocks new
bids and payment but does not require renewed approval to use those exits.

Focused tests use actual Core, Manager, Ledger, Resolver, factory, escrow,
recorder, house and threshold Safe with explicit typed Artist, governance and
entropy boundaries. Separate actual Artist/Safe authority tests use the original
typed unit Core/governance boundary. Their composition does not assert a joined
global deployment or transaction gas capacity. Token TEMPLATE proceeds and
primary allocation-time snapshot profiles remain separate requirements.
