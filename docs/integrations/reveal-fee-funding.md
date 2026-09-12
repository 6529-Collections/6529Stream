# Fund and settle reveal fees

This guide covers the developing full-v1 coordinator. Its collection escrow and
typed fee policy pass focused tests; automatic request timing and the complete
recovery lifecycle remain in progress. Use the frozen RC1 checkout and its
artifacts for RC1 contracts.

## Read the declared policy

Use `IStreamRevealFeeEscrow` for `core()`,
`collectionRevealPolicy(collectionId)`, `revealFeeEscrow(collectionId)` and
`fundRevealFeeEscrow(collectionId)`. The interface lives under
`smart-contracts/interfaces/stream/entropy/`.

Always check `policy.declared`. A successful call returning an undeclared
policy does not authorize treating the fee as zero. `revealFeePerTokenWei` is
the declared per-token funding value. Actual request execution uses the
provider's live quote and can require additional caller funding if it rises.

For a token already minted, use its Core-recorded `coordinatorAtMint(tokenId)`
when resolving an existing reveal obligation. A later current-pointer change
does not move that token's escrow, request or caller credits to the new instance.
Verify the selected coordinator's `core()` against the intended collection Core.

## Top up and request

Any account or Safe may call `fundRevealFeeEscrow` with native currency. Funding
only credits the selected collection. It does not request randomness or send
funds to the provider. This remains available during a provider quote outage.

On a token request, the coordinator spends the lesser of that collection's
escrow and the live provider quote. The caller pays the remainder. Excess caller
value becomes that caller's `entropyFeeCredit`, claimable through
`claimEntropyFeeCredit(destination)`. Collection funds never become caller
credit. An insufficient payment or failed provider request rolls back the whole
request. Scope entropy requests use caller funds and do not spend token escrow.

For example, with a quote of 100 wei and 60 wei in collection escrow, a caller
attaching 55 wei pays 40 wei and receives 15 wei of pull credit. With 150 wei
already in escrow, attaching 25 wei leaves 50 wei in escrow and credits all
25 wei to the caller. Units here are illustrative.

## Administration and receipts

`IStreamRevealPolicyAdmin` exposes these direct operational calls:

| Call | Effect |
| --- | --- |
| `configureCollectionRevealPolicy` | Declare mode, reveal-owner role, SLO and fee before registration or freeze |
| `updateRevealFeePerToken` | Change the fee against the live typed provider quote, including after promises lock |
| `withdrawRevealFeeEscrow` | Send residual funds to the unique current treasury once the collection has no unfinished token obligations |

The calling contract must hold `ROLE_ENTROPY_ADMIN` in the canonical registry.
A Safe's owners cannot call as if they held the Safe's role. Configure the exact
`ROLE_ENTROPY_REVEAL_OWNER` role identifier; role assignment and collection policy
are separate setup steps. The treasury must resolve uniquely to a contract.
Use the [activation guide](current-artist-activation.md) for a new deployment.

Index `RevealPolicyConfigured`, `RevealFeePerTokenUpdated`,
`RevealFeeEscrowFunded`, `RevealFeeEscrowSpent` and `RevealFeeEscrowWithdrawn`
from the coordinator's address. All use schema version 1. A registered or
requested token blocks residual withdrawal until a supported terminal state.
A failed treasury transfer restores the complete escrow balance for retry.

Safe transactions use ordinary CALL with the coordinator as target and the
required native value. Inspect the Safe execution result and the protocol
events and balances; an outer receipt alone does not prove successful execution.
See [ADR 0028](../adr/0028-reveal-fee-custody-and-role-activation.md) for the
canonical role checks, provider quote capability and remaining lifecycle work.
