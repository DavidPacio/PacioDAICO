/*  \Poll\Poll.sol started 2018.07.11

Contract to run Pacio DAICO Polls

Owned by Deployer OpMan Hub Admin Web

djh??
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
  uint32 private pPollId;                 // Id of current poll. A member poll request updates pPollId
  uint8  private pPollN;                  // Enum of Poll in progress, including when a request 'poll' is running though a request poll does not result in a state change
  bool   private pPollRequestB;           // Set when a member request poll is current
  uint32 private pChangePollCurrentValue; // Current value of a setting to be changed if a change poll is approved
  uint32 private pChangePollToValue;      // Value setting is to be changed to if a change poll is approved
  uint32 private pPollStartT;             // Poll start time - also used as a flag for is there a poll current. Other values are left for examination after a poll
  uint32 private pPollEndT;               // Poll end time
  uint32 private pNumMembersVoted;        // Number of members who have voted
  uint32 private pPiosVotedYes;           // Pios voted Yes
  uint32 private pPiosVotedNo;            // Pios voted No
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
  uint32[NUM_POLLS] private pPollEndTA; // Array of poll end times

  // View Methods
  // ============
  // Poll.DaicoState()  Should be the same as Hub.DaicoState()
  function DaicoState() external view returns (uint32) {
    return pState;
  }
  // Poll.PollInProgressOrLastPollRun()
  function PollInProgressOrLastPollRun() external view returns (uint8) {
    return pPollN;
  }
  // Poll.PollStartTimeZeroForNoCurrentPoll()
  function PollStartTimeZeroForNoCurrentPoll() external view returns (uint32) {
    return pPollStartT;
  }
  // Poll.PollEndTime()
  function PollEndTime() external view returns (uint32) {
    return pPollEndT;
  }
  // Poll.PollId()
  function PollId() external view returns (uint32) {
    return pPollId;
  }
  // Poll.PiosVotedYes()
  function PiosVotedYes() external view returns (uint32) {
    return pPiosVotedYes;
  }
  // Poll.PiosVotedNo()
  function PiosVotedNo() external view returns (uint32) {
    return pPiosVotedNo;
  }
  // Poll.NumberOfMembersWhoHaveVoted()
  function NumberOfMembersWhoHaveVoted() external view returns (uint32) {
    return pNumMembersVoted;
  }
  // Poll.IsPollRequestCurrent()
  function IsPollRequestCurrent() external view returns (bool) {
    return pPollRequestB;
  }
  // Poll.ChangePollCurrentValue()
  function ChangePollCurrentValue() external view returns (uint32) {
    return pChangePollCurrentValue;
  }
  // Poll.ChangePollToValue()
  function ChangePollToValue() external view returns (uint32) {
    return pChangePollToValue;
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
  event        PollRequestV(uint32 indexed PollId, address Member, uint8 RequestedPollN, uint32 ChangeToValue, uint32 NumMembersVoted);
  event PollRequestTimeoutV(uint32 indexed PollId, uint8 RequestedPollN);
  // djh?? PollTimeOut
  event          PollStartV(uint32 indexed PollId, uint32 PollN);
  event            PollEndV(uint32 indexed PollId, uint32 PollN);
  event               VoteV(uint32 indexed PollId, address indexed voterA, uint8 VoteN, int32 PiosVoted, uint32 PiosVotedYes, uint32 PiosVotedNo);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by Deployer OpMan Hub Admin Web
  // Owners must first be set by deploy script calls:
  //   Poll.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   Poll.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Poll.ChangeOwnerMO(POLL_ADMIN_OWNER_X, PCL hw wallet account address as Admin)
  //   Poll.ChangeOwnerMO(POLL_WEB_OWNER_X, Web address)

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
  // Called from Initialise() and pCheckForEndOfPoll() if pMaxVoteHardCapCentiPc changes to set List.pMaxPicosVote
  function pSetMaxVotePerMember() private {
    // Maximum vote in picos for a member = Sale.pPicoHardCap * Poll.pMaxVoteHardCapCentiPc / 100
    pListC.SetMaxVotePerMember(safeMul(safeMul(uint256(pSaleC.PioHardCap()), 10*12), pMaxVoteHardCapCentiPc) / 100);
  }

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
  function RequestPoll(uint8 requestedPollN, uint32 requestChangeToValue) external IsAdminOrWalletCaller returns (bool) {
    return pRequestPoll(iIsAdminCallerB(), msg.sender, requestedPollN, requestChangeToValue);
  }

  // Poll.WebRequestPoll()
  // ---------------------
  // Called via Pacio web site on behalf of a logged in Member to request a poll
  // A successful request results in pPollN being set but does not result in a state change until the request is confirmed
  function WebRequestPoll(address requesterA, uint8 requestedPollN, uint32 requestChangeToValue) external IsWebCaller returns (bool) {
    return pRequestPoll(false, requesterA, requestedPollN, requestChangeToValue);
  }

  // Poll.pRequestPoll() private
  // -------------------
  // Called from Poll.RequestPoll() or Poll.WebRequestPoll() to process a poll request
  // A successful request by Admin results in an immediate start.
  // A successful request by a Member results in pPollN being set but does not result in a state change until the request is confirmed
  function pRequestPoll(bool adminB, address requesterA, uint8 requestedPollN, uint32 requestChangeToValue) private returns (bool) {
    require(requestedPollN > 0 && requestedPollN <= NUM_POLLS, 'Invalid Poll Request'); // range check of requestedPollN
    uint32 now32T = uint32(now);
    require(now32T - pPollEndTA[requestedPollN-1] >= pDaysBeforePollRepeat * DAY, 'Too soon after previous poll'); // repeat days check
    if (pPollStartT > 0)
      pCheckForEndOfPoll();
    require(pPollStartT == 0, 'Poll already in progress');
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
      require(requestedPollN > POLL_CHANGE_S_CAP_DISP_PC_N, 'inapplicable Poll'); // All polls up to POLL_CHANGE_S_CAP_DISP_PC_N are inapplicable after close
    if (pState & STATE_S_CAP_REACHED_B > 0)
      require(requestedPollN != POLL_CHANGE_S_CAP_USD_N && requestedPollN != POLL_CHANGE_S_CAP_PIO_N && requestedPollN != POLL_CHANGE_S_CAP_DISP_PC_N, 'inapplicable Poll');
    if (!pPollRequestB && requestedPollN > POLL_CLOSE_SALE_N && requestedPollN < POLL_TERMINATE_FUNDING_N) {
      // First request - either Admin or Member request - for a change poll request
      // Get currentValue and do sense checks for this change poll requests
      uint32 currentValue;
      bool   okB = true;
      if (requestedPollN == POLL_CHANGE_S_CAP_USD_N) {
        // USD Soft Cap
        currentValue = pSaleC.UsdSoftCap();
        okB = requestChangeToValue >= pSaleC.UsdRaised() && requestChangeToValue < pSaleC.UsdHardCap();
      }else if (requestedPollN == POLL_CHANGE_S_CAP_PIO_N) {
        // PIO Soft Cap
        currentValue = pSaleC.PioSoftCap();
        okB = requestChangeToValue * 10**12 >= pSaleC.PicosSold() && requestChangeToValue < pSaleC.PioHardCap();
      }else if (requestedPollN == POLL_CHANGE_H_CAP_USD_N) {
        // USD Hard Cap
        currentValue = pSaleC.UsdHardCap();
        okB = requestChangeToValue >= pSaleC.UsdRaised() && requestChangeToValue > pSaleC.UsdSoftCap();
      }else if (requestedPollN == POLL_CHANGE_H_CAP_PIO_N) {
        // PIO Hard Cap
        currentValue = pSaleC.PioHardCap();
        okB = requestChangeToValue * 10**12 >= pSaleC.PicosSold();
      }else if (requestedPollN == POLL_CHANGE_SALE_END_TIME_N) {
        // Sale End Time
        currentValue = pSaleC.SaleEndTime();
        okB = requestChangeToValue > now32T && requestChangeToValue > pSaleC.SaleStartTime();
      }else if (requestedPollN == POLL_CHANGE_S_CAP_DISP_PC_N) {
        // Soft Cap Reached Dispersal %
        currentValue = pMfundC.SoftCapReachedDispersalPercent();
        okB = requestChangeToValue <= 100;
      }else if (requestedPollN == POLL_CHANGE_TAP_RATE_N) {
        // Tap rate Ether pm
        currentValue = pMfundC.TapRateEtherPm();
        // no sense check
      }else if (requestedPollN == POLL_CHANGE_REQUEST_NUM_N) {
        // 3 The number of Members required to request a Poll for it to start automatically
        currentValue = pRequestsToStartPoll;
        okB = requestChangeToValue >= 1 && requestChangeToValue <= 10;
      }else if (requestedPollN == POLL_CHANGE_REQUEST_DAYS_N) {
        // 2 Days in which a request for a Poll must be confirmed by pRequestsToStartPoll Members for it to start, or else to lapse
        currentValue = pPollRequestConfirmDays;
        okB = requestChangeToValue >= 1 && requestChangeToValue <= 14;
      }else if (requestedPollN == POLL_CHANGE_POLL_DAYS_N) {
        // 7 Days for which a poll runs
        currentValue = pPollRunDays;
        okB = requestChangeToValue >= 1 && requestChangeToValue <= 30;
      }else if (requestedPollN == POLL_CHANGE_REPEAT_DAYS_N) {
        // 30 Days which must elapse before any particular poll can be repeated
        currentValue = pDaysBeforePollRepeat;
        okB = requestChangeToValue >= 7 && requestChangeToValue <= 90;
      }else if (requestedPollN == POLL_CHANGE_MAX_VOTE_PC_N) {
        // 50 CentiPercentage of hard cap PIOs as the maximum voting PIOs per Member. 50 = 0.5%
        currentValue = pMaxVoteHardCapCentiPc;
        okB = requestChangeToValue > 0 && requestChangeToValue <= 100;
      }else if (requestedPollN == POLL_CHANGE_VALID_MEMS_XRT_PC_N) {
        // 25 Percentage of Members to vote for polls other than Release reserve & restart and Termination ones to be valid
        currentValue = pValidMemsExclRrrTermPollsPc;
        okB = requestChangeToValue > 0 && requestChangeToValue <= 50;
      }else if (requestedPollN == POLL_CHANGE_PASS_XRT_PC_N) {
        // 50 Percentage of yes votes of PIOs voted to approve polls other than Release reserve & restart and Termination ones
        currentValue = pPassVoteExclRrrTermPollsPc;
        okB = requestChangeToValue > 0 && requestChangeToValue <= 75;
      }else if (requestedPollN == POLL_CHANGE_VALID_MEMS_RT_PC_N) {
        // 33 Percentage of Members to vote for a Release reserve & restart or Termination poll to be valid
        currentValue = pValidMemsRrrTermPollsPc;
        okB = requestChangeToValue > 0 && requestChangeToValue <= 50;
      }else if (requestedPollN == POLL_CHANGE_PASS_RT_PC_N) {
        // 75 Percentage of yes votes of PIOs voted to approve a Release reserve & restart or Termination poll
        currentValue = pPassVoteRrrTermPollsPc;
        okB = requestChangeToValue > 50 && requestChangeToValue <= 100;
      }else{
        // Release some of the PIOs held in reserve and restart the DAICO
        // currentValue = 0;
        okB = requestChangeToValue >= 1000000 && requestChangeToValue <= 500000000; // 1 to 500 million - deliberately wide range check as lots of other info would need to be specified for a proposed release and restart
      }
      if (requestChangeToValue == currentValue)
        revert('No change requested');
      if (!okB)
        revert('Change requested out of range or not sensible');
      pChangePollCurrentValue = currentValue;
    } // End of first request - either Admin or Member request - for a change poll request block
    if (!adminB) {
      // Wallet caller - must be a member
      if (!pPollRequestB) {
        // First request for a Member request Poll - start the member request "poll" being run here via requests, not via voting
        pPollId++; // update pPollId for the member request "poll"
        pPollRequestB      = true;
        pNumMembersVoted   = 0;
        pPollN             = requestedPollN;
        pChangePollToValue = requestChangeToValue;
        pPollStartT        = now32T;
        pPollEndT            =
        pPollEndTA[pPollN-1] = pPollStartT + pPollRequestConfirmDays * DAY;
      }else{
        // second or subsequent request - check that this request is the same as the pending one
        // The check that this request is within pPollRequestConfirmDays days has been done already by the pCheckForEndOfPoll() above
        require(requestedPollN == pPollN && requestChangeToValue == pChangePollToValue, 'Different poll request pending');
      }
      require(pListC.Vote(requesterA, pPollId, VOTE_YES_N) != 0, 'Vote not valid'); // checks that requesterA is a member who hasn't already voted
      pNumMembersVoted++; // no need to sum votes here as only pNumMembersVoted matters
      emit PollRequestV(pPollId, requesterA, requestedPollN, requestChangeToValue, pNumMembersVoted);
      if (pNumMembersVoted < pRequestsToStartPoll)
        return true;
    } // End Member caller block
    // Either Admin or Member request with pNumMembersVoted == pRequestsToStartPoll
    // Start the poll
    pPollRequestB    = false;
    pPiosVotedYes    =
    pPiosVotedNo     =
    pNumMembersVoted = 0;
    pPollStartT      = now32T;
    pPollEndT            =
    pPollEndTA[pPollN-1] = pPollStartT + pPollRunDays * DAY;
    pHubC.PollStartEnd(pPollId, pPollN);
    emit PollStartV(++pPollId, pPollN); // with pPollId incremented
    return true;
  } // end RequestPoll()

  // Poll.pCheckForEndOfPoll() private
  // -------------------------
  function pCheckForEndOfPoll() private {
    if (pPollStartT == 0 || uint32(now) < pPollEndT)
      return; // no current poll or poll is still running
    if (pPollRequestB) {
      // Was a Member initiated Poll Request
      emit PollRequestTimeoutV(pPollId, pPollN);
    }else{
      // Was a running poll
      pHubC.PollStartEnd(pPollId, 0);
      emit PollEndV(pPollId, pPollN);
      // djh?? to be completed
     // Call pSetMaxVotePerMember if pMaxVoteHardCapCentiPc changes to set List.pMaxPicosVote

    }
    // Poll has finished
    pPollStartT = 0;
  }

  // Poll.VoteYes()
  // --------------
  // To be called from an account for a yes vote
  function VoteYes() external IsNotContractCaller {
    pVote(msg.sender, VOTE_YES_N);
  }

  // Poll.WebVoteYes()
  // -----------------
  // To be called from a Pacio web site for a yes vote by a logged in Member
  function WebVoteYes(address voterA) external IsWebCaller {
    pVote(voterA, VOTE_YES_N);
  }

  // Poll.VoteNo()
  // -------------
  // To be called from an account for a no vote
  function VoteNo() external IsNotContractCaller {
    pVote(msg.sender, VOTE_NO_N);
  }

  // Poll.WebVoteNo()
  // ----------------
  // To be called from a Pacio web site for a no vote by a logged in Member
  function WebVoteNo(address voterA) external IsWebCaller {
    pVote(voterA, VOTE_NO_N);
  }

  // Poll.pVote() private
  // ------------
  function pVote(address voterA, uint8 voteN) private {
    require(pPollStartT > 0, 'No poll in progress');
    int32 piosVoted = pListC.Vote(voterA, pPollId, voteN); // checks that voterA is a member who hasn't already voted and returns 0 if so
    require(piosVoted != 0, 'Vote not valid');
    if (voteN == VOTE_YES_N) {
      require(piosVoted > 0, 'List.Vote() error');
      pPiosVotedYes += uint32(piosVoted);
    }else{
      require(piosVoted < 0, 'List.Vote() error');
      pPiosVotedNo  += uint32(-piosVoted);
    }
    pNumMembersVoted++;
    emit VoteV(pPollId, voterA, voteN, piosVoted, pPiosVotedYes, pPiosVotedNo);
    pCheckForEndOfPoll();
  }

  // Poll.VoteRevoke()
  // -----------------
  // To be called from an account for revoking a vote
  function VoteRevoke() external IsNotContractCaller {
    pVoteRevoke(msg.sender);
  }

  // Poll.WebVoteRevoke()
  // --------------------
  // To be called from a Pacio web site for revoking a vote by a logged in Member
  function WebVoteRevoke(address voterA) external IsWebCaller {
    pVoteRevoke(voterA);
  }

  // Poll.pVoteRevoke() private
  // ------------------
  function pVoteRevoke(address voterA) private {
    require(pPollStartT > 0, 'No poll in progress');
    int32 piosVoted = pListC.Vote(voterA, pPollId, VOTE_REVOKE_N); // checks that voterA is a member who has already voted and returns 0 if so
    require(piosVoted != 0, 'Revoke vote not valid');
    if (piosVoted > 0) {
      // Was a yes vote
      pPiosVotedYes = pPiosVotedYes > uint32(piosVoted) ? pPiosVotedYes - uint32(piosVoted) : 0;
    }else{
      // Was a no vote
      piosVoted = -piosVoted;
      pPiosVotedNo = pPiosVotedNo > uint32(piosVoted) ? pPiosVotedNo - uint32(piosVoted) : 0;
    }
    pNumMembersVoted--;
    pCheckForEndOfPoll();
  }

  // Poll Fallback function
  // ======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Poll contract other than via the defined methods with their testing for valid access
  }

} // End Poll contract
