import copy
import gzip
import hashlib
import json
import unittest

from tools.metadata import conservation_profile as p
from tools.metadata import conservation_language as lang


class ConservationProfileTest(unittest.TestCase):
    def sample(self, name='interview-vmq.json'):
        return copy.deepcopy(p.examples()[name])

    def valid(self, value, family=p.INTERVIEW, catalogs=None):
        return p.validate(p.canonical(value),family,catalogs)

    def bad(self,value,family=p.INTERVIEW,catalogs=None):
        with self.assertRaises(p.ConservationError): self.valid(value,family,catalogs)

    def catalog(self):
        return {'CONSERVATION_EXAMPLE_FORMATS_V1':p.canonical(self.sample('format-catalog.json'))}

    def test_all_seven_goldens_and_eight_definition_bytes(self):
        for name,raw in p.outputs().items(): self.assertEqual((p.ROOT/name).read_bytes(),raw)

    def test_all_named_intent_fields_required_and_no_implicit_interview(self):
        v=self.sample('intent-present.json')
        for key in v:
            c=copy.deepcopy(v);del c[key];self.bad(c,p.INTENT)
        for key in v['display']:
            c=copy.deepcopy(v);del c['display'][key];self.bad(c,p.INTENT)
        c=copy.deepcopy(v);c['display']['unlisted']=c['display']['scale'];self.bad(c,p.INTENT)

    def test_waiver_requires_its_own_statement_and_interview_entry(self):
        for name in ('intent-waiver.json','intent-waiver-present.json'):
            v=self.sample(name);self.valid(v,p.WAIVER)
            for key in ('waiverStatement','interview'):
                c=copy.deepcopy(v);del c[key];self.bad(c,p.WAIVER)
        v=self.sample('intent-waiver.json');v['interview']=None;self.bad(v,p.WAIVER)

    def test_present_exact_profile_schema_and_full_record_locator(self):
        for key in ('schemaId','profileHash','recordHash','chainId','core','host'):
            v=self.sample('intent-present.json');del v['interview']['record'][key];self.bad(v,p.INTENT)
        for key in ('schemaId','profileHash'):
            v=self.sample('intent-present.json');v['interview']['record'][key]='0x'+'12'*32;self.bad(v,p.INTENT)
        for val in ('0','01',str(1<<256),1):
            v=self.sample('intent-present.json');v['interview']['record']['chainId']=val;self.bad(v,p.INTENT)
        for val in ('0x'+'0'*40,'0x'+'AB'*20,'0x'+'ab'*19):
            v=self.sample('intent-present.json');v['interview']['record']['host']=val;self.bad(v,p.INTENT)

    def test_closed_present_and_waived_union(self):
        v=self.sample('intent-present.json');v['interview']['statement']=v['interview']['payload'];self.bad(v,p.INTENT)
        v=self.sample('intent-estate-waived.json');v['interview']['record']={};self.bad(v,p.INTENT)

    def test_exact_outer_profile_subject_predecessor_and_no_authority_flags(self):
        for name,family in [('interview-vmq.json',p.INTERVIEW),('intent-present.json',p.INTENT),('intent-waiver.json',p.WAIVER)]:
            for key in ('profileHash','subjectId'):
                v=self.sample(name);v[key]=p.ZERO;self.bad(v,family)
            v=self.sample(name);v['profileHash']='0x'+'12'*32;self.bad(v,family)
            v=self.sample(name);v['predecessor']=p.ZERO;self.bad(v,family)
            for key in ('authority','isArtist','finalized','archiveVerified'):
                v=self.sample(name);v[key]=True;self.bad(v,family)

    def test_artist_claim_generation_and_estate_classification(self):
        v=self.sample('intent-estate-waived.json');self.valid(v,p.INTENT)
        for val in ('0','01',str(1<<64),1):
            c=copy.deepcopy(v);c['artist']['bindingGeneration']=val;self.bad(c,p.INTENT)
        for val in ('current_authority','living_artist',True):
            c=copy.deepcopy(v);c['artist']['statementOrigin']=val;self.bad(c,p.INTENT)

    def test_all_six_reference_widths_and_no_digest_truth(self):
        for alg in range(1,7):
            for size in ((1,32,128) if alg in (4,5) else (32,)):
                v=self.sample();v['transcript']['content']['hash'].update(algorithm=alg,digest='0x'+'00'*size);self.valid(v)
            for size in ((0,129) if alg in (4,5) else (0,31,33,128)):
                v=self.sample();v['transcript']['content']['hash'].update(algorithm=alg,digest='0x'+'01'*size);self.bad(v)
        for alg in (0,7,True,'2'):
            v=self.sample();v['instrument']['document']['hash']['algorithm']=alg;self.bad(v)

    def test_reference_uri_and_canonicalization_exact(self):
        for val in ('http://bad','https://','https:///bad','ipfs://x\n','ar://x y'):
            v=self.sample();v['transcript']['content']['uri']=val;self.bad(v)
        v=self.sample();v['transcript']['content']['hash']['canonicalizationId']=p.ZERO;self.bad(v)
        v=self.sample();v['transcript']['content']['uri']='https://'+'x'*2040;self.valid(v)
        v['transcript']['content']['uri']+='x';self.bad(v)

    def test_instrument_and_participant_inactive_fields(self):
        v=self.sample();v['instrument']['name']='ignored';self.bad(v)
        v=self.sample('interview-derivative-av.json');del v['instrument']['name'];self.bad(v,catalogs=self.catalog())
        v=self.sample();v['participants'][0]['roleLabel']='ignored';self.bad(v)
        v=self.sample();v['participants'][0]['role']='other';self.bad(v)
        v['participants'][0]['roleLabel']='Explicit role';self.valid(v)
        v['participants']=[];self.bad(v)

    def test_gregorian_dates_and_no_date_normalization(self):
        for value in ('0001-01-01','2000-02-29','9999-12-31'):
            v=self.sample();v['interviewDate']=value;self.valid(v)
        for value in ('0000-01-01','1900-02-29','2024-02-30','2024-2-29','2024-02-29\n'):
            v=self.sample();v['interviewDate']=value;self.bad(v)

    def test_all_optional_captures_and_catalog_full_document(self):
        v=self.sample('interview-derivative-av.json');self.valid(v,catalogs=self.catalog())
        for c in v['captures']:
            self.assertIn(c['kind'],('audio','video'));self.assertEqual(c['payload']['format']['formatId'],'0x'+format(21,'064x'))
        v['captures'][0]['kind']='image';self.bad(v,catalogs=self.catalog())

    def test_catalog_unselected_entry_mutation_requires_full_commitment(self):
        v=self.sample('interview-derivative-av.json');catalog=self.sample('format-catalog.json')
        catalog['entries'][0]['mapping']['puid']='fmt/112';raw=p.canonical(catalog)
        self.bad(v,catalogs={'CONSERVATION_EXAMPLE_FORMATS_V1':raw})
        for c in v['captures']: c['payload']['format']['catalog']['documentHash']=p.digest(raw)
        self.valid(v,catalogs={'CONSERVATION_EXAMPLE_FORMATS_V1':raw})
        catalog['entries'][0]['mapping']['puid']='fmt/0';raw=p.canonical(catalog)
        for c in v['captures']: c['payload']['format']['catalog']['documentHash']=p.digest(raw)
        self.bad(v,catalogs={'CONSERVATION_EXAMPLE_FORMATS_V1':raw})

    def test_catalog_unique_selection_correspondence_and_unused_witness(self):
        v=self.sample('interview-derivative-av.json');catalog=self.sample('format-catalog.json')
        catalog['entries'].append(copy.deepcopy(catalog['entries'][1]));raw=p.canonical(catalog)
        for c in v['captures']:c['payload']['format']['catalog']['documentHash']=p.digest(raw)
        self.bad(v,catalogs={'CONSERVATION_EXAMPLE_FORMATS_V1':raw})
        v=self.sample('interview-derivative-av.json');v['captures'][0]['payload']['format']['mapping']['specification']['uri']='ipfs://different';self.bad(v,catalogs=self.catalog())
        self.bad(self.sample(),catalogs=self.catalog())
        v=self.sample('interview-derivative-av.json');self.bad(v,catalogs={})

    def test_pronom_identifier_and_closed_format_branches(self):
        for puid in ('fmt/0','fmt/01','FMT/111','fmt/111\n'):
            v=self.sample();f=v['transcript']['format'];f['puid']=puid;f['formatId']=p.digest(('PRONOM:'+puid).encode());self.bad(v)
        v=self.sample();v['transcript']['format']['formatId']='0x'+'12'*32;self.bad(v)
        v=self.sample();v['transcript']['format']['catalog']={};self.bad(v)

    def test_arrays_have_no_eight_item_cap_and_preserve_duplicates_order(self):
        v=self.sample();v['participants']=[copy.deepcopy(v['participants'][0]) for _ in range(10)]
        v['languages']=['EN','fr','x-test']*4;self.assertLess(len(p.canonical(v)),8192);self.assertEqual(self.valid(v),v)
        c=self.sample('format-catalog.json');c['entries']=[{'entryId':'0x'+format(i,'064x'),'mapping':{'kind':'pronom','puid':'fmt/111'}} for i in range(1,21)]
        self.valid(c,p.CATALOG)

    def test_exact_8192_and_overflow_no_truncation(self):
        v=self.sample();v['languages']=['en']
        # Expand the ordered language array using valid private-use tags, then pad one URI.
        while len(p.canonical(v))+4<6500: v['languages'].append('en')
        for ref in [v['transcript']['content'],v['instrument']['document']]:
            need=min(8192-len(p.canonical(v)),2048-len(ref['uri']))
            ref['uri']+='x'*need
        self.assertEqual(len(p.canonical(v)),8192);self.valid(v)
        v['languages'].append('en');self.bad(v)

    def test_utf8_no_normalization_and_json_ambiguity(self):
        v=self.sample('interview-derivative-av.json');self.valid(v,catalogs=self.catalog())
        v['instrument']['name']='é';a=p.canonical(v);v['instrument']['name']='e\u0301';self.assertNotEqual(a,p.canonical(v))
        v['instrument']['name']='🎨'*129;self.bad(v,catalogs=self.catalog())
        good=p.canonical(self.sample())
        for raw in (good+b' ',good[:-1]+b',"version":1}',good.replace(b'"version":1',b'"version":true'),
                    good.replace(b'"version":1',b'"version":1.0'),good.replace(b'"version":1',b'"version":NaN'),
                    good.replace(b'"EN-latn-US"',b'"\\ud800"')):
            with self.assertRaises(p.ConservationError):p.validate(raw,p.INTERVIEW)

    def test_acyclic_profile_hashes_and_present_interview_dependency(self):
        docs=p.documents()
        for f in p.FAMILIES:
            profile=json.loads(docs[p.PROFILES[f]])
            self.assertEqual(profile['schemaHash'],p.digest(docs[f]))
            self.assertNotIn(p.digest(docs[p.PROFILES[f]]),docs[f].decode())
        expected=p.digest(docs[p.PROFILES[p.INTERVIEW]])
        self.assertIn(expected,docs[p.INTENT].decode());self.assertIn(expected,docs[p.WAIVER].decode())


class ConservationLanguageProfileTest(unittest.TestCase):
    def test_original_standard_hashes_and_all_grandfathered(self):
        self.assertEqual(len(lang.original('rfc5646.txt',lang.RFC_SHA)),208592)
        self.assertEqual(len(lang.original('language-subtag-registry.txt',lang.REGISTRY_SHA)),731799)
        self.assertEqual(len(lang.GRANDFATHERED),26)
        for tag in lang.GRANDFATHERED:self.assertEqual(lang.require_valid(tag.upper()),tag.upper())

    def test_registered_classes_ranges_and_deprecated_still_valid(self):
        for tag in ('en','zh-cmn-Hans-CN','sl-rozaj-biske-1994','de-CH-1901','es-419','qaa-Qaaa-QM',
                    'qtz-Qabx-QZ','en-XA','en-XZ','iw','en-BU','x-a-B-12345678','en-u-ca-buddhist','EN-a-exact'):
            self.assertEqual(lang.require_valid(tag),tag)

    def test_syntax_validity_and_extension_meaning_distinct(self):
        for tag in ('zzzz','abcdefgh','en-abcde','en-Abcd','en-AB'):
            lang.parse(tag)
            with self.assertRaises(lang.LanguageError):lang.require_valid(tag)
        # Prefix suitability is a recommendation, and extension semantics a separate validation class.
        self.assertEqual(lang.require_valid('en-cmn'),'en-cmn')
        self.assertEqual(lang.require_valid('en-u-unknown'),'en-u-unknown')

    def test_case_insensitive_duplicates_but_private_repetition_allowed(self):
        for tag in ('sl-rozaj-ROZAJ','en-a-xx-A-yy','en--US','en-a','en-123456789','en-US\n','eñ','en-x'):
            with self.assertRaises(lang.LanguageError):lang.parse(tag)
        self.assertEqual(lang.require_valid('en-x-a-A'),'en-x-a-A')

    def test_language_required_and_registry_invalid_rejects_profile(self):
        v=p.examples()['interview-vmq.json'];v['languages']=[]
        with self.assertRaises(p.ConservationError):p.validate(p.canonical(v),p.INTERVIEW)
        v['languages']=['zzzz']
        with self.assertRaises(p.ConservationError):p.validate(p.canonical(v),p.INTERVIEW)


if __name__=='__main__':unittest.main()
