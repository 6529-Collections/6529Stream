"""Build and replay an original conservation/interview dossier supplement offline."""
import argparse
from pathlib import Path
import sys

from . import conservation_dossier_projection_v1 as projection
from . import object_dossier as package
from . import public_conservation_capture as capture
from . import public_conservation_source as source
from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CONSERVATION_DOSSIER_V1'
MODE = 'retained_conservation_dossier_v1'
CLAIMS = {
    'completeOriginalCaptureReplay': True,
    'originalSourceBytesRetained': True,
    'allOriginalPayloadFieldsAccounted': True,
    'historicalArtistEstateLineagesSeparate': True,
    'participantIdentityProven': False,
    'interviewPerformanceProven': False,
    'interviewConsentProven': False,
    'referencedMediaRetrieved': False,
    'archiveDeliveryProven': False,
    'historicalSignaturesRevalidated': False,
    'sourceProvenanceSelfAuthenticated': False,
    'completeCanonicalDossier': False,
    'completeCanonicalPacket': False,
    'institutionalConformance': False,
    'profileRegistered': False,
}
QUALIFICATION = (
    'Supplementary projection of complete retained conservation-source records and selection histories. '
    'Participant roles, identity documents, dates, instruments, formats and references remain attributed '
    'declarations. Original Artist and estate statements and recorded current-use eligibility stay '
    'separate. Source replay does not authenticate RPC provenance, historical signatures, participants, '
    'consent, performance, media retrieval or archive delivery. Full canonical dossier and packet '
    'acceptance remain separate.')
PROFILE_BYTES = dumps({
    'name': NAME, 'version': '1', 'mode': MODE,
    'sourceRevision': source.SOURCE_REVISION, 'sourceProfileHash': source.PROFILE_HASH,
    'captureProfileHash': capture.PROFILE_HASH, 'projectionProfileHash': projection.PROFILE_HASH,
    'input': 'Complete unchanged public conservation capture, independently pinned by manifest hash. '
        'Every build and verification replays its original bounded RPC transcript.',
    'output': 'Original capture under input/ plus deterministic record, reference, selection and '
        'field-coverage projections. No optional substitute source facts or caller-authored projection.',
    'disclosure': 'Explicit public disclosure is required before input reads. Classification remains '
        'the caller responsibility; no publication, consent or legal permission is inferred.',
    'bounds': {'files': str(MAX_FILES), 'bytes': str(MAX_BYTES), 'manifestBytes': str(MAX_MANIFEST)},
    'claims': CLAIMS, 'qualification': QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'conservation dossier requires explicit public disclosure before reads')


def _build(files, source_manifest_hash, *, disclosure):
    _public(disclosure)
    original = capture.verify(files, source_manifest_hash)
    originals = dict(original.files)
    snapshot = loads(originals['source/snapshot.json'], maximum=source.MAX_OUTPUT, canonical=True)
    source_manifest = loads(original.manifest, maximum=MAX_MANIFEST, canonical=True)
    derived = projection.project(snapshot)
    require(type(derived) is dict and derived, 'conservation dossier projection is empty')
    package._bounded(derived)
    result = {'input/' + path: raw for path, raw in originals.items()}
    reserved = {'manifest.json', 'report.json', 'definitions/dossier-profile.json',
        'definitions/projection-profile.json'}
    require(not (set(derived) & reserved) and all(not path.startswith('input/') for path in derived),
        'conservation dossier projection path collision')
    result.update(derived)
    result['definitions/dossier-profile.json'] = PROFILE_BYTES
    result['definitions/projection-profile.json'] = projection.PROFILE_BYTES
    report = {
        'profile': NAME, 'version': '1', 'status': 'supplementary_partial_dossier',
        'sourceManifestHash': source_manifest_hash,
        'sourceSnapshotHash': keccak256(originals['source/snapshot.json']),
        'sourceProfileHash': source.PROFILE_HASH, 'sourceRevision': source.SOURCE_REVISION,
        'sourceProvenance': source_manifest['provenance'],
        'sourceState': snapshot['source'], 'identity': snapshot['identity'],
        'recordCount': str(len(snapshot['records'])),
        'recordCounts': {name: str(sum(row['nativeEvidence'][1] == kind for row in snapshot['records']))
            for kind, name in (('0', 'intent'), ('1', 'intent_waiver'), ('2', 'interview'))},
        'sourceClaims': snapshot['claims'], 'sourceQualification': snapshot['qualification'],
        'sourceRemaining': snapshot['remaining'], 'claims': CLAIMS, 'qualification': QUALIFICATION,
    }
    result['report.json'] = dumps(report)
    package._bounded(result)
    manifest = dumps({
        'mode': MODE, 'profile': NAME, 'version': '1', 'profileHash': PROFILE_HASH,
        'projectionProfileHash': projection.PROFILE_HASH, 'sourceManifestHash': source_manifest_hash,
        'sourceSnapshotHash': report['sourceSnapshotHash'], 'provenance': source_manifest['provenance'],
        'disclosure': disclosure, 'files': [package._ref(path, raw) for path, raw in sorted(result.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION,
    })
    require(len(manifest) <= MAX_MANIFEST, 'conservation dossier manifest byte bound')
    result['manifest.json'] = manifest
    package._bounded(result)
    return package.Assembly(tuple(sorted(result.items())), manifest, report)


def build(files, source_manifest_hash, *, disclosure):
    """Derive only from the complete, independently pinned original capture."""
    try:
        return _build(files, source_manifest_hash, disclosure=disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed conservation dossier source') from exc


def _verify(files, manifest_hash):
    package._bounded(files)
    raw = files.get('manifest.json', b'')
    require(keccak256(raw) == manifest_hash, 'conservation dossier external manifest pin differs')
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version', 'profileHash',
        'projectionProfileHash', 'sourceManifestHash', 'sourceSnapshotHash', 'provenance', 'disclosure',
        'files', 'claims', 'qualification'} and manifest['mode'] == MODE and manifest['profile'] == NAME
        and manifest['version'] == '1' and manifest['profileHash'] == PROFILE_HASH
        and manifest['projectionProfileHash'] == projection.PROFILE_HASH and manifest['claims'] == CLAIMS
        and manifest['qualification'] == QUALIFICATION, 'conservation dossier closed manifest/profile differs')
    _public(manifest['disclosure'])
    require(manifest['files'] == [package._ref(path, value) for path, value in sorted(files.items())
        if path != 'manifest.json'], 'conservation dossier file commitments differ')
    originals = {path[len('input/'):]: value for path, value in files.items() if path.startswith('input/')}
    rebuilt = build(originals, manifest['sourceManifestHash'], disclosure=manifest['disclosure'])
    require(rebuilt.manifest == raw and dict(rebuilt.files) == files,
        'conservation dossier complete reconstruction differs')
    return rebuilt


def verify(files, manifest_hash):
    """Rebuild every output byte from the unchanged embedded source capture."""
    try:
        return _verify(files, manifest_hash)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed conservation dossier package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    create = commands.add_parser('build')
    create.add_argument('source', type=Path)
    create.add_argument('output', type=Path)
    create.add_argument('--manifest-hash', required=True)
    create.add_argument('--disclosure', required=True, choices=('public', 'restricted'))
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            output = {'profileHash': PROFILE_HASH, 'profile': loads(PROFILE_BYTES, maximum=len(PROFILE_BYTES)),
                'projectionProfileHash': projection.PROFILE_HASH,
                'projection': loads(projection.PROFILE_BYTES, maximum=len(projection.PROFILE_BYTES))}
        else:
            if args.command == 'build':
                _public(args.disclosure)
                result = build(read_tree(args.source), args.manifest_hash, disclosure=args.disclosure)
                write_tree(dict(result.files), args.output)
            else:
                result = verify(read_tree(args.directory), args.manifest_hash)
            output = {'manifestHash': result.manifest_hash, 'report': result.report}
        print(dumps(output).decode('utf-8'))
        return 0
    except (MuseumError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
