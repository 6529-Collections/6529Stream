"""Internal occurrence extraction from already verified V4 and retained PREMIS.

The enclosing package owns concrete child admission. This helper checks retained
byte/pointer correspondence; it does not admit a source or prove completeness.
"""
from copy import deepcopy
from hashlib import sha256

from . import object_dossier as package
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CANONICAL_EVIDENCE_OCCURRENCES_V2'
MAX_OCCURRENCES = 16384
MAX_BYTES = package.MAX_BYTES
PRIOR = 'canonical/input/acquisition/prior/'
MEDIA = PRIOR + 'captures/media-masters/'
RENDER = PRIOR + 'captures/prospective-reference/'
CONSERVATION = 'canonical/input/conservation/'
QUALIFICATION = ('Internal projection of already verified child packages. References are relative to the enclosing '
    'package (dossier/ or properties/). Original authority, source state, selection, history and availability remain '
    'separate. No authoritative render inventory, token applicability, current delivery, format detection, institutional '
    'acceptance or completion of the original 19 groups and 49 assessments is inferred.')
MEDIA_QUALIFICATION = ('Recorded three-slot media manifest and master-selection evidence. An ABSENT head, an unoccupied '
    'slot and a WAIVED master role are distinct. A role waiver is not a waiver of the whole slot. Declared URIs and saved '
    'coverage do not establish received media bytes or current archival availability.')
RENDER_QUALIFICATION = ('Original pre-sale prospective simulations, with complete retained native history and separate '
    'current-source observations. These are not post-mint or authoritative render inventory evidence, browser execution '
    'proof or token references. COLLECTION policy V2, scoped policy V2 and VIEW retrieval reference flavors are not '
    'projected by this version, even when retained elsewhere in the verified dossier.')
PROPERTIES_QUALIFICATION = ('Conservation significant-properties References are documentary references, not an interpretation '
    'of their linked document. Retained PREMIS properties are exact original independent-account object/media declarations '
    'selected by the original plan. Local matching bytes establish only the original declared digest and size comparison; '
    'missing and mismatching files and an empty property array remain explicit. No collection-to-token applicability is inferred.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '2', 'status': 'internal_post_verification_projection',
    'inputs': ['verified canonical_object_dossier_v4 file map', 'optional verified premis_retained file map'],
    'referenceBase': 'enclosing package: dossier/ and properties/',
    'denominators': {'media': 'All retained manifests, selection events, three slot histories, original records, coverage and historical candidates.',
        'render': 'All retained original prospective records and captures, plus native history/current-source context.',
        'properties': 'Every conservation significant_properties reference occurrence, plus every explicitly selected PREMIS object and property in original array order.'},
    'payloadDerivation': 'PREMIS original snapshot payloadHex is hex-decoded and parsed as exact canonical RFC8785 JSON; pointers into decoded bytes are explicit.',
    'limits': {'inputBytes': str(MAX_BYTES), 'outputBytes': str(MAX_BYTES), 'occurrences': str(MAX_OCCURRENCES)},
    'sourceReplayPerformedHere': False, 'qualification': QUALIFICATION,
    'familyQualifications': [MEDIA_QUALIFICATION, RENDER_QUALIFICATION, PROPERTIES_QUALIFICATION]})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _pointer(value, pointer):
    require(type(pointer) is str and (pointer == '' or pointer.startswith('/')), 'evidence occurrence JSON pointer')
    for part in pointer.split('/')[1:]:
        part = part.replace('~1', '/').replace('~0', '~')
        if type(value) is list:
            require(part == str(uint(part)) and uint(part) < len(value), 'evidence occurrence array pointer')
            value = value[uint(part)]
        else:
            require(type(value) is dict and part in value, 'evidence occurrence object pointer')
            value = value[part]
    return value


class _Files:
    def __init__(self, dossier, properties):
        self.files = {'dossier/' + p: b for p, b in dict(dossier).items()}
        if properties is not None: self.files.update({'properties/' + p: b for p, b in dict(properties).items()})
        package._bounded(self.files)
        self.json, self.refs = {}, {}

    def load(self, path):
        require(path in self.files, 'evidence occurrence retained file missing: ' + path)
        if path not in self.json: self.json[path] = loads(self.files[path], maximum=MAX_BYTES, canonical=True)
        return self.json[path]

    def ref(self, path, pointer='', *, binary=False):
        require(path in self.files, 'evidence occurrence retained bytes missing: ' + path)
        if path not in self.refs: self.refs[path] = package._ref(path, self.files[path])
        if not binary: _pointer(self.load(path), pointer)
        else: require(pointer == '', 'evidence occurrence raw byte pointer')
        return {**self.refs[path], 'pointer': pointer,
            'derivation': {'kind': 'raw_bytes' if binary else 'json_pointer'}}

    def decoded(self, path, pointer, raw, value, inner):
        require(hex_bytes(_pointer(self.load(path), pointer)) == raw, 'evidence occurrence original payload bytes')
        _pointer(value, inner)
        result = self.ref(path, pointer)
        result['derivation'] = {'kind': 'hex_decode_then_rfc8785_jcs', 'jsonPointer': inner,
            'decodedBytes': str(len(raw)), 'decodedKeccak256': keccak256(raw),
            'decodedSHA256': '0x' + sha256(raw).hexdigest()}
        return result

    def exists(self, prefix):
        return any(path.startswith(prefix) for path in self.files)

    def bytes_ref(self, path, raw):
        require(self.files.get(path) == raw, 'evidence occurrence derived byte file differs: ' + path)
        return self.ref(path, binary=True)


def _group(qualification):
    return {'status': 'source_missing', 'occurrences': [], 'sourceReferences': [], 'qualification': qualification}


def _add(group, kind, status, refs, value, qualification):
    require(len(group['occurrences']) < MAX_OCCURRENCES, 'evidence occurrence count bound')
    identity = {'profileHash': PROFILE_HASH, 'kind': kind, 'index': str(len(group['occurrences'])), 'sources': refs}
    group['occurrences'].append({'occurrenceId': keccak256(dumps(identity)), 'kind': kind, 'status': status,
        'sourceReferences': refs, 'value': deepcopy(value), 'qualification': qualification})


def _media(f):
    g = _group(MEDIA_QUALIFICATION); prefix = 'dossier/' + MEDIA
    if not f.exists(prefix): return g
    path = prefix + 'source/snapshot.json'; s = f.load(path)
    require(s['profile'] == 'STREAM_MUSEUM_PUBLIC_MEDIA_MASTER_SOURCE_V1', 'evidence occurrence media profile')
    require(set(s['slots']) == {'1', '2', '3'}, 'evidence occurrence media slot denominator')
    mask = uint(s['mediaContext']['occupiedMask']); require(mask <= 7, 'evidence occurrence occupied mask')
    g['sourceReferences'] = [f.ref(path), f.ref(prefix + 'source/anchor.json'), f.ref(prefix + 'source/transcript.json')]
    _add(g, 'media_context', 'observed', [f.ref(path, '/mediaContext')],
        {k: s[k] for k in ('sourceState', 'currentAssociation', 'mediaContext', 'historyCoverage')}, MEDIA_QUALIFICATION)
    for key, kind in (('manifests', 'media_manifest'), ('manifestSelections', 'media_manifest_selection'),
            ('records', 'media_original_record'), ('coverage', 'media_saved_coverage'),
            ('historicalCandidates', 'media_historical_candidate')):
        for i, row in enumerate(s[key]):
            value = row if key != 'records' else {k: v for k, v in row.items()
                if k not in ('payloadHex', 'statementHex', 'signatureHex')}
            _add(g, kind, 'retained_original', [f.ref(path, '/' + key + '/' + str(i))], value, MEDIA_QUALIFICATION)
    for slot in ('1', '2', '3'):
        row = s['slots'][slot]; require(row['status'] in ('ABSENT', 'PRESENT', 'WAIVED'), 'evidence occurrence slot status')
        _add(g, 'media_slot', row['status'], [f.ref(path, '/slots/' + slot)],
            {'slot': slot, 'occupiedAtSource': bool(mask & (1 << (int(slot) - 1))), **row}, MEDIA_QUALIFICATION)
    g['status'] = ('retained_occurrences' if mask or s['records'] or
        any(row['history'] for row in s['slots'].values()) else 'retained_empty')
    return g


def _render(f):
    g = _group(RENDER_QUALIFICATION); prefix = 'dossier/' + RENDER
    if not f.exists(prefix): return g
    path = prefix + 'source/snapshot.json'; s = f.load(path)
    require(s['profile'] == 'STREAM_MUSEUM_PUBLIC_PROSPECTIVE_REFERENCE_SOURCE_V1', 'evidence occurrence prospective profile')
    require(uint(s['history']['count']) == len(s['records']), 'evidence occurrence prospective history denominator')
    g['sourceReferences'] = [f.ref(path), f.ref(prefix + 'source/anchor.json'), f.ref(prefix + 'source/transcript.json')]
    context = {k: s[k] for k in ('sourceState', 'provenance', 'history', 'historyCoverage')}
    context['currentSource'] = {k: v for k, v in s['currentSource'].items() if k != 'source'}
    context['currentSource']['sourcePreimageRetained'] = s['currentSource'].get('source') is not None
    _add(g, 'prospective_source_context', s['currentSource']['status'], [f.ref(path, '/currentSource'), f.ref(path, '/history')],
        context, RENDER_QUALIFICATION)
    for i, row in enumerate(s['records']):
        pointer = '/records/' + str(i); require(row['index'] == str(i), 'evidence occurrence prospective original index')
        base = prefix + 'prospective/records/' + row['index'].zfill(3) + '/'
        refs = [f.ref(path, pointer)]
        for name, raw in (('payload.abi', hex_bytes(row['payloadHex'])),
                ('publication.abi', hex_bytes(row['publicationAbiHex'])), ('environment.json', hex_bytes(row['environmentHex'])),
                ('script.js', hex_bytes(row['originalSource'][15]))):
            refs.append(f.bytes_ref(base + name, raw))
        value = {k: row[k] for k in ('index', 'recordHash', 'receipt', 'receiptFields', 'publication', 'evidenceHash')}
        value.update({'scope': 'pre_sale_prospective_simulation', 'captureCount': str(len(row['captures'])),
            'isRetainedHistoryHead': row['recordHash'] == s['history']['head']})
        _add(g, 'prospective_reference', 'retained_original', refs, value, RENDER_QUALIFICATION)
        for j, capture in enumerate(row['captures']):
            refs = [f.ref(path, pointer + '/captures/' + str(j)),
                f.bytes_ref(base + 'captures/' + str(j) + '.html', hex_bytes(capture['animationHTMLHex'])),
                f.bytes_ref(base + 'captures/' + str(j) + '.abi', hex_bytes(capture['executionHex']))]
            value = {k: v for k, v in capture.items() if k not in ('animationHTMLHex', 'executionHex')}
            value.update({'referenceRecordHash': row['recordHash'], 'historyIndex': str(i), 'captureIndex': str(j),
                'scope': 'pre_sale_prospective_simulation'})
            value.update({'receivedByteRoles': ['animationHTML', 'executionDeclaration'], 'pngBytesRetained': False})
            _add(g, 'prospective_capture', 'retained_html_and_execution_declaration', refs, value, RENDER_QUALIFICATION)
    g['status'] = 'retained_occurrences' if s['records'] else 'retained_empty'
    return g


def _conservation(f, g):
    prefix = 'dossier/' + CONSERVATION
    if not f.exists(prefix): return 0, False
    path = prefix + 'source/conservation/reference-occurrences.json'; refs = f.load(path)['occurrences']
    dossier_path = prefix + 'source/conservation/dossier.json'; dossier = f.load(dossier_path)
    correspondence_path = prefix + 'archive/correspondence.json'; correspondence = f.load(correspondence_path)['occurrences']
    require(len(correspondence) == len(refs), 'evidence occurrence conservation full correspondence')
    g['sourceReferences'] += [f.ref(path), f.ref(dossier_path), f.ref(correspondence_path)]
    _add(g, 'conservation_properties_context', 'retained_original', [f.ref(dossier_path, '/scopes')],
        {'source': dossier['source'], 'scopes': dossier['scopes'],
            'recordFamilies': [r['family'] for r in dossier['records']]}, PROPERTIES_QUALIFICATION)
    count = 0
    for i, occurrence in enumerate(refs):
        require(correspondence[i]['occurrence'] == occurrence, 'evidence occurrence conservation correspondence identity')
        if occurrence['relation'] != 'significant_properties': continue
        require(occurrence['dossierPath'] == 'conservation/dossier.json', 'evidence occurrence conservation original path')
        original = _pointer(dossier, occurrence['jsonPointer'])
        require(original == {'hash': occurrence['hash'], 'uri': occurrence['uri']}, 'evidence occurrence conservation reference differs')
        row = correspondence[i]; sources = [f.ref(path, '/occurrences/' + str(i)),
            f.ref(dossier_path, occurrence['jsonPointer']), f.ref(correspondence_path, '/occurrences/' + str(i))]
        if row['materialPath'] is not None:
            sources.append(f.ref(prefix + 'materials/data/' + row['materialPath'], binary=True))
        _add(g, 'conservation_significant_properties_reference', row['status'], sources,
            {'reference': occurrence, 'correspondence': row}, PROPERTIES_QUALIFICATION)
        count += 1
    return count, True


def _premis(f, g):
    prefix = 'properties/'
    if not f.exists(prefix): return 0, False
    path = prefix + 'source/snapshot.json'; s = f.load(path)
    plan_path = prefix + 'input/plan.json'; plan = f.load(plan_path)
    comparison_path = prefix + 'projection/comparisons.json'; comparisons = f.load(comparison_path)
    require(plan['sourceSnapshotHash'] == keccak256(f.files[path]) and len(comparisons) == len(plan['objects']),
        'evidence occurrence PREMIS plan/snapshot denominator')
    g['sourceReferences'] += [f.ref(path), f.ref(plan_path), f.ref(comparison_path), f.ref(prefix + 'projection/report.json')]
    by_hash = {row['recordHash']: (i, row) for i, row in enumerate(s['records'])}
    require(len(by_hash) == len(s['records']), 'evidence occurrence PREMIS duplicate originals')
    chosen = [row['recordHash'] for row in plan['objects']]
    require(chosen == sorted(set(chosen)), 'evidence occurrence PREMIS exact ordered selection')
    count = 0
    for index, (selection, comparison) in enumerate(zip(plan['objects'], comparisons)):
        require(comparison['source']['recordHash'] == selection['recordHash'] and comparison['path'] == selection['path'],
            'evidence occurrence PREMIS selection/comparison')
        i, original = by_hash[selection['recordHash']]; raw = hex_bytes(original['payloadHex'])
        value = loads(raw, maximum=MAX_BYTES, canonical=True); properties = value['significantProperties']
        require(type(properties) is list, 'evidence occurrence PREMIS properties array')
        pointer = '/records/' + str(i); subject = original['subject']; obj = value['object']
        require(subject[:4] == ['2', value['collectionId'], '0', obj['objectId']], 'evidence occurrence PREMIS original media subject')
        expected = {'algorithm': value['hashAlgorithm'], 'digest': obj['contentHash'], 'byteSize': obj['byteSize']}
        require(comparison['expectedOriginalDeclaration'] == expected, 'evidence occurrence PREMIS original declaration')
        local = prefix + 'retained/' + selection['path']; measured = None
        if local in f.files:
            content = f.files[local]; measured = {'byteSize': str(len(content)), 'SHA256': '0x' + sha256(content).hexdigest(),
                'KECCAK256': keccak256(content)}
            status = 'matches' if measured['byteSize'] == expected['byteSize'] and measured[expected['algorithm']] == expected['digest'] else 'mismatch'
        else: status = 'missing'
        require(comparison['status'] == status and comparison['observedLocalBytes'] == measured,
            'evidence occurrence PREMIS local byte comparison')
        sources = [f.ref(path, pointer), f.ref(plan_path, '/objects/' + str(index)),
            f.ref(comparison_path, '/' + str(index)), f.decoded(path, pointer + '/payloadHex', raw, value, '')]
        if measured is not None: sources.append(f.ref(local, binary=True))
        common = {'selector': comparison['source'], 'nativeSubject': subject, 'objectSubject': comparison['objectSubject'],
            'sourceState': s['sourceState'], 'sourceProvenance': s['evidence'], 'scope': 'declared_object_media',
            'localComparison': comparison, 'propertyCount': str(len(properties))}
        _add(g, 'retained_premis_object', 'properties_empty' if not properties else 'properties_declared', sources,
            {**common, 'declaration': value}, PROPERTIES_QUALIFICATION)
        for j, prop in enumerate(properties):
            _add(g, 'retained_premis_significant_property', status,
                [f.decoded(path, pointer + '/payloadHex', raw, value, '/significantProperties/' + str(j)), *sources[:3]],
                {**common, 'propertyIndex': str(j), 'property': prop}, PROPERTIES_QUALIFICATION)
            count += 1
    return count, True


def extract(dossier_files, properties_files=None):
    """Project immutable, concretely verified children; not a public admission API."""
    try:
        f = _Files(dossier_files, properties_files)
        properties = _group(PROPERTIES_QUALIFICATION)
        conservation_count, conservation_present = _conservation(f, properties)
        premis_count, premis_present = _premis(f, properties)
        if conservation_present or premis_present:
            properties['status'] = 'retained_occurrences' if conservation_count + premis_count else 'retained_empty'
        result = {'media': _media(f), 'render': _render(f), 'properties': properties}
        require(sum(len(g['occurrences']) for g in result.values()) <= MAX_OCCURRENCES, 'evidence occurrence aggregate count bound')
        require(len(dumps(result)) <= MAX_BYTES, 'evidence occurrence output byte bound')
        return result
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, UnicodeError, RecursionError) as exc:
        raise MuseumError('malformed verified canonical evidence occurrence input') from exc
