# VIEW attributed retrieval witness

`StreamViewRetrievalWitnessV1` retains a new statement by the original institutional
Archive writer about a complete adopted VIEW image. It does not perform network
requests, infer file digests from URLs, prove an origin immutable, or parse a generic
resolver. The writer attests exact origin, redirect, mirror, or Arweave-path
correspondence to the complete object already admitted by the original Archive.

## Deployment and source identity

The constructor accepts thirteen words: Core/address pin, Router/address pin,
root-free preservation checkpoint/address pin, original external Archive/address
pin, chain ID, and read/source/archive/signature gas caps. It validates canonical
checkpoint configuration, Archive capability/profile/Core, and Router/Core
reciprocity. No unpublished adoption, root, snapshot, reference, inventory, or
provider binding is required during construction. Deploy after checkpoint and
Archive and before the companion-enabled inventory and complete provider binding.
The exact profile is `6529STREAM_VIEW_ATTRIBUTED_RETRIEVAL_V1`.

Every prepare/publish/current read obtains the actual checkpoint current source,
complete adopted payload and exact image URI. Complete scope, Core, Router, adoption,
source hash, original declaration and payload coordinates are committed. Before an
observation can be published, the pinned Router must return the complete canonical
locked Artist presentation with the exact adopted Artist runtime and nonzero original
identity, acceptance and snapshot fields. Its complete hash and Artist ID enter the
signed Source. The admitted object must belong to that Artist. Downstream
inventory/media admission independently repeats the Artist/full-scope/exact-row join.
This prevents a writer for an unrelated Artist from creating a target-scope
revocation epoch.

## Fresh signature and retained authority

`prepare(Request)` derives the complete Observation and digest. The signing domain
is `6529STREAM_VIEW_RETRIEVAL_OBSERVATION_V1`, chain, satellite, exact configuration
hash, and the complete Observation. The writer comes from the second institutional
receipt and immutable active family storing agent after the original complete
receipt-pair/fixity/native admission. It is not caller-selected.

`publish(Request,signature)` checks its own writer nonce and uses the original
own-key/EIP-7702/ERC-1271 validator, including direct-writer empty signatures. It
repeats complete source and Archive preparation after signature verification, then
retains the canonical observation and signature in existing 8192-byte STOP carriers.
Missing or changed chunks roll back the entire publication and nonce. The whole
payload limit stays 524288 bytes and the URI limit stays 2048 bytes.

Original receipt signatures, old deadlines and today's Safe owners are not replayed
when reading history. The fresh retrieval deadline admits its submission; later
expiry does not invalidate that historical authorization. Actual source and original
pair/family/fixity/native currentness are still checked on every operative read.

## Exact route interpretation

A zero-hop path represents direct retrieval only when the complete requested and
resolved URI bytes are equal. No unresolved Arweave path is accepted. HTTP redirect
steps use only 301, 302, 303, 307 and 308. Mirror steps explicitly assert identical
retrieved bytes and do not invent an HTTP response. Every nonempty route is ordered,
starts at the actual adopted URI, makes progress and ends at the exact resolved URI.
Query, percent-encoding, fragment and path bytes are retained literally.

An Arweave path step retains the complete manifest bytes, separately admitted object
and original receipt pair. Keccak, SHA-256 and full size must agree; the endowed
transaction must match the path root. The chosen path-to-target interpretation is
an attributed signed claim, not a JSON parser or native transaction-ID-as-digest
claim. A final `ar://` transaction must match the final object's endowed receipt.
Full source/object/coverage/route/writer/time/nonce/deadline values enter the digest.

## Currentness, revocation and consumer boundary

`record` and `encoded` are historical. `requireCurrent` returns the authenticated
receipt and original full Archive admission; `requireCorrespondence` shares the
same body and additionally returns the complete authenticated source projection.
Neither creates authority or caches currentness.

Only the original record writer may revoke it, with a nonzero reason. The immutable
source scope saved at publication chooses the scope-keyed revocation epoch; callers
cannot supply alternative revoke coordinates. History remains readable. A consumer
must combine that scope epoch with its original Archive environment, then reread the
exact witness/source/pair during cover, refresh, full-current and media review. This
epoch covers revocation only; it is not an output, Artist, policy or source mutation
epoch. Unrelated scopes do not invalidate one another.

The companion-enabled inventory uses the distinct draft profile
`6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1`. Its constructor retains
the original Dependencies tuple plus the satellite address/runtime. The original
dependency hash is unchanged; the immutable companion is authenticated by the
selected inventory runtime and explicit capability/configuration joins. Original
inventory profiles cannot advertise this interpretation by inference.

`coverRetrievalNext` records an explicit item-index-to-witness association and folds
the retained witness identity into the original full admission commitment. Cover,
refresh, full-current and media review share the same correspondence reader.
Raw-CID, absent and exact-locator rows keep their bytes; an explicit fresh witness
may also serve an ordinary HTTPS locator row when it really redirects or mirrors.
Generic `coverNext` continues to require original exact-locator correspondence.
Neither path changes generic Archive admission. A refresh interrupted by same-scope
revocation cannot complete under its earlier epoch; another scope does not disturb it.

## Evidence and limits

The original producer source and seven codec plus fourteen actual Archive/Store test
bodies were independently reviewed at ABI96. A later coupled-consumer review found
the foreign-Artist scope-epoch issue described above. The complete successor at
ABI103 has a separate independent source review covering all producer and consumer
paths plus 34 authored bodies: seven codec, sixteen producer and eleven Bundle
cases. The older capture remains qualified and does not cover the Artist repair.

These cases use original signed Archive receipts, native/fixity proofs, threshold
Safes, actual Store carriers, the actual satellite and Bundle state machine. They
cover full literal receipt/event domains, fresh signature/nonce refusal, missing
carrier rollback, Artist/runtime/chain drift, family/fixity restoration, historical
deadline semantics, direct origin and complete separately archived 9KB Arweave
manifest bytes, same-scope and cross-scope revocation, partial cover/refresh, and a
true final-segment rollback followed by identical retry. Checkpoint/Router and
inventory authority are explicitly typed, not an actual Artist/op17 ceremony. The
codec closed-kind test uses a valid-width unsupported kind, not malformed ABI upper
bits. Two additional SourceSelection cases and the existing typed fixtures check
the new closed companion configuration without inventing operative evidence.

A selected native size pass on the exact reviewed ABI103 source emitted fourteen
products from 287 source files with zero compiler errors. All templates fit the
24,576-byte runtime and 49,152-byte creation limits, including the static constructor
arguments. Witness runtime is 12,346 bytes, inventory 16,963 and Bundle 21,843.
The capture authenticates source/settings/metadata and compiler-declared links; it
is not a deployed linked graph or test execution. No retrieval EVM tests, cold gas,
full Artist/Router/finality ceremony or transaction-cap acceptance are claimed.
Original complete source reobservation and the separate maximum-scope freshness
and capacity work remain required.
