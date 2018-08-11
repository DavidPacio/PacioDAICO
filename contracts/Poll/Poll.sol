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
  uint32 private pPollN;                  // Enum of Poll in progress
  uint32 private pChangePollCurrentValue; // Current value of a setting to be changed if a change poll is approved
  uint32 private pChangePollToValue;      // Value setting is to be changed to if a change poll is approved
  uint32 private pPollStartT;             // Poll start time
  uint32 private pPollEndT;               // Poll end time
  uint32 private pRequestsRequiredToStartPoll    =  3; // The number of Members required to request a Poll for it to start automatically
  uint32 private pRequestDays                    =  2; // Days in which a request for a Poll must be confirmed by pRequestsRequiredToStartPoll Members for it to start, or else to lapse
  uint32 private pPollRunDays                    =  7; // Days for which a poll runs
  uint32 private pDaysBeforePollRepeat           = 30; // Days which must elapse before any particular poll can be repeated
  uint32 private pMaxVoteHardCapCentiPc          = 50; // CentiPercentage of hard cap PIOs as the maximum voting PIOs per Member. 50 = 0.5%
  uint32 private pValidVoteExclTerminationPollPc = 25; // Percentage of eligible PIOs voted required for a non-termination poll to be valid
  uint32 private pPassVoteExclTerminationPollPc  = 50; // Percentage of yes votes of PIOs voted to approve a non-termination poll
  uint32 private pValidVoteTerminationPollPc     = 33; // Percentage of eligible PIOs voted required for a termination poll to be valid
  uint32 private pPassVoteTerminationPollPc      = 75; // Percentage of yes votes of PIOs voted to approve a termination poll


  // View Methods
  // ============
  // Poll.DaicoState()  Should be the same as Hub.DaicoState()
  function DaicoState() external view returns (uint32) {
    return pState;
  }
  // Poll.PollInProgress()
  function Poll() external view returns (uint32) {
    return pPollN;
  }
  // Poll.ChangePollCurrentValue()
  function ChangePollCurrentValue() external view returns (uint32) {
    return pChangePollCurrentValue;
  }
  // Poll.ChangePollToValue()
  function ChangePollToValue() external view returns (uint32) {
    return pChangePollToValue;
  }
  // Poll.PollStartTime()
  function PollStartTime() external view returns (uint32) {
    return pPollStartT;
  }
  // Poll.PollEndTime()
  function PollEndTime() external view returns (uint32) {
    return pPollEndT;
  }
  // Poll.RequestsRequiredToStartPoll()
  function RequestsRequiredToStartPoll() external view returns (uint32) {
    return pRequestsRequiredToStartPoll;
  }
  // Poll.RequestPollConfirmationDays()
  function RequestPollConfirmationDays() external view returns (uint32) {
    return pRequestDays;
  }
  // Poll.PollRunDays()
  function PollRunDays() external view returns (uint32) {
    return pPollRunDays;
  }
  // Poll.DaysBeforePollRepeat()
  function DaysBeforePollRepeat() external view returns (uint32) {
    return pDaysBeforePollRepeat;
  }
  // Poll.MaxVoteHardCapCentiPc()
  function MaxVoteHardCapCentiPc() external view returns (uint32) {
    return pMaxVoteHardCapCentiPc;
  }
  // Poll.ValidVoteExclTerminationPollPc()
  function pValidVoteExclTerminationPc() external view returns (uint32) {
    return pValidVoteExclTerminationPollPc;
  }
  // Poll.PassVoteExclTerminationPollPc()
  function pPassVoteExclTerminationPc() external view returns (uint32) {
    return pPassVoteExclTerminationPollPc;
  }
  // Poll.ValidVoteTerminationPollPc()
  function pValidVoteTerminationPc() external view returns (uint32) {
    return pValidVoteTerminationPollPc;
  }
  // Poll.PassVoteTerminationPollPc()
  function pPassVoteTerminationPc() external view returns (uint32) {
    return pPassVoteTerminationPollPc;
  }

  // Events
  // ======
  event StateChangeV(uint32 PrevState, uint32 NewState);

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
