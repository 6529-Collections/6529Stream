"""Replay conservation sources, documentary archives and typed museum mappings."""
import argparse
from pathlib import Path
import sys
from tempfile import TemporaryDirectory

from . import conservation_archive_v1 as archive
from . import conservation_dossier_projection_v1 as projection
from . import conservation_dossier_v1 as original
from . import conservation_semantic_graph_v1 as semantic
from . import object_dossier as package
from .bagit import MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import require
from .package_v2 import _dependencies

NAME = 'STREAM_MUSEUM_CONSERVATION_DOSSIER_V2'
MODE = 'retained_conservation_dossier_v2'
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
CLAIMS = {
    'originalDossierReplayed': True,
    'originalSourceBytesRetained': True,
    'completeReferenceDenominatorRetained': True,
    'typedMappingReconstructed': True,
    'offlineModelDependenciesRetained': True,
    'participantIdentityProven': False,
    'interviewPerformanceProven': False,
    'interviewConsentProven': False,
    'sourceProvenanceSelfAuthenticated': False,
    'archiveAvailabilityProven': False,
    'historicalSignatureRevalidation': False,
    'completeCanonicalDossier': False,
    'completeCanonicalPacket': False,
    'institutionalConformance': False,
    'profileRegistered': False,
}
QUALIFICATION = (
    'Complete processing is scoped to the original bound conservation source and every documentary '
    'reference it contains. Missing or unsupported correspondence blocks completion; no source '
    'occurrence is discarded. Native retained Archive correspondence, received byte fixity, '
    'declared format, current availability, named identity and interview performance are separate '
    'facts. All original Artist and estate histories and eligibility qualifications remain intact. '
    'A complete result within this source family is not complete canonical dossier or release acceptance.')
PROFILE_BYTES = dumps({
    'name': NAME, 'version': '2', 'mode': MODE,
    'originalDossierProfileHash': original.PROFILE_HASH,
    'archiveProfileHash': archive.PROFILE_HASH,
    'semanticProfileHash': semantic.PROFILE_HASH,
    'input': 'Externally pinned unchanged conservation dossier, exact materials envelope and retained bytes.',
    'denominator': 'Every original selected record, catalog document, semantic leaf and reference occurrence.',
    'verification': 'Replay the original source, repeat each concrete Archive and model check, then compare every output byte.',
    'sourcePaths': 'Component dossier paths and original Reference URIs retain their original scope. source-locations.json resolves component dossier input paths beneath source/; a URI is never rewritten as a fetched package file.',
    'dependencies': 'Exact offline linked-art-v2 and vocabulary closures from the existing package collector; retained code is never executed.',
    'claims': CLAIMS, 'qualification': QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'conservation V2 requires public disclosure before input reads')


def _destination(output, *inputs):
    target = Path(output).resolve()
    require(all(not target.is_relative_to(Path(source).resolve()) for source in inputs),
        'conservation output must be outside input directories')


def _report(files, path):
    require(path in files, 'conservation component report missing: ' + path)
    return loads(files[path], maximum=64 * 1024 * 1024, canonical=True)


def _archive_complete(files):
    try:
        archive.require_complete(files)
    except MuseumError:
        return False
    return True


def _merge(target, additions, prefix):
    require(type(additions) is dict and additions and all(path.startswith(prefix) for path in additions),
        'conservation component output path differs')
    package._bounded(additions)
    require(not set(target).intersection(additions), 'conservation component path collision')
    target.update(additions)


def _build(files, source_hash, materials_raw, materials_hash, material_files, *, disclosure, model_root):
    _public(disclosure)
    checked = original.verify(files, source_hash)
    originals = dict(checked.files)
    require(type(material_files) is dict, 'conservation material file mapping required')
    archived = archive.verify(originals, materials_raw, materials_hash, material_files)
    projected = {path: originals[path] for path in projection.OUTPUTS}
    root = Path(model_root).resolve()
    dependencies = _dependencies(root, recorded=True)
    mapped = semantic.render(projected, model_root=root)
    archive_report = _report(archived, 'archive/report.json')
    semantic_report = _report(mapped, semantic.REPORT_PATH)
    archive_complete = _archive_complete(archived)
    semantic_complete = semantic_report['status'] == 'supported' and semantic_report['completeness'] in (
        'complete_for_profile', 'complete_with_stream_extensions')
    report = {
        'profile': NAME, 'version': '2', 'sourceManifestHash': source_hash,
        'sourceProvenance': checked.report['sourceProvenance'],
        'sourceState': checked.report['sourceState'], 'identity': checked.report['identity'],
        'processingScope': 'all_records_catalogs_and_reference_occurrences_in_original_bound_conservation_source',
        'status': 'complete_with_stream_extensions' if archive_complete and semantic_complete else 'incomplete',
        'archiveComplete': archive_complete, 'semanticComplete': semantic_complete,
        'sourceLocationMap': 'source-locations.json',
        'archive': archive_report, 'semantic': semantic_report,
        'claims': CLAIMS, 'qualification': QUALIFICATION,
    }
    result = {'source/' + path: raw for path, raw in originals.items()}
    result.update({'materials/data/' + path: raw for path, raw in material_files.items()})
    result['materials/input.json'] = materials_raw
    _merge(result, dependencies, 'dependencies/')
    _merge(result, archived, 'archive/')
    _merge(result, mapped, semantic.OUTPUT_PREFIX)
    result['definitions/dossier-v2-profile.json'] = PROFILE_BYTES
    result['source-locations.json'] = dumps({
        'originalDossierManifestHash': source_hash, 'originalDossierRoot': 'source/',
        'componentInputPathsAreRelativeTo': 'originalDossierRoot',
        'inputs': [{'componentPath': path, 'packagePath': 'source/' + path,
            'hash': keccak256(originals[path])} for path in projection.OUTPUTS],
        'referenceURIsRewritten': False,
    })
    result['report.json'] = dumps(report)
    package._bounded(result)
    manifest = dumps({
        'mode': MODE, 'profile': NAME, 'version': '2', 'profileHash': PROFILE_HASH,
        'sourceManifestHash': source_hash, 'materialsHash': materials_hash,
        'disclosure': disclosure, 'sourceProvenance': report['sourceProvenance'],
        'files': [package._ref(path, raw) for path, raw in sorted(result.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION,
    })
    require(len(manifest) <= MAX_MANIFEST, 'conservation V2 manifest byte bound')
    result['manifest.json'] = manifest
    package._bounded(result)
    return package.Assembly(tuple(sorted(result.items())), manifest, report)


def build(files, source_hash, materials_raw, materials_hash, material_files, *, disclosure, model_root=MODEL_ROOT):
    """Run both concrete family consumers over one independently verified dossier."""
    try:
        return _build(files, source_hash, materials_raw, materials_hash, material_files,
            disclosure=disclosure, model_root=model_root)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed conservation V2 input') from exc


def _verify(files, manifest_hash):
    package._bounded(files)
    raw = files.get('manifest.json', b'')
    require(keccak256(raw) == manifest_hash, 'conservation V2 external manifest pin differs')
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {'mode', 'profile', 'version', 'profileHash',
        'sourceManifestHash', 'materialsHash', 'disclosure', 'sourceProvenance', 'files', 'claims', 'qualification'}
        and value['mode'] == MODE and value['profile'] == NAME and value['version'] == '2'
        and value['profileHash'] == PROFILE_HASH and value['claims'] == CLAIMS
        and value['qualification'] == QUALIFICATION, 'conservation V2 closed manifest differs')
    _public(value['disclosure'])
    require(value['files'] == [package._ref(path, body) for path, body in sorted(files.items())
        if path != 'manifest.json'], 'conservation V2 file commitments differ')
    originals = {path.removeprefix('source/'): body for path, body in files.items() if path.startswith('source/')}
    materials = {path.removeprefix('materials/data/'): body for path, body in files.items()
        if path.startswith('materials/data/')}
    dependencies = {path.removeprefix('dependencies/'): body for path, body in files.items()
        if path.startswith('dependencies/')}
    with TemporaryDirectory(prefix='stream-conservation-model-') as temporary:
        model_root = Path(temporary) / 'dependencies'
        write_tree(dependencies, model_root)
        rebuilt = build(originals, value['sourceManifestHash'], files['materials/input.json'],
            value['materialsHash'], materials, disclosure=value['disclosure'], model_root=model_root)
    require(rebuilt.manifest == raw and dict(rebuilt.files) == files, 'conservation V2 full reconstruction differs')
    return rebuilt


def verify(files, manifest_hash):
    """Use the package's retained model closure and rebuild without network access."""
    try:
        return _verify(files, manifest_hash)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed conservation V2 package') from exc


def require_complete(result):
    """Refuse completion when any original reference or mapping is unresolved."""
    archive.require_complete(dict(result.files))
    require(result.report['semanticComplete'] and result.report['status'] == 'complete_with_stream_extensions',
        'conservation semantic mapping is incomplete')
    return result.report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    template = commands.add_parser('material-template')
    template.add_argument('source', type=Path)
    template.add_argument('output', type=Path)
    template.add_argument('--manifest-hash', required=True)
    template.add_argument('--disclosure', required=True)
    create = commands.add_parser('build')
    create.add_argument('source', type=Path)
    create.add_argument('materials', type=Path)
    create.add_argument('output', type=Path)
    create.add_argument('--manifest-hash', required=True)
    create.add_argument('--materials-hash', required=True)
    create.add_argument('--disclosure', required=True)
    create.add_argument('--require-complete', action='store_true')
    for name in ('verify', 'complete'):
        command = commands.add_parser(name)
        command.add_argument('directory', type=Path)
        command.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            message = {'profileHash': PROFILE_HASH, 'profile': loads(PROFILE_BYTES, maximum=len(PROFILE_BYTES))}
        elif args.command == 'material-template':
            _public(args.disclosure)
            _destination(args.output, args.source)
            checked = original.verify(read_tree(args.source), args.manifest_hash)
            raw = archive.template(dict(checked.files))
            write_tree({'input.json': raw}, args.output)
            message = {'materialsHash': keccak256(raw), 'directory': str(args.output)}
        elif args.command == 'build':
            _public(args.disclosure)
            _destination(args.output, args.source, args.materials)
            material_tree = read_tree(args.materials)
            require('input.json' in material_tree and all(path == 'input.json' or path.startswith('data/')
                for path in material_tree), 'conservation material directory shape differs')
            materials = {path.removeprefix('data/'): raw for path, raw in material_tree.items() if path.startswith('data/')}
            result = build(read_tree(args.source), args.manifest_hash, material_tree['input.json'],
                args.materials_hash, materials, disclosure=args.disclosure)
            if args.require_complete:
                require_complete(result)
            write_tree(dict(result.files), args.output)
            message = {'manifestHash': result.manifest_hash, 'report': result.report}
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
            if args.command == 'complete':
                require_complete(result)
            message = {'manifestHash': result.manifest_hash, 'report': result.report}
        print(dumps(message).decode('utf-8'))
        return 0
    except (MuseumError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
