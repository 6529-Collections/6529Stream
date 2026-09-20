"""Exact unchanged native membership embedded in new scoped-policy evidence."""
from copy import deepcopy
import socket
import unittest
from unittest.mock import patch

from . import scoped_policy_membership_v2 as w
from .canonical import MuseumError, keccak256
from .chain_abi import encode
from .independent_wire import ZERO
from .native_finality_wire import from_json
from .scoped_static_types import MEMBERSHIP_FACTS, SCOPE
from .test_scoped_static_snapshot_wire import supplied, ReadHarness as OriginalHarness, H


class ReadHarness(w.ScopedPolicyMembershipReads, OriginalHarness):
    pass


def vector(scope=2,count=3):
    b,c,g,s=supplied(scope,count)
    return b['membership'],c,g,s[0]


class ScopedPolicyMembershipTests(unittest.TestCase):
    def test_original_three_scope_denominators_and_burn_observation(self):
        with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
            for scope,count in ((1,1),(2,3),(3,300)):
                with self.subTest(scope=scope):
                    m,c,g,s=vector(scope,count)
                    original=deepcopy(m['facts'])
                    before=w.validate(m,c,g,s,original,m['tokens'])
                    m['identities'][0][3]=True;m['lifecycles'][0]='3'
                    after=w.validate(m,c,g,s,original,m['tokens'])
                    self.assertEqual(before['facts'],after['facts'])
                    self.assertFalse(before['identityObservations'][0]['burned'])
                    self.assertTrue(after['identityObservations'][0]['burned'])
                    self.assertFalse(after['claims']['historicalBurnStateReconstructed'])
                    self.assertEqual(after['facts'][6:],['0',ZERO])
                    self.assertEqual(len(w.expected_events(m,c,g,s)),0 if scope==1 else 3+len(m['progressHistory']))

    def test_exact_original_definitions_and_token_hash(self):
        self.assertEqual([len(d['bytes']) for d in w.definitions()],[2047,1309])
        m,c,g,s=vector(1,1)
        self.assertEqual(m['facts'][4],keccak256(encode(('uint256',),(int(s[2]),))))
        self.assertIsNone(m['publication'])
        m['facts'][4]=ZERO
        with self.assertRaisesRegex(MuseumError,'TOKEN membership'): w.validate(m,c,g,s,m['facts'],m['tokens'])

    def test_collection_prefix_cannot_enter_scoped_commitment(self):
        m,c,g,s=vector();m['facts'][6:]=['3',H('collection prefix')]
        m['facts'][5]=w.original.membership_hash(from_json(MEMBERSHIP_FACTS,m['facts']),from_json(SCOPE,s),c,g)
        with self.assertRaisesRegex(MuseumError,'facts/count'): w.validate(m,c,g,s,m['facts'],m['tokens'])

    def test_original_facts_and_output_row_denominator_are_exact(self):
        m,c,g,s=vector();original=deepcopy(m['facts']);original[5]=H('different original')
        with self.assertRaisesRegex(MuseumError,'original membership facts differ'): w.validate(m,c,g,s,original,m['tokens'])
        tokens=list(reversed(m['tokens']))
        with self.assertRaisesRegex(MuseumError,'output membership differs'): w.validate(m,c,g,s,m['facts'],tokens)
        with self.assertRaisesRegex(MuseumError,'output member denominator'): w.validate(m,c,g,s,m['facts'],tokens[:-1])

    def test_prepared_and_inconsistent_burn_never_count(self):
        for lifecycle,burned in (('1',False),('2',True),('3',False)):
            m,c,g,s=vector();m['lifecycles'][0]=lifecycle;m['identities'][0][3]=burned
            with self.assertRaisesRegex(MuseumError,'identity/lifecycle'): w.validate(m,c,g,s,m['facts'],m['tokens'])
        m,c,g,s=vector();m['inventoryTokens'][0]='999'
        with self.assertRaisesRegex(MuseumError,'serial lookup'): w.validate(m,c,g,s,m['facts'],m['tokens'])

    def test_metadata_authority_definition_and_carrier_correspondence(self):
        for field,value in ((2,'1'),(7,H('other definition'))):
            m,c,g,s=vector();m['publication'][7][field]=value
            with self.assertRaisesRegex(MuseumError,'authority/definitions'): w.validate(m,c,g,s,m['facts'],m['tokens'])
        m,c,g,s=vector();m['parts'][0]['runtime']+='00'
        with self.assertRaisesRegex(MuseumError,'carrier bytes/hash'): w.validate(m,c,g,s,m['facts'],m['tokens'])

    def test_full_progress_partition_and_scope_identity(self):
        m,c,g,s=vector(3,300);m['progressHistory']=m['progressHistory'][:-1]
        with self.assertRaisesRegex(MuseumError,'progress incomplete'): w.validate(m,c,g,s,m['facts'],m['tokens'])
        m,c,g,s=vector();s[3]=H('different scope')
        with self.assertRaises(MuseumError): w.validate(m,c,g,s,m['facts'],m['tokens'])
        for kind in ('0','4'):
            m,c,g,s=vector();s[0]=kind
            with self.assertRaisesRegex(MuseumError,'scope unsupported'): w.validate(m,c,g,s,m['facts'],m['tokens'])

    def test_finite_bound_precedes_source_calls(self):
        m,c,g,s=vector(2,819)
        with self.assertRaisesRegex(MuseumError,'membership bound'): w.validate(m,c,g,s,m['facts'],m['tokens'])
        f=ReadHarness(supplied(2,819))
        with self.assertRaisesRegex(MuseumError,'read bound'): f._membership(f.s[0],f.b['membership']['facts'],f.b['membership']['tokens'])
        self.assertEqual(f.requested,[])

    def test_original_getter_roundtrip_all_scopes_and_no_current_selection(self):
        for kind,count in ((1,1),(2,3),(3,300)):
            f=ReadHarness(supplied(kind,count));m=f.b['membership']
            with patch.object(socket,'socket',side_effect=AssertionError('network forbidden')):
                result=f._membership(f.s[0],m['facts'],m['tokens'])
            self.assertEqual(result,m)
            self.assertFalse(any('requireCurrent' in q or 'requireCompleteCollection' in q or 'requireScopeMembership' in q for q in f.requested))


if __name__=='__main__': unittest.main()
