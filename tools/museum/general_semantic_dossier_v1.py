"""Offline direct General assertions with exact documentary source joins.

General receipt authority remains distinct from Metadata classes and institution
identity. This package interprets source assertions, not physical or legal acts.
"""
import argparse
from pathlib import Path
import re
from tempfile import TemporaryDirectory

from .attribution_dossier import MAX_GENERAL_V2_RESOURCE
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_rpc import ReplayTransport
from .dependencies import safe_path
from .general_attestation_source_v2 import GeneralAttestationSourceV2, PROFILE_BYTES as GENERAL_BYTES
from .general_semantic_profile_v1 import GeneralSemanticProfileV1
from .general_semantic_source_v1 import GeneralSemanticSourceV1, PROFILE_BYTES as SOURCE_BYTES
from .independent_wire import require
from .metadata_catalog_source import MetadataCatalogSource, PROFILE_BYTES as METADATA_BYTES
from .object_dossier import Assembly, _bounded, _ref
from .owner_notice_dossier import _source_files, leaves
from .owner_notice_semantics import consistent_reads
from .package_v2 import _dependencies
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator
from .repository_exchange import _publish

NAME = 'STREAM_MUSEUM_GENERAL_SEMANTIC_DOSSIER_V1'
MODE = 'general_direct_semantic_dossier'
RULE = 'urn:6529stream:museum:general-semantic-dossier:v1:'
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
MAX_SELECTION = 524288
CLAIMS = {
    'completeGeneralSourceReplayed': True, 'completeMetadataSourceReplayed': True,
    'originalSourceBytesRetained': True,
    'exactDocumentaryEvidenceChecked': True, 'generalReceiptProfileHashPreserved': True,
    'sourceOriginAuthenticated': False, 'consensusProof': False,
    'crossHostPublicationPositionProven': False, 'currentAuthorityGranted': False,
    'namedInstitutionIdentityProven': False, 'institutionalStandingProven': False,
    'independentHumanReviewProven': False, 'instrumentValidityProven': False,
    'physicalExistenceProven': False, 'historicalPerformanceProven': False,
    'physicalCustodyProven': False, 'legalTitleProven': False,
    'museumAccessionProven': False, 'rightsGranted': False,
    'exportProfileRegistered': False, 'fullMuseumConformance': False,
    'institutionalAcceptance': False, 'networkFetch': False,
}
QUALIFICATION = (
    'Exact original General assertion and documentary evidence, reconstructed '
    'from externally admitted native source transcripts. A SIGNER_VERIFIED '
    'institutional or estate receipt authenticates the recorded account claim; '
    'an OPERATOR_ASSERTED curatorial receipt authenticates its recorder and '
    'configured grant, not the separately asserted attester or DID. Neither '
    'establishes a named institution, person, instrument validity, reviewer '
    'independence, physical custody, legal title, accession or factual truth. '
    'Referenced Metadata evidence must have a strictly earlier recorded '
    'timestamp; equal timestamps do not establish cross-host order. The '
    'generic General receipt profile-definition hash remains zero. Registered '
    'interpretation documents are checked separately against the original '
    'payload profile hash. Original physical/event claims remain attributed '
    'statements, not inferred Acquisition or TransferOfCustody activities.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'mode': MODE,
    'status': 'prospective_unregistered_export_profile',
    'sourceProfileHash': keccak256(SOURCE_BYTES), 'validationPolicyHash': VALIDATION_HASH,
    'selection': 'Externally pinned source snapshot and exact General assertion '
        'selectors. Direct non-disputed/non-withdrawn statements only; review '
        'interpretation is unavailable. Conflicting explicitly single-valued '
        'claims within one original anchor subject are withheld without recency '
        'preference. Unselected records cannot veto.',
    'projection': 'One occurrence-qualified LinguisticObject per selected '
        'assertion, with exact original JCS assertion content. No Person, Group, '
        'Acquisition, TransferOfCustody, accession, ownership or event inference.',
    'identity': 'Original declaration and assertion IDs remain source values. '
        'A statement resource ID hashes its full native General occurrence '
        'selector; shared declaration IRIs never merge different statements.',
    'coverage': 'Every original General semantic statement leaf, every emitted '
        'resource leaf, all selected and withheld assertions, and all opaque '
        'source records retained. This is not a full Museum schema-field audit.',
    'retention': 'Complete General V2 and Metadata catalogues, anchors, original '
        'transcripts, semantic definition capture, selection and offline model closure.',
    'verification': 'Replay both concrete original sources and semantic definition '
        'capture, then compare every regenerated byte with the committed package.',
    'conditionalClaims': {'registeredInterpretationDocumentsChecked': 'True only '
        'when the replayed source actually checked the complete registered '
        'interpretation closure for a supported original. Empty or unsupported-only '
        'sources retain local candidate definitions without that admission claim.'},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _json(raw):
    return loads(raw, maximum=MAX_BYTES, canonical=True)


def _public(disclosure):
    require(disclosure == 'public', 'general semantics requires public disclosure before reads')


def select(snapshot, raw, digest):
    """Original General selectors never use Metadata authorization-class labels."""
    require(type(raw) is bytes and len(raw) <= MAX_SELECTION and any(hex_bytes(digest, 32))
        and keccak256(raw) == digest, 'general semantic selection external pin or bound differs')
    policy = loads(raw, maximum=MAX_SELECTION, canonical=True)
    require(type(policy) is dict and set(policy) == {
        'profile', 'sourceSnapshotHash', 'sourceAuthoritySet', 'singleValuedRelations'}
        and policy['profile'] == NAME and policy['sourceSnapshotHash'] == keccak256(dumps(snapshot)),
        'general semantic selection shape or snapshot differs')
    for key in ('sourceAuthoritySet', 'singleValuedRelations'):
        values = policy[key]
        require(type(values) is list and len(values) <= 512
            and len({dumps(value) for value in values}) == len(values),
            'general semantic selection duplicate or bound')
    require(all(type(value) is str and len(value) <= 2048
        and re.fullmatch(r'[A-Za-z][A-Za-z0-9+.-]*:[^\s]+', value)
        for value in policy['singleValuedRelations']), 'general semantic relation IRI differs')
    originals = {}
    for record in snapshot['statements']:
        if record['status'] != 'supported': continue
        for index, assertion in enumerate(record['value']['assertions']):
            reference = {**record['source'], 'pointer': '/assertions/' + str(index)}
            key = dumps(reference)
            require(key not in originals, 'general semantic duplicate original assertion')
            originals[key] = {'source': reference, 'assertion': assertion,
                'anchorSubject': record['value']['anchorSubject'], 'authority': record['authority'],
                'originalProfileHash': record['value']['profileHash'], 'reasons': []}
    selected, withheld = [], []
    for reference in sorted(policy['sourceAuthoritySet'], key=dumps):
        key = dumps(reference)
        require(key in originals, 'general semantic selected original assertion absent')
        row = originals[key]
        if row['assertion']['origin'] != 'direct_statement':
            row['reasons'].append('mapping_review_not_supported')
        if row['assertion']['reviewStatus'] in ('disputed', 'withdrawn'):
            row['reasons'].append('selected_original_revision_disputed_or_withdrawn')
        (withheld if row['reasons'] else selected).append(row)
    groups = {}
    for row in selected:
        assertion = row['assertion']
        if assertion['relation'] in policy['singleValuedRelations']:
            key = (dumps(row['anchorSubject']), assertion['subject'], assertion['relation'])
            groups.setdefault(key, []).append(row)
    for group in groups.values():
        if len({dumps(row['assertion']['object']) for row in group}) > 1:
            for row in group: row['reasons'].append('conflicting_selected_source_values')
    withheld.extend(row for row in selected if row['reasons'])
    selected = [row for row in selected if not row['reasons']]
    return {'profile': NAME, 'selectionHash': digest, 'policy': policy,
        'selected': selected, 'withheld': sorted(withheld, key=lambda row: dumps(row['source'])),
        'unselectedCount': str(len(originals) - len(policy['sourceAuthoritySet'])),
        'claims': dict(CLAIMS, registeredInterpretationDocumentsChecked=snapshot['interpretationDocumentsChecked']),
        'qualification': QUALIFICATION}


def _graph(snapshot, selection, model):
    files, index, provenance, coverage = {}, [], [], []
    for record in snapshot['statements']:
        coverage.extend({'source': record['source'], 'pointer': pointer, 'value': value,
            'pointerBase': 'semantics/snapshot.json statement', 'disposition': 'retained_original'}
            for pointer, value in leaves(record))
    for row in selection['selected']:
        source = row['source']; key = keccak256(dumps(source))[2:]
        identifier = RULE + 'statement:' + key
        resource = {'@context': CONTEXT, 'id': identifier, 'type': 'LinguisticObject',
            '_label': 'Historically recorded General assertion',
            'content': dumps(row['assertion']).decode('utf-8'),
            'referred_to_by': [{'type': 'LinguisticObject', 'content': QUALIFICATION}]}
        path = 'graph/resources/' + key + '.json'; raw = dumps(resource)
        require(path not in files, 'general semantic duplicate graph occurrence')
        files[path] = raw
        files['graph/expanded/' + key + '.json'] = model.validate_and_expand(
            raw, maximum=MAX_GENERAL_V2_RESOURCE).expanded_bytes
        index.append({'id': identifier, 'type': 'LinguisticObject', 'path': path,
            'source': source, 'originalAssertionId': row['assertion']['id'],
            'authority': row['authority']})
        provenance.extend({'entity': identifier, 'path': pointer, 'value': value,
            'source': source, 'assertionHash': keccak256(dumps(row['assertion'])),
            'authority': row['authority'], 'rule': RULE + 'exact-attributed-statement',
            'qualification': QUALIFICATION} for pointer, value in leaves(resource))
    files.update({'graph/index.json': dumps({'resources': index}),
        'graph/selection.json': dumps(selection),
        'graph/sidecar.json': dumps({'statements': snapshot['statements'], 'qualification': QUALIFICATION}),
        'graph/source-coverage.json': dumps(coverage), 'graph/provenance.json': dumps(provenance)})
    return files, len(index)


def build(source, selection_raw, selection_hash, *, disclosure, model_root=MODEL_ROOT):
    """Capture only concrete original sources; all scope is fixed before reads."""
    _public(disclosure)
    try:
        require(type(source) is GeneralSemanticSourceV1, 'concrete General semantic source required')
        raw = source.snapshot(); snapshot = _json(raw)
        selection = select(snapshot, selection_raw, selection_hash)
        root = Path(model_root).resolve()
        expected = GeneralSemanticProfileV1(root)
        require(source.profile.profile_bytes == expected.profile_bytes
            and dict(source.profile.documents) == dict(expected.documents),
            'general semantic interpretation and model dependencies differ')
        graph, resource_count = _graph(snapshot, selection, validator(root))
        files = _source_files(source.metadata, 'sources/metadata')
        files.update(_source_files(source.general, 'sources/general'))
        files.update({'sources/metadata/profile.json': METADATA_BYTES,
            'sources/general/profile.json': GENERAL_BYTES, 'semantics/snapshot.json': raw,
            'semantics/transcript.json': source.transcript(), 'definitions/source-profile.json': SOURCE_BYTES,
            'definitions/profile.json': PROFILE_BYTES, 'inputs/selection.json': selection_raw})
        for name, (_, document) in source.profile.documents.items():
            files['semantics/documents/' + name + '.json'] = document
        consistent_reads([body for path, body in files.items() if path.endswith('/transcript.json')])
        files.update(_dependencies(root, recorded=True)); files.update(graph)
        report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'mode': MODE,
            'sourceState': snapshot['sourceState'], 'sourceSnapshotHash': keccak256(raw),
            'sourceProvenance': source.provenance, 'interpretationProfileHash': source.profile.profile_hash,
            'selectionHash': selection_hash, 'sourceRecordCount': str(len(snapshot['statements'])),
            'supportedRecordCount': str(sum(row['status'] == 'supported' for row in snapshot['statements'])),
            'selectedAssertionCount': str(len(selection['selected'])),
            'withheldAssertionCount': str(len(selection['withheld'])), 'resourceCount': str(resource_count),
            'interpretationDocumentsStatus': ('checked' if snapshot['interpretationDocumentsChecked']
                else 'not_required_no_supported_records'),
            'claims': dict(CLAIMS, registeredInterpretationDocumentsChecked=snapshot['interpretationDocumentsChecked']),
            'qualification': QUALIFICATION}
        files['report.json'] = dumps(report)
        files['source/locations.json'] = dumps({'originalGeneralSourceBase': 'sources/general/',
            'originalMetadataSourceBase': 'sources/metadata/', 'semanticSnapshotPath': 'semantics/snapshot.json',
            'selectorRule': 'General assertion pointers address the original General payload; '
                'internal Metadata source selectors address their own original payload. '
                'The two authority vocabularies are distinct.', 'exportReferenceBase': ''})
        _bounded(files)
        manifest = dumps({'mode': MODE, 'version': '1', 'profileHash': PROFILE_HASH,
            'interpretationProfileHash': source.profile.profile_hash, 'provenance': source.provenance,
            'selectionHash': selection_hash, 'disclosure': disclosure,
            'files': [_ref(path, body) for path, body in sorted(files.items())]})
        require(len(manifest) <= MAX_MANIFEST, 'general semantic manifest bound')
        files['manifest.json'] = manifest; _bounded(files)
        return Assembly(tuple(sorted(files.items())), manifest, report)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed General semantic dossier input') from exc


def _replay(metadata_anchor, metadata_transcript, general_anchor, general_transcript,
            semantic_transcript, *, provenance, model_root):
    metadata = MetadataCatalogSource(metadata_anchor,
        ReplayTransport(metadata_transcript, keccak256(metadata_transcript)), provenance=provenance)
    general = GeneralAttestationSourceV2(general_anchor,
        ReplayTransport(general_transcript, keccak256(general_transcript)), provenance=provenance)
    return GeneralSemanticSourceV1(metadata, general,
        ReplayTransport(semantic_transcript, keccak256(semantic_transcript)),
        profile=GeneralSemanticProfileV1(model_root))


def verify(files, manifest_hash):
    """Every native source, definition, selection and derived byte is rebuilt."""
    try:
        _bounded(files); raw = files.get('manifest.json', b'')
        require(any(hex_bytes(manifest_hash, 32)) and keccak256(raw) == manifest_hash,
            'general semantic external manifest pin differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'version', 'profileHash',
            'interpretationProfileHash', 'provenance', 'selectionHash', 'disclosure', 'files'}
            and manifest['mode'] == MODE and manifest['version'] == '1' and manifest['profileHash'] == PROFILE_HASH
            and manifest['provenance'] in ('synthetic_fixture', 'trusted_rpc'),
            'general semantic closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [_ref(path, body) for path, body in sorted(files.items()) if path != 'manifest.json'],
            'general semantic file commitments differ')
        with TemporaryDirectory(prefix='stream-general-model-') as temporary:
            root = Path(temporary) / 'model'
            write_tree({path.removeprefix('dependencies/'): body for path, body in files.items()
                if path.startswith('dependencies/')}, root)
            source = _replay(files['sources/metadata/anchor.json'], files['sources/metadata/transcript.json'],
                files['sources/general/anchor.json'], files['sources/general/transcript.json'],
                files['semantics/transcript.json'], provenance=manifest['provenance'], model_root=root)
            rebuilt = build(source, files['inputs/selection.json'], manifest['selectionHash'],
                disclosure=manifest['disclosure'], model_root=root)
        require(dict(rebuilt.files) == files, 'general semantic full reconstruction differs')
        return rebuilt
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed General semantic dossier package') from exc


def replay_plan(path, expected_hash, *, disclosure):
    """Read exact local capture files named by an externally pinned replay plan."""
    _public(disclosure)
    path = Path(path)
    require(path.stat().st_size <= MAX_SELECTION, 'general semantic replay plan bound')
    raw = path.read_bytes()
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        'general semantic replay plan external pin differs')
    plan = loads(raw, maximum=MAX_SELECTION, canonical=True)
    keys = {'profile', 'provenance', 'metadataAnchor', 'metadataTranscript',
        'generalAnchor', 'generalTranscript', 'semanticTranscript', 'selection'}
    require(type(plan) is dict and set(plan) == keys and plan['profile'] == NAME
        and plan['provenance'] in ('synthetic_fixture', 'trusted_rpc'), 'general semantic replay plan shape')
    inputs, total = {}, 0
    for key in sorted(keys - {'profile', 'provenance'}):
        ref = plan[key]
        require(type(ref) is dict and set(ref) == {'path', 'hash'}, 'general semantic replay input reference')
        target = safe_path(path.parent, ref['path'])
        require(target.stat().st_size <= MAX_BYTES, 'general semantic replay input byte bound')
        body = target.read_bytes(); total += len(body)
        require(total <= MAX_BYTES and any(hex_bytes(ref['hash'], 32)) and keccak256(body) == ref['hash'],
            'general semantic replay input pin or aggregate bound differs')
        inputs[key] = body
    source = _replay(inputs['metadataAnchor'], inputs['metadataTranscript'], inputs['generalAnchor'],
        inputs['generalTranscript'], inputs['semanticTranscript'], provenance=plan['provenance'], model_root=MODEL_ROOT)
    return build(source, inputs['selection'], plan['selection']['hash'], disclosure=disclosure)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path); check.add_argument('--manifest-hash', required=True)
    replay = commands.add_parser('replay')
    replay.add_argument('plan', type=Path); replay.add_argument('output', type=Path)
    replay.add_argument('--plan-hash', required=True); replay.add_argument('--disclosure', choices=('public',), required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            result = {'profileHash': PROFILE_HASH, 'sourceProfileHash': keccak256(SOURCE_BYTES),
                'interpretationProfileHash': GeneralSemanticProfileV1().profile_hash}
        elif args.command == 'verify':
            result = {'manifestHash': verify(read_tree(args.directory), args.manifest_hash).manifest_hash}
        else:
            built = replay_plan(args.plan, args.plan_hash, disclosure=args.disclosure)
            _publish(dict(built.files), args.output, [args.plan.parent])
            result = {'manifestHash': built.manifest_hash, 'report': built.report}
        print(dumps(result).decode('utf-8'))
    except (MuseumError, OSError) as exc: parser.exit(1, 'general semantics: ' + str(exc) + '\n')


if __name__ == '__main__': main()
