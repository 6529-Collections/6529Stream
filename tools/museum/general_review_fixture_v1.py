"""Replay the local signed/curator General packet without a compiler or network."""
import gzip
import hashlib
from pathlib import Path

from .canonical import dumps, hex_bytes, keccak256, loads
from .chain_rpc import ReplayTransport
from .general_attestation_source import ARTIST, CURATORIAL
from .general_attestation_source_v2 import GeneralAttestationSourceV2
from .general_publication_v1 import GeneralPublicationAdapterV1
from .general_review_profile_v1 import GeneralSemanticReviewProfileV1
from .general_review_selection import replay
from .general_semantic_source_v2 import GeneralSemanticSourceV2
from .independent_wire import require

MAX_BYTES=64*1024*1024
BUNDLE=('anchor.json','general-transcript.json','general-source.json','publication-hints.json',
    'publication-transcript.json','publications.json','semantic-transcript.json','semantic-source.json',
    'selection.json','selection-result.json','graph.json','provenance.json','profile.json')
FILES=(*BUNDLE,'native-inputs.json','native-reuse-audit.json','deployment-evidence.json','cases.json')
FIXTURE=Path(__file__).parent/'fixtures/general-review-native-v1.json.gz'
FIXTURE_MANIFEST_HASH='0xe3e39b2982a44f0ff898a0479dca2ee4db91c791519aa182d76e042a40535b29'


def source_from(files,profile=None):
    general=GeneralAttestationSourceV2(files['anchor.json'],ReplayTransport(files['general-transcript.json'],
        keccak256(files['general-transcript.json'])),provenance='trusted_rpc')
    publication=GeneralPublicationAdapterV1(general,files['publication-hints.json'],ReplayTransport(
        files['publication-transcript.json'],keccak256(files['publication-transcript.json'])),provenance='trusted_rpc')
    return GeneralSemanticSourceV2(general,publication,ReplayTransport(files['semantic-transcript.json'],
        keccak256(files['semantic-transcript.json'])),profile=profile or GeneralSemanticReviewProfileV1())


def verify_capture(files,profile=None):
    require(type(files) is dict and set(files)==set(FILES) and all(type(v) is bytes and len(v)<=MAX_BYTES for v in files.values()),
        'General retained packet file set/bounds differ')
    profile=profile or GeneralSemanticReviewProfileV1()
    bundle={name:files[name] for name in BUNDLE}
    replay(bundle,keccak256(files['selection.json']),provenance='trusted_rpc',disclosure='public')
    anchor=loads(files['anchor.json']); evidence=loads(files['deployment-evidence.json'],maximum=MAX_BYTES)
    manifest=loads(files['native-inputs.json'],maximum=MAX_BYTES); audit=loads(files['native-reuse-audit.json'],maximum=MAX_BYTES)
    require(keccak256(files['deployment-evidence.json'])==anchor['deploymentEvidenceHash'], 'General deployment evidence pin differs')
    digest=hashlib.sha256(files['native-inputs.json']).hexdigest()
    require(audit['manifestSha256']==digest==evidence['nativeManifestSha256']
        and evidence['nativeReuseAuditHash']==keccak256(files['native-reuse-audit.json']), 'General native input joins differ')
    require(audit['status']=='QUALIFIED_HISTORICAL_INPUTS' and set(audit['products'])==set(manifest['products']), 'General historical input qualification differs')
    for name,row in evidence['artifacts'].items():
        require(name in manifest['products'] and all(row[k]==manifest['products'][name][k] for k in ('source','artifact','sha256')),
            'General deployed artifact manifest differs')
        require(0<int(row['runtimeBytes'])<=24576, 'General deployed artifact cap differs')
    boundary=evidence['boundaries']
    require(len(boundary)==1 and boundary[0]['contract']=='GeneralArtistBoundary'
        and boundary[0]['address']==anchor['artistRegistry']==anchor['artistAttribution']
        and boundary[0]['nativeArtistStatementsExecuted'] is False, 'General unused Artist boundary differs')
    require(evidence['curatorGrantRevokedAfterPublication'] is True, 'General historical grant control missing')
    originals=loads(files['general-source.json'],maximum=MAX_BYTES)
    require(len(originals['records'])==6 and len(originals['lanes'])==4, 'General complete original lane inventory differs')
    artist=next(r for r in originals['lanes'] if r['recordType']==ARTIST)
    require(artist['count']=='0' and artist['state']=='authenticated_empty', 'General native Artist lane must remain empty')
    curator=[r for r in originals['records'] if r['value'][3]==CURATORIAL]
    require(len(curator)==2 and all(r['receipt'][0]==evidence['curator'] and r['value'][0]==evidence['unsignedAttesterLabel']
        and r['receipt'][0]!=r['value'][0] and r['receipt'][17]=='1' for r in curator), 'General unsigned curator label/receipt control differs')
    cases=loads(files['cases.json'],maximum=MAX_BYTES)
    require(cases['profileHash']==profile.profile_hash and files['profile.json']==profile.profile_bytes
        and cases['actualArtistLaneExecuted'] is False and cases['actualWholeStack'] is False, 'General explicit capture scope differs')
    selection=loads(files['selection-result.json'],maximum=MAX_BYTES)
    require(len(selection['selected'])==1 and len(selection['selected'][0]['qualifyingReviews'])==2,
        'General selected signed/curator approvals differ')
    return {'status':'PASS','originalRecords':6,'nativeLaneCount':4,'signedAndCuratorApprovals':2,
        'originalSourcePublicationSelectionReplay':True,'typedUnusedArtistBoundary':True,
        'actualArtist':False,'currentWholeStack':False,'independentHumans':False,'consensusFinality':False}


def load_fixture(path=FIXTURE):
    path=Path(path); raw=path.read_bytes()
    manifest=path.with_suffix('').with_suffix('.manifest.json').read_bytes()
    require(keccak256(manifest)==FIXTURE_MANIFEST_HASH,'General fixture external manifest pin differs')
    pins=loads(manifest,maximum=1048576,canonical=True)
    require(hashlib.sha256(raw).hexdigest()==pins['gzipSha256'] and len(raw)<=MAX_BYTES,'General fixture compressed pin/bound differs')
    with gzip.open(path,'rb') as stream: expanded=stream.read(MAX_BYTES+1)
    require(len(expanded)<=MAX_BYTES and keccak256(expanded)==pins['payloadHash'],'General fixture expanded pin/bound differs')
    body=loads(expanded,maximum=MAX_BYTES,canonical=True)
    files={name:hex_bytes(value) for name,value in body.items()}
    require({name:keccak256(value) for name,value in files.items()}==pins['files'],'General fixture file pins differ')
    return files
