"""Coherent synthetic reference ZIP/PNG bytes and original Archive receipts.

Only fixture construction hooks are replaced. All production reference,
inventory, retrieval, semantic and package validators run unchanged. The test
signatures/Archive observations are synthetic and do not prove possession by
an institution or execution of the declared environment.
"""
from copy import deepcopy
from functools import lru_cache
from hashlib import sha256
from io import BytesIO
from unittest.mock import patch
from zipfile import ZIP_STORED, ZipFile, ZipInfo

from . import view_preservation_retrieval_fixture_v1 as retrieval_fixture
from . import test_view_preservation_retrieval_inventory_v1 as inventory_fixture
from . import test_view_preservation_reference_wire_v1 as reference_fixture
from . import view_preservation_inventory_fixture_v1 as original_inventory_fixture
from . import view_preservation_inventory_sources_v1 as inventory_sources
from . import view_preservation_reference_types_v1 as reference_types
from . import view_preservation_reference_wire_v1 as reference_wire
from . import view_preservation_retrieval_inventory_v1 as inventory_wire
from .canonical import dumps, keccak256, schema_id
from .current_media_inputs import image_bytes
from .independent_wire import json_values, require
from .native_finality_wire import from_json
from .test_view_preservation_retrieval_v1 import complete_envelope

_ORIGINAL_ARCHIVE = retrieval_fixture._archive
_ORIGINAL_LABEL = retrieval_fixture.D
PACKAGE_CONTENTS = (('engine.exe', b'synthetic engine declaration; not executable'),
    ('tool.py', b'# synthetic reference tool declaration; never executed\n'))


def received_bytes(role):
    if role == 'png':
        return image_bytes()
    require(role == 'zip', 'synthetic reference receipt role must be zip or png')
    stream = BytesIO()
    with ZipFile(stream, 'w', compression=ZIP_STORED) as output:
        for name, raw in PACKAGE_CONTENTS:
            entry = ZipInfo(name, date_time=(2000, 1, 1, 0, 0, 0))
            entry.compress_type = ZIP_STORED
            entry.create_system = 0
            output.writestr(entry, raw)
    return stream.getvalue()


def _sha(raw):
    return '0x' + sha256(raw).hexdigest()


def _archive(role, context, graph, source, media_bytes):
    """Use the existing complete receipt encoder with native reference roles."""
    named = {row['name']: row for row in reference_types.definitions()}
    schema = named['STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1' if role == 'zip'
        else 'STREAM_REFERENCE_PNG_OBJECT_V1']
    catalogue = named['STREAM_REFERENCE_NATIVE_FORMATS_V1']
    exact = {'media schema': schema['id'],
        'media format': schema_id('IANA:application/zip' if role == 'zip' else 'IANA:image/png'),
        'format catalogue': catalogue['id'], 'format catalogue bytes': catalogue['hash']}
    with patch.object(retrieval_fixture, 'D', side_effect=lambda label: exact.get(label, _ORIGINAL_LABEL(label))):
        return _ORIGINAL_ARCHIVE(context, graph, source, media_bytes)


def _inventory(role, uri, *, count=1, burned=False):
    inventory, context, graph, witness, configuration = inventory_fixture.supplied(
        uri, count=count, burned=burned)
    value = inventory['value']; old_context = deepcopy(value['context'])
    fixed = [{'stage': row['stage'], 'index': row['index'], 'items': deepcopy(row['items']),
        'sourceWitnessHash': row['segment'][3], 'source': deepcopy(row['source'])}
        for row in value['segments'] if 2 <= int(row['stage']) <= 6]
    original, _, _, _ = inventory_sources.selected(value['reference'])
    source = from_json(inventory_fixture.t.SOURCE, inventory_wire.retrieval_source(value))
    raw = received_bytes(role)
    obj, admission, _, _, _, _ = _archive(role, context, graph, source, raw)
    coverage = admission[3]; observation = original['publication'][1]
    environment = observation[8]
    if role == 'zip':
        old_key = environment[0]
        environment[:2] = [coverage[1], coverage[0]]
        original['source'][6] = json_values(coverage)
        # Real ZIP entries exactly match these declarations, but the semantic
        # consumer must still not infer member possession from container bytes.
        entries = [[name, str(len(body)), _sha(body)] for name, body in PACKAGE_CONTENTS]
        environment[6] = entries[0][2]
        environment[9] = entries[1][2]
        environment[12] = entries
        original['fileInventories']['package'] = reference_fixture.inventory(
            tuple((name, int(size), digest) for name, size, digest in entries), True, context, graph)
    else:
        capture, sample = observation[7][0], original['source'][7][0]
        old_key = capture[6]
        capture[6:8] = [coverage[1], coverage[0]]
        capture[9] = [obj[4], obj[4]]
        sample[2] = json_values(coverage)
    target = next(row for row in original['objects'] if row['objectHash'] == old_key)
    target.update(objectHash=coverage[1], identity=json_values(obj))
    environment_bytes = reference_wire.environment_bytes(from_json(reference_types.ENVIRONMENT, environment))
    environment[2:4] = [keccak256(environment_bytes), str(len(environment_bytes))]
    original['environment'] = '0x' + environment_bytes.hex()
    for capture in observation[7]:
        capture[10] = environment[2]
    reference_fixture.reseal(value['reference'], context, graph)
    original_inventory_fixture.set_context(value,
        from_json(inventory_fixture.it.DESCRIPTIONS, old_context[5]),
        from_json(inventory_fixture.it.CONSERVATION, old_context[6]), old_context[7])
    inventory_fixture.seal(value, context, graph, fixed)
    inventory_wire.validate(inventory, context, graph, witness, configuration)
    return inventory, context, graph, witness, configuration


@lru_cache(maxsize=2)
def supplied_raw(role):
    """Return canonical full native envelope with one same-object received role."""
    raw = received_bytes(role)
    with patch.object(retrieval_fixture, 'MEDIA_BYTES', raw), \
            patch.object(retrieval_fixture, 'inventory_supplied',
                side_effect=lambda uri, **options: _inventory(role, uri, **options)), \
            patch.object(retrieval_fixture, '_archive',
                side_effect=lambda context, graph, source, media: _archive(role, context, graph, source, media)):
        value = complete_envelope()
    return dumps(value)
