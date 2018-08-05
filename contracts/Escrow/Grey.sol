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
  enum NGreyState {
    None,              // 0 Sale not started yet
    SoftCapMissRefund, // 1 Failed to reach soft cap, contributions being refunded
    SaleClosed,        // 2 Sale is closed whether by hitting hard cap, out of time, or manually -> contributions being refunded as LE_REFUND_GREY_SALE_CLOSE_B refunds
    Open,              // 3 Grey escrow is open for deposits
    GreyClosed         // 4 Grey escrow is empty as a result of refunds or whitelisting transfers to Escrow emptying the pot
  }
  NGreyState private pStateN;

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



  uint256 private pDepositId;      // Deposit Id
  uint256 private pWhitelistId;    // Whitelisting transfer Id
  uint256 private pRefundId;       // Id of refund in progress - RefundInfo() call followed by a Refund() caLL
  bool private pRefundInProgressB; // to prevent re-entrant refund calls lock
  I_ListEscrow private pListC;     // the List contract

  // View Methods
  // ============
  // Grey.EscrowWei() -- Echoed in Sale View Methods
  function EscrowWei() external view returns (uint256) {
    return address(this).balance;
  }
  // Grey.State()
  function State() external view returns (uint8) {
    return uint8(pStateN);
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
  event EndSaleV(NGreyState State);
  event DepositV(uint256 indexed DepositId, address indexed Account, uint256 Wei);
  event  RefundV(uint256 indexed RefundId,  address indexed Account, uint256 RefundWei);
  event RefundingCompleteV(NGreyState State);

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
  //require(pEStateN == NGreyState.None); // can only be called before the sale starts
    pStateN = NGreyState.Open;
    pListC  = I_ListEscrow(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(LIST_CONTRACT_X));
    iPausedB       =        // make Grey Escrow active
    iInitialisingB = false;
    emit InitialiseV();
  }

  // Grey.StartSale()
  // ----------------
  // Called from Hub.StartSale()
  function StartSale() external IsHubContractCaller {
    require(pStateN == NEscrowState.None        // initial start
         || pStateN == NEscrowState.SaleClosed, // a restart
            'Invalid state for Escrow StartSale call');
    pStateN = pSoftCapB ? NEscrowState.SoftCapReached : NEscrowState.PreSoftCap;
    emit StartSaleV(pStateN);
  }


  // Grey.EndSale()
  // --------------
  // Is called from Hub.EndSaleMO() when hard cap is reached, time is up, or the sale is ended manually
  function EndSale() external IsHubContractCaller {
    pStateN = NGreyState.SaleClosed; // Sale is closed whether by hitting hard cap, out of time, or manually -> contributions being refunded as LE_REFUND_GREY_SALE_CLOSE_B refunds
    emit EndSaleV(pStateN);
  }

  // State changing methods
  // ======================

  // Grey.Deposit()
  // --------------
  // Called from Sale.Buy() for a grey list case to transfer the contribution for escrow keeping here
  //                        after a List.GreyDeposit() call to update the list entry
  function Deposit(address vSenderA) external payable IsSaleContractCaller {
    require(pStateN == NGreyState.Open, "Deposit to Grey Escrow not allowed");
    emit DepositV(++pDepositId, vSenderA, msg.value);
  }

  // Grey.RefundInfo()
  // -----------------
  // Called from Hub.pRefund() for info as part of a refund process:
  // Hub.pRefund() calls: List.EntryTyoe()                - for type info
  //                      Escrow/Grey.RefundInfo()        - for refund info: amount and refund bit                    ********
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      Escrow/Grey.Refund()            - to do the actual refund
  function RefundInfo(address accountA, uint256 vRefundId) external IsHubContractCaller returns (uint256 refundWei, uint32 refundBit) {
    require(!pRefundInProgressB, 'Refund already in Progress'); // Prevent re-entrant calls
    pRefundInProgressB = true;
    pRefundId = vRefundId;
    if (pStateN == NGreyState.SoftCapMissRefund)
      refundBit = LE_REFUND_GREY_S_CAP_MISS_B;
    else if (pStateN == NGreyState.SaleClosed)
      refundBit = LE_REFUND_GREY_SALE_CLOSE_B;
    if (refundBit > 0)
      refundWei = Min(pListC.WeiContributed(accountA), address(this).balance);
  }

  // Grey.Refund()
  // -------------
  // Called from Hub.pRefund() to perform the actual refund from Escrow after Token.Refund() -> List.Refund() calls
  // Hub.pRefund() calls: List.EntryTyoe()                - for type info
  //                      Escrow/Grey.RefundInfo()        - for refund info: amount and refund bit
  //                      Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //                      Escrow/Grey.Refund()            - to do the actual refund                                      ********
  function Refund(address toA, uint256 vRefundWei, uint256 vRefundId) external IsHubContractCaller returns (bool) {
    require(pRefundInProgressB                                                              // /- all expected to be true if called as intended
         && vRefundId == pRefundId   // same hub call check                                 // |
         && (pStateN == NGreyState.SoftCapMissRefund || pStateN == NGreyState.SaleClosed)); // |
    require(vRefundWei <= address(this).balance, 'Refund not available');
    toA.transfer(vRefundWei);
    emit RefundV(pRefundId, toA, vRefundWei);
    if (address(this).balance == 0) { // refunding is complete
      pStateN == NGreyState.GreyClosed;
      emit RefundingCompleteV(pStateN);
    }
    pRefundInProgressB = false;
    return true;
  } // End Refund()

  // Grey Fallback function
  // ======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Grey contract other than via the defined methods with their testing for valid access
  }

} // End Grey contract
