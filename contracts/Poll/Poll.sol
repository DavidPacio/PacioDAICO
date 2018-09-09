/*  \Poll\Poll.sol started 2018.07.11

Contract to run Pacio DAICO Polls

Owners: Deployer OpMan Hub Admin Web

djh??
• poll info for web purposes

Pause/Resume
============
OpMan.PauseContract(POLL_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(POLL_CONTRACT_X) IsConfirmedSigner which is a managed op

Poll.Fallback function
======================
No sending ether to this contract!

*/

pragma solidity ^0.4.24;

import "../lib/Math.sol";
import "../lib/OwnedPoll.sol";
import "../OpMan/I_OpMan.sol";
import "../Hub/I_HubPoll.sol";
import "../Sale/I_SalePoll.sol";
import "../List/I_ListPoll.sol";
import "../Funds/I_MfundPoll.sol";

contract Poll is OwnedPoll, Math {
  string public  name = "Pacio Polls";
  uint32 private pState;                  // DAICO state using the STATE_ bits. Replicated from Hub on a change. STATE_POLL_RUNNING_B set when a poll is running
  uint32 private pPollId;                 // Id of current poll. A member poll request updates pPollId
  uint8  private pPollN;                  // Enum of Poll in progress, including when a request 'poll' is running though a request poll does not result in a state change
  bool   private pPollRequestB;           // Set when a member request poll is current
  uint32 private pChangePollCurrentValue; // Current value of a setting to be changed if a change poll is approved
  uint32 private pChangePollToValue;      // Value setting is to be changed to if a change poll is approved
  uint32 private pPollStartT;             // Poll start time
  uint32 private pPollEndT;               // Poll end time
  uint32 private pNumMembersVoted;        // Number of members who have voted
  uint32 private pPiosVotedYes;           // Pios voted Yes
  uint8  private pPollResultN;            // Poll result: POLL_YES_N | POLL_NO_N | POLL_INVALID
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
  I_SalePoll  private pSaleC;  // the Sale contract  |  Sale  is owned by Deployer OpMan Hub Admin Poll            so includes Poll
  I_ListPoll  private pListC;  // the List contract  |  List  is owned by Deployer OpMan Hub Sale Poll Token       so includes Poll
  I_MfundPoll private pMfundC; // the Mfund contract |  Mfund is owned by Deployer OpMan Hub Sale Poll Pfund Admin so includes Poll
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
  // Poll.Proxy()
  function Proxy(address voterA) external view returns (address) {
    return pListC.Proxy(voterA);
  }

  // djh?? vote info
  // // Poll.VoteCast()
  // function VoteCast(address voterA) external view returns (uint32 voteT, int32 vote, uint256 picosHeld) {
  //   R_Vote storage srVoteR = pVotesMR[voterA];
  //   return (srVoteR.voteT, srVoteR.vote, pListC.PicosBalance(voterA));
  // }

  // Events
  // ======
  event InitialiseV(address HubContract, address ListContract, address MfundContract);
  event StateChangeV(uint32 PrevState, uint32 NewState);
  event        RequestPollV(uint32 indexed PollId, address Member, uint8 RequestedPollN, uint32 ChangeToValue, uint32 NumMembersVoted);
  event RequestPollTimeoutV(uint32 indexed PollId, uint8 RequestedPollN);
  event          PollStartV(uint32 indexed PollId, uint32 PollN, uint32 PollStartT, uint32 PollEndT, uint32 ChangePollToValue);
  event               VoteV(uint32 indexed PollId, address indexed Voter, uint8 VoteN, int32 PiosVoted, int32 NumMembersVotedFor, uint32 PiosVotedYes, uint32 PiosVotedNo, uint32 NumMembersVoted);
  event            PollEndV(uint32 indexed PollId, uint32 PollN, uint32 NumMembersVoted, uint32 PiosVotedYes, uint32 PiosVotedNo, uint32 ValidMembersPc, uint32 PassVotePc, uint8 PollResultN, uint32 ChangePollCurrentValue, uint32 ChangePollToValue);
  event PollChangeRequestsToStartPollV(uint32 RequestsToStartPoll);
  event PollChangePollRequestConfirmDaysV(uint32 PollRequestConfirmDays);
  event PollChangePollRunDaysV(uint32 PollRunDays);
  event PollChangeDaysBeforePollRepeatV(uint32 DaysBeforePollRepeat);
  event PollChangeMaxVoteHardCapCentiPcV(uint32 MaxVoteHardCapCentiPc);
  event PollChangeValidMemsExclRrrTermPollsPcV(uint32 ValidMemsExclRrrTermPollsPc);
  event PollChangePassVoteExclRrrTermPollsPcV(uint32 PassVoteExclRrrTermPollsPc);
  event PollChangeValidMemsRrrTermPollsPcV(uint32 ValidMemsRrrTermPollsPc);
  event PollChangePassVoteRrrTermPollsPcV(uint32 PassVoteRrrTermPollsPc);
  event PollReleaseReserveAndRestartDaiso(uint32 PiosToRelease);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by Deployer OpMan Hub Admin Web
  // Owners must first be set by deploy script calls:
  //   Poll.SetOwnerIO(OPMAN_OWNER_X OpMan address)
  //   Poll.SetOwnerIO(HUB_OWNER_X, Hub address)
  //   Poll.SetOwnerIO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
  //   Poll.SetOwnerIO(POLL_WEB_OWNER_X, Web address)

  // Poll.Initialise()
  // -----------------
  // Called from the deploy script to initialise the Poll contract
  function Initialise() external IsInitialising {
    I_OpMan opManC = I_OpMan(iOwnersYA[OPMAN_OWNER_X]);
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
  // Called from Initialise() and
  // pClosePoll() for a POLL_CHANGE_MAX_VOTE_PC_N yes poll to change Poll.pMaxVoteHardCapCentiPc
  // pClosePoll() for a POLL_CHANGE_H_CAP_USD_N yes poll to change Sale.pPicoHardCap change
  // to set List.pMaxPicosVote
  // After a call to pSetMaxVotePerMember() an admin traverse of List is required to update list entry.piosProxyVote for Members who are proxies
  function pSetMaxVotePerMember() private {
    // Maximum vote in picos for a member = Sale.pPicoHardCap * Poll.pMaxVoteHardCapCentiPc / 100
    pListC.SetMaxVotePerMember(safeMul(safeMul(uint256(pSaleC.PioHardCap()), 10*12), pMaxVoteHardCapCentiPc) / 100);
  }

  // Poll.UpdatePioVotesDelegated()
  // ------------------------------
  // To be called by Admin (via web) on a traverse of the List for proxy appointers to to update list pioVotesDelegated and sumVotesDelegated up the line
  // following a pSetMaxVotePerMember() call to set List.pMaxPicosVote
  function UpdatePioVotesDelegated(address entryA) external IsAdminCaller {
    pListC.UpdatePioVotesDelegated(entryA);
  }

  // State changing methods
  // ======================

  // Poll.StateChange()
  // ------------------
  // Called from Hub.pSetState() on a change of state to replicate the new state setting and take any required actions
  function StateChange(uint32 vState) external IsHubContractCaller {
    emit StateChangeV(pState, vState);
    // djh?? Force close of poll relating to soft cap or hard cap if ....
    pState = vState;
  }

  // Poll.RequestPoll()
  // ------------------
  // Called by Admin or Members to request a poll
  // A successful request by Admin results in an immediate start.
  // A successful request by a Member results in pPollN being set but does not result in a state change until the request is confirmed
  function RequestPoll(uint8 requestedPollN, uint32 requestChangeToValue) external IsAdminOrWalletCaller  IsActive returns (bool) {
    return pRequestPoll(iIsAdminCallerB(), msg.sender, requestedPollN, requestChangeToValue);
  }

  // Poll.WebRequestPoll()
  // ---------------------
  // Called via Pacio web site on behalf of a logged in Member to request a poll
  // A successful request results in pPollN being set but does not result in a state change until the request is confirmed
  function WebRequestPoll(address requesterA, uint8 requestedPollN, uint32 requestChangeToValue) external IsWebCaller IsActive returns (bool) {
    return pRequestPoll(false, requesterA, requestedPollN, requestChangeToValue);
  }

  // Poll.CheckForEndOfPoll()
  // ------------------------
  // Called from the Pacio web site or by Admin to check for a poll ending
  // Return true if the poll closed as a result of the call
  function CheckForEndOfPoll() external IsWebOrAdminCaller IsActive returns (bool) {
    return pCheckForEndOfPoll();
  }

  // Poll.SetProxy()
  // --------------
  // Called from the Pacio web site or by Admin to add or remove a proxy
  // Sets the proxy address of entry accountA to vProxyA plus updates bits and pNumProxies
  // vProxyA = 0x0 to unset or remove a proxy
  function SetProxy(address accountA, address vProxyA) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.SetProxy(accountA, vProxyA);
  }


  // Poll.pRequestPoll() private
  // -------------------
  // Called from Poll.RequestPoll() or Poll.WebRequestPoll() to process a poll request
  // A successful request by Admin results in an immediate start.
  // A successful request by a Member results in pPollN being set but does not result in a state change until the request is confirmed
  // Returns true on successful completion of a call. Otherwise a revert would have happened i.e. no false return.
  function pRequestPoll(bool adminB, address requesterA, uint8 requestedPollN, uint32 requestChangeToValue) private returns (bool) {
    require(requestedPollN > 0 && requestedPollN <= NUM_POLLS, 'Invalid Poll Request'); // range check of requestedPollN
    uint32 now32T = uint32(now);
    require(now32T - pPollEndTA[requestedPollN-1] >= pDaysBeforePollRepeat * DAY, 'Too soon after previous poll'); // repeat days check
    if (pState & STATE_POLL_RUNNING_B > 0)
      // a poll is running so see if it is ready to close
      require(pCheckForEndOfPoll(), 'Poll already in progress'); // pCheckForEndOfPoll() returns true if the poll closed
    // Check for inapplicable poll requests
    //                             /--- Not applicable after soft cap hit
    // Poll 'Enums'                |/- Not applicable after sale close
    // POLL_CLOSE_SALE_N            c Close the sale
    // POLL_CHANGE_S_CAP_USD_N     sc Change Sale.pUsdSoftCap  the USD soft cap
    // POLL_CHANGE_S_CAP_PIO_N     sc Change Sale.pPicoSoftCap the Pico (PIO) soft cap
    // POLL_CHANGE_H_CAP_USD_N      c Change Sale.pUsdHardCap  the USD sale hard cap
    // POLL_CHANGE_H_CAP_PIO_N      c Change Sale.pPicoHardCap the Pico (PIO) sale hard cap
    // POLL_CHANGE_SALE_END_TIME_N  c Change Sale.pSaleEndT       the sale end time
    // POLL_CHANGE_S_CAP_DISP_PC_N sc Change Mfund.pSoftCapDispersalPc the soft cap reached dispersal %
    if (pState & STATE_SALE_CLOSED_B > 0)
      require(requestedPollN > POLL_CHANGE_S_CAP_DISP_PC_N, 'Inapplicable Poll'); // All polls up to POLL_CHANGE_S_CAP_DISP_PC_N are inapplicable after close
    if (pState & STATE_S_CAP_REACHED_B > 0)
      require(requestedPollN != POLL_CHANGE_S_CAP_USD_N && requestedPollN != POLL_CHANGE_S_CAP_PIO_N && requestedPollN != POLL_CHANGE_S_CAP_DISP_PC_N, 'Inapplicable Poll');
    // POLL_RELEASE_RESERVE_PIOS_N  c Release some of the PIOs held in reserve and restart the DAICO
    // POLL_TERMINATE_FUNDING_N     c Terminate funding and refund all remaining funds in Mfund in proportion to PIOs held
    //                              |- Require sale to have closed
    require(requestedPollN < POLL_RELEASE_RESERVE_PIOS_N || pState & STATE_SALE_CLOSED_B > 0, 'Inapplicable Poll');
    // End of inapplicable poll requests checks
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
        currentValue = pMfundC.SoftCapReachedDispersalPc();
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
        pPollRequestB        = true;
        pNumMembersVoted     = 0;
        pPollN               = requestedPollN;
        pChangePollToValue   = requestChangeToValue;
        pPollStartT          = now32T;
        pPollEndT            =
        pPollEndTA[pPollN-1] = pPollStartT + pPollRequestConfirmDays * DAY;
      }else{
        // second or subsequent request - check that this request is the same as the pending one
        // The check that this request is within pPollRequestConfirmDays days has been done already by the pCheckForEndOfPoll() above
        require(requestedPollN == pPollN && requestChangeToValue == pChangePollToValue, 'Different poll request pending');
      }
      (uint32 piosVoted, uint32 numMembersVotedFor, uint8 voteN) = pListC.Vote(requesterA, pPollId, VOTE_YES_N);
      require(piosVoted > 0 && numMembersVotedFor > 0 && voteN == 0, 'Vote not valid'); // checks that requesterA is a member who hasn't already voted. the numMembersVotedFor and voteN checks are really just to suppress unused local variable compiler warnings
      pNumMembersVoted++; // no need to sum votes here as only pNumMembersVoted matters
      emit RequestPollV(pPollId, requesterA, requestedPollN, requestChangeToValue, pNumMembersVoted);
      if (pNumMembersVoted < pRequestsToStartPoll)
        return true;
    } // End Member caller block
    // Either Admin or Member request with pNumMembersVoted == pRequestsToStartPoll
    // Start the poll
    pPollRequestB        = false;
    pPiosVotedYes        =
    pPiosVotedNo         =
    pNumMembersVoted     = 0;
    pPollStartT          = now32T;
    pPollEndT            =
    pPollEndTA[pPollN-1] = pPollStartT + pPollRunDays * DAY;
    pHubC.PollStartEnd(++pPollId, pPollN); // Sets state bit STATE_POLL_RUNNING_B with pPollId incremented
    emit PollStartV(pPollId, pPollN, pPollStartT, pPollEndT, pChangePollToValue);
    return true;
  } // end RequestPoll()

  // Poll.ClosePollYesMO()
  // ---------------------
  // Can be called manually by Admin as a managed op to force Yes result closing of a Poll if necessary.
  function ClosePollYesMO() external IsAdminCaller {
    require(pState & STATE_POLL_RUNNING_B > 0, 'No poll in progress');
    require(I_OpMan(iOwnersYA[OPMAN_OWNER_X]).IsManOpApproved(POLL_CLOSE_YES_MO_X));
  //pClosePoll(uint32 validMemsPc, uint32 passVotePc, uint8 pollResultN) private returns (bool)
    pClosePoll(0, 0, POLL_YES_N); // the 0s for validMemsPc and passVotePc indicate that this was a forced close
  }

  // Poll.ClosePollNoMO()
  // ---------------------
  // Can be called manually by Admin as a managed op to force Yes result closing of a Poll if necessary.
  function ClosePollNoMO() external IsAdminCaller {
    require(pState & STATE_POLL_RUNNING_B > 0, 'No poll in progress');
    require(I_OpMan(iOwnersYA[OPMAN_OWNER_X]).IsManOpApproved(POLL_CLOSE_NO_MO_X));
  //pClosePoll(uint32 validMemsPc, uint32 passVotePc, uint8 pollResultN) private returns (bool)
    pClosePoll(0, 0, POLL_NO_N); // the 0s for validMemsPc and passVotePc indicate that this was a forced close
  }

  // Poll.pCheckForEndOfPoll() private
  // -------------------------
  // Checks for a poll ending and processes it if so.
  // Returns true if the poll closed
  function pCheckForEndOfPoll() private returns (bool) {
    if (uint32(now) < pPollEndT)
      return false; // no current poll or poll is still running
    // Time is up
    // Poll has closed
    if (pPollRequestB) {
      // Was a Member initiated Poll Request
      emit RequestPollTimeoutV(pPollId, pPollN);
      return true;
    }
    // Was a running poll
    uint32 validMemsPc; // Percentage of Members to vote for poll to be valid
    uint32 passVotePc;  // Percentage of yes votes of PIOs voted to approve poll
    uint8  pollResultN;
    if (pPollN < POLL_RELEASE_RESERVE_PIOS_N) {
      // polls other than Release reserve & restart and Termination ones
      validMemsPc = pValidMemsExclRrrTermPollsPc; // Percentage of Members to vote for polls other than Release reserve & restart and Termination ones to be valid
      passVotePc  = pPassVoteExclRrrTermPollsPc;  // Percentage of yes votes of PIOs voted to approve polls other than Release reserve & restart and Termination ones
    }else{
      // Release reserve & restart or Termination poll
      validMemsPc = pValidMemsRrrTermPollsPc; // Percentage of Members to vote for a Release reserve & restart or Termination poll to be valid
      passVotePc  = pPassVoteRrrTermPollsPc;  // Percentage of yes votes of PIOs voted to approve a Release reserve & restart or Termination poll
    }
    if (pNumMembersVoted < pListC.NumberOfPacioMembers() * validMemsPc / 100)
      pollResultN = POLL_INVALID; // Poll result was invalid due to insufficient members voting
    else
      pollResultN = pPiosVotedYes >= uint32(uint256(pPiosVotedYes + pPiosVotedNo) * passVotePc / 100) ? POLL_YES_N  // largest uint32 4,294,967,295 could overflow   1,000,000,000 * 75
                                                                                                      : POLL_NO_N;
    return pClosePoll(validMemsPc, passVotePc, pollResultN);
  }

  // Poll.pClosePoll() private
  // -----------------
  // Process the closing of a poll
  // Returns true
  function pClosePoll(uint32 validMemsPc, uint32 passVotePc, uint8 pollResultN) private returns (bool) {
    pPollResultN = pollResultN;
    emit PollEndV(pPollId, pPollN, pNumMembersVoted, pPiosVotedYes, pPiosVotedNo, validMemsPc, passVotePc, pPollResultN, pChangePollCurrentValue, pChangePollToValue);
    pHubC.PollStartEnd(pPollId, 0); // Unsets state bit STATE_POLL_RUNNING_B
    if (pollResultN != POLL_YES_N)
      return true; // No or Invalid so there is nothing more to do

    if (pPollN == POLL_CLOSE_SALE_N)                 pHubC.CloseSaleMO(STATE_CLOSED_POLL_B);                // Close the sale
    else if (pPollN == POLL_CHANGE_S_CAP_USD_N)      pSaleC.PollSetUsdSoftCap(pChangePollToValue);          // USD Soft Cap
    else if (pPollN == POLL_CHANGE_S_CAP_PIO_N)      pSaleC.PollSetPioSoftCap(pChangePollToValue);          // PIO Soft Cap
    else if (pPollN == POLL_CHANGE_H_CAP_USD_N) {
      pSaleC.PollSetUsdHardCap(pChangePollToValue);  // USD Hard Cap
      pSetMaxVotePerMember();                        // to set List.pMaxPicosVote
    }else if (pPollN == POLL_CHANGE_H_CAP_PIO_N)     pSaleC.PollSetPioHardCap(pChangePollToValue);          // PIO Hard Cap
    else if (pPollN == POLL_CHANGE_SALE_END_TIME_N)  pSaleC.PollSetSaleEndTime(pChangePollToValue);         // Sale End Time
    else if (pPollN == POLL_CHANGE_S_CAP_DISP_PC_N)  pMfundC.PollSetSoftCapDispersalPc(pChangePollToValue); // Soft Cap Reached Dispersal %
    else if (pPollN == POLL_CHANGE_TAP_RATE_N)       pMfundC.PollSetTapRateEtherPm(pChangePollToValue);     // Tap rate Ether pm
    else if (pPollN == POLL_CHANGE_REQUEST_NUM_N) {
      // The number of Members required to request a Poll for it to start automatically
      pRequestsToStartPoll = pChangePollToValue;
      emit PollChangeRequestsToStartPollV(pRequestsToStartPoll);
    }else if (pPollN == POLL_CHANGE_REQUEST_DAYS_N) {
      // Days in which a request for a Poll must be confirmed by pRequestsToStartPoll Members for it to start, or else to lapse
      pPollRequestConfirmDays = pChangePollToValue;
      emit PollChangePollRequestConfirmDaysV(pPollRequestConfirmDays);
    }else if (pPollN == POLL_CHANGE_POLL_DAYS_N) {
      // Days for which a poll runs
      pPollRunDays = pChangePollToValue;
      emit PollChangePollRunDaysV(pPollRunDays);
    }else if (pPollN == POLL_CHANGE_REPEAT_DAYS_N) {
      // 30 Days which must elapse before any particular poll can be repeated
      pDaysBeforePollRepeat = pChangePollToValue;
      emit PollChangeDaysBeforePollRepeatV(pDaysBeforePollRepeat);
    }else if (pPollN == POLL_CHANGE_MAX_VOTE_PC_N) {
      // CentiPercentage of hard cap PIOs as the maximum voting PIOs per Member. 50 = 0.5%
      pMaxVoteHardCapCentiPc = pChangePollToValue;
      pSetMaxVotePerMember(); // to set List.pMaxPicosVote
      emit PollChangeMaxVoteHardCapCentiPcV(pMaxVoteHardCapCentiPc);
    }else if (pPollN == POLL_CHANGE_VALID_MEMS_XRT_PC_N) {
      // Percentage of Members to vote for polls other than Release reserve & restart and Termination ones to be valid
      pValidMemsExclRrrTermPollsPc = pChangePollToValue;
      emit PollChangeValidMemsExclRrrTermPollsPcV(pValidMemsExclRrrTermPollsPc);
    }else if (pPollN == POLL_CHANGE_PASS_XRT_PC_N) {
      // Percentage of yes votes of PIOs voted to approve polls other than Release reserve & restart and Termination ones
      pPassVoteExclRrrTermPollsPc = pChangePollToValue;
      emit PollChangePassVoteExclRrrTermPollsPcV(pPassVoteExclRrrTermPollsPc);
    }else if (pPollN == POLL_CHANGE_VALID_MEMS_RT_PC_N) {
      // Percentage of Members to vote for a Release reserve & restart or Termination poll to be valid
      pValidMemsRrrTermPollsPc = pChangePollToValue;
      emit PollChangeValidMemsRrrTermPollsPcV(pValidMemsRrrTermPollsPc);
    }else if (pPollN == POLL_CHANGE_PASS_RT_PC_N) {
      // Percentage of yes votes of PIOs voted to approve a Release reserve & restart or Termination poll
      pPassVoteRrrTermPollsPc = pChangePollToValue;
      emit PollChangePassVoteRrrTermPollsPcV(pPassVoteRrrTermPollsPc);
    }else if (pPollN == POLL_RELEASE_RESERVE_PIOS_N)
      // Release some of the PIOs held in reserve and restart the DAICO
      emit PollReleaseReserveAndRestartDaiso(pChangePollToValue);
    else if (pPollN == POLL_TERMINATE_FUNDING_N)
      // Terminate funding and refund all remaining funds in Mfund in proportion to PIOs held. Applicable only after the sale has closed.
      pHubC.PollTerminateFunding();
    else
      revert('Unknown poll close enum');
    return true; // Poll has closed with a Yes vote
  } // End of pClosePoll()

  // Poll.VoteYes()
  // --------------
  // To be called from an account for a yes vote
  function VoteYes() external IsNotContractCaller IsActive {
    pVote(msg.sender, VOTE_YES_N);
  }

  // Poll.WebVoteYes()
  // -----------------
  // To be called from a Pacio web site for a yes vote by a logged in Member
  function WebVoteYes(address voterA) external IsWebCaller IsActive {
    pVote(voterA, VOTE_YES_N);
  }

  // Poll.VoteNo()
  // -------------
  // To be called from an account for a no vote
  function VoteNo() external IsNotContractCaller IsActive {
    pVote(msg.sender, VOTE_NO_N);
  }

  // Poll.WebVoteNo()
  // ----------------
  // To be called from a Pacio web site for a no vote by a logged in Member
  function WebVoteNo(address voterA) external IsWebCaller IsActive {
    pVote(voterA, VOTE_NO_N);
  }

  // Poll.pVote() private
  // ------------
  function pVote(address voterA, uint8 voteN) private {
    require(pState & STATE_POLL_RUNNING_B > 0, 'No poll in progress');
    (uint32 piosVoted, uint32 numMembersVotedFor, uint8 prevVoteN) = pListC.Vote(voterA, pPollId, voteN);
    require(piosVoted != 0, 'Vote not valid');
    if (voteN == VOTE_REVOKE_N) {
      // Revoking previous vote
      if (prevVoteN == VOTE_YES_N)
        // Was a yes vote
        pPiosVotedYes = subMaxZero32(pPiosVotedYes, piosVoted);
      else
        // Was a no vote
        pPiosVotedNo = subMaxZero32(pPiosVotedNo, piosVoted);
      pNumMembersVoted = subMaxZero32(pNumMembersVoted, numMembersVotedFor);
      emit VoteV(pPollId, voterA, prevVoteN, -int32(piosVoted), -int32(numMembersVotedFor), pPiosVotedYes, pPiosVotedNo, pNumMembersVoted);
    }else{
      // Yes or No expected
      if (voteN == VOTE_YES_N)
        pPiosVotedYes += piosVoted;
      else
        pPiosVotedNo  += piosVoted;
      pNumMembersVoted += numMembersVotedFor;
      emit VoteV(pPollId, voterA, voteN, int32(piosVoted), int32(numMembersVotedFor), pPiosVotedYes, pPiosVotedNo, pNumMembersVoted);
    }
    pCheckForEndOfPoll();
  }

  // Poll.VoteRevoke()
  // -----------------
  // To be called from an account for revoking a vote
  function VoteRevoke() external IsNotContractCaller IsActive {
    pVote(msg.sender, VOTE_REVOKE_N);
  }

  // Poll.WebVoteRevoke()
  // --------------------
  // To be called from a Pacio web site for revoking a vote by a logged in Member
  function WebVoteRevoke(address voterA) external IsWebCaller IsActive {
    pVote(voterA, VOTE_REVOKE_N);
  }

  // Owners: Deployer OpMan Hub Admin Web

  // Poll.NewOwner()
  // ---------------
  // Called from Hub.NewOpManContractMO() with ownerX = OPMAN_OWNER_X if the OpMan contract is changed
  //             Hub.NewHubContractMO()   with ownerX = HUB_OWNER_X   if the Hub   contract is changed
  function NewOwner(uint256 ownerX, address newOwnerA) external IsHubContractCaller {
    emit ChangeOwnerV(iOwnersYA[ownerX], newOwnerA, ownerX);
    iOwnersYA[ownerX] = newOwnerA;
  }

  // Poll.NewHubContract()
  // ---------------------
  // Called from Hub.NewHubContract()
  function NewHubContract(address newHubContractA) external IsHubContractCaller {
    pHubC = I_HubPoll(newHubContractA);
  }

  // Poll.NewSaleContract()
  // ----------------------
  // Called from Hub.NewSaleContract() if the Sale contract is changed.
  function NewSaleContract(address newSaleContractA) external IsHubContractCaller {
    pSaleC = I_SalePoll(newSaleContractA);
  }

  // Poll.NewListContract()
  // ----------------------
  // Called from Hub.NewListContract() if the List contract is changed. newListContractA is checked and logged by Hub.NewListContract()
  function NewListContract(address newListContractA) external IsHubContractCaller {
    pListC = I_ListPoll(newListContractA);
  }

  // Poll.NewMfundContract()
  // ----------------------
  // Called from Hub.NewMfundContract()
  function NewMfundContract(address newMfundContractA) external IsHubContractCaller {
    pMfundC = I_MfundPoll(newMfundContractA);
  }


  // Poll Fallback function
  // ======================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Poll contract other than via the defined methods with their testing for valid access
  }

} // End Poll contract
