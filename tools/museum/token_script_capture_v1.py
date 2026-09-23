"""Offline replay package for one token-resolved script source observation."""
from . import script_dependency_rpc_v1 as rpc
from . import token_script_source_v1 as native
from .bagit import MAX_BYTES, MAX_MANIFEST
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .object_dossier import Assembly, _bounded, _ref

PROFILE = 'STREAM_MUSEUM_TOKEN_SCRIPT_CAPTURE_V1'
CLAIMS = {'nativeTokenSourceReplayed': True, 'exactAvailableScriptBytesRetained': True,
    'registeredInterpretationProven': False, 'dossierRequirementPromoted': False,
    'nonScriptClassificationProven': False, 'sourceOriginAuthenticated': False,
    'consensusVerified': False, 'networkFetch': False}
QUALIFICATION = ('The complete token-resolved native source and original ordered transcript '
    'are retained with exact available script/dependency bytes. Positive script classification '
    'is source-state evidence only. No registered interpretation, dossier promotion, negative '
    'work-class inference, origin authentication or consensus is established.')
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1',
    'nativeSourceProfileHash': native.PROFILE_HASH, 'rpcProfileHash': rpc.PROFILE_HASH,
    'claims': CLAIMS, 'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _input(raw, digest, maximum, label):
    require(type(raw) is bytes and 0 < len(raw) <= maximum and
        keccak256(raw) == digest, 'token script ' + label + ' input commitment differs')


def _payloads(snapshot):
    files, references = {}, {}
    interpretation = snapshot['interpretation']
    if interpretation is None:
        return files, references
    report = interpretation['report']
    for role in ('script', 'dependency'):
        item = report[role]
        payload = item.get('payloadHex')
        if payload is None:
            continue
        require(item.get('payloadStatus') == 'complete',
            'token script incomplete payload projection')
        path = 'payloads/' + role + '.bin'
        files[path] = hex_bytes(payload)
        references[role] = _ref(path, files[path])
    return files, references


def _assemble(anchor_raw, anchor_hash, transcript_raw, transcript_hash,
        runtime_bridge_raw, runtime_bridge_hash, *, provenance, disclosure):
    require(disclosure == 'public', 'token script public disclosure required before reads')
    _input(anchor_raw, anchor_hash, native.collection.MAX_ANCHOR, 'anchor')
    _input(transcript_raw, transcript_hash, rpc.MAX_TRANSCRIPT, 'transcript')
    _input(runtime_bridge_raw, runtime_bridge_hash, MAX_BYTES, 'runtime bridge')
    anchor = loads(anchor_raw, maximum=native.collection.MAX_ANCHOR, canonical=True)
    require(anchor['runtimeAdmission']['artifactHash'] == runtime_bridge_hash,
        'token script runtime admission bridge differs')
    transport = rpc.ReplayTransport(transcript_raw, transcript_hash)
    reader = native.TokenScriptSource(anchor_raw, transport, provenance=provenance)
    snapshot_raw = reader.snapshot(); transport.finish()
    require(reader.transcript() == transcript_raw,
        'token script original transcript differs')
    snapshot = loads(snapshot_raw, maximum=MAX_BYTES, canonical=True)
    payloads, refs = _payloads(snapshot)
    inputs = {'anchorHash': anchor_hash, 'transcriptHash': transcript_hash,
        'runtimeBridgeHash': runtime_bridge_hash, 'provenance': provenance,
        'disclosure': disclosure}
    report = {'profile': PROFILE, 'profileHash': PROFILE_HASH,
        'sourceState': snapshot['sourceState'], 'workClass': snapshot['workClass'],
        'positiveScriptClassification': snapshot['positiveScriptClassification'],
        'interpretationStatus': snapshot['interpretationStatus'],
        'payloads': refs, 'claims': CLAIMS, 'qualification': QUALIFICATION}
    files = {'source/anchor.json': anchor_raw, 'source/transcript.json': transcript_raw,
        'source/runtime-bridge.bin': runtime_bridge_raw, 'source/snapshot.json': snapshot_raw,
        'definitions/capture-profile.json': PROFILE_BYTES,
        'definitions/source-profile.json': native.PROFILE_BYTES,
        'definitions/rpc-profile.json': rpc.PROFILE_BYTES,
        'report.json': dumps(report)}
    files.update(payloads)
    _bounded(files)
    manifest = dumps({'profile': PROFILE, 'profileHash': PROFILE_HASH,
        'inputs': inputs, 'files': [_ref(path, raw) for path, raw in sorted(files.items())],
        'claims': CLAIMS, 'qualification': QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, 'token script manifest byte bound')
    files['manifest.json'] = manifest
    _bounded(files)
    return Assembly(tuple(sorted(files.items())), manifest, report)


def replay(anchor_raw, anchor_hash, transcript_raw, transcript_hash,
        runtime_bridge_raw, runtime_bridge_hash, *, provenance, disclosure):
    try:
        return _assemble(anchor_raw, anchor_hash, transcript_raw, transcript_hash,
            runtime_bridge_raw, runtime_bridge_hash, provenance=provenance,
            disclosure=disclosure)
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed token script capture') from exc


def verify(files, expected_hash):
    try:
        files = dict(files); _bounded(files)
        require(keccak256(files['manifest.json']) == expected_hash,
            'token script external manifest differs')
        manifest = loads(files['manifest.json'], maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) ==
            {'profile', 'profileHash', 'inputs', 'files', 'claims', 'qualification'} and
            manifest['profile'] == PROFILE and manifest['profileHash'] == PROFILE_HASH and
            manifest['claims'] == CLAIMS and manifest['qualification'] == QUALIFICATION,
            'token script closed manifest differs')
        require(manifest['files'] == [_ref(path, raw) for path, raw in sorted(files.items())
            if path != 'manifest.json'], 'token script manifest files differ')
        inputs = manifest['inputs']
        require(type(inputs) is dict and set(inputs) ==
            {'anchorHash', 'transcriptHash', 'runtimeBridgeHash', 'provenance', 'disclosure'},
            'token script closed inputs differ')
        result = replay(files['source/anchor.json'], inputs['anchorHash'],
            files['source/transcript.json'], inputs['transcriptHash'],
            files['source/runtime-bridge.bin'], inputs['runtimeBridgeHash'],
            provenance=inputs['provenance'], disclosure=inputs['disclosure'])
        require(dict(result.files) == files, 'token script deterministic reconstruction differs')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed token script capture package') from exc
