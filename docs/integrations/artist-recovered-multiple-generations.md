# Recovered multiple-Artist generation history

This developing operation 60 profile imports complete original PRIMARY_ONLY
generation histories across recovered class 1/class 3 Artists and collections.
It retains the existing recovered Request and royalty witness entry. It does
not change the Coordinator ABI, owner storage layouts, original authorization,
or the codecs selected by earlier profiles.

## Scope and carrier

`MULTIPLE_GENERATIONS` is bit **2097152**, with tag
`6529STREAM_ARTIST_RECOVERED_MULTIPLE_GENERATIONS_V1`, version 1, allowed mask
**2276351**, and combined owner advertisement **4194303**. The allowed mask
contains recovered class/history bits 1–16, original consent/attestation bits 32–256,
generation 512, correction 2048, accepted-generation 4096, dispute 8192,
history-content 32768, history-record 131072, and this profile bit.

There must be multiple selected Artists or collections, complete accepted current
bindings, and at least one collection at generation 2–128. Each collection retains
one original Artist across all its generations. Earlier pending generations may
have authentic refusal 3 or withdrawal 4 terminals. Earlier accepted generations
must have the original governed 44 opening and class 2 revoke 46 resolution before
the next corrective 1 proposal. Signed/reopened disputes, ratification 52,
collection sanctions, Platform declarations/corrections, changed-primary
rebinding, collaborators and class 4 are separate required-profile work; this
tag rejects those families. Existing supported Identity sanction grants remain.

Every owner envelope is
`abi.encode(tag, uint16(1), uint8(owner), M.State, bytes auxiliary)`.
Each Artist/collection appears once in canonical selector order. Owner0 rows
are original binding/correction bundles; owner3 rows are original acceptance
histories; owner4 rows are `G.Attribution` containing original governed-revocation
history and original attestation rows; owner6 rows are `G.Consents` containing
original consent rows and the complete accepted/pending binding inventory.
Identity and Payout retain complete canonical rows per Artist. Collaborator
rows remain empty for PRIMARY_ONLY.

Owner0 and owner4 auxiliary bytes contain the same complete `G.Inventory`:
original Archive catalogues, operation envelopes, binding/correction rows and
generation points. Owner3 carries the complete generation matrix. Other owners
require empty auxiliary bytes. The original cross-owner anchor and all Artist
queries remain unchanged. Only owner4 collection record lists are copied and
projected to the exact original op24 subsequences. No owner provenance, journal,
alias, nonce, publication inventory or original coordinate is filtered.

## Original chronology and conservation

One complete admission precedes source collection. Original Archive proposal,
completion and snapshot proofs retain all seven original cutoffs. Independent
collection cursors permit interleaved owner0 operations; no per-collection
revision is substituted for a global owner clock. Native1/3/2 occurrences join
their exact original Archive points. Governed44 is native, while resolution 46
uses its authentic RESOLVE/governance alias pair. A resolution is never inferred
as opening-plus-one when another collection writes between them.

Every op24 row uses its saved binding generation and association. It must fall
after that generation's actual owner4 acceptance completion and before its next
proposal. C2PA predecessors remain one chain per Artist across all collections,
generations and original eras; original source heads and publication carriers
are compared directly. All original14/15/16/17/20/21 rows, grants, revocations,
signature bytes, domains and delegated nonce lanes are preserved. Operation 14
has no saved generation and receives no invented assignment; retained delegated 14
requires an authentic accepted historical mode 2 binding. Saved-generation
delegated 16 uses its exact accepted mode 2 binding.

Identical economics terms may retain multiple original15 records in distinct
accepted generations. The source collector consumes one term witness per actual
op15 occurrence, reads that record's association and checks both the original
first-record terms map and the per-binding record getter. Later rows retain the
first `originalRecord` and original continuation replay domain. Import checks
all target cells before economics writes, preserves the first terms-map record,
and installs every distinct association. Sale duplicate checks use the original
full replay scope `(terms, generation, bindingHash)`; repeated terms across
generations retain distinct signed records and the original latest lookup.

Consent and attestation workers return per-Artist/per-grant increments. One
equality covers every retained version after all collections and generations;
the original complete nonce union, bitmap words, popcounts, exhaustion, hints and
index order remain intact. Shared timing/registration state is installed once.

## Atomic import and evidence

There is one guarded apply/commit per owner and one activation per unique lane.
Original target-map preconditions precede installation; late failures roll back
the whole transaction. After writes, the fixed generation currentness route
revalidates the canonical owner4 envelope, original anchor, exact full owner4
provenance, aggregate chronology and original complete Archive catalogue against
all seven cutoffs. That route also applies when there are no op24 records. The
existing full-source, publication, timing, external-guard and final Archive
checks retain their original order.

Eleven actual-owner/Safe scenarios and 29 pure consent-worker scenarios are
authored and type-checked. They cover repeated economics/sale terms, global
grant versions, interleaved resolution points, accepted/refused/withdrawn
generation combinations, class3, independent numeric delegate nonces, repeated
imports, missing witnesses, currentness refusal and late rollback/retry.
Actual fixtures use real Registry, Coordinator, owners, Safe and Archive; Core,
scoped governance contexts and archival coverage remain explicit unit boundaries.
The late rollback scenario uses a destination Archive block-number overflow;
it does not simulate source-currentness drift during the transaction.

All 1,562 pre-profile production ABIs and 11,355 ABI entries remain unchanged;
the capacity repair also preserves all 1,600 already-committed production
products, their 11,438 ABI entries, method maps and recursive storage layouts.
Fixed typed libraries separate full binding decoding, owner4 proof and record
installation, consent/family collection and final encoding. Original validation,
target checks, revocation/record writes, global conservation and final currentness
remain ordered. The record writer receives only the exact binding hashes selected
from the fully authenticated inventory; the complete original inventory proof
is retained before any target write.

Selected source-specific native captures now provide fitting outputs for every
requested product. The family worker has 66 bytes of runtime margin; the earlier
Coordinator capture is exactly 24,576 bytes. Each output retains its actual
compiler input and source/metadata hashes. These captures span repair revisions
and do not substitute for one compatible final-source dependency context.
Earlier Yul and oversized outputs remain diagnostic evidence. The eleven actual
scenarios are unchanged; execution, gas and joined-current acceptance remain
separate evidence. This profile does not establish full-v1, audit or release readiness.
