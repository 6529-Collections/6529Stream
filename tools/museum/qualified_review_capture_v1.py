"""Actual isolated-EVM qualified-account review originals on pinned products.

This driver registers the separately owned prospective profile, publishes a
mapping by account A and later reviewed/rejected statements by account B, and
retains native source, publication and interpretation replay. It does not own
selection policy or infer distinct people from distinct accounts. No compiler,
remote RPC, state injection or change to the original V1/V2 fixtures is used.
"""
from datetime import datetime, timezone
import hashlib
from pathlib import Path

from .account_profile import JCS_ID, JCS_NAME, account_iri
from .canonical import dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import decode
from .chain_rpc import ReplayTransport, RpcTransport
from .current_museum_capture import CurrentMuseumFixture, ROOT, main as run_local
from .independent_publication import (IndependentPublicationAdapter, EVENT_DATA,
    EVENT_TOPIC, PROFILE as PUBLICATION_PROFILE)
from .independent_source import IndependentSourceAdapter, PROFILE as SOURCE_PROFILE
from .independent_wire import RAW_BYTES, RAW_DEFINITION, SUBJECT, ZERO, require
from .local_account_fixture import _selector
from .local_independent_fixture import REQUEST, WRITE_SIGNATURE
from .projection import CRM
from .recorded_semantic import RegisteredInterpretationCapture, RecordedSemanticSource
from .review import REVIEW_MAPPING_RULE, REVIEW_RELATION, review_literal


QUALIFICATION = ('Actual local EVM publication and registered interpretation on an explicitly pinned '
    'historical native foundation and official Safe governance. Native artifact source revisions '
    'remain separate from this fixture revision. Distinct accounts do not establish independent '
    'people, professional qualifications or institutions. No whole-stack, latest-source, remote '
    'deployment, consensus-finality or effective selection-policy claim.')
MAX_BYTES = 64 * 1024 * 1024
FILES = ('anchor.json', 'deployment-evidence.json', 'native-inputs.json', 'native-reuse-audit.json',
    'source-capture.json', 'transcript.json', 'publication-hints.json',
    'publications.json', 'publication-transcript.json', 'interpretation.json',
    'interpretation-transcript.json', 'qualified-cases.json', 'capture-pins.json')


def profile_for_hash(expected_hash):
    # The profile owner supplies this module; no guessed registered bytes.
    from .qualified_review_profile import QualifiedAccountReviewProfile
    return QualifiedAccountReviewProfile(ROOT, expected_hash=expected_hash)


def _envelope(profile, sid, prior, entities, assertions):
    return {'profileSchemaId': schema_id(profile.profile_schema_name),
        'profileHash': profile.profile_hash,
        'anchorSubject': {'kind': 'collection', 'subjectId': sid},
        'entities': entities, 'assertions': assertions, 'sourceRecords': [prior],
        'authorityAlignments': []}


def mapping_payload(profile, chain, account, sid, prior, seed, created_at):
    """Typed V2 entity layout with explicit null continuations, new profile pin."""
    agent = account_iri(chain, account)
    prefix = 'urn:stream:qualified-review-fixture:'
    entities = [{'id': prefix + name, 'kind': kind, 'declaringAgent': agent,
        'names': [{'value': name, 'language': None, 'kind': 'preferred'}],
        'sourceRecords': [prior], 'predecessors': [], 'continuation': None}
        for name, kind in (('visual', 'visual_content'), ('work', 'abstract_work'))]
    assertion = {'id': prefix + 'mapping', 'subject': prefix + 'visual',
        'relation': CRM + 'P129_is_about', 'object': {'entity': prefix + 'work'},
        'assertingAgent': agent, 'createdAt': created_at,
        'evidence': [{'source': {'algorithm': '1', 'digest': keccak256(seed),
            'canonicalizationId': RAW_BYTES}, 'selectorType': 'json_pointer',
            'selector': '/statement', 'basis': 'own_signed_statement'}],
        'origin': 'human_mapping', 'reviewStatus': 'unreviewed',
        'mappingRule': prefix + 'mapping-rule',
        'rationale': 'Account A declares this mapping; no review is inferred.',
        'reviewEvidence': [], 'corrects': [], 'disputes': []}
    return dumps(_envelope(profile, sid, prior, entities, [assertion]))


def review_payload(profile, chain, account, sid, original, original_raw,
                   created_at, disposition, label):
    """Exact original review literal; a later record never rewrites the target."""
    require(disposition in ('reviewed', 'rejected'), 'qualified fixture review disposition')
    original_value = loads(original_raw, maximum=8192, canonical=True)['assertions'][0]
    target = original | {'pointer': '/assertions/0'}
    body = {'assertionRecord': target,
        'assertionRevisionHash': keccak256(dumps(original_value)),
        'profileHash': profile.profile_hash,
        'mappingRule': original_value['mappingRule'], 'disposition': disposition}
    assertion = {'id': 'urn:stream:qualified-review-fixture:' + label,
        'subject': original_value['id'], 'relation': REVIEW_RELATION,
        'object': {'literal': review_literal(body)},
        'assertingAgent': account_iri(chain, account), 'createdAt': created_at,
        'evidence': [{'source': {'algorithm': '1', 'digest': keccak256(original_raw),
            'canonicalizationId': JCS_ID}, 'selectorType': 'json_pointer',
            'selector': '/assertions/0', 'basis': 'documentary_evidence'}],
        'origin': 'direct_statement', 'reviewStatus': 'unreviewed',
        'mappingRule': REVIEW_MAPPING_RULE,
        'rationale': 'An attributed account review; selection remains separately supplied.',
        'reviewEvidence': [], 'corrects': [], 'disputes': []}
    return dumps(_envelope(profile, sid, original, [], [assertion]))


class QualifiedReviewFixture(CurrentMuseumFixture):
    def profile_for_capture(self):
        return self.qualified_profile

    def publish_account(self, raw, schema, canonical, nonce, account):
        require(type(raw) is bytes and 0 < len(raw) <= 8192, 'qualified fixture payload bound')
        subject = (0, 1, 0, ZERO)
        sid, = self.call('StreamCollectionAttestations', 'deriveSubject', (subject,))
        now = int(self.rpc('eth_getBlockByNumber', ['latest', False])['timestamp'], 16)
        request = (account, 1, sid, schema_id('INDEPENDENT_SEMANTIC_ASSERTION'), schema,
            1, hex_bytes(keccak256(raw)), canonical,
            'https://example.org/qualified-review/retained-payload.json', raw, now, nonce, now + 86400)
        host = self.addresses['StreamCollectionAttestations']
        tx = self.invoke(host, WRITE_SIGNATURE, (SUBJECT, REQUEST, 'bytes'),
            (subject, request, b''), sender=account)
        events = [row for row in tx['logs'] if row['address'] == host
            and row['topics'] and row['topics'][0] == EVENT_TOPIC]
        require(len(events) == 1, 'qualified fixture exact native publication event')
        digest = decode(EVENT_DATA, hex_bytes(events[0]['data']))[1]
        record, receipt = self.call('StreamCollectionAttestations', 'collectionRecord', (digest,))
        require(receipt[1] == account, 'qualified fixture native attestor differs')
        definition, = self.call('StreamSchemaRegistry', 'documentBytes', (schema,))
        return _selector(host, digest, record, receipt, definition), sid

    def build_qualified(self):
        self.foundation()
        self.register_document('RAW_BYTES', 1, RAW_DEFINITION)
        seed_schema = self.register_document('STREAM_LOCAL_QUALIFIED_REVIEW_SEED_V1', 0,
            b'{"type":"object"}')
        executor, core = self.addresses['StreamGovernanceExecutor'], self.addresses['StreamCore']
        self.deploy('StreamCollectionAttestations', ((core, self.schemas, executor,
            self.deployment, 'https://example.org/qualified-review/attestations.json',
            schema_id('local qualified review native host'),
            ('METADATA_ERC1271_VERIFY_GAS', 400000, 90000, 2),
            ('METADATA_DEPENDENCY_READ_GAS', 300000, 50000, 2)),))
        self.publisher, self.reviewer = self.rpc('eth_accounts', [])[:2]
        require(self.publisher != self.reviewer, 'qualified fixture needs distinct accounts')
        seed = dumps({'statement': 'A local documentary seed for one attributed mapping.'})
        prior, sid = self.publish_account(seed, seed_schema, RAW_BYTES, 100, self.publisher)
        profile = self.profile_for_capture()
        for name in [JCS_NAME] + [n for n in profile.documents if n != JCS_NAME]:
            kind, raw = profile.documents[name]
            self.register_document(name, kind, raw,
                profile.document_canonicalizations.get(name, RAW_BYTES if name == JCS_NAME else JCS_ID),
                profile.document_predecessors.get(name, ZERO))
        now = int(self.rpc('eth_getBlockByNumber', ['latest', False])['timestamp'], 16)
        # This claimed timestamp is deliberately shared: native order is authoritative.
        stamp = datetime.fromtimestamp(now, timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        raw = mapping_payload(profile, '31337', self.publisher, sid, prior, seed, stamp)
        schema = schema_id(profile.assertion_schema_name)
        original, _ = self.publish_account(raw, schema, JCS_ID, 101, self.publisher)
        choices = {'mapping': original | {'pointer': '/assertions/0'}}
        for label, disposition, account, nonce in (
                ('approved', 'reviewed', self.reviewer, 100),
                ('rejected', 'rejected', self.reviewer, 101),
                ('self_review', 'reviewed', self.publisher, 102)):
            review = review_payload(profile, '31337', account, sid, original, raw,
                stamp, disposition, label)
            row, _ = self.publish_account(review, schema, JCS_ID, nonce, account)
            choices[label] = row | {'pointer': '/assertions/0'}
        self.choices = choices
        block = self.rpc('eth_getBlockByNumber', ['latest', False])
        evidence = dumps({'kind': 'local_evm_fixture',
            'workflow': 'actual_registered_qualified_account_review_v1',
            'nativeInputManifestSha256': hashlib.sha256(self.manifest_raw).hexdigest(),
            'nativeReuseAuditHash': keccak256(self.native_reuse_audit),
            'artifacts': self.artifact_rows, 'transactions': self.receipts,
            'safeFixture': self.manifest['safeFixture'], 'safeComponents': self.safe_components,
            'safeAccounts': self.safe_accounts, 'boundaries': [], 'governanceRoot': self.governor,
            'publisher': self.publisher, 'reviewer': self.reviewer,
            'hostGovernanceAuthority': executor, 'qualification': QUALIFICATION})
        anchor = dumps({'profile': SOURCE_PROFILE, 'chainId': '31337',
            'blockHash': block['hash'], 'blockNumber': str(int(block['number'], 16)),
            'timestamp': str(int(block['timestamp'], 16)), 'stateRoot': block['stateRoot'],
            'environment': 'local_evm_fixture', 'deploymentEvidenceHash': keccak256(evidence),
            'host': self.addresses['StreamCollectionAttestations'], 'core': core,
            'schemas': self.schemas, 'store': self.store,
            'codePins': [{'address': address,
                'runtimeHash': keccak256(hex_bytes(self.rpc('eth_getCode', [address, 'latest'])))}
                for address in self.capture_code_addresses()], 'lanes': self.capture_lanes()})
        return anchor, evidence


def capture(fixture, output):
    output.joinpath('native-reuse-audit.json').write_bytes(fixture.native_reuse_audit)
    anchor, evidence = fixture.build_qualified()
    output.joinpath('anchor.json').write_bytes(anchor)
    output.joinpath('deployment-evidence.json').write_bytes(evidence)
    original = IndependentSourceAdapter(anchor, RpcTransport(fixture.endpoint), provenance='trusted_rpc')
    snapshot = original.snapshot(); transcript = original.reader.transcript()
    output.joinpath('source-capture.json').write_bytes(snapshot)
    output.joinpath('transcript.json').write_bytes(transcript)
    replay = IndependentSourceAdapter(anchor, ReplayTransport(transcript, keccak256(transcript)),
        provenance='trusted_rpc')
    require(replay.snapshot() == snapshot, 'qualified fixture source replay differs')
    hashes = {row['recordHash'] for row in loads(snapshot, maximum=MAX_BYTES)['records']}
    hints = []
    for tx in fixture.receipts:
        for event in tx['receipt']['logs']:
            if event['address'] == original.a['host'] and event['topics'] and event['topics'][0] == EVENT_TOPIC:
                digest = decode(EVENT_DATA, hex_bytes(event['data']))[1]
                if digest in hashes:
                    hints.append({'recordHash': digest, 'transactionHash': tx['transactionHash']})
    hints_raw = dumps({'profile': PUBLICATION_PROFILE, 'records': hints})
    output.joinpath('publication-hints.json').write_bytes(hints_raw)
    publication = IndependentPublicationAdapter(original, hints_raw,
        RpcTransport(fixture.endpoint), provenance='trusted_rpc')
    public_raw = publication.snapshot(); public_transcript = publication.reader.transcript()
    output.joinpath('publications.json').write_bytes(public_raw)
    output.joinpath('publication-transcript.json').write_bytes(public_transcript)
    public_replay = IndependentPublicationAdapter(replay, hints_raw,
        ReplayTransport(public_transcript, keccak256(public_transcript)), provenance='trusted_rpc')
    require(public_replay.snapshot() == public_raw, 'qualified fixture publication replay differs')
    profile = fixture.profile_for_capture()
    interpretation = RegisteredInterpretationCapture(publication, profile, RpcTransport(fixture.endpoint))
    interpreted = interpretation.snapshot(); interpreted_transcript = interpretation.probe.reader.transcript()
    output.joinpath('interpretation.json').write_bytes(interpreted)
    output.joinpath('interpretation-transcript.json').write_bytes(interpreted_transcript)
    repeated = RegisteredInterpretationCapture(public_replay, profile,
        ReplayTransport(interpreted_transcript, keccak256(interpreted_transcript)))
    require(repeated.snapshot() == interpreted, 'qualified fixture interpretation replay differs')
    source = RecordedSemanticSource(repeated, profile_hash=profile.profile_hash)
    cases = {'version': '1', 'profileHash': profile.profile_hash,
        'sourceStateHash': source.state.commitment, 'publisher': fixture.publisher,
        'reviewer': fixture.reviewer, 'selectors': fixture.choices, 'qualification': QUALIFICATION}
    output.joinpath('qualified-cases.json').write_bytes(dumps(cases))
    pins = {'profileHash': profile.profile_hash, 'files': {name: keccak256(output.joinpath(name).read_bytes())
        for name in FILES if name != 'capture-pins.json'}}
    output.joinpath('capture-pins.json').write_bytes(dumps(pins))
    from .qualified_review_fixture_v1 import verify_capture
    verify_capture({name: output.joinpath(name).read_bytes() for name in FILES}, profile)
    return keccak256(dumps(pins))


def main():
    def configure(parser):
        parser.add_argument('--profile-hash', required=True)
        parser.add_argument('--native-reuse-audit', type=Path, required=True)
        parser.add_argument('--native-reuse-audit-sha256', required=True)
    def prepare(args):
        args.qualified_profile = profile_for_hash(args.profile_hash)
        require(args.native_reuse_audit.stat().st_size <= MAX_BYTES, 'native reuse audit byte bound')
        args.audit_raw = args.native_reuse_audit.read_bytes()
        require(hashlib.sha256(args.audit_raw).hexdigest() == args.native_reuse_audit_sha256,
            'native reuse audit external pin differs')
        audit = loads(args.audit_raw, maximum=MAX_BYTES, canonical=True)
        require(audit['nativeManifest']['sha256'] == args.native_manifest_sha256,
            'native reuse audit manifest differs')
    def configure_fixture(fixture, args):
        fixture.qualified_profile = args.qualified_profile
        fixture.native_reuse_audit = args.audit_raw
    run_local(fixture_type=QualifiedReviewFixture, capture_function=capture,
        configure_parser=configure, prepare_arguments=prepare, configure_fixture=configure_fixture)


if __name__ == '__main__': main()
