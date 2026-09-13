// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Complete untrusted witnesses for steward designation and recovery response JSON.
/// @dev The authenticated carrier determines the speaker. These values convey no authority.
library StreamOwnerNoticeTypes {
    enum StewardKind {
        INSTITUTION,
        REGISTRAR_CONTACT
    }
    enum ContactKind {
        HTTPS,
        MAILTO,
        EIP155
    }
    enum ResponseClass {
        ACKNOWLEDGED,
        OBJECTED
    }

    struct Reference {
        uint16 algorithm;
        bytes32 canonicalizationId;
        bytes digest;
        string uri;
    }

    /// @dev HTTPS/MAILTO require chainId=0/account=0; EIP155 requires uri empty.
    struct Contact {
        ContactKind kind;
        string uri;
        uint256 chainId;
        address account;
    }

    struct Designation {
        bytes32 subjectId;
        bytes32 profileHash;
        bytes32 predecessor;
        StewardKind kind;
        string name;
        Reference identity;
        Contact[] contactEndpoints;
    }

    struct Response {
        bytes32 subjectId;
        bytes32 profileHash;
        bytes32 recoveryId;
        bytes32 recoveryManifestHash;
        ResponseClass response;
        string grounds;
        Reference[] evidenceReferences;
    }
}
