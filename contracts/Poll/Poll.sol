/*  \Poll\Poll.sol started 2018.07.11

Contract to run Pacio DAICO Polls

Owned by Deployer OpMan Hub Admin

djh??
- update pPollId
- include pPollId in evnts
- add the List stuff..........
web/admin fn to check for end of poll

Differences from Abyss
- one contract not a new one for each poll
- djh??


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
import "../Hub/I_HubPoll.sol";
import "../Sale/I_SalePoll.sol";
import "../List/I_ListPoll.sol";
import "../Funds/I_MfundPoll.sol";

contract Poll is OwnedPoll, Math {
  string public  name = "Pacio Polls";
  uint32 private pState;                  // DAICO state using the STATE_ bits. Replicated from Hub on a change
  uint32 private pPollId;                 // Id of current poll. A poll request updates pPollId
  uint32 private pPollN;                  // Enum of Poll in progress, including when a request 'poll' is running though a request poll does not result in a state change
  uint32 private pNumPollRequests;        // Number of poll requests received which needs to reach pRequestsToStartPoll for the requested poll to start
  uint32 private pChangePollCurrentValue; // Current value of a setting to be changed if a change poll is approved
  uint32 private pChangePollToValue;      // Value setting is to be changed to if a change poll is approved
  uint32 private pPollStartT;             // Poll start time
  uint32 private pPollEndT;               // Poll end time
  uint32 private pRequestsToStartPoll         =  3; // Number of Members required to request a Poll for it to start automatically
  uint32 private pPollRequestConfirmDays      =  2; // Days in which a request for a Poll must be confirmed by pRequestsToStartPoll Members for it to start, or else to lapse
  uint32 private pPollRunDays                 =  7; // Days for which a poll runs
  uint32 private pDaysBeforePollRepeat        = 30; // Days which must elapse before any particular poll can be repeated
  uint32 private pMaxVoteHardCapCentiPc       = 50; // CentiPercentage of hard cap PIOs as the maximum voting PIOs per Member. 50 = 0.5%
  uint32 private pValidMemsExclRrrTermPollsPc = 25; // Percentage of Members to vote for polls other than Release reserve & restart and Termination ones to be valid
  uint32 private pPassVoteExclRrrTermPollsPc  = 50; // Percentage of yes votes of PIOs voted to approve polls other than Release reserve & restart and Termination ones
  uint32 private pValidMemsRrrTermPollsPc     = 33; // Percentage of Members to vote for a Release reserve & restart or Termination poll to be valid
  uint32 private pPassVoteRrrTermPollsPc      = 75; // Percentage of yes votes of PIOs voted to approve a Release reserve & restart or Termination poll
  I_HubPoll   private pHubC;   // the Hub contract   /- Poll makes state changing calls to these contracts so they need to have Poll as an owner. Hub does.
  I_SalePoll  private pSaleC;  // the Sale contract  |  Sale is owned by Deployer OpMan Hub  Admin                so includes Poll   <-- add Poll
  I_ListPoll  private pListC;  // the List contract  |  List is owned by Deployer OpMan Hub   Sale  Token         so includes Poll   <-- add Poll
  I_MfundPoll private pMfundC; // the Mfund contract |  Mfund is owned by Deployer OpMan Hub   Sale  Pfund  Admin so includes Poll   <-- add Poll
  uint32[NUM_POLLS] private pPrevPollEndTA; // Array of poll end times

  // View Methods
  // ============
  // Poll.DaicoState()  Should be the same as Hub.DaicoState()
  function DaicoState() external view returns (uint32) {
    return pState;
  }
  // Poll.PollInProgress()
  function PollInProgress() external view returns (uint32) {
    return pPollN;
  }
  // Poll.NumberOfCurrentPollRequests()
  function NumberOfCurrentPollRequests() external view returns (uint32) {
    return pNumPollRequests;
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
    return pRequestsToStartPoll;
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
  function ValidVoteExclTerminationPc() external view returns (uint32) {
    return pValidMemsExclRrrTermPollsPc;
  }
  // Poll.PassVoteExclTerminationPollPc()
  function PassVoteExclTerminationPc() external view returns (uint32) {
    return pPassVoteExclRrrTermPollsPc;
  }
  // Poll.ValidVoteTerminationPollPc()
  function ValidVoteTerminationPc() external view returns (uint32) {
    return pValidMemsRrrTermPollsPc;
  }
  // Poll.PassVoteTerminationPollPc()
  function PassVoteTerminationPc() external view returns (uint32) {
    return pPassVoteRrrTermPollsPc;
  }
  // // Poll.VoteCast()
  // function VoteCast(address voterA) external view returns (uint32 voteT, int32 vote, uint256 picosHeld) {
  //   R_Vote storage srVoteR = pVotesMR[voterA];
  //   return (srVoteR.voteT, srVoteR.vote, pListC.PicosBalance(voterA));
  // }

  // Events
  // ======
  event InitialiseV(address HubContract, address ListContract, address MfundContract);
  event StateChangeV(uint32 PrevState, uint32 NewState);
  event PollRequestV(uint32 RequestedPollN, uint32 ChangeToValue);
  event PollRequestTimeoutV(uint32 RequestedPollN);
  event PollStartV(uint32 PollN);
  event PollEndV(uint32 PollN);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by Deployer OpMan Hub Admin
  // Owners must first be set by deploy script calls:
  //   Poll.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   Poll.ChangeOwnerMO(HUB_OWNER_X,   Hub address)
  //   Poll.ChangeOwnerMO(POLL_ADMIN_OWNER_X, PCL hw wallet account address as Admin)

  // Poll.Initialise()
  // -----------------
  // Called from the deploy script to initialise the Poll contract
  function Initialise() external IsInitialising {
    I_OpMan opManC = I_OpMan(iOwnersYA[OP_MAN_OWNER_X]);
    pHubC   = I_HubPoll(iOwnersYA[HUB_OWNER_X]);
    pSaleC  = I_SalePoll(opManC.ContractXA(SALE_CONTRACT_X));
    pListC  = I_ListPoll(opManC.ContractXA(LIST_CONTRACT_X));
    pMfundC = I_MfundPoll(opManC.ContractXA(MFUND_CONTRACT_X));
    pSetMaxVotePerMember();
    emit InitialiseV(pHubC, pListC, pMfundC);
    iPausedB       =         // make Poll active
    iInitialisingB = false;
  }

  // pSetMaxVotePerMember() private
  // ----------------------
  // Called from Initialise() and djh?? to set List.pMaxPicosVote
  function pSetMaxVotePerMember() private {
    // Maximum vote in picos for a member = Sale.pPicoHardCap * Poll.pMaxVoteHardCapCentiPc / 100
    pListC.SetMaxVotePerMember(safeMul(safeMul(uint256(pSaleC.PioHardCap()), 10*12), pMaxVoteHardCapCentiPc) / 100);
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
  // A successful request by Admin results in an immediate start.
  // A successful request by a Member results in pPollN being set but does not result in a state change until the request is confirmed
  function RequestPoll(uint32 vRequestedPollN, uint32 vChangeToValue) external IsAdminOrWalletCaller returns (bool) {
    require(vRequestedPollN > 0 && vRequestedPollN <= NUM_POLLS, 'Invalid Poll Request'); // range check of vRequestedPollN
    uint32 now32T = uint32(now);
    require(now32T - pPrevPollEndTA[vRequestedPollN-1] >= pDaysBeforePollRepeat * DAY, 'Too soon after previous poll'); // repeat days check
    if (pPollN > 0)
      pCheckForEndOfPoll();
    require(pPollN == 0, 'Poll already in progress');
    // Check for inapplicable poll requests
    //                             /--- Not applicable after soft cap hit
    // Poll 'Enums'                |/- Not applicable after sale close
    // POLL_CLOSE_SALE_N            c Close the sale
    // POLL_CHANGE_S_CAP_USD_N     sc Change Sale.pUsdSoftCap the USD soft cap
    // POLL_CHANGE_S_CAP_PIO_N     sc Change Sale.pPioSoftCap the PIO soft cap
    // POLL_CHANGE_H_CAP_USD_N      c Change Sale.pUsdHardCap the USD sale hard cap
    // POLL_CHANGE_H_CAP_PIO_N      c Change Sale.pPioHardCap the PIO sale hard cap
    // POLL_CHANGE_SALE_END_TIME_N  c Change Sale.pSaleEndT       the sale end time
    // POLL_CHANGE_S_CAP_DISP_PC_N sc Change Mfund.pSoftCapDispersalPc the soft cap reached dispersal %
    if (pState & STATE_CLOSED_COMBO_B > 0)
      require(vRequestedPollN > POLL_CHANGE_S_CAP_DISP_PC_N, 'inapplicable Poll'); // All polls up to POLL_CHANGE_S_CAP_DISP_PC_N are inapplicable after close
    if (pState & STATE_S_CAP_REACHED_B > 0)
      require(vRequestedPollN != POLL_CHANGE_S_CAP_USD_N && vRequestedPollN != POLL_CHANGE_S_CAP_PIO_N && vRequestedPollN != POLL_CHANGE_S_CAP_DISP_PC_N, 'inapplicable Poll');
    if (pNumPollRequests == 0) {
      // First request
      // Get currentValue and do sense checks for change poll requests
      if (vRequestedPollN > POLL_CLOSE_SALE_N && vRequestedPollN < POLL_TERMINATE_FUNDING_N) {
        uint32 currentValue;
        bool   okB = true;
        if (vRequestedPollN == POLL_CHANGE_S_CAP_USD_N) {
          // USD Soft Cap
          currentValue = pSaleC.UsdSoftCap();
          okB = vChangeToValue >= pSaleC.UsdRaised() && vChangeToValue < pSaleC.UsdHardCap();
        }else if (vRequestedPollN == POLL_CHANGE_S_CAP_PIO_N) {
          // PIO Soft Cap
          currentValue = pSaleC.PioSoftCap();
          okB = vChangeToValue * 10**12 >= pSaleC.PicosSold() && vChangeToValue < pSaleC.PioHardCap();
        }else if (vRequestedPollN == POLL_CHANGE_H_CAP_USD_N) {
          // USD Hard Cap
          currentValue = pSaleC.UsdHardCap();
          okB = vChangeToValue >= pSaleC.UsdRaised() && vChangeToValue > pSaleC.UsdSoftCap();
        }else if (vRequestedPollN == POLL_CHANGE_H_CAP_PIO_N) {
          // PIO Hard Cap
          currentValue = pSaleC.PioHardCap();
          okB = vChangeToValue * 10**12 >= pSaleC.PicosSold();
        }else if (vRequestedPollN == POLL_CHANGE_SALE_END_TIME_N) {
          // Sale End Time
          currentValue = pSaleC.SaleEndTime();
          okB = vChangeToValue > now32T && vChangeToValue > pSaleC.SaleStartTime();
        }else if (vRequestedPollN == POLL_CHANGE_S_CAP_DISP_PC_N) {
          // Soft Cap Reached Dispersal %
          currentValue = pMfundC.SoftCapReachedDispersalPercent();
          okB = vChangeToValue <= 100;
        }else if (vRequestedPollN == POLL_CHANGE_TAP_RATE_N) {
          // Tap rate Ether pm
          currentValue = pMfundC.TapRateEtherPm();
          // no sense check
        }else if (vRequestedPollN == POLL_CHANGE_REQUEST_NUM_N) {
          // 3 The number of Members required to request a Poll for it to start automatically
          currentValue = pRequestsToStartPoll;
          okB = vChangeToValue >= 1 && vChangeToValue <= 10;
        }else if (vRequestedPollN == POLL_CHANGE_REQUEST_DAYS_N) {
          // 2 Days in which a request for a Poll must be confirmed by pRequestsToStartPoll Members for it to start, or else to lapse
          currentValue = pPollRequestConfirmDays;
          okB = vChangeToValue >= 1 && vChangeToValue <= 14;
        }else if (vRequestedPollN == POLL_CHANGE_POLL_DAYS_N) {
          // 7 Days for which a poll runs
          currentValue = pPollRunDays;
          okB = vChangeToValue >= 1 && vChangeToValue <= 30;
        }else if (vRequestedPollN == POLL_CHANGE_REPEAT_DAYS_N) {
          // 30 Days which must elapse before any particular poll can be repeated
          currentValue = pDaysBeforePollRepeat;
          okB = vChangeToValue >= 7 && vChangeToValue <= 90;
        }else if (vRequestedPollN == POLL_CHANGE_MAX_VOTE_PC_N) {
          // 50 CentiPercentage of hard cap PIOs as the maximum voting PIOs per Member. 50 = 0.5%
          currentValue = pMaxVoteHardCapCentiPc;
          okB = vChangeToValue > 0 && vChangeToValue <= 100;
        }else if (vRequestedPollN == POLL_CHANGE_VALID_MEMS_XRT_PC_N) {
          // 25 Percentage of Members to vote for polls other than Release reserve & restart and Termination ones to be valid
          currentValue = pValidMemsExclRrrTermPollsPc;
          okB = vChangeToValue > 0 && vChangeToValue <= 50;
        }else if (vRequestedPollN == POLL_CHANGE_PASS_XRT_PC_N) {
          // 50 Percentage of yes votes of PIOs voted to approve polls other than Release reserve & restart and Termination ones
          currentValue = pPassVoteExclRrrTermPollsPc;
          okB = vChangeToValue > 0 && vChangeToValue <= 75;
        }else if (vRequestedPollN == POLL_CHANGE_VALID_MEMS_RT_PC_N) {
          // 33 Percentage of Members to vote for a Release reserve & restart or Termination poll to be valid
          currentValue = pValidMemsRrrTermPollsPc;
          okB = vChangeToValue > 0 && vChangeToValue <= 50;
        }else if (vRequestedPollN == POLL_CHANGE_PASS_RT_PC_N) {
          // 75 Percentage of yes votes of PIOs voted to approve a Release reserve & restart or Termination poll
          currentValue = pPassVoteRrrTermPollsPc;
          okB = vChangeToValue > 50 && vChangeToValue <= 100;
        }else{
          // Release some of the PIOs held in reserve and restart the DAICO
          // currentValue = 0;
          okB = vChangeToValue >= 1000000 && vChangeToValue <= 500000000; // 1 to 500 million - deliberately wide range check as lots of other info would need to be specified for a proposed release and restart
        }
        if (vChangeToValue == currentValue)
          revert('No change requested');
        if (!okB)
          revert('Change requested out of range or not sensible');
        pChangePollCurrentValue = currentValue;
      }
      pPollN = vRequestedPollN;
      pChangePollToValue = vChangeToValue;
      pPollStartT = now32T;
      pPollEndT                =
      pPrevPollEndTA[pPollN-1] = pPollStartT + pPollRequestConfirmDays * DAY;
    }
    if (!iIsAdminCallerB()) {
      // Is not Admin caller so is a wallet caller - must be a member
      if (pNumPollRequests > 0)
        // second or subsequent request
        // Check that this request is the same as the pending one
        require(vRequestedPollN == pPollN && vChangeToValue == pChangePollToValue, 'Different poll request pending');
      require(pListC.Vote(msg.sender, pPollId, VOTE_YES_N) != 0, 'Vote not valid'); // checks that msg.sender is a member who hasn't already voted
      emit PollRequestV(vRequestedPollN, vChangeToValue);
      if (++pNumPollRequests == pRequestsToStartPoll)
        pStartPoll();
    }
    pStartPoll();
    return true;
  } // end RequestPoll()

  // Poll.pStartPoll() private
  // -----------------
  function pStartPoll() private {
    pPollStartT = uint32(now);
    pPollEndT                =
    pPrevPollEndTA[pPollN-1] = pPollStartT + pPollRunDays * DAY;
    pNumPollRequests = 0;
    pHubC.PollStartEnd(pPollN);
    emit PollStartV(pPollN);
  }

  // Poll.pCheckForEndOfPoll() private
  // -------------------------
  function pCheckForEndOfPoll() private {
    if (uint32(now) < pPollEndT)
      return;
    if (pNumPollRequests > 0) {
      // Was a Member initiated Poll Request
      emit PollRequestTimeoutV(pPollN);
    }else{
      // Was a running poll
      pHubC.PollStartEnd(0);
      emit PollEndV(pPollN);
      // djh?? to be completed
    }
    // Poll has finished
    pPollN      =
    pPollStartT =
    pPollEndT   =
    pChangePollCurrentValue =
    pChangePollToValue      = 0;
  }

  // Poll Fallback function
  // ======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Poll contract other than via the defined methods with their testing for valid access
  }

} // End Poll contract
