"""Bounded ABI and native definition-roster tests; no EVM or live source claims."""
import json
from pathlib import Path
import re
import subprocess
import unittest

from . import view_preservation_inventory_types_v1 as t
from .canonical import MuseumError, keccak256, schema_id
from .chain_abi import Array, decode, encode, width
from .test_view_preservation_reference_types_v1 import sample

ROOT = Path(__file__).resolve().parents[2]
INTERFACES = 'smart-contracts/interfaces/stream/preservation/'


def pinned(path):
    result = subprocess.run(['git', 'show', t.SOURCE_REVISION + ':' + path],
        cwd=ROOT, capture_output=True, check=False)
    if result.returncode:
        raise unittest.SkipTest('immutable native source object unavailable in this checkout')
    return result.stdout


def struct_fields(source, name):
    text = re.sub(r'//[^\n]*|/\*.*?\*/', '', source, flags=re.S)
    body = re.search(r'\bstruct\s+' + re.escape(name) + r'\s*\{([^}]+)\}', text).group(1)
    return tuple(re.findall(r'([A-Za-z_][\w.]*(?:\[\d*\])?)\s+(\w+)\s*;', body))


def native_descriptor(source, name, known):
    def kind(value):
        fixed = re.fullmatch(r'(.+)\[(\d+)\]', value)
        if fixed:
            return (kind(fixed[1]),) * int(fixed[2])
        return known.get(value, value)
    return tuple(kind(value) for value, _ in struct_fields(source, name))


class InventoryTypesTests(unittest.TestCase):
    def test_complete_ordered_36_definition_roster(self):
        rows = t.definitions()
        self.assertEqual(len(rows), t.DEFINITION_COUNT)
        self.assertEqual(len({r['id'] for r in rows}), 36)
        self.assertEqual([len(r['bytes']) for r in rows], [11481,2350,1720,957,14613,1335,
            10223,3814,4927,3828,11052,3820,2059,3842,838,1074,2236,286,351,422,78,
            19553,1099,833,20629,1553,870,4738,833,931,852,849,810,755,699,498])
        for row in rows:
            self.assertEqual(set(row), {'name', 'id', 'kind', 'hash', 'bytes'})
            self.assertEqual(row['id'], schema_id(row['name']))
            self.assertEqual(row['hash'], keccak256(row['bytes']))
            self.assertIn(row['kind'], (0, 1, 2))
            self.assertIsInstance(json.loads(row['bytes']), dict)
        roster = encode((('bytes32',) * 36, ('bytes32',) * 36),
            (tuple(r['id'] for r in rows), tuple(r['hash'] for r in rows)))
        self.assertEqual(keccak256(roster), '0xeb43f3b1e1761cd46710ac0508547d7c7249cc386022f8357a93eaec561f99e7')
        self.assertEqual(rows[20]['name'], 'RAW_BYTES')
        self.assertEqual(rows[21]['name'], 'STREAM_VIEW_PRESERVATION_SNAPSHOT_ABI_V1')
        self.assertEqual(rows[-1]['name'], 'STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1')

    def test_profiles_are_distinct_labels_not_invented_documents(self):
        self.assertEqual(t.PROFILE, '0x21732c7313db88e268ed694575cf4a5f1312714381af3ba63211b467f36701d6')
        self.assertEqual(t.BUNDLE_PROFILE, '0xe5a4353e3bd489518f0746b667e897da34f8a4b60b203ffc55b319a5195032a1')
        self.assertNotIn(t.PROFILE, {r['id'] for r in t.definitions()})
        self.assertNotIn(t.BUNDLE_PROFILE, {r['id'] for r in t.definitions()})
        self.assertEqual(len(t.STAGES), 12)
        self.assertEqual(tuple(t.STAGES.values()), tuple(range(12)))
        self.assertEqual(t.STAGES['definitions'], 7)
        self.assertEqual(t.STAGES['tokenOutputs'], 11)
        self.assertEqual(t.KIND_VALUES['EMPTY_PACKAGE_MEMBER'], 11)

    def test_fixed_widths_and_full_receipt_layout(self):
        expected = {'DEPENDENCIES':1344, 'PLAN':608, 'INVENTORY_PROGRESS':352,
            'CONTEXT':3744, 'TOKEN_PROGRESS':96, 'SEGMENT':128, 'ORIGINAL_INPUTS':256,
            'INVENTORY_BODY':608, 'EVIDENCE':736, 'BUNDLE_DEPENDENCIES':480,
            'BUNDLE_EVIDENCE':288, 'ADMISSION':1024, 'PROGRESS':256, 'REFRESH':128}
        for name, size in expected.items():
            with self.subTest(name=name):
                kind = getattr(t, name)
                self.assertEqual(width(kind), size)
                raw = encode((kind,), (sample(kind),))
                self.assertEqual(len(raw), size)
                self.assertEqual(decode((kind,), raw), (sample(kind),))
        self.assertEqual(t.CONTEXT[3], t.SNAPSHOT_RECEIPT)
        self.assertEqual(t.CONTEXT[4], t.REFERENCE_RECEIPT)
        self.assertEqual(t.INVENTORY_EVIDENCE, t.EVIDENCE)

    def test_dynamic_items_and_witnesses_preserve_exact_fields(self):
        for kind in (t.ITEM, t.WORK, t.RIGHTS, t.INTENT, t.INTENT_WAIVER, t.INTERVIEW):
            values = (sample(kind),)
            raw = encode((kind,), values)
            self.assertEqual(decode((kind,), raw, maximum=t.MAX_PAYLOAD), values)
            with self.assertRaisesRegex(MuseumError, 'noncanonical'):
                decode((kind,), raw + bytes(32), maximum=t.MAX_PAYLOAD)
        self.assertEqual(len(t.ITEM), 17)
        self.assertEqual(t.ITEM[7:10], ('bytes', 'string', 'uint64'))

    def test_narrow_field_and_bounded_array_fail_closed(self):
        item = list(sample(t.ITEM)); item[5] = 65536
        with self.assertRaisesRegex(MuseumError, 'overflow'):
            encode((t.ITEM,), (item,))
        progress = bytearray(encode((t.PROGRESS,), (sample(t.PROGRESS),)))
        progress[-32:] = (2).to_bytes(32, 'big')
        with self.assertRaisesRegex(MuseumError, 'bool'):
            decode((t.PROGRESS,), bytes(progress))
        hostile = (32).to_bytes(32, 'big') + (t.MAX_SEGMENT_ITEMS + 1).to_bytes(32, 'big')
        with self.assertRaisesRegex(MuseumError, 'array bound'):
            decode((t.ITEMS,), hostile)

    def test_event_and_interface_pins(self):
        self.assertEqual(t.INTERFACE_ID, '0xb8957a7d')
        self.assertEqual(t.BUNDLE_INTERFACE_ID, '0xafce9e0d')
        self.assertEqual(t.SELECTORS['supportsInterface'], '0x01ffc9a7')
        self.assertEqual(t.SELECTORS['appendRootAuthorization'], '0xa5837274')
        self.assertEqual(t.SELECTORS['appendInterview'], '0x4a983e5d')
        self.assertEqual(t.EVENTS['segment'], '0xb7de0e91c5e2fc46abd30dafd4bd824c172ee3ec48823b028f348c30a13193f8')
        self.assertEqual(t.EVENTS['completed'], '0xbcde2093195c8e7eec37afa4500297493f8956be9cff3008dce703d96ede5084')
        self.assertEqual(t.EVENT_INDEXED['segment'], ('id', 'index'))
        values = (1, sample(t.SEGMENT), (sample(t.ITEM),))
        self.assertEqual(decode(t.EVENT_DATA['segment'], encode(t.EVENT_DATA['segment'], values)), values)

    def test_domains_keep_shared_item_chains_but_separate_view_evidence(self):
        from . import object_inventory_source as original
        self.assertEqual((t.ITEM_DOMAIN, t.LINK_DOMAIN, t.SEGMENT_DOMAIN),
                         (original.ITEM_DOMAIN, original.LINK_DOMAIN, original.SEGMENT_DOMAIN))
        self.assertNotEqual(t.PLAN_DOMAIN, original.PLAN_DOMAIN)
        self.assertNotEqual(t.EVIDENCE_DOMAIN, original.EVIDENCE_DOMAIN)
        self.assertEqual(len(set(t.DOMAIN.values())), len(t.DOMAIN))
        for key, name in t.DOMAIN_NAMES.items():
            self.assertEqual(t.DOMAIN[key], schema_id(name))

    def test_view_structs_against_exact_native_source(self):
        source = pinned(INTERFACES + 'StreamViewPreservationRenderCriticalTypesV1.sol').decode()
        known = {'StreamFinalityScope':t.SCOPE, 'Inventory.Plan':t.INVENTORY_PROGRESS,
            'Inventory.Evidence':t.INVENTORY_BODY, 'Inventory.BundleEvidence':t.BUNDLE_BODY,
            'Snapshot.Receipt':t.SNAPSHOT_RECEIPT, 'Reference.Receipt':t.REFERENCE_RECEIPT,
            'StreamFinalityDescriptionEvidence':t.DESCRIPTIONS,
            'IStreamConservationRecordSelection.Selection':t.CONSERVATION}
        for native, kind in (('Plan',t.PLAN), ('TokenProgress',t.TOKEN_PROGRESS),
                             ('Context',t.CONTEXT), ('Evidence',t.EVIDENCE), ('BundleEvidence',t.BUNDLE_EVIDENCE)):
            self.assertEqual(native_descriptor(source,native,known), kind)
        self.assertEqual(tuple(name for _,name in struct_fields(source,'Context')),
            ('scope','subject','artistId','snapshot','referenceRender','descriptions','conservation',
             'interviewEvidenceHash','nativeHash','rootRecordHash','tokenInventoryHash','checkpointHash',
             'outputManifestRecord','adoptionRecord','viewId','payloadHash','sourceContextHash',
             'policyChainHash','outputRoot','manifestIndexHash','tokenCount'))

    def test_neutral_aliases_against_exact_native_source(self):
        source = pinned(INTERFACES + 'StreamPreservationInventoryTypes.sol').decode()
        known = {'Kind':'uint8','OriginalInputs':t.ORIGINAL_INPUTS}
        for native, kind in (('Item',t.ITEM), ('Segment',t.SEGMENT), ('Plan',t.INVENTORY_PROGRESS),
            ('OriginalInputs',t.ORIGINAL_INPUTS), ('Evidence',t.INVENTORY_BODY), ('BundleEvidence',t.BUNDLE_BODY)):
            self.assertEqual(native_descriptor(source,native,known), kind)
        source = pinned(INTERFACES + 'StreamRenderCriticalSourceTypes.sol').decode()
        self.assertEqual(native_descriptor(source,'Dependencies',{}),t.DEPENDENCIES)
        source = pinned(INTERFACES + 'StreamBundleArchiveTypes.sol').decode()
        known = {'Proof':t.PROOF,'StreamExternalArtifactTypes.Coverage':t.EXTERNAL_COVERAGE,
                 'StreamFinalityArtifactTypes.Coverage':t.ONCHAIN_COVERAGE}
        for native,kind in (('Dependencies',t.BUNDLE_DEPENDENCIES),('Proof',t.PROOF),
                            ('Admission',t.ADMISSION),('Progress',t.PROGRESS),('Refresh',t.REFRESH)):
            self.assertEqual(native_descriptor(source,native,known),kind)

    def test_whole_native_interface_surfaces_and_witness_layouts(self):
        for file, names in (('IStreamViewPreservationRenderCriticalInventoryV1.sol',t.FUNCTIONS),
                            ('IStreamViewPreservationBundleArchiveCoverageV1.sol',t.BUNDLE_INTERFACE_NAMES)):
            actual = re.findall(r'\bfunction\s+(\w+)\(',pinned(INTERFACES+file).decode())
            self.assertEqual(set(actual),set(names))
        for prefix,name in (('WORK','StreamWorkRecordTypes'),('RIGHTS','StreamRightsRecordTypes'),
                             ('CONSERVATION','StreamConservationRecordTypes')):
            src=pinned('smart-contracts/interfaces/stream/metadata/'+name+'.sol').decode()
            src=re.sub(r'//[^\n]*|/\*.*?\*/','',src,flags=re.S)
            structs=set(re.findall(r'\bstruct\s+(\w+)\s*\{',src))
            enums=set(re.findall(r'\benum\s+(\w+)\s*\{',src))
            for name in structs:
                fields=[]
                for kind,field in struct_fields(src,name):
                    base=kind.split('[')[0]; suffix=kind[len(base):]
                    base='uint8' if base in enums else prefix+'_'+base if base in structs else base
                    fields.append(base+suffix+' '+field)
                self.assertEqual(t.WITNESS_LAYOUTS[prefix+'_'+name],';'.join(fields))


if __name__ == '__main__':
    unittest.main()
