"""Offline qualified physical-transfer events from original General statements.

The complete General dossier is replayed before any physical interpretation.
This supplement preserves source qualifications and never turns token activity
or an account signature into physical custody, institutional standing or title.
"""
import argparse
from pathlib import Path
from tempfile import TemporaryDirectory

from . import general_semantic_dossier_v1 as general
from . import physical_transfer_semantics_v1 as semantics
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .object_dossier import Assembly, _bounded, _ref
from .package_v2 import _dependencies
from .preservation_graph import validator
from .repository_exchange import _publish

NAME, MODE = semantics.NAME, semantics.MODE
PROFILE_BYTES, PROFILE_HASH = semantics.PROFILE_BYTES, semantics.PROFILE_HASH
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
SOURCE_PREFIX = 'sources/general-dossier/'


def _json(raw):
    return loads(raw, maximum=MAX_BYTES, canonical=True)


def _public(disclosure):
    require(disclosure == 'public', 'physical transfer requires public disclosure before reads')


def build(source_files, source_hash, *, disclosure, model_root=MODEL_ROOT):
    """Verify the exact original source and retain every byte before deriving."""
    _public(disclosure)
    try:
        original = general.verify(source_files, source_hash)
        source = dict(original.files)
        root = Path(model_root).resolve()
        dependencies = _dependencies(root, recorded=True)
        require({path: raw for path, raw in source.items() if path.startswith('dependencies/')} == dependencies,
            'physical transfer source and graph model dependencies differ')
        snapshot = _json(source['semantics/snapshot.json'])
        selection = _json(source['graph/selection.json'])
        metadata = _json(source['sources/metadata/snapshot.json'])
        rows, coverage = semantics.derive(snapshot, selection, metadata)
        graph, resource_count = semantics.graph(rows, validator(root))
        files = {SOURCE_PREFIX + path: raw for path, raw in source.items()}
        files.update(dependencies)
        files.update(graph)
        files['definitions/profile.json'] = PROFILE_BYTES
        files['transfer/sidecar.json'] = dumps({'statements': rows,
            'sourceSelection': selection, 'qualification': semantics.QUALIFICATION})
        files['transfer/source-coverage.json'] = dumps(coverage)
        dispositions = {}
        for row in rows:
            disposition = row['disposition']
            dispositions[disposition] = str(int(dispositions.get(disposition, '0')) + 1)
        index = _json(graph['transfer/index.json'])
        report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'mode': MODE,
            'sourceManifestHash': source_hash, 'sourceProfileHash': general.PROFILE_HASH,
            'sourceState': original.report['sourceState'],
            'sourceProvenance': original.report['sourceProvenance'],
            'sourceInterpretationProfileHash': original.report['interpretationProfileHash'],
            'sourceInterpretationDocumentsStatus': original.report['interpretationDocumentsStatus'],
            'sourceSelectionHash': original.report['selectionHash'],
            'sourceRecordCount': original.report['sourceRecordCount'],
            'statementDispositionCounts': dispositions, 'resourceCount': str(resource_count),
            'embeddedEventCount': str(len(index['embeddedEvents'])),
            'claims': semantics.CLAIMS, 'qualification': semantics.QUALIFICATION}
        files['report.json'] = dumps(report)
        files['source/locations.json'] = dumps({
            'originalGeneralDossierBase': SOURCE_PREFIX,
            'originalSemanticSnapshotPath': SOURCE_PREFIX + 'semantics/snapshot.json',
            'originalMetadataSnapshotPath': SOURCE_PREFIX + 'sources/metadata/snapshot.json',
            'originalSelectionPath': SOURCE_PREFIX + 'graph/selection.json',
            'statementSidecarPath': 'transfer/sidecar.json',
            'graphIndexPath': 'transfer/index.json',
            'pointerRule': 'Outer selectors address original General payloads. '
                'Entity pointers address declarations in the same original payload. '
                'Instrument selectors address their exact original Metadata payload; '
                'the evidence selector addresses its retained bytes. Embedded-event '
                'index pointers address the named graph resource file.',
            'exportReferenceBase': ''})
        _bounded(files)
        manifest = dumps({'mode': MODE, 'version': '1', 'profileHash': PROFILE_HASH,
            'sourceManifestHash': source_hash, 'disclosure': disclosure,
            'files': [_ref(path, raw) for path, raw in sorted(files.items())]})
        require(len(manifest) <= MAX_MANIFEST, 'physical transfer manifest bound')
        files['manifest.json'] = manifest
        _bounded(files)
        return Assembly(tuple(sorted(files.items())), manifest, report)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed physical transfer input') from exc


def verify(files, manifest_hash):
    """Replay the nested sources and compare every regenerated output byte."""
    try:
        _bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(manifest_hash, 32)) and keccak256(raw) == manifest_hash,
            'physical transfer external manifest pin differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {
            'mode', 'version', 'profileHash', 'sourceManifestHash', 'disclosure', 'files'}
            and manifest['mode'] == MODE and manifest['version'] == '1'
            and manifest['profileHash'] == PROFILE_HASH, 'physical transfer closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [_ref(path, raw) for path, raw in sorted(files.items())
            if path != 'manifest.json'], 'physical transfer file commitments differ')

        def subtree(prefix):
            return {path.removeprefix(prefix): raw for path, raw in files.items() if path.startswith(prefix)}

        with TemporaryDirectory(prefix='stream-physical-transfer-model-') as temporary:
            root = Path(temporary) / 'model'
            write_tree(subtree('dependencies/'), root)
            rebuilt = build(subtree(SOURCE_PREFIX), manifest['sourceManifestHash'],
                disclosure=manifest['disclosure'], model_root=root)
        require(dict(rebuilt.files) == files, 'physical transfer full reconstruction differs')
        return rebuilt
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed physical transfer package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    create = commands.add_parser('build')
    create.add_argument('source', type=Path)
    create.add_argument('output', type=Path)
    create.add_argument('--source-hash', required=True)
    create.add_argument('--disclosure', choices=('public',), required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            result = {'profileHash': PROFILE_HASH, 'sourceProfileHash': general.PROFILE_HASH}
        elif args.command == 'verify':
            result = {'manifestHash': verify(read_tree(args.directory), args.manifest_hash).manifest_hash}
        else:
            _public(args.disclosure)
            built = build(read_tree(args.source), args.source_hash, disclosure=args.disclosure)
            _publish(dict(built.files), args.output, [args.source])
            result = {'manifestHash': built.manifest_hash, 'report': built.report}
        print(dumps(result).decode('utf-8'))
    except (MuseumError, OSError) as exc:
        parser.exit(1, 'physical transfer: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()
