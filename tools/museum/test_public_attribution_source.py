"""Coherent supplied RPC controls; no native execution or sanction acceptance."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import public_attribution_source as source
from . import public_personhood_source as personhood_source
from . import public_personhood_capture as personhood_capture
from . import artist_attestation_source as artist
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import Array, calldata, decode, encode
from .direct_conservation_fixture import DirectConservationFixture
from .independent_wire import ZERO, ZERO_ADDRESS
from .public_history_rpc import PublicReplayTransport
from .test_current_rights_source import A, H
from .test_public_personhood_source import K


class PublicAttributionFixture(DirectConservationFixture):
    """Eight attribution modes on the same map as six original DIRECT sources."""
    def __init__(self, mode="accepted"):
        if mode not in ("accepted", "sanctioned", "later_sanction", "restored", "none", "platform", "imported", "unconfirmed"):
            raise ValueError("unsupported attribution fixture mode")
        super().__init__()
        self.mode = mode
        self.attribution_configuration = K("synthetic905 Artist configuration")
        self.sanction_rows, self.attribution_events, self.archive_rows = [], [], []
        for index in (0, 2, 4, 6):
            for getter, value in (("archiveV2", self.archive), ("mintManager", self.suite[4])):
                self.add(self.owners[index], getter + "()", (), (), ("address",), (value,))
            self.add(self.owners[index], "domainId()", (), (), ("bytes32",), (artist.DOMAINS[index],))
        self.add(self.coordinator, "configurationHash()", (), (), ("bytes32",), (self.attribution_configuration,))
        self.platform = source.zero(source.PLATFORM)
        if mode in ("none", "platform"):
            self.current_binding = source.zero(artist.BINDING)
            self.add(self.owners[0], "binding(uint256)", ("uint256",), (1,), (artist.BINDING,), (self.current_binding,))
            self.set_attribution(0, 0)
            if mode == "platform":
                timestamp = self.time(0)
                digest = source.hash_abi(("bytes32", "uint256", "address", "address", "uint256", "bytes32", "uint64"),
                    (K("6529STREAM_PLATFORM_WORKS_DECLARATION_V1"), 31337, self.registry, self.core, 1, K("platform statement"), timestamp))
                d = (digest, K("platform statement"), A(90), timestamp)
                self.platform = (d, *self.platform[1:])
                self.event(0, self.owners[4], [source.PLATFORM_EVENT, H(1)], source.PLATFORM_DATA, (1, *d))
        else:
            self.set_attribution(2, 1)
            if mode != "imported":
                self.transition(0, 1, block=0, authority=0, record=self.current_binding[3])
                self.transition(1, 2, block=0, record=K("acceptance original"))
            if mode == "unconfirmed": self.append_sanction(block=2)
            if mode in ("sanctioned", "later_sanction", "restored"):
                first = self.append_sanction(block=2)
                self.confirm(first, block=3)
                self.set_attribution(3, 1)
                if mode in ("later_sanction", "restored"): self.append_sanction(block=4)
                if mode == "restored":
                    self.transition(3, 4, block=4, record=K("dispute record"))
                    self.transition(4, 3, block=5, record=K("dispute resolution record"))
        self.add(self.owners[4], "platformWorksState(uint256)", ("uint256",), (1,), (source.PLATFORM,), (self.platform,))
        d = self.platform[0]
        self.add(self.registry, "platformWorksDeclaration(uint256)", ("uint256",), (1,), ("bool", "bytes32", "uint64"), (d[0] != ZERO, d[0], d[3]))
        if not self.sanction_rows: self.latest(ZERO)
        self.attribution_anchor = {key: self.personhood_anchor[key] for key in source.COMMON}
        self.attribution_anchor.update(profile=source.PROFILE, host=A(1), artistRegistry=self.registry,
            runtimeAdmission={"sourceCommit": source.SOURCE_REVISION, "kind": "synthetic_fixture", "artifactHash": K("synthetic attribution source905 artifact")},
            codePins=[{"address": address, "runtimeHash": digest} for address, digest in sorted(self.pins.items())])
        self.a = self.attribution_anchor

    def time(self, block): return int(self.blocks[H(200 + block)]["timestamp"], 16)

    def set_attribution(self, state, generation):
        b = self.current_binding
        self.add(self.owners[4], "attributionState(uint256)", ("uint256",), (1,), ("uint8", "uint64"), (state, generation))
        self.add(self.registry, "collectionArtistState(uint256)", ("uint256",), (1,), source.COMPOSITE,
            (state, generation, b[0], 0 if b[0] == ZERO else 1, b[3]))

    def transition(self, old, new, *, block, generation=1, authority=1, record=None, reason=ZERO, actor=None):
        log = self.event(block, self.owners[4], [source.STATE_EVENT, H(1), H(new)], source.STATE_DATA,
            (1, generation, old, A(90) if actor is None else actor, authority, K("transition") if record is None else record, reason, ""))
        self.attribution_events.append(log)
        return log

    def operation_archive(self, operation, scope, payload, *, block, actor=A(90)):
        mask = 0x47 if operation == 12 else 0x51
        prior = tuple((artist.DOMAINS[i], 1, K("prior state"), K("prior evidence")) if (mask >> i) & 1 else source.zero(artist.SNAPSHOT) for i in range(7))
        after = tuple((artist.DOMAINS[i], 2, K("after state"), K("after evidence")) if (mask >> i) & 1 else source.zero(artist.SNAPSHOT) for i in range(7))
        shape = source.OP12 if operation == 12 else source.OP13
        outer = (1, self.attribution_configuration, operation, actor, scope, prior, after, encode(shape, payload))
        raw = encode(artist.ARCHIVE, outer)
        key = source.hash_abi(("bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"),
            (K("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), 31337, self.registry, self.coordinator, operation, actor, scope))
        pointer = self._carrier(raw)
        self.add(self.archive, "artistEvidenceBytesV2(bytes32,uint64)", ("bytes32", "uint64"), (key, 1), ("bytes",), (raw,))
        self.add(self.archive, "artistEvidenceMetadataV2(bytes32,uint64)", ("bytes32", "uint64"), (key, 1),
            ("bytes32", "address", "uint32", "uint64"), (keccak256(raw), pointer, len(raw), block))
        log = self.event(block, self.archive, [artist.ARCHIVED, key, H(1), keccak256(raw)], ("address", "uint256"), (pointer, len(raw)))
        row = {"key": key, "raw": raw, "outer": outer, "payload": payload, "pointer": pointer, "log": log, "operation": operation}
        self.archive_rows.append(row)
        return row

    def rewrite_archive(self, row, payload):
        outer = (*row["outer"][:7], encode(source.OP12 if row["operation"] == 12 else source.OP13, payload))
        raw = encode(artist.ARCHIVE, outer); pointer = row["pointer"]; block = int(row["log"]["blockNumber"], 16)
        row.update(outer=outer, payload=payload, raw=raw)
        self.codes[pointer] = b"\0" + raw; self.pins[pointer] = keccak256(self.codes[pointer])
        for pin in getattr(self, "attribution_anchor", {}).get("codePins", []):
            if pin["address"] == pointer: pin["runtimeHash"] = self.pins[pointer]
        self.add(self.archive, "artistEvidenceBytesV2(bytes32,uint64)", ("bytes32", "uint64"), (row["key"], 1), ("bytes",), (raw,))
        self.add(self.archive, "artistEvidenceMetadataV2(bytes32,uint64)", ("bytes32", "uint64"), (row["key"], 1),
            ("bytes32", "address", "uint32", "uint64"), (keccak256(raw), pointer, len(raw), block))
        row["log"]["topics"][3] = keccak256(raw)
        row["log"]["data"] = "0x" + encode(("address", "uint256"), (pointer, len(raw))).hex()

    def latest(self, digest, *, binding=None, terms=None):
        b = self.current_binding if binding is None else binding
        scope = (0, 1, 0, ZERO) if terms is None else terms[:4]
        self.add(self.owners[6], "sanctionForAssociation(bytes32,uint64,bytes32,uint8,uint256,uint256,bytes32)",
            ("bytes32", "uint64", "bytes32", "uint8", "uint256", "uint256", "bytes32"), (b[0], b[4], b[3], *scope), ("bytes32",), (digest,))

    def append_sanction(self, *, block=4, authority_class=1, binding=None):
        b = self.current_binding if binding is None else binding
        nonce = len(self.sanction_rows) + 1
        uri = "ipfs://synthetic-sanction-manifest"
        subject = (K("6529STREAM_ARTIST_SANCTION_SUBJECT_V1"), 31337, self.core, A(6), 0, 1, 0, ZERO,
            K("core facts"), K("non-sanction components"), keccak256(uri.encode()), K("manifest content"), K("manifest schema"), K("manifest canonicalization"))
        value = {"contentRoot": K("content root"), "mediaHashes": [], "referenceRenderHashes": [K("render")],
            "sanctionSubject": {name: (v if name == "scopeType" else str(v) if type(v) is int else v) for name, v in zip(source.SUBJECT_FIELDS, subject)},
            "schema": "6529STREAM_ARTIST_SANCTION_CEREMONY_V1", "signingTool": {"name": "Synthetic", "version": "1"}, "statement": "Synthetic sanction " + str(nonce)}
        raw_ceremony = dumps(value); signature = b"synthetic historical sanction signature"
        terms = (0, 1, 0, ZERO, keccak256(encode((source.SUBJECT,), (subject,))), keccak256(raw_ceremony))
        r = (ZERO, b[0], self.signer, authority_class, terms, nonce, self.time(block), self.time(5) + 100, b[4], b[3], ZERO)
        digest = source.record_hash(self.personhood_anchor, self.registry, r)
        r = (digest, *r[1:-1], source.authorization(self.personhood_anchor, self.registry, r)[2])
        raw = encode(source.SANCTION_ARCHIVE, (source.ARCHIVE_SCHEMA, 1, 31337, self.registry, self.core, A(6), r, raw_ceremony, signature))
        self.add(self.owners[6], "sanctionRecord(bytes32)", ("bytes32",), (digest,), (source.RECORD,), (r,))
        self.add(self.owners[6], "sanctionArchiveBytes(bytes32)", ("bytes32",), (digest,), ("bytes",), (raw,))
        facts = (digest, b[0], source.ARCHIVE_SCHEMA, source.ARCHIVE_CANON, keccak256(raw), len(raw))
        self.add(self.owners[6], "sanctionArchiveFacts(bytes32)", ("bytes32",), (digest,), (source.FACTS,), (facts,))
        log = self.event(block, self.owners[6], [source.SANCTION_EVENT, H(1), terms[4], source.topic("address", r[2])],
            source.SANCTION_DATA, (1, 0, 0, ZERO, digest, r[3], terms[5], nonce, r[6]))
        request = (terms, (), (uri, *subject[10:]), value["statement"], "Synthetic", "1")
        payload = (b, request, (nonce, r[7], signature), (r[2], r[10], False), (b[0], r[2], r[3], 1 if r[3] == 1 else 3), r,
            (subject, raw_ceremony, K("scope inputs"), K("review facts")))
        archive = self.operation_archive(12, digest, payload, block=block)
        row = {"record": r, "raw": raw, "facts": facts, "log": log, "archive": archive, "ceremony": value}
        self.sanction_rows.append(row); self.latest(digest, binding=b, terms=terms)
        return row

    def confirm(self, row, *, block=3):
        r = row["record"]; finality_hash = K("finality original " + r[0])
        event = self.transition(2, 3, block=block, generation=r[8], authority=r[3], record=r[0], reason=finality_hash)
        transition = (1, r[1], r[8], r[0], finality_hash, 2)
        components = ((K("ARTIST_SANCTION"), self.registry, K("finalityState(uint256)")[:10], self.pins[self.registry], K("artist module version"), K("artist manifest"), r[0]),)
        components_hash = source.hash_abi(("bytes32", Array(source.COMPONENT, 32)), (K("6529STREAM_FINALITY_COMPONENTS_V1"), components))
        finality = (finality_hash, K("final manifest"), K("final URI"), components_hash, A(6), self.time(block), K("full finality"))
        scope = source.hash_abi(("bytes32", source.TRANSITION), (K("6529STREAM_ARTIST_SANCTION_FINALIZATION_TRANSITION_V1"), transition))
        payload = (self.current_binding, transition, r, A(6), self.pins[A(6)], finality, components,
            (K("action"), A(90), K("reason"), K("roles"), 1), ((r[0], K("artifact"), K("completion")), K("witness")), K("raw reads"), source.hash_abi(("bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"),
                (K("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), 31337, self.registry, self.coordinator, self.archive, self.owners[6], artist.DOMAINS[6],
                    K("consent_finality.replay.sanction_finalization_transition_key"), scope)))
        archive = self.operation_archive(13, scope, payload, block=block)
        return {"event": event, "archive": archive}

    def source(self, **kwargs):
        return source.PublicAttributionSource(dumps(self.attribution_anchor), self, **kwargs)

    def result(self): return loads(self.source().snapshot(), maximum=source.MAX_OUTPUT)

    def personhood_capture(self):
        adapter = personhood_source.PublicPersonhoodSource(dumps(self.personhood_anchor), self)
        adapter.snapshot(); transcript = adapter.transcript()
        return personhood_capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes), personhood_source.PROFILE_HASH,
            transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")


class PublicAttributionSourceTests(unittest.TestCase):
    def test_accepted_source_uses_exact_public_replay(self):
        f = PublicAttributionFixture(); adapter = f.source(); raw = adapter.snapshot(); transcript = adapter.transcript()
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            replay = source.PublicAttributionSource(adapter.anchor_bytes, PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)
        result = loads(raw, maximum=source.MAX_OUTPUT)
        self.assertEqual(result["current"]["attribution"], ["2", "1"])
        self.assertTrue(result["history"]["completeLocalBaseline"])
        self.assertIsNone(result["history"]["originalConfirmation"])


    def test_original_confirmation_latest_and_restoration_are_distinct(self):
        for mode in ("sanctioned", "later_sanction", "restored"):
            with self.subTest(mode=mode):
                f = PublicAttributionFixture(mode); result = f.result()
                history, sanctions = result["history"], result["sanctions"]
                self.assertEqual(result["current"]["attribution"], ["3", "1"])
                self.assertEqual(history["originalConfirmation"]["recordHash"], f.sanction_rows[0]["record"][0])
                self.assertEqual(history["confirmationArchive"]["sanctionRecordHash"], sanctions["originalConfirmedHash"])
                self.assertEqual(len(history["confirmations"]), 1)
                if mode != "sanctioned": self.assertNotEqual(sanctions["latestAssociationHash"], sanctions["originalConfirmedHash"])
                self.assertEqual(len(history["restorations"]), int(mode == "restored"))

    def test_none_platform_import_and_unconfirmed_do_not_infer_confirmation(self):
        for mode in ("none", "platform", "imported", "unconfirmed"):
            result = PublicAttributionFixture(mode).result()
            self.assertIsNone(result["history"]["originalConfirmation"])
            self.assertFalse(result["claims"]["historicalImportCompletenessProven"])
            if mode in ("none", "platform"):
                self.assertEqual(result["current"]["attribution"], ["0", "0"])
                self.assertEqual(result["current"]["platformDeclaration"][0], mode == "platform")
            if mode == "imported": self.assertFalse(result["history"]["completeLocalBaseline"])
            if mode == "unconfirmed": self.assertNotEqual(result["sanctions"]["latestAssociationHash"], ZERO)

    def test_original_record_hash_tampering_fails(self):
        f = PublicAttributionFixture("sanctioned"); r = f.sanction_rows[0]["record"]
        changed = (*r[:5], r[5] + 1, *r[6:])
        f.add(f.owners[6], "sanctionRecord(bytes32)", ("bytes32",), (r[0],), (source.RECORD,), (changed,))
        with self.assertRaisesRegex(MuseumError, "native sanction record"): f.result()

    def test_typed_archive_facts_and_signature_commitments_are_checked(self):
        for what in ("facts", "signature"):
            f = PublicAttributionFixture("sanctioned"); row = f.sanction_rows[0]; r = row["record"]
            if what == "facts":
                facts = (*row["facts"][:4], K("different archive"), row["facts"][5])
                f.add(f.owners[6], "sanctionArchiveFacts(bytes32)", ("bytes32",), (r[0],), (source.FACTS,), (facts,))
            else:
                fields = decode(source.SANCTION_ARCHIVE, row["raw"])
                raw = encode(source.SANCTION_ARCHIVE, (*fields[:8], b""))
                f.add(f.owners[6], "sanctionArchiveBytes(bytes32)", ("bytes32",), (r[0],), ("bytes",), (raw,))
            with self.assertRaisesRegex(MuseumError, "archive"): f.result()

    def test_latest_cannot_omit_original_or_replace_it_with_unknown_hash(self):
        for digest in (ZERO, K("unobserved latest")):
            f = PublicAttributionFixture("unconfirmed"); f.latest(digest)
            with self.assertRaisesRegex(MuseumError, "latest association"): f.result()
        f = PublicAttributionFixture(); f.latest(K("unknown import"))
        with self.assertRaisesRegex(MuseumError, "original publication missing"): f.result()

    def test_omitted_operation_archive_is_not_replaced_by_stored_sanction(self):
        f = PublicAttributionFixture("unconfirmed")
        row = f.archive_rows[0]
        f.receipts[row["log"]["transactionHash"]]["logs"].remove(row["log"])
        with self.assertRaisesRegex(MuseumError, "operation archive missing"): f.result()

    def test_rehashed_op12_original_signature_and_authority_status_are_checked(self):
        for field in ("signature", "status"):
            f = PublicAttributionFixture("unconfirmed"); row = f.archive_rows[0]; payload = list(row["payload"])
            if field == "signature": payload[2] = (*payload[2][:2], b"different signature")
            else: payload[4] = (*payload[4][:3], 4)
            f.rewrite_archive(row, tuple(payload))
            with self.assertRaisesRegex(MuseumError, "operation12 payload differs"): f.result()

    def test_confirmation_replay_component_and_finality_time_tampering_fails(self):
        for field in ("replay", "component", "future"):
            f = PublicAttributionFixture("sanctioned"); row = f.archive_rows[-1]; payload = list(row["payload"])
            if field == "replay": payload[10] = K("different replay")
            elif field == "future": payload[5] = (*payload[5][:5], f.time(5) + 1, payload[5][6])
            else:
                components = ((*payload[6][0][:6], K("wrong confirmed record")),)
                payload[6] = components
                payload[5] = (*payload[5][:3], source.hash_abi(("bytes32", Array(source.COMPONENT, 32)),
                    (K("6529STREAM_FINALITY_COMPONENTS_V1"), components)), *payload[5][4:])
            f.rewrite_archive(row, tuple(payload))
            with self.assertRaisesRegex(MuseumError, "confirmation|operation13"): f.result()

    def test_actor_remains_separate_from_historical_signer_after_rotation(self):
        f = PublicAttributionFixture("sanctioned")
        f.add(f.owners[2], "authorityState(bytes32)", ("bytes32",), (f.artist_id,), source.AUTHORITY, (A(222), 3, 3, f.registration_hash))
        f.add(f.registry, "collectionArtistState(uint256)", ("uint256",), (1,), source.COMPOSITE,
            (3, 1, f.artist_id, 3, f.current_binding[3]))
        result = f.result(); row = result["sanctions"]["records"][0]
        self.assertEqual(row["record"][2], f.signer)
        self.assertNotEqual(result["history"]["originalConfirmation"]["actor"], row["record"][2])
        self.assertNotEqual(result["current"]["authority"][0], row["record"][2])
        self.assertFalse(result["claims"]["originalSignaturesReauthorized"])

    def test_profile_admission_and_runtime_pin_fail_closed(self):
        for field in ("profile", "runtimeAdmission", "codePins"):
            f = PublicAttributionFixture(); a = deepcopy(f.attribution_anchor)
            if field == "profile": a[field] = personhood_source.PROFILE
            elif field == "runtimeAdmission": a[field]["sourceCommit"] = "0" * 40
            else: a[field][0]["runtimeHash"] = K("wrong runtime")
            with self.assertRaises(MuseumError): source.PublicAttributionSource(dumps(a), f).snapshot()

    def test_final_header_mutation_is_not_accepted(self):
        f = PublicAttributionFixture(); original = f.request; calls = 0
        def request(method, params):
            nonlocal calls
            result = original(method, params)
            if method == "eth_getBlockByHash" and params[0] == f.a["blockHash"]:
                calls += 1
                if calls >= 3: result["transactions"] = []
            return result
        f.request = request
        with self.assertRaises(MuseumError): f.result()



    def test_confirmation_cannot_use_an_older_sanction_already_superseded(self):
        f = PublicAttributionFixture("unconfirmed"); first = f.sanction_rows[0]
        f.append_sanction(block=2)
        f.confirm(first, block=3); f.set_attribution(3, 1)
        with self.assertRaisesRegex(MuseumError, "not latest sanction at transition"): f.result()

    def test_platform_saved_declaration_requires_original_publication(self):
        f = PublicAttributionFixture("platform")
        logs = f.receipts[H(400)]["logs"]
        logs[:] = [log for log in logs if log["topics"][0] != source.PLATFORM_EVENT]
        with self.assertRaisesRegex(MuseumError, "platform original declaration missing"): f.result()

    def test_transition_uri_explicit_reader_bound(self):
        f = PublicAttributionFixture(); event = f.attribution_events[0]
        fields = decode(source.STATE_DATA, hex_bytes(event["data"]))
        event["data"] = "0x" + encode(source.STATE_DATA, (*fields[:-1], "x" * source.MAX_TRANSITION_URI)).hex()
        self.assertTrue(f.result()["history"]["completeLocalBaseline"])
        fields = (*fields[:-1], "x" * (source.MAX_TRANSITION_URI + 1))
        event["data"] = "0x" + encode(source.STATE_DATA, fields).hex()
        with self.assertRaisesRegex(MuseumError, "transition fields"): f.result()


if __name__ == "__main__": unittest.main()
