"""All-owner-family semantic selection and expansion of a canonical dossier.

This is an additive export. It keeps the exact V3 dossier, native authorities,
all original evidence and the fixed forty-nine requirements. Its new manifest
commits to children and earlier inputs only, never to its own enclosing package.
"""
import argparse
from pathlib import Path
from tempfile import TemporaryDirectory

from . import canonical_object_dossier_v3 as dossier
from . import canonical_semantic_sources_v2 as sources
from . import canonical_semantic_projection_v2 as projection
from . import genesis_registry_plan_v1 as owner_definitions
from . import conservation_semantic_graph_v1 as conservation
from . import object_dossier as package
from . import object_dossier_inventory as requirements
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .package_v2 import _dependencies
from .preservation_graph import VALIDATION_HASH

NAME = 'STREAM_MUSEUM_CANONICAL_SEMANTIC_EXPORT_V2'
MODE = 'canonical_native_semantic_export_v2'
MANIFEST_PATH = 'semantic/export-manifest.json'
INVENTORY_PATH = 'inputs/source-inventory.json'
SELECTION_PATH = 'inputs/selection.json'
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
MAX_SELECTION = 1024 * 1024
OWNER_PLAN_PREFIX = 'definitions/owner-genesis-plan/'
CLAIMS = {
    'canonicalDossierReplayed': True, 'originalSourceBytesRetained': True,
    'fixedNativeOccurrenceInventoryBeforeSelection': True,
    'originalAuthorityPreserved': True, 'deterministicOfflineExpansion': True,
    'allFortyNineDossierRequirementsRetained': True,
    'acyclicExportCommitments': True, 'currentAuthorityInferred': False,
    'sourceOriginAuthenticated': False, 'fullMuseumConformance': False,
    'completeCanonicalDossier': False, 'profileRegistered': False,
    'preservedToolArchive': False, 'institutionalAcceptance': False,
    'legalTitleProven': False, 'networkFetch': False,
    'allNamedOwnerFamiliesSupported': True, 'unknownOwnerRowsRetained': True,
    'ownerDefinitionRegistrationObservedHere': False,
    'specializedNoticeTransitionsInferred': False,
    'redemptionFulfillmentInferred': False,
}
QUALIFICATION = (
    'Semantic interpretation and selection within the exact replayed canonical V3 source. '
    'Native WORK, all ten named owner families, future admitted owner types and condition statements keep distinct '
    'selectors, authority and currentness. Every admitted occurrence remains in the inventory '
    'before selection. Conservation remains its separately verified attributed graph. '
    'Structural Linked Art validation and reproducible expansion do not establish current '
    'authority, legal title, source origin, consensus, global record completeness, profile '
    'registration, preserved execution tooling or institutional acceptance. The exact frozen '
    '51-definition plan supplies interpretation bytes and does not prove a live registration. '
    'Unsupported owner encodings remain opaque; historical family statements do not establish '
    'operative steward/recovery state or redemption fulfillment.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '2', 'mode': MODE,
    'sourceDossierProfileHash': dossier.PROFILE_HASH,
    'sourceInventoryProfileHash': sources.PROFILE_HASH,
    'projectionProfileHash': projection.PROFILE_HASH,
    'validationPolicyHash': VALIDATION_HASH,
    'requirementsHash': requirements.REQUIREMENTS_HASH,
    'ownerDefinitionPlanProfileHash': owner_definitions.PROFILE_HASH,
    'retention': 'Exact original dossier under input/; exact caller selection under inputs/.',
    'disclosure': 'Explicit public-only source and export. No restricted-data adapter or authorization inference.',
    'hashGraph': 'Earlier source and selection -> semantic children -> export manifest -> package envelope. No later publication or enclosing-manifest hash is a source input.',
    'verification': 'Replay concrete source, reconstruct inventory before selection, expand with retained pinned model, compare every byte.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'canonical semantic export requires public disclosure before reads')


def _conservation_family(originals):
    """Reference the exact already replayed family without rewriting its path scope."""
    prefix = 'conservation/'
    if prefix + 'manifest.json' not in originals:
        return {'status': 'not_supplied', 'originalPathBase': None, 'documents': []}
    names = [name for name in originals if name.startswith(prefix + conservation.OUTPUT_PREFIX)]
    require(names and all(prefix + path in originals for path in (
        conservation.INDEX_PATH, conservation.PROVENANCE_PATH,
        conservation.SIDECAR_PATH, conservation.COVERAGE_PATH, conservation.REPORT_PATH)),
        'canonical semantic conservation graph missing')
    return {'status': 'retained_separately_verified_family', 'originalPathBase': 'input/conservation/',
        'documents': [package._ref('input/' + path, originals[path]) for path in sorted(names)],
        'qualification': conservation.QUALIFICATION}


def _plan(plan_files, plan_hash):
    require((plan_files is None) == (plan_hash is None),
        'canonical semantic owner definition files and pin must be supplied together')
    if plan_files is None:
        prepared = owner_definitions.prepare()
        plan_files, plan_hash = dict(prepared.files), prepared.manifest_hash
    return owner_definitions.admit(dict(plan_files), plan_hash)


def prepare_selection(files, source_hash, *, disclosure, plan_files=None, plan_hash=None):
    """Replay first, then return a source-bound default policy for review."""
    _public(disclosure)
    plan = _plan(plan_files, plan_hash)
    _, inventory = sources.admit(files, source_hash,
        plan_files=dict(plan.files), plan_hash=plan.manifest_hash)
    return projection.default_selection(inventory,
        plan_files=dict(plan.files), plan_hash=plan.manifest_hash)


def _build(files, source_hash, selection_raw, selection_hash, *, disclosure, model_root,
           plan_files, plan_hash):
    _public(disclosure)
    require(type(selection_raw) is bytes and len(selection_raw) <= MAX_SELECTION
        and any(hex_bytes(selection_hash, 32)) and keccak256(selection_raw) == selection_hash,
        'canonical semantic selection commitment or bound differs')
    plan = _plan(plan_files, plan_hash)
    retained_plan = dict(plan.files)
    checked, inventory = sources.admit(files, source_hash,
        plan_files=retained_plan, plan_hash=plan.manifest_hash)
    originals = dict(checked.files)
    root = Path(model_root).resolve()
    dependencies = _dependencies(root, recorded=True)
    mapped = projection.render(inventory, selection_raw, selection_hash, model_root=root,
        plan_files=retained_plan, plan_hash=plan.manifest_hash)
    require(type(mapped) is dict and mapped and all(path.startswith('semantic/') for path in mapped)
        and MANIFEST_PATH not in mapped, 'canonical semantic projection output paths differ')
    package._bounded(mapped)
    files = {'input/' + path: raw for path, raw in originals.items()}
    files.update(dependencies)
    files.update(mapped)
    files[INVENTORY_PATH] = dumps(inventory)
    files[SELECTION_PATH] = selection_raw
    files['definitions/export-profile.json'] = PROFILE_BYTES
    files['definitions/source-profile.json'] = sources.PROFILE_BYTES
    files['definitions/projection-profile.json'] = projection.PROFILE_BYTES
    files['definitions/requirements.json'] = requirements.REQUIREMENTS_BYTES
    native_definitions = sources.definition_files(plan_files=retained_plan,
        plan_hash=plan.manifest_hash)
    require(all(path.startswith(('definitions/native-source/', OWNER_PLAN_PREFIX))
        or path == 'definitions/owner-family-profile.json' for path in native_definitions)
        and not set(files).intersection(native_definitions), 'canonical semantic source definition paths differ')
    files.update(native_definitions)
    dependency_rows = [package._ref(path, raw) for path, raw in sorted(files.items())
        if path.startswith(('dependencies/', 'definitions/'))]
    files['semantic/dependency-lock.json'] = dumps(dependency_rows)
    files['semantic/conservation-family.json'] = dumps(_conservation_family(originals))
    files['semantic/source-locations.json'] = dumps({
        'sourceDossierManifestHash': source_hash, 'originalSourcePathBase': 'input/',
        'scope': 'Original source-file pointers in the derived inventory and projection provenance are relative to the unchanged V3 dossier below input/. ownerDefinitions document paths and export document references are package-relative; they identify the separately retained frozen interpretation plan.',
        'sourceDocuments': [package._ref('input/' + path, raw) for path, raw in sorted(originals.items())],
        'originalReferencesRewritten': False})
    # Requirements stay as the original dossier assessed them; a narrower new
    # semantic family cannot promote global or institutional obligations.
    assessment = loads(originals['dossier/requirements.json'], maximum=MAX_BYTES, canonical=True)
    require(len(assessment['results']) == 49 and assessment['counts']['total'] == 49,
        'canonical semantic fixed requirement denominator differs')
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'version': '2',
        'sourceDossierManifestHash': source_hash, 'sourceState': checked.report['sourceState'],
        'sourceInventoryHash': keccak256(files[INVENTORY_PATH]), 'selectionHash': selection_hash,
        'ownerDefinitionPlan': plan.report,
        'ownerDefinitionPlanManifestHash': plan.manifest_hash,
        'projection': loads(mapped['semantic/report.json'], maximum=MAX_BYTES, canonical=True),
        'conservation': loads(files['semantic/conservation-family.json'], maximum=MAX_BYTES, canonical=True),
        'dossierRequirements': assessment, 'claims': CLAIMS, 'qualification': QUALIFICATION}
    files['report.json'] = dumps(report)
    children = [package._ref(path, raw) for path, raw in sorted(files.items())
        if not path.startswith('input/')]
    export = {'profile': NAME, 'profileHash': PROFILE_HASH, 'version': '2',
        'sourceDossier': package._ref('input/manifest.json', originals['manifest.json']),
        'sourceState': checked.report['sourceState'], 'disclosure': disclosure,
        'selectionHash': selection_hash, 'inventoryHash': keccak256(files[INVENTORY_PATH]),
        'ownerDefinitionPlanManifestHash': plan.manifest_hash,
        'children': children, 'claims': CLAIMS, 'qualification': QUALIFICATION}
    files[MANIFEST_PATH] = dumps(export)
    require(len(files[MANIFEST_PATH]) <= MAX_MANIFEST, 'canonical semantic export manifest bound')
    package._bounded(files)
    envelope = dumps({'mode': MODE, 'profile': NAME, 'version': '2', 'profileHash': PROFILE_HASH,
        'sourceDossierManifestHash': source_hash, 'selectionHash': selection_hash,
        'ownerDefinitionPlanManifestHash': plan.manifest_hash,
        'disclosure': disclosure, 'exportManifest': package._ref(MANIFEST_PATH, files[MANIFEST_PATH]),
        'files': [package._ref(path, raw) for path, raw in sorted(files.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(envelope) <= MAX_MANIFEST, 'canonical semantic package manifest bound')
    files['manifest.json'] = envelope
    package._bounded(files)
    return package.Assembly(tuple(sorted(files.items())), envelope, report)


def build(files, source_hash, selection_raw, selection_hash, *, disclosure, model_root=MODEL_ROOT,
          plan_files=None, plan_hash=None):
    try:
        return _build(files, source_hash, selection_raw, selection_hash,
            disclosure=disclosure, model_root=model_root, plan_files=plan_files, plan_hash=plan_hash)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed canonical semantic source input') from exc


def verify(files, expected_hash):
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'canonical semantic external package pin differs')
        value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(value) is dict and set(value) == {'mode', 'profile', 'version', 'profileHash',
            'sourceDossierManifestHash', 'selectionHash', 'disclosure', 'exportManifest',
            'ownerDefinitionPlanManifestHash', 'files', 'claims', 'qualification'}
            and value['mode'] == MODE and value['profile'] == NAME
            and value['version'] == '2' and value['profileHash'] == PROFILE_HASH
            and value['claims'] == CLAIMS and value['qualification'] == QUALIFICATION,
            'canonical semantic closed manifest differs')
        _public(value['disclosure'])
        require(value['files'] == [package._ref(path, body) for path, body in sorted(files.items())
            if path != 'manifest.json'], 'canonical semantic file commitments differ')
        originals = {p.removeprefix('input/'): b for p, b in files.items() if p.startswith('input/')}
        retained = {p.removeprefix('dependencies/'): b for p, b in files.items() if p.startswith('dependencies/')}
        plan_files = {p.removeprefix(OWNER_PLAN_PREFIX): b for p, b in files.items()
            if p.startswith(OWNER_PLAN_PREFIX)}
        with TemporaryDirectory(prefix='stream-native-semantic-') as temporary:
            root = Path(temporary) / 'model'
            write_tree(retained, root)
            result = build(originals, value['sourceDossierManifestHash'], files[SELECTION_PATH],
                value['selectionHash'], disclosure=value['disclosure'], model_root=root,
                plan_files=plan_files, plan_hash=value['ownerDefinitionPlanManifestHash'])
        require(dict(result.files) == files, 'canonical semantic full reconstruction differs')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed canonical semantic package') from exc


def _selection_file(path):
    require(not path.is_symlink() and not (hasattr(path, 'is_junction') and path.is_junction()) and path.is_file(),
        'canonical semantic selection must be a regular file')
    with path.open('rb') as handle:
        raw = handle.read(MAX_SELECTION + 1)
    require(len(raw) <= MAX_SELECTION, 'canonical semantic selection file bound')
    return raw


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    for name in ('prepare-selection', 'build'):
        command = commands.add_parser(name)
        command.add_argument('--dossier', type=Path, required=True)
        command.add_argument('--dossier-hash', required=True)
        command.add_argument('--disclosure', required=True)
        command.add_argument('--output', type=Path, required=True)
        command.add_argument('--owner-definitions', type=Path)
        command.add_argument('--owner-definitions-hash')
        if name == 'build':
            command.add_argument('--selection', type=Path, required=True)
            command.add_argument('--selection-hash', required=True)
    command = commands.add_parser('verify')
    command.add_argument('directory', type=Path)
    command.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            message = {'profileHash': PROFILE_HASH, 'sourceProfileHash': sources.PROFILE_HASH,
                'projectionProfileHash': projection.PROFILE_HASH}
        elif args.command == 'verify':
            result = verify(read_tree(args.directory), args.manifest_hash)
            message = {'manifestHash': result.manifest_hash, 'report': result.report}
        else:
            _public(args.disclosure)
            from .repository_exchange import _destination, _publish
            inputs = [args.dossier] + ([args.selection] if args.command == 'build' else [])
            require((args.owner_definitions is None) == (args.owner_definitions_hash is None),
                'owner definition directory and hash must be supplied together')
            if args.owner_definitions is not None:
                inputs.append(args.owner_definitions)
            _destination(args.output, inputs)
            originals = read_tree(args.dossier)
            plan_files = read_tree(args.owner_definitions) if args.owner_definitions is not None else None
            if args.command == 'prepare-selection':
                raw = prepare_selection(originals, args.dossier_hash, disclosure=args.disclosure,
                    plan_files=plan_files, plan_hash=args.owner_definitions_hash)
                _publish({'selection.json': raw}, args.output, inputs)
                message = {'selectionHash': keccak256(raw), 'sourceDossierManifestHash': args.dossier_hash}
            else:
                result = build(originals, args.dossier_hash, _selection_file(args.selection),
                    args.selection_hash, disclosure=args.disclosure,
                    plan_files=plan_files, plan_hash=args.owner_definitions_hash)
                _publish(dict(result.files), args.output, inputs)
                message = {'manifestHash': result.manifest_hash, 'report': result.report}
        print(dumps(message).decode('utf-8'))
    except MuseumError as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
