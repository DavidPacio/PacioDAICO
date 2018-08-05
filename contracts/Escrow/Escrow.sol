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
import "../List/I_TokenEscrow.sol";

contract Escrow is OwnedEscrow, Math {
  uint256 private constant INITIAL_TAP_RATE_ETH_PM = 100; // Initial Tap rate in Ether pm
  uint256 private constant SOFT_CAP_TAP_PC         = 50;  // % of escrow balance to be dispersed on soft cap being reached
  string  public name = "Pacio DAICO Escrow";
  uint32  private pState;             // DAICO state using the STATE_ bits. Replicated from Hub on a change
  uint256 private pTotalDepositedWei; // Total wei deposited in escrow before any withdrawals or refunds
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
  // Escrow.TotalDepositedWei() Total wei deposited in escrow before any withdrawals or refunds
  function TotalDepositedWei() external view returns (uint256) {
    return pTotalDepositedWei;
  }
  // Escrow.EscrowWei() -- Echoed in Sale View Methods
  function EscrowWei() external view returns (uint256) {
    return address(this).balance;
  }
  // Escrow.State()  Should be the same as Hub.State()
  function State() external view returns (uint32) {
    return pState;
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
  event EndSaleV(NEscrowState State);
  event TerminateV(NEscrowState State, uint256 TerminationPicosIssued);
  event  DepositV(uint256 indexed DepositId,  address indexed Account, uint256 Wei);
  event WithdrawV(uint256 indexed WithdrawId, address Account, uint256 Wei);
  event   RefundV(uint256 indexed RefundId,   address indexed Account, uint256 RefundWei);
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
  function StateChange(vState) external IsHubContractCaller {
    if ((vState & STATE_S_CAP_REACHED_B) > 0 && (pState & STATE_S_CAP_REACHED_B) == 0) {
      // Change of state for Soft Cap being reached
      // Make the soft cap withdrawal
      pWithdraw(safeMul(address(this).balance, SOFT_CAP_TAP_PC) / 100);
      emit SoftCapReachedV();
    }else ((vState & STATE_TERMINATE_REFUND_B) > 0 && (pState & STATE_TERMINATE_REFUND_B) == 0) {
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
    if (pStateN == NEscrowState.SaleClosed)
      //                          tapRateWeiPerSec = (pTapRateEtherPm * 10**18) / MONTH
      amountWei = Min(safeMul(now - pLastWithdrawT, (pTapRateEtherPm * 10**18) / MONTH), address(this).balance);
  }

  // State changing external methods callable by owners only
  // =======================================================

  // Escrow.Deposit()
  // ----------------
  // Is called from Sale.Buy() to transfer the contribution for escrow keeping here, after the Issue() call which updates the list entry
  function Deposit(address vSenderA) external payable IsSaleContractCaller {
    require(pStateN >= NEscrowState.PreSoftCap, "Deposit to Escrow not allowed"); // PreSoftCap or SoftCapReached = Deposits ok
    pTotalDepositedWei = safeAdd(pTotalDepositedWei, msg.value);
    emit DepositV(++pDepositId, vSenderA, msg.value);
  }

  // Escrow.WithdrawMO()
  // -------------------
  // Is called by Admin to withdraw the available tap as a managed operation
  function WithdrawMO() external IsAdminCaller {
    require(pStateN == NEscrowState.SaleClosed, "Sale not closed");
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
  //                      Escrow/Grey.RefundInfo()        - for refund info: amount and refund bit                    ********
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      Escrow/Grey.Refund()            - to do the actual refund
  function RefundInfo(address accountA, uint256 vRefundId) external IsHubContractCaller returns (uint256 refundWei, uint32 refundBit) {
    require(!pRefundInProgressB, 'Refund already in Progress'); // Prevent re-entrant calls
    pRefundInProgressB = true;
    pRefundId = vRefundId;
    if (pStateN == NEscrowState.SoftCapMissRefund) {
      refundWei = pListC.WeiContributed(accountA);
      refundBit = LE_REFUND_ESCROW_S_CAP_MISS_B;
    }else if (pStateN == NEscrowState.TerminateRefund) {
    //refundWei =         pTotalDepositedWei * pListC.PicosBalance(accountA) / pTerminationPicosIssued;
      refundWei = safeMul(pTotalDepositedWei, pListC.PicosBalance(accountA)) / pTerminationPicosIssued;
      refundBit =  LE_REFUND_ESCROW_TERMINATION_B;
    }
    if (refundBit > 0)
      refundWei = Min(refundWei, address(this).balance);
  }

  // Escrow.Refund()
  // ---------------
  // Called from Hub.pRefund() to perform the actual refund from Escrow after Token.Refund() -> List.Refund() calls
  // Hub.pRefund() calls: List.EntryTyoe()                - for type info
  //                      Escrow/Grey.RefundInfo()        - for refund info: amount and refund bit
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      Escrow/Grey.Refund()            - to do the actual refund                                      ********
  function Refund(address toA, uint256 vRefundWei, uint256 vRefundId) external IsHubContractCaller returns (bool) {
    require(pRefundInProgressB                                                                       // /- all expected to be true if called as intended
         && vRefundId == pRefundId   // same hub call check                                          // |
         && (pStateN == NEscrowState.SoftCapMissRefund || pStateN == NEscrowState.TerminateRefund)); // |
    require(vRefundWei <= address(this).balance, 'Refund not available');
    toA.transfer(vRefundWei);
    emit RefundV(pRefundId, toA, vRefundWei);
    if (address(this).balance == 0) { // refunding is complete
      pStateN == NEscrowState.EscrowClosed;
      emit RefundingCompleteV(pStateN);
    }
    pRefundInProgressB = false;
    return true;
  } // End Refund()

  // Escrow Fallback function
  // ========================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Escrow contract other than via the defined methods with their testing for valid access
  }

} // End Escrow contract

