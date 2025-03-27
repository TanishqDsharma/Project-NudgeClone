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

using Math for uint256;
using SafeERC20 for IERC20;

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
    uint16 feeBps_,
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


    factory =  InudgeCampaignFactory(msg.sender);
    holdingPeriodInSeconds=holdingPeriodInSeconds_;
    feeBps=feeBps_;
    alternativeWithdrawalAddress=alternativeWithdrawalAddress_;

    
    targetToken=targetToken_;
    rewardToken=rewardToken_;

    campaignId=campaignId_;

    // Compute Scaling Factors based on token decimals

    // This determines the number of decimals for the targetToken_ , if the token is ETH then it assumes
    // 18 decimals else it queries the ERC20 tokens decimals count using the IERC20Metadata function.
    uint256 targetDecimals = targetToken_ == NATIVE_TOKEN_ETH ? 18 : 
    IERC20Metadata(targetToken_).decimals();

    // This determines the number of decimals for the rewardToken_, if the token is ETH then it assumes 18 
    // decimals else it queries the ERC20 tokens decimals count using the IERC20Metadata function.
    
    uint256 rewardDecimals = rewardToken_ == NATIVE_TOKEN_ETH ? 18 : 
    IERC20Metadata(rewardToken_).decimals();

    // Normalizing scaling factor to 18 decimals

    // The below two lines normalize the decimals of both token to 18 decimals. If a token has fewer 
    // than 18 decimals, this scaling factor ensures calculations work correctly by adjusting values 
    // accordingly.

    targetScalingFactor = 10 ** (18-targetDecimals);
    rewardScalingFactor = 10 ** (18-rewardDecimals);

    // This assigns the CAMPAIGN_ADMIN_ROLE to the campaignAdmin address.
    _grantRole(CAMPAIGN_ADMIN_ROLE, campaignAdmin);
    
    // If startTimestamp_ is 0 it assigns the startTimestamp to current block.timestamp otherwise specifies
    // the provided timestamp
    startTimestamp = startTimestamp_ == 0 ? block.timestamp:startTimestamp_;

    // This sets isCampaignActive to true if the campaign's startTimestamp has already passed.
    isCampaignActive = startTimestamp<=block.timestamp;

    rewardPPQ = rewardPPQ_;

    // This initializes _manuallyDeactivated to false, meaning the campaign starts in an active 
    // state unless manually turned off later.
    _manuallyDeactivated = false;
}

   ///////////////////
  //// Modifier /////
 ///////////////////

 ///@notice Ensures the campaign is not paused

 modifier whenNotPaused(){
    // Calls factory.isCampaignPaused(address(this)) to check if the campaign is paused.
    if(factory.isCampaignPaused(address(this))) revert CampaignPaused();
    _;
 }

 /**
  *@notice It ensures that only authorized entities (either the Factory contract itself or Nudge admins)
  can execute certain functions.
 */

 modifier onlyFactoryOrNudgeAdmin(){

    // Checks if the caller (msg.sender) has the NUDGE_ADMIN_ROLE in the factory contract and 
    //  checks if msg.sender is NOT the factory contract.
    if(!factory.hasRole(factory.NUDGE_ADMIN_ROLE(), msg.sender) && msg.sender!= address(factory)){
        revert Unauthorized();
    }
    _;
 }

modifier onlyNudgeOperator() {
    // Checks if the caller (msg.sender) has the NUDGE_OPERATOR_ROLE in the factoru contract
        if (!factory.hasRole(factory.NUDGE_OPERATOR_ROLE(), msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

}