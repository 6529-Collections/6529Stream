"""Synthetic RPC originals for multiple native Artist publications.

This builder creates the complete response map before any capture. The unchanged
Metadata and Artist readers perform all admission. It is not chain execution,
signature execution, or proof of human independence. Payload callbacks run during
construction, after earlier original receipts and op24 archives are sealed.
"""
from copy import deepcopy

from . import artist_attestation_source as artist
from . import metadata_catalog_source as metadata
from .account_profile import ASSERTION_SCHEMA_BYTES, JCS_ID, account_iri
from .canonical import dumps, hex_bytes, keccak256, record_chain, schema_id, subject_id
from .chain_abi import Array, encode
from .independent_wire import DOCUMENT, DOCUMENT_SPEC, RAW_BYTES, RAW_DEFINITION, json_values, require
from .native_attribution_semantics import selector
from .schemas import NAMES
from .test_artist_attestation_source import Fixture as RawArtistFixture
from .test_metadata_catalog_source import A, H, Transport
from .test_schema_inventory import assertion_document


class NativeArtistReviewFixture(RawArtistFixture):
    """One to three complete op24 publications, plus an earlier documentary row.

    ``publications`` contains dicts with optional payload (bytes or a callable),
    schemaId/schemaHash/canonicalizationId/canonicalizationHash, signer,
    artistIndex (0 or 1), relayed, delegated, and uri. A payload callback receives
    a copied context with ``documentary``, ``previous`` (sealed originals,
    selectors and nativeAuthority), ``scope``, signer/artistId and index.

    Defaults are two documents under NativeArtistReviewProfile. An explicit
    old NativeAttributionProfile remains available for raw compatibility tests.
    ``mode`` is distinct_artist,
    same_artist (rotated signer), or same_signer (distinct native identities).
    Arbitrary schema inputs remain subject to the real native schema gate.
    """

    def __init__(self, publications=None, *, mode="distinct_artist", profile=None,
                 relayed=False, delegated=False):
        require(mode in ("distinct_artist", "same_artist", "same_signer"), "fixture artist mode")
        specs = [{}, {}] if publications is None else list(publications)
        require(1 <= len(specs) <= 3 and all(type(s) is dict for s in specs), "fixture publication bound")
        allowed = {"payload", "schemaId", "schemaHash", "canonicalizationId", "canonicalizationHash",
                   "signer", "artistIndex", "relayed", "delegated", "uri"}
        require(all(set(s) <= allowed for s in specs), "fixture publication fields")
        super().__init__(empty=True)
        if profile is None:
            from .native_artist_review_profile import NativeArtistReviewProfile
            profile = NativeArtistReviewProfile()
        self.semantic_profile = profile
        self.document_rows, self.chunk_pointers = {}, {}
        self.publications, self.identities_by_index = [], {}
        self._payload_pointers = {}
        self.subject = subject_id("collection", "31337", A(2), "7")
        self.source_scope = {key: self.anchor[key] for key in ("chainId", "core", "collectionId", "artistRegistry", "host")}
        self.host_code = keccak256(b"\x60\x01")
        self._register_identity(0, A(8), 1)
        if mode != "same_artist" or any(s.get("artistIndex") == 1 for s in specs):
            self._register_identity(1, A(14), 2)
        self._documentary()
        for index, supplied in enumerate(specs):
            spec = dict(supplied)
            identity_index = spec.get("artistIndex", 0 if index == 0 or mode == "same_artist" else 1)
            require(identity_index in self.identities_by_index, "fixture original identity missing")
            use_delegate = spec.get("delegated", delegated and index > 0)
            signer = spec.get("signer", A(8) if index == 0 or mode == "same_signer" else A(15) if use_delegate else A(14))
            identity = self.identities_by_index[identity_index]
            authority_account = identity["registrationAuthority"] if use_delegate else signer
            binding = (identity["artistId"], authority_account, identity["documentHash"],
                       H("review-binding-" + str(index)), index + 1, 1, 0, 0, A(9), True)
            context = {"index": index, "signer": signer, "artistId": identity["artistId"],
                       "scope": deepcopy(self.source_scope), "subjectId": self.subject,
                       "binding": json_values(binding), "documentary": deepcopy(self.documentary),
                       "previous": deepcopy(self.publications)}
            payload = spec.get("payload")
            payload = self.default_payload(context) if payload is None else payload(context) if callable(payload) else payload
            require(type(payload) is bytes, "fixture payload bytes")
            spec.update(relayed=spec.get("relayed", relayed), delegated=use_delegate)
            self._publication(index, spec, payload, signer, binding)
            identity["currentAuthority"] = authority_account
        self._catalogue()
        self._current()
        self.install_profile(self.semantic_profile)

    def default_payload(self, context):
        value = assertion_document()
        original = context["documentary"]
        value.update(profileSchemaId=schema_id(NAMES[0]), profileHash=self.semantic_profile.profile_hash,
                     anchorSubject={"kind": "collection", "subjectId": self.subject},
                     sourceRecords=[selector(original, A(1))])
        value["assertions"][0].update(id="urn:fixture:artist-assertion:" + str(context["index"]),
            assertingAgent=account_iri("31337", context["signer"]), evidence=[{
                "source": {"algorithm": "1", "digest": keccak256(hex_bytes(original["payloadHex"])),
                           "canonicalizationId": RAW_BYTES},
                "selectorType": "json_pointer", "selector": "/statement", "basis": "documentary_evidence"}])
        return dumps(value)

    def _register_identity(self, index, authority, block):
        raw = dumps({"displayName": "Synthetic Artist " + str(index), "subject": "artist"})
        digest = keccak256(raw)
        identity = artist._hash(("bytes32", "uint256", "address", "address", "bytes32", "uint256"),
            (schema_id("6529STREAM_ARTIST_ID_V1"), 31337, A(5), authority, digest, index))
        uri = "ipfs://synthetic-identity-" + str(index)
        event = self.log(block, A(42), [artist.REGISTERED, identity, self.topic("address", authority)],
            encode(("uint16", "bytes32", "string", "uint256"), (1, digest, uri, index)))
        self.identities_by_index[index] = {"artistId": identity, "documentHash": digest, "bytes": raw,
            "uri": uri, "registrationAuthority": authority, "currentAuthority": authority,
            "registeredAt": int(self.blocks[block]["timestamp"], 16), "event": event}

    def _original(self, row, pointer):
        digest, record, receipt, raw = row
        return {"recordHash": digest, "record": json_values(record), "receipt": json_values(receipt),
            "subjectId": record[1], "subjectKind": "collection", "payloadHex": "0x" + raw.hex(),
            "payloadPointer": pointer, "authority": {"mode": "historical_native_metadata_receipt",
                "authorizationClass": str(receipt[2]), "recorder": receipt[1],
                "artistAuthorization": receipt[8], "currentPermissionsRevalidated": False}}

    def _documentary(self):
        raw = dumps({"statement": "Earlier original documentary evidence for both synthetic accounts"})
        record = (metadata.WORK, self.subject, (1, hex_bytes(keccak256(raw)), RAW_BYTES), "ipfs://review-documentary",
            schema_id("STREAM_WORK_DESCRIPTION_V1"), artist.ZERO, (0, b"", artist.ZERO), 92)
        digest = metadata.generic_hash(31337, A(1), A(2), 7, A(20), record)
        receipt = (7, A(20), 3, 92, 0, record_chain("31337", A(1), "7", record[0], artist.ZERO, digest, "0"),
            H("documentary-schema"), keccak256(RAW_DEFINITION), artist.ZERO)
        row = (digest, record, receipt, raw)
        self.rows.append(row)
        pointer = self._payload_pointers.setdefault(keccak256(raw), A(100 + len(self._payload_pointers)))
        self.documentary = self._original(row, pointer)
        self.log(2, A(1), [artist.METADATA_RECORDED, self.topic("uint256", 7), record[0], record[1]],
            encode((metadata.RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"),
                   (record, digest, receipt[5], receipt[1], self.topic("uint8", 3), 1)))

    def _publication(self, index, spec, raw, signer, binding):
        op_block, pub_block = 3 + index * 2, 4 + index * 2
        signed_at, recorded_at = (int(self.blocks[b]["timestamp"], 16) for b in (op_block, pub_block))
        rt = schema_id("ARTIST_SEMANTIC_ASSERTION")
        record = (rt, self.subject, (1, hex_bytes(keccak256(raw)), spec.get("canonicalizationId", JCS_ID)),
            spec.get("uri", "ipfs://review-publication-" + str(index)),
            spec.get("schemaId", schema_id(NAMES[1])), artist.ZERO, (0, b"", artist.ZERO), signed_at)
        digest = metadata.generic_hash(31337, A(1), A(2), 7, signer, record)
        previous = self.publications[-1]["original"]["receipt"][5] if self.publications else artist.ZERO
        chain = record_chain("31337", A(1), "7", rt, previous, digest, str(index))
        publication = (A(1), signer, 7, record[1], rt, record[4], record[2][2], 1, keccak256(raw),
                       keccak256(record[3].encode()), record[7], digest)
        statement = encode(("uint16", artist.PUBLICATION), (1, publication))
        terms = (7, 8, record[1], artist.ZERO, artist.PUBLICATION_SCHEMA, keccak256(statement), record[3])
        nonce, authority_class = 17 + index, 2 if spec["delegated"] else 1
        authorization = keccak256(artist.attestation_preimage(31337, A(5), A(2), terms, binding[0], signer,
                                                            authority_class, nonce, signed_at))
        receipt = (7, signer, 1, recorded_at, index, chain, spec.get("schemaHash", keccak256(ASSERTION_SCHEMA_BYTES)),
                   spec.get("canonicalizationHash", keccak256(self.semantic_profile.documents["RFC8785_JCS"][1])), authorization)
        row = (digest, record, receipt, raw)
        self.rows.append(row)
        self.call("consumedArtistAuthorization(bytes32)", ("bool",), (True,), ("bytes32",), (authorization,))
        evidence = (authorization, binding[0], binding[3], binding[4], signer, authority_class, 1, signed_at,
                    artist._hash((artist.PUBLICATION,), (publication,)))
        attestation = (authorization, terms[3], terms[4], terms[5], binding[4], signed_at, signer)
        self.call("publicationAttestation(bytes32)", (artist.PUBLICATION_RECORD,), ((publication, evidence, self.host_code),),
                  ("bytes32",), (authorization,), target=A(44))
        self.call("attestationRecord(bytes32)", (artist.ATTESTATION_RECORD,), (attestation,),
                  ("bytes32",), (authorization,), target=A(44))
        self.call("statementBytes(bytes32)", ("bytes",), (statement,), ("bytes32",), (terms[5],), target=A(44))
        signature = (b"synthetic-original-signature-" + str(index).encode()) if spec["relayed"] else b""
        actor = A(70 + index) if spec["relayed"] else signer
        self.call("signatureBundle(bytes32)", ("bytes",), (signature,), ("bytes32",), (authorization,), target=A(42))
        self.call("attestationAuthorityClass(bytes32)", ("uint8",), (authority_class,),
                  ("bytes32",), (authorization,), target=A(44))
        attested = self.log(op_block, A(44), [artist.ATTESTED, self.topic("uint256", 7),
            self.topic("uint8", 8), self.topic("address", signer)], encode(
                ("uint16", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint8", "uint256", "uint64", "bytes32"),
                (1, *terms[2:6], publication[9], authority_class, nonce, signed_at, authorization)))
        effective = (nonce, signed_at, signature)
        submitted = (nonce, signed_at if spec["relayed"] else 0, signature)
        _, _, signed_digest = artist.signed_preimage(31337, A(5), A(2), terms, nonce, signed_at)
        proof = (signer, signed_digest, not spec["relayed"])
        authority = (binding[0], binding[1], 1, 1)
        grant = artist.ZERO
        delegation = ((artist.ZERO, artist.ZERO_ADDRESS, 0, 0, 0, 0, 0, artist.ZERO),
                      artist.ZERO_ADDRESS, 0, 0, False, artist.ZERO)
        if spec["delegated"]:
            grant_terms = (binding[0], signer, 7, 1, 92, 200, 5, H("review-grant-" + str(index)))
            delegation = (grant_terms, binding[1], 30 + index, 0, False, artist.ZERO)
            grant = artist._hash(("bytes32", "uint256", "address", *artist.GRANT, "uint256"),
                (schema_id("6529STREAM_ARTIST_DELEGATION_RECORD_V1"), 31337, A(5), *grant_terms, 30 + index))
            self.log(2, A(42), [artist.GRANTED, binding[0], self.topic("address", signer), self.topic("uint256", 7)],
                encode(("uint16", "uint32", "uint64", "uint64", "uint64", "bytes32", "uint256", "bytes32"),
                       (1, *grant_terms[3:], 30 + index, grant)))
            self.log(op_block, A(44), [artist.DELEGATED, authorization, grant, binding[0]],
                     encode(("uint16", "address"), (1, signer)))
            self.call("delegationRecord(bytes32)", (artist.DELEGATION,), ((*delegation[:3], 1, True, H("later-revocation")),),
                      ("bytes32",), (grant,), target=A(42))
            self.call("delegatedNonceState(bytes32,address,uint256)", ("bool", "uint256"), (True, nonce + 1),
                      ("bytes32", "address", "uint256"), (binding[0], signer, nonce), target=A(42))
        else:
            self.call("nonceUsed(bytes32,uint256)", ("bool",), (True,), ("bytes32", "uint256"), (binding[0], nonce), target=A(42))
        fact = (A(1), self.host_code, terms[2], terms[3])
        association = (binding[0], binding[3], binding[4], grant, fact)
        self.call("attestationAssociation(bytes32)", (artist.ASSOCIATION,), (association,), ("bytes32",), (authorization,), target=A(44))
        admission = (authority, signer, nonce, signed_at, grant, artist.ZERO, fact)
        payload = encode(artist.AUTHENTICATED_PAYLOAD, (binding, terms, submitted, effective, proof, statement,
            (0, 0, artist.ZERO, artist.ZERO_ADDRESS), False, admission, delegation,
            encode((artist.PUBLICATION, "bytes32"), (publication, self.host_code))))
        before = tuple((artist.DOMAINS[i], 2 * index + 1, H(f"before-state-{index}-{i}"), H(f"before-record-{index}-{i}"))
                       if i in (0, 1, 2, 4) else (artist.ZERO, 0, artist.ZERO, artist.ZERO) for i in range(7))
        after = tuple((artist.DOMAINS[i], 2 * index + 2, H(f"after-state-{index}-{i}"), H(f"after-record-{index}-{i}"))
                      if i in (2, 4) else before[i] for i in range(7))
        archive_id = artist._hash(("bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"),
            (schema_id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), 31337, A(5), self.coordinator, 24, actor, authorization))
        archive_raw = encode(artist.ARCHIVE, (1, self.configuration, 24, actor, authorization, before, after, payload))
        pointer = A(90 + index)
        archive_event = self.log(op_block, self.archive, [artist.ARCHIVED, archive_id, self.topic("uint64", 1), keccak256(archive_raw)],
                                 encode(("address", "uint256"), (pointer, len(archive_raw))))
        published = self.log(pub_block, A(1), [artist.METADATA_RECORDED, self.topic("uint256", 7), rt, record[1]],
            encode((metadata.RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16"),
                   (record, digest, chain, signer, self.topic("uint8", 1), 1)))
        consumed = self.log(pub_block, A(1), [artist.CONSUMED, authorization, digest, self.topic("address", signer)],
                            encode(("address",), (A(13),)))
        self.call("bindingAt(uint256,uint64)", (artist.BINDING,), (binding,), ("uint256", "uint64"), (7, index + 1), target=A(40))
        pointer = self._payload_pointers.setdefault(keccak256(raw), A(100 + len(self._payload_pointers)))
        original = self._original(row, pointer)
        native_authority = {"artistId": binding[0], "signer": signer, "authorityClass": str(authority_class),
            "bindingHash": binding[3], "bindingGeneration": str(binding[4]), "attestationRecordHash": authorization,
            "operationEvidenceId": archive_id, "operationEvidenceHash": keccak256(archive_raw), "actor": actor, "grantRecordHash": grant}
        entry = {"original": original, "selector": selector(original, A(1)), "nativeAuthority": native_authority,
            "binding": binding, "attestation": attestation, "terms": terms, "publication": publication,
            "evidence": evidence, "association": association, "archiveId": archive_id, "archiveRaw": archive_raw,
            "archivePointer": A(90 + index), "archiveEvent": archive_event, "opBlock": op_block, "payload": payload,
            "before": before, "after": after, "actor": actor, "attested": attested,
            "published": published, "consumed": consumed, "signature": signature}
        self.publications.append(entry)
        self.reseal_archive(index, archive_raw)

    def reseal_archive(self, index, raw):
        """Coherently change only archive carrier commitments for refusal controls."""
        entry = self.publications[index]
        entry["archiveRaw"] = raw
        entry["archiveEvent"]["topics"][3] = keccak256(raw)
        entry["archiveEvent"]["data"] = "0x" + encode(("address", "uint256"), (entry["archivePointer"], len(raw))).hex()
        self.call("artistEvidenceBytesV2(bytes32,uint64)", ("bytes",), (raw,),
                  ("bytes32", "uint64"), (entry["archiveId"], 1), target=self.archive)
        self.call("artistEvidenceMetadataV2(bytes32,uint64)", ("bytes32", "address", "uint32", "uint64"),
                  (keccak256(raw), entry["archivePointer"], len(raw), entry["opBlock"]),
                  ("bytes32", "uint64"), (entry["archiveId"], 1), target=self.archive)
        self.put("eth_getCode", [entry["archivePointer"], self.block_ref], "0x00" + raw.hex())

    def _catalogue(self):
        self.policies[schema_id("ARTIST_SEMANTIC_ASSERTION")] = (metadata.ARTIST, 1 << 1, True)
        self.call("recordTypeCount()", ("uint256",), (len(self.policies),))
        for number, (rt, policy) in enumerate(self.policies.items()):
            self.call("recordTypeAt(uint256)", ("bytes32",), (rt,), ("uint256",), (number,))
            self.call("recordPolicy(bytes32)", (metadata.POLICY,), (policy,), ("bytes32",), (rt,))
            lane = [r for r in self.rows if r[1][0] == rt]
            self.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                      (lane[-1][2][5] if lane else artist.ZERO, len(lane)), ("uint256", "bytes32"), (7, rt))
            latest = {(row[1][1], row[2][1]): row[0] for row in lane}
            for (subject, signer), digest in latest.items():
                self.call("latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)", ("bytes32",), (digest,),
                          ("uint256", "bytes32", "bytes32", "address"), (7, rt, subject, signer))
        self.pointers = {}
        for row in self.rows:
            digest, record, receipt, raw = row
            content = keccak256(raw)
            pointer = self._payload_pointers[content]
            self.record_response(row)
            self.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
                      ("uint256", "bytes32", "uint256"), (7, record[0], receipt[4]))
            self.call("recordPayload(bytes32)", ("address", "bytes"), (pointer, raw), ("bytes32",), (digest,))
            self.call("chunk(bytes32)", ("address", "uint32"), (pointer, len(raw)), ("bytes32",), (content,), target=A(4))
            self.put("eth_getCode", [pointer, self.block_ref], "0x00" + raw.hex())
            self.pointers[(self.policies[record[0]][0], content)] = pointer
        self.call("payloadPointerCount(uint256)", ("uint256",), (len(self.pointers),), ("uint256",), (7,))
        for index, ((family, content), pointer) in enumerate(self.pointers.items()):
            self.call("payloadPointerAt(uint256,uint256)", ("address", "bytes32", "bytes32"),
                      (pointer, family, content), ("uint256", "uint256"), (7, index))

    def _current(self):
        latest = self.publications[-1]
        self.call("binding(uint256)", (artist.BINDING,), (latest["binding"],), ("uint256",), (7,), target=A(40))
        self.call("attributionState(uint256)", ("uint8", "uint64"), (2, len(self.publications)), ("uint256",), (7,), target=A(44))
        self.call("attestation(uint256,uint8,bytes32)", (artist.ATTESTATION_RECORD,), (latest["attestation"],),
                  ("uint256", "uint8", "bytes32"), latest["terms"][:3], target=A(44))
        self.call("artistAttestationStatus(uint256,uint8,bytes32,bytes32)", ("uint8", "bytes32", "bytes32", "uint8", "uint64"),
            (1, latest["attestation"][0], latest["terms"][3], int(latest["nativeAuthority"]["authorityClass"]), latest["attestation"][5]),
            ("uint256", "uint8", "bytes32", "bytes32"), (*latest["terms"][:3], latest["terms"][3]), target=A(44))
        for identity in self.identities_by_index.values():
            aid, digest, raw = identity["artistId"], identity["documentHash"], identity["bytes"]
            current = (identity["currentAuthority"], 1, 1, identity["registeredAt"], 110,
                       digest, identity["uri"], "Synthetic Artist identity", 30)
            self.call("identity(bytes32)", (artist.IDENTITY,), (current,), ("bytes32",), (aid,), target=A(42))
            self.call("authorityState(bytes32)", ("address", "uint8", "uint8", "bytes32"), (*current[:3], digest),
                      ("bytes32",), (aid,), target=A(42))
            self.call("operativeIdentityRecord(bytes32)", ("bytes32",), (digest,), ("bytes32",), (aid,), target=A(42))
            self.call("identityRecordBytes(bytes32)", ("bytes",), (raw,), ("bytes32",), (aid,), target=A(42))
            self.call("identityDocumentBytes(bytes32)", ("bytes",), (raw,), ("bytes32",), (digest,), target=A(42))
            empty = (artist.ZERO, (artist.ZERO, 0, artist.ZERO, artist.ZERO_ADDRESS, artist.ZERO, artist.ZERO, 0,
                artist.ZERO_ADDRESS, 0, 0, artist.ZERO, artist.ZERO, artist.ZERO, artist.ZERO, artist.ZERO))
            self.call("currentIdentityContestCause(bytes32)", (artist.CAUSE,), (empty,), ("bytes32",), (aid,), target=A(42))

    def install_document(self, name, kind, raw, *, status=0, canonical=None, predecessor=artist.ZERO):
        pieces = [raw[i:i + 8192] for i in range(0, len(raw), 8192)]
        hashes = tuple(keccak256(piece) for piece in pieces)
        for digest, piece in zip(hashes, pieces):
            pointer = self.chunk_pointers.setdefault(digest, A(1000 + len(self.chunk_pointers)))
            self.call("chunk(bytes32)", ("address", "uint32"), (pointer, len(piece)), ("bytes32",), (digest,), target=A(4))
            self.put("eth_getCode", [pointer, self.block_ref], "0x00" + piece.hex())
        canon = canonical or (RAW_BYTES if name in ("RAW_BYTES", "RFC8785_JCS") else JCS_ID)
        spec = (name, kind, keccak256(raw), canon, predecessor, "", len(raw))
        declaration = keccak256(encode((DOCUMENT_SPEC, Array("bytes32")), (spec, hashes)))
        row = (True, status, declaration, spec, hashes)
        self.document_rows[name] = row
        self.call("document(bytes32)", (DOCUMENT,), (row,), ("bytes32",), (schema_id(name),), target=A(3))

    def install_profile(self, profile):
        for name, (kind, raw) in {"RAW_BYTES": (1, RAW_DEFINITION), **profile.documents}.items():
            self.install_document(name, kind, raw,
                canonical=getattr(profile, "document_canonicalizations", {}).get(name),
                predecessor=getattr(profile, "document_predecessors", {}).get(name, artist.ZERO))

    def semantic(self, *, profile=None):
        """Lazy new adapter import: raw fixture never patches its acceptance rules."""
        from .native_artist_review_source import NativeArtistReviewSource
        return NativeArtistReviewSource(self.overlay(), Transport(self.responses), profile=profile or self.semantic_profile)
