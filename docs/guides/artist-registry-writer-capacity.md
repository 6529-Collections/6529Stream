# Registry writer deployment capacity

This undeployed candidate keeps the original Registry writer constructor and
`StreamArtistRegistryWriterDeployment.deployWriter(address,address)` CREATE
path. The deployment library executes in its caller's context; the caller still
creates the writer with zero value and consumes its own next CREATE nonce.

The previous ea4 capture measured the deployment library at 24,990 runtime bytes
and the child creation template at 24,746 bytes. Moving that complete creation
expression to another library would move the same capacity problem. These are
historical measurements, not measurements of the current candidate.

The repair moves the seven original authority-hydration request encodings from
`StreamArtistRegistryWriterExtension` to the fixed linked
`StreamArtistRegistryAuthorityHydrationWriter`. The fixed entries cover authority,
delegations, payout, economics, readiness, publications and entropy findings. The extension retains its explicit
selector and immutable-host guard. The worker receives the pinned Coordinator,
original actor and complete original argument bytes, decodes the existing
nominal Request, and calls the original typed Coordinator method. Library
execution preserves the facade as caller. There is no arbitrary selector,
implementation input, changed hydration owner or new authority state.

The constructor, deployment library, factory, all other writer bodies, public
selectors and storage remain unchanged. The new library adds one fixed delegate
frame; no gas or transaction limit is raised. New deployments must link and
record that library along with the three existing writer workers. Historical
child runtime hashes remain evidence for their original source.

The focused test file has thirteen cases, including a bounded fuzz case. It checks
same-host CREATE nonce/value and genuine child runtime, all four constructor
refusals with same-address retry, nested request byte equality using independent
literal Coordinator selectors for every extracted method, actor/caller separation, direct and
foreign-host rejection, late Coordinator revert rollback and identical retry,
and malformed input restoration. The Coordinator is an explicit recording
double: these cases do not establish actual recovered-history admission or a
full Artist ceremony. All thirteen tests passed with 256 bounded fuzz runs at the immutable source
`0d98d04bccba5d508079834c7de324a97bbb8518`. Independent review cleared the
production seam and all thirteen test bodies before execution.

The final native capture uses Solidity 0.8.19, via IR, optimizer 200, Paris,
with metadata hash and CBOR disabled. It selected all six required production
products and their own declaration ASTs in one 25.94-second codegen pass. All
730 native source texts match the 731-source test/type snapshot.

| Product | Runtime bytes | Complete initcode bytes |
| --- | ---: | ---: |
| Registry writer deployment | 24,277 | 24,311 |
| Registry writer extension | 22,824 | 24,097 |
| Authority hydration writer | 3,700 | 3,734 |
| Identity writer | 2,530 | 2,564 |
| Multiple-records writer | 4,348 | 4,382 |
| Recovered writer | 4,988 | 5,022 |

The extension's complete initcode includes its two address arguments (64
bytes); libraries have no constructor arguments. The selected outputs retain
complete compiler bytecode, source maps, metadata, immutable references and
fixed-link references. These are compiler templates and capacity evidence,
not observed deployment traces. Original ABI, method maps and storage are
preserved.

The initial diagnostic was aborted after an unnecessarily broad AST output
selection; it has no current size result. The one-method and three-method
intermediate extractions remained oversized (24,902 and 24,838 runtime bytes),
and their failed boundaries are retained. The final seven-method seam removes
the shared encoder completely. Exact source, ABI and native capacity evidence
is retained with the isolated handoff. Whole-registry deployment, full transaction gas and current-stack
acceptance remain separate from this bounded repair.

## Focused execution addendum

The bounded native test capture selected the same six production products and
three test/helper products from 731 exact source files. All original six
creation and runtime templates are byte-identical to the selected size capture.
The two CREATE targets used by the test fixture and the test class itself also
fit the original size limits; no test allowance was needed to excuse an
oversized deployed product.

The existing canonical owner/export/execution-view tools authenticated the
physical artifacts and cached execution. The exact thirteen-case roster passed
in 1.846 seconds with compilation disabled, no source/artifact drift and 256
fuzz runs. Saved traces independently match 125 recorded CREATE occurrences,
121 successful returned runtimes and 488 fixed-link address comparisons to the
complete native templates. Four failed constructor frames are refusal evidence,
not deployed state. Representative fuzz traces do not stand for 256 separately
retained deployment traces.

The recording Coordinator is deliberately a transport double. These tests prove
original actor/caller and complete request/selector transport, constructor
identity, guard failures and rollback/retry. Actual history admission, a full
Registry deployment ceremony and the new frame's transaction gas remain subject
to current-stack acceptance.
