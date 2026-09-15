# Independent preservation records

`StreamCollectionAttestations` implements the dedicated
[CMC-INDEPENDENT-ATTESTOR](../collection-metadata-contract.md#independent-preservation-lane-cmc-independent-attestor)
lane. Focused tests use the actual SchemaRegistry, DocumentStore, threshold
Safe and sealed Governance Executor. Their Core membership boundary is an
explicit test double; actual current-Core and renderer composition is separate.

The eight specified `INDEPENDENT_*` record types are built in. Entry needs no
family registration, operator grant, current satellite selection, artist
consent, collection unlock, unfrozen state or live governance. An attestor may
write directly in their own name, or authorize a relayer with the permanent
`StreamIndependentPreservationRecord` EIP-712 type. The domain is
`6529StreamCollectionAttestations`, version `1`, current chain ID and this host.
ERC-5267 describes exactly that domain. A direct call has an empty signature;
an external caller needs a valid named-attestor signature.

Every successful write consumes exactly its unordered `(attestor, nonce)`
value. Zero and the largest uint256 are ordinary nonce values. Direct or
relayed `StreamIndependentPreservationRevocation` consumes the same map, with
the independently pinned revocation type. A deadline is inclusive. A used
nonce rejects either operation; revocation does not delete or invalidate an
already recorded assertion. Later assertions carry corrections or disputes.

The signed thirteen fields retain their permanent order and widths. Dynamic
digest, URI and payload fields are hashed separately for EIP-712. The generic
record hash uses the existing fourteen-word preservation preimage, with this
host, the actual attestor and the exact signature-bundle commitment. Its chain
uses the pinned `STREAM_RECORD_CHAIN_V1` preimage and a zero-based index per
`(collectionId, recordType)`. History and latest reads remain attestor-attributed.

`collectionRecordPayload(scopeKey, recordType, subjectId)` selects the calling
address's latest assertion. Third-party readers first call
`latestCollectionRecordHashFor(scopeKey, recordType, subjectId, attestor)`, then
`recordPayload(recordHash)`. `recordSubject(recordHash)` returns the retained
subject witness. There is no global latest assertion that replaces another
attestor's record.

The subject witness is independently recomputed against the signed subject and
scope key. Collection ID zero uses the reserved deployment collection subject.
Other collections must exist in the immutable Core. Token witnesses require
that Core's permanent collection mapping and lifecycle agree on MINTED or
BURNED. Media witnesses bind the exact collection and `PreservationObjectRef`
object ID. There is no current typed object registry, so the object reference
is the attestor's declaration, not a claim of registered-object membership.
Historical reads use local retained facts and never ask Core for current
ownership, pointers, locks or membership.

Schema and canonicalization IDs resolve the actual immutable SchemaRegistry
documents with the appropriate kind. Their exact definition hashes are saved
with each receipt. ACTIVE, DEPRECATED and ARCHIVED definitions are all usable;
retirement cannot turn off an independent history. This initial profile
requires an existing interpretation document but has no live status or
governance gate. Payload meaning, schema conformance and the identity claims
inside a payload remain interpretation concerns; registered bytes are not
operator endorsement of that payload.

The initial limits are 8,192 payload bytes, 2,048 URI bytes and 4,096 signature
bytes. This chooses a finite profile below the recommended 24,576-byte record
maximum, matching the actual shared `StreamSchemaDocumentStore`. The entire
payload is retained with its exact Keccak-256 digest. A second immutable blob
retains `abi.encode(domainSeparator, bytes32[14] signingWords, signature)`.
Those are the canonical EIP-712 encoded words, including all three dynamic
field hashes; the full URI, digest and original payload are separately
recoverable from the record and payload reads. Receipts preserve nonce,
deadline and the original full authorization digest. Direct records retain
the same bundle with no signature and an explicit `DIRECT` scheme.

Both payload and verification bundle enter the host's enumerable pointer
registry only after a successful attestor-authorized write. Permissionless
store uploads alone are not records. Whole-byte reads validate the saved
pointer's bounded code and content hash directly, so history reads do not
depend on live governance, interpretation status or the store's read endpoint.

The host's `METADATA_ERC1271_VERIFY_GAS` row has the normative 90,000 floor and
`FAIL_CLOSED_PRECHECK` failure direction. Its configured genesis value and
supported Safe class must be measured before deployment. Existing Governance
V2 class-1 delayed, monotonic, at-most-2x raises are inherited unchanged.
An optional zero governance authority fixes these values permanently. The
separate dependency-read row bounds Core and document reads. Each call checks
parent gas after constructing its input and reserves bounded returndata.
Neither row grants record authority. All record/nonce mutations share a
reentrancy guard; signature and definition failure precedes nonce consumption.

This host exposes no tokenURI, renderer, ownership, transfer, mint, royalty or
finality mutation. It neither calls nor supplies a default renderer read set.
Current-Core renderer isolation, the broader supported-wallet gas sweep and
the eventual authenticated Museum source adapter remain explicit integration
checks. Focused tests cover actual Safe direct and relayed operations, all 48
host reads, and actual delayed Executor raises and wrong-class rejection.
General artist/curator/estate attestations and the OWNER/SNAPSHOT hosts remain
separate deliverables.
