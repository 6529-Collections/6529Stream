# Collection-artist template materialization

The primary resolver can turn a collection-aware template into an immutable split
profile using the accepted artist's current explicit payout designation. This is
a public deterministic cache operation. It does not authorize a sale, consent to
an assignment, or record official revenue.

Register a template through the resolver's owner. A dynamic entry using
`keccak256("COLLECTION_ARTIST")` must carry `keccak256("artist")` as its label.
Static recipients and `SALE_POSTER` remain supported; other dynamic sources,
including collaborators, currently reject. The factory's existing 64-entry and
canonical profile rules still apply.

```solidity
(bytes32 profileId, address wallet, bytes32 entriesHash) =
    resolver.materializeCollectionPrimaryProfile(templateId, collectionId, salePoster, false);
```

The final boolean selects wallet deployment. `false` registers the exact profile
and returns its deterministic address without deploying it. `true` registers and
deploys or discovers that same wallet. A predicted address containing unexpected
code rejects either path. `profileExists` proves registered immutable terms;
`splitWalletExists` proves the verified deployed wallet. They are different facts.

The original two-argument `materializePrimaryProfile(templateId, salePoster)`
continues to deploy static/SALE_POSTER profiles. It rejects COLLECTION_ARTIST
because no collection identity was supplied. A poster value in a public cache
call is caller-supplied context, not authenticated sale authority. Sale integrations
must separately enforce the normative poster/artist distinction and consent.

## Payout identity and continuity

For collection-aware calls, the resolver first checks the real Core collection,
its constructor-pinned artist facade and the currently selected Core pointer.
It resolves COLLECTION_ARTIST once through the typed
`collectionArtistBeneficiary(collectionId)` read. The artist facade composes the
accepted current binding, operative identity and explicit payout designation
from its immutable semantic owners. The returned artist ID, payout address and
designation record must all be nonzero. The signing authority is never a fallback
recipient. Failed, malformed, stale or unaccepted beneficiary facts reject before
profile registration.

Concrete entries are aggregated by `(account, labelId)` and sorted using the
existing factory rules. The materialized metadata hash binds its domain, chain,
resolver, template and canonical concrete entries. Neither collection ID, sale
ID, caller, poster field nor designation record adds a new identity component
beyond the concrete recipients selected by the template. Identical resulting
rights therefore reuse one profile and wallet.

An artist's later designation may cause the next materialization to produce a
new immutable profile. Earlier profiles retain their original payees forever.
Changing a designation record while keeping the same recipient reuses the
profile but emits the new read witness. `CollectionTemplateMaterialized` includes
schema version 1, template/profile/collection IDs, artist ID, payout, designation
record, wallet, entries hash and actual deployment state. It supplements the
existing cache event; neither event is official settlement evidence. Donations
or prefunding to a predicted address likewise do not become official sales.

## Governed read budget

The primary resolver constructor is now:

```text
(Core, splitFactory, governanceExecutor, explicitArtistFacade, beneficiaryReadGas)
```

`beneficiaryReadGas` is the existing `GasParameterConfig` tuple. Its name must be
`ARTIST_BENEFICIARY_READ_GAS` and failure class must be 2
(`FAIL_CLOSED_PRECHECK`). A deployment supplies an explicit positive floor and
genesis value. The resolver exposes the normal gas-host reads and
`raiseGasParameter`; catalog integration must admit the latter only through the
canonical delayed Executor route. Ownership alone cannot raise the cap. The
original owner/templates/assignments storage roots remain at slots 0/1/2; gas
parameter state appends at 3/4.

The read uses the live cap, an EIP-150 admission check and at most 96 copied return
bytes. It requires exactly three canonical ABI words, including zero upper
address padding. Insufficient outer gas, exhausted callee gas, short/oversized
results, revert data and unset fields fail closed. There is no alternate provider,
unbounded retry or fixed fallback cap. Caps above uint64 cannot be used by this
read. The domain tests use 200,000 genesis gas and a 50,000 floor as planning
values; these are not final cold deployment measurements.

## Tested boundary and integration work

The focused tests use the actual resolver, factory, split wallet and token money
flows, plus official Safe 1.4.1 with 2-of-3 execution signatures. Safe calls cover
all 48 public selectors through public reads, owner operations, permissionless
cache operations, and the explicitly separate governance route. Native and ERC20
proceeds reach the Safe payout account. Malformed reads, exact event witnesses,
cache collisions, payout changes, inherited assignment restrictions, poisoned
predictions, gas raises and canonical-order fuzzing have negative coverage.

Core/artist and target-side governance context are boundary fixtures. The artist
suite separately tests its real composed beneficiary read; full current-stack
and actual timelock integration remain separate. Inline max-64 measurements
record complete resolver calls for registration, later deployment and reuse.
Fixture setup and repeated calls warm accounts and storage, so those values are
not all-cold transaction limits.

Artist-bound assignments still support explicit fixed collection PROFILE terms.
This increment does not open TEMPLATE assignment, change the artist economics
consent payload, migrate sale/auction adapters, add collaborator sources, or
configure the genesis ROLE_TREASURY template and its receiving evidence.
Those are subsequent coordinated integrations. A fixed profile created by this
cache is immutable; assigning it does not make future sales dynamically follow
later artist payout changes. Existing auctions keep their creation-time proceeds
rights under the [auction funding rules](auction-funding.md).
