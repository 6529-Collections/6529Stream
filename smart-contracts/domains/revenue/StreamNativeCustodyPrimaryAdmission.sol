// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeSettlementValidation.sol";
import "../../interfaces/stream/auctions/IStreamNativeCustodyAuction.sol";
import "../../interfaces/stream/revenue/IStreamNativeCustodyPrimarySettlement.sol";

/// @notice Governance explicitly trusts one immutable house implementation for custody history.
/// @dev This pin is not an independent arbitrary-house mint-origin receipt.
library StreamNativeCustodyPrimaryAdmission {
    struct Context {
        address core;
        bytes32 coreHash;
        address registry;
        bytes32 registryHash;
        address authority;
        bytes32 authorityHash;
    }

    event CanonicalCustodyHouseBound(
        address indexed house,
        bytes32 indexed codeHash,
        bytes32 indexed actionId,
        StreamNativeCustodySettlementTypes.CanonicalHouse binding
    );

    function validateAuthority(address authority) public view returns (bytes32) {
        if (
            !StreamSettlementAdmission.isContract(authority)
                || uint256(
                        StreamPreparedNativeSettlementValidation.word(
                            authority, "isStreamGovernedParameterAuthority()"
                        )
                    ) != 1
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        bytes memory raw = StreamPreparedNativeSettlementValidation.read(
            authority, abi.encodeWithSignature("currentAction()"), 192
        );
        (bool executing, bytes32 id, uint8 kind, bytes32 scope, bytes32 old_, bytes32 next) =
            abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (keccak256(raw) != keccak256(abi.encode(executing, id, kind, scope, old_, next))) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        return authority.codehash;
    }

    function transition(
        Context memory x,
        StreamNativeCustodySettlementTypes.CanonicalHouse memory prior,
        address house
    ) public view returns (bytes32 scope, bytes32 oldState, bytes32 newState) {
        StreamNativeCustodySettlementTypes.CanonicalHouse memory next = candidate(x, house);
        scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_CANONICAL_CUSTODY_HOUSE_SCOPE_V1"),
                block.chainid,
                address(this),
                x.core,
                x.registry
            )
        );
        oldState = stateHash(scope, prior);
        newState = stateHash(scope, next);
    }

    function bind(
        Context memory x,
        StreamNativeCustodySettlementTypes.CanonicalHouse storage saved,
        address house
    ) public {
        if (saved.house != address(0)) {
            revert IStreamNativeCustodyPrimarySettlement.NativeCustodyHouseAlreadyBound();
        }
        if (msg.sender != x.authority || x.authority.codehash != x.authorityHash) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        StreamNativeCustodySettlementTypes.CanonicalHouse memory next = candidate(x, house);
        (bytes32 scope, bytes32 oldState, bytes32 newState) = transition(x, saved, house);
        bytes memory raw = StreamPreparedNativeSettlementValidation.read(
            x.authority, abi.encodeWithSignature("currentAction()"), 192
        );
        (bool executing, bytes32 id, uint8 kind, bytes32 actualScope, bytes32 old_, bytes32 next_) =
            abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            !executing || id == 0 || kind != 1 || actualScope != scope || old_ != oldState
                || next_ != newState
                || keccak256(raw)
                    != keccak256(abi.encode(executing, id, kind, actualScope, old_, next_))
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        saved.house = next.house;
        saved.codeHash = next.codeHash;
        saved.boundAt = next.boundAt;
        saved.revision = next.revision;
        saved.recorderBoundAt = next.recorderBoundAt;
        saved.recorderRevision = next.recorderRevision;
        emit CanonicalCustodyHouseBound(house, next.codeHash, id, next);
    }

    function requireCurrent(
        Context memory x,
        StreamNativeCustodySettlementTypes.CanonicalHouse memory pin,
        address house
    ) public view {
        if (pin.house == address(0) || house != pin.house || house.codehash != pin.codeHash) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        bindings(x, house);
        StreamPreparedNativeSettlementAdmission.requireModule(x.registry, house);
        StreamPreparedNativeSettlementAdmission.requireRecorder(
            x.registry, address(this), pin.recorderBoundAt, pin.recorderRevision
        );
    }

    function candidate(Context memory x, address house)
        private
        view
        returns (StreamNativeCustodySettlementTypes.CanonicalHouse memory next)
    {
        bindings(x, house);
        StreamNativeSettlementTypes.SaleLifecycleBinding memory life =
            StreamPreparedNativeSettlementAdmission.capture(x.registry, house);
        (uint64 at_, uint64 rev) =
            StreamPreparedNativeSettlementAdmission.captureRecorder(x.registry, address(this));
        next = StreamNativeCustodySettlementTypes.CanonicalHouse(
            house, house.codehash, life.saleCreatedAt, life.saleAdapterRegistryRevision, at_, rev
        );
    }

    function bindings(Context memory x, address house) private view {
        StreamSettlementAdmission.requireRegistry(x.core, x.coreHash, x.registry, x.registryHash);
        if (
            !StreamSettlementAdmission.isContract(house)
                || StreamPreparedNativeSettlementValidation.addressWord(house, "core()") != x.core
                || StreamPreparedNativeSettlementValidation.word(house, "coreCodeHash()")
                    != x.coreHash
                || StreamPreparedNativeSettlementValidation.addressWord(house, "moduleRegistry()")
                    != x.registry
                || StreamPreparedNativeSettlementValidation.word(house, "moduleRegistryCodeHash()")
                    != x.registryHash
                || StreamPreparedNativeSettlementValidation.addressWord(
                        house, "primarySaleSettlement()"
                    ) != address(this)
                || StreamPreparedNativeSettlementValidation.word(house, "settlementCodeHash()")
                    != address(this).codehash
                || StreamPreparedNativeSettlementValidation.addressWord(
                        house, "governanceAuthority()"
                    ) != x.authority
                || StreamPreparedNativeSettlementValidation.addressWord(house, "revenueResolver()")
                    != StreamPreparedNativeSettlementValidation.addressWord(
                        address(this), "revenueResolver()"
                    )
        ) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
        bytes memory raw = StreamPreparedNativeSettlementValidation.read(
            house,
            abi.encodeWithSelector(
                bytes4(0x01ffc9a7), type(IStreamNativeCustodyAuction).interfaceId
            ),
            32
        );
        if (abi.decode(raw, (uint256)) != 1) {
            revert IStreamNativeCustodyPrimarySettlement.InvalidNativeCustodySettlement();
        }
    }

    function stateHash(bytes32 scope, StreamNativeCustodySettlementTypes.CanonicalHouse memory pin)
        private
        view
        returns (bytes32)
    {
        // Timestamps are authenticated observations at execution, not unknowable scheduling inputs.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CANONICAL_CUSTODY_HOUSE_STATE_V1"),
                block.chainid,
                address(this),
                scope,
                pin.house,
                pin.codeHash,
                pin.revision,
                pin.recorderRevision
            )
        );
    }
}
