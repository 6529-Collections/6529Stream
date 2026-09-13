// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./RevenueResolverTestMocks.sol";
import "./GovernedParameterTestMocks.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";

/// @dev Strict facade boundary fixture; actual owner composition is covered in the artist suite.
contract ArtistTemplateFactsMock is RevenueResolverArtistMock, IStreamArtistBeneficiaryFacts {
    bytes32 public identity = keccak256("artist identity");
    bytes32 public designation = keccak256("designation one");
    address public payout;
    uint8 public mode;
    uint256 public gasWork;

    constructor(address core_, address payout_) RevenueResolverArtistMock(core_) {
        payout = payout_;
    }

    function setFacts(bytes32 artistId, address recipient, bytes32 record) external {
        identity = artistId;
        payout = recipient;
        designation = record;
    }

    function setMode(uint8 value) external {
        mode = value;
    }

    function setGasWork(uint256 value) external {
        gasWork = value;
    }

    function collectionArtistBeneficiary(uint256)
        external
        view
        returns (bytes32, address, bytes32)
    {
        uint8 m = mode;
        if (m == 1) revert("unaccepted or stale binding");
        uint256 start = gasleft();
        while (start - gasleft() < gasWork) { }
        bytes32 id = identity;
        address payee = payout;
        bytes32 record = designation;
        if (m == 0) return (id, payee, record);
        uint256 length = m == 2 ? 95 : m == 3 ? 97 : m == 4 || m == 5 ? 65_536 : 96;
        bytes memory result = new bytes(length);
        assembly ("memory-safe") {
            mstore(add(result, 32), id)
            mstore(add(result, 64), payee)
            mstore(add(result, 96), record)
            if eq(m, 6) { mstore(add(result, 64), or(payee, shl(160, 1))) }
            if eq(m, 5) { revert(add(result, 32), mload(result)) }
            return(add(result, 32), mload(result))
        }
    }
}

/// @dev Only a designated real Safe may forward the configured governance action context.
contract TemplateGovernanceMock is MockGovernedParameterAuthority {
    address public controller;

    constructor() MockGovernedParameterAuthority(true) {
        controller = msg.sender;
    }

    function setController(address next) external {
        require(msg.sender == controller);
        controller = next;
    }

    function execute(address target, bytes calldata data) external {
        require(msg.sender == controller, "controller");
        (bool ok, bytes memory reason) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
    }
}
