/*  \Poll\Poll.sol started 2018.07.11

Contract to run Pacio DAICO Polls

Owned by Deployer, OpMan, Hub, Admin

djh??

Pause/Resume
============
OpMan.PauseContract(POLL_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(POLL_CONTRACT_X) IsConfirmedSigner which is a managed op

List.Fallback function
======================
No sending ether to this contract!


*/

pragma solidity ^0.4.24;

import "../lib/OwnedPoll.sol";
import "../lib/Math.sol";

contract Poll is OwnedByOpManAndHub, Math {
  // Data

  // Events
  // ======

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Admin
  // Owners must first be set by deploy script calls:
  //   Poll.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   Poll.ChangeOwnerMO(HUB_OWNER_X,   Hub address)
  //   Poll.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)

  // Poll.Initialise()
  // -----------------
  // Called from the deploy script to initialise the Poll contract
  function Initialise() external IsInitialising {
    iPausedB       =         // make Poll active
    iInitialisingB = false;
  }

  // View Methods
  // ============

  // Modifier functions
  // ==================

  // State changing methods
  // ======================

  // Poll Fallback function
  // ======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Poll contract other than via the defined methods with their testing for valid access
  }

} // End Poll contract
