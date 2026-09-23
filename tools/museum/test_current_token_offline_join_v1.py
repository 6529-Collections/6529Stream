"""One original V4 replayed through current assessment and four native exports."""
import unittest
from unittest.mock import patch

from . import canonical_current_assessment_v2 as current
from . import canonical_object_dossier_v5 as reviewed
from . import canonical_native_inputs_v1 as native_inputs
from . import current_token_offline_join_v1 as joined
from . import native_iiif_v2 as iiif
from . import native_linked_art_v1 as linked_art
from . import native_multiformat_package_v2 as formats
from . import native_premis_v2 as premis
from . import native_work_lido_v1 as lido
from .canonical import MuseumError, dumps, keccak256
from . import test_canonical_current_assessment_v1 as fixture


class CurrentTokenOfflineJoinTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture.CurrentAssessmentTests.setUpClass()
        cls.base = fixture.CurrentAssessmentTests.base
        cls.native = {path.removeprefix('canonical/input/acquisition/inputs/'): raw
            for path, raw in cls.base.files
            if path.startswith('canonical/input/acquisition/inputs/')}
        cls.native_hash = keccak256(cls.native['manifest.json'])
        cls.assessment = current.compose(dict(fixture.CurrentAssessmentTests.result.files),
            fixture.CurrentAssessmentTests.result.manifest_hash, disclosure='public')
        cls.reviewed = reviewed.compose(dict(cls.base.files), cls.base.manifest_hash,
            disclosure='public')
        pin = cls.base.manifest_hash
        def plan(version, kind, **extra):
            return {'version': version, 'kind': kind, 'sourceManifestHash': pin,
                'selected': [], **extra}
        raw = dumps({'version': '2', 'sourceManifestHash': pin, 'adapters': {
            'linked-art': plan('1', linked_art.PLAN_KIND),
            'premis': plan('2', premis.PLAN_KIND, selectedRights=[]),
            'iiif': plan('2', iiif.PLAN_KIND),
            'lido': plan('1', lido.PLAN_KIND)}})
        with patch('socket.socket', side_effect=AssertionError('network forbidden')):
            cls.formats = formats.compose(dict(cls.base.files), pin, raw, keccak256(raw),
                disclosure='public')

    def test_pinned_original_survives_all_three_consumers(self):
        with patch('socket.socket', side_effect=AssertionError('network forbidden')):
            report = joined.check(self.native, self.native_hash,
                dict(self.base.files), self.base.manifest_hash,
                dict(self.assessment.files), self.assessment.manifest_hash,
                dict(self.formats.files), self.formats.manifest_hash,
                v5_files=dict(self.reviewed.files), v5_hash=self.reviewed.manifest_hash)
        self.assertEqual(report['originalRequirementRows'], '49')
        self.assertEqual(report['currentRequirementRows'], '49')
        self.assertEqual(report['originalFieldRows'], report['fourFormatFieldRows'])
        self.assertEqual(set(report['fourFormats']), set(formats.ADAPTERS))
        self.assertFalse(report['actualCurrentCaptureAcceptance'])

    def test_wrong_external_pin_refuses_offline_join(self):
        with self.assertRaises(MuseumError):
            joined.check(self.native, self.native_hash,
                dict(self.base.files), self.base.manifest_hash,
                dict(self.assessment.files), self.assessment.manifest_hash,
                dict(self.formats.files), '0x' + '11' * 32)

    def test_distinct_re_pinned_original_transport_cannot_join(self):
        metadata = {name: self.native['work/metadata/' + name]
            for name in native_inputs.METADATA_FILES}
        condition = {path.removeprefix('work/condition/'): raw
            for path, raw in self.native.items()
            if path.startswith('work/condition/')}
        other, pin = native_inputs.create(self.native['preservation/input.json'],
            self.native['work/evidence.json'] + b'\n', metadata,
            self.native['recovery/evidence.json'],
            condition_files=condition or None)
        with self.assertRaisesRegex(MuseumError, 'original V10 native input bytes differ'):
            joined.check(other, pin, dict(self.base.files), self.base.manifest_hash,
                dict(self.assessment.files), self.assessment.manifest_hash,
                dict(self.formats.files), self.formats.manifest_hash)


if __name__ == '__main__':
    unittest.main()
