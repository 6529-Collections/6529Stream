"""Frozen 29-schema/22-support genesis registration expectations.

This copies the existing prospective inputs. It does not refresh their source
provenance or turn a proposed registration into an observed one. Verification
uses retained bytes and fixed version-local commitments, never today's schema
directory or an operator-selected list of required names.
"""
from dataclasses import dataclass
from pathlib import Path

from .canonical import MuseumError, dumps, keccak256, loads
from .independent_wire import require
from .object_dossier import _bounded, _ref
from .publication import KINDS, PublicationPlan

PROFILE = 'STREAM_MUSEUM_GENESIS_REGISTRY_PLAN_V1'
CATALOG_HASH = '0xa60f14576f45eea7dc6f844f2c4ec05b744a4301876e8e9280af548c7c4d8242'
ADMISSION_PLAN_HASH = '0x43666c1faaa380ef1815dfe8634597fd82533cf92c76fbbb2f88cfedaf35a4a2'
DOCUMENTS_HASH = '0x2fa1d0415cb9a754a67ae20c38dfe89b544033d3b34686987b2e95e0b9f78c73'
MAX_BYTES, MAX_FILES = 8 * 1024 * 1024, 64
QUALIFICATION = ('Exact existing prospective genesis inputs: 29 canonical schema names and 22 support '
    'documents. Their original source provenance and examples remain declarations in the catalog. '
    'This package verifies intended definition bytes, not source-code freshness, registration, '
    'governance execution, semantic conformance or institutional acceptance.')
PROFILE_BYTES = dumps({'name': PROFILE, 'version': '1', 'catalogHash': CATALOG_HASH,
    'admissionPlanHash': ADMISSION_PLAN_HASH, 'orderedDocumentsHash': DOCUMENTS_HASH,
    'canonicalSchemaCount': 29, 'supportDocumentCount': 22,
    'qualification': QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


@dataclass(frozen=True)
class Plan:
    files: tuple[tuple[str, bytes], ...]
    manifest: bytes
    documents: tuple[PublicationPlan, ...]
    canonical_names: tuple[str, ...]
    report: dict

    @property
    def manifest_hash(self):
        return keccak256(self.manifest)


def _limits(files):
    _bounded(files)
    require(len(files) <= MAX_FILES and sum(map(len, files.values())) <= MAX_BYTES,
        'genesis plan aggregate bound')


def _derive(originals):
    _limits(originals)
    require(keccak256(originals['catalog.json']) == CATALOG_HASH
        and keccak256(originals['admission-plan.json']) == ADMISSION_PLAN_HASH,
        'genesis plan frozen original commitments differ')
    catalog = loads(originals['catalog.json'], maximum=1048576, canonical=True)
    plan = loads(originals['admission-plan.json'], maximum=1048576, canonical=True)
    require(plan['catalogHash'] == CATALOG_HASH
        and keccak256(dumps(plan['documents'])) == DOCUMENTS_HASH,
        'genesis plan frozen document denominator differs')
    canonical_names = tuple(row['name'] for row in catalog['entries'])
    require(len(canonical_names) == len(set(canonical_names)) == 29
        and len(plan['documents']) == 51, 'genesis plan fixed counts differ')
    documents, expected, seen = [], {'catalog.json', 'admission-plan.json'}, set()
    for row in plan['documents']:
        path = 'definitions/' + row['documentId'][2:] + '.json'
        expected.add(path)
        raw, spec = originals[path], row['specification']
        require(row['documentId'] not in seen and set(row['dependsOn']) <= seen,
            'genesis plan duplicate or unordered dependency')
        seen.add(row['documentId'])
        document = PublicationPlan(spec['name'], tuple(KINDS)[int(spec['kind'])],
            spec['canonicalizationId'], spec['supersedesId'], spec['uri'], raw)
        metadata = document.metadata()
        require(all(row[key] == value for key, value in metadata.items()),
            'genesis plan original document bytes differ')
        documents.append(document)
    require(set(originals) == expected, 'genesis plan extra or omitted original file')
    require(set(canonical_names) <= {d.name for d in documents},
        'genesis plan canonical name denominator differs')
    report = {'profile': PROFILE, 'profileHash': PROFILE_HASH, 'catalogHash': CATALOG_HASH,
        'admissionPlanHash': ADMISSION_PLAN_HASH, 'documentsHash': DOCUMENTS_HASH,
        'canonicalSchemas': list(canonical_names), 'canonicalSchemaCount': 29,
        'supportDocumentCount': 22, 'totalDocuments': 51, 'registrationObserved': False,
        'qualification': QUALIFICATION}
    files = dict(originals) | {'profile.json': PROFILE_BYTES, 'report.json': dumps(report)}
    manifest = dumps({'profile': PROFILE, 'profileHash': PROFILE_HASH,
        'files': [_ref(path, raw) for path, raw in sorted(files.items())]})
    files['manifest.json'] = manifest
    _limits(files)
    return Plan(tuple(sorted(files.items())), manifest, tuple(documents), canonical_names, report)


def prepare(root=None):
    """Copy original checked-in prospective files; never regenerate old metadata."""
    root = Path(root) if root is not None else Path(__file__).resolve().parents[2]
    # Version-local byte copies survive later regeneration of the source catalog
    # (whose interpreter provenance may change without changing any definition).
    base = root / 'tools/museum/fixtures/genesis-registry-plan-v1'
    originals = {name: _read(base / name, 1048576) for name in ('catalog.json', 'admission-plan.json')}
    require(keccak256(originals['admission-plan.json']) == ADMISSION_PLAN_HASH,
        'genesis plan source revision differs; use an explicitly versioned plan')
    plan = loads(originals['admission-plan.json'], maximum=1048576, canonical=True)
    for row in plan['documents']:
        path = root / row['sourcePath']
        # All source paths come from the immutable, profile-pinned original plan.
        originals['definitions/' + row['documentId'][2:] + '.json'] = _read(path, 524288)
    return _derive(originals)


def _read(path, maximum):
    with path.open('rb') as file:
        raw = file.read(maximum + 1)
    require(len(raw) <= maximum, 'genesis plan source file bound')
    return raw


def admit(files, expected_hash):
    """Rebuild only from the frozen retained originals; external pin is mandatory."""
    try:
        _limits(files)
        require(keccak256(files['manifest.json']) == expected_hash,
            'genesis plan external manifest commitment differs')
        originals = {path: raw for path, raw in files.items()
            if path not in ('manifest.json', 'profile.json', 'report.json')}
        result = _derive(originals)
        require(dict(result.files) == files, 'genesis plan deterministic reconstruction differs')
        return result
    except MuseumError:
        raise
    except (KeyError, TypeError, ValueError, IndexError, OverflowError) as exc:
        raise MuseumError('malformed genesis registry plan') from exc
