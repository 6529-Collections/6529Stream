"""Join exact token script bytes to the selected registered interpretation."""
from . import token_script_capture_v1 as token_capture
from . import token_script_interpretation_v1 as interpretation
from . import token_script_registry_source_v1 as registry
from . import collection_script_wire_v1 as wire
from .bagit import MAX_BYTES, MAX_MANIFEST
from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import require
from .object_dossier import Assembly, _bounded, _ref
from .public_history_rpc import MAX_TRANSCRIPT, PublicReplayTransport

PROFILE = 'STREAM_MUSEUM_TOKEN_SCRIPT_REGISTERED_CAPTURE_V1'
CLAIMS = {'tokenSourceReplayed': True, 'registeredInterpretationReplayed': True,
    'sameStateAndSelectedMetadataJoined': True,
    'positiveScriptRequirementEligibleOnlyWhenMatched': True,
    'negativeWorkClassProven': False, 'completeSelectionHistoryProven': False,
    'historicalWriterGrantProven': False, 'sourceOriginAuthenticated': False,
    'consensusVerified': False, 'institutionalAcceptance': False}
QUALIFICATION = ('Only a complete positively selected token script, exact native '
    'override/frozen-source history and all four current ACTIVE SchemaRegistry '
    'interpretation documents at the same block earn a script-manifest reference. '
    'The preserved bytes do not prove renderer execution, a non-script class, '
    'global selection history, source origin, consensus or institutional acceptance.')
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1',
    'tokenCaptureProfileHash': token_capture.PROFILE_HASH,
    'registrySourceProfileHash': registry.PROFILE_HASH,
    'interpretationProfileHash': interpretation.PROFILE_HASH,
    'eligibleCodes': ['OD-SCRIPT-MANIFEST'],
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _sub(files, prefix):
    return {path.removeprefix(prefix): raw for path, raw in files.items()
        if path.startswith(prefix)}


def _compose(token_files, token_hash, registry_anchor, registry_anchor_hash,
        registry_transcript, registry_transcript_hash, disclosure):
    require(disclosure == 'public', 'registered token script public disclosure required before reads')
    require(type(registry_anchor) is bytes and 0 < len(registry_anchor) <= registry.genesis.MAX_ANCHOR
        and keccak256(registry_anchor) == registry_anchor_hash,
        'registered token script Registry anchor commitment differs')
    require(type(registry_transcript) is bytes and
        0 < len(registry_transcript) <= MAX_TRANSCRIPT and
        keccak256(registry_transcript) == registry_transcript_hash,
        'registered token script Registry transcript commitment differs')
    token = token_capture.verify(dict(token_files), token_hash)
    registry_anchor_value = loads(registry_anchor,
        maximum=registry.genesis.MAX_ANCHOR, canonical=True)
    provenance = ('trusted_rpc' if registry_anchor_value['runtimeAdmission']['kind'] ==
        'externally_admitted_runtime' else 'synthetic_fixture')
    transport = PublicReplayTransport(registry_transcript, registry_transcript_hash)
    source = registry.TokenScriptRegistrySource(registry_anchor, transport,
        provenance=provenance)
    registry_snapshot = source.snapshot(); transport.finish()
    require(source.transcript() == registry_transcript,
        'registered token script Registry original transcript differs')
    token_files = dict(token.files)
    token_snapshot = loads(token_files['source/snapshot.json'], maximum=MAX_BYTES,
        canonical=True)
    registry_value = loads(registry_snapshot, maximum=registry.genesis.MAX_OUTPUT,
        canonical=True)
    token_state, registry_state = token_snapshot['sourceState'], registry_value['sourceState']
    require(all(token_state[key] == value for key, value in registry_state.items()),
        'registered token script exact source state differs')
    require(token_snapshot['graph']['metadata']['address'] ==
        registry_value['graph']['metadataHost'] and
        token_snapshot['graph']['metadata']['runtimeHash'] ==
        next(row['runtimeHash'] for row in registry_value['graph']['runtimePins']
            if row['address'] == registry_value['graph']['metadataHost']),
        'registered token script selected Metadata differs')
    eligible = token_snapshot['positiveScriptClassification'] is True
    if eligible:
        selected = token_snapshot['interpretation']
        require(selected is not None and selected['report']['completeScriptBytes'] is True
            and selected['report']['manifest']['rendererCompatibility'] in
                (wire.STABLE_PROFILE, wire.CHUNKED_PROFILE)
            and selected['report']['manifestHash'] ==
                token_snapshot['manifestSelection']['manifestHash'],
            'registered token script selected manifest differs')
        require('payloads/script.bin' in token_files,
            'registered token script complete payload absent')
    report = {'profile': PROFILE, 'profileHash': PROFILE_HASH,
        'sourceState': token_state, 'workClass': token_snapshot['workClass'],
        'currentVerifiedCodes': ['OD-SCRIPT-MANIFEST'] if eligible else [],
        'scriptRequirement': None if not eligible else
            _ref('token/source/snapshot.json', token_files['source/snapshot.json']),
        'registeredInterpretation': _ref('registry/source/snapshot.json', registry_snapshot),
        'claims': CLAIMS, 'qualification': QUALIFICATION}
    files = {'token/' + path: raw for path, raw in token_files.items()}
    files.update({'registry/source/anchor.json': registry_anchor,
        'registry/source/transcript.json': registry_transcript,
        'registry/source/snapshot.json': registry_snapshot,
        'definitions/registered-capture-profile.json': PROFILE_BYTES,
        'definitions/registry-source-profile.json': registry.PROFILE_BYTES,
        'definitions/interpretation-profile.json': interpretation.PROFILE_BYTES,
        'report.json': dumps(report)})
    _bounded(files)
    manifest = dumps({'profile': PROFILE, 'profileHash': PROFILE_HASH,
        'inputs': {'tokenHash': token_hash, 'registryAnchorHash': registry_anchor_hash,
            'registryTranscriptHash': registry_transcript_hash,
            'disclosure': disclosure},
        'files': [_ref(path, raw) for path, raw in sorted(files.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'registered token script manifest byte bound')
    files['manifest.json'] = manifest
    _bounded(files)
    return Assembly(tuple(sorted(files.items())), manifest, report)


def compose(token_files, token_hash, registry_anchor, registry_anchor_hash,
        registry_transcript, registry_transcript_hash, *, disclosure):
    try:
        return _compose(token_files, token_hash, registry_anchor, registry_anchor_hash,
            registry_transcript, registry_transcript_hash, disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError,
            StopIteration) as exc:
        raise MuseumError('malformed registered token script inputs') from exc


def verify(files, expected_hash):
    try:
        files = dict(files); _bounded(files)
        require(keccak256(files['manifest.json']) == expected_hash,
            'registered token script external manifest differs')
        manifest = loads(files['manifest.json'], maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) ==
            {'profile', 'profileHash', 'inputs', 'files', 'claims', 'qualification'}
            and manifest['profile'] == PROFILE and manifest['profileHash'] == PROFILE_HASH
            and manifest['claims'] == CLAIMS and manifest['qualification'] == QUALIFICATION,
            'registered token script closed manifest differs')
        require(manifest['files'] == [_ref(path, raw) for path, raw in sorted(files.items())
            if path != 'manifest.json'], 'registered token script manifest files differ')
        inputs = manifest['inputs']
        require(type(inputs) is dict and set(inputs) ==
            {'tokenHash', 'registryAnchorHash', 'registryTranscriptHash', 'disclosure'},
            'registered token script closed inputs differ')
        result = compose(_sub(files, 'token/'), inputs['tokenHash'],
            files['registry/source/anchor.json'], inputs['registryAnchorHash'],
            files['registry/source/transcript.json'], inputs['registryTranscriptHash'],
            disclosure=inputs['disclosure'])
        require(dict(result.files) == files,
            'registered token script deterministic reconstruction differs')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed registered token script package') from exc
