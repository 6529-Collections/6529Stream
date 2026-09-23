"""Read-only current-token Museum composition from pinned original inputs.

The coordinated token recipe is admitted as a separate same-state capture.
V10 preservation, WORK/Metadata and recovery inputs must be supplied independently;
none are inferred from the recipe's base or native dossier output.
"""
import argparse
from pathlib import Path
from tempfile import TemporaryDirectory

from . import acquisition_canonical_v10 as acquisition
from . import canonical_current_assessment_v1 as current_v1
from . import canonical_current_assessment_v2 as current_v2
from . import canonical_native_inputs_v1 as native_inputs
from . import canonical_object_dossier_v3 as v3
from . import canonical_object_dossier_v4 as v4
from . import canonical_object_dossier_v5 as v5
from . import canonical_semantic_export_v2 as semantic
from . import current_token_dossier_capture as recipe
from . import current_token_offline_join_v1 as offline_join
from . import native_dossier_capture as native_capture
from . import native_multiformat_package_v2 as multiformat
from . import object_dossier as base
from . import token_fixture
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .repository_exchange import _destination, _rename_new


STAGES = ('native-inputs', 'v10', 'v3', 'semantic-v2', 'v4', 'v5',
          'current-v1', 'current-v2', 'four-formats')
STATE_KEYS = current_v1.STATE_KEYS
IDENTITY_KEYS = ('chainId', 'core', 'collectionId', 'tokenId',
                 'blockHash', 'blockNumber')
ANCHOR_KEYS = ('chainId', 'core', 'blockHash', 'blockNumber',
               'timestamp', 'stateRoot', 'environment')
MAX_RUN_BYTES = 1024 * 1024 * 1024


def _subtree(files, prefix):
    return {path.removeprefix(prefix): raw for path, raw in files.items()
        if path.startswith(prefix)}


def _paired(files, digest, label):
    require((files is None) == (digest is None),
        'current composition ' + label + ' directory and pin required together')


def native_transport(files, expected_hash):
    """Adapt only a closed original-file tree to the existing V10 transport."""
    files = dict(files)
    required = {'preservation/input.json', 'work/evidence.json',
        'recovery/evidence.json'} | {'work/metadata/' + name
        for name in native_inputs.METADATA_FILES}
    require(required <= files.keys() and all(path in required or
        path.startswith('work/condition/') for path in files),
        'current composition original native-source inventory differs')
    condition = _subtree(files, 'work/condition/')
    transport, digest = native_inputs.create(files['preservation/input.json'],
        files['work/evidence.json'],
        {name: files['work/metadata/' + name]
            for name in native_inputs.METADATA_FILES},
        files['recovery/evidence.json'], condition_files=condition or None)
    require(any(hex_bytes(expected_hash, 32)) and digest == expected_hash,
        'current composition external native-input transport pin differs')
    native_inputs.admit(transport, expected_hash)
    return transport


def _current_capture_state(summary_state, original_anchor, plan):
    """Bridge the V1 identity and its retained final anchor to nine current keys."""
    require(type(summary_state) is dict and type(original_anchor) is dict
        and type(plan) is dict and type(plan.get('sources')) is list,
        'current composition recipe source-state bridge shape differs')
    hosts = [row['anchor'] for row in plan['sources'] if row['id'] == 'hosts'
        and row['kind'] == 'hosts']
    require(len(hosts) == 1 and type(hosts[0]) is dict,
        'current composition recipe hosts anchor missing')
    host = hosts[0]
    require(all(summary_state.get(key) == original_anchor.get(key) == host.get(key)
        for key in ('chainId', 'core', 'blockHash', 'blockNumber'))
        and all(summary_state.get(key) == host.get(key)
            for key in ('collectionId', 'tokenId'))
        and all(type(original_anchor.get(key)) is str
            and all(type(row['anchor']) is dict
                and row['anchor'].get(key) == original_anchor[key]
                for row in plan['sources'])
            for key in ('timestamp', 'stateRoot', 'environment')),
        'current composition recipe original/native final anchor differs')
    return {key: summary_state[key] if key in IDENTITY_KEYS
        else original_anchor[key] for key in STATE_KEYS}


def admit_capture(directory, expected_hash):
    """Replay the existing recipe outputs; return its qualified source state."""
    directory = Path(directory)
    raw = _read_file(directory / 'recipe-result.json', MAX_MANIFEST, 'recipe result')
    require(any(hex_bytes(expected_hash, 32))
        and keccak256(raw) == expected_hash,
        'current composition external recipe result pin differs')
    summary = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(summary) is dict and summary.get('recipe') == recipe.RECIPE
        and summary.get('version') == '1'
        and summary.get('actualNativeCaptureAcceptance') is False
        and summary.get('fullObjectDossierConformance') is False,
        'current composition recipe result shape/qualification differs')
    retained_dir = directory / 'retained-token'
    require(retained_dir.is_dir() and not retained_dir.is_symlink()
        and not (hasattr(retained_dir, 'is_junction') and retained_dir.is_junction())
        and all((retained_dir / name).is_file()
            and not (retained_dir / name).is_symlink()
            for name in ('manifest.json', 'inputs.json.gz')),
        'current composition retained-token path differs')
    retained, _ = token_fixture.read(retained_dir,
        summary['retainedTokenManifestHash'])
    original = directory / 'original-token-capture'
    require(original.is_dir() and not original.is_symlink()
        and not (hasattr(original, 'is_junction') and original.is_junction()),
        'current composition original captured-token path differs')
    require(all((original / name).is_file() and not (original / name).is_symlink()
        and not (hasattr(original / name, 'is_junction')
            and (original / name).is_junction())
        and (original / name).stat().st_size == len(content)
        and (original / name).read_bytes() == content
        for name, content in retained.items()),
        'current composition original captured token bytes differ')
    assembled = base.verify(read_tree(directory / 'base-assembly'),
        summary['baseManifestHash'])
    require(_subtree(dict(assembled.files), 'source/retained/') ==
        {name: (directory / 'retained-token' / name).read_bytes()
            for name in ('manifest.json', 'inputs.json.gz')},
        'current composition base retained-token bytes differ')
    native_files = read_tree(directory / 'native-dossier')
    native = native_capture.verify(native_files, summary['nativeCaptureResultHash'])
    plan_raw = _read_file(directory / 'native-plan.json',
        MAX_MANIFEST, 'native plan')
    require(_subtree(native_files, 'assembly/base/') == dict(assembled.files)
        and keccak256(plan_raw) == summary['nativePlanHash']
        and native['planHash'] == summary['nativePlanHash'],
        'current composition native capture/base/plan differs')
    require(summary['sourceState'] == loads(assembled.manifest,
        maximum=MAX_MANIFEST, canonical=True)['sourceState'],
        'current composition recipe source state differs')
    return _current_capture_state(summary['sourceState'],
        loads(retained['anchor.json'], maximum=MAX_BYTES, canonical=True),
        loads(plan_raw, maximum=MAX_MANIFEST, canonical=True))


def _same_capture_state(capture_state, canonical_state):
    require(type(capture_state) is dict and all(
        capture_state.get(key) == canonical_state.get(key)
        for key in STATE_KEYS),
        'current composition recipe and canonical final source state differ')


def compose(prior_files, prior_hash, source_files, source_hash, selection_raw,
            selection_hash, format_plan_raw, format_plan_hash, *,
            capture_state=None, conservation_files=None, conservation_hash=None,
            production_files=None, production_hash=None,
            general_files=None, general_hash=None,
            transfer_files=None, transfer_hash=None,
            finality_files=None, finality_hash=None,
            entropy_files=None, entropy_hash=None,
            script_files=None, script_hash=None,
            owner_plan_files=None, owner_plan_hash=None):
    """Compose existing packages in dependency order and check the final join."""
    for label, files, digest in (
            ('conservation', conservation_files, conservation_hash),
            ('production', production_files, production_hash),
            ('general', general_files, general_hash),
            ('transfer', transfer_files, transfer_hash),
            ('finality', finality_files, finality_hash),
            ('entropy', entropy_files, entropy_hash),
            ('script', script_files, script_hash),
            ('owner plan', owner_plan_files, owner_plan_hash)):
        _paired(files, digest, label)
    transport = native_transport(source_files, source_hash)
    acquired = acquisition.compose(prior_files, prior_hash, transport,
        source_hash, disclosure='public')
    dossier = v3.compose(dict(acquired.files), acquired.manifest_hash,
        conservation_files=conservation_files, conservation_hash=conservation_hash,
        disclosure='public')
    semantic_result = semantic.build(dict(dossier.files), dossier.manifest_hash,
        selection_raw, selection_hash, disclosure='public',
        plan_files=owner_plan_files, plan_hash=owner_plan_hash)
    canonical = v4.compose(dict(semantic_result.files), semantic_result.manifest_hash,
        production_files=production_files, production_hash=production_hash,
        general_files=general_files, general_hash=general_hash,
        transfer_files=transfer_files, transfer_hash=transfer_hash,
        disclosure='public')
    if capture_state is not None:
        _same_capture_state(capture_state, canonical.report['sourceState'])
    reviewed = v5.compose(dict(canonical.files), canonical.manifest_hash,
        disclosure='public')
    assessed_v1 = current_v1.compose(dict(canonical.files), canonical.manifest_hash,
        finality_files=finality_files, finality_hash=finality_hash,
        entropy_files=entropy_files, entropy_hash=entropy_hash,
        disclosure='public')
    assessed_v2 = current_v2.compose(dict(assessed_v1.files),
        assessed_v1.manifest_hash, script_files=script_files,
        script_hash=script_hash, disclosure='public')
    exported = multiformat.compose(dict(canonical.files), canonical.manifest_hash,
        format_plan_raw, format_plan_hash, disclosure='public')
    joined = offline_join.check(transport, source_hash, dict(canonical.files),
        canonical.manifest_hash, dict(assessed_v2.files), assessed_v2.manifest_hash,
        dict(exported.files), exported.manifest_hash,
        v5_files=dict(reviewed.files), v5_hash=reviewed.manifest_hash)
    stages = dict(zip(STAGES, (transport, acquired, dossier, semantic_result,
        canonical, reviewed, assessed_v1, assessed_v2, exported)))
    pins = {name: source_hash if name == 'native-inputs' else stage.manifest_hash
        for name, stage in stages.items()}
    return stages, {'mode': 'current_token_read_only_composition', 'version': '1',
        'stageManifestHashes': pins, 'recipeSourceStateMatched': capture_state is not None,
        'offlineJoin': joined, 'sourceOriginAuthenticated': False,
        'actualCurrentCaptureAcceptance': False,
        'institutionalAcceptance': False,
        'qualification': 'Existing packages are independently composed from pinned '
        'original inputs; a separately admitted token recipe shares the final '
        'source state when supplied. The recipe is not substituted for V10 '
        'preservation, WORK/Metadata, recovery or prior acquisition sources.'}


def _read_file(path, maximum, label):
    path = Path(path)
    require(path.is_file() and not path.is_symlink() and
        not (hasattr(path, 'is_junction') and path.is_junction()),
        'current composition ' + label + ' must be a regular file')
    with path.open('rb') as handle:
        raw = handle.read(maximum + 1)
    require(0 < len(raw) <= maximum,
        'current composition ' + label + ' byte bound')
    return raw


def _publish(stages, report, output, sources):
    root = _destination(output, sources)
    total = sum(len(raw) for stage in stages.values()
        for raw in (stage.values() if type(stage) is dict else dict(stage.files).values()))
    require(total <= MAX_RUN_BYTES, 'current composition aggregate output bound')
    with TemporaryDirectory(prefix='.stream-current-compose-', dir=root.parent) as temporary:
        staged = Path(temporary) / 'result'
        staged.mkdir()
        for name, stage in stages.items():
            files = stage if type(stage) is dict else dict(stage.files)
            write_tree(files, staged / name)
            require(read_tree(staged / name) == files,
                'current composition staged ' + name + ' bytes differ')
        (staged / 'run-result.json').write_bytes(dumps(report))
        _destination(root, sources)
        _rename_new(staged, root)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for role in ('capture', 'prior', 'native-sources'):
        parser.add_argument('--' + role, type=Path, required=True)
    parser.add_argument('--capture-result-hash', required=True)
    parser.add_argument('--prior-hash', required=True)
    parser.add_argument('--native-inputs-hash', required=True)
    for role in ('selection', 'format-plan'):
        parser.add_argument('--' + role, type=Path, required=True)
        parser.add_argument('--' + role + '-hash', required=True)
    for role in ('conservation', 'production', 'general', 'transfer',
                 'finality', 'entropy', 'script', 'owner-plan'):
        parser.add_argument('--' + role, type=Path)
        parser.add_argument('--' + role + '-hash')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        sources = [args.capture, args.prior, args.native_sources,
            args.selection, args.format_plan]
        options = {}
        for role in ('conservation', 'production', 'general', 'transfer',
                     'finality', 'entropy', 'script', 'owner-plan'):
            path = getattr(args, role.replace('-', '_'))
            digest = getattr(args, role.replace('-', '_') + '_hash')
            _paired(path, digest, role)
            if path is not None: sources.append(path)
            key = role.replace('-', '_')
            options[key + '_files'] = None if path is None else read_tree(path)
            options[key + '_hash'] = digest
        _destination(args.output, sources)
        state = admit_capture(args.capture, args.capture_result_hash)
        selected = _read_file(args.selection, semantic.MAX_SELECTION, 'selection')
        plan = _read_file(args.format_plan, multiformat.MAX_PLAN, 'format plan')
        stages, report = compose(read_tree(args.prior), args.prior_hash,
            read_tree(args.native_sources), args.native_inputs_hash,
            selected, args.selection_hash, plan, args.format_plan_hash,
            capture_state=state, **options)
        report['recipeResultHash'] = args.capture_result_hash
        _publish(stages, report, args.output, sources)
    except (MuseumError, OSError, KeyError, TypeError, ValueError) as exc:
        parser.exit(2, 'current composition: ' + str(exc) + '\n')
    print(dumps(report).decode('utf-8'))


if __name__ == '__main__':
    main()
