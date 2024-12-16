// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

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

    function run() external {
        createSubascriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        address vrfCoordinator = helperConfig.getChainConfig().vrfCoordinator;
        uint256 subId = helperConfig.getChainConfig().subscriptionId;
        address linkToken = helperConfig.getChainConfig().link;
        fundSubscription(vrfCoordinator, subId, linkToken);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken
    ) public {
        console.log("Funding subscription on Chain Id: ", block.chainid);
        console.log("vrfCoordinator: ", vrfCoordinator);
        console.log("subscriptionId: ", subscriptionId);
        console.log("linkToken: ", linkToken);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function functionAddConsumerUsingConfig(
        address mostRecentlyDeployed
    ) public {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        uint256 subId = helperConfig.getChainConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getChainConfig().vrfCoordinator;
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId);
    }

    function addConsumer(
        address contractToAddrToVrf,
        address vrfCoordinator,
        uint256 subId
    ) public {
        console.log("Adding consumer on Chain Id: ", block.chainid);
        console.log("contractToAddrToVrf: ", contractToAddrToVrf);
        console.log("vrfCoordinator: ", vrfCoordinator);
        console.log("subId: ", subId);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            contractToAddrToVrf
        );
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        functionAddConsumerUsingConfig(mostRecentlyDeployed);
    }
}
