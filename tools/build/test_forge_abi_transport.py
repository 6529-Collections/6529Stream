"""Foundry top-level ABI serialization tests; no compiler or EVM invocation."""
import copy
import unittest
from tools.build import scoped_standard_json as scoped
from tools.build.test_scoped_standard_json import fixture


class ForgeAbiTransportTests(unittest.TestCase):
    def setUp(self):
        self.abi = [
            {'type':'error', 'name':'Failure', 'inputs':[{'name':'value', 'type':'uint256'}]},
            {'type':'function', 'name':'read', 'inputs':[{'name':'key', 'type':'uint256'}, {'name':'owner', 'type':'address'}],
             'outputs':[{'name':'a', 'type':'uint256'}, {'name':'b', 'type':'address'}], 'stateMutability':'view'},
        ]

    def test_only_top_level_permutation_is_recorded_without_mutation(self):
        original = copy.deepcopy(self.abi)
        swapped = list(reversed(self.abi))
        changes = scoped.forge_abi_transport(self.abi, swapped)
        self.assertEqual(len(changes), 1)
        self.assertIn(scoped.sha(scoped.canonical(self.abi)), changes[0])
        self.assertIn(scoped.sha(scoped.canonical(swapped)), changes[0])
        self.assertEqual(self.abi, original)
        self.assertEqual(scoped.forge_abi_transport(self.abi, original), [])

    def test_nested_order_fields_types_missing_extra_duplicates_refuse(self):
        for kind in ('input_order','output_order','name','type','mutability','missing','extra','duplicate'):
            changed = copy.deepcopy(self.abi)
            if kind == 'input_order':changed[1]['inputs'].reverse()
            elif kind == 'output_order':changed[1]['outputs'].reverse()
            elif kind == 'name':changed[1]['name']='different'
            elif kind == 'type':changed[0]['inputs'][0]['type']='bytes32'
            elif kind == 'mutability':changed[1]['stateMutability']='pure'
            elif kind == 'missing':changed.pop()
            elif kind == 'extra':changed[0]['new']=False
            else:changed.append(copy.deepcopy(changed[0]))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                scoped.forge_abi_transport(self.abi,changed)

    def test_duplicate_counts_are_preserved_and_json_types_remain_exact(self):
        original = self.abi + [self.abi[0]]
        self.assertEqual(len(scoped.forge_abi_transport(original,original[1:] + original[:1])), 1)
        with self.assertRaises(ValueError):scoped.forge_abi_transport(original,self.abi + [self.abi[1]])
        for a,b in ((False,0),(0,0.0)):
            with self.subTest(a=a,b=b),self.assertRaises(ValueError):
                scoped.forge_abi_transport([{'test':a}],[{'test':b}])

    def test_missing_or_nonarray_abi_refuses(self):
        for value in (None,{},''):
            with self.subTest(value=value),self.assertRaises(ValueError):
                scoped.forge_abi_transport([],value)

    def test_full_output_records_permutation_and_only_empty_selector_omission(self):
        _,_,_,_,native = fixture()
        item = native['contracts']['Owner.sol']['Owner']
        item['abi']=copy.deepcopy(self.abi)
        item['evm']['methodIdentifiers']={}
        serialized = copy.deepcopy(native)
        target = serialized['contracts']['Owner.sol']['Owner']
        target['abi'].reverse()
        del target['evm']['methodIdentifiers']
        before = copy.deepcopy(native)
        changes = scoped.forge_output_transport(native,serialized)
        self.assertEqual(len(changes),2)
        self.assertEqual(native,before)
        item['evm']['methodIdentifiers']={'read(uint256,address)':'12345678'}
        with self.assertRaises(ValueError):scoped.forge_output_transport(native,serialized)


if __name__ == '__main__':
    unittest.main()
