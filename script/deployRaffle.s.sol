// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Script} from "../forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, fundSubscription, AddConsumer} from "../script/interaction.s.sol";

contract DeployRaffle is Script {
    fundSubscription FundSubscription;

    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // Create a new instance of the HelperConfig contract.
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint256 subscriptionId,
            uint32 callbackGasLimit,
            address link
        ) = helperConfig.ActiveNetworkConfig();

        if (subscriptionId == 0) {
            //we should assume we don't have one the we create one
            CreateSubscription createSubscriptionId = new CreateSubscription();
            subscriptionId = createSubscriptionId.createSubscription(
                vrfCoordinator
            );

            //fund it
            FundSubscription = new fundSubscription();
            FundSubscription.fundSub(vrfCoordinator, subscriptionId, link);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            vrfCoordinator,
            subscriptionId
        );

        return (raffle, helperConfig);
    }
}
 