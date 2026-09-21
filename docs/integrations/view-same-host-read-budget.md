# VIEW same-provider identity read budget

The fixed Configuration worker calls four exact selectors back on its own
provider: the complete source selection and the snapshot address, runtime hash
and validation budget. Their existing source budget is an upper ceiling. It
must not be reserved in full when Discovery has admitted a smaller component
call envelope.

`StreamFinalityViewSameHostReadsV1` admits only those four selectors. It retains
at least `gasleft()/64 + 100000`, forwards the smaller of the remainder and the
original source ceiling, and refuses below 50000. The original inventory IO
reader still applies its independent EIP-150 reserve, exact STATICCALL return
length and original error. Returns are exactly 192 or 32 bytes. Configuration
retains all canonical decoding, receipt/preimage, runtime, dependency, scope and
reciprocity checks. The helper cannot read an arbitrary address or caller-chosen
return width. The historical receipt and direct factory getters retain their
original read budget.

Nested dependency readers retain their full original strict caps. A reduced
outer allowance that cannot execute them fails; this helper does not authorize
partial validation or turn identity selection into current finality evidence.
The 100000 local reserve permits fixed result transport and epilogue; it does
not promise completion after an adversarial getter spends the whole allowance.

ABI78 checks 117 sources with zero errors. Four new authored regressions compare
complete direct/composed Configuration results under 12m/44m outer envelopes
and 24m/48m source ceilings, preserve the strict 2m child allowance, and test
insufficient gas, closed selectors, wrong widths and noncanonical addresses.
The surrounding constructor/getter graph is explicit and typed.

The immutable `01f71ceb` capture now passes all eight Configuration cases.
The native build completed in 74.485 seconds (70.954 seconds in code generation) over 117 exact sources with
all 164 ABI products selected up front. Complete native artifact, AST, metadata,
link and source checks passed. The original size check incorrectly classified
the 30,574-byte aggregate test root as a deployed protocol product; that failed
record is retained. Applying the repository's existing aggregate-test policy
allowed the exact unchanged cached artifacts to run: eight passed, zero failed,
1.531 seconds, with source/artifact/cache/capture/config hashes unchanged. All
70 other nonempty products retained the 24,576/49,152 limits; created fixtures
have no constructor arguments. The test-only runtime code-size allowance was
2,000,000; the original 100m test gas allowance remained unchanged.

The first unsupported AST-only preflight and a later sandbox version-command
refusal also remain retained. An unused loader-only test draft at ABI81 was
restored to exact `01f71ceb` before execution and was never compiled. No actual
nine-component provider/Discovery ceremony, complete cold capacity or shipping
transaction conclusion follows from these typed eight cases.
