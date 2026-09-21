"""Preserved-tool supplement for one exact V3 dossier, with explicit replay.

Inspection checks original bytes and semantics without executing archived code.
Assembly/replay explicitly execute the caller's pinned reviewed source/runtime.
An inspection cannot authenticate a previous local execution statement.
"""
import argparse
from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory

from . import canonical_object_dossier_v3 as dossier
from . import canonical_composition_observations_v1 as observations
from . import object_dossier as package
from . import preserved_tool_replay_v1 as replay
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import require
from .repository_exchange import _destination, _publish

NAME = 'STREAM_PRESERVED_TOOL_DOSSIER_V1'
QUALIFICATION = ('A preserved-tool supplement retains the exact V3 dossier and its complete nineteen '
    'packet groups and forty-nine acceptance requirements, complete source/runtime transports, '
    'runtime recipe, every declared vector and a local replay receipt. Optional original native '
    'release observations are reconciled at the same source state. Successful vector regeneration '
    'does not establish end-to-end genesis reconstruction, a reproducible compiler build, complete '
    'semantic/render outputs, global history, institutional acceptance or release authority. '
    'Passive inspection validates recorded execution bytes but cannot authenticate their origin; '
    'the separate replay command executes the selected reviewed archives again.')


def _extract(files, prefix):
    return {p.removeprefix(prefix): raw for p, raw in files.items() if p.startswith(prefix)}


def _receipt(files, pins, cases, source_files):
    package._bounded(files)
    require(set(files) == {'manifest.json', 'report.json', 'worker.py', 'runtime-recipe.json',
        'vectors.json', 'stdout.log', 'stderr.log'}, 'tool supplement exact receipt filenames differ')
    manifest = loads(files.get('manifest.json', b''), maximum=MAX_MANIFEST, canonical=True)
    require(manifest == {'schema': replay.NAME,
        'files': [package._ref(p, b) for p, b in sorted(files.items()) if p != 'manifest.json'],
        'qualification': replay.QUALIFICATION}, 'tool supplement replay receipt inventory differs')
    report = loads(files.get('report.json', b''), maximum=MAX_BYTES, canonical=True)
    require(type(report) is dict and set(report) == {'schema', 'sourcePartsSha256', 'runtimePartsSha256',
        'runtimeRecipeSha256', 'workerSha256', 'cases', 'child', 'runtime', 'claims', 'qualification'}
        and report['claims'] == replay.CLAIMS
        and report.get('schema') == replay.NAME and report.get('qualification') == replay.QUALIFICATION
        and report.get('sourcePartsSha256') == pins['sourcePartsSha256']
        and report.get('runtimePartsSha256') == pins['runtimePartsSha256']
        and report.get('runtimeRecipeSha256') == pins['runtimeRecipeSha256']
        and report.get('workerSha256') == sha256(files.get('worker.py', b'')).hexdigest()
        and report.get('cases') == replay._expected(cases), 'tool supplement replay receipt pins/results differ')
    require(files['worker.py'] == Path(replay.__file__).with_name('preserved_tool_worker_v1.py').read_bytes(),
        'tool supplement fixed replay worker differs')
    require(sha256(files.get('runtime-recipe.json', b'')).hexdigest() == pins['runtimeRecipeSha256'],
        'tool supplement runtime recipe differs')
    replay.validate_child(report['child'], report['cases'], source_files,
        files['runtime-recipe.json'], files['worker.py'])
    return report


def _derive(original, dossier_hash, source_package, runtime_package, recipe, recipe_hash,
        source_hash, runtime_hash, receipt_files, release_raw):
    from . import preserved_tool_source_v1 as source_tools
    from . import preserved_tool_runtime_v1 as runtime_tools
    from . import preserved_tool_release_v1 as release_tools
    checked = dossier.verify(original, dossier_hash)
    source_archive = source_tools.verify(source_package, source_hash)
    runtime_archive = source_tools.verify_transport(runtime_package, runtime_hash)
    replay.validate_toolchain(source_archive.source_manifest, dict(runtime_archive.files),
        recipe, runtime_hash, recipe_hash)
    with TemporaryDirectory(prefix='stream-tool-inspect-') as temporary:
        root = Path(temporary)
        write_tree(runtime_archive.restored_files, root / 'runtime')
        runtime_report = runtime_tools.validate_tree(root / 'runtime', recipe, recipe_hash)
        source_files = dict(source_archive.restored_files)
        cases = replay.admit_vectors(source_files)
    require(any(case['kind'] == 'dossier_v3' and case['manifestHash'] == dossier_hash
        and case['files'] == original for case in cases),
        'tool supplement selected dossier is not an exact preserved replay vector')
    pins = {'dossierManifestHash': dossier_hash, 'sourcePartsSha256': source_hash,
        'runtimePartsSha256': runtime_hash, 'runtimeRecipeSha256': recipe_hash,
        'releaseEvidenceHash': None if release_raw is None else keccak256(release_raw)}
    receipt = _receipt(receipt_files, pins, cases, source_files)
    require(receipt_files['vectors.json'] == source_files['vectors/replay-vectors.json']
        and receipt_files['runtime-recipe.json'] == recipe
        and receipt['runtime'] == runtime_report, 'tool supplement replay inputs differ')
    released, joined = None, None
    if release_raw is not None:
        released = release_tools.validate(release_raw, pins['releaseEvidenceHash'],
            package=source_package, expected_parts_sha256=source_hash)
        acquisition = _extract(original, 'acquisition/')
        rows = loads(acquisition['source-observations.json'], maximum=MAX_BYTES, canonical=True)
        conserved = _extract(original, 'conservation/')
        if conserved:
            rows += dossier._conservation_sources(conserved, checked.report['conservationReport']['sourceProvenance'])
        joined = observations.reconcile(checked.report['sourceState'], rows + released.observations)
    report = {'schema': NAME, 'inputs': pins, 'sourceState': checked.report['sourceState'],
        'packetRequirements': checked.report['packetRequirements'],
        'dossierRequirements': checked.report['dossierRequirements'],
        'toolCapabilities': {'preservedSourceVerified': True, 'runtimeClosureVerified': True,
            'allDeclaredVectorResultsByteChecked': True, 'selectedDossierVectorRetained': True,
            'localExecutionReceiptRetained': True, 'previousExecutionOriginAuthenticated': False,
            'compiledBuildReproduced': False, 'fullGenesisReconstructionProven': False,
            'canonicalZeroOperatorCompletion': False},
        'release': None if released is None else released.report, 'sourceReconciliation': joined,
        'remainingToolAcceptance': ['reproducible_compiler_build', 'full_genesis_chain_state_reconstruction',
            'semantic_and_render_scope', 'trusted_execution_attestation', 'release_authority',
            'new_execution_receipt_archival_correspondence']
            + (['original_native_release_selection_and_dual_family_archives'] if released is None else released.report['remaining']),
        'qualification': QUALIFICATION}
    require(len(report['packetRequirements']) == 19
        and report['dossierRequirements']['counts']['total'] == 49
        and len(report['dossierRequirements']['results']) == 49, 'tool supplement fixed requirement denominators')
    files = {'dossier/' + p: raw for p, raw in original.items()}
    files.update({'tool/source/' + p: raw for p, raw in source_archive.files})
    files.update({'tool/runtime/' + p: raw for p, raw in runtime_archive.files})
    files.update({'replay/' + p: raw for p, raw in receipt_files.items()})
    if released is not None:
        files.update({'release/' + p: raw for p, raw in released.files.items()
            if not p.startswith('tool-package/')})
    files['report.json'] = dumps(report)
    package._bounded(files)
    manifest = dumps({'schema': NAME, 'inputs': pins,
        'files': [package._ref(p, raw) for p, raw in sorted(files.items())], 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'tool supplement manifest bound')
    files['manifest.json'] = manifest
    package._bounded(files)
    return package.Assembly(tuple(sorted(files.items())), manifest, report)


def assemble(dossier_directory, dossier_hash, source_package, source_hash, runtime_package,
        runtime_hash, runtime_recipe, runtime_recipe_hash, *, output, disclosure, release_raw=None, timeout=900):
    require(disclosure == 'public', 'tool supplement public disclosure required before reads/execution')
    sources = list(map(Path, (dossier_directory, source_package, runtime_package)))
    _destination(output, sources)
    original = read_tree(dossier_directory)
    dossier.verify(original, dossier_hash)
    with TemporaryDirectory(prefix='stream-tool-dossier-') as temporary:
        receipt = replay.run(source_package, source_hash, runtime_package, runtime_hash,
            runtime_recipe, runtime_recipe_hash, output=Path(temporary) / 'replay', timeout=timeout)
        result = _derive(original, dossier_hash, Path(source_package), Path(runtime_package),
            runtime_recipe, runtime_recipe_hash, source_hash, runtime_hash, dict(receipt.files), release_raw)
    _publish(dict(result.files), output, sources)
    return result


def inspect(files, expected_hash):
    """Verify all preserved bytes and source semantics; never run archived code."""
    files = dict(files)
    package._bounded(files)
    raw = files.get('manifest.json', b'')
    require(keccak256(raw) == expected_hash, 'tool supplement external manifest differs')
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {'schema', 'inputs', 'files', 'qualification'}
        and value['schema'] == NAME and value['qualification'] == QUALIFICATION
        and value['files'] == [package._ref(p, b) for p, b in sorted(files.items()) if p != 'manifest.json'],
        'tool supplement closed manifest differs')
    pins = value['inputs']
    require(type(pins) is dict and set(pins) == {'dossierManifestHash', 'sourcePartsSha256',
        'runtimePartsSha256', 'runtimeRecipeSha256', 'releaseEvidenceHash'}, 'tool supplement input pins differ')
    with TemporaryDirectory(prefix='stream-tool-inspection-') as temporary:
        root = Path(temporary)
        for name in ('source', 'runtime'):
            write_tree(_extract(files, 'tool/' + name + '/').items(), root / name)
        receipt = _extract(files, 'replay/')
        release_raw = files.get('release/source/evidence.json')
        require((None if release_raw is None else keccak256(release_raw)) == pins['releaseEvidenceHash'],
            'tool supplement release pin differs')
        result = _derive(_extract(files, 'dossier/'), pins['dossierManifestHash'], root / 'source',
            root / 'runtime', receipt['runtime-recipe.json'], pins['runtimeRecipeSha256'],
            pins['sourcePartsSha256'], pins['runtimePartsSha256'], receipt, release_raw)
        require(dict(result.files) == files, 'tool supplement full reconstruction differs')
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    build = commands.add_parser('assemble')
    for name in ('dossier', 'source-package', 'runtime-package', 'runtime-recipe', 'output'):
        build.add_argument('--' + name, required=True, type=Path)
    for name in ('dossier-hash', 'source-sha256', 'runtime-sha256', 'runtime-recipe-sha256', 'disclosure'):
        build.add_argument('--' + name, required=True)
    build.add_argument('--release-evidence', type=Path)
    build.add_argument('--timeout', type=int, default=900)
    for name in ('inspect', 'replay'):
        command = commands.add_parser(name)
        command.add_argument('directory', type=Path)
        command.add_argument('--manifest-hash', required=True)
        if name == 'replay':
            command.add_argument('--output', type=Path, required=True)
            command.add_argument('--timeout', type=int, default=900)
    args = parser.parse_args(argv)
    try:
        if args.command == 'assemble':
            require(args.disclosure == 'public', 'tool supplement public disclosure required before reads/execution')
            result = assemble(args.dossier, args.dossier_hash, args.source_package, args.source_sha256,
                args.runtime_package, args.runtime_sha256, args.runtime_recipe.read_bytes(),
                args.runtime_recipe_sha256, output=args.output, disclosure=args.disclosure,
                release_raw=args.release_evidence.read_bytes() if args.release_evidence else None, timeout=args.timeout)
            message = {'manifestHash': result.manifest_hash, 'archivedCodeExecutedThisRun': True}
        else:
            result = inspect(read_tree(args.directory), args.manifest_hash)
            if args.command == 'replay':
                pins = result.report['inputs']
                result = replay.run(args.directory / 'tool/source', pins['sourcePartsSha256'],
                    args.directory / 'tool/runtime', pins['runtimePartsSha256'],
                    (args.directory / 'replay/runtime-recipe.json').read_bytes(), pins['runtimeRecipeSha256'],
                    output=args.output, timeout=args.timeout)
                message = {'manifestHash': result.manifest_hash, 'archivedCodeExecutedThisRun': True}
            else:
                message = {'manifestHash': result.manifest_hash, 'archivedCodeExecutedThisRun': False,
                    'previousExecutionOriginAuthenticated': False, 'report': result.report}
        print(dumps(message).decode('utf-8'))
    except (MuseumError, ValueError, OSError, KeyError) as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
