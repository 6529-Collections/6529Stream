import copy
import json
import unittest

from tools.metadata import owner_notice_profile as p


class OwnerNoticeProfileTest(unittest.TestCase):
    def sample(self, name='steward-institution.json'):
        return copy.deepcopy(p.examples()[name])

    def valid(self, value, family=p.STEWARD):
        return p.validate(p.canonical(value), family)

    def bad(self, value, family=p.STEWARD):
        with self.assertRaises(p.NoticeError):
            self.valid(value, family)

    def test_all_four_complete_examples_match_generated_bytes(self):
        for name, value in p.examples().items():
            family = p.STEWARD if name.startswith('steward') else p.RESPONSE
            self.assertEqual(self.valid(value,family),value)
        for name, raw in p.outputs().items():
            self.assertEqual((p.ROOT/name).read_bytes(),raw)

    def test_required_fields_and_no_authority_flags(self):
        for name in ('steward-institution.json','recovery-acknowledged.json'):
            v = self.sample(name)
            family = p.STEWARD if name.startswith('steward') else p.RESPONSE
            for key in v:
                changed = copy.deepcopy(v);del changed[key];self.bad(changed,family)
            for key in ('owner','veto','writeAuthority','standing','speaker','relayer'):
                changed=copy.deepcopy(v);changed[key]=True;self.bad(changed,family)

    def test_all_six_literal_algorithms_and_digest_shapes(self):
        for alg in (1,2,3,4,5,6):
            v=self.sample();h=v['steward']['identity']['hash'];h['algorithm']=alg
            sizes=(1,32,128) if alg in (4,5) else (32,)
            for size in sizes:
                h['digest']='0x'+'00'*size;self.valid(v)
            for size in (0,129) if alg in (4,5) else (0,31,33,128):
                h['digest']='0x'+'01'*size;self.bad(v)
        for alg in (0,7,65535,True,'1'):
            v=self.sample();v['steward']['identity']['hash']['algorithm']=alg;self.bad(v)

    def test_hash_canonicalization_and_exact_lowercase_bytes(self):
        for key in ('canonicalizationId','digest'):
            for val in ('0X'+'01'*32,'0x'+'AB'*32,'0x1'):
                v=self.sample();v['steward']['identity']['hash'][key]=val;self.bad(v)
        v=self.sample();v['steward']['identity']['hash']['canonicalizationId']=p.ZERO;self.bad(v)

    def test_contact_closed_variants_and_canonical_account_width(self):
        v=self.sample();a=v['contactEndpoints'][2];self.assertEqual(a['chainId'],str((1<<256)-1));self.valid(v)
        for chain in ('0','01',str(1<<256),1):
            v=self.sample();v['contactEndpoints'][2]['chainId']=chain;self.bad(v)
        for account in ('0x'+'00'*20,'0x'+'AB'*20,'0x'+'ab'*19):
            v=self.sample();v['contactEndpoints'][2]['account']=account;self.bad(v)
        for index,key,value in ((0,'account','0x'+'ab'*20),(1,'chainId','1'),(2,'uri','https://example.org')):
            v=self.sample();v['contactEndpoints'][index][key]=value;self.bad(v)

    def test_more_than_eight_contacts_and_evidence_fit_total(self):
        v=self.sample();v['contactEndpoints']=[{'kind':'https','uri':f'https://example.org/{i}'} for i in range(12)]
        self.assertLess(len(p.canonical(v)),8192);self.valid(v)
        r=self.sample('recovery-objected.json');r['evidenceReferences']=[copy.deepcopy(r['evidenceReferences'][0]) for _ in range(12)]
        self.assertLess(len(p.canonical(r)),8192);self.valid(r,p.RESPONSE)

    def test_contact_exact_tuple_duplicates_and_lexical_distinctions(self):
        v=self.sample();v['contactEndpoints'].append(copy.deepcopy(v['contactEndpoints'][0]));self.bad(v)
        v=self.sample();v['contactEndpoints']=[{'kind':'mailto','uri':'mailto:A@example.org'},{'kind':'mailto','uri':'mailto:a@example.org'}];self.valid(v)
        self.assertEqual(self.valid(v)['contactEndpoints'],v['contactEndpoints'])
        v['contactEndpoints']=[];self.bad(v)

    def test_mailbox_supported_grammar_and_full_consumption(self):
        for uri in ('mailto:a@example.org','mailto:A.a+stream_name-x@a-b.example','mailto:a@b'):
            v=self.sample();v['contactEndpoints']=[{'kind':'mailto','uri':uri}];self.valid(v)
        for uri in ('mailto:.a@example.org','mailto:a..b@example.org','mailto:a.@example.org','mailto:a@-example.org',
                    'mailto:a@example-.org','mailto:a@example..org','mailto:a@example.org\n','mailto:a@example.org?subject=x',
                    'mailto:a%40b@example.org','mailto:a@@example.org','mailto:ä@example.org','MAILTO:a@example.org'):
            v=self.sample();v['contactEndpoints']=[{'kind':'mailto','uri':uri}];self.bad(v)

    def test_content_uri_reference_is_not_retrieval(self):
        for uri in ('https://example.org/ref','ipfs://opaque','ar://opaque'):
            v=self.sample();v['steward']['identity']['uri']=uri;self.valid(v)
        for uri in ('https://','https:///bad','https://?bad','https://#bad','http://example.org','ipfs://','ar://x\n'):
            v=self.sample();v['steward']['identity']['uri']=uri;self.bad(v)

    def test_response_closed_values_and_nonzero_scheduled_identifiers(self):
        for response in ('acknowledged','objected'):
            v=self.sample('recovery-acknowledged.json');v['response']=response;self.valid(v,p.RESPONSE)
        for response in ('accepted','vetoed','unknown',0,False):
            v=self.sample('recovery-acknowledged.json');v['response']=response;self.bad(v,p.RESPONSE)
        for key in ('subjectId','profileHash','recoveryId','recoveryManifestHash'):
            v=self.sample('recovery-acknowledged.json');v[key]=p.ZERO;self.bad(v,p.RESPONSE)
        v=self.sample('recovery-acknowledged.json');v['grounds']='';self.bad(v,p.RESPONSE)

    def test_exact_utf8_lexicals_and_no_normalization(self):
        text='" \\ /\r\n\u0000\u0001 🎨 e\u0301'
        v=self.sample();v['steward']['name']=text;self.assertEqual(self.valid(v)['steward']['name'],text)
        v['steward']['name']='é';a=p.canonical(v);v['steward']['name']='e\u0301';b=p.canonical(v);self.assertNotEqual(a,b)
        v['steward']['name']='🎨'*129;self.bad(v)

    def test_exact_total_8192_and_8193(self):
        v=self.sample('recovery-acknowledged.json')
        reference={'hash':{'algorithm':2,'canonicalizationId':p.RAW,'digest':'0x'+'01'*32},'uri':'https://x'}
        v['grounds']='g'*2048;v['evidenceReferences']=[copy.deepcopy(reference) for _ in range(3)]
        # Fill the independently serialized total using URI fields, without exceeding each2048.
        for row in v['evidenceReferences']:
            remain=8192-len(p.canonical(v));row['uri']+='x'*min(2048-len(row['uri']),remain)
        self.assertEqual(len(p.canonical(v)),8192);self.valid(v,p.RESPONSE)
        row=next(r for r in v['evidenceReferences'] if len(r['uri'])<2048);row['uri']+='x'
        self.assertEqual(len(p.canonical(v)),8193);self.bad(v,p.RESPONSE)

    def test_noncanonical_duplicate_nonfinite_and_invalid_unicode(self):
        raw=p.canonical(self.sample())
        for changed in (b' '+raw,raw.replace(b'"version":1',b'"version":1,"version":1'),
                        raw.replace(b'"version":1',b'"version":true'),raw.replace(b'"version":1',b'"version":1.0'),raw.replace(b'"version":1',b'"version":NaN'),
                        raw.replace(b'Explicit institution',b'\\ud800'),raw.replace(b'Explicit institution',b'\xff')):
            with self.assertRaises(p.NoticeError):p.validate(changed,p.STEWARD)

    def test_predecessor_null_or_exact_reference_and_no_fake_absence(self):
        v=self.sample();self.assertIsNone(self.valid(v)['predecessor'])
        for predecessor in (p.ZERO,'',False,1):
            v=self.sample();v['predecessor']=predecessor;self.bad(v)
        for kind in ('institution','registrar_contact'):
            v=self.sample();v['steward']['kind']=kind;self.valid(v)
        for kind in ('owner','none','withdrawn'):
            v=self.sample();v['steward']['kind']=kind;self.bad(v)

    def test_no_actor_field_and_independent_same_payload(self):
        raw=p.canonical(self.sample('recovery-acknowledged.json'))
        self.assertEqual(p.validate(raw,p.RESPONSE),self.sample('recovery-acknowledged.json'))
        self.assertNotIn('owner',p.schema(p.RESPONSE)['properties'])
        self.assertNotIn('independent',p.schema(p.RESPONSE)['properties'])
        self.assertIn('canonical scheduled action ID',p.profile(p.RESPONSE)['meaning'])


if __name__=='__main__':unittest.main()
