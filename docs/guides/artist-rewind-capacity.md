# Artist V3 transport capacity

The V3 recovery host keeps the original external selectors, operation guards,
storage layout, record domains and Archive sequence. Its fixed view transport
uses the compiler-declared Identity storage roots; it has no raw slot aliases
or caller-selected delegate target.

`StreamArtistIdentityReadDispatch` adds a sixteen-root overload for the V3
capability, inventory and context reads. Every previous overload remains in
place. The new overload passes all other selectors to the previous
fifteen-root implementation. `StreamArtistRecoveryRewindInventory.readEncoded`
decodes only its nine declared selectors and calls the original typed bodies
or reads the same supplemental maps. The original current-capability branch
is evaluated before the old capability fallback.

The terminal read wrappers declare their unused structured return values as
`calldata`. They do not return a calldata pointer: each wrapper still reaches
the same unconditional EVM `RETURN` over bytes produced by the fixed worker.
This removes Solidity's unused default memory-object construction. Public ABI
tuples and selectors are unchanged. No such declaration is used on an ordinary
return path, an internal caller-dependent read or a mutation with a modifier
tail.

`StreamArtistRecoveryRewindTransport` accepts only the two original V3
Coordinator selectors. It receives the unchanged economic context and full
original calldata, then calls the original preparation recipe or the fixed
recovery decoder. Both external Coordinator functions retain their original
`operation` modifier: begin, recipe, history/payload synchronization, unlock.
The decoder preserves the actor/request/authorization/manifest tuple. Neither
transport introduces authority, an alternative operation or a new record.

## Evidence and remaining limits

The comparison baseline is integration `e4ccdba4`; the fixed preparation and
record workers are the separate `f6684292` dependency. Selected code generation
uses Solidity 0.8.19, via IR, optimizer 200, Paris, and no CBOR metadata. The
retained comparison checks the original host ABI entries and recursive storage
layouts, the exact prior read overloads, original inventory bodies, and the
limited declaration/body differences.

Creation-object length and constructor-argument length are separate facts. The
fixed constructor tuples have determinable argument lengths; the Registry's
dynamic URI requires a concrete deployment value before claiming its complete
initcode length.

The original Estate and Identity writer deployment wrappers were already above
the runtime limit on the pre-V3 `f541a56e` source. This transport repair does not
repair those wrappers or establish whole-suite deployability. The retained
before/after measurements distinguish them from the new V3 host regressions.

The original governed read budgets are unchanged. The new V3 routing introduces
fixed library frames and copies; a selected bytecode measurement is not a cold
read-budget or current-stack execution result. The existing V3 actual-owner,
Safe, history and Archive regression suites still require execution against
the final linked source, including malformed-call refusal, original context
reads, one-time replay, and late Archive rollback. No native, complete-graph,
release or audit acceptance follows from the source and capacity comparison.
