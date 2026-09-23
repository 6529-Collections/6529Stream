"""Add verified semantic families to an unchanged canonical V3/V10 dossier.

V4 is an additive envelope.  It replays every supplied child, preserves the
canonical semantic V2 package byte-for-byte, and leaves its nineteen packet
groups and forty-nine requirement decisions unchanged.  Supplemental
statements are evidence occurrences, never requirement promotions.
"""
import argparse
from pathlib import Path

from . import canonical_dossier_observations_v4 as observations
from . import canonical_semantic_export_v2 as canonical
from . import general_semantic_dossier_v1 as general
from . import recorded_physical_production_v1 as production
from . import recorded_physical_transfer_v1 as transfer
from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require


NAME = 'STREAM_OBJECT_DOSSIER_V4'
MODE = 'canonical_object_dossier_v4_assembly'
DOSSIER_PATH = 'dossier/object-dossier-v4.json'
SUPPLEMENTAL_PATH = 'dossier/supplemental-families.json'
OBSERVATIONS_PATH = 'dossier/source-observations.json'
MISSING_PATH = 'dossier/missing-evidence.json'
PREFIXES = {'canonical': 'canonical/', 'production': 'production/',
            'general': 'general/', 'transfer': 'transfer/'}
CLAIMS = {
    'canonicalSemanticV2Replayed': True,
    'canonicalV3AndV10BytesRetained': True,
    'allNineteenPacketGroupsRetained': True,
    'allFortyNineRequirementsRetained': True,
    'supplementalSourcesReplayed': True,
    'supplementalRequirementPromotions': False,
    'semanticResourceIdentitiesMergedAcrossFamilies': False,
    'sourceOriginAuthenticated': False,
    'globalHostInventoryProven': False,
    'physicalPerformanceProven': False,
    'legalTitleOrCurrentCustodyProven': False,
    'institutionalStandingOrAcceptanceProven': False,
    'completeSemanticMappingProven': False,
    'completeCanonicalDossier': False,
    'profileRegistered': False,
    'networkFetch': False,
}
QUALIFICATION = (
    'The exact canonical semantic V2 package remains the sole V3/V10 and '
    'nineteen/forty-nine denominator. Optional Artist physical-production, '
    'General documentary and General physical-transfer packages are replayed '
    'as separate supplemental source families. Their graph namespaces and '
    'original selectors remain distinct; matching IRIs are not merged. A '
    'transfer package already contains its complete General source package, '
    'so a separately supplied General package must be byte-identical and is '
    'not stored twice. Same-anchor positive source contradictions reject; '
    'different states, configurations or provenance remain explicit unjoined '
    'observations. Collection and media statements are documentary scope, not '
    'token authority. No supplemental package promotes an original requirement '
    'decision or proves physical performance, legal title, current custody, '
    'institutional standing, acceptance, global source completeness or full '
    'semantic conformance.')
PROFILE_BYTES = dumps({
    'name': NAME, 'version': '4', 'mode': MODE,
    'canonicalProfileHash': canonical.PROFILE_HASH,
    'productionProfileHash': production.PROFILE_HASH,
    'generalProfileHash': general.PROFILE_HASH,
    'transferProfileHash': transfer.PROFILE_HASH,
    'observationProfileHash': observations.PROFILE_HASH,
    'prefixes': PREFIXES,
    'retention': 'Verified packages are retained byte-for-byte under fixed prefixes. '
        'General is stored under general/ only without transfer; otherwise the exact '
        'nested transfer/sources/general-dossier/ package is the one retained occurrence.',
    'requirements': 'The exact original nineteen packet-group and forty-nine dossier '
        'assessment bytes remain under canonical/input/. Supplemental evidence has no promotions.',
    'verification': 'Replay every child, reconcile original source observations, then '
        'reconstruct and compare every output byte.',
    'claims': CLAIMS, 'qualification': QUALIFICATION,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'object dossier V4 public disclosure required before reads')


def _paired(files, digest, label):
    require((files is None) == (digest is None),
        'object dossier V4 ' + label + ' files and pin must be supplied together')


def _files(result):
    return dict(result.files)


def _subtree(files, prefix):
    return {path.removeprefix(prefix): raw for path, raw in files.items()
            if path.startswith(prefix)}


def _dependencies(files):
    return _subtree(files, 'dependencies/')


def _manifest(files):
    return loads(files['manifest.json'], maximum=MAX_MANIFEST, canonical=True)


def _located(files, prefix, path, selector=''):
    require(path in files, 'object dossier V4 family reference missing: ' + path)
    return {**package._ref(prefix + path, files[path]), 'selector': selector}


def _family_references(role, files, prefix):
    paths = {
        'canonical': {'graphIndex': ('semantic/index.json', ''),
            'selection': ('semantic/selection.json', ''),
            'statements': ('semantic/assertions.json', ''),
            'provenance': ('semantic/provenance.json', ''),
            'coverage': ('semantic/coverage.json', '')},
        'production': {'graphIndex': ('production/index.json', ''),
            'selection': ('sources/attribution/dossier.json', '/selection'),
            'statements': ('production/sidecar.json', '/rows'),
            'provenance': ('production/provenance.json', ''),
            'coverage': ('production/coverage.json', '')},
        'general': {'graphIndex': ('graph/index.json', ''),
            'selection': ('graph/selection.json', ''),
            'statements': ('graph/sidecar.json', '/statements'),
            'provenance': ('graph/provenance.json', ''),
            'coverage': ('graph/source-coverage.json', '')},
        'transfer': {'graphIndex': ('transfer/index.json', ''),
            'selection': (transfer.SOURCE_PREFIX + 'graph/selection.json', ''),
            'statements': ('transfer/sidecar.json', '/statements'),
            'provenance': ('transfer/provenance.json', ''),
            'coverage': ('transfer/source-coverage.json', '')},
    }[role]
    return {name: _located(files, prefix, path, selector)
            for name, (path, selector) in paths.items()}


def _child(role, checked, manifest_hash, prefix, storage='standalone'):
    files = _files(checked)
    manifest = _manifest(files)
    return {'role': role, 'status': 'retained', 'profileHash': manifest['profileHash'],
        'mode': manifest['mode'], 'manifestHash': manifest_hash, 'prefix': prefix,
        'storage': storage, 'sourceState': checked.report['sourceState'],
        'report': package._ref(prefix + 'report.json', files['report.json']),
        'references': _family_references(role, files, prefix),
        'requirementPromotions': [],
        'graphIdentityMergedAcrossFamilies': False}


def _absent(role):
    return {'role': role, 'status': 'absent', 'profileHash': None, 'mode': None,
        'manifestHash': None, 'prefix': None, 'storage': 'absent',
        'sourceState': None, 'report': None, 'references': None, 'requirementPromotions': [],
        'graphIdentityMergedAcrossFamilies': False}


def _assessment(base):
    raw = base['input/dossier/requirements.json']
    value = loads(raw, maximum=MAX_BYTES, canonical=True)
    require(type(value) is dict and value['counts']['total'] == 49
        and len(value['results']) == 49,
        'object dossier V4 exact forty-nine assessment denominator differs')
    report = loads(base['input/report.json'], maximum=MAX_BYTES, canonical=True)
    packet = report['packetRequirements']
    require(type(packet) is list and len(packet) == 19,
        'object dossier V4 exact nineteen packet denominator differs')
    return raw, value, packet


def _compose(canonical_files, canonical_hash, production_files, production_hash,
             general_files, general_hash, transfer_files, transfer_hash, disclosure):
    _public(disclosure)
    for role, supplied, digest in (
            ('production', production_files, production_hash),
            ('general', general_files, general_hash),
            ('transfer', transfer_files, transfer_hash)):
        _paired(supplied, digest, role)

    base_result = canonical.verify(dict(canonical_files), canonical_hash)
    base = _files(base_result)
    production_result = (None if production_files is None else
        production.verify(dict(production_files), production_hash))
    transfer_result = (None if transfer_files is None else
        transfer.verify(dict(transfer_files), transfer_hash))
    supplied_general_result = (None if general_files is None else
        general.verify(dict(general_files), general_hash))

    transfer_general, nested_general_hash = None, None
    if transfer_result is not None:
        transferred = _files(transfer_result)
        transfer_general = _subtree(transferred, transfer.SOURCE_PREFIX)
        transfer_manifest = _manifest(transferred)
        nested_general_hash = transfer_manifest['sourceManifestHash']
        require(transfer_general and keccak256(transfer_general['manifest.json']) == nested_general_hash,
            'object dossier V4 transfer nested General pin differs')
        if supplied_general_result is not None:
            require(general_hash == nested_general_hash
                and _files(supplied_general_result) == transfer_general,
                'object dossier V4 redundant General package differs from transfer source')

    effective_general = (transfer_general if transfer_general is not None else
        None if supplied_general_result is None else _files(supplied_general_result))
    effective_general_result = supplied_general_result
    if effective_general is not None and effective_general_result is None:
        # Transfer verification already replayed these exact nested bytes.  The
        # retained report is read only after that successful reconstruction.
        effective_general_report = loads(effective_general['report.json'],
            maximum=MAX_BYTES, canonical=True)
    else:
        effective_general_report = (None if effective_general_result is None
            else effective_general_result.report)

    baseline_dependencies = _dependencies(base)
    require(baseline_dependencies, 'object dossier V4 canonical model dependency closure missing')
    for role, result in (('production', production_result), ('general', supplied_general_result),
                         ('transfer', transfer_result)):
        if result is not None:
            require(_dependencies(_files(result)) == baseline_dependencies,
                'object dossier V4 ' + role + ' model dependency closure differs')

    standalone_general = (None if transfer_result is not None else effective_general)
    source_rows = observations.sources(base,
        production_files=None if production_result is None else _files(production_result),
        general_files=standalone_general,
        transfer_files=None if transfer_result is None else _files(transfer_result))
    reconciliation = observations.reconcile(base_result.report['sourceState'], source_rows)
    subjects = observations.subjects(base_result.report['sourceState'],
        production_files=None if production_result is None else _files(production_result),
        general_files=standalone_general,
        transfer_files=None if transfer_result is None else _files(transfer_result))

    assessment_raw, assessment, packet_requirements = _assessment(base)
    families = [_child('canonical', base_result, canonical_hash, PREFIXES['canonical'])]
    families.append(_absent('production') if production_result is None else
        _child('production', production_result, production_hash, PREFIXES['production']))
    if effective_general is None:
        families.append(_absent('general'))
    elif transfer_result is not None:
        families.append({'role': 'general', 'status': 'retained',
            'profileHash': _manifest(effective_general)['profileHash'],
            'mode': _manifest(effective_general)['mode'], 'manifestHash': nested_general_hash,
            'prefix': PREFIXES['transfer'] + transfer.SOURCE_PREFIX,
            'storage': 'nested_in_transfer', 'sourceState': effective_general_report['sourceState'],
            'report': package._ref(PREFIXES['transfer'] + transfer.SOURCE_PREFIX + 'report.json',
                effective_general['report.json']),
            'references': _family_references('general', effective_general,
                PREFIXES['transfer'] + transfer.SOURCE_PREFIX),
            'requirementPromotions': [],
            'graphIdentityMergedAcrossFamilies': False})
    else:
        families.append(_child('general', supplied_general_result, general_hash, PREFIXES['general']))
    families.append(_absent('transfer') if transfer_result is None else
        _child('transfer', transfer_result, transfer_hash, PREFIXES['transfer']))

    unresolved = [row['code'] for row in assessment['results'] if row['state'] != 'verified']
    unjoined = [{'name': row['name'], 'reasons': row['reasons']}
        for row in reconciliation['sources'] if row['status'] == 'unjoined']
    non_token = [{'family': row['family'], 'source': row['source'],
        'selectionDisposition': row['selectionDisposition'], 'status': row['status']}
        for row in subjects if row['status'] != 'exact_token_subject']
    missing = {'unresolvedOriginalRequirementCodes': unresolved,
        'absentSupplementalFamilies': [row['role'] for row in families if row['status'] == 'absent'],
        'unjoinedSourceObservations': unjoined,
        'nonTokenOrUnboundStatementApplicability': non_token,
        'requirementPromotions': [],
        'notEstablishedBySupplementalFamilies': [
            'global record/host/event inventory', 'physical performance',
            'legal title or current custody', 'institutional standing or acceptance',
            'complete field-level semantic mapping and museum conformance'],
        'qualification': QUALIFICATION}
    supplemental = {'families': families, 'subjects': subjects,
        'requirementPromotions': [], 'graphIdentityMergePolicy': 'none',
        'canonicalPacketRequirementCount': '19',
        'canonicalDossierRequirementCount': '49',
        'canonicalAssessment': package._ref(
            PREFIXES['canonical'] + 'input/dossier/requirements.json', assessment_raw),
        'canonicalPacketReport': package._ref(
            PREFIXES['canonical'] + 'input/report.json', base['input/report.json']),
        'qualification': QUALIFICATION}
    dossier = {'schema': NAME, 'version': 4,
        'sourceState': base_result.report['sourceState'],
        'canonicalSemanticPackage': package._ref(
            PREFIXES['canonical'] + 'manifest.json', base['manifest.json']),
        'supplementalFamilies': package._ref(SUPPLEMENTAL_PATH, dumps(supplemental)),
        'sourceObservations': package._ref(OBSERVATIONS_PATH, dumps(reconciliation)),
        'missingEvidence': package._ref(MISSING_PATH, dumps(missing)),
        'packetRequirements': {'count': '19', 'source': supplemental['canonicalPacketReport']},
        'dossierRequirements': {'count': '49', 'source': supplemental['canonicalAssessment']},
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'version': '4',
        'sourceState': base_result.report['sourceState'],
        'canonicalManifestHash': canonical_hash,
        'inputs': {row['role']: row['manifestHash'] for row in families},
        'familyPresence': {row['role']: row['status'] == 'retained' for row in families},
        'sourceReconciliation': reconciliation,
        'packetRequirementCount': str(len(packet_requirements)),
        'dossierRequirementCount': str(len(assessment['results'])),
        'originalDossierRequirementCounts': assessment['counts'],
        'requirementPromotions': [], 'missingEvidence': missing,
        'claims': CLAIMS, 'qualification': QUALIFICATION}

    output = {PREFIXES['canonical'] + path: raw for path, raw in base.items()}
    if production_result is not None:
        output.update({PREFIXES['production'] + path: raw
            for path, raw in _files(production_result).items()})
    if transfer_result is not None:
        output.update({PREFIXES['transfer'] + path: raw
            for path, raw in _files(transfer_result).items()})
    elif supplied_general_result is not None:
        output.update({PREFIXES['general'] + path: raw
            for path, raw in _files(supplied_general_result).items()})
    output.update({DOSSIER_PATH: dumps(dossier), SUPPLEMENTAL_PATH: dumps(supplemental),
        OBSERVATIONS_PATH: dumps(reconciliation), MISSING_PATH: dumps(missing),
        'definitions/profile.json': PROFILE_BYTES,
        'definitions/observation-profile.json': observations.PROFILE_BYTES,
        'report.json': dumps(report)})
    package._bounded(output)
    inputs = {'canonical': canonical_hash,
        'production': None if production_result is None else production_hash,
        'general': (nested_general_hash if transfer_result is not None else
            None if supplied_general_result is None else general_hash),
        'generalStorage': ('nested_in_transfer' if transfer_result is not None else
            'absent' if supplied_general_result is None else 'standalone'),
        'transfer': None if transfer_result is None else transfer_hash}
    manifest = dumps({'mode': MODE, 'profile': NAME, 'version': '4',
        'profileHash': PROFILE_HASH, 'inputs': inputs, 'disclosure': disclosure,
        'dossier': package._ref(DOSSIER_PATH, output[DOSSIER_PATH]),
        'files': [package._ref(path, raw) for path, raw in sorted(output.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'object dossier V4 manifest byte bound')
    output['manifest.json'] = manifest
    package._bounded(output)
    return package.Assembly(tuple(sorted(output.items())), manifest, report)


def compose(canonical_files, canonical_hash, *, production_files=None, production_hash=None,
            general_files=None, general_hash=None, transfer_files=None, transfer_hash=None,
            disclosure):
    try:
        return _compose(canonical_files, canonical_hash, production_files, production_hash,
            general_files, general_hash, transfer_files, transfer_hash, disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed object dossier V4 inputs') from exc


def verify(files, expected_hash):
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'object dossier V4 external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version',
            'profileHash', 'inputs', 'disclosure', 'dossier', 'files', 'claims', 'qualification'}
            and manifest['mode'] == MODE and manifest['profile'] == NAME
            and manifest['version'] == '4' and manifest['profileHash'] == PROFILE_HASH
            and manifest['claims'] == CLAIMS and manifest['qualification'] == QUALIFICATION
            and type(manifest['inputs']) is dict and set(manifest['inputs']) == {
                'canonical', 'production', 'general', 'generalStorage', 'transfer'},
            'object dossier V4 closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [package._ref(path, body)
            for path, body in sorted(files.items()) if path != 'manifest.json'],
            'object dossier V4 file commitments differ')
        children = {role: _subtree(files, prefix) for role, prefix in PREFIXES.items()}
        storage = manifest['inputs']['generalStorage']
        require(storage in ('absent', 'standalone', 'nested_in_transfer')
            and bool(children['production']) == (manifest['inputs']['production'] is not None)
            and bool(children['transfer']) == (manifest['inputs']['transfer'] is not None)
            and bool(children['general']) == (storage == 'standalone')
            and (storage == 'nested_in_transfer') == bool(children['transfer'])
            and (manifest['inputs']['general'] is None) == (storage == 'absent'),
            'object dossier V4 child presence differs')
        result = compose(children['canonical'], manifest['inputs']['canonical'],
            production_files=children['production'] or None,
            production_hash=manifest['inputs']['production'],
            general_files=children['general'] or None,
            general_hash=manifest['inputs']['general'] if storage == 'standalone' else None,
            transfer_files=children['transfer'] or None,
            transfer_hash=manifest['inputs']['transfer'], disclosure=manifest['disclosure'])
        require(dict(result.files) == files, 'object dossier V4 full reconstruction differs')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed object dossier V4 package') from exc


def complete(files, expected_hash):
    result = verify(files, expected_hash)
    missing = result.report['missingEvidence']
    details = missing['unresolvedOriginalRequirementCodes'] or missing['notEstablishedBySupplementalFamilies']
    raise MuseumError('complete canonical dossier unavailable; missing evidence: ' + ', '.join(details))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('profiles')
    create = commands.add_parser('assemble')
    create.add_argument('--canonical', type=Path, required=True)
    create.add_argument('--canonical-hash', required=True)
    for role in ('production', 'general', 'transfer'):
        create.add_argument('--' + role, type=Path)
        create.add_argument('--' + role + '-hash')
    create.add_argument('--disclosure', required=True)
    create.add_argument('--output', type=Path, required=True)
    for name in ('verify', 'complete'):
        command = commands.add_parser(name)
        command.add_argument('directory', type=Path)
        command.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'profiles':
            result = {'profileHash': PROFILE_HASH, 'canonicalProfileHash': canonical.PROFILE_HASH,
                'observationProfileHash': observations.PROFILE_HASH}
        elif args.command == 'assemble':
            _public(args.disclosure)
            from .repository_exchange import _destination, _publish
            sources = [args.canonical]
            for role in ('production', 'general', 'transfer'):
                path = getattr(args, role)
                _paired(path, getattr(args, role + '_hash'), role)
                if path is not None:
                    sources.append(path)
            _destination(args.output, sources)
            result = compose(read_tree(args.canonical), args.canonical_hash,
                production_files=None if args.production is None else read_tree(args.production),
                production_hash=args.production_hash,
                general_files=None if args.general is None else read_tree(args.general),
                general_hash=args.general_hash,
                transfer_files=None if args.transfer is None else read_tree(args.transfer),
                transfer_hash=args.transfer_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, sources)
            result = {'manifestHash': result.manifest_hash, 'report': result.report}
        else:
            function = complete if args.command == 'complete' else verify
            checked = function(read_tree(args.directory), args.manifest_hash)
            result = {'manifestHash': checked.manifest_hash, 'report': checked.report}
        print(dumps(result).decode('utf-8'))
    except MuseumError as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
