/*  \Escrow\Escrow.sol started 2018.07.11

Escrow management of funds from whitelisted participants in the Pacio DAICO

Owned by Deployer, OpMan, Hub, Sale

djh??

View Methods
============

State changing methods
======================

Pause/Resume
============
OpMan.Pause(ESCROW_X) IsConfirmedSigner
OpMan.ResumeContractMO(ESCROW_X) IsConfirmedSigner which is a managed op

List.Fallback function
======================
No sending ether to this contract!

Events
======

*/

pragma solidity ^0.4.24;

import "../lib/OwnedEscrow.sol";
import "../lib/Math.sol";

contract Escrow is OwnedEscrow, Math {
  // Data
  uint256 private constant INITIAL_TAP_RATE_ETH_PM = 100; // Initial Tap rate in Ether pm
  uint256 private constant SOFT_CAP_TAP_PC         = 50;  // % of escrow balance to be dispersed on soft cap being reached
  string  public name = "Pacio DAICO Escrow";
  enum NEscrowState {
    None,            // 0 Not started yet
    SaleRefund,      // 1 Failed to reach soft cap, contributions being refunded
    TerminateRefund, // 2 A VoteEnd vote has voted to end the project, contributions being refunded
    SaleClosed,      // 3 Sale is closed whether by hitting hard cap, out of time, or manually = normal tap operations
    PreSoftCap,      // 4 Sale running prior to soft cap          /- deposits ok
    SoftCapReached   // 5 Soft cap reached, initial draw allowed  |
  }
  NEscrowState public EscrowStateN;
  uint256 private pWeiBalance;     // wei in escrow
  address private pPclAccountA;    // The PCL account (wallet or multi sig contract) for taps (withdrawals)
  uint256 private pTapRateEtherPm; // Tap rate in Ether pm e.g. 100
  uint256 private pLastWithdrawT;  // Last withdrawal time, 0 before any withdrawals

  // uint256 public tap;
  // uint256 public lastWithdrawTime = 0;
  // uint256 public firstWithdrawAmount = 0;

  // event RefundContributor(address tokenHolder, uint256 amountWei, uint256 timestamp);
  // event RefundHolder(address tokenHolder, uint256 amountWei, uint256 tokenAmount, uint256 timestamp);
  // event RefundEnabled(address initiatorAddress);


  // Events
  // ======
  event SetPclAccountV(address PclAccount);
  event  DepositV(address indexed Account, uint256 Wei);
  event WithdrawV(address indexed Account, uint256 Wei);
  event SoftCapReachedV();

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale
  // Owners must first be set by deploy script calls:
  //   Escrow.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   Escrow.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Escrow.ChangeOwnerMO(SALE_OWNER_X, Sale address)

  // Escrow.Initialise()
  // -------------------
  // Called from the deploy script to initialise the Escrow contract
  function Initialise() external IsInitialising {
  //require(EscrowStateN == NEscrowState.None); // can only be called before the sale starts
    pTapRateEtherPm = INITIAL_TAP_RATE_ETH_PM; // 100
    iPausedB       =        // make Escrow active
    iInitialisingB = false;
  }
  // Escrow.StartSale()
  // -----------------
  // Called from Hub.StartSale()
  function StartSale() external IsHubCaller {
    require(EscrowStateN == NEscrowState.None // can only be called before the sale starts
         && pPclAccountA != address(0));      // must have set the PCL account
    EscrowStateN = NEscrowState.PreSoftCap;   // Sale running prior to soft cap
    iPausedB = false; // make Escrow active
  }
  // Escrow.EndSale()
  // ----------------
  // Is called from Hub.EndSale() when hard cap is reached, time is up, or the sale is ended manually
  function EndSale() external IsHubCaller {
    EscrowStateN = NEscrowState.SaleClosed;
    // djh?? to be completed to
  }

  // Escrow.SetPclAccount()
  // ----------------------
  // Fn to be called via Hub.SetPclAccount() to set or change the PCL account to receive funds withdrawn via taps
  function SetPclAccount(address vPclAccountA) external IsHubCaller {
    require(vPclAccountA != address(0));
    pPclAccountA = vPclAccountA;
    emit SetPclAccountV(vPclAccountA);
  }

  // View Methods
  // ============
  // Escrow.WeiInEscrow() -- Echoed in Sale View Methods
  function WeiInEscrow() external view returns (uint256) {
    return pWeiBalance;
  }
  // Escrow.State()
  function State() external view returns (uint8) {
    return uint8(EscrowStateN);
  }
  // Escrow.InitialTapRateEtherPm()
  function InitialTapRateEtherPm() external pure returns (uint256) {
    return INITIAL_TAP_RATE_ETH_PM;
  }
  // Escrow.TapRateEtherPm()
  function TapRateEtherPm() external view returns (uint256) {
    return pTapRateEtherPm;
  }
  // Escrow.LastWithdrawalTime()
  function LastWithdrawalTime() external view returns (uint256) {
    return pLastWithdrawT;
  }
  // Escrow.SoftCapReachedDispersalPercent()
  function SoftCapReachedDispersalPercent() external pure returns (uint256) {
    return SOFT_CAP_TAP_PC;
  }
  // Escrow.PclAccount()
  function PclAccount() external view returns (address) {
    return pPclAccountA;
  }

  // Modifier functions
  // ==================


  // State changing methods
  // ======================

  // Escrow.Deposit()
  // -----------------
  // Is called from Sale.Buy() to transfer the contribution for escrow keeping here, after the Issue() call which updates the list entry
  function Deposit(address vSenderA) external payable IsSaleCaller {
    require(EscrowStateN >= NEscrowState.PreSoftCap, "Deposit to Escrow not allowed"); // PreSoftCap or SoftCapReached = Deposits ok
    pWeiBalance = safeAdd(pWeiBalance, msg.value);
    emit DepositV(vSenderA, msg.value);
  }

  // EscrowC.SoftCapReached()
  // ------------------------
  // Is called from Hub.SoftCapReached() when soft cap is reached
  function SoftCapReached() external IsHubCaller {
    EscrowStateN = NEscrowState.SoftCapReached;
    emit SoftCapReachedV();
    // Make the soft cap withdrawal
    pWithdraw(safeMul(pWeiBalance, SOFT_CAP_TAP_PC) / 100);
  }

  // EscrowC.pWithdraw()
  // ------------------
  // Called here locally to withdraw
  function pWithdraw(uint256 vWithdrawWei) private {
    pPclAccountA.transfer(vWithdrawWei); // throws on failure
    pWeiBalance = subMaxZero(pWeiBalance, vWithdrawWei);
    pLastWithdrawT = now;
    emit WithdrawV(pPclAccountA, vWithdrawWei);
  }


  // Escrow Fallback function
  // ========================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Escrow contract other than via the defined methods with their testing for valid access
  }

} // End Escrow contract
