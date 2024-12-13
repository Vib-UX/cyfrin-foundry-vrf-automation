// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract CreateSubscription is Script {
    function createSubascriptionUsingConfig()
        public
        returns (uint256, address)
    {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        address vrfCoordinator = helperConfig.getChainConfig().vrfCoordinator;
        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
        // create subscription
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        console.log("Creating subscription on Chain Id: ", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("Your subscription id is: ", subId);
        console.log(
            "Please update the subscription Id in your HelperConfig.s.sol"
        );

        return (subId, vrfCoordinator);
    }

    // Fund it!

    function run() external {
        createSubascriptionUsingConfig();
    }
}