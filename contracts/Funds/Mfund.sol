/*  \Escrow\Escrow.sol started 2018.07.11

Escrow management of funds from whitelisted participants in the Pacio DAICO

Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Admin

Pause/Resume
============
OpMan.PauseContract(ESCROW_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(ESCROW_CONTRACT_X) IsConfirmedSigner which is a managed op

*/

pragma solidity ^0.4.24;

import "../lib/OwnedEscrow.sol";
import "../lib/Math.sol";
import "../OpMan/I_OpMan.sol";
import "../List/I_ListEscrow.sol";
import "../Token/I_TokenEscrow.sol";

contract Escrow is OwnedEscrow, Math {
  uint256 private constant INITIAL_TAP_RATE_ETH_PM = 100; // Initial Tap rate in Ether pm
  uint256 private constant SOFT_CAP_TAP_PC         = 50;  // % of escrow balance to be dispersed on soft cap being reached
  string  public name = "Pacio DAICO Escrow";
  uint32  private pState;             // DAICO state using the STATE_ bits. Replicated from Hub on a change
  uint256 private pTotalDepositedWei; // Total wei deposited in escrow before any withdrawals or refunds. Should == this.balance until the soft cap hit withdrawal
  uint256 private pTerminationPicosIssued; // Token.PicosIssued() when a TerminateRefund starts for proportional calcs
  address private pPclAccountA;       // The PCL account (wallet or multi sig contract) for taps (withdrawals)
  uint256 private pTapRateEtherPm;    // Tap rate in Ether pm e.g. 100
  uint256 private pLastWithdrawT;     // Last withdrawal time, 0 before any withdrawals
  uint256 private pDepositId;         // Deposit Id
  uint256 private pWithdrawId;        // Withdrawal Id
  uint256 private pRefundId;          // Id of refund in progress - RefundInfo() call followed by a Refund() caLL
  bool    private pRefundInProgressB; // to prevent re-entrant refund calls
  I_ListEscrow private pListC;        // the List contract

  // View Methods
  // ============
  // Escrow.State()  Should be the same as Hub.State()
  function State() external view returns (uint32) {
    return pState;
  }
  // Escrow.TotalDepositedWei() Total wei deposited in escrow before any withdrawals or refunds
  function TotalDepositedWei() external view returns (uint256) {
    return pTotalDepositedWei;
  }
  // Escrow.EscrowWei() -- Echoed in Sale View Methods
  function EscrowWei() external view returns (uint256) {
    return address(this).balance;
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
  // Escrow.DepositId()
  function DepositId() external view returns (uint256) {
    return pDepositId;
  }
  // Escrow.WithdrawId()
  function WithdrawId() external view returns (uint256) {
    return pWithdrawId;
  }
  // Escrow.RefundId()
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
    pListC = I_ListEscrow(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(LIST_CONTRACT_X));
  }

  // Escrow.SetPclAccountMO()
  // ------------------------
  // Called by the deploy script when initialising
  //  or manually as Admin as a managed op to set/update the Escrow PCL withdrawal account
  function SetPclAccountMO(address vPclAccountA) external {
    require(iIsInitialisingB() || (iIsAdminCallerB() && I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(ESCROW_SET_PCL_ACCOUNT_MO_X)));
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

  // Escrow.StateChange()
  // --------------------
  // Called from Hub.pSetState() on a change of state to replicate the new state setting and take any required actions
  function StateChange(uint32 vState) external IsHubContractCaller {
    if ((vState & STATE_S_CAP_REACHED_B) > 0 && (pState & STATE_S_CAP_REACHED_B) == 0) {
      // Change of state for Soft Cap being reached
      // Make the soft cap withdrawal
      pWithdraw(safeMul(address(this).balance, SOFT_CAP_TAP_PC) / 100);
      emit SoftCapReachedV();
    }else if ((vState & STATE_TERMINATE_REFUND_B) > 0 && (pState & STATE_TERMINATE_REFUND_B) == 0) {
      // Change of state for STATE_TERMINATE_REFUND_B = A VoteEnd vote has voted to end the project, contributions being refunded. Any of the closes must be set and STATE_OPEN_B unset) will have been set.
      pTerminationPicosIssued = I_TokenEscrow(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(TOKEN_CONTRACT_X)).PicosIssued(); // Token.PicosIssued()
      emit TerminateV(pTerminationPicosIssued);
    }
    emit StateChangeV(pState, vState);
    pState = vState;
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
    emit WithdrawV(++pWithdrawId, pPclAccountA, vWithdrawWei);
  }

  // Escrow.TapAmountWei()
  // ---------------------
  // Private fn to calculate the amount available for taping (withdrawal)
  function TapAmountWei() private view returns(uint256 amountWei) {
    if (pState & STATE_TAPS_OK_B > 0)
      //                          tapRateWeiPerSec = (pTapRateEtherPm * 10**18) / MONTH
      amountWei = Min(safeMul(now - pLastWithdrawT, (pTapRateEtherPm * 10**18) / MONTH), address(this).balance);
  }

  // State changing external methods callable by owners only
  // =======================================================

  // Escrow.Deposit()
  // ----------------
  // Called from:
  // a. Sale.Buy() to transfer the contribution here,     after a                      Sale.pBuy()-> Token.Issue() -> List.Issue() call
  // b. Hub.pPMtransfer() to transfer from Pfund to Mfund after a Sale.PMtransfer() -> Sale.pBuy()-> Token.Issue() -> List.Issue() call
  function Deposit(address vSenderA) external payable IsSaleContractCaller {
    require(iIsSaleContractCallerB() || iIsPfundCallerB(), 'Not Sale or Pfund caller');
    require(pState & STATE_DEPOSIT_OK_COMBO_B > 0, "Deposit to Escrow not allowed");
    pTotalDepositedWei = safeAdd(pTotalDepositedWei, msg.value);
    emit DepositV(++pDepositId, vSenderA, msg.value);
  }

  // Escrow.WithdrawMO()
  // -------------------
  // Is called by Admin to withdraw the available tap as a managed operation
  function WithdrawMO() external IsAdminCaller {
    require(pState & STATE_TAPS_OK_B > 0, 'Tap not available');
    require(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(ESCROW_WITHDRAW_MO_X));
    uint256 withdrawWei = TapAmountWei();
    require(withdrawWei > 0, 'Available withdrawal is 0');
    pWithdraw(withdrawWei);
  }

  // State changing external methods
  // ===============================

  // Escrow.RefundInfo()
  // -------------------
  // Called from Hub.pRefund() for info as part of a refund process:
  // Hub.pRefund() calls: List.EntryTyoe()                - for type info
  //                      Escrow.RefundInfo()             - for refund info: picos, wei and refund bit                    ********
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      Escrow.Refund()                 - to do the actual refund
  function RefundInfo(uint256 vRefundId, address accountA) external IsHubContractCaller returns (uint256 refundPicos, uint256 refundWei, uint32 refundBit) {
    require(!pRefundInProgressB, 'Refund already in Progress'); // Prevent re-entrant calls
    pRefundInProgressB = true;
    pRefundId   = vRefundId;
    refundPicos = pListC.PicosBalance(accountA);
    if (pState & STATE_S_CAP_MISS_REFUND_B > 0) {
      // Soft Cap Miss Refund
      refundWei = pListC.WeiContributed(accountA);
      refundBit = LE_REFUND_ESCROW_S_CAP_MISS_B;
    }else if (pState & STATE_TERMINATE_REFUND_B > 0) {
      // Terminate Refund
    //refundWei =         pTotalDepositedWei * refundPicos / pTerminationPicosIssued;
      refundWei = safeMul(pTotalDepositedWei, refundPicos) / pTerminationPicosIssued;
      refundBit = LE_REFUND_ESCROW_TERMINATION_B;
    }
    if (refundBit > 0)
      refundWei = Min(refundWei, address(this).balance);
  }

  // Escrow.Refund()
  // ---------------
  // Called from Hub.pRefund() to perform the actual refund from Escrow after Token.Refund() -> List.Refund() calls
  // Hub.pRefund() calls: List.EntryTyoe()                - for type info
  //                      Escrow.RefundInfo()             - for refund info: picos, wei and refund bit
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      Escrow.Refund()                 - to do the actual refund                                      ********
  // Returns false refunding is complete
  function Refund(uint256 vRefundId, address toA, uint256 vRefundPicos, uint256 vRefundWei, uint32 vRefundBit) external IsHubContractCaller returns (bool) {
    require(pRefundInProgressB                                                                    // /- all expected to be true if called as intended
         && vRefundId == pRefundId   // same hub call check                                       // |
         && (vRefundBit == LE_REFUND_ESCROW_ONCE_OFF_B || pState & STATE_REFUNDING_COMBO_B > 0)); // |
    uint256 refundWei = Min(vRefundWei, address(this).balance); // Should not need this but b&b
    toA.transfer(refundWei);
    emit RefundV(pRefundId, toA, vRefundPicos, refundWei, vRefundBit);
    pRefundInProgressB = false;
    return address(this).balance == 0 ? false : true; // return false when refunding is complete
  } // End Refund()

  // Escrow Fallback function
  // ========================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Escrow contract other than via the defined methods with their testing for valid access
  }

} // End Escrow contract
