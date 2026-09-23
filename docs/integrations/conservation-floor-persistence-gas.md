# Conservation-floor persistence and collector gas

Fresh conservation preparation rows preserve the original storage layout, keys,
receipt words and event bytes. The implementation now writes only fields that
the sole private seed producer populates. Computed receipt hashes, first/release
receipt links and recorded time remain zero in that seed; historical getters
continue to reconstruct them. Optional token and release fields are written when
nonzero. A fresh, genuinely `CONSERVATION_WAIVED` collection keeps the original
empty source/facts words without issuing zero-to-zero storage writes.

This relies on the existing append-only invariant: both preparation mappings
have one private writer, the writer first checks `exists`, and neither mapping
has a reset or delete path. Non-WAIVED source and documentary facts are retained
in full. Authority, source authentication, payment checks, preparation hashes,
event order, replay and rollback behavior are unchanged.

The focused tests execute the actual Floor with the original explicitly typed
Core, Registry, recorder and source-provider boundaries. They independently
construct complete preparation, first-sale, release and settlement preimages;
check event bytes, optional fields, idempotence and prepayment absence; and
exercise late failure followed by an identical retry and retained history after
a source change. These fixtures do not establish native documentary evidence
or a complete current commerce transaction.

## Recorded source evidence

At base `b752f5bd7fb6db456ebc89d5e7230041b63296af`, the original Floor is byte-identical
to the frozen `9bdabdf2` product. Paired Solidity 0.8.19, viaIR, optimizer 200,
Paris, no-CBOR codegen over 55 sources measures runtime **24,535 to 24,498 bytes**
and bare creation **26,707 to 26,670 bytes**. Its 736 constructor argument bytes
remain unchanged. Original ABI, selectors and recursive storage layouts match.
The same six tests pass against both the original and changed Floor, including
256 fuzz runs per version. Each capture has 164 exact Git-matched sources, seven
genuine native artifacts and 329 verified metadata source Keccaks; all six
reached production products meet the original runtime and complete init-code
limits. The cached EVM runs preserved every source, setting and artifact byte.

The test-local preparation measurement falls from 456,416 to 422,887 gas
(a 33,529 saving). The complete inline persistence/settlement measurement falls
from 805,208 to 801,679 (3,529 saved). These are calls within test transactions,
not all-cold external collector transactions; setup, commerce and intrinsic
costs are outside these measured intervals. The smaller inline saving is
consistent with subsequent reads paying cold-access costs for skipped slots;
that explanation has not been separately established by an opcode trace.

## Collector transaction boundary

The existing paid public Dutch test at exact `9bdabdf2` was rerun from genuine,
unchanged cached artifacts. All 502 source files matched raw Git blobs, and all
1,088 copied project files and the original frozen project remained unchanged.
The one selected case passed without compilation.

It registers and previews before purchasing, so this is a **warmed diagnostic**.
The actual purchase frame used 2,904,763 gross gas. Its 516-byte calldata contains
371 zero and 145 nonzero bytes, giving 24,804 ordinary intrinsic gas. Their sum,
2,929,567, is arithmetic over that warmed frame, not a separately submitted cold
transaction receipt. The test's 3,959,147 reported net gas also includes
registration, preview, assertions and a later refund claim. Setup separately
used 74,931,449 gas.

Three nonoverlapping portions dominate that purchase:

| Portion | Gross frame gas | Detail |
| --- | ---: | --- |
| Official settlement | 1,139,605 | Includes the genuine Floor call at 560,342 |
| Manager/Ledger/Core mint | 669,328 | Includes Core 388,679 and Ledger 100,773 |
| Carrier frame remainder and first refund credit | 532,787 | 374,261 plus 158,526 |

The example is the first paid sale of an explicitly WAIVED collection, with
500 wei excess creating the payer's first refund-index entry. Artist, entropy
and target governance remain typed fixture boundaries; Core, Manager, Ledger,
Recorder, Resolver, Registry, Metadata and Floor are actual products.

[MPA-GAS-BUDGET](../mint-policy-and-accounting.md) requires the complete all-cold
single-step collector transaction to fit **500,000 gas**. It provides no
first-sale or inline-floor exception. The existing permissionless
`preparePrimarySale` can move genuine immutable preparation work to an earlier
operator transaction, but [the Floor contract](../conservation-sale-floor.md)
keeps one-transaction purchase valid and still authenticates current paid facts.
The separate 700,000 `PREPARED_MINT` ceiling describes atomic mint orchestration;
it is not an exemption for offloading conservation preparation.

This bounded storage change saves gas in the measured intervals and leaves
the remaining roughly 2.4 million in the purchase diagnostic unresolved. [ADR 0033](../adr/0033-engineering-rehearsals-and-collector-gas.md)
already requires an integrated storage/execution design for consumer, recorder,
Manager and Core. Durable keyed reads, exact receipts and credit accounting,
independent replay, and atomic rollback must survive that design. Replacing
them with event-only or caller-supplied witnesses would be a semantic change.
The numerical ceilings remain unchanged; local engineering evidence is not a
conforming release or production-gas acceptance.
