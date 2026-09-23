# Router internal read sharing

The batch at `8ad30331c41c45e7df0230b7bd89aa059d85dfd8` reduces repeated
internal code on the joined V2 Router source at
`9b016f1a26c015b394b1ac01a663b7e0d395db9f`. It follows the
[codec and serving-path factoring](router-codec-factoring.md).

## Bounded reads

`StreamRendererCalls.read` receives its existing maximum return length and
exact-length flag in a memory-only `ReadOptions` value. The 48 production call
sites in 11 consumers keep the same target, encoded input, maximum, exactness
and gas-cap expressions. The public contract interfaces are unchanged.

The original read body retains its code-existence check, 12,000-gas reserve,
available-gas calculation, cap ceiling, STATICCALL, return-length check before
copying, and exact custom error. `fixedCode` and `stringResult` are unchanged;
their distinct failure and canonical-string rules are not combined with this
read path. The change adds no external call or storage field.

Passing the memory value at the call sites matters: a scalar forwarding
wrapper was optimized back into multiple bodies. The selected implementation
has one bounded-read body in optimized Router IR. Its memory allocation and
field loads can change gas consumption near a low-gas boundary. This evidence
does not establish identical gas consumption or worst-case collector budgets.

## Configuration records

`StreamMetadataStaticState.record` shares the complete storage-to-memory copy.
Default, explicit-record and resolved configuration reads use the same
constant-slot mapping and original keys. Activation checks and token,
collection and default precedence are unchanged. These reads remain internal
and access storage directly. No delegated configuration decoder, record cache,
new namespace or replacement authorization state is introduced.

The optimized Router IR contains one shared record-copy helper. The shared
token-serving implementation from the preceding batch remains singular.

## Regression scope

`StreamRendererCallsSharingTest` compares results with a frozen copy of the
original five-argument reader. It covers raw bytes, empty and non-word-aligned
returns, exact and maximum lengths, oversized and reverted payloads, missing
code, short selectors, zero and small caps, and bounded low-gas refusal.

Its mutation test first proves the target can write through an ordinary call.
It then invokes both reader harness methods through ordinary calls and checks
that the helpers refuse the target's write with the exact error and preserve
state. The outer test call does not supply an inherited static context.

The configuration regression compares complete encoded records across the
default, explicit, collection and token views, including unknown zero records
and retained snapshots after a default change. This is a cross-view consistency
oracle; the existing activation test separately checks the full record-hash
preimage.

The selected native capture includes all changed production consumers and nine
test hosts. These focused tests retain typed surrounding boundaries and do not
replace actual-current Terminal10/Instant8, V2 publication acceptance, full CI,
collector gas checks or release evidence.

## Native checkpoint

The immutable 280-source capture at `8ad30331` compiles successfully with the
original Solidity 0.8.19, via-IR, optimizer 200, Paris and metadata settings.
Router ABI and all 97 method identifiers match the joined base: the original
94 methods plus the three V2 publication/binding methods. Common production
ABIs are unchanged. Normalized Router storage matches the source-verified
reference, and captured inputs remain unchanged.

Router runtime is **28,600 bytes**, still **4,024 bytes above** the unchanged
24,576-byte limit. Creation code is 34,212 bytes. The current graph fixture's
288-byte constructor arguments bring initcode to 34,500 bytes, below the
49,152-byte limit. Other nonempty production artifacts in this capture fit the
runtime and bare creation-code limits; their constructor arguments were not
universally audited. The earlier 26,754-byte Router checkpoint predates the V2
join, so the difference does not isolate this batch's size effect.

The cached cohort passes **86 of 86 cases** in 6.733 seconds, including six fuzz
cases with 256 runs each and seed `0x6529`. No native artifact or cache hash
changed during execution. The integrator authorized functional execution with
the existing fixture profile despite the known Router size failure. This is
functional regression evidence, not deployment acceptance.

Across 58 unchanged successful unit cases, the largest execution-gas increase
against the preceding pre-V2 capture is 373,017 gas (1.9893%) in the Safe bundle
selection/retry case. These totals include multiple calls and, in some tests,
additional contract deployments. They combine the V2 join and internal sharing;
they do not establish per-call cost or worst-case gas compliance.

The integration branch subsequently trimmed a test-helper trailing blank line
and added `STREAM_MASTER_WAIVER_V1` to the Metadata publication schema branch.
Those changes are outside this frozen capture. This checkpoint does not claim
to validate that new waiver branch or later conservation-floor integration.
