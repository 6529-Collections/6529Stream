# Stream Collection Facade Profile

Specification status: Draft. This document follows
[`docs/spec-policy.md`](spec-policy.md) and implements
[ADR 0015](adr/0015-collection-identity-and-facade-readiness.md)
decisions W3, W4, and W5. It is a dormant extension profile, not a
launch component: no facade exists in the genesis deployment, the
genesis system is physically free of facade bytecode, and a facade
becomes deployable only through the ADR 0015 decision W3 tripwire
procedure ([Deployment Decision Procedure](#deployment-decision-procedure)).
The profile is specified in full now so that a tripwire deployment is a
review-and-deploy exercise, never a design sprint (ADR 0015 decision
W5).

This document is the normative home for the per-collection ERC-721
facade: the facade interface and identity reads, the local-serial token
identity rule and the catalog-number read, the facade side of the
routed ownership-mutation path, the facade-local approval model,
exclusive ERC-721 `Transfer` emission, delegation of `tokenURI`,
`royaltyInfo`, and `contractURI` to Core and the metadata router, the
metadata-refresh relay, per-facade Permanent-class requirements, the
facade threat model, and the deployment decision procedure. Other
documents cite these definitions and must not restate them (ADR 0010
decision D3.1).

Boundaries with the neighboring homes:

1. Core-side facade readiness is not defined here. The identity-mode
   vocabulary (`CORE_NATIVE`, `EXTERNAL_FACADE`), the one-way
   pre-first-mint mode declaration, the transfer-controller registry,
   the controlled mutation path and its invariant set, the
   controlled-ownership-change event family, the native-entry revert
   rules, and the finality identity binding record family are dormant
   Core genesis surfaces (ADR 0015 decision W4): the umbrella
   architecture owns the identity-mode doctrine
   ([`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-IDENTITY-MODE]) and the protocol v1 specification owns the
   surface shapes, event schemas, and domain constants
   ([`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
   [PV1-IDENTITY-MODE] and [PV1-TRANSFER-CONTROLLER]). This document
   consumes those surfaces and defines only the facade side of each
   boundary.
2. The normative collection-identity signal (ADR 0015 decision W1) is
   owned by
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   ([MRR-COLLECTION-DISCOVERY]) for the reads and by
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   ([CMC-COLLECTION-IDENTITY-JSON]) for the
   `properties.stream.collection` token-JSON member set. A facade adds
   the address-keyed grouping key on top of that signal; it never
   replaces it. Router and renderer serving is identity-mode
   independent ([MRR-FACADE-SERVING]).
3. For artist-bound collections the `EXTERNAL_FACADE` mode declaration
   joins the artist consent/veto surface of
   [`docs/stream-artist-authority.md`](stream-artist-authority.md)
   ([AA-CONTENT]) — the mode changes the marketplace identity of the
   work, so the declaration is consent-gated at the same authority
   level as a content-affecting write (ADR 0015 decision W4.1). This
   document adds no consent rule of its own.
4. The Governed Gas Parameter model is owned by
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-GGP]. The facade introduces no new Governed Gas Parameter
   ([FCP-READS] rule 6).
5. The conformance matrix
   ([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md))
   owns every gate this profile names, including the ADR 0015 decision
   W2 marketplace-commitment gate whose failure arms the tripwire.

## Design Summary

```text
Two-layer identity split for one EXTERNAL_FACADE collection:

  StreamCore (Permanent, shared, state-authoritative)
    ownership storage, token identity, supply facts, locks,
    finality components, record chains, state exports,
    controlled mutation path, controlled-ownership-change events

  StreamCollectionFacade (Permanent, per-collection,
                          marketplace-authoritative)
    the ERC-721 address venues index for this collection:
    exclusive Transfer emitter, approval surface, transferFrom
    entry, tokenId = collection-local serial, delegated
    tokenURI / royaltyInfo / contractURI, ERC-4906 relay

Routed transfer:
  owner or operator
    -> facade.transferFrom / safeTransferFrom
         (facade-local approvals + Core ownerOf checks)
    -> Core controlled mutation path
         (full native invariant set; settles ownership,
          record chains, controlled-ownership-change event)
    -> terminal callback onStreamOwnershipChange
         (facade updates bookkeeping, emits Transfer)
    -> facade onERC721Received check (safe variants, last step)

Mint (manager-only, both modes):
  mint path -> Core ownership materializes
    -> same terminal callback
    -> facade emits Transfer(0, collector, serial)

Burn (facade entry, burnable collections only):
  owner or operator -> facade.burn
    -> Core controlled mutation path (to = 0, native preconditions)
    -> same terminal callback
    -> facade emits Transfer(owner, 0, serial)
```

The facade holds no funds, no ownership state, and no governance: it is
an immutable, ownerless projection of Core state onto a per-collection
ERC-721 address, plus the approval state that ERC-721 venues require at
that address.

## Scope And Architecture

Requirements [FCP-SCOPE]:

1. Two-layer identity split. For a collection in `EXTERNAL_FACADE`
   mode, Core is the state-authoritative record — ownership storage,
   token identity, supply facts, locks, finality components, record
   chains, and state exports — and the facade is the
   marketplace-authoritative ERC-721: the exclusive ERC-721 `Transfer`
   emitter, the only approval surface, and the only
   `transferFrom`/`safeTransferFrom` entry for its collection. State
   reads, record chains, and state exports are mode-independent
   (ADR 0015 decision W4.4; export mechanics per
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-EXPORT]).
2. Cardinality. One facade fronts exactly one `EXTERNAL_FACADE`-mode
   collection of exactly one Core, and that collection binds exactly
   one transfer controller — its facade — one-way, before its first
   mint (ADR 0015 decision W4.2). A facade serving two collections, a
   collection served by two facades, and a rebindable controller are
   all nonconformant by construction.
3. Profile permanence. The interfaces, identity rules, emission rules,
   and invariants in this document are Permanent and frozen at the
   depth of the other frozen extension profiles (for example
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   [SSA-SEALED]): a future facade implementation requires its own
   accepted module spec against this profile and passes through the
   deployment decision procedure ([FCP-DEPLOYMENT]). No genesis
   implementation exists.
4. Prior art. Every mechanism the facade composes has precedent —
   ERC-7631/DN404 mirror-contract emission and ENS registry-fronting
   are the mechanism precedents — but no production
   deployment composes them at per-collection cardinality; the facade
   is a first-of-kind composite, and that status is why deployment
   requires the dedicated adversarial review of ADR 0015 decision W3
   rather than routine module registration (ADR 0015; containment
   finding ADR 0014 decision V9).
5. Reserved capability. Facade deployment applies only to collections
   created after a go decision under [FCP-DEPLOYMENT]; retrofit of a
   minted `CORE_NATIVE` collection is excluded permanently because
   identity mode is one-way and pre-first-mint (ADR 0015 decision W3).
   Absence of a facade changes nothing for `CORE_NATIVE` collections:
   the W1 identity signal is the platform-wide collection-identity
   contract in both modes.
6. Sales/custody seam. The genesis sale, custody, and burn layer of
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   executes native Core ERC-721 mutation entries on already-minted
   tokens — custody entry, custody-to-recipient delivery, custody
   release, pull NFT claims — and `Core.burn` on burn-program
   sources: exactly the entries Core closes for `EXTERNAL_FACADE`
   collections ([PV1-TRANSFER-CONTROLLER] requirement 8).
   Custody-settling sale kinds and Stream-source burn programs are
   therefore excluded for `EXTERNAL_FACADE` collections at
   configuration time — never discovered at settlement — with the
   configuration-time gate owned by [SSA-IDENTITY] rule 9 in the
   sales specification (ADR 0015 decision W3). Mint-delivery sale
   kinds are unaffected in both modes, because minting routes the
   manager path and the terminal controller callback ([FCP-MINT]
   rule 1). Reconciling the seam through facade-aware adapter
   profiles is a mandatory scope item of the tripwire review
   ([FCP-DEPLOYMENT] rule 2).

## Facade Token Identity

Requirements [FCP-IDENTITY]:

1. Local token ID rule. The facade-local ERC-721 `tokenId` is the
   collection-local serial exactly as Core stores it
   (`collectionSerial` of `tokenCollectionIdentity`,
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-IDENTITY]): serial `n` is facade token ID `n`, dense from 1 in
   mint order (ADR 0015 decision W4.6). No offset, remapping, or
   reassignment exists, and the rule is fixed at facade deployment and
   immutable for the life of the facade.
2. Catalog-number read. `streamCatalogTokenId(uint256 localTokenId)`
   returns the Core global sequential token ID — the protocol catalog
   number (ADR 0009 decision 1) — for the given local serial. The read
   answers for every serial the collection has ever minted, including
   burned serials (retained identity per [LTA-IDENTITY] rule 5), and
   reverts with `FacadeUnknownLocalToken` for a serial never delivered
   through the mint callback ([FCP-MINT]).
3. Reverse read. `streamLocalTokenId(uint256 catalogTokenId)` returns
   the local serial for a Core global token ID. It must be derived from
   Core's `tokenCollectionIdentity(catalogTokenId)` at call time, must
   revert with `FacadeUnknownCatalogToken` when the mapping does not
   exist or the collection ID is not `streamCollectionId()`, and must
   never consult facade-local storage, so the answer can never diverge
   from Core state.
4. Binding reads. `streamCore()` returns the one Core address and
   `streamCollectionId()` returns the one collection ID the facade
   fronts. Both are set at deployment, immutable, and must equal the
   Core-side controller-registry binding for the collection
   ([PV1-TRANSFER-CONTROLLER] requirements 1-2); the deployment
   ceremony proves the equality ([FCP-DEPLOYMENT] rule 4).
5. Mapping storage. The facade stores the `localTokenId ->
   catalogTokenId` mapping itself, written exactly once per serial by
   the mint callback ([FCP-MINT] rule 2), never mutated, and retained
   after burn. Because the controller binding precedes the collection's
   first mint (ADR 0015 decision W4.2), the facade observes every mint
   of its collection; no backfill path exists or is needed.
6. Name and symbol. `name()` and `symbol()` are fixed at deployment and
   must equal the collection's registered name facts in the collection
   metadata satellite at deployment time
   ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md)).
   They never change afterward, and their permanence is transitive,
   not payload-borne: the facade identity binding record family binds
   the facade address and its local-ID rule into the collection's
   finality components — the pinned payload carries no name or symbol
   members (record family home
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-FACADE-BINDING]) — and that immutable address resolves the
   immutable `name()`/`symbol()` for the life of the facade
   (ADR 0015 decision W4.5; finality-component rule
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-FINALITY] requirement 16).
7. Supply read. `totalSupply()` returns Core's pinned per-collection
   supply read `totalSupplyOfCollection(streamCollectionId())` at call
   time — the collection's live token count, minted-ever minus burned,
   mode-independent, a Permanent facade-readiness genesis read
   ([PV1-FACADE-READINESS] in
   [`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md);
   ADR 0015 decision W4.6) — with no facade-local supply storage. This
   is the collection-scoped ERC-721 meaning at the facade address;
   Core's own `totalSupply()` remains the global count
   ([LTA-ENUMERATION]).

## Interface

The complete facade surface. Signatures of the standard members are
byte-for-byte the published standard signatures; the events deliberately
carry no `schemaVersion` field because marketplace consumption requires
the exact ecosystem shapes, and the facade defines no Stream-native
event of its own. All facade events register in the machine-readable
event catalog with these standard signatures
([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
[LCM-EVENTS]).

```solidity
// IStreamTransferController — the terminal ownership-change callback
// receiver — is owned by the protocol v1 specification
// ([PV1-TRANSFER-CONTROLLER] in docs/launch-v1-target-architecture.md)
// and is not restated here: the facade implements it by inheritance,
// with mint, transfer, and burn distinguished by the ERC-721
// zero-address conventions of that home (from == address(0) is mint,
// to == address(0) is burn).

interface IStreamCollectionFacade is IStreamTransferController {
    // ERC-721
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function balanceOf(address owner) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool approved) external;

    function getApproved(uint256 tokenId)
        external
        view
        returns (address);

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    // ERC-721 Metadata
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 tokenId)
        external
        view
        returns (string memory);

    // ERC-165
    function supportsInterface(bytes4 interfaceId)
        external
        view
        returns (bool);

    // ERC-2981
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);

    // ERC-7572
    event ContractURIUpdated();

    function contractURI() external view returns (string memory);

    // ERC-4906 relay for the facade-local id space
    event MetadataUpdate(uint256 _tokenId);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    // Stream identity reads
    function streamCore() external view returns (address);

    function streamCollectionId() external view returns (uint256);

    function streamCatalogTokenId(uint256 localTokenId)
        external
        view
        returns (uint256);

    function streamLocalTokenId(uint256 catalogTokenId)
        external
        view
        returns (uint256);

    function totalSupply() external view returns (uint256);

    // Conditional member: present exactly when the collection's burn
    // posture permits burning ([FCP-MINT] rule 4); absent otherwise.
    function burn(uint256 tokenId) external;

    // Metadata refresh relay (Core refresh-authority class only)
    function relayMetadataUpdate(uint256 localTokenId) external;

    function relayBatchMetadataUpdate(
        uint256 fromLocalTokenId,
        uint256 toLocalTokenId
    ) external;

    function relayContractURIUpdated() external;
}
```

Requirements [FCP-INTERFACE]:

1. A conformant facade implements every member above with the stated
   semantics; the facade additionally exposes the canonical module
   identity surface of
   [`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-MODULE-ID] ([FCP-PERMANENCE] rule 4).
2. `supportsInterface` reports truthfully, golden-tested as an exact
   truth table:
   - `0x01ffc9a7` (ERC-165): true;
   - `0x80ac58cd` (ERC-721): true;
   - `0x5b5e139f` (ERC-721 Metadata): true;
   - `0x2a55205a` (ERC-2981): true;
   - `0x49064906` (ERC-4906): true;
   - `0xe8a3d485` (the derived single-selector interface ID of
     ERC-7572 `contractURI()`): true;
   - `0x780e9d63` (ERC-721 Enumerable): false, permanently — the
     facade carries no enumerable index, consistent with the Core
     enumeration posture (ADR 0012 decision T10; [LTA-ENUMERATION]).
     Per-owner and per-collection enumeration is served by state walks
     and the periphery enumeration lens over Core, not by the facade.
3. `IStreamCollectionFacade`'s own ERC-165 interface ID and the
   interface ID recorded in the facade's module registry record are
   pinned under the protocol v1 selector discipline ([PV1-DOMAINS])
   when implementation constants are pinned. The
   `onStreamOwnershipChange` shape, its selector constant
   (`ON_STREAM_OWNERSHIP_CHANGE_SELECTOR`), and its acknowledgment
   rule are owned by [PV1-TRANSFER-CONTROLLER]; this profile defines
   no numeric vocabulary and no hash constant beyond [FCP-DOMAINS].
4. The callback and relay members are part of the Permanent profile
   interface. The facade implements `IStreamTransferController`
   exactly as pinned at its home ([PV1-TRANSFER-CONTROLLER]
   requirement 10): mint, transfer, and burn arrive through one
   callback distinguished by the ERC-721 zero-address conventions,
   `collectionSerial` carries the facade-local token ID, and `data`
   is opaque context that the facade must accept without decoding
   obligations. This document owns the receiver-side duties
   ([FCP-ROUTING] rule 3); the caller-side ordering, invariants, and
   acknowledgment verification stay at the Core home.
5. No payable surface exists: no facade function is `payable` and the
   facade has no `receive` or `fallback` function. Value can reach a
   facade only by force (selfdestruct of a third contract, coinbase);
   forced value is permanently stranded by design — the facade is
   ownerless and has no sweep surface, and this is disclosed rather
   than mitigated.

## Mutation Routing

Requirements [FCP-ROUTING]:

1. Entry validation. `transferFrom(from, to, tokenId)` and both
   `safeTransferFrom` variants must verify, against current state and
   before any external call: `to != address(0)`; the token is mapped
   ([FCP-IDENTITY] rule 2); `from` equals the current owner read live
   from Core `ownerOf(streamCatalogTokenId(tokenId))`; and
   `msg.sender` is authorized by the facade-local approval state —
   `msg.sender == from`, `msg.sender == getApproved(tokenId)`, or
   `isApprovedForAll(from, msg.sender)`. Failing any check reverts;
   no partial effect exists.
2. Routing. After validation the facade calls Core's
   `controlledOwnershipChange(streamCollectionId(),
   streamCatalogTokenId(tokenId), from, to, "")` — the facade always
   passes empty `data` on routed transfers, pinned so two facade
   implementations of one collection are call-shape identical. For a
   transfer the controlled path enforces exactly the native transfer
   invariant set and nothing more: current-owner match and a nonzero
   recipient. Native transfers are unconditioned on this Core line —
   locks, finality components, and pause never gate ownership
   transfer, in either identity mode
   ([`docs/stream-long-term-architecture.md`](stream-long-term-architecture.md)
   [LTA-STANDARDS]; ADR 0015 decision W4.3) — so no conformant
   implementation reads a lock, finality, or pause check into the
   routed transfer path; anything stricter would make facade tokens
   soulbound where native tokens transfer freely. The native
   burn-precondition suite applies only to the `to == address(0)`
   burn case ([FCP-MINT] rule 4). The controlled path settles all
   Core state and record-chain writes before the terminal callback
   (path home [PV1-TRANSFER-CONTROLLER] requirements 6-9). The facade
   never mutates ownership by any other route and holds no ownership
   state to mutate.
3. Terminal callback. Core invokes
   `onStreamOwnershipChange(collectionId, tokenId, collectionSerial,
   from, to, data)` on the registered controller as the terminal step
   of every ownership mutation of the collection — mint, transfer,
   and burn, distinguished by the ERC-721 zero-address conventions
   (ADR 0015 decision W4.3; [PV1-TRANSFER-CONTROLLER]
   requirement 10). The facade must: (a) revert with
   `FacadeUnauthorizedCallback` unless `msg.sender == streamCore()`;
   (b) revert with `FacadeCollectionMismatch` unless
   `collectionId == streamCollectionId()`, and with
   `FacadeInvalidOwnershipChange` when `from` and `to` are both the
   zero address; (c) apply exactly the bookkeeping of [FCP-MINT] and
   rule 4 for the mutation kind; (d) emit exactly one ERC-721
   `Transfer(from, to, collectionSerial)`; (e) make no call to any
   Core ownership-mutation entry — Core reverts within-callback
   mutation reentry ([PV1-TRANSFER-CONTROLLER] requirement 9), and
   attempting it is nonconformant; and (f) return
   `ON_STREAM_OWNERSHIP_CHANGE_SELECTOR`, which Core verifies. A
   callback revert unwinds the entire mutation at Core;
   settled-but-unnotified state cannot exist.
4. Facade effects locus. All facade state writes driven by ownership
   change — per-owner balance bookkeeping, per-token approval reset,
   and the mint mapping write — happen inside the callback and nowhere
   else, so every mutation kind (routed transfer, mint delivery, and
   burn) produces identical facade bookkeeping through one code path.
   For a transfer (`from` and `to` both nonzero): the facade must
   verify the token is mapped, decrement `balanceOf(from)`, increment
   `balanceOf(to)`, and clear the per-token approval. The approval
   reset emits no `Approval` event: EIP-721 defines the `Transfer`
   emission as implying the reset, and a redundant mirror emission is
   banned (ADR 0011 decision R12 posture).
5. Checks-effects-interactions is mandatory at both layers: Core
   settles all state and record-chain writes before the callback
   (Core-side rule, ADR 0015 decision W4.3), and the facade performs
   all checks against pre-call state (rule 1), performs its writes
   only inside the callback (rule 4), and performs the receiver
   interaction (rule 6) strictly after the routed mutation — callback
   included — has completed. No facade state write may follow the
   receiver call.
6. `safeTransferFrom` receiver check. After the routed mutation
   returns, if `to` has code the facade must call
   `onERC721Received(msg.sender, from, tokenId, data)` on `to`
   (`data = ""` for the three-argument variant) and revert unless the
   ERC-721 magic value returns. The call is made with unbounded gas
   per ERC-721 semantics: a hostile receiver can revert only the
   caller's own transfer, so no Governed Gas Parameter bound applies —
   in contrast to the bounded third-party delivery paths of
   [`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   ([SSA-ENGLISH] rule 7), where a receiver could block someone else's
   settlement. `transferFrom` performs no receiver call.
7. Reentrancy posture. The facade must be reentrancy-safe with no
   transfer-entry mutex, proven by the [FCP-GATES] routed-mutation
   suite:
   - the only untrusted code executed in any facade flow is the
     rule 6 receiver call, which runs after Core and facade state are
     fully settled, so every read a reentrant caller performs
     observes a consistent, completed mutation;
   - nested transfers initiated from a receiver hook are permitted
     and safe — each nested mutation is a complete
     validate-route-callback-check sequence over settled state, and a
     transfer-entry mutex is nonconformant because it breaks
     legitimate receiver-initiated composition;
   - reentering Core directly is closed independently: native
     ERC-721 mutation entries revert for the collection (ADR 0015
     decision W4.3; [PV1-TRANSFER-CONTROLLER] requirement 8) and the
     controlled path rejects every caller except the registered
     controller;
   - reentering the callback is closed by rule 3(a): only the bound
     Core may call it, and Core calls it only as the terminal step of
     a mutation it has fully settled;
   - `approve`/`setApprovalForAll` reached reentrantly operate on
     settled state and create no inconsistency window.
8. Prepared-incomplete allocations. Core token identity in
   `PREPARED_INCOMPLETE` lifecycle ([LTA-IDENTITY]) triggers no
   callback and no facade surface: the facade learns of a token only
   at the mint callback, when ERC-721 ownership first exists. Facade
   reads for a serial not yet delivered revert per [FCP-IDENTITY]
   rule 2 exactly as for a never-allocated serial.

## Approvals

Requirements [FCP-APPROVALS]:

1. Approval state — the per-token approved address and the
   owner-to-operator approval map — lives only in the facade, and
   Core approval state is inert for the collection, permanently
   (ADR 0015 decision W4.3): Core's native `approve` reverts per-token
   for the collection's tokens, Core `getApproved` returns
   `address(0)` for them, and a Core-level operator grant conveys no
   authority over them because every native entry that would consume
   it reverts. The Core-side revert conditions and the contract-wide
   `setApprovalForAll` scoping are owned by
   [PV1-TRANSFER-CONTROLLER] requirement 8.
2. `approve(to, tokenId)` requires the token to be mapped and
   `msg.sender` to be the current Core-read owner or an operator
   approved by that owner; it writes the per-token approval and emits
   `Approval` at the facade. `setApprovalForAll(operator, approved)`
   writes the operator map for `msg.sender` and emits
   `ApprovalForAll` at the facade. `Approval` and `ApprovalForAll`
   are emitted by the facade only; no other contract emits approval
   events for the collection.
3. `getApproved(tokenId)` reverts for an unmapped token and otherwise
   returns the facade-stored approval; `isApprovedForAll` is a pure
   map read. Marketplaces therefore read and write the complete
   approval surface at the one address they already index.
4. Approval scope is facade-routed mutations only. Facade approvals
   are invisible to Core — Core never reads them, and no Core-side
   authority (manager mint execution, governance, satellite writes)
   resolves through them. What the facade's approval store grants is
   exactly the ability to route [FCP-ROUTING] transfers and, where
   the collection is burnable, [FCP-MINT] rule 4 burns through the
   facade's own entries.
5. Per-token approvals reset on every ownership change through the
   callback ([FCP-ROUTING] rule 4); operator approvals persist per
   ERC-721 semantics until revoked by their granter.

## Mint Delivery And Burn

Requirements [FCP-MINT]:

1. Mint delivery. Minting is manager-only in both identity modes —
   the facade cannot mint, and a controlled-path call with
   `from == address(0)` reverts at Core
   ([PV1-TRANSFER-CONTROLLER] requirement 7; mint ABI home
   [`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md)
   [MPA-CORE-ABI]). When ERC-721 ownership materializes for a token of
   the facade's collection — single-step mint and prepared-mint
   completion alike — Core routes the same terminal callback with
   `from = address(0)` and `to` the delivery identity settled by the
   mint path ([PV1-TRANSFER-CONTROLLER] requirement 12; ADR 0015
   decision W4).
2. Mint bookkeeping. The callback must revert if the local serial is
   already mapped, then write the `collectionSerial ->
   catalogTokenId` entry exactly once ([FCP-IDENTITY] rule 5),
   increment `balanceOf(to)`, and emit
   `Transfer(address(0), to, collectionSerial)`.
3. No receiver check on mint. The mint callback performs no
   `onERC721Received` call, and Core performs none on facade-mode
   delivery ([PV1-TRANSFER-CONTROLLER] requirement 12). Mint receiver
   policy is owned by the mint
   and sale layers, whose delivery shapes are deliberately
   account-type-free and revert-isolated
   ([`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md)
   [SSA-AIRDROP] rule 2, [SSA-ENGLISH] rule 7); a facade-layer
   receiver veto inside the terminal callback would reintroduce
   exactly the delivery-griefing those shapes remove, and is
   nonconformant.
4. Burn symmetry. Core's native burn entry is closed for the
   collection ([PV1-TRANSFER-CONTROLLER] requirement 8), so where the
   collection's burn posture permits burning ([LTA-IDENTITY] rule 8;
   [`docs/collection-metadata-contract.md`](collection-metadata-contract.md)
   [CMC-BURN]) the facade must expose exactly one `burn(tokenId)`
   entry, validated like a transfer — mapped token, `msg.sender`
   owner, approved, or operator per [FCP-ROUTING] rule 1 — and routed
   as `controlledOwnershipChange(streamCollectionId(),
   streamCatalogTokenId(tokenId), owner, address(0), "")`. Core
   enforces the identical preconditions as the native burn path,
   including the one-way collection burn block
   ([PV1-TRANSFER-CONTROLLER] requirement 7). In the resulting
   callback (`to == address(0)`) the facade must decrement
   `balanceOf(from)`, clear the per-token approval, emit
   `Transfer(from, address(0), collectionSerial)`, and retain the
   identity mapping ([FCP-IDENTITY] rule 2). For a collection whose
   posture forbids burning, the facade must omit the `burn` entry —
   no callable dead path — and no burn origin exists for the
   collection in either layer.
5. Post-burn reads. After BURN, `ownerOf`, `getApproved`, and
   `tokenURI` for the serial behave as for any ERC-721 burned token
   (reverting per the delegated Core behavior), while
   `streamCatalogTokenId` and `royaltyInfo` continue to answer through
   the retained mapping, mirroring Core's burned-token posture
   ([LTA-IDENTITY] rule 5).

## Delegated Reads And Metadata Refresh

Requirements [FCP-READS]:

1. `ownerOf(tokenId)` returns Core
   `ownerOf(streamCatalogTokenId(tokenId))` read live; the facade
   stores no owner. `balanceOf(owner)` returns the facade-maintained
   per-owner count ([FCP-ROUTING] rule 4), reverts for
   `address(0)`, and must satisfy the conservation invariant of
   [FCP-THREATS] item (e). Facade-local serial enumeration needs no
   enumerable index and adds no Core surface ([LTA-ENUMERATION]
   rule 4): local IDs are dense in `[1, mintedEver]` in mint order
   ([FCP-IDENTITY] rule 1), so a state walk over `ownerOf` and
   `streamCatalogTokenId` enumerates the collection from the facade
   exactly as dense global IDs do at Core.
2. `tokenURI(tokenId)` returns Core
   `tokenURI(streamCatalogTokenId(tokenId))` byte-for-byte. The facade
   adds no rendering, no rewriting, and no gas bound of its own: Core's
   `tokenURI` already applies the bounded fail-safe router posture
   ([`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md)
   [MRR-CORE-TOKENURI]), and the facade's call into its own bound Core
   is a trusted-infrastructure call. Router and renderer resolution is
   keyed by the global token ID and never branches on identity mode
   ([MRR-FACADE-SERVING]). Token JSON served for the token carries the
   collection member set including the catalog number
   ([CMC-COLLECTION-IDENTITY-JSON]), so both identities of the
   two-layer split are readable from the metadata itself.
3. `royaltyInfo(tokenId, salePrice)` returns Core
   `royaltyInfo(streamCatalogTokenId(tokenId), salePrice)` unchanged —
   receiver and amount exactly as Core-native ERC-2981 resolves them
   ([`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
   Royalty Resolver Contract). Royalty economics, freezes, and artist
   rights are unaffected by identity mode.
4. `contractURI()` serves the collection-scoped ERC-7572 metadata:
   the facade resolves the current metadata router through Core's
   pinned satellite pointer read at call time and calls the router's
   collection read (`contractURIForCollection`,
   [MRR-COLLECTION-DISCOVERY]) for `(streamCore(),
   streamCollectionId())`. The facade holds no satellite pointer of
   its own, so router rotation under the Core Satellite Pointer Policy
   ([LTA-POINTERS]) is tracked automatically.
5. Fail-safe posture. The rule 4 router read is a bounded staticcall
   with a returndata cap that returns the documented fallback payload
   instead of reverting when the read is unset, code-less, reverting,
   oversized, or malformed — the same posture as Core's own delegated
   `contractURI()` ([MRR-CORE-TOKENURI] family).
6. No new Governed Gas Parameter. The rule 5 bound consumes the
   Core-hosted `METADATA_ROUTER_GAS_LIMIT` current value read from its
   host at call time, with the EIP-150 63/64 parent-gas precheck and
   capped returndata copying ([LTA-GGP]; [MRR-ROUTER-GGP]). The facade
   defines no parameter, hosts no parameter, and therefore needs no
   governance.
7. Refresh relay. Facades relay ERC-4906 refresh for their local id
   space: `relayMetadataUpdate` emits `MetadataUpdate(localTokenId)`,
   `relayBatchMetadataUpdate` emits
   `BatchMetadataUpdate(fromLocalTokenId, toLocalTokenId)`, and
   `relayContractURIUpdated` emits `ContractURIUpdated()`. Relay
   entries validate that token IDs or ranges are mapped and ordered
   and that a batch range spans at most `MAX_REFRESH_RANGE` local IDs
   (constant home
   [`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md);
   ADR 0009 decision 15); oversized refreshes arrive as chunked relay
   calls exactly as at Core.
8. Authorized-relay rule. Only Core-originated refresh authority may
   trigger facade refresh events, verified per caller against Core
   state at call time — never a facade-local allowlist, which an
   ownerless contract could not maintain — and every other caller
   reverts with `FacadeUnauthorizedRelay`. The per-caller derivations
   are exact:
   - `relayMetadataUpdate` and `relayBatchMetadataUpdate` accept
     `msg.sender` when it equals the current metadata router or the
     current artwork finality registry, each resolved from Core's
     pinned satellite pointer reads at call time (Core-side caller-set
     precedent: the restricted ERC-4906 helper set owned by the Core
     Hook Budget table,
     [`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md)
     [PV1-HOOKS]; [MRR-REFRESH-EMITTERS]);
   - the same entries accept the entropy coordinator per token,
     exactly as Core's helpers do ([MRR-REFRESH-EMITTERS] rule 2):
     `msg.sender == coordinatorAtMint(streamCatalogTokenId(id))` must
     hold for every `id` in the relayed token or range, so the
     coordinator that owes a token's reveal keeps relay authority for
     it across pointer rotation, and a successor coordinator is
     rejected for tokens minted under a predecessor;
   - `relayContractURIUpdated` accepts only the current
     collection-metadata satellite — the producer of the
     collection-scoped contract-metadata facts the facade's
     `contractURI()` serves
     ([`docs/collection-metadata-contract.md`](collection-metadata-contract.md);
     [MRR-COLLECTION-DISCOVERY]) — resolved from Core's pinned
     `COLLECTION_METADATA` satellite pointer read at call time
     ([LTA-POINTERS]); the facade-aware satellite version carrying
     the relay duty is named at facade deployment ([FCP-DEPLOYMENT]
     rule 4).
   Callers are responsible for translating affected global IDs to
   local IDs; within one collection both sequences are monotonic in
   mint order, so a global range intersected with the collection maps
   to one local range.
9. Emission discipline and producers. The relay entries are the only
   paths that emit `MetadataUpdate`, `BatchMetadataUpdate`, or
   `ContractURIUpdated` at the facade; the facade never
   self-originates a refresh, so a facade refresh event always
   corresponds to a Core-authorized refresh fact in the same
   transaction. The genesis satellite implementations carry no facade
   relay duty and contain no relay call site — nothing exists at
   genesis to relay to (ADR 0015 decision W5):
   facade-local refresh events exist only through the facade-aware
   satellite versions whose accepted module specs add the duty to
   call the matching relay entry — in the same transaction as their
   Core-side refresh emission, for affected tokens of an
   `EXTERNAL_FACADE` collection — and whose acceptance is a
   precondition of the deployment sequence ([FCP-DEPLOYMENT] rule 4),
   so no facade ever serves marketplaces against relay-silent
   satellites.

## Permanence And Deployment Discipline

Requirements [FCP-PERMANENCE]:

1. Permanent class. Every deployed facade is Permanent-class exactly
   as the matrix's permanence checks define it (ADR 0012 decision T1;
   [`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md)
   [LCM-STATIC] rule 10, [LCM-FORBIDDEN] item 14): immutable bytecode,
   no owner, no admin role, no upgrade path, no proxy or beacon, no
   `SELFDESTRUCT`, no pause surface, and no governed parameter. The
   missing pause surface removes nothing: ownership transfer is
   ungated in either identity mode — locks, finality components, and
   pause never condition transfers on this Core line ([LTA-STANDARDS];
   ADR 0015 decision W4.3) — and the Core-side preconditions that do
   bind, the native burn-precondition suite on routed burns
   ([FCP-MINT] rule 4) and mint-layer pause and policy on the manager
   path, bind identically in both modes at Core, with no facade
   authority existing.
2. Deterministic deployment. Facades deploy through the deterministic
   deployment factory with a pinned salt, recorded init-code hash, and
   manifest entry per [LTA-DEPLOY]; the facade address is reproducible
   from the deployment manifest alone before the ceremony runs.
3. Inventory membership. At deployment each facade joins the module
   registry ([LTA-REGISTRY]) — registered `ACTIVE` with module type
   `STREAM_COLLECTION_FACADE` ([FCP-DOMAINS]), its interface ID, a
   pinned `runtimeCodeHash`, and a `moduleVersion` — and joins the
   release-manifest inventory, so the museum-mode address-set
   derivation and event-history snapshot rules pick the facade up from
   state alone ([LTA-EVENT-HISTORY] rule 1). Registration and the
   Core-side controller binding are governed actions (ADR 0015
   decision W4.7; ADR 0004 action classes), ordered by construction:
   module-registry membership is a Core-checked eligibility condition
   of the binding itself — `registerCollectionTransferController`
   reverts for a controller not yet registered
   ([PV1-TRANSFER-CONTROLLER] requirement 2; ADR 0015 decision
   W4.2) — so a facade is registry-visible from state before its
   first possible emission and the [LTA-EVENT-HISTORY] rule 6
   from-genesis address-set coverage holds for every facade log
   stream.
4. Module identity. The facade exposes the canonical module identity
   surface ([LTA-MODULE-ID]) with
   `streamModuleType() = keccak256("STREAM_COLLECTION_FACADE")`.
5. Golden coverage. Every deployed facade is covered by the golden
   interface tests and static permanence checks named in [FCP-GATES]
   before its collection's first mint; a facade whose gates have not
   passed must not receive the controller binding.
6. Zero-governance inertness. A facade needs no governance after
   deployment — every read resolves through immutable bindings or
   Core state, and every authority check derives from Core state. With
   governance lost before any deployment, no facade can ever deploy
   (mode declaration and controller registration are governed), and
   the dormant Core surfaces stay inert: the zero-signer museum-mode
   drill proves a `CORE_NATIVE`-only deployment is identical on every
   pre-ADR-0015 surface, with the facade-readiness reads answering
   their dormant defaults (`CORE_NATIVE`, zero controller) and the
   governed entries reverting for every caller — scoped by
   [PV1-FACADE-READINESS] requirement 1, the single scoping home for
   the claim (ADR 0015 decision W4.7).

## Event Exclusivity

Requirements [FCP-EXCLUSIVITY]:

1. The facade is the only ERC-721 `Transfer` emitter for its tokens.
   Core emits the controlled-ownership-change event family —
   `ControlledOwnershipChanged` — for the collection in place of
   ERC-721 `Transfer` (ADR 0015 decision W4.4); the family's schema
   and emission points are owned by [PV1-TRANSFER-CONTROLLER]
   requirement 11 in
   [`docs/launch-v1-target-architecture.md`](launch-v1-target-architecture.md).
2. Exactly-one correspondence. Every ownership mutation of the
   collection produces, in one transaction, exactly one Core
   `ControlledOwnershipChanged` event and exactly one facade `Transfer`
   emitted from the terminal callback. In the machine-readable event
   catalog the facade `Transfer` is tagged as the required
   same-execution mirror of the Core `ControlledOwnershipChanged` fact
   family for its collection — the [MRR-ROUTER-EVENTS] rule 2 mirror
   precedent — so the pair registers as one declared event set per
   mutation under the one-fact-one-owner discipline ([LCM-EVENTS]).
   Any state in which both Core
   ERC-721 `Transfer` and facade `Transfer` emit for one mutation, or
   neither emits, is nonconformant. The neither case is structurally
   excluded by the terminal callback's atomicity ([FCP-ROUTING]
   rule 3); the both case is structurally excluded by the Core event
   doctrine carve-out (Core-side gate).
3. The facade must not emit `Transfer` outside a callback frame: no
   constructor emission, no administrative emission, no emission from
   the transfer entries themselves. `CORE_NATIVE` collections are
   untouched — Core remains their only ERC-721 `Transfer` emitter —
   and a facade cannot emit for tokens outside its collection because
   its event vocabulary is its local id space.
4. Indexer truth rule. Events are notification, state is authority:
   ownership truth for facade collections is Core `ownerOf` (equally
   readable as facade `ownerOf`), and the reconstruction lanes —
   state exports, dense-ID state walks, and event replay
   ([LTA-ENUMERATION]; [LTA-EVENT-HISTORY]) — remain mode-independent.
   Event-history reconstruction for a facade collection combines the
   Core controlled-ownership-change stream and the facade `Transfer`
   stream, both address-derivable from state ([FCP-PERMANENCE]
   rule 3).

## Threat Model

Requirements [FCP-THREATS]:

Numbered adversarial analysis. Each mitigation names its enforcement
locus; the matrix carries the corresponding gates ([FCP-GATES]).

1. Controller-authority abuse (a). The registered controller is the
   approval authority for its collection, so a malicious or defective
   facade can, for its own collection only: route transfers with
   fabricated authorization (it defines the approval checks), refuse
   to route (revert callbacks, freezing mints, transfers, and burns),
   serve corrupted reads, and emit misleading events. Per-collection
   containment caps the blast radius structurally, not procedurally:
   - the controller binding is per-collection and one-way, and Core's
     controlled path accepts a mutation only from the collection's own
     registered controller for tokens of that collection
     ([PV1-TRANSFER-CONTROLLER] requirements 6-7), so a facade can
     never mutate another
     collection, any `CORE_NATIVE` token, or any Core global
     invariant — supply facts, token identity, record chains, exports,
     locks, and finality enforcement all settle Core-side, beyond
     controller reach, with the controlled path enforcing exactly the
     open native invariant set ([FCP-ROUTING] rule 2; ADR 0015
     decision W4.3);
   - the facade holds no funds ([FCP-INTERFACE] rule 5) and no
     ownership state ([FCP-READS] rule 1), so theft through the facade
     is bounded at unauthorized transfers within the one collection,
     and a bricked facade is bounded at one collection's transferable
     liquidity — the works, their identity, their finality, and their
     export/provenance record survive intact at Core;
   - the deployment procedure makes a malicious facade a
     governance-level event rather than a drive-by: facades deploy
     from reviewed, hash-pinned init code and bind through governed
     actions ([FCP-PERMANENCE] rules 2-3, [FCP-DEPLOYMENT]).
2. Reentrancy through the routed mutation (b). The composed attack
   surface is a malicious `onERC721Received` receiver (or any contract
   reached during it) reentering the facade or Core mid-transfer. The
   ordering discipline closes it: Core settles all state and
   record-chain writes before the terminal callback (ADR 0015 decision
   W4.3), the facade writes only inside the callback, and untrusted
   code runs only after both are complete ([FCP-ROUTING] rules 5-7).
   Native Core entries revert for the collection, the controlled path
   rejects non-controller callers, and the callback rejects non-Core
   callers, so no reentrant path observes or creates a half-settled
   mutation. The residual risk — a conformant-looking implementation
   that writes facade state after the receiver call — is a profile
   violation caught by the reentrancy gate, which must include a
   receiver that recursively transfers, approves, burns-via-Core, and
   re-calls the callback and relay entries.
3. Event-exclusivity violations as indexer corruption (c). A facade
   that emits `Transfer` events uncorrelated with mutations — or
   suppresses them — corrupts marketplace and indexer views of its
   collection: phantom ownership, hidden sales, wash-trade cover. It
   cannot corrupt Core state, exports, or the controlled-ownership-
   change stream, so the truth remains state-derivable and
   cross-checkable ([FCP-EXCLUSIVITY] rule 4), and the emission gates
   pin the correspondence per mutation kind before any binding. The
   symmetric Core-side violation (Core emitting ERC-721 `Transfer` for
   an `EXTERNAL_FACADE` collection) double-counts every mutation at
   two addresses and is excluded by the Core-side mode gates.
4. Approval-gate compromise (d). If the facade's approval logic is
   defective — anyone can approve, operator map confusion, missing
   reset — the exposure is unauthorized transfer of that collection's
   tokens, the same class as an ERC-721 approval bug on any standalone
   collection contract. Core's controlled-path invariant set still
   binds: current-owner match and a nonzero recipient for transfers,
   and the full native burn-precondition suite — including the
   one-way collection burn block — for burns ([FCP-ROUTING] rule 2;
   [FCP-MINT] rule 4), so forged facade approvals can never mint,
   burn past Core-side burn preconditions ([FCP-APPROVALS] rule 4),
   or reach another collection. Owners' approvals on
   other Stream collections live in Core or in other facades and are
   untouched.
5. Facade-Core desync claims (e). The design leaves nothing to drift:
   ownership is never copied (live Core reads, [FCP-READS] rule 1),
   the identity mapping is written once from Core-supplied callback
   data and Core serials are dense and immutable ([FCP-IDENTITY]),
   and the reverse read is stateless over Core ([FCP-IDENTITY]
   rule 3). The only facade-derived facts are per-owner balances and
   the local-id event stream, both driven by the exclusive terminal
   callback, and both machine-checkable against Core state: for every
   owner, facade `balanceOf(owner)` must equal the count of live
   collection tokens Core attributes to that owner, and facade
   `totalSupply()` must equal Core's live collection count — a
   state-walk conservation gate, re-runnable forever by anyone.
6. Marketplace edge cases (f). Address-keyed venue primitives are the
   facade's purpose and its residual risk surface:
   - address-keyed collection bids: solved by construction — the
     facade address is the collection, so collection offers,
     collection stats, and collection verification key exactly one
     artist series;
   - operator-filter registries and royalty-enforcement lists: the
     facade has no transfer hook and never consults a filter registry,
     the same Permanent openness posture as Core ([PV1-EXCL] item 1);
     venues that condition features on filter integration will treat
     facade collections exactly as they treat Core — the W3 review
     round evaluates that reality at decision time rather than
     assuming it away;
   - `owner()`-style collection administration: the facade is
     ownerless, so venues that resolve collection management rights
     from an `owner()` read fall back to their platform verification
     flows; the W3 review must confirm per-venue that ownerless
     collections can be claimed and administered through those flows;
   - royalty plumbing: ERC-2981 answers at the facade address
     ([FCP-READS] rule 3), and the per-venue royalty-resolution
     evidence discipline of [LCM-MARKETPLACE] extends to facade
     addresses at deployment ([FCP-DEPLOYMENT] rule 5).

## Deployment Decision Procedure

Requirements [FCP-DEPLOYMENT]:

1. Tripwire. The facade line advances to a deployment decision
   automatically if and only if the ADR 0015 decision W2
   marketplace-commitment gate cannot be satisfied before the
   public-sale boundary; the tripwire therefore fires before any
   public sale by construction (ADR 0015 decision W3). Nothing else
   arms it: with W2 satisfied, this profile retires to a permanent
   dormant option and no facade deploys.
2. Adversarial review round. A go/no-go decision requires a dedicated
   adversarial review of this profile against then-current marketplace
   reality — re-validating every [FCP-THREATS] item, the
   [FCP-THREATS] item (f) venue behaviors by named venue, and the
   Core-side dormant surfaces — recorded as release evidence. The
   review's mandatory scope additionally includes the sales/custody
   seam ([FCP-SCOPE] rule 6): facade-aware sale-adapter profiles that
   lift the [SSA-IDENTITY] rule 9 configuration exclusion by routing
   custody mutation through the facade's ERC-721 entries are accepted
   in this review, or the exclusion stands for the deployment's
   collections (ADR 0015 decision W3). The
   review is not a formality gate: it exists because the facade is a
   first-of-kind composite ([FCP-SCOPE] rule 4).
3. Owner decision. After the review, deployment is a protocol-owner
   go/no-go. A go decision names the collections it covers; it applies
   only to collections created after the decision, and no retrofit
   path exists for any collection that has minted under `CORE_NATIVE`
   identity (ADR 0015 decision W3).
4. Deployment sequence per collection. Precondition: the facade-aware
   satellite versions that carry the [FCP-READS] rules 8-9 relay
   duties — the metadata router, the artwork finality registry, the
   entropy coordinator, and the collection-metadata satellite — must have
   accepted module specs and must be named in the go decision's
   release evidence as the versions serving the collection, because
   genesis satellites carry no relay duty ([FCP-READS] rule 9) and a
   facade bound without them would emit no facade-address refresh
   events. Then, per collection: (a) deploy the facade
   deterministically ([FCP-PERMANENCE] rule 2) with its immutable
   `(core, collectionId, name, symbol)` bindings; (b) pass the
   [FCP-GATES] pre-binding suites; (c) register the facade in the
   module registry ([FCP-PERMANENCE] rule 3); (d) declare the
   collection `EXTERNAL_FACADE` and bind the controller pre-first-mint
   — with the artist consent surface satisfied for artist-bound
   collections ([AA-CONTENT]; ADR 0015 decision W4.1); (e) verify the
   facade's binding reads equal the Core-side registration
   ([FCP-IDENTITY] rule 4); (f) record the facade in the release
   manifest and the facade identity binding record family
   ([CMC-FACADE-BINDING]). Steps (c) and (d) are governed actions,
   and their order is Core-enforced, not ceremony discipline: the
   step (d) binding reverts for a controller not yet registered in
   the module registry ([FCP-PERMANENCE] rule 3;
   [PV1-TRANSFER-CONTROLLER] requirement 2; ADR 0015 decision W4.2).
   Step (d) is impossible after the collection's first mint, so a
   half-configured collection cannot mint into an ambiguous mode.
5. Marketplace evidence. Before the first sale of a facade-fronted
   collection, the [LCM-MARKETPLACE]-class display and
   royalty-resolution evidence must exist for the facade address
   itself; evidence captured for Core does not transfer, because the
   facade is a different ERC-721 address with its own venue state.

## Domain Constants [FCP-DOMAINS]

This table is the normative home for the facade-profile domain
constants. The protocol v1 domain-constants mirror carries these rows
for the CI recomputation test ([PV1-MIRROR]); the hash value below is
computed from the adjacent string preimage, and the CI recomputation
checker re-derives it from that preimage ([PV1-MIRROR] rule 2).

| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |
| --- | --- | --- | --- | --- | --- |
| `STREAM_COLLECTION_FACADE` module type | `STREAM_COLLECTION_FACADE` | 0x10f31f822ddc93e9cc5b5b8696166e94f953b83c514ca790ae0bbc83acf8ded8 | collection facades | `1` | module type constant per [LTA-MODULE-ID]; [FCP-PERMANENCE] rule 4 |

The profile defines no EIP-712 domain, no hash-derived identifier
beyond the module type, and no Stream-native event schema. The
identity-mode vocabulary, the `CollectionTransferControllerRegistered`
and `ControlledOwnershipChanged` event families, and the
`ON_STREAM_OWNERSHIP_CHANGE_SELECTOR` constant are Core genesis
constants owned by [PV1-IDENTITY-MODE] and [PV1-TRANSFER-CONTROLLER]
(ADR 0015, Release Impact); the facade identity binding record family
is owned by [CMC-FACADE-BINDING]; the facade interface ID is pinned
under the [PV1-DOMAINS] selector discipline at implementation time
([FCP-INTERFACE] rule 3).

## Errors

Facade-specific custom errors named by this profile. ERC-721
authorization and existence failures use the implementation's declared
custom errors, covered by the [FCP-GATES] golden interface suite:

```solidity
error FacadeUnknownLocalToken(uint256 localTokenId);
error FacadeUnknownCatalogToken(uint256 catalogTokenId);
error FacadeUnauthorizedCallback(address caller);
error FacadeUnauthorizedRelay(address caller);
error FacadeCollectionMismatch(uint256 collectionId);
error FacadeInvalidOwnershipChange();
```

## Conformance Hooks

Requirements [FCP-GATES]:

The conformance matrix
([`docs/launch-conformance-matrix.md`](launch-conformance-matrix.md))
owns the gate rows; this section names the required coverage and adds
no gate mechanics of its own. Gates 1-7 are pre-binding gates: every
one must pass for a facade before the controller binding of
[FCP-DEPLOYMENT] rule 4(d). The Core-side dormant-surface gates —
mode-declaration and registration negatives, controlled-path CEI
ordering, per-mode event assertions, museum-mode inertness — are
Core-side rows owned by the matrix against [PV1-IDENTITY-MODE] and
[PV1-TRANSFER-CONTROLLER] and are not restated here.

1. Facade golden interface suite: every [FCP-INTERFACE] member by
   selector, the exact `supportsInterface` truth table including the
   ERC-721 Enumerable false case, and standard-signature event
   catalog registration.
2. Routed-mutation suite: [FCP-ROUTING] validation set, CEI ordering,
   single terminal callback per mutation, approval reset without a
   mirror `Approval` emission, receiver-check ordering and magic-value
   enforcement, and the rule 7 reentrancy matrix including nested
   receiver-initiated transfers succeeding.
3. Event-exclusivity suite: exactly-one `Transfer` per mutation kind,
   no emission outside a callback frame, and cross-address
   correspondence with the Core controlled-ownership-change stream in
   the same transaction.
4. Identity suite: local-serial equality with Core serials over mint
   order, catalog-read totality over `[1, mintedEver]`, burned-serial
   retention, stateless reverse-read agreement, and mapping
   immutability.
5. Delegated-read equivalence suite: `tokenURI` and `royaltyInfo`
   byte-equality with Core for live and burned tokens, `contractURI`
   equality with the router collection read, fail-safe fallback
   behavior at the [FCP-READS] rule 5 boundary, and GGP threshold
   tests just below, at, and above the EIP-150 precheck.
6. Refresh-relay suite: acceptance for each producer under the
   [FCP-READS] rule 8 per-caller derivations — the pointer-resolved
   router and finality registry, per-token `coordinatorAtMint`
   acceptance including a rotated-out coordinator relaying for tokens
   minted under it, and the pointer-resolved collection-metadata
   satellite for `relayContractURIUpdated` — rejection for every
   other caller class including a successor coordinator over a
   predecessor's tokens, range validation, and the
   `MAX_REFRESH_RANGE` cap.
7. Permanence and conservation suite: [LCM-STATIC] rule 10 static
   permanence checks over facade bytecode (no owner, upgrade path,
   selfdestruct, payable surface), and the [FCP-THREATS] item (e)
   balance/supply state-walk conservation check.
8. Deployment-ceremony gates: deterministic-deployment manifest
   verification, registry and release-manifest inventory membership,
   binding-equality verification, finality-binding record presence,
   and the [FCP-DEPLOYMENT] rule 5 facade-address marketplace
   evidence. This gate confirms end state only; the
   registration-before-binding order is enforced by Core at the
   binding itself ([FCP-PERMANENCE] rule 3), so this gate's position
   after the ceremony is not load-bearing for the
   [LTA-EVENT-HISTORY] rule 6 coverage claim.
