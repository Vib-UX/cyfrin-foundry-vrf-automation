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

/**
 * @title Raffle Contract
 * @author Vibhav Sharma
 * @notice This contract is for creating raffles
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle {
    error Raffle__SendMoreToEnterRaffle();
    uint256 private immutable i_entranceFees;

    // @dev i_interval time between the lottery in seconds
    uint256 private immutable i_interval;

    uint256 private s_lastTimestamp;

    address payable[] private s_players;

    /* Events */
    event RaffleEntered(address indexed player);

    constructor(uint256 _entranceFees, uint256 _interval) {
        i_entranceFees = _entranceFees;
        i_interval = _interval;
        s_lastTimestamp = block.timestamp;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFees, "Not Enough Eth sent!"); Expensive gas
        /* v8.26*/
        // require(msg.value >= i_entranceFees, SendMoreToEnterRaffle); // Less gas efficient

        /* v8.24*/
        if (msg.value <= i_entranceFees) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        // 1. Make migration easier
        // 2. Make front end indexing easier

        emit RaffleEntered(msg.sender);
    }

    /*
        1. Get a random number
        2. Use random numebr to pick a winner
        3. Auto Call the pickWinner
    */
    function pickWinner() external {
        // check to see if enough time has passed
        if ((block.timestamp - s_lastTimestamp) < i_interval) {
            revert();
        }

        // Get our random number from Chainlink (The reason we are using Chainlink is to get a random number) as blockchain is a deterministic system How chainlink solves that?
        //  In VRF 2.5 getting RNG is two step process
        //  1. Request a random number
        //  2. Get the random number
    }

    /** Getter Functions */
    function getEntranceFees() public view returns (uint256) {
        return i_entranceFees;
    }
}
