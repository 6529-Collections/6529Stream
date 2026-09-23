"""Exact native field and actual target correspondence across four adapters."""
from decimal import Decimal
from itertools import combinations

from lxml import etree

from . import canonical_field_inventory_v1 as inventory
from . import object_dossier as package
from .canonical import MuseumError, dumps, keccak256, loads
from .iiif_numbers import target_loads
from .independent_wire import require
from .same_source_format_ledger_v1 import _XPATH, _pointer, _value

NAME = 'STREAM_MUSEUM_NATIVE_MULTIFORMAT_LEDGER_V1'
FORMATS = ('linked-art', 'premis', 'iiif', 'lido')
SPECIAL_DOMAINS = ('original_identity', 'operator_context', 'derived_bytes')
INVENTORY_PATH = 'conformance/source-field-inventory.json'
LEDGER_PATH = 'conformance/native-format-field-ledger.json'
COMPARISONS_PATH = 'conformance/same-field-comparisons.json'
FAMILIES_PATH = 'conformance/source-family-coverage.json'
PROFILE_BYTES = dumps({'name': NAME, 'version': '1',
    'inventoryProfileHash': inventory.PROFILE_HASH, 'formats': list(FORMATS),
    'join': 'Exact derived occurrence ID, original domain reference, field pointer and canonical value bytes.',
    'target': 'Resolve actual bounded local scalar pointer/XPath and verify its file hash and value.',
    'sourceDenominator': 'Every field of the complete original V4 semantic inventory before selection.',
    'separateEvidence': list(SPECIAL_DOMAINS),
    'comparison': 'Compare actual representations of exactly the same original field. Equal values are representation agreement only; different representations remain visible and are never rewritten.',
    'limits': {'packageBytes': package.MAX_BYTES, 'proofRows': 262144},
    'claims': {'fullSemanticAgreementProven': False, 'allNativeFormatsMapped': False,
        'institutionalAcceptance': False, 'sourceAuthorityPromoted': False}})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _json(raw):
    return loads(raw, maximum=package.MAX_BYTES, canonical=True)


def _scalar(value):
    require(value is None or type(value) in (bool, str, int, Decimal),
        'native format target must be a scalar')
    if type(value) is Decimal:
        return {'kind': 'number', 'lexical': format(value, 'f')}
    return _value(value)


class _Targets:
    def __init__(self, files):
        self.files, self.parsed, self.hashes = files, {}, {}

    def resolve(self, format_name, proof):
        target = proof['target']; path = target['path']
        require(type(path) is str and path.startswith(format_name + '/')
            and path in self.files, 'native format own target path missing')
        raw = self.files[path]
        if path not in self.hashes: self.hashes[path] = keccak256(raw)
        require(target['hash'] == self.hashes[path], 'native format target hash differs')
        xml = format_name in ('premis', 'lido')
        require(set(target) == {'path', 'hash', 'xpath' if xml else 'pointer'},
            'native format closed target reference differs')
        if path not in self.parsed:
            if xml:
                require(b'<!DOCTYPE' not in raw and b'<!ENTITY' not in raw,
                    'native format XML declaration forbidden')
                self.parsed[path] = etree.fromstring(raw, etree.XMLParser(
                    resolve_entities=False, load_dtd=False, no_network=True, huge_tree=False))
            else:
                self.parsed[path] = target_loads(raw) if format_name == 'iiif' else _json(raw)
        if xml:
            xpath = target['xpath']
            require(type(xpath) is str and len(xpath) <= 4096 and _XPATH.fullmatch(xpath),
                'native format XPath outside bounded profile')
            matches = self.parsed[path].xpath(xpath, namespaces={
                'premis': 'http://www.loc.gov/premis/v3', 'xsi': 'http://www.w3.org/2001/XMLSchema-instance',
                'lido': 'http://www.lido-schema.org', 'xml': 'http://www.w3.org/XML/1998/namespace'})
            require(len(matches) == 1, 'native format target must be unique')
            item = matches[0]
            require(not isinstance(item, etree._Element) or len(item) == 0,
                'native format target must be a scalar leaf')
            actual = _scalar(item.text if isinstance(item, etree._Element) else str(item))
        else:
            pointer = target['pointer']
            require(type(pointer) is str and len(pointer) <= 4096,
                'native format target pointer bound')
            actual = _scalar(_pointer(self.parsed[path], pointer))
        declared = proof['targetValue']
        expected = (declared if type(declared) is dict and set(declared) == {'kind', 'lexical'}
            and declared['kind'] == 'number' else _scalar(declared))
        require(actual == expected, 'native format actual target value differs')
        return {'target': target, 'value': actual, 'rule': proof['rule']}


def build(inventory_raw, files):
    """Source and each adapter must have been concretely replayed by the caller."""
    try:
        package._bounded(files)
        value = _json(inventory_raw)
        require(value['profileHash'] == inventory.PROFILE_HASH,
            'native format inventory profile differs')
        occurrences = {r['occurrenceId']: r for r in value['occurrences']}
        require(len(occurrences) == len(value['occurrences']), 'native format duplicate occurrence')
        old_ids = {r['originalOccurrenceId']: r['occurrenceId'] for r in value['occurrences']
            if r['originalOccurrenceId'] is not None}
        keys = {}
        for index, field in enumerate(value['fields']):
            key = (field['occurrenceId'], field['domain'], field['pointer'])
            require(key not in keys, 'native format duplicate original field')
            keys[key] = index
        mapped, target_reader, proof_count = {}, _Targets(files), 0
        proof_refs, separate = {}, {name: 0 for name in FORMATS}
        for name in FORMATS:
            path = name + '/provenance.json'; raw = files[path]
            proof_refs[name] = package._ref(path, raw)
            proofs = _json(raw)['rows']
            require(type(proofs) is list, 'native format proof rows required')
            proof_count += len(proofs)
            require(proof_count <= 262144, 'native format proof row bound')
            for proof_index, proof in enumerate(proofs):
                occurrence_id = old_ids.get(proof['occurrenceId']) if name == 'lido' else proof['occurrenceId']
                require(occurrence_id in occurrences, 'native format original occurrence missing')
                occurrence = occurrences[occurrence_id]
                target = target_reader.resolve(name, proof)
                require(type(proof['rule']) is str and proof['rule'], 'native format mapping rule missing')
                require(type(proof['sources']) is list and proof['sources'],
                    'native format proof needs source attribution')
                for source in proof['sources']:
                    if source['domain'] in SPECIAL_DOMAINS:
                        separate[name] += 1
                        continue
                    key = (occurrence_id, source['domain'], source['pointer'])
                    require(key in keys, 'native format source field missing')
                    index = keys[key]; field = value['fields'][index]
                    domains = [d for d in occurrence['domains'] if d['name'] == field['domain']]
                    require(len(domains) == 1 and domains[0]['source'] == source['sourceReference'],
                        'native format original domain reference differs')
                    require(field['presence'] == 'present' and field['exactHex'] == source['exactHex'],
                        'native format original exact field value differs')
                    mapped.setdefault((index, name), []).append({
                        'provenance': proof_refs[name] | {'jsonPointer': '/rows/' + str(proof_index)},
                        **target})
        ledger, comparisons, families = [], [], {}
        for occurrence in value['occurrences']:
            family = families.setdefault(occurrence['family'], {'family': occurrence['family'],
                'occurrenceCount': 0, 'fieldCount': 0,
                'mappedFields': {name: 0 for name in FORMATS}})
            family['occurrenceCount'] += 1
        for index, field in enumerate(value['fields']):
            occurrence = occurrences[field['occurrenceId']]
            family = families[occurrence['family']]; family['fieldCount'] += 1
            formats, represented = {}, {}
            for name in FORMATS:
                evidence = mapped.get((index, name), [])
                if evidence: family['mappedFields'][name] += 1
                formats[name] = {'disposition': 'mapped' if evidence else
                    'not_applicable' if field['presence'] == 'absent' else 'retained_stream_only',
                    'rule': 'exact-native-field-to-resolved-target' if evidence else field['rule'],
                    'reason': 'This exact original field has validated format-local target evidence.' if evidence
                        else field['reason'], 'evidence': evidence}
                if evidence:
                    represented[name] = evidence
            ledger.append({'sourceFieldPointer': '/fields/' + str(index), 'formats': formats})
            pairs = []
            for left, right in combinations(FORMATS, 2):
                a, b = represented.get(left, []), represented.get(right, [])
                av, bv = ({dumps(e['value']) for e in entries} for entries in (a, b))
                pairs.append({'formats': [left, right], 'status': 'insufficient_mapped_formats' if not a or not b
                    else 'equal_target_representations' if av == bv else 'different_target_representations',
                    'targets': {left: a, right: b}})
            if len(represented) >= 2:
                comparisons.append({'sourceFieldPointer': '/fields/' + str(index),
                    'occurrenceId': field['occurrenceId'], 'domain': field['domain'],
                    'pointer': field['pointer'], 'exactHex': field['exactHex'], 'pairs': pairs,
                    'qualification': 'One exact original field; target equality is representation agreement, not source truth or full semantic equivalence.'})
        common = {'profileHash': PROFILE_HASH, 'inventory': package._ref(INVENTORY_PATH, inventory_raw),
            'provenance': proof_refs}
        return {LEDGER_PATH: dumps(common | {'rows': ledger,
                'separateEvidenceReferenceCounts': separate}),
            COMPARISONS_PATH: dumps(common | {'rows': comparisons,
                'fieldsWithAtLeastTwoMappedFormats': str(len(comparisons)),
                'unlistedFields': 'Fewer than two mapped formats; full ledger retains every field.',
                'fullSemanticAgreementProven': False}),
            FAMILIES_PATH: dumps(common | {'families': [families[k] for k in sorted(families)],
                'denominators': value['denominators'],
                'scope': 'Only original occurrences retained by this exact V4 source; no global host completeness.'})}
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, etree.LxmlError) as exc:
        raise MuseumError('malformed native format field evidence') from exc
