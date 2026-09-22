"""Explicit owner EXHIBITION location commitments joined to recorded TGN evidence.

Both retained packages are concretely replayed. The binding is a selector, not
authority: the original owner payload must itself commit to the whole original
Place declaration payload. Account review and geographic truth remain separate.
"""
import argparse
from pathlib import Path
from tempfile import TemporaryDirectory

from . import authority_package_v2 as authority_package
from . import authority_v2 as authority
from . import canonical_semantic_sources_v2 as sources
from . import owner_exhibitions as exhibitions
from .account_profile import JCS_ID
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree, write_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import require
from .object_dossier import Assembly, _bounded, _ref
from .package_recorded import INPUT_FILES
from .package_v2 import _dependencies
from .preservation_graph import CONTEXT, validator
from .recorded_projection import replay_source_bytes
from .repository_exchange import _publish
from .typed_declarations import declaration_evidence

NAME = 'STREAM_MUSEUM_RECORDED_EXHIBITION_GEOGRAPHY_V1'
MODE = 'recorded_exhibition_location_join'
MODEL_ROOT = Path(__file__).resolve().parents[2] / 'schemas/museum'
MAX_BINDING = 16384
CLAIMS = {
    'ownerDossierReplayed': True, 'recordedAuthorityPackageReplayed': True,
    'ownerReferencedDeclarationBytes': True, 'ownerApprovedTgnIdentity': False,
    'sourceOriginAuthenticated': False, 'consensusProof': False,
    'geographicTruthProven': False, 'publisherIdentityAuthenticated': False,
    'independentHumanReviewProven': False, 'historicalPerformanceProven': False,
    'historicalTimeProven': False, 'institutionIdentityProven': False,
    'displayPermissionProven': False, 'physicalCustodyProven': False,
    'currentOwnerProven': False, 'currentLiveAuthorityProven': False,
    'sharedCanonicalHistoryProven': False,
    'fullMuseumConformance': False, 'institutionalAcceptance': False,
    'profileRegistered': False, 'networkFetch': False,
}
QUALIFICATION = (
    'One explicit historical OwnerRecords EXHIBITION location join. The original '
    'venue.location Keccak/JCS reference commits to the whole earlier original '
    'Place declaration payload; a matching label or IRI alone cannot join sources. '
    'A separately reviewed account TGN alignment is attributed to its own original '
    'account, selection, review and retained snapshot. It does not express owner '
    'approval of that alignment or prove geographic truth, publisher identity, '
    'independent human review, performance, institution identity or permission. '
    'Both observations retain their own block and provenance; position comparison '
    'within the declared chain/Core is not a shared canonical history proof. This additive scope '
    'does not complete MUSEUM-23 or change the nineteen packet groups or forty-nine '
    'dossier assessments.')
BINDING_KEYS = frozenset(('version', 'profileHash', 'ownerSourceProfileHash',
    'ownerManifestHash', 'ownerOccurrenceId', 'ownerSelector', 'venuePointer',
    'locationPointer', 'authorityProfileHash', 'authorityManifestHash',
    'declarationSelector', 'declarationHash', 'role', 'rationale'))
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'mode': MODE,
    'ownerSourceProfileHash': sources.PROFILE_HASH,
    'authorityProfileHash': authority.PROFILE_HASH,
    'bindingKeys': sorted(BINDING_KEYS),
    'binding': 'External JCS selector pin plus original owner venue.location commitment '
        'to exact whole original Place declaration payload. Same chain/Core; declaration '
        'publication strictly precedes owner publication. URI is opaque documentary text.',
    'alignment': 'Only resolved reviewed GETTY_TGN equivalent_entity candidates bound '
        'to that exact declaration may emit equivalent. Other declarations, weak relations, '
        'disputes, superseded candidates and ambiguity remain retained evidence.',
    'activity': 'Only completed owner statements with explicit title, institution and venue '
        'names produce Activity/took_place_at. The bound Place may remain without Activity.',
    'retention': 'Complete original V3 and authority packages, owner inventory, original '
        'binding, selected evidence, coverage, graph provenance and offline model closure.',
    'verification': 'Reconstruct both original sources and every derived byte offline.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'exhibition geography requires public disclosure before reads')


def _json(raw):
    return loads(raw, maximum=MAX_BYTES, canonical=True)


def _binding(raw, digest, owner_hash, authority_hash):
    require(type(raw) is bytes and 0 < len(raw) <= MAX_BINDING
        and any(hex_bytes(digest, 32)) and keccak256(raw) == digest,
        'exhibition geography binding byte bound or external pin differs')
    value = loads(raw, maximum=MAX_BINDING, canonical=True)
    require(type(value) is dict and set(value) == BINDING_KEYS,
        'exhibition geography closed binding differs')
    require(value['version'] == '1' and value['profileHash'] == PROFILE_HASH
        and value['ownerSourceProfileHash'] == sources.PROFILE_HASH
        and value['authorityProfileHash'] == authority.PROFILE_HASH
        and value['ownerManifestHash'] == owner_hash and value['authorityManifestHash'] == authority_hash
        and value['venuePointer'] == '/venue' and value['locationPointer'] == '/venue/location'
        and value['role'] == 'exhibition_location'
        and type(value['rationale']) is str and 0 < len(value['rationale'].encode('utf-8')) <= 2048,
        'exhibition geography binding scope or profile differs')
    return value


def _admit(owner_files, owner_hash, authority_files, authority_hash, binding, directory, plan):
    _, inventory = sources.admit(owner_files, owner_hash,
        plan_files=dict(plan.files), plan_hash=plan.manifest_hash)
    selected = [row for row in inventory['rows'] if row['occurrenceId'] == binding['ownerOccurrenceId']]
    require(len(selected) == 1, 'exhibition geography exact owner occurrence missing')
    owner = selected[0]
    require(owner['selector'] == binding['ownerSelector']
        and owner['selector']['kind'] == 'native_owner_family'
        and owner['family'] == 'EXHIBITION' and owner['semantic'] is not None,
        'exhibition geography original supported owner EXHIBITION required')
    value, bounds = exhibitions.validate_payload(hex_bytes(owner['original']['record'][5]))
    require(value == owner['semantic'], 'exhibition geography original owner payload differs')
    write_tree(authority_files, directory)
    verified = authority_package.verify_authority_package(directory, authority_hash)
    retained = dict(verified.files)
    source_manifest = _json(retained['source/manifest.json'])
    pins = source_manifest['pins']
    recorded = replay_source_bytes(directory / 'source/dependencies',
        {name: retained['source/inputs/' + name] for name in INPUT_FILES},
        **{key + '_hash': pins[key] for key in ('source', 'publication', 'interpretation', 'profile')})
    require(all(inventory['sourceState'][key] == recorded.anchor[key] for key in ('chainId', 'core', 'environment')),
        'exhibition geography chain/Core/environment differs')
    declaration, original = recorded.entity(recorded.state, binding['declarationSelector'], recorded.profile_hash)
    evidence = declaration_evidence(declaration, binding['declarationSelector'])
    require(declaration['kind'] == 'place' and declaration['id'] == value['venue']['entityId']
        and evidence['declarationHash'] == binding['declarationHash'],
        'exhibition geography exact Place declaration differs')
    require(value['venue']['location']['hash'] == {'algorithm': '1', 'digest': original.payload_hash,
        'canonicalizationId': JCS_ID} and keccak256(original.payload) == original.payload_hash,
        'exhibition geography owner location does not commit to original declaration payload')
    owner_position = tuple(uint(owner['original']['publication'][key], 64)
        for key in ('blockNumber', 'transactionIndex', 'logIndex'))
    declaration_position = recorded.positions[original.selector.record_hash]
    require(declaration_position < owner_position,
        'exhibition geography declaration must precede owner publication')
    report, candidates = _json(retained['authority/report.json']), _json(retained['authority/sidecar.json'])
    matches = [row for row in report['results'] if row['entityId'] == declaration['id']
        and row['authority'] == 'GETTY_TGN' and row['entityKind'] == 'Place']
    require(len(matches) == 1, 'exhibition geography exact Place/TGN request missing')
    result = matches[0]
    eligible = [row for row in candidates if row['body']['alignment']['entityId'] == declaration['id']
        and row['body']['alignment']['authority'] == 'GETTY_TGN' and row['body']['entityKind'] == 'Place'
        and row['entityDeclaration'] == evidence and row['eligible'] and not row['supersededBy']
        and row['body']['alignment']['matchKind'] == 'equivalent_entity']
    identities = sorted({row['body']['alignment']['canonicalIri'] for row in eligible})
    equivalent = identities[0] if result['status'] == 'resolved' and len(identities) == 1 else None
    require(equivalent is None or result['candidateIdentities'] == identities,
        'exhibition geography resolved authority identities differ')
    selected_evidence = {'ownerOccurrenceId': owner['occurrenceId'], 'ownerSelector': owner['selector'],
        'ownerAuthority': owner['authority'], 'ownerCurrentness': owner['currentness'],
        'ownerPublication': owner['original']['publication'], 'ownerPayload': value,
        'ownerPointers': owner['pointers'], 'declaration': evidence,
        'declarationOriginalPayloadHex': '0x' + original.payload.hex(),
        'declarationPayloadHash': original.payload_hash,
        'declarationAuthority': _json(original.authority_evidence),
        'declarationPublicationPosition': [str(v) for v in declaration_position],
        'authoritySourceState': dict(recorded.anchor), 'authorityResult': result,
        'eligibleBoundAssertions': [row['assertion']['id'] for row in eligible],
        'equivalent': equivalent, 'claims': CLAIMS, 'qualification': QUALIFICATION}
    return inventory, owner, value, bounds, selected_evidence


def _graph(owner, value, bounds, selected, model):
    files, index, provenance = {}, [], []
    identifier = value['venue']['entityId']
    def named(identity, kind, name):
        resource = {'@context': CONTEXT, 'id': identity, 'type': kind,
            '_label': identity if name is None else name['value'],
            'referred_to_by': [{'type': 'LinguisticObject', 'content': QUALIFICATION}]}
        if name is not None: resource['identified_by'] = [{'type': 'Name', 'content': name['value']}]
        return resource
    def emit(resource, rule, pointers):
        key = keccak256(resource['id'].encode('utf-8'))[2:]
        path = 'geography/resources/' + key + '.json'
        require(path not in files, 'exhibition geography conflicting resource identities')
        raw = dumps(resource)
        files[path] = raw
        files['geography/expanded/' + key + '.json'] = model.validate_and_expand(raw).expanded_bytes
        index.append({'id': resource['id'], 'type': resource['type'], 'path': path})
        provenance.extend({'entity': resource['id'], 'graphPointer': pointer, 'value': scalar,
            'ownerOccurrenceId': owner['occurrenceId'], 'ownerSelector': owner['selector'],
            'ownerPayloadPointers': pointers, 'binding': 'inputs/binding.json',
            'selectedEvidence': 'geography/selected-evidence.json',
            'authorityEvidence': 'sources/authority/authority/provenance.json' if pointer.startswith('/equivalent') else None,
            'rule': rule, 'qualification': QUALIFICATION} for pointer, scalar in exhibitions.fields(resource))
    place = named(identifier, 'Place', value['venue']['name'])
    if selected['equivalent'] is not None:
        place['equivalent'] = [{'id': selected['equivalent'], 'type': 'Place', '_label': selected['equivalent']}]
    emit(place, 'original_location_commitment_and_separate_reviewed_alignment', ['/venue'])
    missing = [key + '_name_not_recorded' for key in ('title', 'institution', 'venue') if value[key]['name'] is None]
    disposition = 'nonperformed_source' if value['status'] != 'completed' else 'unsupported' if missing else 'activity'
    if disposition == 'activity':
        group = named(value['institution']['entityId'], 'Group', value['institution']['name'])
        emit(group, 'owner_named_institution_participant', ['/institution'])
        event = named(value['exhibitionId'], 'Activity', value['title']['name'])
        event['participant'] = [{'id': group['id'], 'type': 'Group'}]
        event['took_place_at'] = [{'id': identifier, 'type': 'Place'}]
        span = {'type': 'TimeSpan', 'identified_by': [{'type': 'Name',
            'content': value['opening']['expression'] + ' / ' + value['closing']['expression']}]}
        for i, key, targets in ((0, 'opening', ('begin_of_the_begin', 'end_of_the_begin')),
                (1, 'closing', ('begin_of_the_end', 'end_of_the_end'))):
            date = value[key]
            if bounds[i] and date['earliest'] is not None:
                span[targets[0]], span[targets[1]] = date['earliest'], date['latest']
        event['timespan'] = span
        emit(event, 'owner_completed_exhibition_statement', ['/exhibitionId', '/status', '/title',
            '/institution', '/venue', '/opening', '/closing'])
    files['geography/index.json'] = dumps({'resources': sorted(index, key=lambda row: row['id'])})
    files['geography/provenance.json'] = dumps(provenance)
    files['geography/coverage.json'] = dumps([{'source': 'owner_payload', 'ownerOccurrenceId': owner['occurrenceId'],
        'pointer': pointer, 'value': scalar, 'disposition': 'retained_original'}
        for pointer, scalar in exhibitions.fields(value)] + [
        {'source': 'bound_declaration', 'selector': selected['declaration']['source'],
            'pointer': pointer, 'value': scalar, 'disposition': 'retained_original'}
        for pointer, scalar in exhibitions.fields(selected['declaration']['value'])])
    return files, {'disposition': disposition, 'missingNames': missing,
        'authorityStatus': selected['authorityResult']['status'],
        'boundEquivalentEmitted': selected['equivalent'] is not None}


def build(owner_files, owner_hash, authority_files, authority_hash, binding_raw, binding_hash, *,
          disclosure, model_root=MODEL_ROOT, plan_files=None, plan_hash=None):
    """Build one explicitly bound join after replaying both complete original packages."""
    _public(disclosure)
    try:
        _bounded(owner_files); _bounded(authority_files)
        binding = _binding(binding_raw, binding_hash, owner_hash, authority_hash)
        plan = sources._plan(plan_files, plan_hash)
        with TemporaryDirectory(prefix='stream-exhibition-authority-') as temporary:
            inventory, owner, value, bounds, selected = _admit(owner_files, owner_hash,
                authority_files, authority_hash, binding, Path(temporary) / 'authority', plan)
        root = Path(model_root).resolve()
        graph, graph_report = _graph(owner, value, bounds, selected, validator(root))
        report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'mode': MODE,
            'ownerManifestHash': owner_hash, 'authorityManifestHash': authority_hash,
            'bindingHash': binding_hash, 'ownerSourceState': inventory['sourceState'],
            'ownerSourceProvenance': _json(owner_files[sources.OWNER_PREFIX + 'sources/owner/snapshot.json'])['mode'],
            'ownerSourceBindings': inventory['sourceBindings'],
            'authoritySourceQualification': 'externally_pinned_recorded_transcript_replay_not_origin_authentication',
            'graph': graph_report, 'claims': CLAIMS, 'qualification': QUALIFICATION}
        files = {'sources/owner/' + path: raw for path, raw in owner_files.items()}
        files.update({'sources/authority/' + path: raw for path, raw in authority_files.items()})
        files.update(sources.definition_files(plan_files=dict(plan.files), plan_hash=plan.manifest_hash))
        files.update(_dependencies(root, recorded=True)); files.update(graph)
        files.update({'inputs/binding.json': binding_raw, 'source/owner-inventory.json': dumps(inventory),
            'source/locations.json': dumps({'ownerOriginalReferenceBase': 'sources/owner/',
                'ownerInventoryReferenceBase': 'sources/owner/', 'ownerDefinitionsReferenceBase': '',
                'authorityPackageReferenceBase': 'sources/authority/',
                'authorityRecordedSourceReferenceBase': 'sources/authority/source/',
                'exportReferenceBase': '',
                'rule': 'Original path/hash/JSON-pointer descriptors remain unchanged; prepend their declared base only when resolving in this export.'}),
            'geography/selected-evidence.json': dumps(selected), 'report.json': dumps(report),
            'definitions/profile.json': PROFILE_BYTES, 'definitions/owner-source-profile.json': sources.PROFILE_BYTES,
            'definitions/authority-profile.json': authority.PROFILE_BYTES})
        _bounded(files)
        manifest = dumps({'mode': MODE, 'version': '1', 'profileHash': PROFILE_HASH,
            'ownerManifestHash': owner_hash, 'authorityManifestHash': authority_hash,
            'ownerDefinitionPlanManifestHash': plan.manifest_hash,
            'bindingHash': binding_hash, 'disclosure': disclosure,
            'files': [_ref(path, raw) for path, raw in sorted(files.items())]})
        require(len(manifest) <= MAX_MANIFEST, 'exhibition geography manifest byte bound')
        files['manifest.json'] = manifest; _bounded(files)
        return Assembly(tuple(sorted(files.items())), manifest, report)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed exhibition geography input') from exc


def verify(files, manifest_hash):
    """Rebuild every byte with the exact retained sources, binding and model closure."""
    try:
        _bounded(files); raw = files.get('manifest.json', b'')
        require(any(hex_bytes(manifest_hash, 32)) and keccak256(raw) == manifest_hash,
            'exhibition geography external manifest pin differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'version', 'profileHash',
            'ownerManifestHash', 'authorityManifestHash', 'ownerDefinitionPlanManifestHash',
            'bindingHash', 'disclosure', 'files'}
            and manifest['mode'] == MODE and manifest['version'] == '1' and manifest['profileHash'] == PROFILE_HASH,
            'exhibition geography closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [_ref(path, body) for path, body in sorted(files.items()) if path != 'manifest.json'],
            'exhibition geography file commitments differ')
        def subtree(prefix):
            return {path.removeprefix(prefix): body for path, body in files.items() if path.startswith(prefix)}
        with TemporaryDirectory(prefix='stream-exhibition-model-') as temporary:
            root = Path(temporary) / 'model'; write_tree(subtree('dependencies/'), root)
            rebuilt = build(subtree('sources/owner/'), manifest['ownerManifestHash'],
                subtree('sources/authority/'), manifest['authorityManifestHash'],
                files['inputs/binding.json'], manifest['bindingHash'], disclosure=manifest['disclosure'], model_root=root,
                plan_files=subtree('definitions/owner-genesis-plan/'),
                plan_hash=manifest['ownerDefinitionPlanManifestHash'])
        require(dict(rebuilt.files) == files, 'exhibition geography full reconstruction differs')
        return rebuilt
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed exhibition geography package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    create = commands.add_parser('build')
    for name in ('owner', 'authority', 'binding', 'output'): create.add_argument(name, type=Path)
    for name in ('owner-hash', 'authority-hash', 'binding-hash'): create.add_argument('--' + name, required=True)
    create.add_argument('--disclosure', choices=('public',), required=True)
    check = commands.add_parser('verify'); check.add_argument('directory', type=Path); check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles': result = {'profileHash': PROFILE_HASH}
        elif args.command == 'verify':
            result = {'manifestHash': verify(read_tree(args.directory), args.manifest_hash).manifest_hash}
        else:
            _public(args.disclosure)
            require(args.binding.stat().st_size <= MAX_BINDING, 'exhibition geography binding file bound')
            with args.binding.open('rb') as handle: raw = handle.read(MAX_BINDING + 1)
            built = build(read_tree(args.owner), args.owner_hash, read_tree(args.authority), args.authority_hash,
                raw, args.binding_hash, disclosure=args.disclosure)
            _publish(dict(built.files), args.output, [args.owner, args.authority, args.binding])
            result = {'manifestHash': built.manifest_hash, 'report': built.report}
        print(dumps(result).decode('utf-8'))
    except (MuseumError, OSError) as exc: parser.exit(1, 'exhibition geography: ' + str(exc) + '\n')


if __name__ == '__main__': main()
