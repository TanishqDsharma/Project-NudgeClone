//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.28;

import "./IBaseNudgeCampaign.sol";



interface INudgePointsCampaign is IBaseNudgeCampaign {

    // Errors

    error NativeTokenTransferFailed();
    error CampaignAlreadyPaused();
    error CampaignNotPaused();
    error InvalidInputArrayLengths();
    error InvalidTargetToken();
    error CampaignAlreadyExists();

    
    // Events

    event PointsCampaignCreated(uint256 campaignId, uint32 holdingPeriodInSeconds,
     address targetToken);
    event CampaignsPaused(uint256[] campaigns);
    event CampaignsUnpaused(uint256[] campaigns);

    struct Campaign{
        uint32 holdingPeriodInSeconds;
        address targetToken;
        uint256 pID;
        uint256 totalReallocatedAmount;
    }

    function createPointsCampaign(
        uint256[] calldata campaignId,
        uint32  holdingPeriodInSeconds,
        address targetToken
     ) external returns(Campaign memory);
    

    function createdPointsCampaigns(
        uint256[] calldata campaignId,
        uint32[] calldata holdingPeriodInSeconds,
        address[] calldata targetToken
    ) external returns(Campaign[] memory);


    function pauseCampaigns(uint256[] calldata campaigns) external;


}