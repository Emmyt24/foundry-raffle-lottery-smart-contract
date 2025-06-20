// SPDX-License-Identifier: MIT

// please uncomment the startBroadcast and the stopBroadcast before runing the scripts
// commented all vm in script it not allow to have vm runing in script and also running in test.
// so uncomment the vm in script if you want to run the script.

pragma solidity ^0.8.15;
import {Script, console} from "../forge-std/Script.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/linkToken.sol";
import {Raffle} from "../src/Raffle.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256) {
        // create subcription using config just get the networkConfig
        HelperConfig helperConfig = new HelperConfig();
        helperConfig.ActiveNetworkConfig();

        return 0;
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256) {
        console.log("creating subscription on cahinId ", block.chainid);
        vm.startBroadcast();
        uint256 subId = uint256(
            VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription()
        );
        vm.stopBroadcast();
        console.log("your subId is ", subId);
        console.log("please update subscriptionId in Helperconfig.s.sol");
        return subId;
    }

    function run() external returns (uint256) {
        // subscriptionId is in uint64
        return createSubscriptionUsingConfig(); // we just have the function run to return the create the creatsubcriptioid fuction.
    }
}

contract fundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 2 ether;

    function fundSubUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint256 subId,
            ,
            address link
        ) = helperConfig.ActiveNetworkConfig();
        fundSub(vrfCoordinator, subId, link);
    }

    function fundSub(
        address vrfCoordinator,
        uint256 subId,
        address link
    ) public {
        console.log("funding subscription", subId);
        console.log("using vrfCoordinator", vrfCoordinator);
        console.log("on chainId ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubUsingConfig();
    }
}

contract AddConsumer is Script {
    function addconsumerUsingconfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , uint256 subId, , ) = helperConfig
            .ActiveNetworkConfig();
        addConsumer(raffle, vrfCoordinator, subId);
    }

    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint256 subId
    ) public {
        console.log("adding consumer contract ", raffle);
        console.log("using vrfCoordinator ", vrfCoordinator);
        console.log("on chainId ", block.chainid);
        // vm.startBroadcast();

        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, raffle);

        // vm.startBroadcast();
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );

        addconsumerUsingconfig(raffle);
    }
}
