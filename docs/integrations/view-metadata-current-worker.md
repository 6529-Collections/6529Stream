# VIEW metadata current-evidence worker

The new VIEW Metadata kernel measured 26,213 runtime bytes at the joined source
9db6df068f17a36abc94eaa7d911c65488500741. Its current evidence body now runs in a
fixed compiler-linked worker. All source, snapshot/lock, content root, full
28-word binding, prepared-state and timestamp predicates retain their original
order and read limits. The same provider remains the delegate host. The facade
returns the complete original Evidence; its root, snapshot and manifest bodies
are unchanged. There is no new cache or authority path.

The moved current/root/binding/canonical bodies mechanically match the previous
source after only Evidence type qualification and formatting. All ten original
ABI rows and the empty storage layout match. Seven authored differential tests
compare a frozen original implementation, full output and literal root/binding
preimages, both lock branches, all 28 binding-word mutations, malformed canonical
bytes, state/snapshot/scope/time drift and restores, scope/configuration error
order and dynamic retained data. Configuration, Snapshot and inventory source
replies are explicitly typed test boundaries. External read fixtures require the
actual delegate host as caller. These tests do not establish the complete source,
Artist consent or Registry ceremony.

Selected native Solidity 0.8.19, viaIR, optimizer 200, Paris, no CBOR/hash measured
Metadata runtime/creation 19,001/19,033 and Current worker 21,299/21,331 bytes.
The 220 exact source texts join all 440 metadata entries, and every compiler link
placeholder and normal compiler setting was independently checked. This is an
unlinked two-product size measurement; constructor/runtime deployment and gas are
not established. The extra full-Evidence call frame needs actual composed gas
acceptance. Seven tests are authored/typechecked, not executed.

Evidence: `.tmp-view-metadata-current-size1` and `.tmp-view-output-abi88` in the
integration evidence workspace. All original limits and source-qualified failures
remain; no maximum-scope or shipping-transaction acceptance follows.
