/*  \Votes\VoteEnd.sol started 2018.07.11

Voting re ending the DAICO and refunding the remaining funds

Owned by Deployer, OpMan, Hub

djh??

• No vote allowed until sale has been closed
• to call Hub.Terminate() on a Yes to end vote

View Methods
============

State changing methods
======================

Pause/Resume
============
OpMan.PauseContract(VOTE_END_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(VOTE_END_CONTRACT_X) IsConfirmedSigner which is a managed op

List.Fallback function
======================
No sending ether to this contract!

Events
=====

*/

pragma solidity ^0.4.24;

import "../lib/OwnedByOpManAndHub.sol";
import "../lib/Math.sol";

contract VoteEnd is OwnedByOpManAndHub, Math {
  // Data

  // Events
  // ======

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub
  // Owners must first be set by deploy script calls:
  //   VoteEnd.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   VoteEnd.ChangeOwnerMO(HUB_OWNER_X, Hub address)

  // VoteEnd.Initialise()
  // -------------------
  // Called from the deploy script to initialise the VoteEnd contract
  function Initialise() external IsInitialising {
    iPausedB       =         // make VoteEnd active
    iInitialisingB = false;
  }

  // View Methods
  // ============

  // Modifier functions
  // ==================

  // State changing methods
  // ======================

  // VoteEnd Fallback function
  // =========================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the VoteEnd contract other than via the defined methods with their testing for valid access
  }

} // End VoteEnd contract
