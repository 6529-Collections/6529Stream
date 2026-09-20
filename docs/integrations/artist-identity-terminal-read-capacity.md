# Identity terminal-read capacity

The Identity owner retains its original external ABI, storage, constructor,
selectors and fixed read workers. Forty-four external read return declarations
use `calldata` instead of `memory`. Each affected body contains only the original
forwarder, which ends with an unconditional EVM `RETURN` of the worker's ABI
bytes. The compiler does not need to allocate an unused default memory return
object before that terminal return. No calldata object is read or returned by
Solidity after the forwarder.

This change does not move any authority check, replay mutation, checkpoint,
record, native receipt, or state write. The three existing forwarding paths
retain the original caller, complete calldata, fixed targets and declared roots.
Direct STATIC reads are unchanged. The recovered delegation feature hook remains
`DELEGATION_GRAPH_FEATURES` from the integrated source.

## Exact boundary and measurements

The paired baseline is `ccbaf41fa13d33fdf59fd3c715b7cc1ca920646c`.
Both products use Solidity 0.8.19, via-IR, optimizer 200, Paris, no CBOR and no
bytecode hash. Runtime must fit 24,576 bytes; full initcode must fit 49,152.

| Product | Original | Terminal-read declarations |
| --- | ---: | ---: |
| Identity runtime | 26,198 | 23,393 |
| Creation bytecode | 33,505 | 30,700 |
| Original constructor arguments | 288 | 288 |
| Full initcode | 33,793 | 30,988 |

The runtime saving is 2,805 bytes, with 1,183 bytes of runtime headroom. This is
selected production code generation, not an executed deployment or gas result.
The earlier 70c0 source's 26,351-byte Identity precedes the common Owner return
repair; its measurement is retained separately and is not this paired baseline.

The source comparison reconstructs the complete original Identity file after
restoring only the 44 return declarations. All 224 function bodies and the
constructor body are byte-identical after line-ending normalization. The
whole-source ABI and recursive storage comparison retains all 47,681 original
ABI entries and 4,185 contract/interface/library layouts. These broad counts
include test and historical source definitions; they are not a claim that all
those behaviors were executed or accepted. The Identity runtime's 16 fixed
library targets and creation code's 26 targets are unchanged. Optimizer link
occurrences differ for OwnerCommit (three versus four); that worker and its
original host call sites have no source change.

## Focused behavioral oracles

`test/unit/artist/StreamArtistIdentityTerminalReads.t.sol` authors eight cases:

- Actual compiler-derived Factory parts, original three children, Identity
  construction, original immutable bindings and nonce-1/nonce-2 children.
- Original registration and exact dynamic identity/document/metadata bytes.
- Arbitrary document bytes across 1–256-byte lengths, compared with independent
  original identity-domain and ABI preimages.
- Mixed empty dynamic values and the original unknown-preimage refusal.
- Original timing writer, exact retained checkpoint/entry and bounds refusal.
- Missing arguments, noncanonical uint8 and unknown selector refusal.
- Missing recovered provenance, unknown auxiliary kind and wrong fixed suite.
- Original unauthorized/incorrect-operation refusal followed by the exact valid
  registration arguments, without consuming state on failure.

The fixture deploys actual Identity and constructor children. Core, Manager,
Registry/Archive addresses, governance action facts and the Coordinator are
explicit typed boundaries. No owner storage is seeded or overwritten. This is
not an actual Executor/Safe, seven-owner import or complete current-graph test.
The eight cases are type-checked; runtime execution and cold read gas remain
pending. Production runtime and initcode checks remain present in the fixture.

## Retained local evidence

The task-owned capture is
`D:/repos/6529Stream/.tmp-identity-terminal-capacity`:

- `preservation.json`: each declaration/body and whole-file reconstruction.
- `joined-separated/abi-original` and `abi-final`: 2,717/2,718 source inputs,
  outputs and zero-error results; `compatibility.json` records strict comparison.
- `joined-separated/size-original` and `size-final`: paired selected products;
  final input SHA256 `95e280f6a16eb1175bd3044dfdfe88710c63e5a547d3a2fb8ce9770a8da12aeb`.
- `joined-separated/links.json`: original/new fixed targets and occurrences.
- `baseline` and `five-declarations`: the initial 654-source paired probe.
- `joined-ccb`: an interrupted mixed-output attempt retained without a result.

The interrupted attempt combined whole-source ABI/layout outputs with selected
bytecode and took unexpectedly broad compiler time. It was stopped, then the
ABI/layout and selected-bytecode jobs were separated. No compiler configuration
or contract limit was changed. The separate Attribution replay-mutation proposal
remains inert and outside this source boundary.
