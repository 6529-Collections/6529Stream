"""Join verified collection script observations to unchanged dossier requirements.

Both concrete children are reconstructed before their reports are consumed.
The supplemental ledger identifies supporting source occurrences; it never
rewrites an original assessment or turns byte availability into acceptance.
"""
import argparse
from pathlib import Path

from . import canonical_object_dossier_v4 as dossier
from . import collection_script_package_v1 as scripts
from . import canonical_script_observations_v1 as observations
from . import object_dossier as package
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CANONICAL_DOSSIER_SCRIPT_LINKS_V1'
MODE = 'canonical_dossier_script_links_v1'
LINKS_PATH = 'evidence/script-requirement-links.json'
OBSERVATIONS_PATH = 'evidence/source-observations.json'
ASSESSMENT = 'canonical/input/dossier/requirements.json'
PACKET_REPORT = 'canonical/input/report.json'
CODES = ('OD-SCRIPT-MANIFEST', 'OD-DEPENDENCY-MANIFEST')
CLAIMS = {'concreteChildrenReplayed': True, 'originalChildrenRetained': True,
    'originalAssessmentsUnchanged': True, 'occurrenceReferencesPreserved': True,
    'requirementPromotions': False, 'tokenAuthorityInferred': False,
    'scriptExecuted': False, 'uriResourcesRetrieved': False,
    'runtimeBridgeContentsVerified': False, 'registeredInterpretationProven': False,
    'completeSelectionHistoryProven': False, 'authoritativeRenderInventory': False,
    'sourceOriginAuthenticated': False, 'consensusVerified': False,
    'completeObjectDossier': False, 'institutionalAcceptance': False, 'networkFetch': False}
QUALIFICATION = (
    'Supporting collection-scope script/dependency observations for an unchanged canonical V4 dossier. '
    'The original nineteen packet groups and forty-nine assessment bytes remain authoritative for '
    'that original assessment. Current manifest, raw saved bundle, inline source, zero selection, '
    'verified wire-empty dependency and unavailable outcomes retain their separate original meanings. '
    'Joined observations agree on their declared source state; unjoined observations do not establish '
    'the dossier state. Source replay and available bytes do not register an interpretation, execute '
    'a script, retrieve a URI, prove complete history or render inventory, authenticate provider origin '
    'or consensus, or confer token authority or institutional acceptance.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'dossierProfileHash': dossier.PROFILE_HASH,
    'scriptProfileHash': scripts.PROFILE_HASH, 'observationProfileHash': observations.PROFILE_HASH,
    'requirementCodes': CODES,
    'retention': 'Exact verified children under dossier/ and scripts/; original source selectors '
        'and payload references in a supplemental ledger. No original assessment changes.',
    'verification': 'Replay both concrete children, reconcile positive original observations, '
        'preserve unavailable outcomes and rebuild every derived byte offline.',
    'bounds': {'packageBytes': str(MAX_BYTES), 'manifestBytes': str(MAX_MANIFEST)},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == 'public', 'script links public disclosure required before reads')


def _sub(files, prefix):
    return {path.removeprefix(prefix): raw for path, raw in files.items() if path.startswith(prefix)}


def _json(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _located(files, prefix, path, selector=''):
    return {**package._ref(prefix + path, files[path]), 'selector': selector}


def _payload(files, reference):
    if reference is None:
        return None
    path = reference['path']
    require(reference == package._ref(path, files[path]), 'script links original payload differs')
    return package._ref('scripts/' + path, files[path])


def _occurrences(files, snapshot, report, role):
    interpretations = snapshot['interpretations']
    require(len(interpretations) == len(report['payloads']), 'script links occurrence denominator')
    rows = []
    for index, (item, payloads) in enumerate(zip(interpretations, report['payloads'])):
        selector = '/interpretations/' + str(index)
        require(all(item[key] == payloads[key] for key in ('basis', 'host', 'manifestHash')),
            'script links original occurrence order differs')
        manifest_selector = selector + '/value/manifest' if role == 'script' else (
            selector + '/value/library/dependencyManifest' if item['value']['library'] is not None else None)
        rows.append({'interpretationIndex': str(index), 'basis': item['basis'],
            'host': item['host'], 'manifestHash': item['manifestHash'],
            'interpretation': _located(files, 'scripts/', 'source/snapshot.json', selector),
            'manifest': None if manifest_selector is None else
                _located(files, 'scripts/', 'source/snapshot.json', manifest_selector),
            'wireReport': _located(files, 'scripts/', 'source/snapshot.json', selector + '/report/' + role),
            'wireStatus': item['report'][role].get('status'),
            'payloadStatus': item['report'][role].get('payloadStatus'),
            'wireBytesComplete': item['report']['completeScriptBytes' if role == 'script' else 'completeDependencyBytes'],
            'payload': _payload(files, payloads[role]),
            'requirementAccepted': False})
    return rows


def _compose(dossier_files, dossier_hash, script_files, script_hash, disclosure):
    _public(disclosure)
    # Reconstruct complete children before reading any descriptive report.
    base = dossier.verify(dict(dossier_files), dossier_hash)
    child = scripts.verify(dict(script_files), script_hash)
    base_files, child_files = dict(base.files), dict(child.files)
    assessment = _json(base_files, ASSESSMENT)
    packet_report = _json(base_files, PACKET_REPORT)
    require(assessment['counts']['total'] == 49 and len(assessment['results']) == 49
        and len(packet_report['packetRequirements']) == 19,
        'script links original nineteen/forty-nine denominator differs')
    snapshot = _json(child_files, 'source/snapshot.json')
    reconciliation = observations.reconcile(base_files, child_files)
    by_code = {row['code']: (index, row) for index, row in enumerate(assessment['results'])}
    require(len(by_code) == 49 and all(code in by_code for code in CODES),
        'script links original requirement identity differs')
    links = []
    for code, role in zip(CODES, ('script', 'dependency')):
        index, original = by_code[code]
        links.append({'requirementCode': code, 'originalAssessmentState': original['state'],
            'originalAssessment': _located(base_files, 'dossier/', ASSESSMENT, '/results/' + str(index)),
            'role': 'supporting_collection_observations', 'subjectScope': 'collection',
            'tokenAuthorityInferred': False, 'requirementPromotions': [],
            'occurrences': _occurrences(child_files, snapshot, child.report, role),
            'availability': snapshot['availability'],
            'originalAvailability': _located(child_files, 'scripts/', 'source/snapshot.json', '/availability'),
            'originalObservedCalls': _located(child_files, 'scripts/', 'source/snapshot.json', '/observations'),
            'sourceReconciliation': package._ref(OBSERVATIONS_PATH, dumps(reconciliation))})
    ledger = {'profile': NAME, 'profileHash': PROFILE_HASH, 'requirementLinks': links,
        'originalAssessment': package._ref('dossier/' + ASSESSMENT, base_files[ASSESSMENT]),
        'originalPacketReport': package._ref('dossier/' + PACKET_REPORT, base_files[PACKET_REPORT]),
        'packetRequirementCount': '19', 'dossierRequirementCount': '49',
        'untouchedRequirementCodes': [row['code'] for row in assessment['results'] if row['code'] not in CODES],
        'requirementPromotions': [], 'claims': CLAIMS, 'qualification': QUALIFICATION}
    report = {'profile': NAME, 'profileHash': PROFILE_HASH, 'sourceState': base.report['sourceState'],
        'scriptSourceState': child.report['sourceState'], 'sourceReconciliation': reconciliation,
        'packetRequirementCount': '19', 'dossierRequirementCount': '49',
        'originalDossierRequirementCounts': assessment['counts'],
        'linkedRequirementCodes': list(CODES), 'requirementPromotions': [],
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    files = {'dossier/' + path: raw for path, raw in base_files.items()}
    files.update({'scripts/' + path: raw for path, raw in child_files.items()})
    files.update({LINKS_PATH: dumps(ledger), OBSERVATIONS_PATH: dumps(reconciliation),
        'definitions/profile.json': PROFILE_BYTES,
        'definitions/observation-profile.json': observations.PROFILE_BYTES, 'report.json': dumps(report)})
    package._bounded(files)
    manifest = dumps({'mode': MODE, 'profile': NAME, 'version': '1', 'profileHash': PROFILE_HASH,
        'inputs': {'dossier': dossier_hash, 'scripts': script_hash}, 'disclosure': disclosure,
        'links': package._ref(LINKS_PATH, files[LINKS_PATH]),
        'files': [package._ref(path, raw) for path, raw in sorted(files.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'script links manifest byte bound')
    files['manifest.json'] = manifest
    package._bounded(files)
    return package.Assembly(tuple(sorted(files.items())), manifest, report)


def compose(dossier_files, dossier_hash, script_files, script_hash, *, disclosure):
    try:
        return _compose(dossier_files, dossier_hash, script_files, script_hash, disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed script requirement link inputs') from exc


def verify(files, expected_hash):
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'script links external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'version',
            'profileHash', 'inputs', 'disclosure', 'links', 'files', 'claims', 'qualification'}
            and manifest['mode'] == MODE and manifest['profile'] == NAME
            and manifest['version'] == '1' and manifest['profileHash'] == PROFILE_HASH
            and manifest['claims'] == CLAIMS and manifest['qualification'] == QUALIFICATION
            and type(manifest['inputs']) is dict and set(manifest['inputs']) == {'dossier', 'scripts'},
            'script links closed manifest differs')
        _public(manifest['disclosure'])
        require(manifest['files'] == [package._ref(path, body)
            for path, body in sorted(files.items()) if path != 'manifest.json'],
            'script links file commitments differ')
        result = compose(_sub(files, 'dossier/'), manifest['inputs']['dossier'],
            _sub(files, 'scripts/'), manifest['inputs']['scripts'], disclosure=manifest['disclosure'])
        require(dict(result.files) == files, 'script links full reconstruction differs')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed script requirement link package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('assemble')
    for role in ('dossier', 'scripts'):
        create.add_argument('--' + role, type=Path, required=True)
        create.add_argument('--' + role + '-hash', required=True)
    create.add_argument('--disclosure', required=True)
    create.add_argument('--output', type=Path, required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'assemble':
            _public(args.disclosure)
            from .repository_exchange import _destination, _publish
            inputs = [args.dossier, args.scripts]
            _destination(args.output, inputs)
            result = compose(read_tree(args.dossier), args.dossier_hash,
                read_tree(args.scripts), args.scripts_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, inputs)
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
        print(dumps({'manifestHash': result.manifest_hash, 'report': result.report}).decode('utf-8'))
    except MuseumError as exc:
        parser.exit(2, str(exc) + '\n')


if __name__ == '__main__':
    main()
