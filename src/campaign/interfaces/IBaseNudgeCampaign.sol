//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.28;


/**
 * This interface defines the core structure for a Nudge Campaign Contract. It provides with
 * errors, structs, events, and functions necessary to manage user participation.
 */

interface IBaseNudgeCampaign {

    // ERRORS

    error CampaignPaused();
    error UnauthorizedSwapCaller();
    error Unauthorized();
    error InsufficientAmountReceived();
    error InvalidToTokenRecevied(address toToken);

    //Enums 

    enum ParticipationStatus {
        PARTICIPATING,
        INVALIDATED,
        CLAIM,
        HANDLED_OFFCHAIN
    }

    // Structs

    struct Participation {
        ParticipationStatus status;
        address userAddress;
        uint256 toAmount;
        uint256 userAmount;
        uint256 startTimstamp;
        uint256 startBlockNumber;
    }

    // Events

    event NewParticipation(
        uint256 indexed campaignId,
        uint256 indexed userAddress,
        uint256 pID,
        uint256 toAmount,
        uint256 entitledRewards,
        uint256 fees,
        bytes data
    );

    // functions

    // // external function
    // function handleReallocation(
    //     uint256 campaignId,
    //     address userAddress,
    //     address toToken,
    //     uint256 toAmount,
    //     bytes memory data
    // ) external payable;

    // // internal function

    // function getBalanceOfSelf(address token) external view returns(uint256);


}