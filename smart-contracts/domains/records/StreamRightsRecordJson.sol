// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRecordJson.sol";
import "../../interfaces/stream/metadata/StreamRightsRecordTypes.sol";

/// @notice Complete closed rights-record serialization with exact-byte witness verification.
/// @dev A pure interpretation primitive. Registry pins, original publisher, current selection,
///      lineage and instrument availability must be joined by an authenticated consumer.
library StreamRightsRecordJson {
    error InvalidRightsWitness();

    function serialize(StreamRightsRecordTypes.Statement memory s)
        public
        pure
        returns (bytes memory)
    {
        if (
            s.subjectId == 0 || s.profileHash == 0
                || s.licensor.instrumentDigest != s.instrument.digest
        ) revert InvalidRightsWitness();
        string memory end;
        if (s.openEnd) {
            if (s.endDate != 0) revert InvalidRightsWitness();
            end = "null";
        } else {
            if (s.endDate < s.startDate) revert InvalidRightsWitness();
            end = StreamRecordJson.date(s.endDate);
        }
        string memory ai = "";
        if (s.hasAiTrainingPermission) {
            if (s.aiTrainingPermission != s.grants.aiTraining.status) {
                revert InvalidRightsWitness();
            }
            ai = string.concat('"AI_TRAINING_PERMISSION":', _status(s.aiTrainingPermission), ",");
        } else if (s.aiTrainingPermission != StreamRightsRecordTypes.Status.UNSPECIFIED) {
            revert InvalidRightsWitness();
        }
        string memory result = string.concat("{", ai, '"basis":', _basis(s.basis));
        result = string.concat(
            result,
            ',"effectiveDates":{"end":',
            end,
            ',"start":',
            StreamRecordJson.date(s.startDate),
            "}"
        );
        result = string.concat(result, ',"grants":', _grants(s.grants));
        result = string.concat(
            result, ',"instrument":', _document(s.instrument), ',"licensor":', _licensor(s.licensor)
        );
        result = string.concat(
            result,
            ',"predecessor":',
            s.predecessor == 0 ? "null" : StreamRecordJson.hexValue(s.predecessor)
        );
        result = string.concat(
            result,
            ',"profileHash":',
            StreamRecordJson.hexValue(s.profileHash),
            ',"subjectId":',
            StreamRecordJson.hexValue(s.subjectId),
            ',"version":1}'
        );
        if (bytes(result).length > 8192) revert InvalidRightsWitness();
        return bytes(result);
    }

    function requireExact(StreamRightsRecordTypes.Statement memory witness, bytes memory stored)
        public
        pure
        returns (bytes32)
    {
        return StreamRecordJson.requirePayload(serialize(witness), stored);
    }

    function _grants(StreamRightsRecordTypes.Grants memory g) private pure returns (string memory) {
        string memory first = string.concat(
            '{"ai_training":',
            _grant(g.aiTraining),
            ',"derivative":',
            _grant(g.derivative),
            ',"exhibition":',
            _grant(g.exhibition)
        );
        return string.concat(
            first,
            ',"print":',
            _grant(g.print),
            ',"publication":',
            _grant(g.publication),
            ',"reproduction":',
            _grant(g.reproduction),
            "}"
        );
    }

    function _grant(StreamRightsRecordTypes.Grant memory g) private pure returns (string memory) {
        if (
            g.status == StreamRightsRecordTypes.Status.GRANTED_WITH_CONDITIONS
                && g.conditions.kind == StreamRightsRecordTypes.ConditionKind.NONE
        ) revert InvalidRightsWitness();
        return string.concat(
            '{"conditions":',
            _conditions(g.conditions),
            ',"extension":',
            StreamRecordJson.quote(g.extension, 512, true),
            ',"status":',
            _status(g.status),
            "}"
        );
    }

    function _conditions(StreamRightsRecordTypes.Conditions memory c)
        private
        pure
        returns (string memory)
    {
        if (c.kind == StreamRightsRecordTypes.ConditionKind.DOCUMENT) {
            if (bytes(c.text).length != 0 || !c.document.exists) revert InvalidRightsWitness();
            return string.concat('{"document":', _document(c.document), ',"kind":"document"}');
        }
        _emptyDocument(c.document);
        if (c.kind == StreamRightsRecordTypes.ConditionKind.TEXT) {
            return string.concat(
                '{"kind":"text","text":', StreamRecordJson.quote(c.text, 1024, false), "}"
            );
        }
        if (bytes(c.text).length != 0) revert InvalidRightsWitness();
        return "null";
    }

    function _document(StreamRightsRecordTypes.Document memory d)
        private
        pure
        returns (string memory)
    {
        if (!d.exists) {
            _emptyDocument(d);
            return "null";
        }
        if (d.digest == 0) revert InvalidRightsWitness();
        StreamMetadataRenderer.requireValidUtf8ContentUri("rightsDocument", d.uri, 2048, false);
        return string.concat(
            '{"hash":{"algorithm":1,"canonicalizationId":',
            StreamRecordJson.hexValue(keccak256("RAW_BYTES")),
            ',"digest":',
            StreamRecordJson.hexValue(d.digest),
            '},"uri":',
            StreamRecordJson.quote(d.uri, 2048, false),
            "}"
        );
    }

    function _emptyDocument(StreamRightsRecordTypes.Document memory d) private pure {
        if (d.exists || bytes(d.uri).length != 0 || d.digest != 0) revert InvalidRightsWitness();
    }

    function _licensor(StreamRightsRecordTypes.Licensor memory l)
        private
        pure
        returns (string memory)
    {
        string memory identity;
        if (l.kind == StreamRightsRecordTypes.LicensorKind.ARTIST) {
            if (l.artistId == 0 || l.account != address(0) || bytes(l.name).length != 0) {
                revert InvalidRightsWitness();
            }
            identity = string.concat(
                '{"artistId":', StreamRecordJson.hexValue(l.artistId), ',"kind":"artist"}'
            );
        } else if (l.kind == StreamRightsRecordTypes.LicensorKind.ACCOUNT) {
            if (l.artistId != 0 || bytes(l.name).length != 0) revert InvalidRightsWitness();
            identity = string.concat(
                '{"address":', StreamRecordJson.account(l.account), ',"kind":"address"}'
            );
        } else {
            if (l.artistId != 0 || l.account != address(0)) revert InvalidRightsWitness();
            identity = string.concat(
                '{"kind":',
                l.kind == StreamRightsRecordTypes.LicensorKind.ESTATE
                    ? '"estate"'
                    : '"institution"',
                ',"name":',
                StreamRecordJson.quote(l.name, 512, false),
                "}"
            );
        }
        return string.concat(
            '{"identity":',
            identity,
            ',"instrumentDigest":',
            l.instrumentDigest == 0 ? "null" : StreamRecordJson.hexValue(l.instrumentDigest),
            "}"
        );
    }

    function _basis(StreamRightsRecordTypes.Basis b) private pure returns (string memory) {
        if (b == StreamRightsRecordTypes.Basis.COPYRIGHT) return '"copyright"';
        if (b == StreamRightsRecordTypes.Basis.LICENSE) return '"license"';
        if (b == StreamRightsRecordTypes.Basis.STATUTE) return '"statute"';
        if (b == StreamRightsRecordTypes.Basis.PUBLIC_DOMAIN) return '"public_domain"';
        if (b == StreamRightsRecordTypes.Basis.CONTRACT) return '"contract"';
        return '"unspecified"';
    }

    function _status(StreamRightsRecordTypes.Status s) private pure returns (string memory) {
        if (s == StreamRightsRecordTypes.Status.GRANTED) return '"granted"';
        if (s == StreamRightsRecordTypes.Status.GRANTED_WITH_CONDITIONS) {
            return '"granted_with_conditions"';
        }
        if (s == StreamRightsRecordTypes.Status.DENIED) return '"denied"';
        return '"unspecified"';
    }
}
