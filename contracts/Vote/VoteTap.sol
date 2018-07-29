/*  \Vote\VoteTap.sol started 2018.07.11

Voting re changing the Tap rate

Owned by Deployer, OpMan, Hub

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

import "../lib/OwnedByOpManAndHub.sol";
import "../lib/Math.sol";

contract VoteTap is OwnedByOpManAndHub, Math {
  // Data

  // Events
  // ======

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub
  // Owners must first be set by deploy script calls:
  //   VoteTap.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   VoteTap.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address) <=== Must come after HUB_OWNER_X have been set

  // VoteTap.Initialise()
  // -------------------
  // Called from the deploy script to initialise the VoteTap contract
  function Initialise() external IsDeployerCaller {
    require(iInitialisingB); // To enforce being called only once
    iPausedB       =         // make VoteTap active
    iInitialisingB = false;
  }

  // View Methods
  // ============

  // Modifier functions
  // ==================

  // State changing methods
  // ======================

  // VoteTap Fallback function
  // =========================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the VoteTap contract other than via the defined methods with their testing for valid access
  }

} // End VoteTap contract
