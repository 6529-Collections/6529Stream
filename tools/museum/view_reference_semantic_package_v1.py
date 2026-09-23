"""Replay native VIEW reference evidence and preserve its file-role semantics.

The exact retrieval envelope is the source. The package retains that envelope,
its verified inventory and the pinned offline Linked Art model closure. No file
is published, fetched, executed, scanned or accepted by an institution here.
"""
import argparse
from pathlib import Path
from tempfile import TemporaryDirectory

from . import view_reference_semantic_sources_v1 as sources
from . import view_reference_semantic_graph_v1 as graph
from . import view_preservation_retrieval_v1 as retrieval
from .bagit import MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .object_dossier import Assembly, _bounded, _ref
from .package_v2 import _dependencies
from .repository_exchange import _publish

NAME = 'STREAM_MUSEUM_VIEW_REFERENCE_SEMANTIC_PACKAGE_V1'
MODE = 'native_view_reference_semantic_package_v1'
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
SOURCE_PATH = 'source/envelope.json'
INVENTORY_PATH = 'source/inventory.json'
SOURCE_REPORT_PATH = 'source/retrieval-report.json'
CLAIMS = {
    'originalEnvelopeRetained': True,
    'concreteNativeRetrievalReplayed': True,
    'occurrenceInventoryReconstructed': True,
    'offlineModelDependenciesRetained': True,
    'graphReconstructed': True,
    'sourceOriginAuthenticated': False,
    'currentLiveAuthorityProven': False,
    'browserExecutionProven': False,
    'archiveDeliveryProven': False,
    'fileSafetyScanned': False,
    'publicationSafetyEstablished': False,
    'physicalCustodyProven': False,
    'fullMuseumConformance': False,
    'completeCanonicalDossier': False,
    'institutionalAcceptance': False,
    'profileRegistered': False,
    'networkFetch': False,
}
QUALIFICATION = (
    'A bounded native VIEW reference/file-role crosswalk over one exact verified retrieval '
    'envelope. Source observations retain their admitted provenance and captured-block scope. '
    'Declared file roles, retained received bytes and Archive correspondence remain separate; '
    'a package member is not received merely because its container is retained. Model validation '
    'and complete reconstruction do not prove source origin, browser performance, scan safety, '
    'archive delivery, live authority, physical custody, institutional acceptance or complete '
    'MUSEUM-24. This additive family package does not change the nineteen packet groups, '
    'forty-nine dossier assessments or earlier semantic profiles.')
PROFILE_BYTES = dumps({
    'name': NAME, 'version': '1', 'mode': MODE,
    'retrievalProfileHash': retrieval.PROFILE_HASH,
    'sourceProfileHash': sources.PROFILE_HASH,
    'graphProfileHash': graph.PROFILE_HASH,
    'retention': 'Exact externally pinned retrieval envelope under source/envelope.json; '
        'derived source inventory and report, exact profiles, crosswalk and offline model closure.',
    'verification': 'Replay the concrete retrieval consumer, reconstruct every occurrence and '
        'graph with the retained model closure, then compare every package byte.',
    'hashGraph': 'Earlier source envelope -> inventory and graph children -> package manifest.',
    'disclosure': 'Explicit public-only output; no disclosure authority inferred from supplied bytes.',
    'claims': CLAIMS, 'qualification': QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'VIEW reference semantic package requires public disclosure before reads')


def _pin(raw, digest):
    require(type(raw) is bytes and 0 < len(raw) <= retrieval.MAX_INPUT,
        'VIEW reference semantic source byte bound')
    require(any(hex_bytes(digest, 32)) and keccak256(raw) == digest,
        'VIEW reference semantic external source commitment differs')


def _build(source_raw, source_hash, *, disclosure, model_root):
    _public(disclosure)
    _pin(source_raw, source_hash)
    checked, inventory = sources.admit(source_raw, source_hash)
    root = Path(model_root).resolve()
    dependencies = _dependencies(root, recorded=True)
    mapped = graph.render(inventory, model_root=root)
    require(type(mapped) is dict and mapped and all(path.startswith(graph.OUTPUT_PREFIX) for path in mapped),
        'VIEW reference semantic graph output paths differ')
    graph_report = loads(mapped[graph.REPORT_PATH], maximum=retrieval.MAX_INPUT, canonical=True)
    report = {
        'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceHash': source_hash,
        'sourceProvenance': checked['sourceProvenance'],
        'sourceState': loads(source_raw, maximum=retrieval.MAX_INPUT, canonical=True)['context'],
        'sourceInventory': _ref(INVENTORY_PATH, dumps(inventory)),
        'graph': graph_report, 'claims': CLAIMS, 'qualification': QUALIFICATION,
    }
    files = {
        SOURCE_PATH: source_raw, INVENTORY_PATH: dumps(inventory),
        SOURCE_REPORT_PATH: dumps(checked),
        'definitions/package-profile.json': PROFILE_BYTES,
        'definitions/source-profile.json': sources.PROFILE_BYTES,
        'definitions/retrieval-profile.json': retrieval.PROFILE_BYTES,
        'definitions/graph-profile.json': graph.PROFILE_BYTES,
        'definitions/crosswalk.json': graph.CROSSWALK_BYTES,
        'report.json': dumps(report),
    }
    require(not set(files).intersection(dependencies) and not set(files).intersection(mapped)
        and not set(dependencies).intersection(mapped), 'VIEW reference semantic output collision')
    files.update(dependencies)
    files.update(mapped)
    _bounded(files)
    manifest = dumps({
        'mode': MODE, 'profile': NAME, 'version': '1', 'profileHash': PROFILE_HASH,
        'sourceHash': source_hash, 'disclosure': disclosure,
        'files': [_ref(path, raw) for path, raw in sorted(files.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION,
    })
    require(len(manifest) <= MAX_MANIFEST, 'VIEW reference semantic manifest byte bound')
    files['manifest.json'] = manifest
    _bounded(files)
    return Assembly(tuple(sorted(files.items())), manifest, report)


def build(source_raw, source_hash, *, disclosure, model_root=MODEL_ROOT):
    """Replay exact native source before interpreting any file or relationship."""
    try:
        return _build(source_raw, source_hash, disclosure=disclosure, model_root=model_root)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed VIEW reference semantic input') from exc


def _verify(files, manifest_hash):
    _bounded(files)
    raw = files.get('manifest.json', b'')
    require(any(hex_bytes(manifest_hash, 32)) and keccak256(raw) == manifest_hash,
        'VIEW reference semantic external manifest commitment differs')
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {
        'mode', 'profile', 'version', 'profileHash', 'sourceHash', 'disclosure',
        'files', 'claims', 'qualification'} and value['mode'] == MODE
        and value['profile'] == NAME and value['version'] == '1'
        and value['profileHash'] == PROFILE_HASH and value['claims'] == CLAIMS
        and value['qualification'] == QUALIFICATION,
        'VIEW reference semantic closed manifest differs')
    _public(value['disclosure'])
    require(value['files'] == [_ref(path, body) for path, body in sorted(files.items())
        if path != 'manifest.json'], 'VIEW reference semantic file commitments differ')
    dependencies = {path.removeprefix('dependencies/'): body for path, body in files.items()
        if path.startswith('dependencies/')}
    with TemporaryDirectory(prefix='stream-view-reference-model-') as temporary:
        root = Path(temporary) / 'model'
        write_tree(dependencies, root)
        rebuilt = build(files[SOURCE_PATH], value['sourceHash'],
            disclosure=value['disclosure'], model_root=root)
    require(dict(rebuilt.files) == files, 'VIEW reference semantic full reconstruction differs')
    return rebuilt


def verify(files, manifest_hash):
    """Rebuild with retained dependencies; no network or default model fallback."""
    try:
        return _verify(files, manifest_hash)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed VIEW reference semantic package') from exc


def _read(path):
    require(path.stat().st_size <= retrieval.MAX_INPUT, 'VIEW reference semantic input file bound')
    with path.open('rb') as handle:
        raw = handle.read(retrieval.MAX_INPUT + 1)
    require(len(raw) <= retrieval.MAX_INPUT, 'VIEW reference semantic input file grew past bound')
    return raw


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
            value = {'profileHash': PROFILE_HASH, 'sourceProfileHash': sources.PROFILE_HASH,
                'graphProfileHash': graph.PROFILE_HASH, 'crosswalkHash': graph.CROSSWALK_HASH}
        elif args.command == 'build':
            _public(args.disclosure)
            result = build(_read(args.source), args.source_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, [args.source])
            value = {'manifestHash': result.manifest_hash, 'report': result.report}
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
            value = {'manifestHash': result.manifest_hash, 'report': result.report}
        print(dumps(value).decode('utf-8'))
        return 0
    except (MuseumError, OSError) as exc:
        parser.exit(1, 'VIEW reference semantic package: ' + str(exc) + '\n')


if __name__ == '__main__':
    main()
