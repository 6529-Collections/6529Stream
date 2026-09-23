"""Reassess five native-state dossier requirements from replayed originals.

The original V4/V3 assessment and nineteen packet groups remain byte-for-byte
retained. This assessment is a separate, source-qualified view of five codes;
all other requirements keep their original unresolved status.
"""
import argparse
from pathlib import Path

from . import canonical_dossier_observations_v4 as observations
from . import canonical_object_dossier_v4 as dossier
from . import canonical_object_dossier_v5 as joined_dossier
from . import object_dossier as package
from . import object_dossier_inventory as inventory
from . import public_attribution_capture as attribution
from . import public_mint_entropy_capture as entropy
from . import public_scoped_policy_finality_capture_v2 as finality
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CURRENT_REQUIREMENT_ASSESSMENT_V1'
MODE = 'canonical_current_assessment_v1'
PREFIX = {'v4': 'v4/', 'finality': 'finality/', 'entropy': 'entropy/'}
ASSESSMENT_PATH = 'assessment/current-requirements.json'
COMPARISON_PATH = 'assessment/original-comparison.json'
CODES = ('identity', 'OD-FINALITY-STATUS', 'OD-CONTENT-ROOT-PROOF',
    'OD-ENTROPY-PROVENANCE', 'OD-ATTRIBUTION')
STATE_KEYS = ('chainId', 'core', 'collectionId', 'tokenId', 'blockHash',
    'blockNumber', 'timestamp', 'stateRoot', 'environment')
CLAIMS = {'originalV4BytesRetained': True, 'originalNineteenFortyNineDenominatorRetained': True,
    'separateCurrentFortyNineRowAssessment': True, 'concreteSourcesReplayed': True,
    'onlyFiveNativeStateCodesEligible': True, 'providerCompletenessAssumed': True,
    'sourceOriginAuthenticated': False, 'chainConsensusProven': False,
    'globalHistoryComplete': False, 'crossFamilyAuthoritySubstituted': False,
    'physicalFactsProven': False, 'institutionalAcceptance': False,
    'completeCanonicalDossier': False, 'networkFetch': False}
QUALIFICATION = ('A separate, bounded assessment of five native-state codes from a verified V4 '
    'dossier and optional exact-state finality and entropy captures. Every native capture is replayed '
    'from its original RPC transcript. Its conclusions hold within the declared source provenance '
    'and provider-completeness assumptions, not chain consensus or independently authenticated '
    'origin. Original V3/V4 requirement and packet decisions remain unchanged. Collection attribution '
    'applies to this token only through the retained exact Core collection identity. Unknown work class '
    'and all other unresolved codes remain unresolved. Physical and institutional acceptance, profile '
    'registration, full packet coverage and complete dossier conformance are not claimed.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1', 'mode': MODE,
    'v4ProfileHash': dossier.PROFILE_HASH, 'requirementInventoryHash': inventory.REQUIREMENTS_HASH,
    'finalityCaptureProfileHash': finality.PROFILE_HASH,
    'entropyCaptureProfileHash': entropy.PROFILE_HASH,
    'attributionCaptureProfileHash': attribution.PROFILE_HASH,
    'eligibleCodes': CODES, 'sourceStateKeys': STATE_KEYS, 'prefixes': PREFIX,
    'workClass': 'unknown until an original native work-class proof is joined',
    'verification': 'Replay V4 and every supplied capture, compare exact target/state and positive '
        'observations, derive typed EvidenceRefs and rebuild all current bytes.',
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _json(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _sub(files, prefix):
    return {path.removeprefix(prefix): raw for path, raw in files.items() if path.startswith(prefix)}


def _ref(path, raw, selector):
    return inventory.EvidenceRef(path, keccak256(raw), selector)


def _same_state(expected, actual, keys=STATE_KEYS):
    require(type(actual) is dict and all(actual.get(key) == expected[key] for key in keys),
        'current assessment exact native source state differs')


def _native_context(base_files, base_report):
    source = base_report['sourceState']
    packet_path = 'canonical/input/acquisition/packet/acquisition-packet-v10.json'
    packet = _json(base_files, packet_path)
    _same_state(source, packet['sourceState'], ('chainId', 'core', 'collectionId',
        'tokenId', 'blockHash', 'blockNumber'))
    capture_prefix = 'canonical/input/acquisition/prior/captures/attribution/'
    captured = _sub(base_files, capture_prefix)
    require(captured and 'manifest.json' in captured,
        'current assessment original attribution capture missing')
    checked = attribution.verify(captured, keccak256(captured['manifest.json']))
    attr_files = dict(checked.files)
    _same_state(source, _json(attr_files, 'source/anchor.json'),
        tuple(key for key in STATE_KEYS if key != 'tokenId'))
    _same_state(source, _json(attr_files, 'source/snapshot.json')['sourceState'],
        tuple(key for key in STATE_KEYS if key != 'tokenId'))
    current, history = checked.report['current'], checked.report['history']
    require(packet['attribution']['state'].upper() == current['stateLabel']
        and packet['attribution']['artistId'] == current['binding'][0]
        and packet['attribution']['bindingGeneration'] == current['attribution'][1],
        'current assessment original attribution/packet differs')
    return source, packet, packet_path, capture_prefix, attr_files, checked


def _finality_refs(files, source, packet):
    fragment = _json(files, 'scoped-policy-finality/fragment.json')
    proof = _json(files, 'scoped-policy-finality/token-proof.json')
    _same_state(source, fragment['sourceState'])
    _same_state(source, _json(files, 'source/anchor.json'))
    require(fragment['identity']['tokenId'] == source['tokenId']
        and proof['leaf'][0] == source['tokenId']
        and proof['subjectId'] == packet['sourceState']['subjectId'],
        'current assessment finality token/subject proof differs')
    record = fragment['bundle']['finality']['record']
    # A native negative read remains retained but does not prove the positive
    # content-root membership required by this first assessment batch.
    if record[0] is not True or fragment['reconstruction']['status'] != 'reconstructed':
        return {}
    require(any(hex_bytes(proof['root'], 32)) and any(hex_bytes(proof['leafHash'], 32))
        and uint(proof['leafCount']) > 0,
        'current assessment finality proof incomplete')
    return {'OD-FINALITY-STATUS': (_ref('finality/scoped-policy-finality/fragment.json',
                files['scoped-policy-finality/fragment.json'], '/bundle/finality/record'),),
        'OD-CONTENT-ROOT-PROOF': (_ref('finality/scoped-policy-finality/token-proof.json',
                files['scoped-policy-finality/token-proof.json'], '$'),)}


def _entropy_refs(files, source):
    anchor = _json(files, 'source/anchor.json')
    _same_state(source, anchor)
    snapshot = _json(files, 'source/snapshot.json')
    identity = snapshot['identity']
    require(identity['tokenId'] == source['tokenId']
        and identity['collectionId'] == source['collectionId'],
        'current assessment entropy token differs')
    leaf = snapshot['entropy']['leaf']
    require(leaf['tokenId'] == source['tokenId']
        and leaf['status'] == snapshot['observedStatus'],
        'current assessment entropy leaf/status differs')
    if snapshot['terminalEligible'] is not True:
        return {}
    require(any(hex_bytes(leaf['provider'], 20))
        and any(hex_bytes(leaf['requestKey'], 32))
        and any(hex_bytes(snapshot['entropy']['leafHash'], 32))
        and snapshot['entropy']['events'],
        'current assessment entropy complete native proof missing')
    return {'OD-ENTROPY-PROVENANCE': (
        _ref('entropy/source/snapshot.json', files['source/snapshot.json'], '/entropy'),
        _ref('entropy/entropy/leaf-preimage.bin', files['entropy/leaf-preimage.bin'], '$'))}


def _compose(v4_files, v4_hash, finality_files, finality_hash, entropy_files, entropy_hash, disclosure):
    require(disclosure == 'public', 'current assessment public disclosure required before reads')
    for name, files, digest in (('finality', finality_files, finality_hash),
                                ('entropy', entropy_files, entropy_hash)):
        require((files is None) == (digest is None),
            'current assessment ' + name + ' files and pin required together')
    checked = dossier.verify(dict(v4_files), v4_hash)
    base = dict(checked.files)
    final = None if finality_files is None else finality.verify(dict(finality_files), finality_hash)
    ent = None if entropy_files is None else entropy.verify(dict(entropy_files), entropy_hash)
    final_files = None if final is None else dict(final.files)
    ent_files = None if ent is None else dict(ent.files)
    source, packet, packet_path, attr_prefix, attr_files, attr = _native_context(base, checked.report)
    originals = _json(base, 'canonical/input/dossier/requirements.json')
    require(originals['counts']['total'] == 49 and len(originals['results']) == 49
        and [row['code'] for row in originals['results']] ==
            [row['code'] for row in inventory.REQUIREMENTS],
        'current assessment original forty-nine requirement identity differs')
    packet_report = _json(base, 'canonical/input/report.json')
    require(len(packet_report['packetRequirements']) == 19,
        'current assessment original nineteen packet groups differ')
    # V4 has already replayed every retained family. Compare newly attached
    # sources with its entire source inventory, including production and the
    # General/transfer alias, not only the canonical child.
    observed = joined_dossier._v4_sources(base)
    config = observed[0]['configuration']
    for name, child in (('current-finality', final_files), ('current-entropy', ent_files)):
        if child is not None:
            observed.append(observations._rpc(child, name, 'source/anchor.json',
                'source/transcript.json', _json(child, 'manifest.json')['provenance'], config))
    reconciliation = observations.reconcile(source, observed)
    verified = {'identity': (_ref('v4/' + packet_path, base[packet_path], '/sourceState'),)}
    if attr.report['history']['completeLocalBaseline'] is True:
        verified['OD-ATTRIBUTION'] = (_ref('v4/' + attr_prefix + 'attribution/current.json',
            attr_files['attribution/current.json'], '$'),
            _ref('v4/' + attr_prefix + 'attribution/history.json',
                attr_files['attribution/history.json'], '/completeLocalBaseline'))
    if final_files is not None: verified.update(_finality_refs(final_files, source, packet))
    if ent_files is not None: verified.update(_entropy_refs(ent_files, source))
    require(set(verified) <= set(CODES), 'current assessment verified code scope differs')
    supplied = {row['code']: tuple(row['suppliedHashes']) for row in originals['results']
        if row['suppliedHashes'] and row['code'] not in verified}
    current = inventory.assess('unknown', verified, supplied)
    comparison = {'originalAssessment': package._ref(
        'v4/canonical/input/dossier/requirements.json',
        base['canonical/input/dossier/requirements.json']),
        'originalPacketReport': package._ref('v4/canonical/input/report.json',
            base['canonical/input/report.json']),
        'originalPacketGroupCount': '19', 'originalRequirementCount': '49',
        'currentRequirementCount': '49', 'workClass': 'unknown',
        'currentVerifiedCodes': [code for code in CODES if code in verified],
        'rows': [{'code': old['code'], 'originalState': old['state'],
            'currentState': new['state']} for old, new in zip(originals['results'], current['results'])],
        'sourceReconciliation': reconciliation, 'claims': CLAIMS, 'qualification': QUALIFICATION}
    output = {PREFIX['v4'] + path: raw for path, raw in base.items()}
    for name, child in (('finality', final_files), ('entropy', ent_files)):
        if child is not None:
            output.update({PREFIX[name] + path: raw for path, raw in child.items()})
    output[ASSESSMENT_PATH] = dumps(current)
    output[COMPARISON_PATH] = dumps(comparison)
    output['definitions/profile.json'] = PROFILE_BYTES
    report = {'profile': NAME, 'profileHash': PROFILE_HASH,
        'v4ManifestHash': v4_hash, 'finalityManifestHash': finality_hash,
        'entropyManifestHash': entropy_hash, 'sourceState': source,
        'sourceProvenance': {'v4': _json(base, 'canonical/input/acquisition/report.json')['sourceProvenance'],
            'finality': None if final is None else final.report['provenance'],
            'entropy': None if ent is None else ent.report['provenance']},
        'originalPacketGroupCount': '19', 'originalRequirementCount': '49',
        'originalRequirementCounts': originals['counts'], 'currentRequirementCounts': current['counts'],
        'currentVerifiedCodes': comparison['currentVerifiedCodes'],
        'originalAssessmentChanged': False, 'complete': current['complete'],
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    output['report.json'] = dumps(report)
    package._bounded(output)
    manifest = dumps({'mode': MODE, 'profile': NAME, 'profileHash': PROFILE_HASH,
        'version': '1', 'inputs': {'v4': v4_hash, 'finality': finality_hash,
            'entropy': entropy_hash}, 'disclosure': disclosure,
        'assessment': package._ref(ASSESSMENT_PATH, output[ASSESSMENT_PATH]),
        'files': [package._ref(path, raw) for path, raw in sorted(output.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'current assessment manifest byte bound')
    output['manifest.json'] = manifest
    package._bounded(output)
    return package.Assembly(tuple(sorted(output.items())), manifest, report)


def compose(v4_files, v4_hash, *, finality_files=None, finality_hash=None,
            entropy_files=None, entropy_hash=None, disclosure):
    try:
        return _compose(v4_files, v4_hash, finality_files, finality_hash,
            entropy_files, entropy_hash, disclosure)
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed current assessment inputs') from exc


def verify(files, expected_hash):
    try:
        files = dict(files); package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'current assessment external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'mode', 'profile', 'profileHash',
            'version', 'inputs', 'disclosure', 'assessment', 'files', 'claims', 'qualification'}
            and manifest['mode'] == MODE and manifest['profile'] == NAME
            and manifest['profileHash'] == PROFILE_HASH and manifest['version'] == '1'
            and manifest['claims'] == CLAIMS and manifest['qualification'] == QUALIFICATION,
            'current assessment closed manifest differs')
        require(manifest['files'] == [package._ref(path, body) for path, body in sorted(files.items())
            if path != 'manifest.json'], 'current assessment file commitments differ')
        inputs = manifest['inputs']
        require(type(inputs) is dict and set(inputs) == {'v4', 'finality', 'entropy'},
            'current assessment input pins differ')
        children = {name: _sub(files, prefix) for name, prefix in PREFIX.items()}
        require(bool(children['finality']) == (inputs['finality'] is not None)
            and bool(children['entropy']) == (inputs['entropy'] is not None),
            'current assessment child presence differs')
        rebuilt = compose(children['v4'], inputs['v4'], finality_files=children['finality'] or None,
            finality_hash=inputs['finality'], entropy_files=children['entropy'] or None,
            entropy_hash=inputs['entropy'], disclosure=manifest['disclosure'])
        require(dict(rebuilt.files) == files, 'current assessment reconstruction differs')
        return rebuilt
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError, OSError) as exc:
        raise MuseumError('malformed current assessment package') from exc


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('assemble')
    create.add_argument('--v4', type=Path, required=True)
    create.add_argument('--v4-hash', required=True)
    for name in ('finality', 'entropy'):
        create.add_argument('--' + name, type=Path)
        create.add_argument('--' + name + '-hash')
    create.add_argument('--disclosure', required=True)
    create.add_argument('--output', type=Path, required=True)
    check = commands.add_parser('verify')
    check.add_argument('directory', type=Path)
    check.add_argument('--manifest-hash', required=True)
    args = parser.parse_args(argv)
    try:
        if args.command == 'assemble':
            require(args.disclosure == 'public', 'current assessment public disclosure required before reads')
            from .repository_exchange import _destination, _publish
            sources = [args.v4] + [getattr(args, name) for name in ('finality', 'entropy')
                if getattr(args, name) is not None]
            _destination(args.output, sources)
            result = compose(read_tree(args.v4), args.v4_hash,
                finality_files=None if args.finality is None else read_tree(args.finality),
                finality_hash=args.finality_hash,
                entropy_files=None if args.entropy is None else read_tree(args.entropy),
                entropy_hash=args.entropy_hash, disclosure=args.disclosure)
            _publish(dict(result.files), args.output, sources)
        else:
            result = verify(read_tree(args.directory), args.manifest_hash)
        print(dumps({'manifestHash': result.manifest_hash, 'report': result.report}).decode('utf-8'))
    except (MuseumError, OSError) as exc:
        parser.exit(1, 'current assessment: ' + str(exc) + '\n')


if __name__ == '__main__': main()
