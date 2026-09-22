"""Portable native WORK LIDO export with an exact original-field ledger."""
import argparse
from pathlib import Path
from tempfile import TemporaryDirectory

from lxml import etree

from . import canonical_field_inventory_v1 as inventory
from . import native_work_lido_v1 as projection
from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .package_v2 import _dependencies

NAME = 'STREAM_MUSEUM_NATIVE_WORK_LIDO_PACKAGE_V1'
MODE = 'native_work_lido_package_v1'
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
PLAN_PATH = 'inputs/plan.json'
INVENTORY_PATH = 'conformance/source-field-inventory.json'
LEDGER_PATH = 'conformance/native-format-field-ledger.json'
CLAIMS = {'originalV4Replayed': True, 'originalSourcePackageRetained': True,
    'originalFieldInventoryBeforeSelection': True, 'nativeWorkLidoTargetsChecked': True,
    'operatorMetadataSeparatelyAttributed': True, 'retainedValidationClosure': True,
    'originalRequirementsPromoted': False, 'allNativeFormatsMapped': False,
    'crossFormatAgreementProven': False, 'currentAuthorityProven': False,
    'creatorIdentityAuthenticated': False, 'rightsGranted': False,
    'institutionalAcceptance': False, 'profileRegistered': False, 'networkFetch': False}
QUALIFICATION = ('Exact native WORK occurrences from one replayed V4 package, with '
    'separately attributed operator export metadata. LIDO field mappings resolve '
    'actual XML values and original source fields. All original semantic fields '
    'remain inventoried, including unselected and opaque occurrences. This profile '
    'does not map those fields into other formats or claim cross-format agreement. '
    'Native authority, currentness and the original nineteen/forty-nine assessments '
    'remain unchanged. Source publication does not authenticate the operator, '
    'establish creator truth, grant rights or establish institutional acceptance.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'mode': MODE,
    'projectionProfileHash': projection.PROFILE_HASH,
    'planSchemaHash': projection.PLAN_SCHEMA_HASH,
    'inventoryProfileHash': inventory.PROFILE_HASH,
    'paths': {'source': 'source/', 'plan': PLAN_PATH, 'targets': 'lido/',
        'inventory': INVENTORY_PATH, 'ledger': LEDGER_PATH},
    'verification': 'Replay V4, rebuild native WORK LIDO from original occurrences, '
        'resolve each local target and field, compare every retained byte offline.',
    'limits': {'packageBytes': MAX_BYTES, 'manifestBytes': MAX_MANIFEST},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'native WORK package requires public disclosure before reads')


def _json(raw):
    return loads(raw, maximum=MAX_BYTES, canonical=True)


def _ledger(original_inventory, mapped_files):
    """Join only exact original occurrence/domain/field identifiers."""
    value = _json(original_inventory)
    occurrences = {row['occurrenceId']: row for row in value['occurrences']}
    by_original = {row['originalOccurrenceId']: row for row in value['occurrences']
        if row['originalOccurrenceId'] is not None}
    keys, mapped, targets = {}, {}, {}
    for index, field in enumerate(value['fields']):
        occurrence = occurrences[field['occurrenceId']]
        original_id = occurrence['originalOccurrenceId']
        if original_id is not None:
            key = (original_id, field['domain'], field['pointer'])
            require(key not in keys, 'native WORK ledger duplicate original field')
            keys[key] = (index, field)
    provenance = _json(mapped_files['lido/provenance.json'])
    # The exact emitted provenance shape is part of the new projection profile.
    emissions = provenance['rows']
    for proof_index, proof in enumerate(emissions):
        original_id = proof['occurrenceId']
        require(original_id in by_original and by_original[original_id]['family'] == 'WORK',
            'native WORK ledger original occurrence differs')
        path = proof['targetPath']
        require(path.startswith('lido/records/') and path in mapped_files,
            'native WORK ledger target path missing')
        if path not in targets:
            raw = mapped_files[path]
            require(b'<!DOCTYPE' not in raw and b'<!ENTITY' not in raw,
                'native WORK ledger XML declaration forbidden')
            targets[path] = etree.fromstring(raw, etree.XMLParser(
                resolve_entities=False, load_dtd=False, no_network=True))
        from .same_source_format_ledger_v1 import _XPATH
        xpath = proof['targetXPath']
        require(type(xpath) is str and len(xpath) <= 4096 and _XPATH.fullmatch(xpath),
            'native WORK ledger target XPath outside bounded profile')
        actual = targets[path].xpath(xpath, namespaces={'lido': 'http://www.lido-schema.org',
            'xml': 'http://www.w3.org/XML/1998/namespace'})
        require(len(actual) == 1, 'native WORK ledger target is not unique')
        target = actual[0].text if isinstance(actual[0], etree._Element) else str(actual[0])
        require(target == proof['targetValue'], 'native WORK ledger actual XML value differs')
        for source in proof['sources']:
            if source['domain'] in ('operator_context', 'original_identity'):
                continue
            key = (original_id, source['domain'], source['pointer'])
            require(key in keys, 'native WORK ledger source field missing')
            index, field = keys[key]
            require(field['presence'] == 'present' and field['exactHex'] == source['exactHex'],
                'native WORK ledger exact original value differs')
            occurrence = by_original[original_id]
            domain = [row for row in occurrence['domains'] if row['name'] == source['domain']]
            require(len(domain) == 1 and domain[0]['source'] == source['sourceReference'],
                'native WORK ledger original source reference differs')
            mapped.setdefault(index, []).append({'provenancePointer': '/rows/' + str(proof_index),
                'targetPath': path, 'targetXPath': xpath, 'targetValue': target, 'rule': proof['rule']})
    rows = []
    for index, field in enumerate(value['fields']):
        evidence = mapped.get(index, [])
        absent = field['presence'] == 'absent'
        rows.append({'sourceFieldPointer': '/fields/' + str(index),
            'lido': {'disposition': 'mapped' if evidence else 'not_applicable' if absent
                else 'retained_stream_only', 'evidence': evidence,
                'rule': 'urn:6529stream:museum:native-work-lido:local-provenance' if evidence
                    else field['rule'],
                'reason': 'Actual LIDO target with exact original field provenance.' if evidence
                    else field['reason']},
            'otherFormats': {name: 'not_evaluated_by_this_profile'
                for name in ('linked-art', 'premis', 'iiif')}})
    return dumps({'profileHash': PROFILE_HASH,
        'inventory': package._ref(INVENTORY_PATH, original_inventory),
        'provenance': package._ref('lido/provenance.json', mapped_files['lido/provenance.json']),
        'rows': rows, 'mappedNativeFieldCount': str(len(mapped)),
        'crossFormatAgreementProven': False})


def compose(source_files, source_hash, plan_raw, plan_hash, *, disclosure, model_root=MODEL_ROOT):
    try:
        _public(disclosure)
        originals = dict(source_files)
        package._bounded(originals)
        root = Path(model_root).resolve()
        mapped = projection.build(originals, source_hash, plan_raw, plan_hash,
            disclosure=disclosure, model_root=root)
        mapped_files = dict(mapped.files)
        require(all(path.startswith('lido/') for path in mapped_files),
            'native WORK projection file namespace differs')
        # Projection has concretely replayed this same bounded immutable byte
        # map. Enumerate it without a second expensive V4 replay.
        original_inventory = inventory._extract(originals, source_hash).inventory
        ledger = _ledger(original_inventory, mapped_files)
        output = {'source/' + path: raw for path, raw in originals.items()}
        output.update(_dependencies(root, recorded=True, lido=True))
        output.update(mapped_files)
        output.update({PLAN_PATH: plan_raw, INVENTORY_PATH: original_inventory,
            LEDGER_PATH: ledger, 'definitions/profile.json': PROFILE_BYTES,
            'definitions/projection-profile.json': projection.PROFILE_BYTES,
            'definitions/plan-schema.json': projection.PLAN_SCHEMA_BYTES,
            'definitions/inventory-profile.json': inventory.PROFILE_BYTES})
        report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceManifestHash': source_hash,
            'planHash': plan_hash, 'projection': mapped.report,
            'mappedNativeFieldCount': _json(ledger)['mappedNativeFieldCount'],
            'originalFieldCount': str(len(_json(original_inventory)['fields'])),
            'claims': CLAIMS, 'qualification': QUALIFICATION}
        output['report.json'] = dumps(report)
        package._bounded(output)
        manifest = dumps({'mode': MODE, 'profile': NAME, 'version': '1', 'profileHash': PROFILE_HASH,
            'sourceManifestHash': source_hash, 'planHash': plan_hash, 'disclosure': disclosure,
            'files': [package._ref(path, raw) for path, raw in sorted(output.items())],
            'claims': CLAIMS, 'qualification': QUALIFICATION})
        require(len(manifest) <= MAX_MANIFEST, 'native WORK package manifest bound')
        output['manifest.json'] = manifest
        package._bounded(output)
        return package.Assembly(tuple(sorted(output.items())), manifest, report)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OSError, OverflowError, RecursionError,
            etree.LxmlError) as exc:
        raise MuseumError('malformed native WORK package input') from exc


def verify(files, expected_hash):
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'native WORK package external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version',
            'profileHash', 'sourceManifestHash', 'planHash', 'disclosure', 'files', 'claims',
            'qualification'} and manifest['mode'] == MODE and manifest['profile'] == NAME
            and manifest['version'] == '1' and manifest['profileHash'] == PROFILE_HASH
            and manifest['claims'] == CLAIMS and manifest['qualification'] == QUALIFICATION,
            'native WORK package closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [package._ref(path, raw) for path, raw in sorted(files.items())
            if path != 'manifest.json'], 'native WORK package file commitments differ')
        def subtree(prefix):
            return {path.removeprefix(prefix): raw for path, raw in files.items() if path.startswith(prefix)}
        with TemporaryDirectory(prefix='stream-native-work-lido-') as temporary:
            root = Path(temporary) / 'model'
            write_tree(subtree('dependencies/'), root)
            rebuilt = compose(subtree('source/'), manifest['sourceManifestHash'], files[PLAN_PATH],
                manifest['planHash'], disclosure=manifest['disclosure'], model_root=root)
        require(dict(rebuilt.files) == files, 'native WORK package full reconstruction differs')
        return rebuilt
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OSError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed native WORK package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    build = commands.add_parser('assemble')
    for name in ('source', 'plan', 'output'):
        build.add_argument('--' + name, type=Path, required=True)
    for name in ('source-hash', 'plan-hash', 'disclosure'):
        build.add_argument('--' + name, required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'assemble':
            _public(args.disclosure)
            from .repository_exchange import _destination, _publish
            sources = [args.source, args.plan]
            _destination(args.output, sources)
            with args.plan.open('rb') as handle:
                plan_raw = handle.read(projection.MAX_PLAN + 1)
            result = compose(read_tree(args.source), args.source_hash, plan_raw,
                args.plan_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, sources)
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
        print(dumps({'manifestHash': result.manifest_hash, 'report': result.report}).decode('utf-8'))
    except MuseumError as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
