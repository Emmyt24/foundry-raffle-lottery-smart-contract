// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/deployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

// import {CreateSubscription, fundSubscription, AddConsumer} from "../../script/interaction.s.sol";

contract Raffle_Test is Test {
    Raffle raffle;
    /**Event */
    event RaffleEntered(address indexed player);
    // fundSubscription FundSubscription;

    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    uint256 deployerKey;

    address public PLAYER = makeAddr("PLAYER");
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        // This setup prepares the test environment with a deployed Raffle contract and all necessary parameters.
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        // helperConfig = new HelperConfig();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,
            deployerKey
        ) = helperConfig.ActiveNetworkConfig();

        // subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator)
        //     .createSubscription();
        // VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
        //     subscriptionId,
        //     2 ether
        // );
        raffle = new Raffle(
            entranceFee,
            interval,
            address(vrfCoordinator),
            gasLane,
            subscriptionId,
            callbackGasLimit
        );

        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            address(raffle)
        );
    }

    ////////////////
    /////Raffle/////
    ////////////////

    function testRaffleInitializeInOpenState() public view {
        uint256 RaffleState = raffle.getRaffleState();
        assert(RaffleState == 0);
    }

    function testRevertWithoutEntranceFee() public {
        vm.prank(PLAYER);
        vm.deal(PLAYER, 0.1 ether);
        vm.expectRevert(Raffle.Raffle__notEnoughEthSent.selector); // in solidy custom error are identify by selector;
        raffle.EnteredRaffle();
    }

    function testPlayerGetAddedToPlayersArray() public funded {
        raffle.EnteredRaffle{value: entranceFee}();
        assert(PLAYER == raffle.getPlayersIndex(0));
    }

    function testPlayersLengthIncreaseWhenEntered() public funded {
        raffle.EnteredRaffle{value: entranceFee}();
        assert(raffle.getPlayersLength() > 0);
    }

    function testEventgetEmitted() public funded {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.EnteredRaffle{value: entranceFee}();
    }

    function testCantEnterWhenCalculating() public funded {
        raffle.EnteredRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle_NOTOPEN.selector);
        vm.prank(PLAYER);
        raffle.EnteredRaffle{value: entranceFee}();
    }

    ////////////////////
    ///check Upkeep/////
    ////////////////////

    function testCheckUpkeepReturnsFalseIfHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        //assert
        assert(!upKeepNeeded);
    }

    function testReturnFalseIfRaffleNotOpen() public EnterWarpRoll {
        // vm.prank(PLAYER);
        raffle.performUpkeep("");
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        assert(
            raffle.getRaffleState() == uint256(Raffle.RaffleState.CALCULATING)
        );
        assert(upKeepNeeded == false);
    }

    function testReturnFalseIfEnoughTimeHasnotPassed() public funded {
        // vm.prank(PLAYER);
        raffle.EnteredRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 10);
        vm.roll(block.number - 1);
        vm.expectRevert();
        raffle.performUpkeep("");
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        assert(upKeepNeeded == false);
    }

    function testReturnTrueWhenParametersAreGood() public EnterWarpRoll {
        //arrange
        //act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        //assert
        assert(upKeepNeeded);
    }

    /////////////////////
    ////perform upKeep///

    function testPerfomUpKeepCanOnlyRunIfCheckUpKeepIsTrue()
        public
        EnterWarpRoll
    {
        //arrange
        //act //assert
        raffle.performUpkeep("");
    }

    function testPerformUpKeepRevertIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 playersLength = 0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeedNotNeeded.selector,
                currentBalance,
                playersLength,
                raffleState,
                interval
            )
        );

        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdateRaffleStateAndEmitRequestId()
        public
        EnterWarpRoll
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState rState = Raffle.RaffleState(raffle.getRaffleState());
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
        assert(entries.length > 1);
    }

    function testFulfillRandomWordCanOnlybeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public EnterWarpRoll {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    modifier funded() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        _;
    }
    modifier EnterWarpRoll() {
        vm.prank(PLAYER);
        vm.deal(PLAYER, STARTING_BALANCE);
        raffle.EnteredRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }
}
//alpha north unable want drastic crash dove write minor tell job blind
//see phrase probably solflaire
