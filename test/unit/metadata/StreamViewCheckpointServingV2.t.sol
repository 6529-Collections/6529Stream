// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ViewCheckpointFixtureV2.sol";
import {
    StreamViewCheckpointServingV2 as Adapter
} from "../../../smart-contracts/domains/metadata/StreamViewCheckpointServingV2.sol";
import {
    IStreamViewCheckpointServingV2 as API
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamViewCheckpointServingV2.sol";
import {
    IStreamViewAdoptionRouter as RouterAPI
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamViewAdoptionRouter.sol";

interface ViewCheckpointCoolingVm {
    function cool(address account) external;
}

contract StreamViewCheckpointServingV2Test is ViewCheckpointFixtureV2 {
    event CheckpointEnvelope(uint8 mode, uint256 executionAndCallGas, uint256 intrinsicGas);

    function _adapter() private returns (Adapter) {
        return new Adapter(
            API.Binding(
                address(core),
                address(core).codehash,
                address(records),
                address(records).codehash,
                block.chainid,
                8000000
            )
        );
    }

    function _eq(string memory a, string memory b) private pure {
        require(keccak256(bytes(a)) == keccak256(bytes(b)), "exact output");
    }

    function _invalid(Adapter a, StreamFinalityScope memory scope_, uint8 mode) private view {
        (bool ok, bytes memory raw) =
            address(a).staticcall(abi.encodeCall(a.currentOutput, (scope_, 11, mode)));
        require(
            !ok
                && keccak256(raw)
                    == keccak256(abi.encodeWithSelector(V.InvalidViewAdoption.selector)),
            "exact refusal"
        );
    }

    function testFourOriginalDispatchOutputsAndIndependentRequestAreExact() public {
        (Renderer r, bytes32 key) = _renderer();
        Adapter a = _adapter();
        RouterAPI router = RouterAPI(address(records));
        for (uint8 mode = 2; mode <= 3; ++mode) {
            (bytes32 current, string memory out) = a.currentOutput(scope, 11, mode);
            require(current == key);
            _eq(out, r.renderPolicyView(_request(key, 0, false), mode));
            _eq(
                out,
                mode == 2
                    ? router.tokenJSONForView(11, scope.scopeId)
                    : router.tokenHTMLForView(11, scope.scopeId)
            );
            (StreamFinalityScope memory seen, string memory old) = a.historicalOutput(key, 11, mode);
            require(keccak256(abi.encode(seen)) == keccak256(abi.encode(scope)));
            _eq(out, old);
            _eq(
                old,
                mode == 2
                    ? router.historicalTokenJSONForView(11, key)
                    : router.historicalTokenHTMLForView(11, key)
            );
        }
        (address worker, bytes32 workerHash) = a.workerBinding();
        require(
            a.configurationHash()
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_CHECKPOINT_SERVING_V2"),
                        block.chainid,
                        address(a),
                        a.binding(),
                        worker,
                        workerHash
                    )
                )
        );
    }

    function testCurrentBurnedRefusesAtOriginalPredicateAndHistoricalKeepsIdentity() public {
        (Renderer r, bytes32 key) = _renderer();
        Adapter a = _adapter();
        _identity(3, true, 7);
        _invalid(a, scope, 3);
        (, string memory old) = a.historicalOutput(key, 11, 3);
        _eq(old, r.renderPolicyView(_request(key, 0, true), 3));
        _eq(old, records.historicalTokenHTMLForView(11, key));
        _identity(2, false, 7);
        (, string memory restored) = a.currentOutput(scope, 11, 3);
        _eq(restored, r.renderPolicyView(_request(key, 0, false), 3));
    }

    function testFullScopeModesAndUnknownOrSubstitutedTagsRefuse() public {
        (, bytes32 key) = _renderer();
        Adapter a = _adapter();
        StreamFinalityScope memory wrong =
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 2, 0, scope.scopeId);
        _invalid(a, wrong, 3);
        wrong = StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, scope.scopeId);
        _invalid(a, wrong, 3);
        _invalid(a, scope, 1);
        records.forceTag(key, 0);
        _invalid(a, scope, 3);
        records.forceTag(key, keccak256("unknown tag"));
        vm.expectRevert(
            abi.encodeWithSelector(
                V.ViewAdoptionRead.selector,
                address(records),
                bytes4(keccak256("viewAdoptionProfile(bytes32)"))
            )
        );
        a.currentOutput(scope, 11, 3);
        records.forceTag(key, T.PROFILE);
        a.currentOutput(scope, 11, 3);
        (bool ok,) = address(a)
            .staticcall(abi.encodeCall(a.historicalOutput, (bytes32(uint256(1)), 11, uint8(3))));
        require(!ok);
    }

    function testReplacementAndDeclarationDriftKeepExactHistoricalBytes() public {
        (, bytes32 oldKey) = _renderer();
        Adapter a = _adapter();
        (, string memory old) = a.historicalOutput(oldKey, 11, 3);
        (, bytes32 next) = _renderer();
        require(next != oldKey);
        (bytes32 head,) = a.currentOutput(scope, 11, 3);
        require(head == next);
        (, string memory retained) = a.historicalOutput(oldKey, 11, 3);
        _eq(old, retained);
        _answer(
            core,
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), VIEW_ID),
            abi.encode(bytes32(uint256(9)), false)
        );
        _invalid(a, scope, 3);
        (, retained) = a.historicalOutput(oldKey, 11, 3);
        _eq(old, retained);
        _answer(
            core,
            "selectedViewRecord(uint256,bytes32)",
            abi.encode(uint256(1), VIEW_ID),
            abi.encode(VIEW_RECORD, false)
        );
        a.currentOutput(scope, 11, 3);
    }

    function testPendingPolicyAndSourceDriftCannotPromoteToCurrentOutput() public {
        (, bytes32 key) = _renderer();
        Adapter a = _adapter();
        _facts(3, 0, 0);
        _invalid(a, scope, 3);
        _facts(1, 0, 0);
        a.currentOutput(scope, 11, 3);
        _answer(
            core,
            "scopeCoversToken((uint8,uint256,uint256,bytes32),uint256)",
            abi.encode(scope, uint256(11)),
            abi.encode(false)
        );
        _invalid(a, scope, 3);
        _answer(
            core,
            "scopeCoversToken((uint8,uint256,uint256,bytes32),uint256)",
            abi.encode(scope, uint256(11)),
            abi.encode(true)
        );
        _pointer("ARTWORK_FINALITY_REGISTRY", address(sourceSet));
        _invalid(a, scope, 3);
        _pointer("ARTWORK_FINALITY_REGISTRY", address(core));
        a.currentOutput(scope, 11, 3);
        a.historicalOutput(key, 11, 3);
    }

    function testTerminalOptionalFinalizedAndLegacyMatchOriginalOutput() public {
        for (uint8 i; i < 3; ++i) {
            if (i == 0) {
                _policy(2, 1, true);
                _facts(2, 0, 0);
            } else if (i == 1) {
                _policy(2, 0, true);
                _facts(5, keccak256("seed"), keccak256("request"));
            } else {
                _policy(0, 0, false);
                _facts(5, keccak256("seed"), 0);
            }
            (Renderer r, bytes32 key) = _renderer();
            Adapter a = _adapter();
            (, string memory out) = a.currentOutput(scope, 11, 3);
            _eq(
                out,
                r.renderPolicyView(_request(key, i == 0 ? bytes32(0) : keccak256("seed"), false), 3)
            );
            _eq(out, records.historicalTokenHTMLForView(11, key));
        }
    }

    function testConstructorPinsCapAndForeignChainRestore() public {
        _renderer();
        Adapter a = _adapter();
        API.Binding memory b = a.binding();
        bytes32 saved = b.routerCodeHash;
        b.routerCodeHash = keccak256("foreign pin");
        vm.expectRevert(abi.encodeWithSelector(V.ViewAdoptionDependency.selector, address(records)));
        new Adapter(b);
        b.routerCodeHash = saved;
        b.rendererGas = 14000001;
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewAdoption.selector));
        new Adapter(b);
        uint256 chain = a.binding().chainId;
        vm.chainId(chain + 1);
        _invalid(a, scope, 3);
        vm.chainId(chain);
        a.currentOutput(scope, 11, 3);
    }

    function testColdAdapterCallsIncludeIntrinsicWithinOriginalEnvelope() public {
        (Renderer renderer, bytes32 key) = _renderer();
        Adapter a = _adapter();
        V.Record memory saved = abi.decode(records.encoded(key), (V.Record));
        (address carrier,,) = records.carrier(key);
        (address worker,) = a.workerBinding();
        (address encoder,) = renderer.encodingBinding();
        for (uint8 mode = 2; mode <= 3; ++mode) {
            bytes memory input = abi.encodeCall(a.currentOutput, (scope, 11, mode));
            uint256 intrinsic = 21000;
            for (uint256 i; i < input.length; ++i) {
                intrinsic += input[i] == 0 ? 4 : 16;
            }
            address[11] memory accounts = [
                address(a),
                address(core),
                address(records),
                address(renderer),
                address(coordinator),
                address(attribution),
                address(sourceSet),
                address(store),
                worker,
                encoder,
                carrier
            ];
            for (uint256 i; i < accounts.length; ++i) {
                ViewCheckpointCoolingVm(address(vm)).cool(accounts[i]);
            }
            for (uint256 i; i < 5; ++i) {
                if (saved.source.payloadPointers[i] != address(0)) {
                    ViewCheckpointCoolingVm(address(vm)).cool(saved.source.payloadPointers[i]);
                }
            }
            uint256 before = gasleft();
            (bool ok, bytes memory raw) = address(a).staticcall{ gas: 16777216 - intrinsic }(input);
            uint256 used = before - gasleft();
            require(ok, "bounded adapter call");
            require(used + intrinsic <= 16777216, "original envelope");
            (bytes32 observed, string memory output) = abi.decode(raw, (bytes32, string));
            require(observed == key);
            _eq(output, renderer.renderPolicyView(_request(key, 0, false), mode));
            emit CheckpointEnvelope(mode, used, intrinsic);
        }
    }

    function testFixedWorkerRuntimeChangeRefusesThenRestoresExactOutput() public {
        _renderer();
        Adapter a = _adapter();
        (, string memory before) = a.currentOutput(scope, 11, 3);
        (address worker,) = a.workerBinding();
        bytes memory code = worker.code;
        vm.etch(worker, hex"00");
        vm.expectRevert(abi.encodeWithSelector(V.ViewAdoptionDependency.selector, worker));
        a.currentOutput(scope, 11, 3);
        vm.etch(worker, code);
        (, string memory after_) = a.currentOutput(scope, 11, 3);
        _eq(before, after_);
    }
}
