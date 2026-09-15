# Native burn-to-redeem

`StreamBurnRedemption` implements the no-mint burn-to-redeem mechanic in
[the sales specification](../stream-sales-and-auctions.md#burn-to-redeem).
Its caller surface is
[IStreamBurnRedemption](../../smart-contracts/interfaces/stream/mint/IStreamBurnRedemption.sol).
The source is independent of the burn-to-mint gate, which remains a separate
implementation obligation.

## Holder and operator flow

1. The operator registers an immutable program with a source collection, start
   and end timestamps, and the hash of the fulfillment terms. Registration
   records the original kind-9 sale ID and complete configuration commitment.
2. The holder reviews those terms and approves this executor through Core's
   normal ERC-721 approval API. A Safe can own the token, operate the program,
   approve the executor and make every call below.
3. The owner or its approved operator calls `redeem`, supplying the exact terms
   hash and a fulfillment reference hash plus optional public URI. The caller
   and this executor need independent ERC-721 authority. Approval of the executor
   alone never lets an unrelated caller burn the holder's token.
4. The executor records the original token owner and actual redeemer, calls
   Core's native burn, then checks the retained collection, serial and burned
   flag. Any failure rolls back both the token burn and the redemption record.
5. The program operator appends fulfillment updates. Each update retains its
   author, timestamp, reference and previous update hash. The original redemption
   stays unchanged. These are operator reports; they do not prove delivery of a
   physical object.

Programs include both time endpoints. Cancellation stops later redemptions but
does not stop fulfillment reporting for an existing redemption. Gas-parameter
updates do not change the sale ID, terms, or configuration hash.

## References, identities and events

The original five-word redemption preimage binds its domain, chain, this adapter,
Core and token ID. A token burned earlier cannot claim credit. The contract does
not mint or consume payment and never needs a separate mint-ledger nullifier.

`RedemptionRecorded` and `RedemptionFulfilled` preserve the specification's
exact event ABI. Separate version-1 context events retain the sale, serial,
original owner and append-only update fields. Programs, redemptions and updates
have indexed reads and remain readable after retirement.

Fulfillment references retain a nonzero content hash and an optional URI. An
empty URI supports a hash-only private reference. Public references accept
ASCII `https://`, `ipfs://` and `ar://` URIs up to 2,048 bytes; other characters
must be percent-encoded. Reference contents are not interpreted onchain.

## Deployment and lifecycle

Deploy with the current Core, its selected module registry, canonical parameter
governance, the initial operator, manifest commitments and the two governed gas
configurations. Register the exact runtime as `BURN_REDEMPTION_ADAPTER` with this
interface ID and module version before configuring a program. The operator may
be a Safe. Governance controls only the existing governed gas-parameter surface;
the named operator controls program terms, cancellation and fulfillment reports.

New programs require ACTIVE registration. Existing programs may continue after
DEPRECATED status when their recorded registration revision and creation time
precede deprecation. INCIDENT_REVOKED stops execution and fulfillment mutations;
historical reads and cancellation remain available. Current registry selection,
the original Core/registry code hashes, and the complete registered module
record are checked on operational calls.

Core remains the authority for source burn blocks and collection freeze. A
burn-blocked or frozen token cannot be redeemed. The complete operator workflow
still needs to join registered programs to pre-freeze/finality warnings; this
contract does not silently alter Core's burn rules.

## Verification boundary

The focused suite uses real ERC-721 approval/burn mechanics and a real 2-of-2
Safe 1.4.1, with explicit typed Core identity, registry and governance boundaries.
It checks independent approvals, immutable terms/records, exact canonical events,
pre-burn rejection, late rollback and retry, registry drift and retirement,
reentrancy, time windows, URI validation and a 256-input replay property.

Full current-Core/governance composition, operator preparation, transaction gas
limits and the matching full-v1 testnet deployment remain required. Passing this
suite does not establish those separate acceptance items.
