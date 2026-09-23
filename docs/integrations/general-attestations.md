# Additive general attestations

`StreamGeneralAttestations` supplies the general attestation and typed identity
notarization surface from [CMC](../collection-metadata-contract.md). It is a new
companion with its own interface, domain, nonces and receipt history. Existing
`StreamCollectionAttestations` independent class-5 ABI, domain and record semantics
are unchanged. The implementation remains pre-audit; source and focused compiler
checks do not establish deployment or runtime readiness.

## Deployment and discovery

The constructor `Configuration` takes `core`, `schemas`, `metadata`,
`artistRegistry`, `artistAttribution`, `executor`, `deploymentManifestHash`,
`manifestURI`, `manifestHash`, `signatureGas` and `dependencyReadGas`.
Deploy from the exact retained compiler export and its library links.

The module type is `keccak256("GENERAL_ATTESTATIONS")`; its version is
`keccak256("6529stream.general-attestations.v2")`. Discover its dedicated
`IStreamGeneralAttestations` and additive
`IStreamGeneralAttestationPayloadChunks` interfaces through ERC-165. The original
general interface, signed request and EIP-712 domain version remain unchanged.
Do not route its calls to
the older independent host. Coordinated genesis registration and genuine capture
must retain the actual address, constructor values, linked products, compiler
settings and runtime hashes.

The host pins the Core, schema registry, schema chunk store, Metadata authority,
Artist registry and Attribution owner runtimes. Constructor reads validate the
Artist coordinator suite and reciprocal owner links. Governance executor and
schema authority must agree. Signature verification uses the existing
`6529STREAM_GGP_METADATA_ERC1271_VERIFY_GAS` parameter with a 90,000 gas floor;
dependency reads use `6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS`. Both use the
fail-closed parent precheck. Relevant external reads are bounded and checked
against their expected ABI return shape.

## Authority classes

| Type | Entry point | Authority |
| --- | --- | --- |
| `INSTITUTIONAL_VERIFICATION`, `ESTATE_VERIFICATION` | `recordSignedAttestation` | Exact EIP-712/ECDSA or ERC-1271 signature in the attester account's own name |
| `ARTIST_STATEMENT` | `recordArtistStatement` | The same new general signature plus exact original native Artist evidence |
| `CURATORIAL_STATEMENT` | `recordOperatorAttestation` | Actual caller's selected Metadata `familyWriter(collectionId, CURATOR, 3, caller)` grant |
| Typed institution/estate identity statement | `recordIdentityNotarization` | Signed request, exact typed JSON and definitions, selected registry's operative identity at publication |

All signed entry points require a signature even when caller equals attester.
There is no DIRECT-signature bypass. A cryptographically authorized institutional
or estate account is not automatically a verified institution or legal person.
An ERC-1271 wallet may approve empty signature bytes; the verifier still calls the
wallet and requires its exact valid-signature return value.

Operator authorization uses the exact nonzero collection, fixed CURATOR family
and class 3. It has no collection-zero fallback, caller-chosen class, global admin
or governance bypass. The receipt retains the grant revision, collection and
authenticated recorder separately from the request's asserted attester and DID.
Those asserted values do not become their own signature evidence.

## Exact signed request

Use the compiler-exported `Request` tuple and `attestationDigest` getter. The
EIP-712 domain name is `6529StreamGeneralAttestations`, version `1`, with the actual
chain ID and this host address. The primary type is `StreamGeneralAttestation`;
the exact field order is:

```text
address attester
uint256 collectionId
bytes32 subjectId
bytes32 attestationType
string attesterDID
bytes32 schemaId
bytes32 canonicalizationId
string statementURI
bytes payload
bytes32 supersedes
bytes32 artistAuthorizationRecordHash
uint64 effectiveAt
uint256 nonce
uint64 deadline
```

Every field is committed. Nonces are consumed per authenticated recorder; signed
records use the attester as recorder. Operator records use the actual caller.
`revokeAttesterNonce` revokes the caller's nonce. Deadlines are checked at write.
Generic institutional, estate and curatorial payloads are complete state-backed
bytes up to 24,576 bytes. Typed identity notarizations and native Artist statements
retain their separate 8,192-byte bounds. The native Artist bound remains an open
capacity dependency on the original Artist producer; this companion does not
establish 24,576-byte conformance for that route. Signature bytes are bounded to
4,096 and their domain/typed-word envelope to 8,192. Failed late writes
revert the nonce, record, head and pointer changes atomically.

Generic signed, operator and typed-notarization requests use the existing
collection/token/media `Subject` derivation. Native Artist requests use the
original native subject kind and state hash from their retained evidence.
`recordSubject` deliberately rejects that Artist route; read its full
`recordArtistEvidence` instead.

## Native Artist provenance

`ArtistWitness` supplies `subjectKind`, original `nonce` and `nativeReceiptIndex`.
The host reads the pinned Attribution owner's indexed native receipt and requires
operation 24, exact collection, Artist ID and record hash. It checks the original
attestation tuple, association, authority class, statement bytes and historical
signer, and reconstructs the original native record hash, including schema,
subject/state, URI, nonce and signing time. Delegate and successor authority stays
historical; no new address-equals-Artist rule is introduced.

The request's `artistAuthorizationRecordHash` must reference that exact original
record. The new payload, schema, URI, subject and signer must match it. This
general receipt never substitutes for a new native op24 record, a personhood
floor, Artist consent or renderer authority.

## Typed identity notarization

`Notarization` includes `artistId`, `operativeIdentityRecordHash`, `legalPersonRef`,
`instrumentRef`, `officiatingAuthorityIdentityRef` and
`verifyingInstitutionIdentityRef`. Call `notarizationPayload` for its exact
canonical JSON, then sign those same bytes in the request. All six reference hash
forms and bounded UTF-8 content URIs follow the existing owner-reference rules.

The typed route requires the exact registered `STREAM_IDENTITY_NOTARIZATION_V1`
schema, `STREAM_IDENTITY_NOTARIZATION_JSON_PROFILE_V1` catalog and RFC8785
canonicalization definition. Their byte lengths and content hashes are fixed in
`StreamGeneralAttestationDefinitions`; candidate files are under
`schemas/records`. `tools.metadata.identity_notarization_profile` validates the
same closed JSON and exact Artist/operative identity context offline.
These three registry documents themselves use `RAW_BYTES` canonicalization and
zero `supersedesId`; the signed notarization payload uses `RFC8785_JCS`.

Publication checks the selected Artist registry and its actual operative identity
record. The receipt retains that registry/code hash and original identity hash.
Later identity rotation or dispute does not overwrite this history or turn it
into present-day identity verification. Generic entry points cannot use this
schema to bypass the typed checks.

## Append-only reading

`supersedes` must equal the latest record for the exact collection/type/subject/
recorder lane. Replacements leave original records, payloads, signatures and
Artist proof readable. `recordChainHash` and `recordHashAt` enumerate every type's
history; `payloadPointerCount/At` enumerate deduplicated payload and signature
carriers. Full state-backed bytes, not event-only attestations, remain available.

`recordPayload(recordHash)` returns the complete payload for every accepted
record. Its pointer is the single carrier for payloads through 8,192 bytes and
the **first chunk only** for larger payloads. The first chunk's bytecode alone
does not commit to the full larger payload. `Attestation.statementHash` continues
to commit to the complete bytes in the unchanged record and signature preimages.

`recordPayloadInfo(recordHash)` returns the complete content hash, byte length
and chunk count. `recordPayloadChunkAt(recordHash, index)` returns each ordered
chunk hash, pointer and length. Chunks contain 8,192 bytes except the final chunk;
at most three chunks carry one generic payload. Repeated chunks retain every
ordered position even when the collection pointer inventory deduplicates their
`(family, chunkHash)` entries. That inventory contains real chunk hashes, never a
first pointer mislabeled with a larger payload's full hash. Retaining or preparing
bytes does not confer attestation authority. Historical reads reconstruct the
accepted immutable carriers without consulting current authority or schema status.

The [Museum attribution adapter](../museum-native-attribution.md) checks the
original receipt and complete lane/pointer history offline. Historical acceptance
comes from admitted runtime/source provenance and stored evidence; replay does not
ask the current wallet to approve an old signature or infer legal identity.
