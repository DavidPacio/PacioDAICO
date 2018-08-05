/*  \Escrow\Grey.sol started 2018.07.11

Escrow management of funds from grey listed participants in the Pacio DAICO

Owned by Deployer, OpMan, Hub, Sale

djh??
• Different owned wo Admin?
• Do issue on white listing with transfer of Eth to Escrow

View Methods
============

State changing methods
======================

Pause/Resume
============
OpMan.PauseContract(GREY_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(GREY_CONTRACT_X) IsConfirmedSigner which is a managed op

List.Fallback function
======================
No sending ether to this contract!

Events
=====

*/

pragma solidity ^0.4.24;

import "../lib/OwnedEscrow.sol";
import "../lib/Math.sol";
import "../OpMan/I_OpMan.sol";
import "../List/I_ListEscrow.sol";

contract Grey is OwnedEscrow, Math {
  string  public name = "Pacio DAICO Grey List Escrow";
  uint32  private pState;             // DAICO state using the STATE_ bits. Replicated from Hub on a change
  uint256 private pTotalDepositedWei; // Total wei deposited in Grey escrow before any white list transfers or refunds.
  uint256 private pDepositId;    // Deposit Id
  uint256 private pWhitelistId;  // Whitelisting transfer Id
  uint256 private pRefundId;     // Id of refund in progress - RefundInfo() call followed by a Refund() caLL
  I_ListEscrow private pListC;   // the List contract

  // View Methods
  // ============
  // Grey.EscrowWei() -- Echoed in Sale View Methods
  function EscrowWei() external view returns (uint256) {
    return address(this).balance;
  }
  // Grey.TotalDepositedWei() Total wei deposited in Grey escrow before any white list transfers or refunds.
  function TotalDepositedWei() external view returns (uint256) {
    return pTotalDepositedWei;
  }
// Grey.State()  Should be the same as Hub.State()
  function State() external view returns (uint32) {
    return pState;
  }
  // Grey.DepositId()
  function DepositId() external view returns (uint256) {
    return pDepositId;
  }
  // Grey.WhitelistId()
  function WhitelistId() external view returns (uint256) {
    return pWhitelistId;
  }
  // Grey.RefundId()
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
  //   Grey.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   Grey.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Grey.ChangeOwnerMO(SALE_OWNER_X, Sale address)

  // Grey.Initialise()
  // -----------------
  // Called from the deploy script to initialise the Grey contract
  function Initialise() external IsInitialising {
    pListC  = I_ListEscrow(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(LIST_CONTRACT_X));
    iPausedB       =        // make Grey Escrow active
    iInitialisingB = false;
    emit InitialiseV();
  }

  // Grey.StateChange()
  // ------------------
  // Called from Hub.pSetState() on a change of state to replicate the new state setting and take any required actions
  function StateChange(uint32 vState) external IsHubContractCaller {
    emit StateChangeV(pState, vState);
    pState = vState;
  }

  // State changing methods
  // ======================

  // Grey.Deposit()
  // --------------
  // Called from Sale.Buy() for a grey list case to transfer the contribution for escrow keeping here
  //                        after a List.GreyDeposit() call to update the list entry
  function Deposit(address vSenderA) external payable IsSaleContractCaller {
    require(pState & STATE_DEPOSIT_OK_COMBO_B > 0, "Deposit to Grey Escrow not allowed");
    pTotalDepositedWei = safeAdd(pTotalDepositedWei, msg.value);
    emit DepositV(++pDepositId, vSenderA, msg.value);
  }

  // Grey.Refund()
  // -------------
  // Called from Hub.pRefund() to perform the actual refund from Escrow after Token.Refund() -> List.Refund() calls
  // Hub.pRefund() calls: List.EntryTyoe()                - for type info
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      Grey.Refund()                   - to do the actual refund                                      ********
  // Returns false refunding is complete
  function Refund(uint256 vRefundId, address toA, uint256 vRefundWei, uint32 vRefundBit) external IsHubContractCaller returns (bool) {
    require(vRefundId == pRefundId   // same hub call check                                                                           // /- expected to be true if called as intended
         && (vRefundBit == LE_REFUND_GREY_ONCE_OFF_B || pState & STATE_S_CAP_MISS_REFUND_B > 0 || pState & STATE_CLOSED_COMBO_B > 0)); // |
    uint256 refundWei = Min(vRefundWei, address(this).balance); // Should not need this but b&b
    toA.transfer(refundWei);
    emit RefundV(pRefundId, toA, refundWei, vRefundBit);
    return address(this).balance == 0 ? false : true; // return false when refunding is complete
  } // End Refund()


  // Grey Fallback function
  // ======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Grey contract other than via the defined methods with their testing for valid access
  }

} // End Grey contract
