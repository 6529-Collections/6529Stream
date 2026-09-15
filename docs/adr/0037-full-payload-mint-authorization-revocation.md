# ADR 0037: Full-payload mint authorization revocation

Status: accepted implementation direction; matching behavioral and artifact acceptance pending.

## Decision

SSA-OFFER.5 and MPA-TICKET.5 require the exact mint authorization replay key to be
voided. Manager accepts the complete permanent 18-field MintTicket, or the complete
12-field primary SaleOffer (tokenId zero). It derives the original EIP-712 digest
and then `keccak256(abi.encode(TICKET_AUTHORIZATION_DOMAIN, originalDigest))`.
This is the same authorization ID consumed by Ledger; a raw struct hash, sale ID,
nonce alone, or a custody-adapter replay key is insufficient.

The additive `IStreamMintAuthorizationRevocation` exposes typed ID previews and
`voidMintTicket(ticket, verifyingGate, signature)` / `voidMintOffer(offer,
buyerKind, signature)`. Original gate/adapter addresses are domain inputs, not
live authentication callbacks. Ticket binding requires the current chain and
actual Manager/Ledger. Primary offers require the actual Core and tokenId zero.

The authorizer may call directly. A relayer must supply a signature over the
permanent `MintTicketRevocation(uint256 chainId,address manager,address ledger,
bytes32 authorizationId)` under the original domain: `6529Stream Mint Tickets`,
version 1, original gate for tickets; `6529Stream Sales`, version 1, original sale
adapter for primary offers. The ordinary ticket/offer signature and the separate
custody `SaleOfferRevocation` signature cannot authorize this operation. Explicit
kind 1 uses canonical ECDSA (64/65 bytes, low-s); kind 2 uses ERC-1271. Code presence
does not select the signature family. No signature is rechecked for a direct caller.

Historical expired or currently unusable payloads remain voidable. Revocation
does not require a live phase, gate, sale adapter, artist, Core pointer or module
admission. It does not mint, allocate an operation nonce, consume an operation root,
nullifier or counter, or change the original payload.

## Ledger and callback boundary

The additive `IStreamMintLedgerRevocation.voidAuthorization(manager, id)` permits
only an enabled Ledger writer and requires `manager == msg.sender` and a nonzero
ID. It sets the existing manager-scoped authorization-used mapping. It adds no
storage and cannot void another Manager's lane. Consume-after-void and
void-after-consume reject with the existing `AuthorizationAlreadyConsumed` error.

Manager holds its existing reentrancy guard throughout verification and Ledger
interaction. It checks the Ledger's declared revocation capability, exact
32-byte canonical unused read, successful empty void return, and exact used
readback. Any failed or malformed boundary rolls back the entire call. Ledger
and Manager emit distinct schema-1 void events with the exact ID; no mint-consumed
event is emitted for a void. Older Ledger implementations remain usable for their
existing mint path but fail closed for the new revocation path.

## Governed signature budget

Manager appends `MINT_REVOCATION_ERC1271_GAS_LIMIT`, planned genesis 400,000 and
floor 350,000, failure-direction class 2. Calldata is constructed before an
EIP-150 parent precheck immediately before the capped ERC-1271 staticcall;
only exactly one canonical 32-byte magic word succeeds. Long/reverting return
data is never allocated. An insufficient parent budget rejects atomically.

The existing GasHost already requires governance action class 1
(DELAYED_LOOSENING), with the Executor's 48-hour minimum. Governance class 1 and
failure-direction class 2 are different enums. An earlier review proposal for a
per-parameter governance-class hook was based on conflating them and was
withdrawn before implementation. Shared GasHost bytes and all existing row
semantics remain unchanged. These planning values still require final gas
catalog/floor and current-stack acceptance.

## Size and compatibility

The current Manager baseline has only 434 runtime bytes free in the IR profile.
Two existing stored-counter preparation loops move into the typed linked
`StreamMintManagerAccounting` helper. Storage references and immutable Ledger
identity originate only in Manager; policy calculation, artist admission, policy
write and Ledger registration retain their order. There is no new shared state,
generic delegatecall entry, or change to existing ABI signatures/replay maps.
The helper's linked caller context preserves Manager identity and original caller.

The first default-profile Manager baseline and changed build both fail at the
same pre-existing PhaseState stack-depth site; IR is the executable Manager
profile for this bounded proof. Default evidence must not be claimed for Manager
until that separate baseline limitation is resolved.

## Scope

This implements Manager/Ledger revocation and canonical hash primitives. It does
not implement a MintTicketGate or the primary offer consumer that will generate
and submit these authorization IDs. The test's no-gate Manager execution checks
the real Ledger replay boundary with an explicitly supplied canonical ID; it is
not an end-to-end signed-offer mint proof. Current Core/artist composition and
canonical deployment catalog integration remain with the integrator. Existing
secondary custody offer revocation retains its distinct replay semantics.
