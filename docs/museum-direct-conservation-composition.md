# Native DIRECT conservation composition

This additive workflow joins an unchanged native DIRECT acquisition assembly
to two separately verified captures: the collection conservation-selection
history and the collection conservation tier/default history. It preserves all
three inputs byte for byte and reconstructs their six underlying source
transcripts offline.

The workflow is prospective. Synthetic fixtures exercise the native ABI, hash,
receipt and replay rules, but are not deployed-chain evidence.

## Original provider dependency boundary

The original native floor provider stores ten ordered configuration targets:

| Index | Stored dependency |
| --- | --- |
| 0 | Core |
| 1 | collection Metadata host |
| 2 | schema registry |
| 3 | chunk store |
| 4 | RIGHTS selector |
| 5 | conservation selector |
| 6 | master-media source |
| 7 | collection router |
| 8 | Artist facade |
| 9 | reference renderer |

The provider constructor permits targets 5 and 6 to be absent while the graph
is being assembled. That constructor rule does not make target 5 unused. For a
non-platform collection, `currentCollectionRecords` pins target 5 at execution
time and passes targets 0, 1, 2, 3 and 5 to
`StreamFinalityConservationReads.requireCurrent`. A successful saved floor
receipt therefore commits the exact conservation selector and runtime hash in
the provider's original configuration.

For a non-platform first sale, the composition requires the captured selection
source to use that exact selector, Core, Metadata host, schema registry and
chunk store, with the exact saved runtime hashes. A platform first sale returns
before the target-5 read, so the saved provider selector is reported as not
required by that original floor. Its separately captured current selection
source remains retained without being relabeled as a historical provider
dependency. Target 7 is separately bound where the original DIRECT and
provider evidence use the router. Target 8 remains the Artist facade already
bound by the DIRECT personhood assembly. The earlier RIGHTS join binds target
4. Targets 6 and 9 are retained from the original configuration but are
outside this selection-and-tier join.

This is a correspondence between verified original inputs. It does not declare
target 5 to be the globally canonical or currently authorized selector, and it
does not replace the selection source's own complete history proof.

## Historical selection at the first sale

The source retains the complete collection Artist-origin selection history,
including publication block, transaction and log coordinates. For the saved
`FirstSale`, the composition chooses the latest collection Artist selection
strictly before the first-sale publication. Ordering is the complete
`(blockNumber, transactionIndex, logIndex)` tuple; block height alone is not
sufficient.

For a non-platform first sale, the documentary comparison looks for a
historical row that matches every value saved by the provider:

- collection scope and exact collection subject;
- Artist origin, with no estate fallback;
- exact Artist ID and registration identity record hash;
- `INTENT` versus `INTENT_WAIVER`, matched to the corresponding nonzero saved
  slot while the opposite slot remains zero; and
- exact interview-evidence commitment.

The interview commitment is reconstructed from the native domain
`6529STREAM_FINALITY_PRESENT_INTERVIEW_V1` or
`6529STREAM_FINALITY_WAIVED_INTERVIEW_V1`, the deployment chain, the ordered
five-target dependency set, the collection scope, exact subject, complete
selection, interview schema ID and interview profile hash. A PRESENT selection
also retains and verifies its original interview record. A WAIVED selection
retains the exact empty-interview branch and parent declaration.

Missing or mismatched saved documentary facts remain qualified as unresolved;
they do not invalidate an otherwise valid partial assembly. When an exact
matching row is followed by another collection Artist selection before the
first sale, the match is reported as
`original_selected_history_joined_but_superseded`. It is retained as historical
correspondence but is not treated as the selection effective at the sale. A
selection published after the first sale affects only the separate current
head: the original result remains `original_selected_history_joined`, and the
later head cannot rewrite the first-sale facts.

## Tier and mint chronology

The tier capture retains the original declaration history, every allocated
token identity and every completed mint. The composition derives the tier that
was effective for the DIRECT receipt:

- an explicit declaration is used only when its publication precedes the
  completed mint; or
- an undeclared collection uses the native `MUSEUM_GRADE_LITE` default after
  the first completed mint.

The token ID and collection identity in the DIRECT receipt must equal one exact
completed-mint row. The Core mint `Transfer` must strictly precede the DIRECT
floor publication under full block, transaction and log ordering. This matches
the native producer flow: fixed-price adapters complete the mint before
retaining the DIRECT receipt, while auction flows mint before their later paid
settlement.

This extra rule is intentionally stronger than the frozen standalone floor
source. That source can preserve a narrower, internally coherent floor
observation without a tier history. Such an observation may place the retained
floor row before a separately constructed mint. The combined composition
rejects that ordering. A declaration published after the paid floor row but
before a later mint cannot repair it and is not a valid positive example.

The completed identity establishes the DIRECT token and mint receipt ordering.
It does not prove a token-to-operation-root or token-to-operation-ID join,
because the supplied native sources expose no historical getter that supports
that claim.

## Six-source replay

The command has three top-level inputs:

1. the unchanged DIRECT personhood/provider assembly;
2. the public tier/default capture; and
3. the public conservation-selection capture.

The DIRECT input already retains four source transcripts: the DIRECT floor,
historical RIGHTS, original provider configuration and personhood source. The
tier and selection captures add one transcript each. All six are replayed from
their exact retained bytes.

Each input must pass its own verifier and external manifest pin before any
derived output is accepted. The composer then checks the shared chain, Core,
collection, source block, timestamp, state root, environment and deployment
evidence. It reconciles repeated RPC requests, headers, receipts, logs,
runtime pins and original package hashes across the inputs. No anchor, response
or package is silently rebased.

The resulting evidence remains supplied native correspondence. It derives the
token identity and current tier only at the exact captured source block. It
does not extend either observation to another block, claim historical selector
eligibility at the sale block, reexecute payment, revalidate signatures, prove
master-media or archive coverage, join token operation provenance, establish
consensus finality or legal title, or complete an acquisition packet.

## CLI

`tools.museum.acquisition_direct_conservation` assembles the three externally
pinned inputs. Disclosure must be `public`, and the output directory must be
new.

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_direct_conservation assemble `
  --direct direct-personhood-assembly `
  --direct-hash $directHash `
  --tier tier-capture `
  --tier-hash $tierHash `
  --selection selection-capture `
  --selection-hash $selectionHash `
  --disclosure public `
  --output direct-conservation-assembly

.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_direct_conservation verify `
  direct-conservation-assembly --manifest-hash $manifestHash
```

Verification reconstructs the assembly and compares every output byte without
RPC or network access. `complete-packet` first performs the same verification
and then refuses completion:

```powershell
.\.venv-museum\Scripts\python.exe -m tools.museum.acquisition_direct_conservation complete-packet `
  direct-conservation-assembly --manifest-hash $manifestHash
```

## Native source references

The provider/finality review is pinned to integration commit
`36c871f44636837bdc5504e6aaeafe54e14dcb98`:

- `smart-contracts/domains/metadata/StreamNativeConservationFloorProvider.sol`
  lines 102-180: original configuration, runtime use of target 5, saved
  intent/interview facts and the separate personhood dependency;
- `smart-contracts/domains/finality/StreamFinalityConservationReads.sol`
  lines 10-60, 70-127 and 248-288: the five-target dependency set,
  Artist-only selection, full selection hash/current checks and exact interview
  commitment;
- `smart-contracts/domains/mint/StreamFixedPriceSaleAdapter.sol` lines 282-322
  and `smart-contracts/domains/mint/StreamERC20FixedPriceSaleAdapter.sol` lines
  310-361: mint completion before DIRECT receipt retention.

The auction ordering review is pinned to integration commit
`8bb6dfe2957542f641b0d558e1cfd48e1b39ae98`:

- `smart-contracts/domains/auctions/StreamEnglishAuctionHouse.sol` lines
  284-288 and 363-423, together with
  `smart-contracts/domains/revenue/StreamDirectPrimarySaleFloorCall.sol`, which
  retain the paid DIRECT receipt after the auction's earlier mint.

These references document the reviewed producer semantics. They do not turn a
synthetic source-specific runtime identity into deployed-chain acceptance.
