// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IBaseNudgeCampaign.sol";

interface INudgeCampaign is IBaseNudgeCampaign {
    // Errors
    error NotEnoughRewardsAvailable();
    error InactiveCampaign();
    error StartDateNotReached();
    error InvalidCampaignSettings();
    error EmptyClaimArray();
    error HoldingPeriodNotElapsed(uint256 pID);
    error UnauthorizedCaller(uint256 pID);
    error InvalidParticipationStatus(uint256 pID);
    error NativeTokenTransferFailed();
    error EmptyParticipationsArray();
    error InvalidCampaignId();
    error CannotRescueRewardToken();

    // Events
    event ParticipationInvalidated(uint256[] pIDs);
    event RewardsWithdrawn(address to, uint256 amount);
    event FeesCollected(uint256 amount);
    event CampaignStatusChanged(bool isActive);
    event NudgeRewardClaimed(uint256 pID, address userAddress, uint256 rewardAmount);
    event TokensRescued(address token, uint256 amount);

    function collectFees() external returns (uint256);
    function invalidateParticipations(uint256[] calldata pIDs) external;
    function withdrawRewards(uint256 amount) external;
    function setIsCampaignActive(bool isActive) external;
    function claimRewards(uint256[] calldata pIDs) external;
    function rescueTokens(address token) external returns (uint256);

    // View functions
    function getBalanceOfSelf(address token) external view returns (uint256);
    function claimableRewardAmount() external view returns (uint256);
    function getRewardAmountIncludingFees(uint256 toAmount) external view returns (uint256);
    function calculateUserRewardsAndFees(
        uint256 rewardAmountIncludingFees
    ) external view returns (uint256 userRewards, uint256 fees);
    function getCampaignInfo()
        external
        view
        returns (
            uint32 _holdingPeriodInSeconds,
            address _targetToken,
            address _rewardToken,
            uint256 _rewardPPQ,
            uint256 _startTimestamp,
            bool _isCampaignActive,
            uint256 _pendingRewardsIncludingFees,
            uint256 _totalReallocatedAmount,
            uint256 _distributedRewards,
            uint256 _claimableRewards
        );
}