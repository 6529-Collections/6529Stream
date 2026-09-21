"""Retain exact inputs for the three concrete current acquisition consumers."""
from . import object_dossier as package
from .bagit import MAX_MANIFEST
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

NAME = 'STREAM_MUSEUM_CANONICAL_NATIVE_INPUTS_V1'
METADATA_FILES = ('anchor.json', 'transcript.json', 'snapshot.json', 'pins.json', 'profile.json')
PROFILE_BYTES = dumps({'name': NAME, 'version': '1',
    'required': ['preservation/input.json', 'work/evidence.json', 'recovery/evidence.json'],
    'metadata': list(METADATA_FILES), 'condition': 'Optional complete original public-condition capture.',
    'verification': 'External manifest pin and exact file commitments precede concrete source replay.',
    'qualification': 'Transport commitments are not source verification, authority or completeness.'})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def create(preservation_raw, work_raw, metadata_files, recovery_raw, *, condition_files=None):
    """Create a transport manifest; this deliberately makes no verification claim."""
    require(type(metadata_files) is dict and set(metadata_files) == set(METADATA_FILES),
        'canonical native inputs exact Metadata files')
    files = {'preservation/input.json': preservation_raw, 'work/evidence.json': work_raw,
        'recovery/evidence.json': recovery_raw}
    files.update({'work/metadata/' + path: raw for path, raw in metadata_files.items()})
    condition_hash = None
    if condition_files is not None:
        condition_files = dict(condition_files)
        package._bounded(condition_files)
        require('manifest.json' in condition_files, 'canonical native inputs condition manifest missing')
        condition_hash = keccak256(condition_files['manifest.json'])
        files.update({'work/condition/' + path: raw for path, raw in condition_files.items()})
    package._bounded(files)
    manifest = dumps({'profile': NAME, 'version': '1', 'profileHash': PROFILE_HASH,
        'conditionManifestHash': condition_hash,
        'files': [package._ref(path, raw) for path, raw in sorted(files.items())]})
    require(len(manifest) <= MAX_MANIFEST, 'canonical native inputs manifest bound')
    files['manifest.json'] = manifest
    package._bounded(files)
    return files, keccak256(manifest)


def admit(files, expected_hash):
    """Check immutable transport only; caller must run each concrete consumer."""
    try:
        files = dict(files)
        package._bounded(files)
        raw = files.get('manifest.json', b'')
        require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
            'canonical native inputs external manifest differs')
        manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
        require(type(manifest) is dict and set(manifest) == {'profile', 'version', 'profileHash',
            'conditionManifestHash', 'files'} and manifest['profile'] == NAME
            and manifest['version'] == '1' and manifest['profileHash'] == PROFILE_HASH,
            'canonical native inputs closed manifest differs')
        require(manifest['files'] == [package._ref(path, body) for path, body in sorted(files.items())
            if path != 'manifest.json'], 'canonical native inputs file commitments differ')
        metadata = {name: files['work/metadata/' + name] for name in METADATA_FILES}
        condition = {path.removeprefix('work/condition/'): body for path, body in files.items()
            if path.startswith('work/condition/')}
        require(bool(condition) == (manifest['conditionManifestHash'] is not None),
            'canonical native inputs condition pin/presence differs')
        rebuilt, digest = create(files['preservation/input.json'], files['work/evidence.json'],
            metadata, files['recovery/evidence.json'], condition_files=condition or None)
        require(digest == expected_hash and rebuilt == files, 'canonical native inputs reconstruction differs')
        return files, metadata, condition or None, manifest['conditionManifestHash']
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, OverflowError, RecursionError) as exc:
        raise MuseumError('malformed canonical native inputs') from exc
