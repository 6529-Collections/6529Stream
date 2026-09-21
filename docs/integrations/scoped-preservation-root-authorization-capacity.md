# Scoped preservation root-authorization capacity

`StreamScopedPreservationPolicyRenderCriticalRootAuthorizationV1` retains its
original public methods and exposed `Envelope`, `Loaded` and `ContentPayload`
types. Its complete `contentItem` proof now runs in the fixed linked
`StreamScopedPreservationPolicyRenderCriticalRootAuthorizationReadV1` library.
The original append body still checks stage 6, appends the complete item and
advances the same host storage to stage 7.

The worker retains the complete original root record, 25-word preservation
binding, snapshot identity, preservation output profile and historical aggregate
preimage. It checks the same operation-17 envelope, saved Artist consent,
original signature digest and record, exact archive bytes, and immutable STOP
retention before returning the full item and provenance hash. Current aggregate
or nonce values cannot replace those original inputs.

The worker address is fixed by library linking. Calls retain the original host
context and explicit original actor. No caller-supplied worker, mutable
dependency binding, source-cache substitution or reduced proof is introduced.
All read order, gas budgets, hash domains and input structures remain unchanged.
The original custom-error ABI is retained explicitly where factoring would
otherwise remove compiler-inferred declarations.

Focused tests exercise complete provenance and original-byte retention, caller
arguments and host identity, early guard precedence, canonical encoding,
original consent and retention refusals, and restoration. They use declared
typed boundaries for identity discovery and source readback. Type checking and
selected native size checks do not establish EVM execution, added-call gas
acceptance, complete inventory construction or full finality ceremonies. Those
remain part of the coordinated [current-stack validation](../tooling.md).

The runtime limit remains 24,576 bytes and the complete-initcode limit remains
49,152 bytes. The new fixed worker needs admission in the deployment link graph.
