# Frozen royalty phase succession acceptance

## Scope

[StreamCurrentFrozenRoyaltyMintContinuity](../test/current/StreamCurrentFrozenRoyaltyMintContinuity.t.sol)
adds four actual-current regression recipes for a snapshot royalty phase across
MintManager succession. Existing frozen continuity cases use an unconfigured
royalty policy; the royalty economic-continuity suite changes RoyaltyResolver
while retaining its Manager. Neither previously supplied this composition.

The new host uses the actual Core, Artist graph, RoyaltyResolver, predecessor
and successor Managers, Ledger, module registry, manifest and delayed governance.
The Artist principal is an EOA signing original protocol consent. One official
threshold-two Safe serves as Governor and admitted mint executor before and
after succession. The external entropy service and a rejecting NFT recipient
remain explicit test boundaries. Existing fixtures and production sources are
unchanged.

Snapshot mode is elected before any mint. Actual Artist economics consent
authorizes the original 600-basis-point royalty source; the predecessor records
its seven-field phase policy and produces a real prepared token snapshot.
Class-2 governance freezes that consumed phase with the original 72-hour floor.
A same-Ledger import carries its supply counter and canonical freeze, and a
saved Safe cutover transaction fails before the import seal and succeeds after
completion. The original executor Safe remains within the frozen ceiling.

An existing commerce house binds its original Manager immutably; a newly
deployed house would add a forbidden executor. These recipes therefore use the
original generic `executePreparedMint` entrypoint. They establish no paid-sale,
reveal-fee, auction, custody resale or revenue withdrawal acceptance.

## Four cases

| Case | Assertions |
| --- | --- |
| Fresh successor consent | All seven royalty fields remain exact while the Manager-domain wrapper changes. Missing fresh Artist consent rolls back the saved Governor transaction; the same transaction succeeds after the exact record is supplied. A new prepared token has its own operation identity and canonical frozen royalty receipt. |
| Missing policy or stale wrapper | An unregistered royalty branch and the predecessor's wrapper both fail phase configuration despite actual consent for the attempted policy. Imported counter, freeze, original token and Safe/governance state remain intact. |
| Changed economics | Actual Artist consent and governance install a new 700-basis-point current source. Its valid new wrapper cannot replace inherited frozen phase terms; the original token retains 600 basis points and its exact receipt/configuration. |
| Late delivery rollback | The receiver observes a real successor snapshot before rejecting. Snapshot, token, preparation, counter, authorization, operation root and Safe nonce all roll back. Repairing only the recipient permits the byte-identical Safe transaction; replay then fails. |

The successor uses the existing continuity recipe's governed Artist read-budget
raises to 300,000 and 600,000. These are explicit fixture operations, not changed
production defaults, relaxed native limits or measured minimum gas claims.

## Evidence and remaining work

The final ABI-only capture is
`artifacts/native-assembly/counter-scopes/mint-frozen-royalty-continuity-abi-final-1`:
1,005 exact authored sources, four named test functions and zero compiler errors.
Input SHA-256 is
`b7c201ad6260517422cbbbca2c8431aabd793cd9176c04495fe87ac71a72e996`;
output SHA-256 is
`cec04e556d22bffdb2fe18048db69cbc8fff2ad95d4add2c344d48f8ef887c45`.
Formatting and Windows-aware whitespace checks pass.

Native execution is pending. The coordinator selects the joined source and
authenticates the complete host, native creation library, all 55 graph products
and original Safe fixture data before execution. Run all four cases together;
the focused Manager/Ledger captures cannot supply this graph acceptance.
Adding this complete host to the separately inventoried 13-host, 81-case mint
cohort yields 14 hosts and 85 authored cases before any other domain additions.
These counts describe source coverage, not runtime passes or release readiness.
