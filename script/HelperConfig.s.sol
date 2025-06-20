// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/linkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }
    NetworkConfig public ActiveNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            ActiveNetworkConfig = getSepoliaEthConfig();
        } else {
            ActiveNetworkConfig = getAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.1 ether,
                interval: 30,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 73593670110971732139447389460024333523616194323789707814949300942262154837248, // will update it later
                callbackGasLimit: 5000000, //500,000
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
            });
    }

    function getAnvilEthConfig() public returns (NetworkConfig memory) {
        if (ActiveNetworkConfig.vrfCoordinator != address(0)) {
            return ActiveNetworkConfig;
        }
        uint96 baseFee = 0.25 ether; // really 0.25 link
        uint96 gasPriceLink = 1e9; // 1 gwei
        int256 WEI_PER_UINT_LINK = 1e18;
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
                baseFee,
                gasPriceLink,
                WEI_PER_UINT_LINK
            );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinatorV2_5Mock),
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 0, // will update it later
                callbackGasLimit: 5000000, //500,000
                link: address(link)
            });
    }
}
