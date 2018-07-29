/*  \Escrow\Grey.sol started 2018.07.11

Escrow management of funds from grey listed participants in the Pacio DAICO

Owned by Deployer, OpMan, Hub, Sale

djh??

View Methods
============

State changing methods
======================

List.Fallback function
======================
No sending ether to this contract!

Events
=====

*/

pragma solidity ^0.4.24;

import "../lib/OwnedEscrow.sol";
import "../lib/Math.sol";

contract Grey is Owned, Math {
  string  public name = "Pacio DAICO Grey List Escrow";
  enum NGreyState {
    None,            // 0 Not started yet
    SaleRefund,      // 1 Failed to reach soft cap, contributions being refunded
    SaleClosed,      // 2 Sale is closed whether by hitting hard cap, out of time, or manually -> contributions being refunded
    Open             // 3 Grey escrow is open for deposits
  }
  NGreyState public EGreyStateN;
  uint256 private pWeiBalance;     // wei in escrow

  // Events
  // ======
  event InitialiseV();

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale
  // Owners must first be set by deploy script calls:
  //   Grey.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Grey.ChangeOwnerMO(SALE_OWNER_X, Sale address)
  //   Grey.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address) <=== Must come after HUB_OWNER_X, SALE_OWNER_X have been set

  // Grey.Initialise()
  // -----------------
  // Called from the deploy script to initialise the Grey contract
  function Initialise() external IsDeployerCaller {
    require(iInitialisingB); // To enforce being called only once
  //require(EGreyStateN == NGreyState.None); // can only be called before the sale starts
    EGreyStateN = NGreyState.Open;
    iPausedB       =        // make Grey Escrow active
    iInitialisingB = false;
    emit InitialiseV();
  }

  // No Escrow.StartSale() as grey escrow is not affected by the sale starting

  // View Methods
  // ============
  // Escrow.WeiInEscrow() -- Echoed in Sale View Methods
  function WeiInEscrow() external view returns (uint256) {
    return pWeiBalance;
  }


  // Modifier functions
  // ==================

  // State changing methods
  // ======================

  // Grey.Deposit()
  // --------------
  // Fn to be called from Sale.Buy() for a grey list case to transfer the contribution for escrow keeping here
  function Deposit(address vSenderA) external payable IsSaleCaller {
    // djh?? to be completed
  }

  // Grey Fallback function
  // ======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Grey contract other than via the defined methods with their testing for valid access
  }

} // End Grey contract
