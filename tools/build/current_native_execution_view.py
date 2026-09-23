"""An execution-only Forge cache view of independently authenticated native owners.

Original artifacts and full build-info are copied byte for byte. Only routing cache
entries are derived. Namespaced build-info filenames preserve each original source
ID map; they are not new compiler evidence. No compiler or EVM runs in this module.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import posixpath
from pathlib import Path, PurePosixPath
import sys

from tools.build import current_graph_owners as owned
from tools.build.prepare_current_graph import (
    CREATION_NAME, CREATION_SOURCE, helper_coordinate, host_coordinate, sha, source_closure,
)
from tools.build.scoped_standard_json import canonical, forge_abi_transport, forge_ast_transport, forge_storage_transport
from tools.build.native_execution_fixtures import stage_execution_project


def file_hash(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def require(value, message):
    if not value:
        raise ValueError(message)


def safe_relative(value: str) -> str:
    path = PurePosixPath(value)
    require(isinstance(value, str) and value and not path.is_absolute() and '..' not in path.parts
            and path.as_posix() == value and '\\' not in value and ':' not in value,
            f'Unsafe relative path: {value!r}')
    return value


def file_inventory(root: Path) -> dict[str, str]:
    require(root.is_dir(), f'Missing evidence directory: {root}')
    result = {}
    for path in sorted(root.rglob('*')):
        require(not path.is_symlink() and not path.is_junction(), f'Link in evidence directory: {path}')
        if path.is_file():
            result[path.relative_to(root).as_posix()] = file_hash(path)
    return result


def require_disjoint(destination: Path, originals: list[Path]):
    destination = destination.resolve()
    for original in originals:
        original = original.resolve()
        require(not (destination.is_relative_to(original) or original.is_relative_to(destination)),
                f'Execution view overlaps original evidence: {original}')


def executable_equal(physical: dict, native: dict, source: dict, coord: str):
    """Same transports as the canonical exporter; no executable-field normalization."""
    fields = {'abi', 'bytecode', 'deployedBytecode', 'methodIdentifiers', 'rawMetadata', 'metadata', 'ast', 'id'}
    if 'storageLayout' in native:
        fields.add('storageLayout')
    require(set(physical) == fields, f'Physical artifact fields differ: {coord}')
    forge_abi_transport(native['abi'], physical['abi'])
    forge_ast_transport(source['ast'], physical['ast'])
    require(physical['id'] == source['id'], f'Physical source ID differs: {coord}')
    require(physical['methodIdentifiers'] == native['evm']['methodIdentifiers'], f'Method IDs differ: {coord}')
    metadata = json.loads(native['metadata'])
    require(json.loads(physical['rawMetadata']) == metadata
            and physical['metadata']['settings']['compilationTarget'] == metadata['settings']['compilationTarget'],
            f'Physical metadata differs: {coord}')
    if 'storageLayout' in native:
        forge_storage_transport(native['storageLayout'], physical['storageLayout'])
    for field in ('bytecode', 'deployedBytecode'):
        current, original = physical[field], native['evm'][field]
        require(set(current) <= {'object', 'sourceMap', 'linkReferences', 'immutableReferences'},
                f'Unknown executable field: {coord}:{field}')
        require(current['object'].removeprefix('0x') == original['object'].removeprefix('0x'),
                f'Physical bytecode differs: {coord}:{field}')
        for key in ('sourceMap', 'linkReferences', 'immutableReferences'):
            require(current.get(key, {}) == original.get(key, {}), f'Physical {key} differs: {coord}:{field}')


def abi_cases(abi: list) -> list[str]:
    def typename(item):
        value = item['type']
        return '(' + ','.join(typename(x) for x in item['components']) + ')' + value[5:] if value.startswith('tuple') else value
    cases = [row['name'] + '(' + ','.join(typename(x) for x in row['inputs']) + ')'
             for row in abi if row['type'] == 'function' and row['name'].startswith(('test', 'invariant_'))]
    require(cases and len(cases) == len(set(cases)), 'Empty or duplicate native ABI test roster')
    return sorted(cases)


def authenticate(project: Path, products_path: Path, config: Path, preparation: Path,
                 preparation_sha256: str, entrypoints: dict[str, str]) -> dict:
    """Rejoin original evidence, not a merged cache or caller-supplied successful status."""
    require(not sys.flags.optimize, 'Execution views require enabled Python assertions')
    require(entrypoints, 'Explicit entrypoints required')
    for coord, kind in entrypoints.items():
        require(kind in ('test', 'helper'), f'Unsupported entrypoint kind: {kind}')
        (host_coordinate if kind == 'test' else helper_coordinate)(coord)
    raw = preparation.read_bytes()
    require(sha(raw) == preparation_sha256, 'Canonical preparation hash differs')
    proof = owned.strict_json(raw)
    require(proof.get('mode') == 'explicit-native-owners', 'Explicit canonical native-owner preparation required')
    products = owned.strict_json(products_path.read_bytes())
    projection_mode = proof.get('projectionMode', 'flat')
    require(projection_mode in ('flat', 'none'), 'Unknown projection mode')
    require(projection_mode != 'none' or products == {}, 'Export-only preparation cannot have projection products')
    data = owned.owner_manifest(owned.strict_json(config.read_bytes()), products,
                               tuple(owned.coordinate(c) for c in entrypoints),
                               None if projection_mode == 'none' else CREATION_SOURCE + ':' + CREATION_NAME)
    require(proof['ownerManifestSha256'] == file_hash(config), 'Owner manifest differs from preparation')
    contexts = {label: owned.load_context(project, config, label, row, data['owners'])
                for label, row in data['contexts'].items()}
    owned.validate_owner_joins(contexts, data['owners'], products)
    literals = owned.literal_artifact_inventory(contexts, data['owners'])
    identities = {coord: contexts[label]['identity'] for coord, label in data['owners'].items()}
    require(proof['owners'] == identities and proof['literalArtifactSources'] == literals,
            'Canonical preparation owner/literal inventory differs')
    require(set(proof['compilerContexts']) == {c['identity'] for c in contexts.values()}, 'Prepared context inventory differs')
    manifests = []
    for relative in (() if projection_mode == 'none' else ('artifacts/current-graph/compiled', 'artifacts/native-assembly/compiled')):
        folder = project / relative
        manifest = owned.strict_json((folder / 'manifest.json').read_bytes())
        require(file_hash(folder / 'manifest.json') == proof['projectionManifestSha256'], 'Projection manifest changed')
        require(manifest['mode'] == 'explicit-native-owners' and manifest['owners'] == identities, 'Projection ownership differs')
        require(set(manifest['products']) == set(products), 'Projection products differ')
        require(set(file_inventory(folder)) == {n + '.json' for n in products} | {'manifest.json'}, 'Unexpected projection files')
        for name, source in products.items():
            row = manifest['products'][name]; payload = (folder / (name + '.json')).read_bytes()
            require(row['source'] == source and row['owner'] == identities[source + ':' + name]
                    and row['projectionSha256'] == sha(payload) and row['projectionBytes'] == len(payload),
                    f'Projection changed: {name}')
        manifests.append(folder)
    cases = {}; sources = {}; caps = {}; artifacts = {}; protected = {}
    for label, context in contexts.items():
        retained = proof['compilerContexts'][context['identity']]
        for key, value in context['identityFields'].items():
            require(retained[key] == value, f'Prepared context identity differs: {label}:{key}')
        require(retained['compilerCapture'] == context['captureEvidence'], f'Prepared capture differs: {label}')
        require(retained['physicalArtifactHashes'] == {str(p): h for p, h in context['physical'].items()},
                f'Prepared physical inventory changed: {label}')
        exports = Path(retained['nativeExports'])
        export_manifest = owned.strict_json((exports / 'manifest.json').read_bytes())
        require(export_manifest['currentBuildInfoSha256'] == context['identityFields']['buildInfoSha256']
                and export_manifest['compilerCapture'] == context['captureEvidence'], 'Native export owner differs')
        require(set(export_manifest['products']) == set(context['inventory']), 'Export coordinate inventory differs')
        # Every selected production emission keeps the original strict runtime/base-init limits.
        for source, contracts in context['build']['output']['contracts'].items():
            if not source.startswith('smart-contracts/'):
                continue
            for name, native in contracts.items():
                sizes = {field: len(native['evm'][field]['object'].removeprefix('0x')) // 2
                         for field in ('bytecode', 'deployedBytecode')}
                require(sizes['deployedBytecode'] <= 24576 and sizes['bytecode'] <= 49152,
                        f'Native production size limit: {source}:{name}: {sizes}')
                caps[context['identity'] + '/' + source + ':' + name] = sizes
        for coord, owner in data['owners'].items():
            if owner != label:
                continue
            source, name = owned.coordinate(coord)
            physical = context['out'] / Path(source).name / (name + '.json')
            native = context['build']['output']['contracts'][source][name]
            executable_equal(owned.strict_json(physical.read_bytes()), native, context['build']['output']['sources'][source], coord)
            exported = export_manifest['products'][name]
            require(exported['source'] == source and exported['originalPhysicalArtifactSha256'] == file_hash(physical),
                    f'Native export physical binding differs: {coord}')
            export_path = exports / safe_relative(exported['currentExport'])
            require(file_hash(export_path) == exported['currentNativeExportSha256'], f'Native export changed: {coord}')
            executable_equal(owned.strict_json(export_path.read_bytes()), native, context['build']['output']['sources'][source], coord)
            artifacts[coord] = {'owner': context['identity'], 'original': str(physical), 'sha256': file_hash(physical)}
            if entrypoints.get(coord) == 'test':
                cases[coord] = abi_cases(native['abi'])
        for source in source_closure(context['build'], context['roots'], analysis=context['analysis']):
            path = project / safe_relative(source)
            value = file_hash(path)
            require(source not in sources or sources[source] == value, f'Conflicting source: {source}')
            sources[source] = value
        for folder in (context['out'], context['cache'], context['capture'], exports):
            protected[str(folder)] = file_inventory(folder)
    for folder in manifests:
        protected[str(folder)] = file_inventory(folder)
    return {'contexts': contexts, 'owners': data['owners'], 'products': products, 'cases': cases,
            'sources': sources, 'artifacts': artifacts, 'protectedDirectories': protected,
            'productionSizes': caps, 'literalArtifactSources': literals}


def prove_unused_library_roots(contexts: dict, original: list, target: list) -> dict:
    """Prove a search-root-only routing change has no library lookup dependency.

    Every original source must be represented in the authenticated analysis, and
    every import must be literal relative syntax resolving to that same source
    universe/SourceUnit ID. Analysis is discovery evidence only, never bytecode.
    """
    for roots in (original, target):
        require(isinstance(roots, list) and all(isinstance(root, str) for root in roots), 'Invalid library search roots')
        require(len(roots) == len({root.casefold() for root in roots}), 'Duplicate library search roots')
        for root in roots:
            safe_relative(root)
            require(root != '.', 'Project root cannot be transported as an unused library root')
    changed = set(original) ^ set(target)
    if not changed and original != target:
        changed = set(original)  # A reordered search path must also be demonstrably unused.
    source_counts = {}; import_counts = {}
    for label, context in contexts.items():
        sources = context['build']['input']['sources']
        asts = (context['analysis'] or context['build'])['output']['sources']
        imports = 0
        for source in sources:
            safe_relative(source)
            require(not any(source.casefold() == root.casefold() or source.casefold().startswith(root.casefold() + '/')
                            for root in changed), f'Changed library root contains a native source: {source}')
            ast = asts.get(source, {}).get('ast')
            require(isinstance(ast, dict) and ast.get('absolutePath') == source,
                    f'Library-root transport lacks authenticated source AST: {source}')
            for node in ast['nodes']:
                if node.get('nodeType') != 'ImportDirective':
                    continue
                literal = node.get('file')
                require(isinstance(literal, str) and literal.startswith(('./', '../'))
                        and '\\' not in literal and ':' not in literal,
                        f'Library-root transport requires literal relative imports: {source}')
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(source), literal))
                safe_relative(resolved)
                require(resolved == node.get('absolutePath') and resolved in sources,
                        f'Library-root import resolution differs: {source}: {literal}')
                imported = asts.get(resolved, {}).get('ast')
                require(isinstance(imported, dict) and imported.get('absolutePath') == resolved
                        and type(node.get('sourceUnit')) is int and node['sourceUnit'] == imported.get('id'),
                        f'Library-root import SourceUnit differs: {source}: {literal}')
                imports += 1
        source_counts[label] = len(sources); import_counts[label] = imports
    return {'original': original, 'target': target, 'unusedChangedRoots': sorted(changed),
            'sourceCounts': source_counts, 'relativeImportCounts': import_counts}


def cache_transport(contexts: dict, assignments: dict, destination: Path, *,
                    routing: dict | None = None, project: Path | None = None,
                    transport_report: dict | None = None) -> tuple[dict, dict, dict]:
    """Only cache paths/build routing changes; compiler data is never combined."""
    cache = None; files = {}; origins = {}; copies = {}; paths_seen = set(); source_hashes = {}
    target = None; library_transports = {}
    if routing is not None:
        require(set(routing) == {'context', 'profile'} and routing['context'] in contexts, 'Invalid explicit cache routing')
        target = owned.strict_json(contexts[routing['context']]['cacheRaw'])
        require(routing['profile'] in target['profiles'], 'Unknown target cache profile')
        cache = {k: copy.deepcopy(v) for k, v in target.items() if k not in ('files', 'builds')}
        target_semantics = {k: v for k, v in target['profiles'][routing['profile']]['solc'].items() if k != 'outputSelection'}
    for label, context in contexts.items():
        original = owned.strict_json(context['cacheRaw'])
        require(original.get('preprocessed') is False and original.get('mocks') == [], 'Preprocessed/mock caches unsupported')
        header = {k: v for k, v in original.items() if k not in ('files', 'paths', 'builds')}
        if target is not None:
            require({k:v for k,v in header.items() if k != 'profiles'}
                    == {k:v for k,v in cache.items() if k not in ('paths', 'profiles')}, 'Cache format transport differs')
            require({k:v for k,v in original['paths'].items() if k not in ('artifacts', 'build_infos', 'tests', 'scripts', 'libraries')}
                    == {k:v for k,v in target['paths'].items() if k not in ('artifacts', 'build_infos', 'tests', 'scripts', 'libraries')},
                    'Cache source layout differs')
            if original['paths']['libraries'] != target['paths']['libraries']:
                library_transports[label] = prove_unused_library_roots(contexts, original['paths']['libraries'], target['paths']['libraries'])
            native_semantics = {k:v for k,v in context['build']['input']['settings'].items() if k != 'outputSelection'}
            require(native_semantics == target_semantics, 'Target routing profile differs from native compiler settings')
        elif cache is None:
            cache = copy.deepcopy(header); cache['paths'] = copy.deepcopy(original['paths'])
        else:
            require(header == {k: v for k, v in cache.items() if k != 'paths'}, 'Cache profiles/settings differ')
            require({k: v for k, v in original['paths'].items() if k not in ('artifacts', 'build_infos')}
                    == {k: v for k, v in cache['paths'].items() if k not in ('artifacts', 'build_infos')},
                    'Cache source layout differs')
        closure = source_closure(context['build'], context['roots'], analysis=context['analysis'])
        admitted = set(closure)
        if project is not None:
            # Forge visits all src files even with an exact test filter. Retain only
            # genuine source-only bookkeeping whose whole original import closure
            # is current. These rows never add physical artifacts or declarations.
            asts = (context['analysis'] or context['build'])['output']['sources']
            fresh = {}
            for source in set(original['files']) & set(context['build']['input']['sources']):
                path = project / safe_relative(source)
                if not path.is_file():
                    continue
                raw = path.read_bytes(); literal = context['build']['input']['sources'][source]['content'].encode('utf-8')
                if raw == literal or raw.replace(b'\r\n', b'\n') == literal:
                    fresh[source] = sha(raw)
            valid = set(fresh)
            while True:
                invalid = {source for source in valid if 'ast' not in asts.get(source, {})
                           or asts[source]['ast'].get('absolutePath') != source
                           or any(node['absolutePath'] not in valid for node in asts[source]['ast']['nodes']
                                  if node.get('nodeType') == 'ImportDirective')}
                if not invalid:
                    break
                valid -= invalid
            require(closure <= valid, 'Assigned source closure changed during cache transport')
            admitted.update(valid)
            for source in admitted:
                require(source not in source_hashes or source_hashes[source] == fresh[source], 'Routing source changed')
                source_hashes[source] = fresh[source]
        for source in sorted(admitted):
            require(source in original['files'], f'Missing source cache entry: {source}')
            entry = copy.deepcopy(original['files'][source])
            require(entry['sourceName'].replace('\\', '/') == source and entry['seenByCompiler'] is True,
                    f'Uncompiled/misbound cache source: {source}')
            entry['artifacts'] = {}
            # Timestamps are not content identity. Preserve the first original timestamp.
            comparison = {k: v for k, v in entry.items() if k not in ('lastModificationDate', 'artifacts')}
            comparison['imports'] = sorted(p.replace('\\', '/') for p in comparison['imports'])
            if source in origins:
                require(origins[source] == comparison, f'Conflicting cached source: {source}')
            else:
                origins[source] = comparison; files[source] = entry
        ident = context['identity']
        copies['build-info/' + ident + '.json'] = context['path']
        for coord, owner in assignments.items():
            if owner != label:
                continue
            source, name = owned.coordinate(coord)
            relative = Path(source).name + '/' + name + '.json'
            require(relative.casefold() not in paths_seen, f'Colliding physical artifact destination: {relative}')
            paths_seen.add(relative.casefold())
            entries = original['files'][source]['artifacts'][name]
            require(set(entries) == {'0.8.19'} and len(entries['0.8.19']) == 1, f'Ambiguous artifact profile: {coord}')
            profile, row = next(iter(entries['0.8.19'].items()))
            require(row['build_id'] == context['buildId'] and row['path'].replace('\\', '/') == relative,
                    f'Foreign cached artifact: {coord}')
            if target is not None:
                original_semantics = {k:v for k,v in original['profiles'][profile]['solc'].items() if k != 'outputSelection'}
                require(original_semantics == target_semantics, f'Artifact profile compiler semantics differ: {coord}')
                profile = routing['profile']
            files[source]['artifacts'][name] = {'0.8.19': {profile: {'path': relative, 'build_id': ident}}}
            copies[relative] = context['out'] / relative
        # A copied original full build-info is interpreted only as BuildContext by Forge.
        original_build = owned.strict_json(context['raw'])
        native_map = {str(v['id']): s for s, v in context['build']['output']['sources'].items()}
        require(original_build['source_id_to_path'] == native_map and original_build['language'] == 'Solidity',
                'Original native BuildContext differs from source IDs')
    cache['files'] = files; cache['builds'] = sorted(c['identity'] for c in contexts.values())
    cache['paths']['artifacts'] = str((destination / 'out').resolve())
    cache['paths']['build_infos'] = str((destination / 'out/build-info').resolve())
    # Report the proof outside the Forge cache; do not add compiler/cache fields.
    if transport_report is not None:
        transport_report.update(library_transports)
    return cache, copies, source_hashes


def routing_cache_hash(cache: dict) -> str:
    """Only normalize separators in known path fields, never values or ownership."""
    value = copy.deepcopy(cache)
    value['paths'] = {k: ([p.replace('\\', '/') for p in v] if isinstance(v, list)
                           else v.replace('\\', '/')) for k, v in value['paths'].items()}
    normalized = {}
    for source, entry in value['files'].items():
        key = source.replace('\\', '/')
        require(key not in normalized, 'Colliding cache source paths')
        entry['sourceName'] = entry['sourceName'].replace('\\', '/')
        entry['imports'] = sorted(p.replace('\\', '/') for p in entry['imports'])
        for versions in entry['artifacts'].values():
            for profiles in versions.values():
                for row in profiles.values():
                    row['path'] = row['path'].replace('\\', '/')
        normalized[key] = entry
    value['files'] = normalized
    return sha(canonical(value))


def recheck_execution_project(project: Path, expected: dict[str, str]):
    require(file_inventory(project) == expected,
            'Execution-only project or authenticated fixtures changed')


def recheck(snapshot: dict):
    for folder, expected in snapshot['protectedDirectories'].items():
        require(file_inventory(Path(folder)) == expected, f'Original native evidence changed: {folder}')
    for path, expected in snapshot['inputFiles'].items():
        require(file_hash(Path(path)) == expected, f'Execution input changed: {path}')
    root = Path(snapshot['view'])
    if snapshot.get('executionProject'):
        recheck_execution_project(Path(snapshot['executionProject']), snapshot['executionProjectFiles'])
    require(file_inventory(root / 'out') == snapshot['viewArtifacts'], 'Execution artifacts changed')
    current = file_inventory(root / 'cache')
    require(set(current) == set(snapshot['viewCache']), 'Execution cache file inventory changed')
    require(routing_cache_hash(owned.strict_json((root / 'cache/solidity-files-cache.json').read_bytes()))
            == snapshot['routingCacheSha256'], 'Execution cache routing changed')
    for folder, expected in snapshot.get('inputDirectories', {}).items():
        require((not Path(folder).exists()) if expected is None else file_inventory(Path(folder)) == expected,
                f'Execution input directory changed: {folder}')


def prepare_view(project: Path, products: Path, owners: Path, preparation: Path, preparation_sha256: str,
                 destination: Path, entrypoints: dict[str, str], *, inputs: tuple[Path, ...] = (),
                 routing: dict | None = None, source_repo: Path | None = None,
                 source_commit: str | None = None) -> dict:
    project = project.resolve(); destination = destination.resolve()
    require(not destination.exists(), 'Execution view must be a new directory')
    evidence = authenticate(project, products, owners, preparation, preparation_sha256, entrypoints)
    originals = [Path(p) for p in evidence['protectedDirectories']]
    require_disjoint(destination, originals + [owners, products, preparation, project / 'foundry.toml'])
    require(not project.is_relative_to(destination), 'Execution view cannot contain the project')
    require((source_repo is None) == (source_commit is None),
            'Exact source repository and commit must be supplied together')
    library_transports = {}
    cache, copies, routing_sources = cache_transport(evidence['contexts'], evidence['owners'], destination,
        routing=routing, project=project, transport_report=library_transports)
    input_files = {str((project / s).resolve()): h for s, h in evidence['sources'].items()}
    input_files.update({str((project / s).resolve()): h for s, h in routing_sources.items()})
    for context in evidence['contexts'].values():
        input_files.update(context['captureEvidence'].get('authenticatedFiles', {}))
    input_directories = {}
    for relative in ('test/fixtures', 'deployments', 'schemas', 'docs/schemas/finality', 'docs/schemas/preservation'):
        path = project / relative
        input_directories[str(path)] = file_inventory(path) if path.is_dir() else None
    for path in (owners, products, preparation, project / 'foundry.toml', *inputs):
        path = path.resolve()
        if path.is_dir():
            input_directories[str(path)] = file_inventory(path)
            for name, digest in input_directories[str(path)].items():
                input_files[str(path / name)] = digest
        else:
            input_files[str(path)] = file_hash(path)
    # Seal tool implementation, not only artifacts. No edit between prepare and dispatch.
    tool_root = Path(__file__).resolve().parents[2]
    for relative in ('tools/build/current_native_execution_view.py', 'tools/build/current_graph_owners.py',
                     'tools/build/prepare_current_graph.py', 'tools/build/scoped_standard_json.py',
                     'tools/build/native_capture.py', 'tools/build/partition_native_capture.py',
                     'tools/build/native_execution_fixtures.py',
                     'test/helpers/native_assembly_artifacts.py', 'test/helpers/native_assembly_native_exports.py',
                     'tools/development/run_native_execution_view.py', 'tools/development/run_current_acceptance.py'):
        path = tool_root / relative
        input_files[str(path)] = file_hash(path)
    remappings = project / 'remappings.txt'
    if remappings.exists():
        input_files[str(remappings)] = file_hash(remappings)
    destination.mkdir(parents=True)
    fixture_source = None
    if source_repo is not None:
        fixture_source = stage_execution_project(project, destination / 'project', evidence['sources'],
                                                 source_repo, source_commit)
    for relative, original in copies.items():
        target = destination / 'out' / relative
        target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(original.read_bytes())
        require(file_hash(target) == file_hash(original), f'Artifact copy differs: {relative}')
    (destination / 'cache').mkdir()
    (destination / 'cache/solidity-files-cache.json').write_bytes(canonical(cache))
    result = {'version': 1, 'status': 'PREPARED_EXECUTION_VIEW', 'project': str(project), 'view': str(destination),
              'routingTransport': routing, 'routingSourceHashes': routing_sources,
              'librarySearchRootTransports': library_transports, 'entrypoints': entrypoints, 'expectedCases': evidence['cases'], 'artifacts': evidence['artifacts'],
              'productionSizes': evidence['productionSizes'], 'literalArtifactSources': evidence['literalArtifactSources'],
              'preparationSha256': preparation_sha256, 'inputFiles': input_files,
              'inputDirectories': input_directories, 'routingCacheSha256': routing_cache_hash(cache),
              'protectedDirectories': evidence['protectedDirectories'],
              'viewArtifacts': file_inventory(destination / 'out'), 'viewCache': file_inventory(destination / 'cache'),
              'qualification': 'Execution-only cache routing; original physical artifacts and full build-info copied unchanged. '
              'Derived cache JSON permits only representation/key order and known path separator normalization. '
              'Build-context filename keys are full owner identities, not new compiler evidence. '
              'Base initcode/runtime limits only; constructor arguments, deployed code and test results require runtime evidence. '
              'Helper/script authentication is supported; Forge script execution is not supported.'}
    if fixture_source is not None:
        result['executionProject'] = str(destination / 'project')
        result['executionProjectFiles'] = file_inventory(destination / 'project')
        result['authenticatedFixtureSource'] = fixture_source
    for context in evidence['contexts'].values():
        owned.recheck_context(project, context)
    recheck(result)
    (destination / 'execution-view.json').write_bytes(canonical(result))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('project', 'products', 'owners', 'preparation', 'destination'):
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--preparation-sha256', required=True)
    parser.add_argument('--host', action='append', default=[], type=host_coordinate)
    parser.add_argument('--entrypoint', action='append', default=[], type=helper_coordinate)
    parser.add_argument('--routing-context', help='Explicit source cache for execution profile/path routing')
    parser.add_argument('--routing-profile', help='Target profile in the selected routing context')
    parser.add_argument('--input', action='append', default=[], type=Path, help='Additional fixture file/directory to seal')
    parser.add_argument('--source-repo', type=Path, help='Git repository containing exact fixture source commit')
    parser.add_argument('--source-commit', help='Exact source commit for read permissions and non-Solidity fixtures')
    args = parser.parse_args()
    coordinates = [(s + ':' + n, kind) for kind, items in [('test', args.host), ('helper', args.entrypoint)] for s, n in items]
    require(len(coordinates) == len(dict(coordinates)), 'Duplicate entrypoint')
    require(bool(args.routing_context) == bool(args.routing_profile), 'Both routing context and profile are required')
    routing = {'context': args.routing_context, 'profile': args.routing_profile} if args.routing_context else None
    result = prepare_view(args.project, args.products, args.owners, args.preparation, args.preparation_sha256,
                          args.destination, dict(coordinates), inputs=tuple(args.input), routing=routing,
                          source_repo=args.source_repo, source_commit=args.source_commit)
    print(json.dumps({'status': result['status'], 'artifacts': len(result['artifacts']), 'expectedCases': result['expectedCases']}))


if __name__ == '__main__':
    main()
