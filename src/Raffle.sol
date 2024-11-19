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

import {VRFConsumerBaseV2} from "chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title Raffle Contract
 * @author Vibhav Sharma
 * @notice This contract is for creating raffles
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2 {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__RaffleNotOpen();
    error Raffle__TransferFailed();

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
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;

    uint32 private constant NUM_WORDS = 1;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;

        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
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

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /*
        1. Get a random number
        2. Use random numebr to pick a winner
        3. Auto Call the pickWinner
    */
    function pickWinner() external {
        // check to see if enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }

        s_raffleState = RaffleState.CALCULATING;

        // Get our random number from Chainlink (The reason we are using Chainlink is to get a random number) as blockchain is a deterministic system How chainlink solves that?
        //  In VRF 2.5 getting RNG is two step process
        //  1. Request a random number
        //  2. Get the random number
    }

    /** Getter Functions */
    function getEntranceFees() public view returns (uint256) {
        return i_entranceFee;
    }
}
