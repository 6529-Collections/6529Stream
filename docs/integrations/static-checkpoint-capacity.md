# STATIC checkpoint capacity

The capacity repair changes only pure byte scans. It preserves every original JSON,
HTML, field comparison, content leaf, output-chain commitment and source read. The
checkpoint still renders both full Router outputs independently and revalidates all
previous rows before an append or a successful current read.

`StreamStaticContentBytes` skips a complete word only when it contains no comma;
possible field starts still require the original first-word and full-span hash
matches. `StreamRenderContextV1.scriptText` similarly skips only words without `<`,
then applies the original case-insensitive `</script` prefix rule (including a
prefix without a trailing `>`). `StreamStaticText.isValidUtf8` skips complete ASCII
words; every non-ASCII sequence follows the original validator. Malformed UTF-8,
surrogates, truncated sequences, and out-of-range code points remain rejected.
The detector never uses its bit positions as match locations.

No Router, checkpoint admission, authority, storage, deployment default, output
limit, or vendor source changes. In particular, each checkpoint STATICCALL still
requires its entire configured gas cap, EIP-150 allowance, and local reserve.
There is no caller-budget clamping and no partial scope labeled current.

## Workload and evidence

The focused capacity fixture deliberately constructs a new producer with a
4,000,000 dependency-read cap and a 10,000,000 render cap. These are measured fixture
configurations. The read cap includes the selected checkpoint's own 2m child-read
cap and its original full-budget reservation. The render cap includes the
renderer's unchanged 8m optional-attribution cap plus its nested headroom.
They are not a global default or a change to an existing deployment's
raise-only governed parameters. A previously deployed producer with a larger cap
retains that cap and its admission requirements.

The bounded tests cover one token with a 24,576-byte ASCII comment script stored
in the actual SSTORE2 bundle, and a six-token small-script scope appended as
a four-row and a two-row batch. The second batch must also revalidate the first four rows.
Each bounded call includes base/calldata intrinsic gas and reserves another 5,000
gas for the call/measurement frame within 16,777,216. High-budget diagnostics are
recorded separately; success there cannot satisfy the bounded assertion. A 30m
single-render reservation and the 14m multi-row reservation remain explicit
negative controls. Eight rows remain an explicit over-reserved workload, with a
separate high-budget diagnostic; they are not claimed to fit. The unchanged
recovered-attribution gas sweep must reject the
formerly unavailable checkpoint at all tested parent budgets.

The fixture composes actual Router, Renderer, Metadata, inventory, scope membership,
selection/content producers and threshold Safe. Core, Artist, version admission and
governance remain explicit typed boundaries. Cooling covers the named accounts and
storage listed by the test plus both SSTORE2 carriers, not every transitive
read-set account. Execution-plus-intrinsic envelope measurements are not a mined
current-stack transaction receipt or universal cold-read proof.

The exact `1a2f63f1` fixture still contains the original production
`StreamMetadataRouter` at 39,393 runtime bytes under solc0.8.19/viaIR/runs200.
This is a separate EIP-170 deployment blocker; the held Router size proposal was
not applied. The fixture permits oversized deployments solely to exercise the
existing graph, so a passing gas envelope is not a deployability claim.

Capacity depends on content, complete scope size and governed budgets. This profile
does not establish a bound for arbitrary 24KB scripts with many escaped prefixes,
large executable libraries, maximum token data or 32 maximum-size chunks. It does
not establish all declared structural maxima as transaction-usable. Those cases
must retain fail-closed behavior and need their own complete-path measurements.

## Differential coverage

`StreamStaticScanParity.t.sol` compares field matching and UTF-8 validation with
frozen original helpers from `1a2f63f1`, including word/final positions, prefix-only
false positives, escaped keys, wrong token data, all byte values, malformed Unicode,
and arbitrary byte fuzzing. The existing pure-encoding suite still compares exact
JSON/HTML/script bytes with the frozen `2549ddd3` serializer and covers neighboring
memory, every boundary, case variants and incomplete prefixes.

See [the original checkpoint profile](static-content-checkpoint.md) for its
commitment and authority boundaries, and [pure-render evidence](static-render-encoding.md)
for the earlier isolated encoder baseline. The results below identify the retained frozen captures.

## Measured result

The final 227-source capture passes all 13 focused tests: the nine original
composition cases, two finite-capacity/diagnostic cases, and the two unchanged
low-parent-gas regressions. The separate 19-source pure capture passes all 15
tests, including five differential fuzz cases with 256 runs each.

| Named cooled workload | Execution plus calldata/base intrinsic gas | Result |
| --- | ---: | --- |
| One 24,576-byte ASCII-comment script, append | 9,512,309 | Fits |
| Same token, full current validation | 6,072,737 | Fits |
| First four small-script rows, append | 5,756,760 | Fits |
| Next two rows after four, including prior-row validation | 6,653,206 | Fits |
| Complete six-row current validation | 5,671,748 | Fits |

The separate high-budget large-script diagnostic uses 9,145,788 gas for append
and 6,052,294 for current validation (no transaction intrinsic component).
The earlier joined source took 35,327,996 and 21,409,844 respectively. These
high-budget readings are separate from the strict envelope assertions above.
Eight-row current validation costs 7,438,490 with ample parent gas but still
correctly fails the transaction envelope because its final calls cannot receive
their entire 10m configured budget. The second four-row append also refuses
atomically. Neither result is relabeled as supported transaction capacity.

Selected runtime sizes from that same capture are checkpoint 16,510, RendererV1
17,869, pure encoding companion 12,878 and MetadataV1 22,642 bytes. The original
39,393-byte Router remains the separately identified deployment blocker above.

Evidence is retained locally under
`D:/repos/6529Stream/.tmp-static-capacity-checkpoint5/`: `capture.json`,
`native.json`, `native.stderr.log`, `run.json`, `result.json`, and the frozen
project/artifacts. The exact Safe 1.4.1 fixture hash is in the capture manifest.
The pure differential evidence is
`D:/repos/6529Stream/.tmp-static-capacity-pure2/`; the three production files are token-exact after formatting. The parity harness
formatter only reflows lines and braces its existing single-statement `_fill`
loop; that test-only formatting is source-reviewed. Frozen-reference comparisons
allow only library renames and import relocation. `codex-diff-check` passes.

Earlier captures are retained. The 2m outer dependency budget could not satisfy
the Selection producer's unchanged 2m child reservation. A 6m render budget fit
the envelope but starved the existing 8m optional-attribution preflight; the
original exact-output and live-Artist tests correctly rejected that profile.
Those numbers are not accepted capacity evidence. The final profile passes those
same oracles with original attribution intact. No gas guard was weakened.
