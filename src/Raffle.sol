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
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {AutomationCompatibleInterface} from "chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {VRFV2PlusClient} from "chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * @title Raffle Contract
 * @author Vibhav Sharma
 * @notice This contract is for creating raffles
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();
    error Raffle__TransferFailed();
    error Raffle__UpkeepNotNeeded(uint256, uint256, uint256);

    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State Variables */
    uint256 private immutable i_entranceFee;

    // @dev i_interval time between the lottery in seconds
    uint256 private immutable i_interval;

    uint256 private s_lastTimeStamp;

    address payable[] private s_players;
    address payable private s_recentWinner;

    // Chainlink VRF related variables
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;

    uint32 private constant NUM_WORDS = 1;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event PickedWinner(address winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

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
        s_lastTimeStamp = block.timestamp;

        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not Enough Eth sent!"); Expensive gas
        /* v8.26*/
        // require(msg.value >= i_entranceFee, SendMoreToEnterRaffle); // Less gas efficient

        /* v8.24*/
        if (msg.value <= i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        // 1. Make migration easier
        // 2. Make front end indexing easier

        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to be true
     * the following should be true for this to return true
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. There are players registered.
     * 5. Implicity, your subscription is funded with LINK.
     */
    function checkUpkeep(
        bytes memory
    ) public view returns (bool upkeepNeeded, bytes memory) {
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool timePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = isOpen && timePassed && hasPlayers && hasBalance;
        return (upkeepNeeded, "0x0");
    }

    // 1. Get a random number
    // 2. Use the random number to pick a player
    // 3. Automatically called
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        // Will revert if subscription is not set and funded.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(req);
        emit RequestedRaffleWinner(requestId);
    }

    // CEI: Checks, Effects and Interactions Pattern to avoid reentrancy attacks
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        // Checks

        // Effect (Internal Contract States)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        // Resetting the s_players as lottery is decided for this round
        s_players = new address payable[](0);

        // Updating the lastTimeStamp, For fresh instance start
        s_lastTimeStamp = block.timestamp;

        emit PickedWinner(winner);
        // Interactions (External Contracts Interactions)
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFees() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
