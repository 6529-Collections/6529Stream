"""Link five evidence families to an unchanged verified canonical V4 dossier.

The canonical child already retains its native media and prospective-reference
captures. Optional script and preservation-object children remain separate
originals. Every link is supplemental; no original requirement is promoted.
"""
import argparse
from pathlib import Path

from . import canonical_object_dossier_v4 as dossier
from . import canonical_dossier_script_links_v1 as script_links
from . import canonical_evidence_observations_v2 as observations
from . import canonical_evidence_occurrences_v2 as occurrences
from . import collection_script_package_v1 as scripts
from . import premis_retained as properties
from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CANONICAL_EVIDENCE_LINKS_V2'
MODE = 'canonical_dossier_evidence_links_v2'
LINKS_PATH = 'evidence/requirement-links.json'
OBSERVATIONS_PATH = 'evidence/source-observations.json'
ASSESSMENT = script_links.ASSESSMENT
PACKET_REPORT = script_links.PACKET_REPORT
CODES = (*script_links.CODES, 'OD-MEDIA-MANIFEST', 'OD-RENDER-INVENTORY',
    'OD-SIGNIFICANT-PROPERTIES')
CLAIMS = {'concreteChildrenReplayed': True, 'originalChildrenRetained': True,
    'originalAssessmentsUnchanged': True, 'originalOccurrenceReferencesPreserved': True,
    'allSuppliedSourcesComparedTogether': True, 'nestedCanonicalCapturesDuplicated': False,
    'requirementPromotions': False, 'tokenAuthorityInferred': False,
    'authoritativeRenderInventory': False, 'postMintRenderExecutionProven': False,
    'completeSignificantPropertiesInventory': False, 'currentAuthorityEstablished': False,
    'scriptExecuted': False, 'uriResourcesRetrieved': False,
    'runtimeBridgeContentsVerified': False, 'registeredInterpretationProven': False,
    'sourceOriginAuthenticated': False, 'consensusVerified': False,
    'completeObjectDossier': False, 'institutionalAcceptance': False, 'networkFetch': False}
QUALIFICATION = (
    'Supplemental original observations for five fixed requirement slots of an unchanged canonical '
    'V4 dossier. All nineteen packet groups and forty-nine original assessments remain unchanged. '
    'Native media slots, historical selection and current eligibility remain separate. Prospective '
    'named simulations are supporting pre-sale collection records, not post-mint render execution '
    'or a complete authoritative render inventory. Selected preservation-object properties remain '
    'original account declarations; reference documents remain references. Empty selections, empty '
    'property arrays, missing bytes, unavailable calls, authored waivers and missing packages are '
    'distinct. Optional sources participate in one positive-observation comparison. Agreement does '
    'not authenticate source origin, prove consensus, current authority, complete inventories or '
    'institutional acceptance. No original requirement is accepted or promoted by this envelope.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '2', 'mode': MODE,
    'dossierProfileHash': dossier.PROFILE_HASH, 'scriptProfileHash': scripts.PROFILE_HASH,
    'propertiesProfileHash': properties.PROFILE_HASH,
    'scriptOccurrenceProfileHash': script_links.PROFILE_HASH,
    'observationProfileHash': observations.PROFILE_HASH,
    'occurrenceProfileHash': occurrences.PROFILE_HASH, 'requirementCodes': CODES,
    'prefixes': {'dossier': 'dossier/', 'scripts': 'scripts/', 'properties': 'properties/'},
    'retention': 'Verify direct children once and retain every original byte. Reuse native media '
        'and prospective-reference captures already inside the canonical V4 child.',
    'verification': 'Verify V4 and every optional concrete child; reconcile all original positive '
        'observations together; rebuild the supplemental links and every output byte.',
    'bounds': {'packageBytes': str(MAX_BYTES), 'manifestBytes': str(MAX_MANIFEST)},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'canonical evidence links require public disclosure before reads')


def _paired(files, digest, label):
    require((files is None) == (digest is None),
        'canonical evidence links ' + label + ' files and pin must be supplied together')


def _json(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _script_rows(files, checked):
    qualification = ('Supporting collection script observations. Original current and saved occurrences '
        'remain distinct; unavailable or inline source is not an invented manifest. Wire-empty '
        'dependency is local to its interpretation. No token authority or requirement acceptance.')
    if files is None:
        return [{'status': 'not_supplied', 'occurrences': [], 'sourceReferences': [],
            'availability': None, 'qualification': qualification} for _ in script_links.CODES]
    snapshot = _json(files, 'source/snapshot.json')
    return [{'status': 'observed',
        'occurrences': script_links._occurrences(files, snapshot, checked.report, role),
        'sourceReferences': [package._ref('scripts/' + path, files[path])
            for path in ('manifest.json', 'source/snapshot.json', 'report.json')],
        'availability': snapshot['availability'], 'sourceState': snapshot['sourceState'],
        'qualification': qualification} for role in ('script', 'dependency')]


def _compose(dossier_files, dossier_hash, script_files, script_hash,
             properties_files, properties_hash, disclosure):
    _public(disclosure)
    _paired(script_files, script_hash, 'scripts')
    _paired(properties_files, properties_hash, 'properties')
    original = {'dossier': dict(dossier_files)}
    if script_files is not None: original['scripts'] = dict(script_files)
    if properties_files is not None: original['properties'] = dict(properties_files)
    for files in original.values(): package._bounded(files)
    require(sum(len(raw) for files in original.values() for raw in files.values()) <= MAX_BYTES,
        'canonical evidence links aggregate input byte bound')
    # No derived report or semantic field is consumed before concrete replay.
    base = dossier.verify(original['dossier'], dossier_hash)
    script = None if script_files is None else scripts.verify(original['scripts'], script_hash)
    if properties_files is not None: properties.verify(original['properties'], properties_hash)
    base_files = original['dossier']
    script_files = original.get('scripts')
    properties_files = original.get('properties')
    assessment = _json(base_files, ASSESSMENT)
    packet = _json(base_files, PACKET_REPORT)
    require(assessment['counts']['total'] == 49 and len(assessment['results']) == 49
        and len(packet['packetRequirements']) == 19,
        'canonical evidence links original nineteen/forty-nine denominator differs')
    by_code = {row['code']: (index, row) for index, row in enumerate(assessment['results'])}
    require(len(by_code) == 49 and all(code in by_code for code in CODES),
        'canonical evidence links original requirement identity differs')
    observed = observations.reconcile(base_files, script_files, properties_files)
    typed = occurrences.extract(base_files, properties_files)
    require(set(typed) == {'media', 'render', 'properties'},
        'canonical evidence links occurrence families differ')
    families = [*_script_rows(script_files, script),
        typed['media'], typed['render'], typed['properties']]
    links = []
    for code, evidence in zip(CODES, families):
        index, row = by_code[code]
        links.append({**evidence, 'requirementCode': code,
            'originalAssessmentState': row['state'],
            'originalAssessment': script_links._located(base_files, 'dossier/', ASSESSMENT,
                '/results/' + str(index)),
            'role': 'supporting_original_observations', 'requirementAccepted': False,
            'tokenAuthorityInferred': False, 'requirementPromotions': [],
            'sourceReconciliation': package._ref(OBSERVATIONS_PATH, dumps(observed))})
    ledger = {'profile': NAME, 'profileHash': PROFILE_HASH, 'requirementLinks': links,
        'originalAssessment': package._ref('dossier/' + ASSESSMENT, base_files[ASSESSMENT]),
        'originalPacketReport': package._ref('dossier/' + PACKET_REPORT, base_files[PACKET_REPORT]),
        'packetRequirementCount': '19', 'dossierRequirementCount': '49',
        'untouchedRequirementCodes': [row['code'] for row in assessment['results']
            if row['code'] not in CODES],
        'requirementPromotions': [], 'claims': CLAIMS, 'qualification': QUALIFICATION}
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceState': base.report['sourceState'],
        'sourceReconciliation': observed, 'packetRequirementCount': '19',
        'dossierRequirementCount': '49', 'originalDossierRequirementCounts': assessment['counts'],
        'linkedRequirementCodes': list(CODES),
        'familyStatus': {code: value['status'] for code, value in zip(CODES, families)},
        'optionalPackages': {'scripts': script_files is not None,
            'properties': properties_files is not None},
        'requirementPromotions': [], 'claims': CLAIMS, 'qualification': QUALIFICATION}
    output = {role + '/' + path: raw for role, files in original.items() for path, raw in files.items()}
    output.update({LINKS_PATH: dumps(ledger), OBSERVATIONS_PATH: dumps(observed),
        'definitions/profile.json': PROFILE_BYTES,
        'definitions/observation-profile.json': observations.PROFILE_BYTES,
        'definitions/occurrence-profile.json': occurrences.PROFILE_BYTES,
        'report.json': dumps(report)})
    package._bounded(output)
    manifest = dumps({'mode': MODE, 'profile': NAME, 'version': '2', 'profileHash': PROFILE_HASH,
        'inputs': {'dossier': dossier_hash, 'scripts': script_hash, 'properties': properties_hash},
        'disclosure': disclosure, 'links': package._ref(LINKS_PATH, output[LINKS_PATH]),
        'files': [package._ref(path, raw) for path, raw in sorted(output.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'canonical evidence links manifest byte bound')
    output['manifest.json'] = manifest
    package._bounded(output)
    return package.Assembly(tuple(sorted(output.items())), manifest, report)


def compose(dossier_files, dossier_hash, *, script_files=None, script_hash=None,
            properties_files=None, properties_hash=None, disclosure):
    try:
        return _compose(dossier_files, dossier_hash, script_files, script_hash,
            properties_files, properties_hash, disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed canonical evidence link inputs') from exc


def verify(files, expected_hash):
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'canonical evidence links external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version',
            'profileHash', 'inputs', 'disclosure', 'links', 'files', 'claims', 'qualification'}
            and manifest['mode'] == MODE and manifest['profile'] == NAME
            and manifest['version'] == '2' and manifest['profileHash'] == PROFILE_HASH
            and manifest['claims'] == CLAIMS and manifest['qualification'] == QUALIFICATION
            and type(manifest['inputs']) is dict
            and set(manifest['inputs']) == {'dossier', 'scripts', 'properties'},
            'canonical evidence links closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [package._ref(path, body)
            for path, body in sorted(files.items()) if path != 'manifest.json'],
            'canonical evidence links file commitments differ')
        def child(role):
            subset = script_links._sub(files, role + '/')
            return subset if subset or manifest['inputs'][role] is not None else None
        rebuilt = compose(child('dossier'), manifest['inputs']['dossier'],
            script_files=child('scripts'), script_hash=manifest['inputs']['scripts'],
            properties_files=child('properties'), properties_hash=manifest['inputs']['properties'],
            disclosure=manifest['disclosure'])
        require(dict(rebuilt.files) == files, 'canonical evidence links full reconstruction differs')
        return rebuilt
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed canonical evidence link package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('assemble')
    for role in ('dossier', 'scripts', 'properties'):
        create.add_argument('--' + role, type=Path, required=role == 'dossier')
        create.add_argument('--' + role + '-hash', required=role == 'dossier')
    create.add_argument('--disclosure', required=True)
    create.add_argument('--output', type=Path, required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'assemble':
            _public(args.disclosure)
            for role in ('scripts', 'properties'):
                _paired(getattr(args, role), getattr(args, role + '_hash'), role)
            from .repository_exchange import _destination, _publish
            inputs = [value for value in (args.dossier, args.scripts, args.properties) if value is not None]
            _destination(args.output, inputs)
            result = compose(read_tree(args.dossier), args.dossier_hash,
                script_files=None if args.scripts is None else read_tree(args.scripts),
                script_hash=args.scripts_hash,
                properties_files=None if args.properties is None else read_tree(args.properties),
                properties_hash=args.properties_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, inputs)
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
        print(dumps({'manifestHash': result.manifest_hash, 'report': result.report}).decode('utf-8'))
    except MuseumError as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
