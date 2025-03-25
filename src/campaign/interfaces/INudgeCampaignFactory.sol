//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.28;

import "@openzeppelin/contracts/access/IAccessControl.sol";

interface InudgeCampaignFactory is IAccessControl {

    //error 

    error ZeroAddress();
    error InvalidTreasuryAddress();
    error InvalidParameter();
    error InvalidCampaign();
    error CampaignAlreadyPaused();
    error CampaignNotPaused();
    error NativeTokenTransferFailed();
    error IncorrectEtherAmount();
    error InvalidFeeSetting();

    // Events

    event CampaignDeployed(
        address indexed campaign,
        address indexed admin,
        address targetToken,
        address rewardToken,
        uint256 startTimestamp,
        uint256 uuid ) ;


    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event CampaignsPaused(address[] campaigns);
    event CampaignUnpaused(address[] campaigns);
    event FeesCollected(address[] campaigns, uint256 totalAmount);
    event FeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);
    
    
    // function

    function NUDGE_ADMIN_ROLE() external view returns(bytes32);
    function NUDGE_OPERATOR_ROLE() external view  returns(bytes32);
    function SWAP_CALLER_ROLE() external view returns(bytes32);
    function NATIVE_TOKEN() external view returns (address);

    function nudgeTreasuryAddress() external view returns (address);
    function isCampaign(address) external view returns (bool);
    function campaignAddresses(uint256) external view returns (address);
    function isCampaignPaused(address) external view returns (bool);

    function deployCampaign(
        uint32 holdingPeriodInSeconds,
        address targetToken,
        address rewardToken,
        uint256 rewardPPQ,
        address campaignAdmin,
        uint256 startTimestamp,
        address alternativeWithdrawalAddress,
        uint256 uuid
    ) external returns (address);

    function deployAndFundCampaign(
        uint32 holdingPeriodInSeconds,
        address targetToken,
        address rewardToken,
        uint256 rewardPPQ,
        address campaignAdmin,
        uint256 startTimestamp,
        address alternativeWithdrawalAddress,
        uint256 initialRewardAmount,
        uint256 uuid
    ) external payable returns (address);

    function getCampaignAddress(
        uint32 holdingPeriodInSeconds,
        address targetToken,
        address rewardToken,
        uint256 rewardPPQ,
        address campaignAdmin,
        uint256 startTimestamp,
        uint16 feeBps,
        address alternativeWithdrawalAddress,
        uint256 uuid
    ) external view returns (address);

    function updateTreasuryAddress(address newTreasury) external;
    function updateFeeSetting(uint16 newFeeBps) external;
    function collectFeesFromCampaigns(address[] calldata campaigns) external;
    function pauseCampaigns(address[] calldata campaigns) external;
    function unpauseCampaigns(address[] calldata campaigns) external;

}