"""Pure typed projections; no fixture claims native execution or publication."""
import unittest

from tools.metadata import conservation_profile as cp
from . import view_preservation_inventory_references_v1 as r
from . import view_preservation_inventory_types_v1 as t
from .canonical import dumps, keccak256, schema_id, loads
from .chain_abi import Array, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .metadata_rights_source import PROFILE_HASH as RIGHTS_PROFILE


def h(n):return '0x'+format(n,'064x')
def a(n):return '0x'+format(n,'040x')


def zero(kind):
    if isinstance(kind,Array):return ()
    if isinstance(kind,tuple):return tuple(zero(k) for k in kind)
    if kind=='address':return ZERO_ADDRESS
    if kind=='string':return ''
    if kind=='bytes':return b''
    if kind=='bool':return False
    if kind.startswith('uint'):return 0
    return '0x'+'00'*int(kind[5:])


def witness(name,**values):
    fields=[field.split() for field in t.WITNESS_LAYOUTS[name].split(';')]
    return tuple(values.pop(key,zero(t._witness_type(kind))) for kind,key in fields)


def ref(algorithm=1,digest=None):
    return (algorithm,r.RAW,bytes.fromhex('ab'*32) if digest is None else digest,'ipfs://resource')


def entry(present=False):
    if not present:return witness('CONSERVATION_InterviewEntry',status=1,waiverStatement=ref())
    record=(31337,a(1),a(2),h(3),schema_id(cp.INTERVIEW),keccak256(dumps(cp.profile(cp.INTERVIEW))),ref())
    return witness('CONSERVATION_InterviewEntry',record=record)


def intent(waiver=False,present=False):
    family=cp.WAIVER if waiver else cp.INTENT
    common=dict(subjectId=h(1),profileHash=keccak256(dumps(cp.profile(family))),artist=(h(2),1,h(3),0),interview=entry(present))
    if waiver:return witness('CONSERVATION_IntentWaiver',**common,waiverStatement=ref())
    return witness('CONSERVATION_Intent',**common,display=tuple(ref(i) for i in range(1,7)),
        variabilityTolerances=ref(),dependencyAging=ref(),significantProperties=ref())


def interview(catalog=False):
    fmt=(0,schema_id('PRONOM:fmt/111'),'fmt/111',('',(),ZERO))
    if catalog:
        fmt=(1,h(10),'',('TEST_FORMATS',((h(10),0,'fmt/111',zero(t._witness_type('CONSERVATION_Reference'))),
            (h(11),1,'',ref(5,b'\x00\xff'))),h(10)))
    payload=(ref(),fmt)
    return witness('CONSERVATION_Interview',subjectId=h(1),profileHash=keccak256(dumps(cp.profile(cp.INTERVIEW))),
        instrument=(0,'',ref()),participants=((0,'',ref()),(2,'Conservator',ref(6))),interviewDate=20240229,
        languages=('en','i-klingon','x-exact'),transcript=payload,captures=((0,payload),(1,payload)))


def work(catalog=False):
    fmt=(0,ZERO,'',('',(),ZERO))
    if catalog:fmt=(2,h(10),'',('WORK_FORMATS',((h(10),0,'fmt/111',('',ZERO)),(h(11),1,'',('ipfs://spec',h(12)))),h(10)))
    full=witness('WORK_FullDescription',title='Exact "title" 🎨',creator=(1,ZERO,0,ZERO,'Named artist'),
        creation=(1,20240229,20240301),medium='Digital',format=fmt,
        measurements=(0,True,1920,1080,True,(16,9),True,(1,24)),edition=(1,1,9,''),creditLine='Credit',
        hasInscription=True,inscription='Inscribed',alternateTitles=('Alternate',),
        languageVariants=((5,0,'en','Other'),),authorityReferences=((0,2,'Q123'),))
    return witness('WORK_Description',subjectId=h(1),profileHash=h(2),full=full)


def rights():
    doc=(True,'https://example.org/license',h(4))
    grants=[(0,(0,'',(False,'',ZERO)),'') for _ in range(6)]
    grants[0]=(2,(1,'Conditions',(False,'',ZERO)),'')
    grants[5]=(3,(2,'',doc),'Extension')
    return witness('RIGHTS_Statement',subjectId=h(1),profileHash=RIGHTS_PROFILE,basis=5,
        licensor=(2,ZERO,'Institution',ZERO_ADDRESS,h(4)),grants=tuple(grants),startDate=20240229,
        endDate=20240301,instrument=doc,hasAiTrainingPermission=True,aiTrainingPermission=2)


class TypedReferenceTests(unittest.TestCase):
    def derive(self,family,value):
        raw=getattr(r,'serialize_'+family)(value)
        typed,actual,rows=getattr(r,'derive_'+family)(a(1),h(1),keccak256(raw),value)
        self.assertEqual(raw,actual);self.assertEqual(typed,value)
        return loads(raw),rows

    def test_work_exact_literal_and_complete_unselected_catalog(self):
        value,rows=self.derive('work',work(True))
        expected={'subjectId':h(1),'profileHash':h(2),'predecessor':None,'version':1,'form':'full',
            'title':'Exact "title" 🎨','creator':{'kind':'named','name':'Named artist'},
            'creation':{'kind':'range','start':'2024-02-29','end':'2024-03-01'},'medium':'Digital',
            'measurements':{'kind':'measured','pixels':{'width':'1920','height':'1080','unit':'pixels'},
                'aspectRatio':{'numerator':'16','denominator':'9'},'durationSeconds':{'numerator':'1','denominator':'24'}},
            'edition':{'kind':'serial','number':'1','total':'9'},'creditLine':'Credit','inscription':'Inscribed',
            'alternateTitles':['Alternate'],'languageVariants':[{'field':'alternateTitle','alternateTitleIndex':'0','language':'en','value':'Other'}],
            'authorityReferences':[{'role':'creator','authority':'wikidata','identifier':'Q123'}], 'format':value['format']}
        self.assertEqual(value,expected)
        self.assertEqual(len(rows),2);self.assertEqual(rows[0][0],3);self.assertEqual(rows[1][4],1)
        self.assertEqual(rows[1][7],bytes.fromhex(h(12)[2:]));self.assertEqual(rows[1][1],schema_id('WORK_FORMAT_SPECIFICATION'))
        self.assertEqual(rows[0][12],schema_id('WORK_FORMATS'))

    def test_work_absent_and_inactive_arrays(self):
        v=witness('WORK_Description',subjectId=h(1),profileHash=h(2),form=1,absence=('Documented absence',20240229))
        value,rows=self.derive('work',v);self.assertEqual(rows,());self.assertEqual(value['absence']['date'],'2024-02-29')
        changed=list(v);full=list(v[4]);full[10]=('',);changed[4]=tuple(full)
        with self.assertRaises(ValueError):r.serialize_work(changed)

    def test_rights_six_ordered_grants_instrument_and_condition(self):
        value,rows=self.derive('rights',rights())
        self.assertEqual(value['basis'],'contract');self.assertEqual(value['AI_TRAINING_PERMISSION'],'granted_with_conditions')
        self.assertEqual([(row[1],row[4]) for row in rows],[(schema_id('RIGHTS_INSTRUMENT'),0),(schema_id('RIGHTS_USE_CONDITION'),5)])
        self.assertEqual(len(value['grants']),6)
        changed=list(rights());changed[10]=1
        with self.assertRaises(ValueError):r.serialize_rights(changed)

    def test_intent_preserves_algorithms_and_locator_provenance(self):
        value,rows=self.derive('intent',intent(present=True))
        self.assertEqual(len(rows),10);self.assertEqual([row[5] for row in rows[:6]],list(range(1,7)))
        self.assertEqual(rows[9][10],schema_id(cp.INTERVIEW))
        self.assertEqual(rows[9][16],keccak256(encode(('uint256','address','address','bytes32','bytes32'),
            (31337,a(1),a(2),h(3),keccak256(dumps(cp.profile(cp.INTERVIEW)))))))
        self.assertEqual(value['interview']['kind'],'present')

    def test_waiver_explicit_interview_waiver(self):
        value,rows=self.derive('waiver',intent(waiver=True))
        self.assertEqual([row[1] for row in rows],[schema_id('ARTIST_INTENT_WAIVER'),schema_id('INTERVIEW_WAIVER')])
        self.assertEqual(value['interview']['kind'],'interview_waived')

    def test_interview_all_catalog_occurrences_and_captures(self):
        value,rows=self.derive('interview',interview(True))
        self.assertEqual(len(rows),12)
        catalogs=[row for row in rows if row[0]==3]
        self.assertEqual([row[4] for row in catalogs],[0,1,2])
        specs=[row for row in rows if row[1]==schema_id('INTERVIEW_FORMAT_SPECIFICATION')]
        self.assertEqual([row[7] for row in specs],[b'\x00\xff']*3)
        self.assertEqual(len({row[16] for row in specs}),3)
        self.assertEqual([c['kind'] for c in value['captures']],['audio','video'])

    def test_payload_pin_rejects_other_valid_witness(self):
        for family,v in [('work',work()),('rights',rights()),('intent',intent()),('waiver',intent(True)),('interview',interview())]:
            with self.subTest(family=family),self.assertRaises(ValueError):getattr(r,'derive_'+family)(a(1),h(1),h(99),v)

    def test_inactive_union_fields_reject(self):
        v=list(intent());e=list(v[-1]);record=list(e[1]);record[0]=1;e[1]=tuple(record);v[-1]=tuple(e)
        with self.assertRaises(ValueError):r.serialize_intent(v)
        v=list(interview());v[3]=(0,'hidden',ref())
        with self.assertRaises(ValueError):r.serialize_interview(v)
        v=list(work());f=list(v[4]);f[8]=False;v[4]=tuple(f)
        with self.assertRaises(ValueError):r.serialize_work(v)

    def test_invalid_dates_ranges_catalog_duplicates_and_digest_width(self):
        v=list(rights());v[5]=20230229
        with self.assertRaises(ValueError):r.serialize_rights(v)
        v=list(intent());display=list(v[4]);display[0]=ref(1,b'\x01');v[4]=tuple(display)
        with self.assertRaises(ValueError):r.serialize_intent(v)
        v=list(interview(True));p=list(v[7]);f=list(p[1]);c=list(f[3]);c[1]=(c[1][0],c[1][0]);f[3]=tuple(c);p[1]=tuple(f);v[7]=tuple(p)
        with self.assertRaises(ValueError):r.serialize_interview(v)

    def test_conservation_registry_validation_is_explicit_consumer_limit(self):
        v=list(interview());v[6]=('zz',)
        with self.assertRaises(ValueError):r.serialize_interview(v)


if __name__=='__main__':unittest.main()
