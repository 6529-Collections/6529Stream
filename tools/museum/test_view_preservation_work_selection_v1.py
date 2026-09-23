"""Native WORK selection commitments must survive a complete inventory read."""
from copy import deepcopy
import unittest

from . import view_preservation_inventory_fixture_v1 as fixture
from . import view_preservation_inventory_wire_v1 as wire
from . import view_preservation_inventory_stages_v1 as stages
from . import view_preservation_inventory_types_v1 as types
from .canonical import MuseumError, keccak256, schema_id
from .chain_abi import encode
from .independent_wire import ZERO, json_values
from .native_finality_wire import from_json


class WorkSelectionCommitmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = fixture.supplied()

    def vector(self):
        value, context, graph = deepcopy(self.original)
        work = next(row for row in value['segments'] if row['stage'] == '2')
        return value, context, graph, work

    def reseal(self, value, context, graph, work):
        selected = list(from_json(stages.WORK_SELECTION, work['source']['selection']))
        selected[21] = ZERO
        deps = from_json(types.DEPENDENCIES, value['dependencies'])
        native = from_json(types.CONTEXT, value['context'])
        selected[21] = keccak256(encode(
            ('bytes32','uint256','address','address','address','address','address',
             'uint256','bytes32',stages.WORK_SELECTION),
            (schema_id('6529STREAM_WORK_SELECTION_V1'),deps[6],deps[0][7],
             *deps[0][:4],native[0][1],native[1],tuple(selected))))
        work['source']['selection'] = json_values(selected)
        value['context'][5][5] = work['segment'][3] = selected[21]
        fixed = [dict(stage=row['stage'],index=row['index'],items=row['items'],
                      sourceWitnessHash=row['segment'][3],source=row['source'])
                 for row in value['segments'] if 2 <= int(row['stage']) <= 6]
        fixture.seal(value,context,graph,fixed)

    def test_native_hash_and_absent_description_pass_complete_inventory(self):
        value, context, graph, work = self.vector()
        self.reseal(value,context,graph,work)
        report = wire.validate(value,context,graph)
        self.assertTrue(report['claims']['completeTwelveStageInventoryChecked'])
        self.assertEqual(work['source']['selection'][16], [ZERO,ZERO,'0',ZERO])
        self.assertIsNone(work['source']['artist'])

    def test_unchanged_commitment_rejects_every_work_selection_field(self):
        for index in range(21):
            value, context, graph, work = self.vector()
            selected = work['source']['selection']
            kind = stages.WORK_SELECTION[index]
            if isinstance(kind, tuple): selected[index][0] = fixture.H('altered nested field')
            elif kind == 'address': selected[index] = fixture.A(987654)
            elif kind.startswith('uint'): selected[index] = str(int(selected[index])+1)
            else: selected[index] = fixture.H('altered field')
            with self.subTest(index=index), self.assertRaises(MuseumError):
                wire.validate(value,context,graph)

    def test_rehashed_payload_and_revision_still_join_description(self):
        for index, changed in ((2,fixture.H('unrelated payload')),(7,'99'),(7,'0')):
            value, context, graph, work = self.vector()
            work['source']['selection'][index] = changed
            self.reseal(value,context,graph,work)
            with self.subTest(index=index), self.assertRaisesRegex(MuseumError,'work selected record/hash'):
                wire.validate(value,context,graph)

    def test_rehashed_selection_still_joins_original_receipt(self):
        for index in (8,9,12,13,17):
            value, context, graph, work = self.vector()
            selected = work['source']['selection']
            if index == 17: selected[index][0] = fixture.H('omitted original Artist')
            elif index == 12: selected[index] = fixture.A(987654)
            elif index == 9: selected[index] = fixture.H('another record chain')
            else: selected[index] = str(int(selected[index])+1)
            self.reseal(value,context,graph,work)
            with self.subTest(index=index), self.assertRaisesRegex(MuseumError,'selection/original receipt'):
                wire.validate(value,context,graph)

    def test_profile_hash_cannot_replace_receipt_canonicalization_hash(self):
        value, context, graph, work = self.vector()
        definitions = {row['name']:row['hash'] for row in types.definitions()}
        receipt = work['source']['original']['receipt']
        self.assertEqual(receipt[7], '0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9')
        receipt[7] = definitions['STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1']
        with self.assertRaisesRegex(MuseumError,'selection/original receipt'):
            wire.validate(value,context,graph)


if __name__ == '__main__':
    unittest.main()
