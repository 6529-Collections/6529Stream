"""Native V4 exports with retained VIEW media and preservation assertions."""
import argparse
from pathlib import Path
from tempfile import TemporaryDirectory

from . import canonical_object_dossier_v4 as dossier
from . import canonical_field_inventory_v1 as inventory
from . import native_linked_art_v1 as linked_art
from . import native_premis_v2 as premis
from . import native_iiif_v2 as iiif
from . import native_work_lido_v1 as lido
from . import native_multiformat_ledger_v2 as ledger
from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .package_v2 import _dependencies

NAME = 'STREAM_MUSEUM_NATIVE_MULTIFORMAT_PACKAGE_V2'
MODE = 'native_multiformat_package_v2'
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
MAX_PLAN = 2 * 1024 * 1024
PLAN_PATH = 'inputs/export-plan.json'
ADAPTERS = {'linked-art': linked_art, 'premis': premis, 'iiif': iiif, 'lido': lido}
# LIDO V1's existing plan reference is immutable.
PLAN_PATHS = {name: 'inputs/' + name + '-plan.json' for name in ('linked-art', 'premis', 'iiif')}
PLAN_PATHS['lido'] = 'inputs/plan.json'
CLAIMS = {'originalV4Replayed': True, 'originalSourceRetained': True,
    'completeOriginalFieldDenominator': True, 'nativeAdaptersRecomputed': True,
    'actualFormatTargetsResolved': True, 'sameOriginalFieldComparisons': True,
    'retainedValidationClosure': True, 'operatorAndDerivedEvidenceSeparate': True,
    'supplementalOriginalFieldsAccounted': True, 'operatorPaintingDesignationSeparate': True,
    'originalRequirementsPromoted': False, 'allNativeFormatsMapped': False,
    'fullSemanticAgreementProven': False, 'liveSourceCaptured': False,
    'currentAuthorityProven': False, 'institutionalAcceptance': False,
    'profileRegistered': False, 'networkFetch': False}
QUALIFICATION = ('Four prospective local native adapters share one replayed V4 source. Native VIEW '
    'token/file correspondence and documentary preservation assertions retain their exact '
    'original scope. Operator painting designations are separately attributed. '
    'Original occurrences, selectors, fields, authority, currentness and source provenance '
    'remain exact. Each format maps only its declared supported scope; all other original '
    'fields remain explicit. Same-field comparisons inspect actual representations and '
    'do not establish source truth or complete semantic equivalence. Export metadata '
    'and checks of retained bytes remain separately attributed and never imply live media '
    'retrieval, performed underlying activities, effective rights grants, current authority or '
    'institutional acceptance. Original nineteen/forty-nine assessments are unchanged.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '2', 'mode': MODE,
    'status': 'prospective_unregistered_local_adapter',
    'sourceProfileHash': dossier.PROFILE_HASH, 'inventoryProfileHash': inventory.PROFILE_HASH,
    'ledgerProfileHash': ledger.PROFILE_HASH,
    'adapters': {name: {'profileHash': module.PROFILE_HASH,
        'planSchemaHash': module.PLAN_SCHEMA_HASH, 'planPath': PLAN_PATHS[name]}
        for name, module in ADAPTERS.items()},
    'plan': 'Closed version=2, sourceManifestHash and adapters object containing exactly all four closed adapter plans.',
    'verification': 'Concrete original V4 replay, unchanged native field inventory, original-source adapters, independent exact supplemental original leaf resolution, local target ledger and complete-byte reconstruction using retained dependencies.',
    'supplementalInventoryProfiles': {name: module.SOURCE_INVENTORY_PROFILE_HASH for name, module in (('premis', premis), ('iiif', iiif))},
    'limits': {'planBytes': MAX_PLAN, 'packageBytes': MAX_BYTES, 'manifestBytes': MAX_MANIFEST},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'native multiformat public disclosure required before reads')


def _plan(raw, digest, source_hash):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_PLAN and any(hex_bytes(digest, 32))
        and keccak256(raw) == digest, 'native multiformat plan pin/bound differs')
    value = loads(raw, maximum=MAX_PLAN, canonical=True)
    require(type(value) is dict and set(value) == {'version', 'sourceManifestHash', 'adapters'}
        and value['version'] == '2' and value['sourceManifestHash'] == source_hash
        and type(value['adapters']) is dict and set(value['adapters']) == set(ADAPTERS),
        'native multiformat closed export plan differs')
    require(all(type(plan) is dict and plan.get('sourceManifestHash') == source_hash
        for plan in value['adapters'].values()), 'native multiformat adapter source differs')
    return value


def compose(source_files, source_hash, plan_raw, plan_hash, *, disclosure, model_root=MODEL_ROOT):
    try:
        _public(disclosure)
        plan = _plan(plan_raw, plan_hash, source_hash)
        originals = dict(source_files); package._bounded(originals)
        checked = dossier.verify(originals, source_hash)
        require(dict(checked.files) == originals, 'native multiformat verified originals differ')
        original_inventory = inventory._extract(originals, source_hash).inventory
        root = Path(model_root).resolve()
        outputs, reports = {}, {}
        for name, module in ADAPTERS.items():
            raw = dumps(plan['adapters'][name]); digest = keccak256(raw)
            # All adapters consume the same exact map after concrete V4 replay.
            # No derived export is recast as a different source type.
            result = (module._derive(originals, source_hash, raw, digest, root) if name == 'lido'
                else module._derive(originals, source_hash, raw, digest, root,
                    inventory_raw=original_inventory))
            require(all(path.startswith(name + '/') for path in result.files)
                and not set(outputs).intersection(result.files),
                'native multiformat adapter namespace collision')
            outputs.update(result.files); reports[name] = result.report
            outputs[PLAN_PATHS[name]] = raw
            outputs['definitions/' + name + '-profile.json'] = module.PROFILE_BYTES
            outputs['definitions/' + name + '-plan-schema.json'] = module.PLAN_SCHEMA_BYTES
            if name in ('premis', 'iiif'):
                outputs['definitions/' + name + '-source-inventory-profile.json'] = module.SOURCE_INVENTORY_PROFILE_BYTES
        evidence = ledger.build(original_inventory, outputs,
            source_files=originals, supplemental_profiles={name: module.SOURCE_INVENTORY_PROFILE_HASH
                for name, module in (('premis', premis), ('iiif', iiif))})
        output = {'source/' + path: raw for path, raw in originals.items()}
        output.update(_dependencies(root))
        output.update(outputs); output.update(evidence)
        output.update({PLAN_PATH: plan_raw, ledger.INVENTORY_PATH: original_inventory,
            'definitions/profile.json': PROFILE_BYTES,
            'definitions/inventory-profile.json': inventory.PROFILE_BYTES,
            'definitions/ledger-profile.json': ledger.PROFILE_BYTES})
        report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash,
            'planHash': plan_hash, 'adapters': reports,
            'evidence': {path: package._ref(path, raw) for path, raw in evidence.items()},
            'claims': CLAIMS, 'qualification': QUALIFICATION}
        output['report.json'] = dumps(report)
        package._bounded(output)
        manifest = dumps({'mode': MODE, 'profile': NAME, 'version': '2', 'profileHash': PROFILE_HASH,
            'sourceManifestHash': source_hash, 'planHash': plan_hash, 'disclosure': disclosure,
            'files': [package._ref(path, raw) for path, raw in sorted(output.items())],
            'claims': CLAIMS, 'qualification': QUALIFICATION})
        require(len(manifest) <= MAX_MANIFEST, 'native multiformat manifest bound')
        output['manifest.json'] = manifest; package._bounded(output)
        return package.Assembly(tuple(sorted(output.items())), manifest, report)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OSError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed native multiformat input') from exc


def verify(files, expected_hash):
    try:
        files = dict(files); package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'native multiformat external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version',
            'profileHash', 'sourceManifestHash', 'planHash', 'disclosure', 'files', 'claims',
            'qualification'} and manifest['mode'] == MODE and manifest['profile'] == NAME
            and manifest['version'] == '2' and manifest['profileHash'] == PROFILE_HASH
            and manifest['claims'] == CLAIMS and manifest['qualification'] == QUALIFICATION,
            'native multiformat closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [package._ref(path, body) for path, body in sorted(files.items())
            if path != 'manifest.json'], 'native multiformat file commitments differ')
        def subtree(prefix):
            return {path.removeprefix(prefix): body for path, body in files.items() if path.startswith(prefix)}
        with TemporaryDirectory(prefix='stream-native-formats-') as temporary:
            root = Path(temporary) / 'model'
            write_tree(subtree('dependencies/'), root)
            rebuilt = compose(subtree('source/'), manifest['sourceManifestHash'], files[PLAN_PATH],
                manifest['planHash'], disclosure=manifest['disclosure'], model_root=root)
        require(dict(rebuilt.files) == files, 'native multiformat full reconstruction differs')
        return rebuilt
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OSError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed native multiformat package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    build = commands.add_parser('assemble')
    for name in ('source', 'plan', 'output'): build.add_argument('--' + name, type=Path, required=True)
    for name in ('source-hash', 'plan-hash', 'disclosure'): build.add_argument('--' + name, required=True)
    check = commands.add_parser('verify'); check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    commands.add_parser('profiles')
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            print(PROFILE_BYTES.decode('utf-8')); return
        if args.command == 'assemble':
            _public(args.disclosure)
            from .repository_exchange import _destination, _publish
            inputs = [args.source, args.plan]; _destination(args.output, inputs)
            require(not args.plan.is_symlink() and not (hasattr(args.plan, 'is_junction')
                and args.plan.is_junction()) and args.plan.is_file(),
                'native multiformat plan must be a regular file')
            with args.plan.open('rb') as handle: raw = handle.read(MAX_PLAN + 1)
            result = compose(read_tree(args.source), args.source_hash, raw, args.plan_hash,
                disclosure=args.disclosure)
            _publish(dict(result.files), args.output, inputs)
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
        print(dumps({'manifestHash': result.manifest_hash, 'report': result.report}).decode('utf-8'))
    except MuseumError as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
