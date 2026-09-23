"""Original system-manifest selection of an independently preserved tool ZIP.

This is an offline observation verifier. It neither publishes a release nor
authenticates a caller's deployment selection. Historical native payloads use
the system-manifest chunk-root codec, not a generic Metadata record hash.
"""
from dataclasses import dataclass
from pathlib import Path

from . import acquisition_recovery_sustainability_v1 as reads
from . import conservation_archive_v1 as archive
from . import public_chain_history as history
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require

SOURCE_REVISION = 'aa8ce49e5c8c2cba4315c1763ebc5df881a686e4'
PROFILE = 'STREAM_MUSEUM_PRESERVED_TOOL_RELEASE_V1'
MAX_BYTES = 64 * 1024 * 1024
MAX_HISTORY = 64
MAX_PINS = 4096
STATE_KEYS = reads.STATE_KEYS
INTERFACE = '0x37660ede'
MODULE_TYPE = '0x47fd79d5a6e9b1d75dcedf141a46e2e8f6d95d5a5be2b88f197fa98a1436fec6'
AGGREGATE = ('bytes32', 'string', *('address',) * 11, *('bytes32',) * 7, 'uint64')
POINTER = reads.citation.POINTER
CHUNK = ('address', 'uint32', 'bytes32')
DESCRIPTOR = ('bytes4', 'uint16', 'bytes32', 'bytes32', 'uint32', 'uint16', Array(CHUNK, 32))
MAGIC = '0x6c9d2530'
SCHEMA = '0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81'
JCS = '0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044'
ROOT_DOMAIN = '0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b'
LEAF_DOMAIN = '0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5'
LIST_DOMAIN = '0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839'
PUBLISHED = schema_id('StreamSystemManifestPublished(uint16,bytes32,address,bytes32)')
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1', 'sourceReviewCommit': SOURCE_REVISION,
    'normativeSources': ['LTA-RECON:1-3,5', 'CMC-OBJECT-DOSSIER:1-3'],
    'historyProfileHash': history.PROFILE_HASH,
    'bounds': {'inputBytes': MAX_BYTES, 'manifestHistory': MAX_HISTORY, 'runtimePins': MAX_PINS,
        'manifestChunks': 32, 'manifestPayloadBytes': 786400},
    'selection': 'Core SYSTEM_MANIFEST frozen active pointer, immutable Core/Executor binding and exact current 21-field aggregate; reconstructionClientHash equals Keccak of the complete independently verified preserved-tool ZIP. Package transport SHA256 is an independent external pin.',
    'history': 'Complete selected satellite count/At history, exact original publication event bijection, STOP descriptor/chunks and native leaf/list/root domains. Historical payload bytes and action IDs survive; old discovery tuples and governance authorization are not inferred from a pointer entry.',
    'archive': 'Optional original two-family ExternalObject or ArtifactCoverage evidence covers exact tool ZIP and selected deployment payload separately. Every generated getter is matched to retained source-block observations. Native Artist-scoped identity is retained without inferring release authority. Missing evidence remains missing, not an absence proof.',
    'qualification': 'Caller-selected deployment and RPC provenance remain externally admitted. Native payload publication checks chunk bytes, not complete deployment JSON inventory semantics. Archive signatures, checkpoints, liveness and consensus are not reexecuted. Tool source closure/member roles are verified by the preserved-tool archive consumer; build/vector/regeneration execution belongs to the separate offline runner. No current release commitment is manufactured.',
    'claims': {'completeListedManifestHistory': True, 'originalPayloadBytesRetained': True,
        'nativeToolHashEqualityChecked': True, 'sourceProvenanceAuthenticated': False,
        'completeDeploymentInventoryVerified': False, 'governanceAuthorizationReexecuted': False,
        'historicalManifestHostUniverseProven': False, 'archiveLivenessReexecuted': False,
        'toolExecutionPerformed': False, 'consensusVerified': False}})
PROFILE_HASH = keccak256(PROFILE_BYTES)
MissingObservation = reads.MissingObservation


@dataclass(frozen=True)
class Result:
    files: dict
    report: dict
    observations: list


def _closed(value, fields, label):
    require(type(value) is dict and set(value) == set(fields.split()), label + ' shape')


def _hash(types, values): return keccak256(encode(types, values))


def payload_hash(parts):
    """Exact StreamGovernanceEvidence manifest leaf/list/root recipe."""
    require(type(parts) in (list, tuple) and 0 < len(parts) <= 32
        and all(type(p) is bytes and 0 < len(p) <= 24575 for p in parts)
        and all(len(p) == 24575 for p in parts[:-1]), 'tool manifest chunk width/count')
    total = sum(map(len, parts)); require(total <= 786400, 'tool manifest payload bound')
    leaves = tuple(_hash(('bytes32', 'uint256', 'uint32', 'bytes32'),
        (LEAF_DOMAIN, i, len(part), keccak256(part))) for i, part in enumerate(parts))
    listing = _hash(('bytes32', 'uint32', Array('bytes32', 32)), (LIST_DOMAIN, total, leaves))
    return _hash(('bytes32', 'uint16', 'bytes32', 'bytes32', 'uint32', 'uint16', 'bytes32'),
        (ROOT_DOMAIN, 1, SCHEMA, JCS, total, len(parts), listing))


def _payload(o, pointer, expected):
    runtime = o.code(pointer)
    require(runtime[:1] == b'\0' and 353 <= len(runtime) <= 3329, 'tool manifest root runtime')
    d = decode(DESCRIPTOR, runtime[1:], maximum=3328)
    require(d[:4] == (MAGIC, 1, SCHEMA, JCS) and 0 < d[4] <= 786400
        and d[5] == len(d[6]) and len(runtime) == 257 + 96 * d[5], 'tool manifest descriptor')
    parts = []
    for address, size, digest in d[6]:
        raw = o.code(address)
        require(raw[:1] == b'\0' and len(raw) == size + 1 and keccak256(raw[1:]) == digest,
            'tool manifest original chunk bytes')
        parts.append(raw[1:])
    require(sum(map(len, parts)) == d[4] and payload_hash(parts) == expected,
        'tool manifest native root hash')
    return b''.join(parts), {'pointer': pointer, 'runtimeHash': keccak256(runtime),
        'descriptor': json_values(d), 'descriptorHex': '0x' + runtime[1:].hex()}


def _source(value):
    a, g = value['anchor'], value['graph']
    _closed(a, ' '.join(STATE_KEYS), 'tool release anchor')
    for key in ('chainId', 'collectionId', 'tokenId'): require(uint(a[key]) > 0, 'tool release positive identity')
    uint(a['blockNumber'], 64); uint(a['timestamp'], 64); reads._nonzero(a['core'], 20)
    for key in ('blockHash', 'stateRoot', 'deploymentEvidenceHash'): reads._nonzero(a[key])
    require(a['environment'] in ('local_evm_fixture', 'public_chain'), 'tool release environment')
    _closed(g, 'systemManifest executor codePins', 'tool release graph')
    require(type(g['codePins']) is dict and len(g['codePins']) <= MAX_PINS, 'tool release runtime pin bound')
    for address, digest in g['codePins'].items(): reads._nonzero(address, 20); reads._nonzero(digest)
    host, executor = g['systemManifest'], g['executor']
    require(len({host, executor, a['core']}) == 3
        and all(address in g['codePins'] for address in (host, executor, a['core'])), 'tool release required distinct bindings')
    o = reads.Observations(a, g, value['calls'])
    observed = history.scan_public_history(o, a, filters=[{'address': host, 'topics': [PUBLISHED]}])
    for address in g['codePins']: o.code(address)
    pointer = o.one(a['core'], 'getSatellitePointer(bytes32)', POINTER, ('bytes32',), (schema_id('SYSTEM_MANIFEST'),))
    require(pointer[0] == host and pointer[1] == g['codePins'][host] and pointer[2]
        and pointer[3:5] == (MODULE_TYPE, INTERFACE) and pointer[5] in g['codePins']
        and pointer[6] == 1 and pointer[7] != ZERO and pointer[8] != ZERO and pointer[9] > 0,
        'tool release actual frozen active Core pointer')
    for address in (a['core'], host, executor, pointer[5]):
        require(not o.code(address).startswith(b'\xef\x01\x00'), 'tool release delegated EOA binding')
    require(o.one(host, 'core()', 'address') == a['core']
        and o.one(host, 'governanceExecutor()', 'address') == executor, 'tool release immutable bindings')
    for interface, yes in (('0x01ffc9a7', True), (INTERFACE, True), ('0xffffffff', False)):
        require(o.one(host, 'supportsInterface(bytes4)', 'bool', ('bytes4',), (interface,)) == yes,
            'tool release native interface')
    current = o.read(host, 'streamSystemManifest()', AGGREGATE)
    count = o.one(host, 'streamSystemManifestPointerCount()', 'uint256')
    require(0 < count <= MAX_HISTORY and current[20] == count, 'tool release complete history count/revision')
    require(current[9] == executor and all(current[i] != ZERO for i in (0, *range(13, 20)))
        and 0 < len(current[1].encode('utf-8')) <= 2048, 'tool release aggregate identity')
    require(current[11] != ZERO_ADDRESS, 'tool release aggregate registry absent')
    selected_pointer = o.one(host, 'streamSystemManifestPointer()', 'address')
    logs = observed['logs']; require(len(logs) == count, 'tool release publication event denominator')
    entries, files = [], {}
    for index, log in enumerate(logs):
        carrier, digest, stamp = o.read(host, 'streamSystemManifestPointerAt(uint256)',
            ('address', 'bytes32', 'uint64'), ('uint256',), (index,))
        require(len(log['topics']) == 4 and log['topics'][1] == digest
            and log['topics'][2] == '0x' + encode(('address',), (carrier,)).hex()
            and log['topics'][3] != ZERO and decode(('uint16',), hex_bytes(log['data'])) == (1,)
            and stamp == o.stamp(log), 'tool release original pointer/publication join')
        body, descriptor = _payload(o, carrier, digest)
        path = f'manifests/{index:06d}/payload.bin'; files[path] = body
        entries.append({'index': str(index), 'manifestHash': digest, 'updatedAt': str(stamp),
            'payload': {'path': path, 'keccak256': keccak256(body), 'byteLength': str(len(body))},
            'carrier': descriptor, 'publication': log, 'actionId': log['topics'][3]})
    require(entries[-1]['manifestHash'] == current[0] and entries[-1]['carrier']['pointer'] == selected_pointer,
        'tool release current head differs from complete history')
    return o, current, pointer, entries, files, observed['coverage']


def _archives(value, o, materials):
    _closed(value, 'graph toolArchive deploymentManifest', 'tool archive evidence')
    graph = value['graph']; require(type(graph) is dict and set(graph) <= {'coverage', 'externalCoverage'}, 'tool archive graph')
    for row in graph.values():
        _closed(row, 'address runtimeHash', 'tool archive graph row')
        require(o.graph['codePins'].get(row['address']) == row['runtimeHash'], 'tool archive source runtime pin')
    source = {**o.a, 'codePins': [{'address': a, 'runtimeHash': h} for a, h in o.graph['codePins'].items()]}
    originals = archive._Originals({'source': source}, {'calls': o.rows}, graph)
    report = {}
    for name, raw in materials.items():
        row = value[name]
        if row is None:
            report[name] = {'status': 'original_dual_family_evidence_not_supplied'}; continue
        _closed(row, 'artistId proof', 'tool artifact original archive')
        reads._nonzero(row['artistId'])
        proof = row['proof']; _closed(proof, 'backend coverage sourceEvidence originalBundleHash partsHash', 'tool artifact proof')
        require(proof['backend'] in ('external', 'onchain'), 'tool archive backend')
        if proof['backend'] == 'external':
            require('externalCoverage' in graph, 'tool external archive host missing')
            verified = archive._external(proof, raw, archive.archive.RAW, [row['artistId']], None, None, originals, graph)
        else:
            require('coverage' in graph, 'tool artifact archive host missing')
            verified = archive._onchain(proof, raw, archive.archive.RAW, [row['artistId']], originals, graph)
        report[name] = {'status': 'original_dual_family_correspondence_checked', **verified,
            'releaseAuthorityInferred': False, 'currentLivenessVerified': False}
    # The primitive produces the exact original getter list; require actual
    # source-block RPC outcomes for every one rather than trusting this list.
    for address, digest in originals.pins.items():
        require(o.graph['codePins'].get(address) == digest, 'tool archive undeclared/conflicting runtime observation')
    for row in originals.calls:
        answer = o.request('eth_call', [{'to': row['target'], 'data': row['calldata'], 'gas': '0x1312d00'}, o.block])
        require(answer == row['result'], 'tool archive original getter differs')
    return report


def validate(raw, expected_hash, *, package, expected_parts_sha256, disclosure='public'):
    """Replay native observations and independently verify the supplied package.

    `package` is the preserved-tool archive directory, never an executable.
    The external package SHA256 and native evidence Keccak are separate pins.
    """
    require(disclosure == 'public', 'tool release requires public disclosure')
    try: return _validate(raw, expected_hash, Path(package), expected_parts_sha256)
    except MuseumError: raise
    except (KeyError, ValueError, TypeError, IndexError, OverflowError, UnicodeError) as exc:
        raise MuseumError('malformed preserved tool release evidence') from exc


def _validate(raw, expected_hash, package, expected_parts_sha256):
    require(type(raw) is bytes and keccak256(raw) == expected_hash, 'tool release external evidence hash')
    value = loads(raw, maximum=MAX_BYTES, canonical=True)
    _closed(value, 'profile anchor graph provenance calls archives', 'tool release envelope')
    require(value['profile'] == PROFILE and value['provenance'] in ('synthetic_fixture', 'externally_admitted_rpc'),
        'tool release profile/provenance')
    o, current, pointer, entries, files, coverage = _source(value)
    from . import preserved_tool_source_v1 as package_reader
    tool = package_reader.verify(package, expected_parts_sha256)
    # The packager's verified retained bytes, not caller-supplied report fields.
    tool_raw = tool.archive_bytes
    require(keccak256(tool_raw) == current[19], 'tool archive differs from native reconstructionClientHash')
    archived = _archives(value['archives'], o, {'toolArchive': tool_raw,
        'deploymentManifest': files[entries[-1]['payload']['path']]})
    require(o.used == set(o.answers), 'tool release unused original observations')
    transcript = {'profile': PROFILE, 'version': 1, 'calls': value['calls']}
    report = {'profile': PROFILE, 'profileHash': PROFILE_HASH, 'sourceReviewCommit': SOURCE_REVISION,
        'sourceState': o.a, 'provenance': value['provenance'], 'sourceEvidenceHash': expected_hash,
        'selectedCorePointer': json_values(pointer),
        'aggregate': json_values(current), 'history': entries, 'historyCoverage': coverage,
        'reconstructionClientHash': current[19], 'partsManifestSha256': expected_parts_sha256,
        'toolSourceManifestHash': keccak256(dict(tool.restored_files)['manifest/source.json']),
        'toolPackage': tool.report,
        'archive': archived, 'claims': loads(PROFILE_BYTES)['claims'],
        'remaining': ['source_provenance_and_release_authority', 'offline_build_vector_and_regeneration_execution']
            + [name + '_dual_family_archive' for name, row in archived.items()
                if row['status'] != 'original_dual_family_correspondence_checked']}
    files.update({'source/evidence.json': raw, 'source/anchor.json': dumps(o.a),
        'source/transcript.json': dumps(transcript), 'profile.json': PROFILE_BYTES, 'report.json': dumps(report)})
    files.update({'tool-package/' + path: body for path, body in tool.files})
    observations = [{'kind': 'rpc', 'name': 'preserved-tool-release', 'anchor': o.a,
        'transcript': transcript, 'runtimePins': o.graph['codePins'], 'provenance': value['provenance']}]
    return Result(files, report, observations)
