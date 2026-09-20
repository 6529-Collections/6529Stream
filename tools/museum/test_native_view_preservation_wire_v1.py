"""Original preservation joins and chronology using fully rehashed synthetic records."""
from copy import deepcopy
import unittest

from . import native_view_preservation_wire_v1 as wire
from . import view_preservation_root_wire_v1 as root
from .canonical import MuseumError, schema_id
from .independent_wire import ZERO
from .test_view_preservation_snapshot_wire_v1 import reseal as reseal_snapshots
from .test_view_preservation_root_wire_v1 import reseal as reseal_roots
from .view_preservation_fixture_v1 import ViewPreservationFixtureV1


def position(row):
    return tuple(int(row['log'][key], 16)
        for key in ('blockNumber', 'transactionIndex', 'logIndex'))


class NativeViewPreservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = ViewPreservationFixtureV1()
        cls.replaced = ViewPreservationFixtureV1(later_adoption=True)

    def events_for(self, bundle, fixture=None):
        """Retain coordinates, replacing only explicitly rehashed original payloads."""
        fixture = fixture or self.original
        originals = {(row['log']['address'], tuple(row['log']['topics'])): row
            for row in fixture.view_events}
        events = []
        for descriptor in wire.expected_events(bundle, fixture.context, fixture.graph):
            key = descriptor['address'], tuple(descriptor['topics'])
            if key in originals:
                row = deepcopy(originals[key])
                row['log']['data'] = descriptor['data']
            elif descriptor['kind'] in ('view_snapshot_published', 'view_root_published', 'view_root_binding_published'):
                if descriptor['kind'] == 'view_snapshot_published':
                    saved = next(item for item in bundle['snapshot']['history']
                        if item['receipt'][0] == descriptor['topics'][3])
                    stamp, index = int(saved['receipt'][13]), 0
                else:
                    saved = next(item for item in bundle['root']['history']
                        if item['recordHash'] == descriptor['topics'][3])
                    stamp, index = int(saved['record'][17]), int(descriptor['kind'].endswith('binding_published'))
                number = stamp - 100
                row = {'log': {'address': descriptor['address'], 'topics': list(descriptor['topics']),
                    'data': descriptor['data'], 'blockNumber': hex(number),
                    'blockHash': fixture.header(number)['hash'],
                    'transactionHash': schema_id('joined publication transaction ' + str(number)),
                    'transactionIndex': '0x0', 'logIndex': hex(index), 'removed': False},
                    'timestamp': str(stamp)}
            else:
                # Coverage plan ID is intentionally a wildcard in the native descriptor.
                matches = [item for item in fixture.view_events if item['log']['address'] == descriptor['address']
                    and item['log']['topics'][0] == descriptor['topics'][0]
                    and item['log']['data'] == descriptor['data']]
                self.assertEqual(len(matches), 1)
                row = deepcopy(matches[0])
            events.append(row)
        return sorted(events, key=position)

    def test_original_source_snapshot_root_and_later_adoption(self):
        for fixture in (self.original, self.replaced):
            result = wire.validate_bundle(fixture.bundle, fixture.context, fixture.graph)
            joined = wire.validate_event_join(fixture.bundle, fixture.context, fixture.graph, fixture.view_events)
            self.assertEqual(result['snapshot']['source'][3], fixture.output_value['checkpoint']['source'])
            self.assertEqual(result['root']['record'][5], fixture.output_value['checkpoint']['plan'][9])
            self.assertTrue(joined['originalPublicationChronologyChecked'])
            self.assertFalse(joined['historicalAuthorityVerified'])
            self.assertFalse(joined['viewFinalityEstablished'])

    def test_preservation_registration_must_follow_original_adoption(self):
        fixture = self.original
        events = deepcopy(fixture.view_events)
        registration = next(row for row in events if row['log']['address'] == fixture.graph['rendererRegistry']['address'])
        previous = [row for row in events if position(row)[0] == 2][-1]
        registration['log'].update({key: previous['log'][key] for key in
            ('blockNumber', 'blockHash', 'transactionHash', 'transactionIndex')})
        registration['log']['logIndex'] = hex(position(previous)[2] + 1)
        registration['timestamp'] = previous['timestamp']
        events.sort(key=position)
        wire.validate_bundle(fixture.bundle, fixture.context, fixture.graph)
        with self.assertRaisesRegex(MuseumError, 'publication chronology'):
            wire.validate_event_join(fixture.bundle, fixture.context, fixture.graph, events)

    def with_later_snapshot(self, stamp):
        fixture = self.original
        bundle = deepcopy(fixture.bundle)
        snapshots = bundle['snapshot']
        snapshots['lock'] = [ZERO, '0', ZERO, '0']
        later = deepcopy(snapshots['history'][0])
        later['publication'][1] = schema_id('second preserved snapshot')
        later['publication'][8] = later['receipt'][13] = str(stamp)
        snapshots['history'].append(later)
        reseal_snapshots(snapshots, fixture.context, fixture.graph)
        wire.validate_bundle(bundle, fixture.context, fixture.graph)
        return bundle, self.events_for(bundle)

    def test_later_snapshot_after_root_preserves_original_selected_evidence(self):
        bundle, events = self.with_later_snapshot(110)
        self.assertNotEqual(bundle['snapshot']['selectedRecordHash'], bundle['snapshot']['current'][0])
        wire.validate_event_join(bundle, self.original.context, self.original.graph, events)

    def test_snapshot_replaced_before_root_rejected_despite_coherent_hashes(self):
        bundle, events = self.with_later_snapshot(108)
        with self.assertRaisesRegex(MuseumError, 'snapshot changed before CONTENT_ROOT'):
            wire.validate_event_join(bundle, self.original.context, self.original.graph, events)

    def test_original_root_cannot_be_published_after_replacement_adoption(self):
        fixture = self.replaced
        bundle = deepcopy(fixture.bundle)
        bundle['root']['history'][0]['record'][17] = '111'
        reseal_roots(bundle['root'], fixture.context, fixture.graph)
        wire.validate_bundle(bundle, fixture.context, fixture.graph)
        with self.assertRaisesRegex(MuseumError, 'adoption changed before snapshot/root'):
            wire.validate_event_join(bundle, fixture.context, fixture.graph, self.events_for(bundle, fixture))

    def test_root_binding_must_be_immediate_original_publication_event(self):
        fixture = self.original
        events = deepcopy(fixture.view_events)
        binding = next(row for row in events if row['log']['topics'][0] == root.BINDING_PUBLISHED)
        binding['log']['logIndex'] = hex(position(binding)[2] + 1)
        with self.assertRaisesRegex(MuseumError, 'completion event adjacency'):
            wire.validate_event_join(fixture.bundle, fixture.context, fixture.graph, events)

    def test_coherently_rehashed_snapshot_cannot_replace_saved_output_source(self):
        fixture = self.original
        bundle = deepcopy(fixture.bundle)
        bundle['snapshot']['history'][0]['source'][3][4] = schema_id('invented original source context')
        reseal_snapshots(bundle['snapshot'], fixture.context, fixture.graph)
        with self.assertRaises(MuseumError):
            wire.validate_bundle(bundle, fixture.context, fixture.graph)

    def test_every_row_retains_its_permanent_collection_serial(self):
        fixture = self.original
        bundle = deepcopy(fixture.bundle)
        bundle['membership']['membership']['identities'][1][2] = '99'
        with self.assertRaises(MuseumError):
            wire.validate_bundle(bundle, fixture.context, fixture.graph)

    def test_source_anchor_and_event_header_must_be_reciprocal(self):
        fixture = self.original
        last = fixture.view_events[-1]
        context = {**fixture.context, 'blockNumber': str(position(last)[0]),
            'blockHash': last['log']['blockHash'], 'timestamp': last['timestamp']}
        wire.validate_event_join(fixture.bundle, context, fixture.graph, fixture.view_events)
        with self.assertRaisesRegex(MuseumError, 'event block conflict'):
            wire.validate_event_join(fixture.bundle, {**context, 'blockHash': schema_id('other anchor')},
                fixture.graph, fixture.view_events)

    def test_event_denominator_and_removed_status_are_exact(self):
        fixture = self.original
        for operation in ('omit', 'duplicate', 'removed'):
            events = deepcopy(fixture.view_events)
            if operation == 'omit': events.pop()
            elif operation == 'duplicate': events.append(deepcopy(events[-1]))
            else: events[-1]['log']['removed'] = True
            with self.subTest(operation=operation), self.assertRaises(MuseumError):
                wire.validate_event_join(fixture.bundle, fixture.context, fixture.graph, events)


if __name__ == '__main__': unittest.main()
