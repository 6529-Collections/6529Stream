"""Qualified physical Production from exact historical native Artist statements.

This additive export interprets an explicit original literal convention. It does
not change registered source definitions or infer events from token activity.
"""
import argparse
from pathlib import Path
import re
from tempfile import TemporaryDirectory

from . import attribution_dossier
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .object_dossier import Assembly, _bounded, _ref
from .owner_notice_dossier import leaves
from .package_v2 import _dependencies
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator
from .repository_exchange import _publish

NAME = 'STREAM_MUSEUM_RECORDED_PHYSICAL_PRODUCTION_V1'
MODE = 'recorded_physical_production'
RELATION = 'urn:6529stream:museum:physical-production:v1'
RULE = RELATION + ':original-artist-statement'
DATATYPE = RELATION + ':body'
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
STATUSES = ('planned', 'completed', 'cancelled', 'unknown')
MAX_BODY = 16384
CLAIMS = {
    'nativeAttributionPackageReplayed': True, 'originalSourceBytesRetained': True,
    'historicalNativeAuthorityRetained': True, 'exactDeclarationBindings': True,
    'sourceOriginAuthenticated': False, 'consensusProof': False,
    'physicalExistenceProven': False, 'historicalPerformanceProven': False,
    'historicalTimeProven': False, 'namedArtistIdentityProven': False,
    'independentHumanReviewProven': False, 'currentSigningAuthorityGranted': False,
    'physicalCustodyProven': False, 'physicalOwnershipProven': False,
    'legalTitleProven': False, 'museumAccessionProven': False,
    'instrumentValidityProven': False, 'rightsGranted': False,
    'profileRegistered': False, 'fullMuseumConformance': False,
    'institutionalAcceptance': False, 'networkFetch': False,
}
QUALIFICATION = (
    'Historically authorized native Artist assertion, reconstructed from an '
    'externally admitted source transcript. The original statement explicitly '
    'identifies a physical object, a production event, its status and documentary '
    'evidence. A completed statement permits a qualified Production projection; '
    'it does not independently establish physical existence, actual performance, '
    'event time, named artist identity or the validity of an instrument. Native '
    'artistId and signer remain protocol attribution, never inferred Person or '
    'Group identities. Creation, custody, legal title and museum accession remain '
    'separate: no token transfer, upload, exhibition, print-output role or CC0 '
    'term establishes these physical events. This supplementary interpretation '
    'does not complete MSM-RELATIONS5 or the nineteen packet groups and '
    'forty-nine dossier assessments.')
PROFILE_BYTES = dumps({
    'name': NAME, 'version': '1', 'mode': MODE,
    'status': 'prospective_unregistered_export_profile',
    'source': attribution_dossier.PROFILE, 'validationPolicyHash': VALIDATION_HASH,
    'body': {'relation': RELATION, 'mappingRule': RULE, 'datatype': DATATYPE,
        'keys': ['version', 'kind', 'status', 'physicalObject', 'productionEvent'],
        'version': '1', 'kind': 'physical_production', 'statuses': list(STATUSES),
        'declarationKeys': ['id', 'pointer', 'hash'], 'maximumBytes': str(MAX_BODY)},
    'authority': 'Exact selected direct ARTIST_SIGNER statement from concrete native '
        'Artist, metadata and semantic replay. Collection and token anchors retain '
        'their original scope. No new source schema or registered profile.',
    'binding': 'Both entity declarations must be in the same original signed '
        'payload as the assertion; exact /entities/N pointer, original IRI, kind '
        'and Keccak/JCS entity hash. The enclosing original occurrence qualifies '
        'each declaration. The native source verifies prior documentary evidence '
        'selectors, bytes and publication order.',
    'selection': 'Original external source/reviewer selection is preserved. Only '
        'selected direct statements with this exact relation/rule/datatype are '
        'interpreted. All other assertions and unsupported records remain exact.',
    'conflicts': 'Selected production statements cannot merge different declaration '
        'occurrences through one IRI. Conflicting statuses or object/event bindings '
        'are withheld with no recency winner. Unselected statements do not veto.',
    'crosswalk': {'completed': 'physical_object -> HumanMadeObject; event -> '
        'embedded Production; explicit production body -> produced_by. The full '
        'Production is nested under its physical object because the pinned model '
        'does not admit a standalone Production root. Original IRIs and an exact '
        'embedded-event index pointer are retained. Every emitted scalar has '
        'original assertion/declaration provenance.',
        'otherStatus': 'planned/cancelled/unknown remain source sidecars without '
        'HumanMadeObject/Production output.',
        'datesAndAgents': 'createdAt, effectiveDate, signer and artistId remain '
        'sidecars, not event time or carried_out_by. Names are descriptive labels.',
        'otherEvents': 'No Acquisition, TransferOfCustody, accession or title '
        'projection. Existing token title/accession adapters remain separate.'},
    'retention': 'Complete original attribution package, original selection, '
        'source/statement coverage, body evidence, graph provenance and model closure.',
    'verification': 'Rebuild every derived byte from exact original packages offline.',
    'claims': CLAIMS, 'qualification': QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _json(raw):
    return loads(raw, maximum=MAX_BYTES, canonical=True)


def _public(disclosure):
    require(disclosure == 'public', 'physical production requires public disclosure before reads')


def _declaration(pin, original, source, kind):
    require(type(pin) is dict and set(pin) == {'id', 'pointer', 'hash'},
        'physical production closed declaration pin differs')
    require(type(pin['pointer']) is str and re.fullmatch(r'/entities/(0|[1-9][0-9]*)', pin['pointer']),
        'physical production local declaration pointer required')
    index = int(pin['pointer'].rsplit('/', 1)[1])
    entities = original['value']['entities']
    require(index < len(entities), 'physical production declaration absent')
    entity = entities[index]
    require(entity['id'] == pin['id'] and entity['kind'] == kind
        and any(hex_bytes(pin['hash'], 32)) and keccak256(dumps(entity)) == pin['hash'],
        'physical production exact declaration ID/kind/hash differs')
    require(sum(item['id'] == entity['id'] for item in entities) == 1,
        'physical production ambiguous local declaration IRI')
    return {'source': {**source, 'pointer': pin['pointer']},
        'hash': pin['hash'], 'value': entity}


def _body(assertion, original, source):
    literal = assertion['object'].get('literal')
    if (assertion['mappingRule'] != RULE or type(literal) is not dict
            or literal['datatype'] != DATATYPE
            or any(literal[key] is not None for key in ('language', 'unit', 'precision'))):
        return None
    raw = literal['lexicalValue'].encode('utf-8')
    body = loads(raw, maximum=MAX_BODY, canonical=True)
    require(type(body) is dict and set(body) == {
        'version', 'kind', 'status', 'physicalObject', 'productionEvent'}
        and body['version'] == '1' and body['kind'] == 'physical_production'
        and body['status'] in STATUSES, 'physical production closed body differs')
    declarations = {key: _declaration(body[key], original, source, kind)
        for key, kind in (('physicalObject', 'physical_object'), ('productionEvent', 'event'))}
    require(assertion['subject'] == body['physicalObject']['id']
        and body['physicalObject']['id'] != body['productionEvent']['id'],
        'physical production subject/event identity differs')
    return body, declarations


def _derive(dossier):
    semantic, selection = dossier['semanticEvidence'], dossier['selection']
    require(type(semantic) is dict and type(selection) is dict,
        'physical production needs captured semantic source and exact selection')
    chosen = {dumps(row['source']): row for row in selection['selected']}
    withheld = {dumps(row['source']): row for row in selection['withheld']}
    rows, coverage = [], []
    for original in semantic['statements']:
        coverage.extend({'source': original['source'], 'pointer': path, 'value': value,
            'pointerBase': 'semantics/snapshot.json statement', 'disposition': 'retained_original'}
            for path, value in leaves(original))
        if original['status'] != 'supported':
            rows.append({'source': original['source'], 'disposition': 'unsupported_original',
                'original': original, 'body': None, 'declarations': None})
            continue
        for index, assertion in enumerate(original['value']['assertions']):
            source = {**original['source'], 'pointer': '/assertions/' + str(index)}
            key = dumps(source)
            selected = chosen.get(key)
            row = {'source': source, 'assertion': assertion,
                'originalProfileHash': original['value']['profileHash'],
                'historicalAuthority': original['historicalAuthority'],
                'currentQualification': original['currentQualification'],
                'evidence': assertion['evidence'], 'selection': selected or withheld.get(key),
                'disposition': 'unselected', 'reasons': [], 'body': None, 'declarations': None}
            rows.append(row)
            if selected is None:
                if key in withheld:
                    row.update(disposition='source_selection_withheld', reasons=withheld[key]['reasons'])
                continue
            if assertion['relation'] != RELATION:
                row['disposition'] = 'unsupported_relation'
                continue
            if source['authorizationClass'] != 'ARTIST_SIGNER' or assertion['origin'] != 'direct_statement':
                row['disposition'] = 'unsupported_statement_authority'
                continue
            parsed = _body(assertion, original, source)
            if parsed is None:
                row['disposition'] = 'unsupported_literal_convention'
                continue
            body, declarations = parsed
            row.update(body=body, declarations=declarations,
                disposition='candidate', bodyHash=keccak256(dumps(body)))
            coverage.extend({'source': source, 'pointer': path, 'value': value,
                'pointerBase': 'original assertion object.literal.lexicalValue parsed as JCS',
                'disposition': 'retained_original_literal_body'} for path, value in leaves(body))
    candidates = [row for row in rows if row['disposition'] == 'candidate']
    identities, objects, events = {}, {}, {}
    for row in candidates:
        for role, declaration in row['declarations'].items():
            identity = declaration['value']['id']
            identity_key = dumps({'role': role, 'source': declaration['source'], 'hash': declaration['hash']})
            identities.setdefault(identity, set()).add(identity_key)
        body = row['body']
        signature = dumps({'status': body['status'], 'declarations': row['declarations']})
        objects.setdefault(body['physicalObject']['id'], set()).add(signature)
        events.setdefault(body['productionEvent']['id'], set()).add(signature)
    for row in candidates:
        body = row['body']
        ids = [body[key]['id'] for key in ('physicalObject', 'productionEvent')]
        if any(len(identities[identity]) != 1 for identity in ids):
            row['reasons'].append('selected_declaration_identity_collision')
        if len(objects[ids[0]]) != 1 or len(events[ids[1]]) != 1:
            row['reasons'].append('conflicting_selected_production_statements')
        row['disposition'] = ('conflict_withheld' if row['reasons'] else
            'completed_production' if body['status'] == 'completed' else 'retained_' + body['status'])
    return rows, coverage


def _graph(rows, model):
    files, index, embedded, provenance = {}, [], [], []
    groups = {}
    for row in rows:
        if row['disposition'] == 'completed_production':
            groups.setdefault(row['body']['physicalObject']['id'], []).append(row)

    def label(entity, fallback):
        names = entity['names']
        preferred = [name for name in names if name['kind'] == 'preferred' and name['value']]
        nonempty = [name for name in names if name['value']]
        return (preferred or nonempty)[0]['value'] if preferred or nonempty else fallback

    for object_id, statements in sorted(groups.items()):
        example = statements[0]
        object_decl, event_decl = (example['declarations'][key] for key in ('physicalObject', 'productionEvent'))
        event_id = event_decl['value']['id']
        qualifier = [{'type': 'LinguisticObject', 'content': QUALIFICATION}]
        event = {'id': event_id, 'type': 'Production',
            '_label': label(event_decl['value'], 'Artist-described physical production'),
            'referred_to_by': qualifier}
        physical = {'@context': CONTEXT, 'id': object_id, 'type': 'HumanMadeObject',
            '_label': label(object_decl['value'], 'Artist-described physical object'),
            'produced_by': event, 'referred_to_by': qualifier}
        evidence = [{'assertion': row['source'], 'assertionHash': keccak256(dumps(row['assertion'])),
            'bodyHash': row['bodyHash'], 'declarations': row['declarations'],
            'documentaryEvidence': row['evidence'], 'historicalAuthority': row['historicalAuthority'],
            'currentQualification': row['currentQualification']} for row in statements]
        for resource in (physical,):
            identifier = resource['id']; stem = keccak256(identifier.encode('utf-8'))[2:]
            path = 'production/resources/' + stem + '.json'
            require(path not in files, 'physical production duplicate projected identity')
            raw = dumps(resource)
            files[path] = raw
            files['production/expanded/' + stem + '.json'] = model.validate_and_expand(raw).expanded_bytes
            index.append({'id': identifier, 'type': resource['type'], 'path': path,
                'sources': [row['source'] for row in statements], 'qualification': QUALIFICATION})
            embedded.append({'id': event_id, 'type': 'Production', 'path': path,
                'pointer': '/produced_by', 'parentId': identifier,
                'sources': [row['source'] for row in statements], 'qualification': QUALIFICATION})
            provenance.extend({'entity': identifier, 'path': path_, 'value': value,
                'sources': evidence, 'rule': RULE, 'qualification': QUALIFICATION}
                for path_, value in leaves(resource))
    files['production/index.json'] = dumps({'resources': sorted(index, key=lambda row: row['id']),
        'embeddedEntities': sorted(embedded, key=lambda row: row['id'])})
    files['production/provenance.json'] = dumps(provenance)
    return files, {'completedObjectCount': str(len(groups)), 'resourceCount': str(len(index)),
        'embeddedProductionCount': str(len(embedded)),
        'dispositions': {name: str(sum(row['disposition'] == name for row in rows))
            for name in sorted({row['disposition'] for row in rows})}}


def build(source_files, source_hash, *, disclosure, model_root=MODEL_ROOT):
    """Admit a complete native attribution dossier and preserve its exact scope."""
    _public(disclosure)
    try:
        _bounded(source_files)
        require(any(hex_bytes(source_hash, 32)), 'physical production source manifest pin required')
        root = Path(model_root).resolve()
        source_report = attribution_dossier.verify_files(source_files, source_hash, model_root=root)
        dossier = _json(source_files['dossier.json'])
        rows, coverage = _derive(dossier)
        graph, result = _graph(rows, validator(root))
        report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'mode': MODE,
            'sourceManifestHash': source_hash, 'sourceState': dossier['sourceState'],
            'sourceProvenance': source_report['provenance'],
            'sourceSelectionHash': _json(source_files['manifest.json'])['selectionHash'],
            'graph': result, 'claims': CLAIMS, 'qualification': QUALIFICATION}
        files = {'sources/attribution/' + path: raw for path, raw in source_files.items()}
        files.update(_dependencies(root, recorded=True)); files.update(graph)
        files.update({'definitions/profile.json': PROFILE_BYTES,
            'production/sidecar.json': dumps({'rows': rows, 'qualification': QUALIFICATION}),
            'production/coverage.json': dumps(coverage), 'report.json': dumps(report),
            'source/locations.json': dumps({'originalPackageReferenceBase': 'sources/attribution/',
                'semanticSnapshotPath': 'sources/attribution/semantics/snapshot.json',
                'originalPayloadPointerRule': 'Each selector identifies one original native record. '
                    'Declaration and assertion pointers address its retained original payload; '
                    'body pointers address parsed object.literal.lexicalValue, never the export plan.',
                'exportReferenceBase': ''})})
        _bounded(files)
        manifest = dumps({'mode': MODE, 'version': '1', 'profileHash': PROFILE_HASH,
            'sourceManifestHash': source_hash, 'disclosure': disclosure,
            'files': [_ref(path, raw) for path, raw in sorted(files.items())]})
        require(len(manifest) <= MAX_MANIFEST, 'physical production manifest byte bound')
        files['manifest.json'] = manifest; _bounded(files)
        return Assembly(tuple(sorted(files.items())), manifest, report)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed physical production input') from exc


def verify(files, manifest_hash):
    """Reconstruct originals, selection, interpretation and graph entirely offline."""
    try:
        _bounded(files); raw = files.get('manifest.json', b'')
        require(any(hex_bytes(manifest_hash, 32)) and keccak256(raw) == manifest_hash,
            'physical production external manifest pin differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'version', 'profileHash',
            'sourceManifestHash', 'disclosure', 'files'} and manifest['mode'] == MODE
            and manifest['version'] == '1' and manifest['profileHash'] == PROFILE_HASH,
            'physical production closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [_ref(path, body) for path, body in sorted(files.items()) if path != 'manifest.json'],
            'physical production file commitments differ')
        def subtree(prefix):
            return {path.removeprefix(prefix): body for path, body in files.items() if path.startswith(prefix)}
        with TemporaryDirectory(prefix='stream-production-model-') as temporary:
            root = Path(temporary) / 'model'; write_tree(subtree('dependencies/'), root)
            rebuilt = build(subtree('sources/attribution/'), manifest['sourceManifestHash'],
                disclosure=manifest['disclosure'], model_root=root)
        require(dict(rebuilt.files) == files, 'physical production full reconstruction differs')
        return rebuilt
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed physical production package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    create = commands.add_parser('build')
    for name in ('source', 'output'): create.add_argument(name, type=Path)
    create.add_argument('--source-hash', required=True)
    create.add_argument('--disclosure', choices=('public',), required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path); check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles': result = {'profileHash': PROFILE_HASH}
        elif args.command == 'verify':
            result = {'manifestHash': verify(read_tree(args.directory), args.manifest_hash).manifest_hash}
        else:
            _public(args.disclosure)
            built = build(read_tree(args.source), args.source_hash, disclosure=args.disclosure)
            _publish(dict(built.files), args.output, [args.source])
            result = {'manifestHash': built.manifest_hash, 'report': built.report}
        print(dumps(result).decode('utf-8'))
    except (MuseumError, OSError) as exc: parser.exit(1, 'physical production: ' + str(exc) + '\n')


if __name__ == '__main__': main()
