# Complete original living multiplicity with delegation

The existing `hydrateMultipleArtistAuthority(MH.Request)` entry point also
supports complete original living delegation histories. The request, capability,
operation 60, seven-owner mask `0x7f`, signing domains and facade/Coordinator ABI
are unchanged. No caller profile flag or additional facade selector is required.

After authenticating the exact predecessor runtime, reciprocal suite, original
operation-57 seal and destination binding, the worker reads the actual source
journals. Identity operation 25, 26 or 27, Consent operation 16, or a mode-2
binding selects `6529STREAM_ARTIST_MULTIPLE_LIVING_DELEGATION_V1`. Otherwise the
existing multiplicity profile and its encoded owner states remain unchanged.
There is no failed-profile fallback. The separate single-identity delegation
selector still requires its complete one-Artist/one-collection source.

## Completeness and authority

The supplied Artist IDs and collection IDs are sorted, unique and exhaustive.
The fixed worker reads all seven native journals before dividing them by subject.
Every receipt must belong to exactly one supplied Artist and, where applicable,
one supplied collection. Registration ordinals independently reconstruct the
original Artist IDs and complete global registration allocator. All owner
revisions, native counts, source checkpoints and final latched lanes must match.
An independently valid subject export is only a projection; it does not prove
that another subject or dependency was absent.

Supported identities remain original living class 1/status 1, delegation epoch
zero, with nonprovisional revisions and accepted generation-one PRIMARY_ONLY
bindings in consent modes 1 or 2. Complete operations 1/2/14/16/25/26/27/54 are
retained. Every revision document, original signature, grant version, current
grant head, use count, explicit revocation and consent-to-grant association is
carried in its original Registry domain. A global grant's use count must equal
the sum of its supported recorded uses across every included collection.
Current replacement, expiration or revocation never substitutes for the grant
that authorized an original record, nor does import confer fresh authority.

Every principal nonce index and every used delegate lane is matched to its
actual source index, full sparse prefix tree, exhaustion flag and next hint.
The same delegate address under two Artist IDs remains two distinct lanes.
All seven owners' replay cells and original surface/scope preimages are carried;
logical guards are rekeyed by the existing successor import. Fresh successor
writes still require the original live authority checks and successor signature
domain. The original source's operation-57 latch remains historical.

## Compact owner codec

`StreamArtistMultipleDelegationHydrationTypes.sol` defines five closed tagged
`abi.encode(tag, rows)` envelopes. Identity uses `abi.encode(tag, Identities)`:

| Owner | Tag suffix | Exact row |
| --- | --- | --- |
| Binding | `BINDINGS_V1` | collection ID, original `AH.Binding` |
| Identity | `IDENTITIES_V1` | Artist ID, complete record hashes, original canonical `DH.IDENTITY` bytes, principal nonce words; plus complete collection IDs |
| Acceptance | `ACCEPTANCES_V1` | original binding hash, `AH.Acceptance` |
| Attribution | `ATTRIBUTIONS_V1` | collection ID, state, generation |
| Consent | `CONSENTS_V1` | collection ID, original ordered policy selectors, `DH.Consent` |

Each suffix has prefix `6529STREAM_ARTIST_MULTIPLE_DELEGATION_`. Collaborator
and Payout states are explicitly empty. Decoders reject another owner's tag or
noncanonical trailing bytes; the nested identity bytes use the unchanged
delegation codec. Full source validation precedes the original guarded owner
calls, all seven commits, source rechecks and one atomic Archive append. The
fixed workers receive declared typed storage roots; no raw-slot aliases or
caller-selected execution targets are introduced.

The Archive retains the original full commitment/evidence shape and 24,575-byte
carrier limit. Receipt/index bounds are admission ceilings, not promises that
all maximal combinations fit. For example, independently calculated fixture
shapes range from 20,384 to 21,600 bytes; two Artists with one used grant each
and all detached 130-byte Safe signatures need 25,344 bytes and do not fit.
The same original actions made directly by both threshold Safes retain empty
record signature bundles and are estimated at 24,384 bytes. These are ABI-size
calculations, not executed evidence or transaction-capacity acceptance. The
authored direct-Safe case still must pass the unchanged runtime carrier check.

## Validation and remaining profiles

Fourteen authored cases in `StreamArtistMultipleDelegationHydration.t.sol` cover
actual original/successor Artist owners, Archives and threshold Safes: independent
and shared identities, global grant accounting across policies and sales,
revision and grant separation, historical revocation/exhaustion, fresh successor
signatures/nonces, omitted subjects and nonce/replay data, forged exports,
changed source, late Archive rollback/identical retry, old profile bytes,
closed codec tags and the original oversized-evidence refusal. Core/governance
and the explicitly named sale facts/catalog reads remain typed boundaries.
Source/ABI and selected product sizes are separate from native test execution,
full current-Core integration, gas capacity and release acceptance.

Corrected/pending bindings, prebinding revisions, collaborator policies, advanced
authority/guardian/rotation/recovery/estate/dormancy state, nonzero delegation
epochs, other delegated capabilities, timing changes, payout/economics/readiness/
publication/finding combinations, previous imports and larger evidence carriers
remain required separate profiles. Unsupported histories refuse before import.
Held collaborator/global-freeze and codec proposals are not used here.
