/0*  \Poll\Poll.sol started 2018.07.11

Contract to run Pacio DAICO Polls

Owned by Deployer, OpMan, Hub, Admin

djh??

Pause/Resume
============
OpMan.PauseContract(POLL_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(POLL_CONTRACT_X) IsConfirmedSigner which is a managed op

Poll.Fallback function
======================
No sending ether to this contract!


*/

pragma solidity ^0.4.24;

import "../lib/OwnedPoll.sol";
import "../lib/Math.sol";

contract Poll is OwnedPoll, Math {
  string public  name = "Pacio Polls";
  uint32 private pState;                  // DAICO state using the STATE_ bits. Replicated from Hub on a change
  uint32 private pPollN;                  // Enum of Poll requested or running
  bool   private pPollRequestedB;         // true if a pPollN poll has been requested, and this is in its confirmation period
  uint32 private pChangeToValue;          // Value setting is to be changed to if a change poll is approved
  uint32 private pRequestMembers    =  3; // Number of Members required to request a Poll for it to start automatically
  uint32 private pRequestDays       =  2; // Days in which a request for a Poll must be confirmed by pRequestMembers Members for it to start, or else to lapse
  uint32 private pPollRunDays       =  7; // Days for which a poll runs
  uint32 private pRepeatDays        = 30; // Days which must elapse before any particular poll can be repeated
  uint32 private pVotingCentiPc     = 50; // CentiPercentage of hard cap PIOs as the maximum voting PIOs per Member. 50 = 0.5%
  uint32 private pVoteValidExTermPc = 25; // Percentage of eligible voting PIOs (yes + no votes) required for a non-termination poll to be valid
  uint32 private pVotePassExTermPc  = 50; // Percentage of yes vote PIOs to approve a non-termination poll
  uint32 private pVoteValidTermPc   = 33; // Percentage of eligible voting PIOs (yes + no votes) required for a termination poll to be valid
  uint32 private pVotePassTermPc    = 75; // Percentage of yes vote PIOs to approve a termination poll



  // View Methods
  // ============
  // Poll.DaicoState()  Should be the same as Hub.DaicoState()
  function DaicoState() external view returns (uint32) {
    return pState;
  }

  // Events
  // ======
  event     StateChangeV(uint32 PrevState, uint32 NewState);
  event PollStateChangeV(uint32 PrevState, uint32 NewState);

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


  // Modifier functions
  // ==================

  // State changing methods
  // ======================

  // Poll.StateChange()
  // ------------------
  // Called from Hub.pSetState() on a change of state to replicate the new state setting and take any required actions
  function StateChange(uint32 vState) external IsHubContractCaller {
    emit StateChangeV(pState, vState);
    pState = vState;
  }

  // Poll Fallback function
  // ======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Poll contract other than via the defined methods with their testing for valid access
  }

} // End Poll contract
