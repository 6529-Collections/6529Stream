"""Resolved native fields and separate complete retained-source field evidence."""
from itertools import combinations

from lxml import etree

from . import canonical_field_inventory_v1 as inventory
from . import canonical_semantic_sources_v1 as pointers
from . import native_multiformat_ledger_v1 as prior
from . import object_dossier as package
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_MUSEUM_NATIVE_MULTIFORMAT_LEDGER_V2'
FORMATS = prior.FORMATS
INVENTORY_PATH, LEDGER_PATH = prior.INVENTORY_PATH, prior.LEDGER_PATH
COMPARISONS_PATH, FAMILIES_PATH = prior.COMPARISONS_PATH, prior.FAMILIES_PATH
SUPPLEMENTAL_LEDGER_PATH = 'conformance/supplemental-format-field-ledger.json'
SUPPLEMENTAL_FAMILIES_PATH = 'conformance/supplemental-source-family-coverage.json'
MAX_FIELDS = 262144
PROFILE_BYTES = dumps({'name': NAME, 'version': '2',
    'nativeInventoryProfileHash': inventory.PROFILE_HASH,
    'previousLedgerProfileHash': prior.PROFILE_HASH, 'formats': list(FORMATS),
    'nativeDenominator': 'Unchanged complete original V4 field inventory, before selection.',
    'supplementalDenominator': 'Separate source-family inventories before selection. Every domain resolves to an exact retained original file and every actual scalar/null/empty-container leaf must be inventoried exactly once.',
    'join': 'Exact original occurrence, domain root reference, field pointer and canonical value bytes. Supplemental inventories belong to their declaring adapter; equal labels or identifiers do not join occurrences.',
    'targets': 'Actual local target hashes and unique scalar JSON pointers or bounded XML XPaths.',
    'separateEvidence': list(prior.SPECIAL_DOMAINS),
    'limits': {'fields': MAX_FIELDS, 'proofRows': MAX_FIELDS, 'sourceDepth': 128},
    'claims': {'originalDenominatorExpanded': False, 'sourceAuthorityPromoted': False,
        'fullSemanticAgreementProven': False, 'institutionalAcceptance': False}})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _json(raw):
    return loads(raw, maximum=package.MAX_BYTES, canonical=True)


def _leaves(value, pointer='', depth=0):
    require(depth <= 128, 'supplemental original source depth bound')
    if type(value) is dict and value:
        for key in sorted(value):
            escaped = key.replace('~', '~0').replace('/', '~1')
            yield from _leaves(value[key], pointer + '/' + escaped, depth + 1)
    elif type(value) is list and value:
        for index, item in enumerate(value):
            yield from _leaves(item, pointer + '/' + str(index), depth + 1)
    else:
        yield pointer, '0x' + dumps(value).hex()


def _supplement(name, raw, expected_profile, source_files):
    value = _json(raw)
    require(type(value) is dict and value['profileHash'] == expected_profile
        and type(value['occurrences']) is list and type(value['fields']) is list,
        'supplemental source inventory profile/shape differs')
    occurrences, actual = {}, {}
    for row in value['occurrences']:
        identifier = row['occurrenceId']
        require(type(identifier) is str and identifier not in occurrences
            and type(row['family']) is str and type(row['domains']) is list,
            'supplemental original occurrence differs')
        occurrences[identifier] = row
        names = set()
        for domain in row['domains']:
            require(domain['name'] == 'retained_source' and domain['name'] not in names,
                'supplemental original domain differs')
            names.add(domain['name']); ref = domain['source']
            require(type(ref) is dict and type(ref.get('path')) is str
                and ref['path'].startswith('source/'), 'supplemental original source path differs')
            root = pointers.resolve_reference(source_files, ref)
            if type(root) is bytes: root = _json(root)
            for pointer, exact in _leaves(root):
                key = (identifier, domain['name'], pointer)
                require(key not in actual and len(actual) < MAX_FIELDS,
                    'supplemental original field duplicate/bound')
                actual[key] = exact
    declared = {}
    for field in value['fields']:
        key = (field['occurrenceId'], field['domain'], field['pointer'])
        require(key not in declared and field['presence'] == 'present',
            'supplemental declared field duplicate/presence differs')
        declared[key] = field['exactHex']
    require(actual == declared, 'supplemental complete original field denominator differs')
    return value


def _pairs(represented):
    pairs = []
    for left, right in combinations(FORMATS, 2):
        a, b = represented.get(left, []), represented.get(right, [])
        av, bv = ({dumps(e['value']) for e in entries} for entries in (a, b))
        pairs.append({'formats': [left, right], 'status': 'insufficient_mapped_formats' if not a or not b
            else 'equal_target_representations' if av == bv else 'different_target_representations',
            'targets': {left: a, right: b}})
    return pairs


def build(inventory_raw, files, *, source_files, supplemental_profiles):
    """Caller concretely replays V4 and each adapter before deriving this ledger."""
    try:
        package._bounded(files); package._bounded(source_files)
        original_files = {'source/' + path: raw for path, raw in source_files.items()}
        native = _json(inventory_raw)
        require(native['profileHash'] == inventory.PROFILE_HASH,
            'native format original inventory profile differs')
        inventories = {'native': native}
        refs = {'native': package._ref(INVENTORY_PATH, inventory_raw)}
        require(type(supplemental_profiles) is dict
            and set(supplemental_profiles) == {'premis', 'iiif'},
            'supplemental adapter profile set differs')
        for name, pin in sorted(supplemental_profiles.items()):
            path = name + '/supplemental-source-inventory.json'; raw = files[path]
            inventories[name] = _supplement(name, raw, pin, original_files)
            refs[name] = package._ref(path, raw)
        occurrences, keys, fields, families = {}, {}, [], {}
        for origin, value in inventories.items():
            for row in value['occurrences']:
                identifier = row['occurrenceId']
                require(identifier not in occurrences, 'native format duplicate original occurrence')
                occurrences[identifier] = (origin, row)
                family = families.setdefault((origin, row['family']), {'origin': origin,
                    'family': row['family'], 'occurrenceCount': 0, 'fieldCount': 0,
                    'mappedFields': {name: 0 for name in FORMATS}})
                family['occurrenceCount'] += 1
            for index, field in enumerate(value['fields']):
                key = (field['occurrenceId'], field['domain'], field['pointer'])
                require(key not in keys and field['occurrenceId'] in occurrences
                    and occurrences[field['occurrenceId']][0] == origin and len(fields) < MAX_FIELDS,
                    'native format original field duplicate/origin/bound')
                keys[key] = len(fields); fields.append((origin, index, field))
        old_ids = {row['originalOccurrenceId']: row['occurrenceId'] for row in native['occurrences']
            if row['originalOccurrenceId'] is not None}
        mapped, reader, proof_count = {}, prior._Targets(files), 0
        proof_refs, separate = {}, {name: 0 for name in FORMATS}
        for name in FORMATS:
            path = name + '/provenance.json'; raw = files[path]
            proof_refs[name] = package._ref(path, raw); proofs = _json(raw)['rows']
            require(type(proofs) is list, 'native format proof rows required')
            proof_count += len(proofs)
            require(proof_count <= MAX_FIELDS, 'native format proof row bound')
            for proof_index, proof in enumerate(proofs):
                identifier = old_ids.get(proof['occurrenceId']) if name == 'lido' else proof['occurrenceId']
                require(identifier in occurrences, 'native format original occurrence missing')
                origin, occurrence = occurrences[identifier]
                require(origin in ('native', name), 'native format foreign supplemental occurrence')
                target = reader.resolve(name, proof)
                require(type(proof['rule']) is str and proof['rule']
                    and type(proof['sources']) is list and proof['sources'],
                    'native format proof rule/source missing')
                for source in proof['sources']:
                    if source['domain'] in prior.SPECIAL_DOMAINS:
                        separate[name] += 1; continue
                    key = (identifier, source['domain'], source['pointer'])
                    require(key in keys, 'native format source field missing')
                    field_index = keys[key]; field = fields[field_index][2]
                    domains = [d for d in occurrence['domains'] if d['name'] == field['domain']]
                    require(len(domains) == 1 and domains[0]['source'] == source['sourceReference']
                        and field['presence'] == 'present' and field['exactHex'] == source['exactHex'],
                        'native format exact original field reference/value differs')
                    mapped.setdefault((field_index, name), []).append({
                        'provenance': proof_refs[name] | {'jsonPointer': '/rows/' + str(proof_index)}, **target})
        native_rows, supplemental_rows, comparisons = [], [], []
        for field_index, (origin, local_index, field) in enumerate(fields):
            occurrence = occurrences[field['occurrenceId']][1]
            family = families[(origin, occurrence['family'])]; family['fieldCount'] += 1
            formats, represented = {}, {}
            for name in FORMATS:
                evidence = mapped.get((field_index, name), [])
                if evidence: family['mappedFields'][name] += 1; represented[name] = evidence
                formats[name] = {'disposition': 'mapped' if evidence else
                    'not_applicable' if field['presence'] == 'absent' else 'retained_stream_only',
                    'evidence': evidence}
            pointer = '/fields/' + str(local_index)
            row = {'sourceFieldPointer': pointer, 'formats': formats}
            if origin == 'native': native_rows.append(row)
            else: supplemental_rows.append({'origin': origin, 'inventory': refs[origin], **row})
            if len(represented) >= 2:
                comparisons.append({'origin': origin, 'inventory': refs[origin],
                    'sourceFieldPointer': pointer, 'occurrenceId': field['occurrenceId'],
                    'domain': field['domain'], 'pointer': field['pointer'], 'exactHex': field['exactHex'],
                    'pairs': _pairs(represented), 'qualification':
                    'One exact original field; equality is representation agreement, not source truth.'})
        common = {'profileHash': PROFILE_HASH, 'inventory': refs['native'], 'provenance': proof_refs}
        return {LEDGER_PATH: dumps(common | {'rows': native_rows,
                'separateEvidenceReferenceCounts': separate}),
            COMPARISONS_PATH: dumps(common | {'rows': comparisons,
                'fieldsWithAtLeastTwoMappedFormats': str(len(comparisons)),
                'fullSemanticAgreementProven': False}),
            FAMILIES_PATH: dumps(common | {'families': [row for (origin, _), row in sorted(families.items())
                if origin == 'native'], 'denominators': native['denominators'],
                'scope': 'Unchanged native V4 source field denominator.'}),
            SUPPLEMENTAL_LEDGER_PATH: dumps(common | {'inventories': refs, 'rows': supplemental_rows}),
            SUPPLEMENTAL_FAMILIES_PATH: dumps(common | {'inventories': refs,
                'families': [row for (origin, _), row in sorted(families.items()) if origin != 'native'],
                'scope': 'Separate complete source domains retained by this exact V4; not a global host inventory.',
                'originalNativeDenominatorExpanded': False})}
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OSError, OverflowError, RecursionError, etree.LxmlError) as exc:
        raise MuseumError('malformed native supplemental field evidence') from exc
