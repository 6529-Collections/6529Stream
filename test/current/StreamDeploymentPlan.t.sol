// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentGovernanceBootstrap.t.sol";
import "../../script/current/StreamDeploymentPlan.sol";

/// @notice Planning extraction preserves actual foundation execution and catalog meaning.
/// @dev Inherited tests retain the original direct-planner foundation/Safe coverage.
contract StreamDeploymentPlanTest is StreamCurrentGovernanceBootstrapTest {
    function testExternalFoundationPlanMatchesInlineAndInitializesActualExecutor() public {
        StreamDeploymentPlan planner = new StreamDeploymentPlan();
        StreamGovernanceGenesisPlan.Configuration memory c = configuration;
        bytes memory content = bytes("{\"purpose\":\"planner equivalence\",\"version\":1}");
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(content);
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:6529stream:fixture:planner",
            keccak256("events"),
            keccak256("compatibility"),
            keccak256("numeric ids"),
            keccak256("schema"),
            keccak256("canonicalization"),
            keccak256("specification"),
            keccak256("client")
        );
        (SystemManifestBootstrapBinding memory expected, GenesisBatch[] memory expectedBatches) =
            StreamGovernanceGenesisPlan.build(c, payload, update);
        (SystemManifestBootstrapBinding memory binding, GenesisBatch[] memory batches) =
            planner.buildFoundation(c, payload, update);
        require(
            keccak256(abi.encode(binding, batches))
                == keccak256(abi.encode(expected, expectedBatches)),
            "complete plan bytes preserved"
        );
        for (uint256 i; i < binding.actionPolicies.length; ++i) {
            require(
                binding.actionPolicies[i].target != address(planner),
                "helper is not a policy target"
            );
        }
        c.executor.commitGenesisPlan(c.executor.hashGenesisPlan(binding, batches));
        c.executor.prepareGenesis(binding, batches);
        c.executor.initializeGenesis(binding, batches);
        require(c.executor.genesisInitialized(), "actual genesis initialized");
        require(address(c.executor.roleRegistry()) == address(c.roles), "canonical role registry");
        require(c.registry.moduleCount() == 2, "exact foundation registry membership");
        require(c.manifest.streamSystemManifestPointerCount() == 1, "actual manifest published");
        StreamCorePointerState memory pointer =
            StreamCurrentStackPlan.readPointer(c.core, keccak256("SYSTEM_MANIFEST"));
        require(pointer.target == address(c.manifest) && pointer.frozen, "exact frozen manifest");
    }

    function testCatalogDeduplicatesSortsAndPreservesExactFoundationAndOperatingFields() public {
        StreamDeploymentPlan planner = new StreamDeploymentPlan();
        (GenesisBatch[] memory batches, GovernanceActionPolicyEntry[] memory operating) =
            _catalogInput();
        GovernanceActionPolicyEntry[] memory foundation = new GovernanceActionPolicyEntry[](1);
        foundation[0] = operating[0];
        GovernanceActionPolicyEntry[] memory rows =
            planner.catalogAdditions(batches, operating, foundation, keccak256("planner profile"));
        require(rows.length == 2, "duplicate and existing foundation excluded");
        require(_catalogKey(rows[0]) < _catalogKey(rows[1]), "strict canonical ordering");
        bool foundOperating;
        bool foundGenerated;
        for (uint256 i; i < rows.length; ++i) {
            require(rows[i].target != address(planner), "helper absent from catalog");
            if (rows[i].selector == bytes4(keccak256("operating()"))) {
                require(
                    keccak256(abi.encode(rows[i])) == keccak256(abi.encode(operating[1])),
                    "all operating fields retained"
                );
                foundOperating = true;
            } else {
                require(
                    rows[i].actionClass == 3 && rows[i].target == address(configuration.core),
                    "generated target and class"
                );
                require(rows[i].selector == bytes4(keccak256("generated()")), "generated selector");
                require(
                    rows[i].targetCodeHash == address(configuration.core).codehash,
                    "actual target code hash"
                );
                require(
                    rows[i].targetProfileHash
                        == keccak256(
                            abi.encode(keccak256("planner profile"), address(configuration.core))
                        ),
                    "exact profile preimage"
                );
                foundGenerated = true;
            }
        }
        require(foundOperating && foundGenerated, "both intended rows retained");
    }

    function testCatalogRejectsConflictingFoundationFields() public {
        StreamDeploymentPlan planner = new StreamDeploymentPlan();
        (GenesisBatch[] memory batches, GovernanceActionPolicyEntry[] memory operating) =
            _catalogInput();
        GovernanceActionPolicyEntry[] memory foundation = new GovernanceActionPolicyEntry[](1);
        // Memory struct assignment aliases the original row; the conflicting copy must be independent.
        foundation[0] = abi.decode(abi.encode(operating[0]), (GovernanceActionPolicyEntry));
        foundation[0].targetProfileHash = keccak256("changed foundation profile");
        vm.expectRevert();
        planner.catalogAdditions(batches, operating, foundation, keccak256("planner profile"));
    }

    function testFuzzCatalogResultIndependentOfPrototypeDuplicates(uint8 repetitions) public {
        StreamDeploymentPlan planner = new StreamDeploymentPlan();
        (GenesisBatch[] memory batches, GovernanceActionPolicyEntry[] memory operating) =
            _catalogInput();
        GovernanceActionPolicyEntry[] memory foundation = new GovernanceActionPolicyEntry[](0);
        bytes32 expected = keccak256(
            abi.encode(
                planner.catalogAdditions(
                    batches, operating, foundation, keccak256("planner profile")
                )
            )
        );
        GenesisBatch[] memory duplicates = new GenesisBatch[](1 + uint256(repetitions % 8));
        for (uint256 i; i < duplicates.length; ++i) {
            duplicates[i] = batches[0];
        }
        require(
            keccak256(
                abi.encode(
                    planner.catalogAdditions(
                        duplicates, operating, foundation, keccak256("planner profile")
                    )
                )
            ) == expected,
            "repeated prototype does not alter catalog"
        );
    }

    function _catalogInput()
        private
        view
        returns (GenesisBatch[] memory batches, GovernanceActionPolicyEntry[] memory operating)
    {
        operating = new GovernanceActionPolicyEntry[](2);
        operating[0] = GovernanceActionPolicyEntry(
            1,
            address(configuration.executor),
            bytes4(keccak256("foundation()")),
            address(configuration.executor).codehash,
            keccak256("foundation profile"),
            1,
            0,
            0,
            bytes32(0)
        );
        operating[1] = GovernanceActionPolicyEntry(
            2,
            address(configuration.core),
            bytes4(keccak256("operating()")),
            address(configuration.core).codehash,
            keccak256("operating profile"),
            2,
            1,
            7,
            keccak256("operation predicate")
        );
        batches = new GenesisBatch[](1);
        batches[0].actionClass = 3;
        batches[0].calls = new GovernanceCall[](2);
        batches[0].calls[0].target = address(configuration.core);
        batches[0].calls[0].selector = bytes4(keccak256("generated()"));
        batches[0].calls[1] = batches[0].calls[0];
    }

    function _catalogKey(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }
}
