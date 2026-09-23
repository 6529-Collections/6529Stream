"""One observation union for already verified canonical evidence children.

This internal adapter does not admit a source package. Its caller must replay
the complete V4, script and retained PREMIS children before invoking it.
"""
from . import canonical_dossier_observations_v4 as observations
from . import canonical_script_observations_v1 as scripts
from . import chain_rpc
from . import independent_catalog_source as catalog
from . import object_dossier as package
from . import premis_retained
from . import public_scoped_finality_rpc as rpc
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CANONICAL_EVIDENCE_OBSERVATIONS_V2'
PROPERTIES_NAME = 'properties/catalogue'
MAX_BYTES = observations.MAX_BYTES
MAX_SOURCE_ROWS = observations.MAX_ROWS
MAX_SOURCES = observations.MAX_SOURCES
MAX_RUNTIME = 24576
CLAIMS = {'concreteChildVerificationRequired': True,
    'singleCombinedObservationComparison': True,
    'originalUnavailableOccurrencesRetained': True,
    'positiveObservationProjectionExplicit': True,
    'runtimePinsDerivedFromObservedCode': True,
    'catalogueComparisonScopeDerivationExplicit': True,
    'missingStateFieldsInvented': False, 'tokenScopeAdded': False,
    'completeConfigurationEstablished': False, 'sourceOriginAuthenticated': False,
    'consensusVerified': False, 'currentAuthorityEstablished': False,
    'finalityEstablished': False, 'uriRetrieved': False,
    'wholeHistoryEstablished': False, 'requirementPromotionEstablished': False}
QUALIFICATION = (
    'Internal consistency adapter after complete concrete child verification. All original '
    'canonical V4 observations and optional script and retained PREMIS catalogue observations '
    'enter one comparison, including conflicts between optional sources. Original anchors and '
    'source states remain unchanged. A positive original catalogue scopeKey denotes collection '
    'scope and supplies only an explicitly described comparison collectionId; scope zero remains '
    'deployment-wide with collectionId undeclared. No missing environment, token or configuration '
    'is supplied from the dossier. Catalogue configuration declares SchemaRegistry and Store; '
    'its independent host is not Metadata. Script unavailability stays indexed in the original '
    'transcript and is excluded only from positive comparison, never interpreted as absence. '
    'Runtime pins derive from observed code, including original carriers. Different state or '
    'provenance remains unjoined; same-block positive contradictions still reject. Joining '
    'declared observations proves neither complete configuration, source origin, consensus, '
    'authority, finality, delivery, whole history nor requirement completion. References are '
    'relative to the outer package under dossier/, scripts/ and properties/.')
PROFILE_BYTES = dumps({'name': NAME, 'version': '2',
    'observationProfileHash': observations.PROFILE_HASH,
    'scriptObservationProfileHash': scripts.PROFILE_HASH,
    'catalogueSourceProfileHash': catalog.PROFILE_HASH,
    'retainedPropertiesProfileHash': premis_retained.PROFILE_HASH,
    'comparison': 'One union of original canonical sources and all supplied optional sources.',
    'catalogueScopeMapping': 'Only positive original source/anchor.json scopeKey maps to '
        'comparison collectionId; zero remains undeclared. Original sourceState remains exact.',
    'catalogueConfiguration': ['schemas', 'store'],
    'sourceReferenceBase': 'outer package: dossier/, scripts/, properties/',
    'limits': {'bytes': MAX_BYTES, 'originalRows': MAX_SOURCE_ROWS,
        'sources': MAX_SOURCES, 'catalogueTranscriptBytes': chain_rpc.MAX_TRANSCRIPT,
        'runtimeBytes': MAX_RUNTIME},
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _json(files, path, maximum=MAX_BYTES):
    return loads(files[path], maximum=maximum, canonical=True)


def _refs(files, prefix):
    return {kind: package._ref(prefix + '/source/' + kind + '.json',
        files['source/' + kind + '.json']) for kind in ('anchor', 'transcript', 'snapshot')}


def _properties(files):
    anchor_raw, transcript_raw = files['source/anchor.json'], files['source/transcript.json']
    anchor, expected_pins, scope = catalog._anchor(anchor_raw)
    snapshot = _json(files, 'source/snapshot.json')
    transcript = _json(files, 'source/transcript.json', chain_rpc.MAX_TRANSCRIPT)
    state = {key: anchor[key] for key in ('chainId', 'core', 'scopeKey', 'blockHash', 'blockNumber')}
    require(snapshot['profile'] == catalog.PROFILE and snapshot['profileHash'] == catalog.PROFILE_HASH
        and snapshot['anchorHash'] == keccak256(anchor_raw)
        and snapshot['transcriptHash'] == keccak256(transcript_raw)
        and snapshot['sourceState'] == state and snapshot['scopeKey'] == str(scope)
        and snapshot['environment'] == anchor['environment'],
        'evidence join catalogue snapshot correspondence')
    provenance = snapshot['evidence']
    require(provenance in ('synthetic_fixture', 'trusted_rpc') and snapshot['mode'] ==
        ('recorded_state' if provenance == 'trusted_rpc' else 'synthetic_fixture'),
        'evidence join catalogue provenance')
    require(type(transcript) is dict and set(transcript) == {'version', 'calls'}
        and type(transcript['version']) is int and transcript['version'] == 1
        and type(transcript['calls']) is list and len(transcript['calls']) <= MAX_SOURCE_ROWS,
        'evidence join catalogue transcript shape/bound')
    pins, answers = {}, {}
    block = {'blockHash': anchor['blockHash'], 'requireCanonical': True}
    for row in transcript['calls']:
        require(type(row) is dict and set(row) == {'method', 'params', 'result'}
            and row['method'] in chain_rpc.METHODS, 'evidence join catalogue original row shape')
        rpc._row(row)
        key, result = dumps([row['method'], row['params']]), dumps(row['result'])
        require(key not in answers or answers[key] == result,
            'evidence join repeated catalogue outcome differs')
        answers[key] = result
        if row['method'] in ('eth_call', 'eth_getCode'):
            require(row['params'][1] == block, 'evidence join catalogue observation block differs')
        if row['method'] == 'eth_getCode':
            address, raw = row['params'][0], hex_bytes(row['result'])
            require(0 < len(raw) <= MAX_RUNTIME, 'evidence join catalogue runtime byte bound')
            digest = keccak256(raw)
            require(address not in pins or pins[address] == digest,
                'evidence join contradictory catalogue runtime')
            pins[address] = digest
    require(all(pins.get(address) == digest for address, digest in expected_pins.items()),
        'evidence join catalogue declared runtime differs')
    comparison, derivations = dict(anchor), []
    if scope:
        comparison['collectionId'] = str(scope)
        derivations.append({'field': 'collectionId', 'value': str(scope),
            'source': dict(package._ref('properties/source/anchor.json', anchor_raw), pointer='/scopeKey'),
            'rule': 'positive_original_catalogue_scopeKey_is_collection_scope'})
    row = {'kind': 'rpc', 'name': PROPERTIES_NAME, 'anchor': comparison,
        'transcript': transcript, 'runtimePins': pins, 'provenance': provenance,
        'configuration': {key: anchor[key] for key in ('schemas', 'store')}}
    return row, anchor, state, derivations


def _descriptor(family, original, anchor, state, derivations, files, ledger):
    scope = {'kind': 'collection', 'chainId': anchor['chainId'], 'core': anchor['core']}
    if family == 'scripts':
        scope['collectionId'] = anchor['collectionId']
    else:
        scope['scopeKey'] = anchor['scopeKey']
        if anchor['scopeKey'] == '0': scope['kind'] = 'deployment_wide'
        else: scope['collectionId'] = anchor['scopeKey']
    return {'family': family, 'name': original['name'], 'status': ledger['status'],
        'reasons': ledger['reasons'], 'scope': scope, 'provenance': original['provenance'],
        'originalAnchor': anchor, 'originalSourceState': state,
        'comparisonAnchor': original['anchor'], 'comparisonDerivations': derivations,
        'configuration': original['configuration'],
        'undeclaredConfiguration': [key for key in observations.CONFIGURATION
            if key not in original['configuration']],
        'runtimePins': original['runtimePins'], 'sourceReferences': _refs(files, family)}


def reconcile(dossier_files, script_files=None, properties_files=None):
    """Compare already verified children without repeating or replacing their admission."""
    try:
        groups = {'dossier': dict(dossier_files),
            'scripts': None if script_files is None else dict(script_files),
            'properties': None if properties_files is None else dict(properties_files)}
        total = 0
        for files in groups.values():
            if files is not None:
                package._bounded(files)
                total += sum(map(len, files.values()))
        require(total <= MAX_BYTES, 'evidence join aggregate input byte bound')
        reference, rows = scripts._dossier(groups['dossier'])
        count = sum(len(row['transcript']['calls']) if row['kind'] == 'rpc'
            else len(row['calls']) + len(row['events']) for row in rows)
        optional, projection, unavailable = {}, None, []
        if groups['scripts'] is not None:
            row, state, projection, unavailable = scripts._script(groups['scripts'])
            optional['scripts'] = (row, row['anchor'], state, [])
            count += projection['originalCount']
            rows.append(row)
        if groups['properties'] is not None:
            values = _properties(groups['properties'])
            optional['properties'] = values
            count += len(values[0]['transcript']['calls'])
            rows.append(values[0])
        require(count <= MAX_SOURCE_ROWS and len(rows) <= MAX_SOURCES,
            'evidence join original source row/count bound')
        result = observations.reconcile(reference, rows)
        ledger = {row['name']: row for row in result['sources']}
        descriptors = []
        for family, name in (('scripts', scripts.SCRIPT_NAME), ('properties', PROPERTIES_NAME)):
            if family not in optional:
                descriptors.append({'family': family, 'name': name, 'status': 'absent',
                    'reasons': ['optional_source_not_supplied']})
            else:
                values = optional[family]
                descriptors.append(_descriptor(family, *values, groups[family], ledger[name]))
        return {'profileHash': PROFILE_HASH, 'sourceState': reference, 'sources': descriptors,
            'originalObservationCount': count, 'scriptProjection': projection,
            'scriptUnavailable': unavailable,
            'reconciliation': {'profileHash': observations.PROFILE_HASH,
                'hash': keccak256(dumps(result)), 'report': result},
            'claims': dict(CLAIMS), 'qualification': QUALIFICATION}
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('invalid verified canonical evidence observation shape') from exc
