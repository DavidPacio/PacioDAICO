/*  \Escrow\Escrow.sol started 2018.07.11

Escrow management of funds from whitelisted participants in the Pacio DAICO

Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Admin

djh??
• add the push refund function
• destroy refunded PIOs

View Methods
============

State changing methods
======================

Pause/Resume
============
OpMan.PauseContract(ESCROW_X) IsHubCallerOrConfirmedSigner
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
import "../OpMan/I_OpMan.sol";
import "../List/I_ListEscrow.sol";

contract Escrow is OwnedEscrow, Math {
  // Data
  uint256 private constant INITIAL_TAP_RATE_ETH_PM = 100; // Initial Tap rate in Ether pm
  uint256 private constant SOFT_CAP_TAP_PC         = 50;  // % of escrow balance to be dispersed on soft cap being reached
  string  public name = "Pacio DAICO Escrow";
  enum NEscrowState {
    None,              // 0 Not started yet
    SoftCapMissRefund, // 1 Failed to reach soft cap, contributions being refunded
    TerminateRefund,   // 2 A VoteEnd vote has voted to end the project, contributions being refunded
    EscrowClosed,      // 3 Escrow is empty as s result of refunds or withdrawals emptying the pot
    SaleClosed,        // 4 Sale is closed whether by hitting hard cap, out of time, or manually = normal tap operations ok
    PreSoftCap,        // 5 Sale running prior to soft cap          /- deposits ok
    SoftCapReached     // 6 Soft cap reached, initial draw allowed  |
  }
  NEscrowState private pStateN;
  uint256 private pTotalDepositedWei; // Total wei deposited in escrow before any withdrawals or refunds
  uint256 private pTerminationPicosIssued; // Token.PicosIssued() when a TerminateRefund starts for proportional calcs
  address private pPclAccountA;       // The PCL account (wallet or multi sig contract) for taps (withdrawals)
  uint256 private pTapRateEtherPm;    // Tap rate in Ether pm e.g. 100
  uint256 private pLastWithdrawT;     // Last withdrawal time, 0 before any withdrawals
  uint256 private pRefundId;          // Id of refund in progress - RefundInfo() call followed by a Refund() caLL
  bool    private pSoftCapB;          // Set to true when softcap is reached in Sale
  I_ListEscrow private pListC;        // the List contract. Escrow is one of List's owners to allow checking of the Escrow caller.

  // View Methods
  // ============
  // Escrow.TotalDepositedWei() Total wei deposited in escrow before any withdrawals or refunds
  function TotalDepositedWei() external view returns (uint256) {
    return pTotalDepositedWei;
  }
  // Escrow.EscrowWei() -- Echoed in Sale View Methods
  function EscrowWei() external view returns (uint256) {
    return address(this).balance;
  }
  // Escrow.State()
  function State() external view returns (uint8) {
    return uint8(pStateN);
  }
  // Escrow.InitialTapRateEtherPm()
  function InitialTapRateEtherPm() external pure returns (uint256) {
    return INITIAL_TAP_RATE_ETH_PM;
  }
  // Escrow.CurrentTapRateEtherPm()
  function CurrentTapRateEtherPm() external view returns (uint256) {
    return pTapRateEtherPm;
  }
  // Escrow.TapAvailableWei()
  function TapAvailableWei() external view returns (uint256) {
    return TapAmountWei();
  }
  // Escrow.LastWithdrawalTime()
  function LastWithdrawalTime() external view returns (uint256) {
    return pLastWithdrawT;
  }
  // Escrow.TerminationPicosIssued() Token.PicosIssued() when a TerminateRefund starts for proportional calcs
  function TerminationPicosIssued() external view returns (uint256) {
    return pTerminationPicosIssued;
  }
  // Escrow.SoftCapReachedDispersalPercent()
  function SoftCapReachedDispersalPercent() external pure returns (uint256) {
    return SOFT_CAP_TAP_PC;
  }
  // Escrow.PclAccount()
  function PclAccount() external view returns (address) {
    return pPclAccountA;
  }

  // Events
  // ======
  event SetPclAccountV(address PclAccount);
  event StartSaleV(NEscrowState State);
  event SoftCapReachedV(NEscrowState State);
  event EndSaleV(NEscrowState State);
  event TerminateV(NEscrowState State, uint256 TerminationPicosIssued);
  event  DepositV(address indexed Account, uint256 Wei);
  event WithdrawV(address indexed Account, uint256 Wei);
  event RefundV(uint256 indexed RefundId, address indexed Account, uint256 RefundWei);
  event RefundingCompleteV(NEscrowState State);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Admin
  // Owners must first be set by deploy script calls:
  //   Escrow.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   Escrow.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Escrow.ChangeOwnerMO(SALE_OWNER_X, Sale address)
  //   Escrow.ChangeOwnerMO(ESCROW_ADMIN_OWNER_X, PCL hw wallet account address as Admin)

  // Escrow.Initialise()
  // -------------------
  // Called from the deploy script to initialise the Escrow contract
  function Initialise() external IsInitialising {
    pTapRateEtherPm = INITIAL_TAP_RATE_ETH_PM; // 100
    pListC = I_ListEscrow(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(LIST_X));
  }

  // Escrow.SetPclAccountMO()
  // ------------------------
  // Called by the deploy script when initialising
  //  or manually as Admin as a managed op to set/update the Escrow PCL withdrawal account
  function SetPclAccountMO(address vPclAccountA) external {
    require(iIsInitialisingB() || (iIsAdminCallerB() && I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(ESCROW_SET_PCL_ACCOUNT_X)));
    require(vPclAccountA != address(0));
    pPclAccountA = vPclAccountA;
    emit SetPclAccountV(vPclAccountA);
  }

  // Escrow.EndInitialise()
  // ----------------------
  // To be called by the deploy script to end initialising
  function EndInitialising() external IsInitialising {
    iPausedB       =        // make active
    iInitialisingB = false;
  }

  // Escrow.StartSale()
  // ------------------
  // Called from Hub.StartSale()
  function StartSale() external IsHubCaller {
    require(pStateN == NEscrowState.None        // initial start
         || pStateN == NEscrowState.SaleClosed, // a restart
            'Invalid state for Escrow StartSale call');
    pStateN = pSoftCapB ? NEscrowState.SoftCapReached : NEscrowState.PreSoftCap;
    emit StartSaleV(pStateN);
  }

  // EscrowC.SoftCapReached()
  // ------------------------
  // Is called from Hub.SoftCapReached() when soft cap is reached
  function SoftCapReached() external IsHubCaller {
    require(pStateN == NEscrowState.PreSoftCap, 'Invalid state for Escrow Softcap call');
    pStateN = NEscrowState.SoftCapReached;
    pSoftCapB = true;
    // Make the soft cap withdrawal
    pWithdraw(safeMul(address(this).balance, SOFT_CAP_TAP_PC) / 100);
    emit SoftCapReachedV(pStateN);
  }

  // Escrow.EndSale()
  // ----------------
  // Is called from Hub.EndSaleMO() when hard cap is reached, time is up, or the sale is ended manually
  function EndSale() external IsHubCaller {
    pStateN = pSoftCapB ? NEscrowState.SaleClosed         // good end which permits withdrawals
                        : NEscrowState.SoftCapMissRefund; // bad end before soft cap -> refund state
    emit EndSaleV(pStateN);
  }

  // Escrow.Terminate()
  // ------------------
  // Is called from Hub.Terminate() when a VoteEnd vote has voted to end the project, Escrow funds to be refunded in proportion to Picos held
  // Sets state to TerminateRefund and records pTerminationPicosIssued for use in the proportional refund calcs.
  // Hub.Terminate() stops everything except refunds.
  function Terminate(uint256 vPicosIssued) external IsHubCaller { // pTokenC.PicosIssued() is passed
    pStateN = NEscrowState.TerminateRefund; // A VoteEnd vote has voted to end the project, contributions being refunded
    pTerminationPicosIssued = vPicosIssued; // Token.PicosIssued()
    emit TerminateV(pStateN, pTerminationPicosIssued);
  }

  // Private functions
  // =================

  // EscrowC.pWithdraw()
  // -------------------
  // Called here locally to withdraw
  function pWithdraw(uint256 vWithdrawWei) private {
    require(pPclAccountA != address(0), 'PCL account not set'); // must have set the PCL account
    pLastWithdrawT = now;
    pPclAccountA.transfer(vWithdrawWei);
    emit WithdrawV(pPclAccountA, vWithdrawWei);
  }

  // Escrow.TapAmountWei()
  // ---------------------
  // Private fn to calculate the amount available for taping (withdrawal)
  function TapAmountWei() private view returns(uint256 amountWei) {
    if (pStateN == NEscrowState.SaleClosed)
      //                          tapRateWeiPerSec = (pTapRateEtherPm * 10**18) / MONTH
      amountWei = Min(safeMul(now - pLastWithdrawT, (pTapRateEtherPm * 10**18) / MONTH), address(this).balance);
  }

  // State changing external methods callable by owners only
  // =======================================================

  // Escrow.Deposit()
  // ----------------
  // Is called from Sale.Buy() to transfer the contribution for escrow keeping here, after the Issue() call which updates the list entry
  function Deposit(address vSenderA) external payable IsSaleCaller {
    require(pStateN >= NEscrowState.PreSoftCap, "Deposit to Escrow not allowed"); // PreSoftCap or SoftCapReached = Deposits ok
    pTotalDepositedWei = safeAdd(pTotalDepositedWei, msg.value);
    emit DepositV(vSenderA, msg.value);
  }

  // Escrow.WithdrawMO()
  // -------------------
  // Is called by Admin to withdraw the available tap as a managed operation
  function WithdrawMO() external IsAdminCaller {
    require(pStateN == NEscrowState.SaleClosed, "Sale not closed");
    require(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(ESCROW_WITHDRAW_X));
    uint256 withdrawWei = TapAmountWei();
    require(withdrawWei > 0, 'Available withdrawal is 0');
    pWithdraw(withdrawWei);
  }

  // State changing external methods
  // ===============================

  // Escrow.RefundInfo()
  // -------------------
  function RefundInfo(address accountA, uint256 vRefundId) external IsHubCaller returns (uint256 refundWei, uint32 refundBit) {
    pRefundId = vRefundId;
    if (pStateN == NEscrowState.SoftCapMissRefund) {
      refundWei = pListC.WeiContributed(accountA);
      refundBit = REFUND_ESCROW_SOFT_CAP_MISS;
    }else if (pStateN == NEscrowState.TerminateRefund) {
    //refundWei =         pTotalDepositedWei * pListC.PicosBalance(accountA) / pTerminationPicosIssued;
      refundWei = safeMul(pTotalDepositedWei, pListC.PicosBalance(accountA)) / pTerminationPicosIssued;
      refundBit =  REFUND_ESCROW_TERMINATION;
    }
    if (refundBit > 0)
      refundWei = Min(refundWei, address(this).balance);
  }

  // Escrow.Refund()
  // ---------------
  // Called from Hub.pRefund() to perform the actual refund from Escrow after Token.Refund() -> List.Refund() calls
  function Refund(address toA, uint256 vRefundWei, uint256 vRefundId) external IsHubCaller returns (bool) {
    require(vRefundId == pRefundId   // same hub call check
         && (pStateN == NEscrowState.SoftCapMissRefund || pStateN == NEscrowState.TerminateRefund)); // expected to be true if Hub.pRefund() makes the call
    require(vRefundWei <= address(this).balance, 'Refund not available');
    toA.transfer(vRefundWei);
    emit RefundV(pRefundId, toA, vRefundWei);
    if (address(this).balance == 0) { // refunding is complete
      pStateN == NEscrowState.EscrowClosed;
      emit RefundingCompleteV(pStateN);
    }
    return true;
  } // End Refund()

  // Escrow Fallback function
  // ========================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Escrow contract other than via the defined methods with their testing for valid access
  }

} // End Escrow contract

