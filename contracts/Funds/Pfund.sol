/*  \Escrow\Pescrow.sol started 2018.07.11

Escrow management of prepurchase funds in the Pacio DAICO
Cases:
• sending when not yet whitelisted -> prepurchase whether sale open or not
• sending when whitelisted but sale is not yet open -> prepurchase

Owned by Deployer, OpMan, Hub, Sale

djh??
• Different owned wo Admin?
• Do issue on white listing with transfer of Eth to Escrow when sale is open

Pause/Resume
============
OpMan.PauseContract(PESCROW_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(PESCROW_CONTRACT_X) IsConfirmedSigner which is a managed op

List.Fallback function
======================
No sending ether to this contract!

*/

pragma solidity ^0.4.24;

import "../lib/OwnedEscrow.sol";
import "../lib/Math.sol";
import "../OpMan/I_OpMan.sol";
import "../List/I_ListEscrow.sol";
import "../Escrow/I_MfundPfund.sol";

contract Pescrow is OwnedEscrow, Math {
  string  public name = "Pacio DAICO Prepurchase Escrow";
  uint32  private pState;             // DAICO state using the STATE_ bits. Replicated from Hub on a change
  uint256 private pTotalDepositedWei; // Total wei deposited in Prepurchase escrow before any whitelist transfers or refunds.
  uint256 private pDepositId;    // Deposit Id
  uint256 private pWhitelistId;  // Whitelisting transfer Id
  uint256 private pRefundId;     // Id of refund in progress - RefundInfo() call followed by a Refund() caLL
  I_ListEscrow private pListC;   // the List contract
  I_MfundPfund private pMfundC;  // the Mfund contract

  // View Methods
  // ============
  // Pescrow.EscrowWei() -- Echoed in Sale View Methods
  function EscrowWei() external view returns (uint256) {
    return address(this).balance;
  }
  // Pescrow.TotalDepositedWei() Total wei deposited in Prepurchase escrow before any whitelist transfers or refunds.
  function TotalDepositedWei() external view returns (uint256) {
    return pTotalDepositedWei;
  }
  // Pescrow.State()  Should be the same as Hub.State()
  function State() external view returns (uint32) {
    return pState;
  }
  // Pescrow.DepositId()
  function DepositId() external view returns (uint256) {
    return pDepositId;
  }
  // Pescrow.WhitelistId()
  function WhitelistId() external view returns (uint256) {
    return pWhitelistId;
  }
  // Pescrow.RefundId()
  function RefundId() external view returns (uint256) {
    return pRefundId;
  }

  // Events
  // ======
  event InitialiseV();
  event StateChangeV(uint32 PrevState, uint32 NewState);
  event DepositV(uint256 indexed DepositId, address indexed Account, uint256 Wei);
  event  RefundV(uint256 indexed RefundId,  address indexed Account, uint256 RefundWei, uint32 RefundBit);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale
  // Owners must first be set by deploy script calls:
  //   Pescrow.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   Pescrow.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Pescrow.ChangeOwnerMO(SALE_OWNER_X, Sale address)

  // Pescrow.Initialise()
  // --------------------
  // Called from the deploy script to initialise the Pescrow contract
  function Initialise() external IsInitialising {
    pListC  = I_ListEscrow(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(LIST_CONTRACT_X));
    pMfundC = I_MfundPfund(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(ESCROW_CONTRACT_X));
    iPausedB       =        // make Prepurchase escrow active
    iInitialisingB = false;
    emit InitialiseV();
  }

  // Pescrow.StateChange()
  // ---------------------
  // Called from Hub.pSetState() on a change of state to replicate the new state setting and take any required actions
  function StateChange(uint32 vState) external IsHubContractCaller {
    emit StateChangeV(pState, vState);
    pState = vState;
  }

  // State changing methods
  // ======================

  // Pescrow.Deposit()
  // -----------------
  // Called from Sale.Buy() for a prepurchase to transfer the contribution for escrow keeping here
  //                        after a List.PrepurchaseDeposit() call to update the list entry
  function Deposit(address vSenderA) external payable IsSaleContractCaller {
    require(pState & STATE_DEPOSIT_OK_COMBO_B > 0, "Deposit to Prepurchase escrow not allowed");
    pTotalDepositedWei = safeAdd(pTotalDepositedWei, msg.value);
    emit DepositV(++pDepositId, vSenderA, msg.value);
  }

  // Pfund.PMTransfer()
  // ------------------
  // a. Hub.Whitelist()  -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pBuy()-> Token.Issue() -> List.Issue() for Pfund to Mfund transfers on whitelisting
  // b. Hub.PMtransfer() -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pBuy()-> Token.Issue() -> List.Issue() for Pfund to Mfund transfers for an entry which was whitelisted and ready prior to opening of the sale which has now happened
  // then finally Hub.pPMtransfer() calls here to transfer the Ether from P to M
  function PMTransfer(address vSenderA, uint256 vWei) external IsHubContractCaller {
    pMfundC.Deposit.value(vWei)(vSenderA); // transfers vWei from Pfund to Mfund
  }

  // Pescrow.Refund()
  // ----------------
  // Called from Hub.pRefund() to perform the actual refund from Escrow after Token.Refund() -> List.Refund() calls
  // Hub.pRefund() calls: List.EntryTyoe()                - for type info
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      Pescrow.Refund()                - to do the actual refund                                      ********
  // Returns false refunding is complete
  function Refund(uint256 vRefundId, address toA, uint256 vRefundWei, uint32 vRefundBit) external IsHubContractCaller returns (bool) {
    require(vRefundId == pRefundId   // same hub call check                                                                           // /- expected to be true if called as intended
         && (vRefundBit == LE_REFUND_PESCROW_ONCE_OFF_B || pState & STATE_S_CAP_MISS_REFUND_B > 0 || pState & STATE_CLOSED_COMBO_B > 0)); // |
    uint256 refundWei = Min(vRefundWei, address(this).balance); // Should not need this but b&b
    toA.transfer(refundWei);
    emit RefundV(pRefundId, toA, refundWei, vRefundBit);
    return address(this).balance == 0 ? false : true; // return false when refunding is complete
  } // End Refund()


  // Pescrow Fallback function
  // =========================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Pescrow contract other than via the defined methods with their testing for valid access
  }

} // End Pescrow contract
