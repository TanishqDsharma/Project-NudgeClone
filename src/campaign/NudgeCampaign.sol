//SPDX-License-Identifier: MIT
pragma solidity  ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {INudgeCampaign} from "./interfaces/INudgeCampaign.sol";
import "./interfaces/INudgeCampaignFactory.sol";


contract NudgeCampaign is INudgeCampaign,AccessControl{

// Defines unique role identifer for the campaign identifier. This keccak256 computes a 
// unique hash and later its used as an identifier for access control.
    bytes32 public constant CAMPAIGN_ADMIN_ROLE = keccak256("CAMPAIGN_ADMIN_ROLE");
    

// Used for percentage calculation in basis points
    uint256 private constant BPS_DENOMINATOR=10_000;

// Denominator in parts per quadrillion, this allows finer granularity in dividing rewards.

    uint256 PPQ_DENOMINATOR = 1e15;

// Special Address for Native Token Eth

    address public constant NATIVE_TOKEN_ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

// Factory Reference

InudgeCampaignFactory public immutable factory;

// Campaign Configuration

// Defines how long the campaign lasts in seconds.
uint32 public immutable holdingPeriodInSeconds;
address public immutable targetToken;
address public immutable rewardToken;
// Stores reward distribution in parts per quadrillion (PPQ).
uint256 public immutable rewardPPQ;
//Stores the campaign start time in timestamp format.
uint256 public immutable startTimestamp;
// Alternative address where campaign funds can be withdrawn.
address public immutable alternativeWithdrawalAddress;

// Fee parameter in basis points

uint16 public feeBps;
bool public isCampaignActive;

// Stores a unique identifier for this campaign.
uint256 public immutable campaignId;

// Scaling Factors Decimal Normalization:Adjusts token amounts to a standard 18-decimal format.
uint256 public immutable targetScalingFactor;
uint256 public immutable rewardScalingFactor;

// Campaign State

uint256 public pID;
uint256 public pendingRewards;
uint256 public totalReallocatedAmount;
uint256 public accumulatedFees;
uint256 public distributedRewards;

bool private _manuallyDeactivated;
// Participations

mapping(uint256 pID => Participation) public participations;


 // @notice created a new campaign with specified parameters
 // @param holdingPeriodInSeconds_ Durations users must hold token
 //  @param targetToken_ Address of token users need to hold
 // @param rewardToken_ Address of token used for rewards
 // @param rewardPPQ_ Amount reward tokens earned for participating in the campaign, 
 // in parts per quadrillion
 // @param campaignAdmin Address granted campaign role
 // @param startTimestamp_ When the campaign becomes active
 // @param feeBps_ Nudge's fee percentage in basis points
 // @param alternativeWithdrawalAddress_ Optional alternative address for 
 // withdrwaing unallocated rwards
 //  @param campaignId_ Uniq Identifier for the campaign
 //
constructor(
    uint32 holdingPeriodInSeconds_,
    address targetToken_,
    address rewardToken_,
    uint256 rewardPPQ_,
    address campaignAdmin,
    uint256 startTimestamp_,
    uint256 feeBps_,
    address alternativeWithdrawalAddress_,
    uint256 campaignId_
){
// If rewardToken address is zero or campaignAdmin address is zero then revert will happen
    if(rewardToken_==address(0)||campaignAdmin==address(0)){
        revert InvalidCampaignSettings();
    }
// If startTimestamp is not equal to zero and  less than block.timestamp  then revert will happen
    if(startTimestamp_!=0 && startTimestamp_<=block.timestamp){
        revert InvalidCampaignSettings();
    }
// Creates new contract instance and returns the address which can the be used as an instance
// of the interface
    factory = new InudgeCampaignFactory(msg.sender);
    holdingPeriodInSeconds=holdingPeriodInSeconds_;
    feeBps=feeBps_;
    alternativeWithdrawalAddress=alternativeWithdrawalAddress_;

    
    targetToken=targetToken_;
    rewardToken=rewardToken_;

    campaignId=campaignId_;

    // Compute Scaling Factors based on token decimals

    uint256 targetDecimals = targetToken_ == NATIVE_TOKEN_ETH ? 18 : 
    IERC20Metadata(targetToken_).decimals();

    uint256 rewardDecimals = rewardToken_ == NATIVE_TOKEN_ETH ? 18 : 
    IERC20Metadata(rewardToken_).decimals();

    // Normalizing scaling factor to 18 decimals

    targetScalingFactor = 10 ** (18-targetDecimals);
    rewardScalingFactor = 10 ** (18-rewardDecimals);

    _grantRole(CAMPAIGN_ADMIN_ROLE, campaignAdmin);

    startTimestamp = startTimestamp_ == 0 ? block.timestamp:startTimestamp_;

    isCampaignActive = startTimestamp<=block.timestamp;


    _manuallyDeactivated = false;


        


}


}