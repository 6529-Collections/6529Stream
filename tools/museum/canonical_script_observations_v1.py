"""Collection-script observations after concrete dossier and script replay.

This is an internal join, not an admission API. The enclosing wrapper must
verify both complete children first. The script's original transcript remains
unchanged; an explicitly indexed projection supplies only compatible outcomes
to the frozen observation comparator.
"""
from . import canonical_dossier_observations_v4 as observations
from . import collection_script_source_v1 as source
from . import object_dossier as package
from . import script_dependency_rpc_v1 as rpc
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CANONICAL_SCRIPT_OBSERVATIONS_V1'
COMMON = observations.COMMON
SCRIPT_NAME = 'script/collection'
MAX_SOURCE_ROWS = min(observations.MAX_ROWS, rpc.MAX_CALLS)
MAX_BYTES = observations.MAX_BYTES
CLAIMS = {'concreteChildVerificationRequired': True,
    'originalUnavailableOccurrencesRetained': True,
    'positiveObservationProjectionExplicit': True,
    'sameAnchorPositiveContradictionsRejected': True,
    'runtimePinsDerivedFromObservedCode': True,
    'tokenIdAddedToScriptSource': False, 'unavailableMeansAbsence': False,
    'completeConfigurationEstablished': False,
    'sourceOriginAuthenticated': False, 'consensusVerified': False,
    'currentAuthorityEstablished': False, 'finalityEstablished': False,
    'uriRetrieved': False, 'wholeHistoryEstablished': False}
QUALIFICATION = (
    'Internal reconciliation of already verified canonical V4 and collection-script children. '
    'Unavailable eth_call occurrences remain exact, ordered original observations and are excluded '
    'only from the explicitly indexed positive-comparison projection. Successful empty bytes remain '
    'successful bytes. Original log-limit observations retain their existing meaning. The script '
    'source declares collection scope, not a token relationship. Only its observed current Metadata '
    'and Store configuration is compared; SchemaRegistry and ArtistRegistry configuration is '
    'undeclared. Runtime pins come from actual eth_getCode bytes, not expected immutable Registry '
    'commitments that may differ. A joined result means agreement of declared observations, not '
    'complete configuration, authority, finality, source-origin, consensus, URI delivery or history '
    'proof. Different states and provenance classes remain separately retained; contradictory '
    'positive observations at the same chain and block still reject. Host deployment artifacts '
    'remain separate. The enclosing wrapper retains all original child bytes and verifies them.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1',
    'observationProfileHash': observations.PROFILE_HASH,
    'scriptSourceProfileHash': source.PROFILE_HASH,
    'scriptTransportProfileHash': rpc.PROFILE_HASH,
    'commonStateFields': COMMON,
    'scriptConfigurationFields': ['metadata', 'store'],
    'undeclaredScriptConfigurationFields': ['schemas', 'artistRegistry'],
    'projection': 'Original indices partition the transcript into unchanged compatible rows '
        'and exact unavailable eth_call occurrences. The projected transcript keeps its original '
        'profile tag but is comparison-only, never an independently replayable source. '
        'The original transcript reference is relative to the enclosing package at scripts/source/transcript.json.',
    'limits': {'sourceRows': MAX_SOURCE_ROWS, 'sourceCount': observations.MAX_SOURCES,
        'bytes': MAX_BYTES, 'scriptTranscriptBytes': rpc.MAX_TRANSCRIPT},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _json(files, path, maximum=MAX_BYTES):
    return loads(files[path], maximum=maximum, canonical=True)


def _dossier(files):
    base = observations._sub(files, 'canonical/')
    reference = _json(base, 'report.json')['sourceState']
    require(_json(files, 'report.json')['sourceState'] == reference,
        'script join dossier original state differs')
    families = {}
    for family in ('production', 'general', 'transfer'):
        if family + '/manifest.json' in files:
            families[family + '_files'] = observations._sub(files, family + '/')
    return reference, observations.sources(base, **families)


def _script(files):
    anchor_raw = files['source/anchor.json']
    transcript_raw = files['source/transcript.json']
    anchor = _json(files, 'source/anchor.json', source.MAX_ANCHOR)
    snapshot = _json(files, 'source/snapshot.json', source.MAX_SNAPSHOT)
    transcript = _json(files, 'source/transcript.json', rpc.MAX_TRANSCRIPT)
    require(type(anchor) is dict and set(anchor) == set(source.COMMON) |
        {'profile', 'coreRuntimeHash', 'codePins', 'runtimeAdmission'} and
        anchor['profile'] == source.PROFILE, 'script join original anchor shape')
    require(snapshot['profile'] == source.PROFILE and snapshot['profileHash'] == source.PROFILE_HASH
        and snapshot['anchorHash'] == keccak256(anchor_raw)
        and snapshot['transcriptHash'] == keccak256(transcript_raw)
        and snapshot['sourceState'] == {key: anchor[key] for key in source.COMMON},
        'script join original snapshot correspondence')
    require(snapshot['provenance'] in ('synthetic_fixture', 'trusted_rpc'),
        'script join original provenance')
    require(type(transcript) is dict and set(transcript) == {'version', 'profile', 'calls'}
        and type(transcript['version']) is int and transcript['version'] == rpc.VERSION
        and transcript['profile'] == rpc.PROFILE and type(transcript['calls']) is list
        and len(transcript['calls']) <= MAX_SOURCE_ROWS, 'script join transcript shape/bound')
    positive, indices, unavailable, answers, pins = [], [], [], {}, {}
    block = {'blockHash': anchor['blockHash'], 'requireCanonical': True}
    for index, row in enumerate(transcript['calls']):
        rpc._row(row)
        key, outcome = dumps([row['method'], row['params']]), rpc._outcome(row)
        require(key not in answers or answers[key] == outcome,
            'script join repeated original outcome differs')
        answers[key] = outcome
        if row['method'] in ('eth_call', 'eth_getCode'):
            require(row['params'][1] == block, 'script join observation block differs')
        if 'unavailable' in row:
            unavailable.append({'transcriptIndex': index, 'row': row})
            continue
        indices.append(index)
        positive.append(row)
        if row['method'] == 'eth_getCode':
            address, raw = row['params'][0], hex_bytes(row['result'])
            require(len(raw) <= source.MAX_RUNTIME, 'script join runtime byte bound')
            digest = keccak256(raw)
            require(address not in pins or pins[address] == digest,
                'script join contradictory observed runtime')
            pins[address] = digest
    graph = snapshot['graph']
    require(type(graph) is dict and set(graph) == {'core', 'metadata', 'router', 'store'},
        'script join observed graph shape')
    for pair in graph.values():
        require(type(pair) is dict and set(pair) == {'address', 'runtimeHash'} and
            pins.get(pair['address']) == pair['runtimeHash'], 'script join graph runtime differs')
    require(graph['core']['address'] == anchor['core'], 'script join graph Core differs')
    for row in snapshot['runtimeObservations']:
        require(pins.get(row['address']) == row['observedRuntimeHash'],
            'script join runtime observation differs')
    configuration = {key: graph[key]['address'] for key in ('metadata', 'store')}
    projection = {'version': transcript['version'], 'profile': transcript['profile'], 'calls': positive}
    original = {'kind': 'rpc', 'name': SCRIPT_NAME, 'anchor': anchor,
        'transcript': projection, 'runtimePins': pins, 'provenance': snapshot['provenance'],
        'configuration': configuration}
    path = 'scripts/source/transcript.json'
    description = {'sourcePath': path, 'sourceReference': package._ref(path, transcript_raw),
        'sourceHash': keccak256(transcript_raw),
        'originalCount': len(transcript['calls']), 'projectedCount': len(positive),
        'projectedOriginalIndices': indices,
        'unavailableOriginalIndices': [row['transcriptIndex'] for row in unavailable],
        'projectedTranscriptHash': keccak256(dumps(projection))}
    return original, snapshot['sourceState'], description, unavailable


def reconcile(dossier_files, script_files):
    """Join verified child filemaps; concrete admission belongs to the wrapper."""
    try:
        dossier_files, script_files = dict(dossier_files), dict(script_files)
        package._bounded(dossier_files)
        package._bounded(script_files)
        require(sum(map(len, dossier_files.values())) + sum(map(len, script_files.values())) <= MAX_BYTES,
            'script join aggregate input byte bound')
        reference, rows = _dossier(dossier_files)
        original, script_state, projection, unavailable = _script(script_files)
        original_rows = projection['originalCount'] + sum(len(row['transcript']['calls'])
            if row['kind'] == 'rpc' else len(row['calls']) + len(row['events']) for row in rows)
        require(original_rows <= MAX_SOURCE_ROWS and len(rows) + 1 <= observations.MAX_SOURCES,
            'script join original source row/count bound')
        result = observations.reconcile(reference, rows + [original])
        ledger = next(row for row in result['sources'] if row['name'] == SCRIPT_NAME)
        return {'profileHash': PROFILE_HASH, 'sourceState': reference,
            'scriptSource': {'name': SCRIPT_NAME,
                'scope': {'kind': 'collection', 'chainId': script_state['chainId'],
                    'core': script_state['core'], 'collectionId': script_state['collectionId']},
                'status': ledger['status'], 'reasons': ledger['reasons'],
                'originalAnchor': original['anchor'], 'originalSourceState': script_state,
                'configuration': original['configuration'],
                'undeclaredConfiguration': [key for key in observations.CONFIGURATION
                    if key not in original['configuration']],
                'runtimePins': original['runtimePins']},
            'unavailable': unavailable, 'transcriptProjection': projection,
            'reconciliation': {'profileHash': observations.PROFILE_HASH,
                'hash': keccak256(dumps(result)), 'report': result},
            'claims': dict(CLAIMS), 'qualification': QUALIFICATION}
    except (KeyError, TypeError, ValueError, OverflowError, RecursionError) as exc:
        if isinstance(exc, MuseumError):
            raise
        raise MuseumError('invalid verified script/dossier observation shape') from exc
