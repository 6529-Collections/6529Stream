# Shared VIEW content-root state

The original Router scoped history has an additive, closed VIEW transition.
`viewSubject`, `nextView` and `commitView` use the same declared storage roots,
record preimage, event and collection aggregate as the original scoped writer.
The original TOKEN/RELEASE/SEASON entrypoints still reject VIEW. Canonical VIEW
shape validation is separate from real Core membership and producer validation.

`authorizeViewContentRoot` requires literal `CONTENT_ROOT` consent through the
original selected Artist and the existing consumption/evolution maps. A
`RENDERER_CONFIG` adoption is not consent to publish the artwork's content root.
There is no pre-mint bypass in this required-family entrypoint.

The typed VIEW writer must authenticate its distinct producer, profile, schema,
snapshot and complete output commitments before authorizing and committing the
transition. Its closed binding is part of `Record.stateHash`; that state hash is
already included in the original aggregate and record preimages. The producer
binding cannot be substituted with the old non-VIEW leaf schema. The same
collection aggregate must remain included in later legacy collection writes.

This state substrate does not expose a new Router publication method by itself.
The actual typed writer, snapshot, read dispatcher, original op17 consent and
complete publication/finality execution remain separate integration work under
[ADR 0054](../adr/0054-explicit-non-sanction-preservation-rendering.md).

Seven focused state-book tests cover mixed VIEW/legacy histories, independent
heads, original event/record bytes, lineage rollback/retry, closed scope shape,
required nonzero consent, revision overflow and 256 fuzz inputs. They use a
storage harness, not an Artist or membership mock presented as authorization.
The original native1/2 failures were test-oracle memory aliasing and an incomplete
revert expectation; production state code was unchanged when those were fixed.
The final native5 run passes all seven with the literal event-signature check;
the state library is 5,836 bytes and the test harness stays below the original
24,576-byte limit. The native4 test-only size failure remains recorded. The required-family Router wrapper is source/type checked;
actual consent replay and whole-writer authority are not established here.
