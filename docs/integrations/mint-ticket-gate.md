# Signed mint ticket gate

`StreamMintTicketGate` validates the permanent 18-field `MintTicket` against the
actual mint batch. It admits one immutable signer and one explicit signature
kind per deployed gate. A Safe can provide a threshold signer policy. The gate
is view-only: successful validation does not consume an allowance or replay key.

The canonical requirements are [MPA-TICKET and MPA-AUTHZ](../mint-policy-and-accounting.md#canonical-signed-ticket)
and [ADR 0037](../adr/0037-full-payload-mint-authorization-revocation.md).

## Deploy and configure

Deploy `StreamMintTicketGate(governanceAuthority, signer, kind)` with a nonzero
signer and kind `1` (`EOA_712`) or `2` (`ERC1271_712`). `NONE` and
`CALLER_ADAPTER` are unsupported. Kind selection never depends on whether the
signer currently has code; a delegated EOA can still sign with its own key under
kind `1`.

The immutable `gateConfigHash()` is:

```solidity
keccak256(abi.encode(
    keccak256("6529STREAM_MINT_TICKET_GATE_CONFIG_V1"),
    address(signer),
    uint8(kind)
))
```

Admit the gate through the active Module Registry and configure the phase with
its address, this exact configuration hash, and the registry's codehash,
metadata, semantic version and gas pin. The gate checks that the actual Manager
reports this gate and this configuration hash for the requested phase. A ticket
signed by another address cannot supply its own authorization policy.

Changing the authorized signer requires a new gate deployment and a new phase
policy. Governance gas raises do not change the configuration hash. Safe owner
changes follow that Safe's own authorization rules and affect later ERC-1271
checks; they do not change the gate's signer address.

## Build and sign a ticket

Use `StreamMintTicketTypes.MintTicket` and `StreamMintTicketHash`; do not create
a parallel type string or hash a JSON serialization. The EIP-712 domain is:

| Field | Value |
| --- | --- |
| `name` | `6529Stream Mint Tickets` |
| `version` | `1` |
| `chainId` | Current chain |
| `verifyingContract` | Ticket gate address |

`eip712Domain()` exposes these fields through ERC-5267 (`fields = 0x0f`, no salt
or extensions). The ticket also binds the actual Manager and its configured
Ledger, collection, phase, executor, payer, signer and signature kind, quantity,
context, expected policy, nonce and deadline. Executor, payer, initial recipient,
beneficiary and signer remain distinct identities.

Compute the four array fields from the complete, ordered batch:

```solidity
ticket.initialRecipientsHash = keccak256(abi.encode(
    keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), batch.initialRecipients
));
ticket.beneficiariesHash = keccak256(abi.encode(
    keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), batch.beneficiaries
));
ticket.tokenDataArrayHash = keccak256(abi.encode(
    keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), batch.tokenData
));
ticket.mintCommitmentsHash = keccak256(abi.encode(
    keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), batch.mintCommitments
));
bytes32 digest = StreamMintTicketHash.digest(block.chainid, address(gate), ticket);
batch.authorizationId = StreamMintTicketHash.authorizationId(digest);
bytes memory gateData = abi.encode(ticket, signature);
```

The array hashes use distinct domains even when the arrays contain identical
addresses. `tokenDataArrayHash` hashes the entire `bytes[]`, including each
element's boundaries. It is distinct from a single token's `tokenDataHash`.
All four arrays must have the same nonzero length and the ticket quantity must
equal that length. Manager enforces its additional batch and recipient rules.

EOA signatures support canonical 65-byte `r,s,v` and 64-byte EIP-2098 encoding.
High `s`, invalid `v`, zero recovery and recovery to another signer all fail.
For Safe 1.4.1 with its compatibility fallback handler, the owners sign the
Safe's `SafeMessage(bytes)` envelope over `abi.encode(digest)` under the Safe's
own domain. Concatenating owner signatures over the raw ticket digest fails.

## Full-batch Manager dispatch

The gate advertises both the original `IStreamMintGate` and the additive
`IStreamMintBatchGate` ERC-165 capabilities. Manager's validator detects the
latter and calls:

```solidity
gate.validateMintBatch(address(manager), executor, batch, gateData);
```

The original `validateMint` ABI omits `tokenData` and `mintCommitments`. Calling
it on this gate always reverts with `MintTicketFullBatchRequired`. Older
Managers that only implement that selector cannot use this gate.

The returned result contains the full-digest authorization ID, signer and kind,
exact quantity, no nullifiers, and the EIP-712 digest as `gateHash`. Equivalent
valid signature presentations return identical evidence. The canonical ticket
does not sign the raw `resolverData` proof presentation; Manager's active counter
policy validates those proofs separately.

The ticket policy must equal the batch's expected policy and be either current
or the exact immediate predecessor within its grace window. The deadline and
grace boundary are inclusive. Gate admission, executor permission, pause/time
checks, replay and actual counter consumption remain Manager/Ledger duties.

The additive [executor policy grace](mint-policy-grace.md) path registers this
window through an actual consented Manager policy rotation. Keep the original
ticket, signature and batch hash; do not rewrite them to the new current hash.

## Replay and revocation

The required ID is
`keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest))`.
The gate rejects a batch that supplies another ID. Manager must consume that
exact ID through Ledger before calling Core. Reusing a signature encoding or
replacing a 65-byte signature with its compact form produces the same ID.

To revoke an unused ticket, present the complete original ticket and original
gate address through Manager's `voidMintTicket` surface. Direct authorizer calls
and separately signed relayed revocations follow ADR 0037. Expiration, phase
pause and replacing this gate are separate from durable revocation. Gate
previews remain view-only after consumption or revocation; Ledger rejects
execution of the consumed ID.

## Gas and acceptance boundary

ERC-1271 uses `TICKET_ERC1271_GAS_LIMIT`, initially `400,000` with an immutable
`350,000` floor and failure class `2` (`FAIL_CLOSED_PRECHECK`). The shared
Governance-V2 parameter host permits only exact class-1 delayed raises, at most
twice the current value. A zero authority permanently disables raises. The
canonical executor owns the minimum 48-hour delay; the gate authenticates its
executing action context.

The gate constructs the signature call before checking the EIP-150 parent
budget. Reverting, exhausted, short, oversized and noncanonical ERC-1271 returns
fail closed; only one exact 32-byte magic word succeeds. The Manager's outer
gate gas budget must cover the signature cap plus nested-call overhead. A
`400,000` outer budget cannot forward the initial `400,000` signature cap;
start focused sizing with a gate pin of at least `600,000`. Final supported
wallet-class and large-batch measurements must size both budgets together.

`test/unit/mint/StreamMintTicketGate.t.sol` exercises the real gate and real
Safe 1.4.1 bytecode using an explicit Manager read fixture. Its scope includes
full payload and domain mismatches, malformed signatures, gas boundaries and
governed parameter identity. It does not prove current Core admission, durable
Ledger replay or replacement continuity. Those require the combined actual
Manager/Ledger/Core acceptance suite and final gas evidence.
