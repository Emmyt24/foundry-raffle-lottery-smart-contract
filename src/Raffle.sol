// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * @title  A Sample of Raffle Contract
 * @author crypto paps
 * @notice this contract is for creating a sample raffle
 * @dev Implemented Chainling VRFv2
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /**Erros */
    error Raffle__notEnoughEthSent();
    error Raffle_UpkeedNotNeeded(
        uint256 currentBalance,
        uint256 playersLength,
        uint256 raffleState,
        uint256 interval
    );
    error Raffle_winnerNotPaid();
    error Raffle_NOTOPEN();

    /**type declaration */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**state variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    address public raffleOwner;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // duration of the lottery in seconds.
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address payable private s_recentWinner;
    RaffleState private s_raffleState;

    // This is useful for refunding players if the raffle is cancelled
    // or if they want to withdraw their funds.
    mapping(address => uint256) public PlayerToAmountFunded;
    /** Events*/
    event RaffleEntered(address indexed player);
    event pickedWinner(address indexed winner);
    event requestRaffleWinner(uint256 indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        // i_vrfCoordinator = vrfCoordinator;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        raffleOwner = msg.sender;
        s_raffleState = RaffleState.OPEN;
    }

    function EnteredRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__notEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_NOTOPEN();
        }
        s_players.push(payable(msg.sender));
        PlayerToAmountFunded[msg.sender] = msg.value;
        emit RaffleEntered(msg.sender);
    }

    /**
*@dev this is the function that the chainlink automation nodes call
to see if it is time to perform an upkeep.
* the blow pre-requisite should be true for this to return true
* 1. the time interval has passed between raffle runs
* 2. the raffle is in an open state
* 3. the subscription is funded
* 4. the contract has players.
 */
    function checkUpkeep(
        bytes memory /**checkData*/
    ) public view returns (bool upkeedNeeded, bytes memory /**performData*/) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasEnoughPlayer = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeedNeeded = (timeHasPassed &&
            isOpen &&
            hasEnoughPlayer &&
            hasBalance);
        return (upkeedNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeedNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState),
                i_interval
            );
        }
        //Get a random number
        //use the random number to pick a winner
        //and should be automatically called at a certain time stamp
        s_raffleState = RaffleState.CALCULATING; // change the state to calculating
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        emit requestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, //requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner; // keep track of the the last winner
        s_players = new address payable[](0); // we reset the array for new players to enter.
        s_lastTimeStamp = block.timestamp; // here we reset the block.timestamp to start the clock again immediately after resetting the address array
        s_raffleState = RaffleState.OPEN;
        emit pickedWinner(winner);
        (bool callSuccess, ) = s_recentWinner.call{ //transfer the money to the winner
            value: address(this).balance
        }("");

        if (!callSuccess) {
            revert Raffle_winnerNotPaid();
        }
    }

    /**Getter functions*/
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (uint256) {
        return uint256(s_raffleState);
    }

    function getPlayersLength() external view returns (uint256) {
        return s_players.length;
    }

    function getPlayersIndex(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getUpKeepNeeded() external view returns (bool) {
        (bool upkeedNeeded, ) = checkUpkeep("");
        return upkeedNeeded;
    }
}

//you can also use CEI checks, effect, interaction for gas efficiency in you project, also to protect your project from re entrances attack.
// to your checks first
//then your effects
// last the interactions
