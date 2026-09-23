"""Synthetic RPC fixtures exercising concrete General source/publication validators.

Saved signature bytes are synthetic. These fixtures are not recorded-chain or
historical signature execution evidence.
"""
from copy import deepcopy
from .account_profile import JCS_ID, account_iri
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import encode
from .general_attestation_source import (CURATORIAL, CURATOR_FAMILY, ESTATE, INSTITUTIONAL,
    EIP712, chain_hash, domain, native_record_hash, signed_words)
from .general_review_profile_v1 import (ASSERTION_NAME, ASSERTION_SCHEMA_BYTES, PROFILE_SCHEMA_NAME,
    GeneralSemanticReviewProfileV1, REVIEW_MAPPING_RULE, REVIEW_RELATION, review_literal)
from .general_publication_v1 import GeneralPublicationAdapterV1, EVENT_DATA, EVENT_TOPIC, GRANT_DATA, GRANT_TOPIC, PROFILE
from .general_semantic_source_v1 import selector
from .general_semantic_source_v2 import GeneralSemanticSourceV2
from .general_semantic_fixture_v1 import OfflineGeneralSemanticFixture
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .test_general_attestation_source import Transport, a, h, decode_words
from .test_general_attestation_source_v2 import Fixture as NativeFixture


class GeneralReviewFixture:
    _install_document = OfflineGeneralSemanticFixture._install_document
    def __init__(self, *, reviewer="curator", disposition="reviewed", origin="human_mapping",
                 target_status="unreviewed", review_status="unreviewed", same_block=False,
                 mutate_target=None, mutate_review=None, mutate_body=None):
        self.profile = GeneralSemanticReviewProfileV1()
        self.general_fixture = f = NativeFixture(generic_payload_bytes=None)
        for name, (kind, raw) in self.profile.documents.items(): self._install_document(name, kind, raw)
        seed = f.rows[0]
        self.target = self._payload(seed, f.rows[1][2][0], origin, target_status)
        if mutate_target: mutate_target(self.target)
        f.rows[1] = self._replace(f.rows[1], self.target)
        target_native = self._native(f.rows[1]); self.target_source = selector(target_native, f.anchor, "/assertions/0")
        self.target_authority = {"principal": self.target["assertions"][0]["assertingAgent"], "collectionId": "7",
            "subjectId": f.rows[1][1][2], "recordType": INSTITUTIONAL, "verificationClass": "SIGNER_VERIFIED",
            "authorityQualification": "GENERAL_SIGNER_CLAIM", "grantRevision": "0"}
        review_base = f.rows[2]
        if reviewer != "curator":
            value, receipt = list(f.rows[1][1]), list(f.rows[1][2])
            value[0], value[3], value[9] = (a(8) if reviewer == "self" else a(15)), ESTATE, ZERO
            receipt[0], receipt[3], receipt[4], receipt[5], receipt[7] = value[0], 103, 0, ZERO, 12
            review_base = (ZERO, tuple(value), tuple(receipt), b"", b"", b"", f.subject())
        self.review = self._payload(f.rows[1], review_base[2][0], "direct_statement", review_status)
        body = {"assertionRecord": deepcopy(self.target_source),
            "assertionRevisionHash": keccak256(dumps(self.target["assertions"][0])), "profileHash": self.profile.profile_hash,
            "mappingRule": self.target["assertions"][0]["mappingRule"], "targetAuthority": deepcopy(self.target_authority),
            "disposition": disposition}
        if mutate_body: mutate_body(body)
        claim = self.review["assertions"][0]
        claim.update(id="urn:synthetic:review", subject=self.target["assertions"][0]["id"],
            relation=REVIEW_RELATION, mappingRule=REVIEW_MAPPING_RULE, object={"literal": review_literal(body)})
        if mutate_review: mutate_review(self.review)
        if same_block:
            receipt = list(review_base[2]); receipt[3] = 102
            review_base = (review_base[0], review_base[1], tuple(receipt), *review_base[3:])
        f.rows[2] = self._replace(review_base, self.review)
        f.install_v2_state()
        self.review_source = selector(self._native(f.rows[2]), f.anchor, "/assertions/0")
        self._publications(same_block)

    def _native(self, row):
        return {"recordHash": row[0], "value": json_values(row[1]), "receipt": json_values(row[2])}

    def _payload(self, previous, recorder, origin, status):
        f = self.general_fixture
        ref = selector(self._native(previous), f.anchor)
        return {"profileSchemaId": schema_id(PROFILE_SCHEMA_NAME), "profileHash": self.profile.profile_hash,
            "anchorSubject": {"kind": "collection", "subjectId": previous[1][2]}, "entities": [],
            "sourceRecords": [ref], "authorityAlignments": [], "assertions": [{"id": "urn:synthetic:mapping",
                "subject": "urn:synthetic:work", "relation": "urn:synthetic:place",
                "object": {"entity": "urn:synthetic:place:A"}, "assertingAgent": account_iri(f.anchor["chainId"], recorder),
                "createdAt": "2026-09-22T00:00:00Z", "evidence": [{"source": {"algorithm": "1", "digest": previous[1][8],
                    "canonicalizationId": previous[1][6]}, "selectorType": "whole_document", "selector": "", "basis": "documentary_evidence"}],
                "origin": origin, "reviewStatus": status, "mappingRule": "urn:synthetic:mapping-rule",
                "rationale": "Synthetic exact-source mapping", "reviewEvidence": [], "corrects": [], "disputes": []}]}

    def _replace(self, old, parsed):
        f = self.general_fixture; value, receipt = list(old[1]), list(old[2]); payload = parsed if type(parsed) is bytes else dumps(parsed)
        value[5], value[6], value[8] = schema_id(ASSERTION_NAME), JCS_ID, keccak256(payload)
        receipt[11:14] = [keccak256(ASSERTION_SCHEMA_BYTES), keccak256(self.profile.documents["RFC8785_JCS"][1]), ZERO]
        receipt[18:24] = [ZERO_ADDRESS, ZERO, ZERO, ZERO, ZERO, 0]
        bundle = b""
        if receipt[1] == 1:
            words = signed_words(tuple(value), payload, receipt)
            bundle = encode(("bytes32", ("bytes32",) * 15, "bytes"), (domain(31337, f.host), decode_words(words), b"s" * 65))
            receipt[6] = keccak256(b"\x19\x01" + hex_bytes(domain(31337, f.host)) + hex_bytes(keccak256(words)))
            receipt[10] = keccak256(bundle)
        receipt[5] = ZERO
        digest = native_record_hash(31337, f.host, tuple(value), tuple(receipt))
        prior = f.rows[0][2][5] if receipt[4] == 1 else ZERO
        receipt[5] = chain_hash(7, value[3], prior, digest, receipt[4])
        return digest, tuple(value), tuple(receipt), payload, bundle, b"", old[6]

    def _publications(self, same_block):
        f = self.general_fixture; blocks = {}; assignment = {}
        for index, row in enumerate(f.rows):
            number = 6 if same_block and index == 2 else 5 + index
            assignment[row[0]] = number
        hashes = {n: f.anchor["blockHash"] if n == 9 else h("publication-block-" + str(n)) for n in range(4, 10)}
        times = {4: 100, 5: 101, 6: 102, 7: 102 if same_block else 103, 8: 104, 9: 112}
        for number in range(4, 10):
            blocks[number] = {"hash": hashes[number], "number": hex(number), "timestamp": hex(times[number]),
                "stateRoot": f.anchor["stateRoot"] if number == 9 else h("publication-state-" + str(number)),
                "parentHash": hashes.get(number - 1, h("older-parent")), "transactions": []}
        hints, grant_hints, installed_grants = [], [], set()
        def receipt(tx, number, address, topics, data):
            block = blocks[number]; tx_index = len(block["transactions"]); block["transactions"].append(tx)
            log_index = tx_index
            log = {"address": address, "topics": topics, "data": "0x" + data.hex(), "removed": False,
                "blockHash": block["hash"], "blockNumber": hex(number), "transactionHash": tx,
                "transactionIndex": hex(tx_index), "logIndex": hex(log_index)}
            result = {"transactionHash": tx, "status": "0x1", "blockHash": block["hash"], "blockNumber": hex(number),
                "transactionIndex": hex(tx_index), "logs": [log]}
            f.put("eth_getTransactionReceipt", [tx], result)
        for index, row in enumerate(f.rows):
            digest, value, saved = row[:3]; tx = h("General-tx-" + str(index))
            receipt(tx, assignment[digest], f.host, [EVENT_TOPIC, "0x" + (7).to_bytes(32, "big").hex(), value[3], value[2]],
                encode(EVENT_DATA, (digest, value[0], saved[1], saved[2], value[9], saved[5], 1)))
            hints.append({"recordHash": digest, "transactionHash": tx})
            if value[3] == CURATORIAL:
                grant_tx = h("original-curator-grant")
                if grant_tx not in installed_grants:
                    receipt(grant_tx, 4, f.metadata, [GRANT_TOPIC, "0x" + (7).to_bytes(32, "big").hex(), CURATOR_FAMILY,
                        "0x" + bytes(12).hex() + saved[0][2:]], encode(GRANT_DATA, (3, True, saved[17], h("governed-grant-action"))))
                    installed_grants.add(grant_tx)
                grant_hints.append({"recordHash": digest, "transactionHash": grant_tx})
        for block in blocks.values(): f.put("eth_getBlockByHash", [block["hash"], False], block)
        self.hints = dumps({"profile": PROFILE, "records": hints, "curatorGrants": grant_hints})

    def append_statement(self, payload, *, scope=None):
        f = self.general_fixture; old = f.rows[2]
        value, receipt = list(old[1]), list(old[2])
        value[9] = old[0]
        receipt[3], receipt[4], receipt[7] = 112, 1, 14
        subject = old[6]
        if scope is not None:
            subject, value[2] = scope
            value[9] = ZERO  # First publication for this distinct native subject.
        new = self._replace((ZERO, tuple(value), tuple(receipt), b"", b"", b"", subject), payload)
        saved = list(new[2]); saved[5] = chain_hash(7, new[1][3], old[2][5], new[0], 1)
        new = (new[0], new[1], tuple(saved), *new[3:])
        f.rows.append(new); f.install_v2_state(); self._publications(False)
        return selector(self._native(new), f.anchor, "/assertions/0")

    def source(self, *, provenance="synthetic_fixture"):
        general = self.general_fixture.reader(provenance=provenance)
        publication = GeneralPublicationAdapterV1(general, self.hints, Transport(self.general_fixture.responses), provenance=provenance)
        return GeneralSemanticSourceV2(general, publication, Transport(self.general_fixture.responses), profile=self.profile)

    def policy(self, source, *, allow_self=False, include_review=True):
        from .general_review_selection import NAME
        snapshot = loads(source.snapshot(), maximum=67108864)
        rows = {r["source"]["recordHash"]: r for r in snapshot["statements"]}
        from .general_semantic_source_v2 import admission
        value = {"profile": NAME, "sourceSnapshotHash": keccak256(source.snapshot()),
            "sourceAuthoritySet": [{"source": self.target_source, "authority": admission(rows[self.target_source["recordHash"]], source.a)}],
            "reviewerAuthoritySet": [{"source": self.review_source, "authority": admission(rows[self.review_source["recordHash"]], source.a)}] if include_review else [],
            "allowAuthorSelfReview": allow_self, "singleValuedRelations": []}
        raw = dumps(value); return raw, keccak256(raw)
