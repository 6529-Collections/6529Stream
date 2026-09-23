"""Portable attributed Artist review selection with exact offline native replay."""
from pathlib import Path
from tempfile import TemporaryDirectory

from .artist_attestation_source import ArtistAttestationSource, PROFILE_BYTES as ARTIST_SOURCE_BYTES
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .dependencies import safe_path
from .independent_wire import require
from .metadata_catalog_source import MetadataCatalogSource, PROFILE_BYTES as METADATA_BYTES
from .native_artist_review_profile import NativeArtistReviewProfile
from .native_artist_review_selection import select_artist_reviews
from .native_artist_review_source import NativeArtistReviewSource
from .object_dossier import Assembly, _bounded, _ref
from .owner_notice_dossier import _source_files, leaves
from .owner_notice_semantics import consistent_reads
from .package_v2 import _dependencies
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator
from .repository_exchange import _publish

NAME = 'STREAM_MUSEUM_NATIVE_ARTIST_REVIEW_DOSSIER_V1'
MODE = 'native_artist_review_dossier'
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
RULE = 'urn:6529stream:museum:native-artist-review-dossier:v1:'
CLAIMS = {
    'completeSuppliedNativeArtistSourceReplayed': True,
    'completeSuppliedMetadataSourceReplayed': True,
    'originalSourceBytesRetained': True,
    'exactSelectedAssertionAndReviewReplayed': True,
    'sourceOriginAuthenticated': False,
    'consensusProof': False,
    'actualChainAcceptance': False,
    'humanIndependenceProven': False,
    'institutionalStandingProven': False,
    'legalTitleProven': False,
    'fullObjectDossierConformance': False,
    'institutionalAcceptance': False,
    'exportProfileRegistered': False,
    'networkFetch': False,
}
QUALIFICATION = (
    'Exact selected Artist assertion and reviewer statements in an externally admitted '
    'complete native Metadata source, with original op24, Archive, receipt, historical '
    'Artist identity, signer, grant and publication evidence replayed offline. Only '
    'selected eligible reviews affect mapping selection. The output retains every '
    'original and invalid or unselected assertion. Distinct Artist identities and '
    'accounts do not establish different humans or institutions. The caller admits '
    'RPC origin; replay does not prove chain consensus, current authority, source '
    'truth, institutional standing or complete object-dossier conformance.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'mode': MODE,
    'status': 'prospective_unregistered_export_profile',
    'selection': 'Externally pinned exact source and reviewer assertion selectors, '
        'revision/profile/rule/scope/authority joins, native publication order and SELF opt-in.',
    'projection': 'One occurrence-specific validated Linked Art LinguisticObject for '
        'each selected assertion, quoted as an attributed recorded statement. '
        'Review disposition and historical authority stay in the sidecar.',
    'retention': 'Complete Metadata and Artist native snapshots, anchors and transcripts; '
        'Artist interpretation snapshot and transcript; all interpretation documents, '
        'exact selection bytes/result, selected resource provenance and model dependencies.',
    'verification': 'Reconstruct the three concrete readers and compare every regenerated '
        'package byte under the externally pinned manifest hash.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'Artist dossier requires public disclosure before reads')


def _graph(snapshot, selection, model):
    files, index, provenance = {}, [], []
    for row in selection['selected']:
        reference, assertion = row['source'], row['assertion']
        key = keccak256(dumps(reference))[2:]
        identifier = RULE + 'statement:' + key
        resource = {'@context': CONTEXT, 'id': identifier, 'type': 'LinguisticObject',
            '_label': 'Historically recorded Artist assertion',
            'content': dumps(assertion).decode('utf-8'),
            'referred_to_by': [{'type': 'LinguisticObject', 'content': QUALIFICATION}]}
        path = 'graph/resources/' + key + '.json'
        raw = dumps(resource)
        require(path not in files, 'Artist dossier duplicate resource occurrence')
        files[path] = raw
        files['graph/expanded/' + key + '.json'] = model.validate_and_expand(raw).expanded_bytes
        index.append({'id': identifier, 'type': 'LinguisticObject', 'path': path,
            'source': reference, 'assertionRevisionHash': keccak256(dumps(assertion)),
            'nativeAuthority': row['nativeAuthority'], 'reviewCount': str(len(row['reviews']))})
        provenance.extend({'entity': identifier, 'path': pointer, 'value': value,
            'source': reference, 'rule': RULE + 'exact-attributed-statement',
            'assertionRevisionHash': keccak256(dumps(assertion)),
            'nativeAuthority': row['nativeAuthority'], 'qualification': QUALIFICATION}
            for pointer, value in leaves(resource))
    files['graph/index.json'] = dumps({'resources': index})
    files['graph/provenance.json'] = dumps(provenance)
    files['graph/selection.json'] = dumps(selection)
    files['graph/sidecar.json'] = dumps({'statements': snapshot['statements'],
        'interpretationDiagnostics': selection['interpretationDiagnostics'],
        'qualification': QUALIFICATION})
    files['graph/coverage.json'] = dumps({'originals': [
        {'source': row['source'], 'status': row['status'], 'reasonCode': row['reasonCode'],
         'assertionInterpretations': row['assertionInterpretations']}
        for row in snapshot['statements']],
        'selected': [row['source'] for row in selection['selected']],
        'withheld': [row['source'] for row in selection['withheld']],
        'fullSchemaFieldCoverageClaimed': False})
    return files, len(index)


def build(source, selection_raw, selection_hash, *, disclosure, model_root=MODEL_ROOT):
    """Build from concrete native source readers, never from supplied decoded rows."""
    _public(disclosure)
    try:
        require(type(source) is NativeArtistReviewSource, 'concrete Artist review source required')
        snapshot_raw = source.snapshot()
        snapshot = loads(snapshot_raw, maximum=MAX_TRANSCRIPT, canonical=True)
        selection = select_artist_reviews(source, selection_raw, selection_hash)
        expected = NativeArtistReviewProfile()
        require(source.profile.profile_hash == expected.profile_hash
            and dict(source.profile.documents) == dict(expected.documents),
            'Artist dossier interpretation documents differ')
        root = Path(model_root).resolve()
        graph, resources = _graph(snapshot, selection, validator(root))
        files = _source_files(source.catalogue, 'sources/metadata')
        files.update(_source_files(source.artist, 'sources/artist'))
        files.update({'sources/metadata/profile.json': METADATA_BYTES,
            'sources/artist/profile.json': ARTIST_SOURCE_BYTES,
            'semantics/snapshot.json': snapshot_raw,
            'semantics/transcript.json': source.transcript(),
            'definitions/profile.json': PROFILE_BYTES,
            'inputs/selection.json': selection_raw})
        for name, (_, document) in source.profile.documents.items():
            files['semantics/documents/' + name + '.json'] = document
        consistent_reads([files[path] for path in (
            'sources/metadata/transcript.json', 'sources/artist/transcript.json',
            'semantics/transcript.json')])
        files.update(_dependencies(root, recorded=True))
        files.update(graph)
        files['report.json'] = dumps({'profile': NAME, 'profileHash': PROFILE_HASH,
            'interpretationProfileHash': source.profile.profile_hash,
            'sourceSnapshotHash': keccak256(snapshot_raw), 'sourceMode': snapshot['mode'],
            'sourceProvenance': source.provenance, 'selectionHash': selection_hash,
            'originalCount': str(len(snapshot['statements'])),
            'supportedAssertionCount': str(sum(entry['status'] == 'supported'
                for row in snapshot['statements'] for entry in row['assertionInterpretations'])),
            'selectedAssertionCount': str(len(selection['selected'])),
            'withheldAssertionCount': str(len(selection['withheld'])),
            'selectedReviewCount': str(len(selection['reviews'])),
            'resourceCount': str(resources), 'claims': CLAIMS, 'qualification': QUALIFICATION})
        files['source/locations.json'] = dumps({'originalMetadataSourceBase': 'sources/metadata/',
            'originalArtistSourceBase': 'sources/artist/',
            'semanticSnapshotPath': 'semantics/snapshot.json',
            'selectionPath': 'inputs/selection.json', 'exportReferenceBase': ''})
        _bounded(files)
        manifest = dumps({'mode': MODE, 'name': NAME, 'version': '1',
            'profileHash': PROFILE_HASH, 'interpretationProfileHash': source.profile.profile_hash,
            'provenance': source.provenance, 'selectionHash': selection_hash,
            'disclosure': disclosure, 'files': [_ref(path, raw) for path, raw in sorted(files.items())]})
        require(len(manifest) <= MAX_MANIFEST, 'Artist dossier manifest bound')
        files['manifest.json'] = manifest
        _bounded(files)
        return Assembly(tuple(sorted(files.items())), manifest,
            loads(files['report.json'], maximum=MAX_MANIFEST, canonical=True))
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed native Artist dossier input') from exc


def _replay(metadata_anchor, metadata_transcript, artist_transcript, semantic_transcript,
            *, provenance, profile_hash):
    metadata = MetadataCatalogSource(metadata_anchor,
        ReplayTransport(metadata_transcript, keccak256(metadata_transcript)), provenance=provenance)
    artist = ArtistAttestationSource(metadata,
        ReplayTransport(artist_transcript, keccak256(artist_transcript)))
    return NativeArtistReviewSource(artist,
        ReplayTransport(semantic_transcript, keccak256(semantic_transcript)),
        profile=NativeArtistReviewProfile(expected_hash=profile_hash))


def verify(files, manifest_hash):
    """Rebuild every native read, selection and graph byte from retained inputs."""
    try:
        _bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(manifest_hash, 32)) and keccak256(raw) == manifest_hash,
            'Artist dossier external manifest pin differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'name', 'version',
            'profileHash', 'interpretationProfileHash', 'provenance', 'selectionHash',
            'disclosure', 'files'} and manifest['mode'] == MODE and manifest['name'] == NAME
            and manifest['version'] == '1' and manifest['profileHash'] == PROFILE_HASH
            and manifest['provenance'] in ('synthetic_fixture', 'trusted_rpc'),
            'Artist dossier closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [_ref(path, body) for path, body in sorted(files.items())
            if path != 'manifest.json'], 'Artist dossier file commitments differ')
        with TemporaryDirectory(prefix='stream-artist-review-model-') as temporary:
            root = Path(temporary) / 'model'
            write_tree({path.removeprefix('dependencies/'): body for path, body in files.items()
                if path.startswith('dependencies/')}, root)
            source = _replay(files['sources/metadata/anchor.json'],
                files['sources/metadata/transcript.json'],
                files['sources/artist/transcript.json'], files['semantics/transcript.json'],
                provenance=manifest['provenance'], profile_hash=manifest['interpretationProfileHash'])
            rebuilt = build(source, files['inputs/selection.json'], manifest['selectionHash'],
                disclosure=manifest['disclosure'], model_root=root)
        require(dict(rebuilt.files) == files, 'Artist dossier full reconstruction differs')
        return rebuilt
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed native Artist dossier package') from exc


def replay_plan(path, expected_hash, *, disclosure):
    """Read caller-pinned local capture bytes without RPC or implicit path discovery."""
    _public(disclosure)
    path = Path(path)
    require(path.stat().st_size <= MAX_MANIFEST, 'Artist dossier replay plan bound')
    raw = path.read_bytes()
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        'Artist dossier replay plan external pin differs')
    plan = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    keys = {'profile', 'provenance', 'metadataAnchor', 'metadataTranscript',
        'artistTranscript', 'semanticTranscript', 'selection'}
    require(type(plan) is dict and set(plan) == keys and plan['profile'] == NAME
        and plan['provenance'] in ('synthetic_fixture', 'trusted_rpc'),
        'Artist dossier replay plan shape')
    inputs, total = {}, 0
    for key in sorted(keys - {'profile', 'provenance'}):
        ref = plan[key]
        require(type(ref) is dict and set(ref) == {'path', 'hash'},
            'Artist dossier replay input reference')
        target = safe_path(path.parent, ref['path'])
        require(target.stat().st_size <= MAX_BYTES, 'Artist dossier replay input byte bound')
        body = target.read_bytes(); total += len(body)
        require(total <= MAX_BYTES and any(hex_bytes(ref['hash'], 32))
            and keccak256(body) == ref['hash'], 'Artist dossier replay input pin differs')
        inputs[key] = body
    source = _replay(inputs['metadataAnchor'], inputs['metadataTranscript'],
        inputs['artistTranscript'], inputs['semanticTranscript'],
        provenance=plan['provenance'], profile_hash=NativeArtistReviewProfile().profile_hash)
    return build(source, inputs['selection'], plan['selection']['hash'], disclosure=disclosure)


def main(argv=None):
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    replay = commands.add_parser('replay')
    replay.add_argument('plan', type=Path)
    replay.add_argument('output', type=Path)
    replay.add_argument('--plan-hash', required=True)
    replay.add_argument('--disclosure', choices=('public',), required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'verify':
            result = verify(read_tree(args.directory), args.manifest_hash)
        else:
            result = replay_plan(args.plan, args.plan_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, [args.plan.parent])
        print(dumps({'manifestHash': result.manifest_hash, 'report': result.report}).decode())
    except (MuseumError, OSError) as exc:
        parser.exit(1, 'Artist dossier: ' + str(exc) + '\n')


if __name__ == '__main__': main()
