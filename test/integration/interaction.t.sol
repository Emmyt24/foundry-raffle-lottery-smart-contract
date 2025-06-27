// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;
import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";

contract integrationTest is Test {
    Raffle raffle;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    uint256 deployerKey;

    function setUp() external {
        raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
    }

    
}
