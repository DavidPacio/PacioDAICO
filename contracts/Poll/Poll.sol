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
  uint32 private pNumPollRequests;        // Number of poll requests which needs to reach pRequestsRequiredToStartPoll for the requested poll to start
  uint32 private pChangePollCurrentValue; // Current value of a setting to be changed if a change poll is approved
  uint32 private pChangePollToValue;      // Value setting is to be changed to if a change poll is approved
  uint32 private pPollStartT;             // Poll start time
  uint32 private pPollEndT;               // Poll end time
  uint32 private pRequestsRequiredToStartPoll    =  3; // The number of Members required to request a Poll for it to start automatically
  uint32 private pPollRequestConfirmDays         =  2; // Days in which a request for a Poll must be confirmed by pRequestsRequiredToStartPoll Members for it to start, or else to lapse
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
    return pPollRequestConfirmDays;
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

  // Poll.RequestPoll()
  // ------------------
  // Called by Admin or Members to request a poll
  //
  function RequestPoll(uint32 vRequestedPollN, uint32 vChangeToValue) external IsAdminOrWalletCaller returns (bool) {
    if (pPollN > 0)
      pCheckForEndOfPoll();
    require(pPollN == 0, 'Poll already in progress');
    // Check for inapplicable poll requests
    //                             /--- Not applicable after soft cap hit
    // Poll Types                  | /- Not applicable after sale close
    // POLL_CLOSE_SALE_N            c Close the sale
    // POLL_CHANGE_S_CAP_USD_N     sc Change Sale.pUsdSoftCap the soft cap USD
    // POLL_CHANGE_H_CAP_USD_N      c Change Sale.pUsdHardCap the sale hard cap USD
    // POLL_CHANGE_SALE_END_TIME_N  c Change Sale.pEndT       the sale end time
    // POLL_CHANGE_S_CAP_DISP_PC_N sc Change Mfund.pSoftCapDispersalPc the soft cap reached dispersal %
    if (pState & STATE_CLOSED_COMBO_B > 0)
      require(vRequestedPollN > POLL_CHANGE_S_CAP_DISP_PC_N, 'inapplicable Poll'); // All polls up to POLL_CHANGE_S_CAP_DISP_PC_N are inapplicable after close
    if (pState & STATE_S_CAP_REACHED_B > 0)
      require(vRequestedPollN != POLL_CHANGE_S_CAP_USD_N && vRequestedPollN != POLL_CHANGE_S_CAP_DISP_PC_N), 'inapplicable Poll');
    // Poll repeat days check djh??
  uint32 private pDaysBeforePollRepeat           = 30; // Days which must elapse before any particular poll can be repeated
    // Poll sense checks djh??
    if (iIsAdminCallerB()) {
      // Admin caller with no current poll and poll is ok so start it
      pStartPoll(vRequestedPollN, vChangeToValue);
    } else if (!iIsContractCallerB()) {
      if (pNumPollRequests ? 0)
        // Check that this request is the same as the pending one
        require(vRequestedPollN == pPollN && vChangeToValue == pChangePollToValue, 'Different poll request pending');
      if (++pNumPollRequests == pRequestsRequiredToStartPoll),  'Poll already in progress');
        pStartPoll(vRequestedPollN, vChangeToValue);
    }else
      revert('Not Admin or Member caller');
    return true;
  }

  function pStartPoll(uint32 vRequestedPollN, uint32 vChangeToValue) private {
    pPollStartT = uint32(now);
    pEndT = pPollStartT +   uint32 private pPollRunDays                    =  7; // Days for which a poll runs

  }

  function pCheckForEndOfPoll() private {

  }


  //                                                            /--- Not applicable after soft cap hit
  // Poll Types                                                 | /- Not applicable after sale close
  uint32 internal constant POLL_CLOSE_SALE_N           =  1; //  c Close the sale
  uint32 internal constant POLL_CHANGE_S_CAP_USD_N     =  2; // sc Change Sale.pUsdSoftCap the soft cap USD
  uint32 internal constant POLL_CHANGE_H_CAP_USD_N     =  3; //  c Change Sale.pUsdHardCap the sale hard cap USD
  uint32 internal constant POLL_CHANGE_SALE_END_TIME_N =  4; //  c Change Sale.pEndT       the sale end time
  uint32 internal constant POLL_CHANGE_S_CAP_DISP_PC_N =  5; // sc Change Mfund.pSoftCapDispersalPc the soft cap reached dispersal %
  uint32 internal constant POLL_CHANGE_TAP_RATE_N      =  6; //    Change Mfund.pTapRateEtherPm     the Tap rate in Ether per month. A change to 0 stops withdrawals as a softer halt than a termination poll since the tap can be adjusted back up again to resume funding
  uint32 internal constant POLL_CHANGE_REQUEST_NUM_N   =  7; //    Change Poll.pRequestsRequiredToStartPoll    the number of Members required to request a poll for it to start automatically
  uint32 internal constant POLL_CHANGE_REQUEST_DAYS_N  =  8; //    Change Poll.pPollRequestConfirmDays                    the days in which a request for a Poll must be confirmed by Poll.pRequestsRequiredToStartPoll Members for it to start, or else to lapse
  uint32 internal constant POLL_CHANGE_POLL_DAYS_N     =  9; //    Change Poll.pPollRunDays                    the days for which a poll runs
  uint32 internal constant POLL_CHANGE_REPEAT_DAYS_N   = 10; //    Change Poll.pDaysBeforePollRepeat           the days which must elapse before any particular poll can be repeated
  uint32 internal constant POLL_CHANGE_MAX_VOTE_PC_N   = 11; //    Change Poll.pMaxVoteHardCapCentiPc          the CentiPercentage of hard cap PIOs as the maximum voting PIOs per Member
  uint32 internal constant POLL_CHANGE_VALID_XT_PC_N   = 12; //    Change Poll.pValidVoteExclTerminationPollPc the Percentage of eligible PIOs voted required for a non-termination poll to be valid
  uint32 internal constant POLL_CHANGE_PASS_XT_PC_N    = 13; //    Change Poll.pPassVoteExclTerminationPollPc  the Percentage of yes votes of PIOs voted to approve a non-termination poll
  uint32 internal constant POLL_CHANGE_VALID_TERM_PC_N = 14; //    Change Poll.pValidVoteTerminationPollPc     the Percentage of eligible PIOs voted required for a termination poll to be valid
  uint32 internal constant POLL_CHANGE_PASS_TERM_PC_N  = 15; //    Change Poll.pPassVoteTerminationPollPc      the Percentage of yes votes of PIOs voted to approve a termination poll
  uint32 internal constant POLL_TERMINATE_FUNDING_N    = 16; //    Terminate funding and refund all remaining funds in MFund in proportion to PIOs held. Applicable only after the sale has closed.

  uint32 private pPollN;                  // Enum of Poll in progress
  uint32 private pNumPollRequests;        // Number of poll requests which needs to reach pRequestsRequiredToStartPoll for the requested poll to start
  uint32 private pChangePollCurrentValue; // Current value of a setting to be changed if a change poll is approved
  uint32 private pChangePollToValue;      // Value setting is to be changed to if a change poll is approved
  uint32 private pPollStartT;             // Poll start time
  uint32 private pPollEndT;               // Poll end time
  uint32 private pRequestsRequiredToStartPoll    =  3; // The number of Members required to request a Poll for it to start automatically
  uint32 private pPollRequestConfirmDays         =  2; // Days in which a request for a Poll must be confirmed by pRequestsRequiredToStartPoll Members for it to start, or else to lapse
  uint32 private pPollRunDays                    =  7; // Days for which a poll runs
  uint32 private pDaysBeforePollRepeat           = 30; // Days which must elapse before any particular poll can be repeated
  uint32 private pMaxVoteHardCapCentiPc          = 50; // CentiPercentage of hard cap PIOs as the maximum voting PIOs per Member. 50 = 0.5%
  uint32 private pValidVoteExclTerminationPollPc = 25; // Percentage of eligible PIOs voted required for a non-termination poll to be valid
  uint32 private pPassVoteExclTerminationPollPc  = 50; // Percentage of yes votes of PIOs voted to approve a non-termination poll
  uint32 private pValidVoteTerminationPollPc     = 33; // Percentage of eligible PIOs voted required for a termination poll to be valid
  uint32 private pPassVoteTerminationPollPc      = 75; // Percentage of yes votes of PIOs voted to approve a termination poll


  // Poll Fallback function
  // ======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Poll contract other than via the defined methods with their testing for valid access
  }

} // End Poll contract
