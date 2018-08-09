/*  \Funds\Pfund.sol started 2018.07.11

Escrow management of prepurchase funds in the Pacio DAICO

Owned by Deployer, OpMan, Hub, Sale

Pause/Resume
============
OpMan.PauseContract(PFUND_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(PFUND_CONTRACT_X) IsConfirmedSigner which is a managed op

List.Fallback function
======================
No sending ether to this contract!

*/

pragma solidity ^0.4.24;

import "../lib/OwnedPfund.sol";
import "../lib/Math.sol";
import "../OpMan/I_OpMan.sol";
import "../Funds/I_MfundPfund.sol";

contract Pfund is OwnedPfund, Math {
  string  public name = "Pacio DAICO Prepurchase Escrow Fund";
  uint32  private pState;             // DAICO state using the STATE_ bits. Replicated from Hub on a change
  uint256 private pTotalDepositedWei; // Total wei deposited in Prepurchase escrow before any whitelist transfers or refunds.
  uint256 private pDepositId;    // Deposit Id
  uint256 private pPMtransferId; // P to M transfer Id
  uint256 private pRefundId;     // Id of refund in progress - RefundInfo() call followed by a Refund() caLL
  I_MfundPfund private pMfundC;  // the Mfund contract

  // View Methods
  // ============
  // Pfund.State()  Should be the same as Hub.State()
  function State() external view returns (uint32) {
    return pState;
  }
  // Pfund.FundWei() -- Echoed in Sale View Methods
  function FundWei() external view returns (uint256) {
    return address(this).balance;
  }
  // Pfund.TotalDepositedWei() Total wei deposited in Prepurchase escrow before any whitelist transfers or refunds.
  function TotalDepositedWei() external view returns (uint256) {
    return pTotalDepositedWei;
  }
  // Pfund.DepositId()
  function DepositId() external view returns (uint256) {
    return pDepositId;
  }
  // Pfund.PrepurchaseToManagedFundTransferId()
  function PrepurchaseToManagedFundTransferId() external view returns (uint256) {
    return pPMtransferId;
  }
  // Pfund.RefundId()
  function RefundId() external view returns (uint256) {
    return pRefundId;
  }

  // Events
  // ======
  event InitialiseV();
  event StateChangeV(uint32 PrevState, uint32 NewState);
  event    DepositV(uint256 indexed DepositId,    address indexed Account, uint256 Wei);
  event PMTransferV(uint256 indexed PMtransferId, address indexed Account, uint256 Wei);
  event     RefundV(uint256 indexed RefundId,     address indexed Account, uint256 RefundWei, uint32 RefundBit);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale
  // Owners must first be set by deploy script calls:
  //   Pfund.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   Pfund.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Pfund.ChangeOwnerMO(SALE_OWNER_X, Sale address)

  // Pfund.Initialise()
  // ------------------
  // Called from the deploy script to initialise the Pfund contract
  function Initialise() external IsInitialising {
    pMfundC = I_MfundPfund(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(MFUND_CONTRACT_X));
    iPausedB       =        // make Prepurchase escrow active
    iInitialisingB = false;
    emit InitialiseV();
  }

  // Pfund.StateChange()
  // -------------------
  // Called from Hub.pSetState() on a change of state to replicate the new state setting and take any required actions
  function StateChange(uint32 vState) external IsHubContractCaller {
    emit StateChangeV(pState, vState);
    pState = vState;
  }

  // State changing methods
  // ======================

  // Pfund.Deposit()
  // ---------------
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
    emit PMTransferV(++pPMtransferId, vSenderA, vWei);
  }

  // Pfund.Refund()
  // --------------
  // Called from Hub.pRefund() to perform the actual refund after the Token.Refund() -> List.Refund() calls
  // Hub.pRefund() calls: List.EntryBits()                - for type info
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      here                            - to do the actual refund                                      ********
  // Returns false refunding is complete
  function Refund(uint256 vRefundId, address toA, uint256 vRefundWei, uint32 vRefundBit) external IsHubContractCaller returns (bool) {
    require(vRefundId == pRefundId   // same hub call check                                                                           // /- expected to be true if called as intended
         && (vRefundBit == LE_P_REFUND_ONCE_OFF_B || pState & STATE_S_CAP_MISS_REFUND_B > 0 || pState & STATE_CLOSED_COMBO_B > 0)); // |
    uint256 refundWei = Min(vRefundWei, address(this).balance); // Should not need this but b&b
    toA.transfer(refundWei);
    emit RefundV(pRefundId, toA, refundWei, vRefundBit);
    return address(this).balance == 0 ? false : true; // return false when refunding is complete
  } // End Refund()


  // Pfund Fallback function
  // =======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Pfund contract other than via the defined methods with their testing for valid access
  }

} // End Pfund contract