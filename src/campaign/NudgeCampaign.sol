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


/**
 * @notice This function calculates the reward amount the user should receive for a given toAmounts of token
 * taking into account a reward multiplier expressed in parts per quadrillion (PPQ)
 * @param toAmount Amount of tokens
 */
function getRewardAmountIncludingFees(uint256 toAmount) public view returns(uint256){

    // It starts with checking whether both scaling factors are equal to 1. These scaling factors are used 
    // to adjust amounts to a common 18-decimal format.
    if(targetScalingFactor==1&&rewardScalingFactor==1){

        // To calculate the rewards it multiples toAmount with rewardPPQ and then divides with PPQ_DENOMINATOR
        return toAmount.mulDiv(rewardPPQ,PPQ_DENOMINATOR);
    }

    // Next, scale amount to 18 decimals:

    uint256 scaledAmount =  toAmount*targetScalingFactor;
    uint256 rewardAmountIn18Decimals = scaledAmount.mulDiv(rewardPPQ,PPQ_DENOMINATOR);

    // Scale back to reward token decimals
    return rewardAmountIn18Decimals/rewardScalingFactor;
}

/**
 * 
 */
function handleReallocation(
    uint256 campaignId_,
    address userAddress,
    address toToken,
    uint256 toAmount,
    bytes memory data
) external payable whenNotPaused{

    // Check if campaign is active or can be activated
    _validateAndActivateCampaignIfReady();
    // Check if the msg.sender is authorized for swapping
    if(!factory.hasRole(factory.SWAP_CALLER_ROLE(), msg.sender)){
        revert UnauthorizedSwapCaller();
    } 

    //  When toToken is not equal to target token
    if(toToken!=targetToken){
        revert InvalidToTokenRecevied(toToken);
    }

    // When campaignId doesn't match revert is generated
    if(campaignId_!=campaignId){
        revert InvalidCampaignId();
    }

    // The value user will be getting
    uint256 amountReceived;

    // If the token is ETH token then provided value is amountReceived
    if(toToken==NATIVE_TOKEN_ETH){
        amountReceived = msg.value;
    }

    else{
        // If the msg.value is greater than zero then a revert will happen
        if(msg.value>0){
            revert InvalidToTokenRecevied(NATIVE_TOKEN_ETH);
        }
    }

    // Contract instance 
    IERC20 tokenReceived = IERC20(toToken);
    // Getting the balance of the sender
    uint256 balanceOfSender = tokenReceived.balanceOf(msg.sender);
    // Getting the balance of the contract before any transfer happens
    uint256 balanceBefore = getBalanceOfSelf(toToken) ;

    // Is a safe way to transfer ERC20 tokens from msg.sender to address(this),
    // preventing failures due to faulty ERC20 implementations. The contract is 
    // reciving the tokens.
    SafeERC20.safeTransferFrom(tokenReceived, msg.sender, address(this), balanceOfSender);

    // AmountReceived is less than toAmount than revert
    if(amountReceived<toAmount){
        revert InsufficientAmountReceived();
    }

    // This function transfers amountReceived tokens from the contract to userAddress.
    // Even though the contract initially received tokens, they still need to be sent 
    // to the intended recipient. (Think like a swap)
    _transfer(toToken,userAddress,amountReceived);

    // The totalReallocatedAmount keeps tracks of all the funds reallocated to the campaign
    // amountReceived is the amount of tokens that were just received in the transaction and now
    // these are added to the old value of totalReallocatedAmount.
    totalReallocatedAmount+=amountReceived;
    
    // Calculating total rewards including the platform fees
    uint256 rewardsAmountIncludingFees = getRewardAmountIncludingFees(amountReceived);
    // Total Rewards Available to claim
    uint256 rewardsAvailable = claimableRewardAmount();

    // If rewardsAmountIncludingFees is greated than rewardsAvailable then revert
    if(rewardsAmountIncludingFees>rewardsAvailable){
        revert NotEnoughRewardsAvailable();
    }

    // Splitting so total Rewards into two parts: 
       // 1. Rewards that user will receive and fees that associated with the platform
    (uint256 userRewards, uint256 fees) = calculateUserRewardsAndFees(rewardsAmountIncludingFees);

    // pendingRewards updated with users rewards so that it can be claimed later
    pendingRewards+=userRewards;
    // Acculatedfees updated with more fees 
    accumulatedFees+=fees;

    // Increments that participation ID to uniquely track each user's participation
    pID++;

    // Store the participation details
    participations[pID] = Participation({
        status: ParticipationStatus.PARTICIPATING,
        userAddress:userAddress,
        toAmount: amountReceived,
        rewardAmount: userRewards,
        startTimestamp: block.timestamp,
        startBlockNumber: block.number
    });

    emit NewParticipation(campaignId_, userAddress, pID, amountReceived, userRewards, fees, data);


}

/////////////////////////////////////
/////// Admin Functions ////////////
///////////////////////////////////

/**
 * @notice invalidate specifies participants
 * @param pIDs Array of participation
 * @dev only callable by the operator role
 */
function invalidateParticipations(uint256[] calldata pIDs) 
        external onlyNudgeOperator(){

    for(uint256 i=0;i<=pIDs.length;i++){
        // Accesses the Participation struct stored at index pIDs[i]
        Participation storage participation = participations[pIDs[i]];

        // Checks if the participation is already invalid.
        if(participation.status != ParticipationStatus.PARTICIPATING){
            continue;
        }

        // Changes the status from PARTICIPATING to INVALIDATED.
        participation.status = ParticipationStatus.INVALIDATED;
        // Subtracts the invalidated reward from pendingRewards.
        // Ensures the system does not distribute rewards to invalid participations.
        pendingRewards-=participation.rewardAmount;
    }
    emit ParticipationInvalidated(pIDs);

}

/**
 * @notice Allows the campaign admin to withdraw rewards 
 * from the contract ensuring that only available rewards are withdrawn
 * @param amount Amount to withdraw
 */

function withdrawRewards(uint256 amount) external onlyRole(CAMPAIGN_ADMIN_ROLE){
    // claimableRewardAmount: Retrieves the total available rewards that can be withdrawn
    if(amount>claimableRewardAmount()){
         revert NotEnoughRewardsAvailable();
    }
    
    // If alternativeWithdrawalAddress == address(0), rewards go to msg.sender (default).
    // Otherwise, rewards go to alternativeWithdrawalAddress.
    address to = alternativeWithdrawalAddress == address(0) ? msg.sender:alternativeWithdrawalAddress;
    
    // Transfer the tokens
    _transfer(rewardToken, to, amount);
    
    emit RewardsWithdrawn(to, amount);
}


 

/////////////////////////////////////
/////// View Functions ///////////// 
///////////////////////////////////

    /**
     * @notice If the token is ETH we check the contracts balance otherwise 
     * we check the balance for ERC20 
     * @param token Takes the address of the token to get the balance
     */

    function getBalanceOfSelf(address token) public view returns(uint256){
        if(token==NATIVE_TOKEN_ETH){
            return address(this).balance;
        }else{
            return IERC20(token).balanceOf(address(this));
        }
    }

    /**
     * @notice Calls the getBalanceOfSelf function to fetch the current balance of the 
     * 
     * rewardToken in the contract.
     *      If rewardToken is: ETH, it retrieves address(this).balance (contract’s ETH balance). 
     *      An ERC-20 token, it retrieves IERC20(rewardToken).balanceOf(address(this))(contract’s ERC-20 bal).
     * 
     * pendingRewards tracks rewards that have been assigned but not yet claimed by users.Since ,
     * these rewards are reserved, we subtract them from the total balance.
     * 
     * accumalatedFees represents transaction fees or protocol fees collected from rewards.
     * These fees are not meant to be claimable rewards for users.
     */
    function claimableRewardAmount() public view returns(uint256){
        return getBalanceOfSelf(rewardToken) - pendingRewards - accumulatedFees ;
    }

    /**
     * 
     * @param rewardAmountInclusingFees Total rewards including fees
     * @return userRewards  The portion of rewardAmountIncludingFees that goes to the user
     * @return fees The portion Returns as Fees
     */
    function calculateUserRewardsAndFees(uint256 rewardAmountInclusingFees) public view returns(
        uint256 userRewards, uint256 fees
    ) {

        // Gets only the fees amount from the total Rewards
        fees = (rewardAmountInclusingFees*feeBps)/BPS_DENOMINATOR;
        // Calculate userRewards after deducting the totalFees from it
        userRewards = rewardAmountInclusingFees - fees;

    }

    
   /**
    * @notice Returns all the information about the campaign
    * @return _holdingPeriodInSeconds Duration users must hold token
    * @return _targetToken Address of the token user need to hold
    * @return _rewardToken Address of the token used for rewards
    * @return _rewardPPQ Reward parameter in parts per quadrillion
    * @return _startTimestamp  When the campaign becomes active
    * @return _isCampaignActive Whether the campaign is currently active
    * @return _pendingRewards Total rewards pending claim
    * @return _totalReallocatedAmount Total amount of tokens reallocated
    * @return _distributedRewards Total rewards distributed
    * @return _claimableRewards Amount of rewards available for distibution.
    */
    function getCampaignInfo(
        
    ) external view returns(
        uint32 _holdingPeriodInSeconds,
        address _targetToken,
        address _rewardToken,
        uint256 _rewardPPQ,
        uint256 _startTimestamp,
        bool _isCampaignActive,
        uint256 _pendingRewards,
        uint256 _totalReallocatedAmount,
        uint256 _distributedRewards,
        uint256 _claimableRewards) {
         return (
            holdingPeriodInSeconds,
            targetToken,
            rewardToken,
            rewardPPQ,
            startTimestamp,
            isCampaignActive,
            pendingRewards,
            totalReallocatedAmount,
            distributedRewards,
            claimableRewardAmount()
        );
    }

/////////////////////////////////////
/////// Internal Functions /////////
///////////////////////////////////

/**
 * @notice Checks if campaign is active or can be activated based on current timestamp
 */
function _validateAndActivateCampaignIfReady() internal {
    
    if(!isCampaignActive){
    // Only auto-activiate if the campaign is not manually deactiviated and 
    // if the start time has been reached
    if(!_manuallyDeactivated && block.timestamp >=startTimestamp){
        // Automatically activate the campaign if start time is reached
        isCampaignActive=true;
    }else if(block.timestamp<startTimestamp){
        // If startTimestamp is not reached revert
        revert StartDateNotReached();
    }else{
        // If campaign was manually deactivated, revert with InactiveCampaign. 
        revert InactiveCampaign();
    }

    }
}



/**
 * @param token addres of the token to transfer
 * @param to address of the recipient
 * @param amount the amount to transfer
 * 
 */

function _transfer(
    address token,
    address to,
    uint256 amount
) internal{
    // If token is ETH , we use .call to transfer funds. Sends ETH to to using Solidity’s .call() function.
    if(token==NATIVE_TOKEN_ETH){
        // (bool sent,) → Stores whether the transaction was successful (true) or failed (false).
        (bool sent,)=to.call{value:amount}("");
        if(!sent){
            revert NativeTokenTransferFailed();
        }else{
        // Otherwise using safeTransfer to transfer Erc20 funds.
            SafeERC20.safeTransfer(IERC20(token), to, amount);
        }
    }
}

}