/*  \Funds\Mfund.sol started 2018.07.11

Managed fund for PIO purchases or transfers in the Pacio DAICO

Owned by Deployer OpMan Hub Sale Poll Pfund Admin

Pause/Resume
============
OpMan.PauseContract(MFUND_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(MFUND_CONTRACT_X) IsConfirmedSigner which is a managed op

*/

pragma solidity ^0.4.24;

import "../lib/OwnedMfund.sol";
import "../lib/Math.sol";
import "../OpMan/I_OpMan.sol";
import "../List/I_ListMfund.sol";
import "../Token/I_TokenMfund.sol";

contract Mfund is OwnedMfund, Math {
  string  public name = "Pacio DAICO Managed Fund";
  uint256 private pTapRateEtherPm     = 100; // Tap rate in Ether per month starting at 100.                 Can be changed by a POLL_CHANGE_TAP_RATE_N poll. Can be changed to 0 to pause withdrawals
  uint256 private pSoftCapDispersalPc =  50; // % of fund balance to be dispersed on soft cap being reached. Can be changed by a POLL_CHANGE_S_CAP_DISP_PC_N poll
  uint32  private pState;             // DAICO state using the STATE_ bits. Replicated from Hub on a change
  uint256 private pTotalDepositedWei; // Total wei deposited before any withdrawals or refunds. Should == this.balance until the soft cap hit withdrawal
  uint256 private pTerminationPicosIssued; // Token.PicosIssued() when a TerminateRefund starts for proportional calcs
  address private pPclAccountA;       // The PCL account (wallet or multi sig contract) for taps (withdrawals)
  uint256 private pLastWithdrawT;     // Last withdrawal time, 0 before any withdrawals
  uint256 private pDepositId;         // Deposit Id
  uint256 private pWithdrawId;        // Withdrawal Id
  uint256 private pRefundId;          // Id of refund in progress - RefundInfo() call followed by a Refund() caLL
  bool    private pRefundInProgressB; // to prevent re-entrant refund calls
  I_ListMfund private pListC;         // the List contract

  // View Methods
  // ============
  // Mfund.DaicoState() Should be the same as Hub.DaicoState()
  function DaicoState() external view returns (uint32) {
    return pState;
  }
  // Mfund.TotalDepositedWei() Total wei deposited before any withdrawals or refunds
  function TotalDepositedWei() external view returns (uint256) {
    return pTotalDepositedWei;
  }
  // Mfund.FundWei() -- Echoed in Sale View Methods
  function FundWei() external view returns (uint256) {
    return address(this).balance;
  }
  // Mfund.TapRateEtherPm()
  function TapRateEtherPm() external view returns (uint32) {
    return uint32(pTapRateEtherPm);
  }
  // Mfund.TapAvailableWei()
  function TapAvailableWei() external view returns (uint256) {
    return TapAmountWei();
  }
  // Mfund.LastWithdrawalTime()
  function LastWithdrawalTime() external view returns (uint256) {
    return pLastWithdrawT;
  }
  // Mfund.TerminationPicosIssued() Token.PicosIssued() when a TerminateRefund starts for proportional calcs
  function TerminationPicosIssued() external view returns (uint256) {
    return pTerminationPicosIssued;
  }
  // Mfund.SoftCapReachedDispersalPercent()
  function SoftCapReachedDispersalPercent() external view returns (uint256) {
    return pSoftCapDispersalPc;
  }
  // Mfund.PclAccount()
  function PclAccount() external view returns (address) {
    return pPclAccountA;
  }
  // Mfund.DepositId()
  function DepositId() external view returns (uint256) {
    return pDepositId;
  }
  // Mfund.WithdrawId()
  function WithdrawId() external view returns (uint256) {
    return pWithdrawId;
  }
  // Mfund.RefundId()
  function RefundId() external view returns (uint256) {
    return pRefundId;
  }

  // Events
  // ======
  event StateChangeV(uint32 PrevState, uint32 NewState);
  event SetPclAccountV(address PclAccount);
  event SoftCapReachedV();
  event TerminateV(uint256 TerminationPicosIssued);
  event  DepositV(uint256 indexed DepositId,  address indexed Account, uint256 Wei);
  event WithdrawV(uint256 indexed WithdrawId, address Account, uint256 Wei);
  event   RefundV(uint256 indexed RefundId,   address indexed To, uint256 RefundPicos, uint256 RefundWei, uint32 Bit);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by Deployer OpMan Hub Sale Poll Pfund Admin
  // Owners must first be set by deploy script calls:
  //   Mfund.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   Mfund.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Mfund.ChangeOwnerMO(SALE_OWNER_X, Sale address)
  //   Mfund.ChangeOwnerMO(POLL_OWNER_X, Poll address)
  //   Mfund.ChangeOwnerMO(MFUND_PFUND_OWNER_X, Pfund address)
  //   Mfund.ChangeOwnerMO(MFUND_ADMIN_OWNER_X, PCL hw wallet account address as Admin)

  // Mfund.Initialise()
  // ------------------
  // Called from the deploy script to initialise the Mfund contract
  function Initialise() external IsInitialising {
    pListC = I_ListMfund(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(LIST_CONTRACT_X));
  }

  // Mfund.SetPclAccountMO()
  // -----------------------
  // Called by the deploy script when initialising
  //  or manually as Admin as a managed op to set/update the PCL withdrawal account
  function SetPclAccountMO(address vPclAccountA) external {
    require(iIsInitialisingB() || (iIsAdminCallerB() && I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(MFUND_SET_PCL_ACCOUNT_MO_X)));
    require(vPclAccountA != address(0));
    pPclAccountA = vPclAccountA;
    emit SetPclAccountV(vPclAccountA);
  }

  // Mfund.EndInitialise()
  // ---------------------
  // To be called by the deploy script to end initialising
  function EndInitialising() external IsInitialising {
    iPausedB       =        // make active
    iInitialisingB = false;
  }

  // Mfund.StateChange()
  // -------------------
  // Called from Hub.pSetState() on a change of state to replicate the new state setting and take any required actions
  function StateChange(uint32 vState) external IsHubContractCaller {
    if (vState & STATE_S_CAP_REACHED_B > 0 && pState & STATE_S_CAP_REACHED_B == 0) {
      // Change of state for Soft Cap being reached
      // Make the soft cap withdrawal
      pWithdraw(safeMul(address(this).balance, pSoftCapDispersalPc) / 100);
      emit SoftCapReachedV();
    }else if ((vState & STATE_TERMINATE_REFUND_B) > 0 && (pState & STATE_TERMINATE_REFUND_B) == 0) {
      // Change of state for STATE_TERMINATE_REFUND_B = A Terminate poll has voted to end the project, contributions being refunded. Any of the closes must be set and STATE_OPEN_B unset) will have been set.
      pTerminationPicosIssued = I_TokenMfund(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(TOKEN_CONTRACT_X)).PicosIssued(); // Token.PicosIssued()
      emit TerminateV(pTerminationPicosIssued);
    }
    emit StateChangeV(pState, vState);
    pState = vState;
  }

  // Private functions
  // =================

  // Mfund.pWithdraw()
  // -----------------
  // Called here locally to withdraw
  function pWithdraw(uint256 vWithdrawWei) private {
    require(pPclAccountA != address(0), 'PCL account not set'); // must have set the PCL account
    pLastWithdrawT = now;
    pPclAccountA.transfer(vWithdrawWei);
    emit WithdrawV(++pWithdrawId, pPclAccountA, vWithdrawWei);
  }

  // Mfund.TapAmountWei()
  // --------------------
  // Private fn to calculate the amount available for taping (withdrawal)
  function TapAmountWei() private view returns(uint256 amountWei) {
    if (pState & STATE_TAPS_OK_B > 0)
      //                          tapRateWeiPerSec = (pTapRateEtherPm * 10**18) / MONTH
      amountWei = Min(safeMul(now - pLastWithdrawT, (pTapRateEtherPm * 10**18) / MONTH), address(this).balance);
  }

  // State changing external methods callable by owners only
  // =======================================================

  // Mfund.Deposit()
  // ---------------
  // Called from:
  // a. Sale.Buy() to transfer the contribution here,    after a                      Sale.pBuy()-> Token.Issue() -> List.Issue() call
  // b. Hub.pPMtransfer() to transfer from Pfund to here after a Sale.PMtransfer() -> Sale.pBuy()-> Token.Issue() -> List.Issue() call
  function Deposit(address vSenderA) external payable IsSaleContractCaller {
    require(iIsSaleContractCallerB() || iIsPfundContractCallerB(), 'Not Sale or Pfund caller');
    require(pState & STATE_DEPOSIT_OK_COMBO_B > 0, "Deposit not allowed");
    pTotalDepositedWei = safeAdd(pTotalDepositedWei, msg.value);
    emit DepositV(++pDepositId, vSenderA, msg.value);
  }

  // Mfund.WithdrawMO()
  // ------------------
  // Is called by Admin to withdraw the available tap as a managed operation
  function WithdrawMO() external IsAdminCaller {
    require(pState & STATE_TAPS_OK_B > 0, 'Tap not available');
    require(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(MFUND_WITHDRAW_MO_X));
    uint256 withdrawWei = TapAmountWei();
    require(withdrawWei > 0, 'Available withdrawal is 0');
    pWithdraw(withdrawWei);
  }

  // State changing external methods
  // ===============================

  // Mfund.RefundInfo()
  // ------------------
  // Called from Hub.pRefund() for info as part of a refund process:
  // Hub.pRefund() calls: List.EntryBits()                - for type info
  //                      Mfund.RefundInfo()              - for refund info: picos, wei and refund bit                    ********
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      Mfund.Refund()                  - to do the actual refund
  function RefundInfo(uint256 vRefundId, address accountA) external IsHubContractCaller returns (uint256 refundPicos, uint256 refundWei, uint32 refundBit) {
    require(!pRefundInProgressB, 'Refund already in Progress'); // Prevent re-entrant calls
    pRefundInProgressB = true;
    pRefundId   = vRefundId;
    refundPicos = pListC.PicosBalance(accountA);
    if (pState & STATE_S_CAP_MISS_REFUND_B > 0) {
      // Soft Cap Miss Refund
      // Hub.pRefund() does not make the call for a presale entry
      refundWei = pListC.WeiContributed(accountA);
      refundBit = LE_MNP_REFUND_S_CAP_MISS_B; // Mfund but not presale Refund due to soft cap not being reached
    }else if (pState & STATE_TERMINATE_REFUND_B > 0) {
      // Terminate Refund
    //refundWei =         pTotalDepositedWei * refundPicos / pTerminationPicosIssued;
      refundWei = safeMul(pTotalDepositedWei, refundPicos) / pTerminationPicosIssued;
      refundBit = LE_M_REFUND_TERMINATION_B;
    }
    if (refundBit > 0)
      refundWei = Min(refundWei, address(this).balance);
  }

  // Mfund.Refund()
  // --------------
  // Called from Hub.pRefund() to perform the actual refund after the Token.Refund() -> List.Refund() calls
  // Hub.pRefund() calls: List.EntryBits()                - for type info
  //                      Mfund.RefundInfo()              - for refund info: picos, wei and refund bit
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      here                            - to do the actual refund                                      ********
  // Returns false if refunding is complete
  function Refund(uint256 vRefundId, address toA, uint256 vRefundPicos, uint256 vRefundWei, uint32 vRefundBit) external IsHubContractCaller returns (bool) {
    require(pRefundInProgressB                                                                    // /- all expected to be true if called as intended
         && vRefundId == pRefundId   // same hub call check                                       // |
         && (vRefundBit == LE_M_REFUND_ONCE_OFF_B || pState & STATE_REFUNDING_COMBO_B > 0)); // |
    uint256 refundWei = Min(vRefundWei, address(this).balance); // Should not need this but b&b
    toA.transfer(refundWei);
    emit RefundV(pRefundId, toA, vRefundPicos, refundWei, vRefundBit);
    pRefundInProgressB = false;
    return address(this).balance == 0 ? false : true; // return false when refunding is complete
  } // End Refund()

  // Mfund Fallback function
  // =======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Mfund contract other than via the defined methods with their testing for valid access
  }

} // End Mfund contract
