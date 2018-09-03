/* \Hub\Hub.sol 2018.07.13 started

The hub or management contract for the Pacio DAICO

Owned by Deployer OpMan Self Admin Sale Poll  Web

Calls OpMan; Sale; Token; List; Mfund; Pfund; Poll

djh??

• fns for replacing contracts - all of them
  To be MO fnd
• Provide an emergency reset of the pRefundInProgressB bools
• initialise new list contract

Pause/Resume
============
OpMan.PauseContract(HUB_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(HUB_CONTRACT_X) IsConfirmedSigner which is a managed op

Hub Fallback function
=====================
Sending Ether is not allowed

*/

pragma solidity ^0.4.24;
//pragma experimental "v0.5.0";

import "../lib/OwnedHub.sol";
import "../lib/Math.sol";
import "../Sale/I_Sale.sol";
import "../Token/I_TokenHub.sol";
import "../List/I_ListHub.sol";
import "../Funds/I_MfundHub.sol";
import "../Funds/I_PfundHub.sol";
import "../Poll/I_Poll.sol";

contract Hub is OwnedHub, Math {
  string public name = "Pacio DAICO Hub"; // contract name
  uint32     private pState;       // DAICO state using the STATE_ bits. Passed through to Sale, Token, Mfund, and Pfund on change
  uint8      private pPollN;       // Enum of Poll in progress, if any
  address    private pPclAccountA; // The PCL account for withdrawals. Stored here just to avoid an Mfund.PclAccount() call in pIsAccountOkB()
  I_OpManHub private pOpManC;      // the OpMan contract
  I_Sale     private pSaleC;       // the Sale contract
  I_TokenHub private pTokenC;      // the Token contract
  I_ListHub  private pListC;       // the List contract
  I_MfundHub private pMfundC;      // the Mfund contract
  I_PfundHub private pPfundC;      // the Pfund contract
  I_Poll     private pPollC;       // the Poll contract
  bool private pRefundInProgressB; // to prevent re-entrant refund calls
  uint256 private pRefundId;       // Refund Id

  // No Constructor
  // ==============

  // View Methods
  // ============
  // Hub.DaicoState()
  function DaicoState() external view returns (uint32) {
    return pState;
  }
  // Hub.IsTransferAllowedByDefault()
  function IsTransferAllowedByDefault() external view returns (bool) {
    return pListC.IsTransferAllowedByDefault();
  }
  // Hub.RefundId()
  function RefundId() external view returns (uint256) {
    return pRefundId;
  }

  // Events
  // ======
  event InitialiseV(address OpManContract, address SaleContract, address TokenContract, address ListContractt, address PfundContract, address MfundContract, address PollContract);
  event SetPclAccountV(address PclAccount);
  event StateChangeV(uint32 PrevState, uint32 NewState);
  event SetSaleTimesV(uint32 StartTime, uint32 EndTime);
  event StartSaleV();
  event SoftCapReachedV();
  event CloseSaleV();
  event   TokenSwapV(address indexed To, uint256 Picos, uint32 Tranche);
  event BountyIssueV(address indexed To, uint256 Picos, uint32 Tranche);
  event RefundV(uint256 indexed RefundId, address indexed Account, uint256 RefundWei, uint32 RefundBit);
  event PfundRefundingCompleteV();
  event MfundRefundingCompleteV();
  event PollStartV(uint32 PollId, uint8 PollN);
  event   PollEndV(uint32 PollId, uint8 PollN);
  event PollTerminateFundingV();
  event NewSaleContractV(address OldSaleContract, address NewSaleContract);
  event NewListContractV(address OldListContract, address NewListContract);

  // Initialisation/Setup Methods
  // ============================

  // Owned by Deployer OpMan Self Admin Sale Poll  Web
  // Deployer and Self are set by the OwnedHub constructor
  // Others must first be set by deploy script calls:
  //   Hub.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
  //   Hub.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
  //   Hub.ChangeOwnerMO(SALE_OWNER_X, Sale address)
  //   Hub.ChangeOwnerMO(POLL_OWNER_X, Poll address);
  //   Hub.ChangeOwnerMO(HUB_WEB_OWNER_X, Web account address)

  // Hub.Initialise()
  // ----------------
  // To be called by the deploy script to set the contract address variables.
  function Initialise() external IsInitialising {
    pOpManC = I_OpManHub(iOwnersYA[OP_MAN_OWNER_X]);
    pSaleC  =  I_Sale(iOwnersYA[SALE_OWNER_X]);
    pPollC  =  I_Poll(iOwnersYA[POLL_OWNER_X]);
    pTokenC = I_TokenHub(pOpManC.ContractXA(TOKEN_CONTRACT_X));
    pListC  =  I_ListHub(pOpManC.ContractXA(LIST_CONTRACT_X));
    pPfundC = I_PfundHub(pOpManC.ContractXA(PFUND_CONTRACT_X));
    pMfundC = I_MfundHub(pOpManC.ContractXA(MFUND_CONTRACT_X));
  //pSetState(STATE_PRIOR_TO_OPEN_B); Leave as 0 until SetSaleTimes() sets state
    emit InitialiseV(pOpManC, pSaleC, pTokenC, pListC, pPfundC, pMfundC, pPollC);
    iPausedB       =        // make active
    iInitialisingB = false;
  }

  // Hub.SetPclAccountMO()
  // ---------------------
  // Called by the deploy script when initialising
  //  or manually as Admin as a managed op to set/update the PCL withdrawal account
  // Is passed on to MFund for withdrawals, to Sale for Tranche 1 purchases, and to PFund for Tranche 1 PM transfers
  function SetPclAccountMO(address vPclAccountA) external {
    require(iIsInitialisingB() || (iIsAdminCallerB() && I_OpManHub(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(HUB_SET_PCL_ACCOUNT_MO_X)));
    require(pIsAccountOkB(vPclAccountA)); // will reject a vPclAccountA that is the same aas the current pPclAccountA
    pPclAccountA = vPclAccountA; // The PCL account for withdrawals. Stored here just to avoid an Mfund.PclAccount() call in pIsAccountOkB()
    pMfundC.SetPclAccount(vPclAccountA);
     pSaleC.SetPclAccount(vPclAccountA);
    pPfundC.SetPclAccount(vPclAccountA);
    emit SetPclAccountV(vPclAccountA);
  }

  // Hub.PresaleIssue()
  // ------------------
  // To be called repeatedly for all Seed Presale and Private Placement contributors (aggregated) to initialise the DAICO for tokens issued in the Seed Presale and the Private Placement`
  // no pPicosCap check
  // Expects list account not to exist - multiple Seed Presale and Private Placement contributions to same account should be aggregated for calling this fn
  function PresaleIssue(address toA, uint256 picos, uint256 vWei, uint32 dbId, uint32 vAddedT, uint32 vNumContribs) external IsAdminCaller {
    require(pIsAccountOkB(toA)); // Check that toA is defined and not any of the contracts or Admin
    require(pListC.CreatePresaleEntry(toA, dbId, vAddedT, vNumContribs));
    pSaleC.PresaleIssue(toA, picos, vWei, dbId, vAddedT, vNumContribs); // reverts if sale has started
  }

  // Hub.SetSaleTimes()
  // ------------------
  // To be called manually by Admin to set the sale dates. Can be called well before start time which allows registration, Prepurchase escrow deposits, and white listing but wo PIOs being issued until that is done after the sale opens
  // Can also be called to adjust settings.
  // The STATE_SALE_OPEN_B state bit gets set when the first Sale.pProcess() transaction >= Sale.pSaleStartT comes through, or here on a restart after a close.
  // Initialise(), Sale.SetCapsAndTranchesMO(), Sale.SetUsdEtherPrice(), Sale.EndInitialise(), Mfund.SetPclAccountMO(), Mfund.EndInitialise() and PresaleIssue() multiple times must have been called before this.
  function SetSaleTimes(uint32 vStartT, uint32 vEndT) external IsAdminCaller {
    // Could Have previous state settings = a restart
    // Unset everything except for STATE_S_CAP_REACHED_B.  Should not allow 2 soft cap state changes.
    pSetState((pState & STATE_S_CAP_REACHED_B > 0 ? STATE_S_CAP_REACHED_B : 0) | (uint32(now) >= vStartT ? STATE_SALE_OPEN_B : STATE_PRIOR_TO_OPEN_B));
    pSaleC.SetSaleTimes(vStartT, vEndT);
    emit SetSaleTimesV(vStartT, vEndT);
  }

  // Hub.pSetState() private
  // ---------------
  // Called to change state and to replicate the change.
  // Any setting/unsetting must be done by the calling function. This does =
  function pSetState(uint32 vState) private {
    if (vState != pState) {
       pSaleC.StateChange(vState);
      pTokenC.StateChange(vState);
       pListC.StateChange(vState);
      pMfundC.StateChange(vState);
      pPfundC.StateChange(vState);
       pPollC.StateChange(vState);
      emit StateChangeV(pState, vState);
      pState = vState;
    }
  }

  // Hub.StartSaleMO()
  // -----------------
  // Is called from Sale.pProcess() when the first buy arrives after the sale pSaleStartT
  // Can be called manually by Admin as a managed op if necessary.
  function StartSaleMO() external {
    require(iIsSaleContractCallerB() || (iIsAdminCallerB() && pOpManC.IsManOpApproved(HUB_START_SALE_X)));
    pSetState(STATE_SALE_OPEN_B);
    emit StartSaleV();
  }

  // Hub.SoftCapReachedMO()
  // ----------------------
  // Is called from Sale.pSoftCapReached() on soft cap being reached
  // Can be called manually by Admin as a managed op if necessary.
  function SoftCapReachedMO() external {
    require(iIsSaleContractCallerB() || (iIsAdminCallerB() && pOpManC.IsManOpApproved(HUB_SOFT_CAP_REACHED_MO_X)));
    pSetState(pState |= STATE_S_CAP_REACHED_B);
    emit SoftCapReachedV();
  }

  // Hub.CloseSaleMO()
  // -----------------
  // Is called:
  // - by Sale.pCloseSale() to end the sale on hard cap being reached vBit == STATE_CLOSED_H_CAP_B, or time up vBit == STATE_CLOSED_TIME_UP_B
  // - by Poll.pClosePoll() on a vote to end the sale with vBit = STATE_CLOSED_POLL_B
  // - Manually by Admin to end the sale prematurely as a HUB_CLOSE_SALE_MO_X managed op if necessary. In that case vBit is not used and the STATE_CLOSED_MANUAL_B state bit is used
  function CloseSaleMO(uint32 vBit) external {
    uint32 bitsToSet;
    if (iIsSaleContractCallerB())
      bitsToSet = vBit; // Expected to be STATE_CLOSED_H_CAP_B | STATE_CLOSED_TIME_UP_B
    if (iIsPollContractCallerB())
      bitsToSet = vBit; // Expected to be STATE_CLOSED_POLL_B
    else if (iIsAdminCallerB() && pOpManC.IsManOpApproved(HUB_CLOSE_SALE_MO_X))
      bitsToSet = STATE_CLOSED_MANUAL_B;
    else
      revert();
    if (pState & STATE_S_CAP_REACHED_B > 0)
      bitsToSet |= STATE_S_CAP_REACHED_B | STATE_TAPS_OK_B; // leave STATE_S_CAP_REACHED_B set and also set STATE_TAPS_OK_B
    pSetState(bitsToSet);
    emit CloseSaleV();
  }

  // Hub.PollStartEnd()
  // ----------------
  // Called from Poll to start/end a poll, start when vPollN is set, end when vPollN is 0
  function PollStartEnd(uint32 vPollId, uint8 vPollN) external IsPollContractCaller {
    require(vPollN >= 0 && vPollN <= NUM_POLLS); // range check of vPollN. Should be ok if called from Poll as intended so no fail msg
    if (vPollN > 0) {
      pSetState(pState |= STATE_POLL_RUNNING_B);
      emit PollStartV(vPollId, vPollN);
    }else{
      pSetState(pState &= ~STATE_POLL_RUNNING_B);
      emit PollEndV(vPollId, pPollN);
    }
    pPollN = vPollN;
  }

  // Hub.PollTerminateFunding()
  // --------------------------
  // Called from Poll.pClosePoll() when a POLL_TERMINATE_FUNDING_N poll has voted to end funding the project, Mfund funds to be refunded in proportion to Picos held
  // After this only refunds and view functions should work. No transfers. No Deposits.
  function PollTerminateFunding() external IsPollContractCaller {
    pSetState(pState |= STATE_TERMINATE_REFUND_B);
    pOpManC.PauseContract(SALE_CONTRACT_X); // IsHubContractCallerOrConfirmedSigner
    pListC.SetTransfersOkByDefault(false);
    emit PollTerminateFundingV();
  }

  // Hub.SetTransferToPacioBcStateMO()
  // ---------------------------------
  // To be called by Admin as a managed op when starting the process of transferring to the Pacio Blockchain with vBit = STATE_TRANSFER_TO_PB_B
  //                                                                        and when the process is finished with vBit = STATE_TRANSFERRED_TO_PB_B
  function SetTransferToPacioBcStateMO(uint32 vBit) external IsAdminCaller {
    require((vBit == STATE_TRANSFER_TO_PB_B || vBit == STATE_TRANSFERRED_TO_PB_B)
         && pOpManC.IsManOpApproved(HUB_SET_TRAN_TO_PB_STATE_MO_X));
    pSetState(pState |= vBit);
  }

  // Hub.Whitelist()
  // ---------------
  // Called by Admin or from web to whitelist an entry.
  // Possible actions:
  // a. Registered only account (no funds)                   -> whitelisting only
  // b. Pfund not whitelisted account with sale not yet open -> whitelisting only
  // c. Pfund not whitelisted account with sale open         -> whitelisting plus -> Mfund with PIOs issued
  // d. Mfund presale not whitelisted account                -> whitelisting plus presale bits and counts updated
  // If 0 is passed for vWhiteT then now is used
  function Whitelist(address accountA, uint32 vWhiteT) external IsWebOrAdminCaller IsActive returns (bool) {
    uint32  bits = pListC.EntryBits(accountA);
    require(bits > 0, 'Unknown account');
    require(bits & LE_WHITELISTED_B == 0, 'Already whitelisted');
    pListC.Whitelist(accountA, vWhiteT > 0 ? vWhiteT : uint32(now)); // completes cases a, b, d
    return (bits & LE_P_FUND_B > 0 && pState & STATE_SALE_OPEN_B > 0) ? pPMtransfer(accountA) // Case c) Pfund -> Mfund with PIOs issued
                                                                 : true; // cases a, b, d
  }

  // Hub.PMtransfer()
  // ----------------
  // Called by Admin or from web to transfer a Pfund whitelisted account that was still in Pfund because the sale had not opened yet, to Mfund with PIOs issued following opening of the sale.
  function PMtransfer(address accountA) external IsWebOrAdminCaller IsActive returns (bool) {
    uint32  bits = pListC.EntryBits(accountA);
    require(bits > 0, 'Unknown account');
    require(bits & LE_WHITELISTED_B > 0, 'Not whitelisted');
    require(bits & LE_P_FUND_B > 0 && pState & STATE_SALE_OPEN_B > 0, 'Invalid PMtransfer call');
    return pPMtransfer(accountA);
  }

  // Hub.pPMtransfer() private
  // -----------------
  // Cases:
  // a. Hub.Whitelist()  -> here -> Sale.PMtransfer() -> Sale.pProcess()-> Token.Issue() -> List.Issue() for Pfund to Mfund transfers on whitelisting
  // b. Hub.PMtransfer() -> here -> Sale.PMtransfer() -> Sale.pProcess()-> Token.Issue() -> List.Issue() for Pfund to Mfund transfers for an entry which was whitelisted and ready prior to opening of the sale which has now happened
  // then finally calls Pfund.PMTransfer() to transfer the Ether from P to M or to pPclAccountA if it is a Tranche 1 case
  function pPMtransfer(address accountA) private returns (bool) {
    uint256 weiContributed = Min(pListC.WeiContributed(accountA), pPfundC.FundWei());
     pSaleC.PMtransfer(accountA, weiContributed); // processes the issue
    pPfundC.PMTransfer(accountA, weiContributed, pListC.EntryBits(accountA) & LE_TRANCH1_B > 0); // transfers weiContribured from the Pfund to the Mfund or to pPclAccountA if it is a Tranche 1 case
    // Pfund.PMTransfer() emits an event
    return true;
  }

  // Hub.TokenSwap()
  // ---------------
  // Called by Admin to perform the Pacio part of a token swap
  // toA is expected to exist and not to be funded
  function TokenSwap(address toA, uint256 picos, uint32 tranche) external IsAdminCaller IsActive returns (bool) {
    require(pState & STATE_DEPOSIT_OK_B > 0, 'Sale has closed'); // STATE_PRIOR_TO_OPEN_B | STATE_SALE_OPEN_B
    require(pIsAccountOkB(toA)); // Check that toA is defined and is not a contract or Admin or Web or pPclAccountA
    uint32 bits = pListC.EntryBits(toA);
    require(bits > 0 && bits & LE_FUNDED_B == 0, 'Existing unfunded account required');
    pSaleC.TokenSwapAndBountyIssue(toA, picos, tranche);
    emit TokenSwapV(toA, picos, tranche);
    return true;
  }

  // Hub.BountyIssue()
  // -----------------
  // Called by Admin to issue bounty tokens
  // toA is expected to exist
  function BountyIssue(address toA, uint256 picos, uint32 tranche) external IsAdminCaller IsActive returns (bool) {
    require(pState & STATE_TRANS_ISSUES_NOK_B == 0, 'Bounty issue nok'); // Check that state does not prohibit issues
    require(pIsAccountOkB(toA)); // Check that toA is defined and is not a contract or Admin or Web or pPclAccountA
    uint32 bits = pListC.EntryBits(toA);
    require(bits > 0 && bits & LE_TRANSFERS_NOK_B == 0, 'Account NOK');
    pSaleC.TokenSwapAndBountyIssue(toA, picos, tranche);
    emit BountyIssueV(toA, picos, tranche);
    return true;
  }

  // Hub.Refund()
  // ------------
  // Pull refund request from a contributor, not a contract
  function Refund() external IsNotContractCaller returns (bool) {
    return pRefund(msg.sender, false);
  }

  // Hub.PushRefund()
  // ----------------
  // Push refund request from web or admin, not a contract
  function PushRefund(address toA, bool vOnceOffB) external IsWebOrAdminCaller returns (bool) {
    return pRefund(toA, vOnceOffB);
  }

  // Hub.pRefund() private
  // -------------
  // Private fn to process a refund, called by Hub.Refund() or Hub.PushRefund()
  // Calls: List.EntryBits()                     - for type info
  //        here for Pfund or Mfund.RefundInfo() - for refund info: picos, amount and bit
  //        Token.Refund() -> List.Refund()      - to update Token and List data, in the reverse of an Issue
  //        Pfund/Mfund.Refund()                 - to do the actual refund
  function pRefund(address toA, bool vOnceOffB) private returns (bool) {
    require(!pRefundInProgressB, 'Refund already in Progress'); // Prevent re-entrant calls
    pRefundInProgressB = true;
    uint256 refundPicos;
    uint256 refundWei;
    uint32  refundBit;
    uint32  bits = pListC.EntryBits(toA);
    bool pfundB;
    require(bits > 0 && bits & LE_REFUNDS_NOK_B == 0   // LE_REFUNDS_NOK_B is not a complete check
         && (vOnceOffB || pState & STATE_REFUNDING_B > 0));
    if (bits & LE_P_FUND_B > 0) {
      // Pfund Refund
      pfundB = true;
      if (vOnceOffB)
        refundBit = LE_P_REFUNDED_ONCE_OFF_B;
      else if (pState & STATE_S_CAP_MISS_REFUND_B > 0)
        refundBit = LE_P_REFUNDED_S_CAP_MISS_B;
      else if (pState & STATE_SALE_CLOSED_B > 0)
        refundBit = LE_P_REFUNDED_SALE_CLOSE_B;
      if (refundBit > 0)
        refundWei = Min(pListC.WeiContributed(toA), pPfundC.FundWei());
    }else if (bits & LE_HOLDS_PICOS_B > 0) {
      // Mfund Refund which could be for a presale or tranche 1 investor not entitled to a soft cap miss refund
      if (vOnceOffB || ( pState & STATE_S_CAP_MISS_REFUND_B == 0 || bits & LE_PRESALE_TRANCH1_B == 0))
        // is a manual once off refund or is not for a soft cap miss Presale/Tranche 1 investor
        (refundPicos, refundWei, refundBit) = pMfundC.RefundInfo(pRefundId, toA); // returns refundBit = LE_M_REFUNDED_S_CAP_MISS_NPT1B || LE_M_REFUNDED_TERMINATION_B || 0
      // else no refund for a non once off Presale/Tranche 1 investor unless done manually
      if (vOnceOffB)
        refundBit = LE_M_REFUNDED_ONCE_OFF_B;

    }
    require(refundWei > 0, 'No refund available');
    pTokenC.Refund(++pRefundId, toA, refundWei, refundBit); // IsHubContractCaller IsActive -> List.refund()
    if (pfundB) {
      if (!pPfundC.Refund(pRefundId, toA, refundWei, refundBit)) {
        if (pPfundC.FundWei() == 0) {
          pSetState(pState |= STATE_PFUND_EMPTY_B);
          emit PfundRefundingCompleteV();
        }
      }
    }else{
      if (!pMfundC.Refund(pRefundId, toA, refundPicos, refundWei, refundBit)) {
        if (pMfundC.FundWei() == 0) {
          pSetState(pState |= STATE_MFUND_EMPTY_B);
          emit MfundRefundingCompleteV();
        }
      }
    }
    emit RefundV(pRefundId, toA, refundWei, refundBit);
    pRefundInProgressB = false;
    return true;
  }

  // New Contracts Being Deployed
  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  //   Contract Owned By                                   External Calls
  //   -------- --------                                   --------------
  //   OpMan    Deployer Self  Hub  Admin                  All including self
  //   Hub      Deployer OpMan Self Admin Sale Poll Web    OpMan Sale Token List Mfund Pfund Poll
  //   Sale     Deployer OpMan Hub  Admin Poll             OpMan Hub List Token Mfund Pfund
  //   Token    Deployer OpMan Hub  Admin Sale             OpMan List
  // * List     Deployer OpMan Hub  Token Sale Poll        OpMan
  //   Mfund    Deployer OpMan Hub  Admin Sale Poll Pfund  OpMan List
  //   Pfund    Deployer OpMan Hub  Sale                   OpMan Mfund
  //   Poll     Deployer OpMan Hub  Admin Web              OpMan Hub Sale List Mfund

  // If a New Sale contract is deployed
  // **********************************
  // Hub.NewSaleContract()
  // ---------------------
  // To be called manually as a managed op via the ChangeContractMO() call to change the Sale contract in OpMan, here and in the Poll contract, plus change the Sale owner for Hub, Token, List, Mfund, Pfund
  // Expects the old Sale contract to have been paused
  // Calling NewSaleContract() will stop calls from the old Sale contract to the Token contract IsSaleContractCaller functions from working
  // * OpMan
  // * Hub   sale contract pSaleC
  // * Poll  sale contract pSaleC
  // * Token sale address  pSaleA
  // * List  sale address  pSaleA
  // * Hub   Sale owner    iOwnersYA[SALE_OWNER_X]
  // * Token Sale owner    iOwnersYA[SALE_OWNER_X]
  // * List  Sale owner    iOwnersYA[SALE_OWNER_X]
  // * Mfund Sale owner    iOwnersYA[SALE_OWNER_X]
  // * Pfund Sale owner    iOwnersYA[PFUND_SALE_OWNER_X]
  function NewSaleContract(address newSaleContractA) external IsAdminCaller {
    require(pSaleC.Paused());
    require(pIsContractB(newSaleContractA)); // Checks that contractA is a contract. The following ChangeContractMO() call checks that it is not one of the current contracts.
    require(pOpManC.ChangeContractMO(SALE_CONTRACT_X, newSaleContractA)); // MO which also checks that newSaleContractA is not a duplicateContract
    emit ChangeOwnerV(pSaleC, newSaleContractA, SALE_OWNER_X);
    emit NewSaleContractV(pSaleC, newSaleContractA);
    pSaleC = I_Sale(newSaleContractA);
    iOwnersYA[SALE_OWNER_X] = newSaleContractA;
    pTokenC.NewSaleContract(newSaleContractA); // which creates a new Sale list entry and transfers the old Sale picos to the new entry
    pMfundC.NewSaleContract(newSaleContractA);
    pPfundC.NewSaleContract(newSaleContractA);
     pPollC.NewSaleContract(newSaleContractA);
  }

  // If a New List contract is deployed
  // **********************************
  // Hub.NewListContract()
  // ---------------------
  // To be called manually to change the List contract here and in the Sale, Token, Mfund, and Poll contracts.
  // The new List contract would need to have been initialised
  // * OpMan
  // * Hub   List contract pListC
  // * Sale  List contract pListC
  // * Token List contract iListC
  // * Mfund List contract pListC
  // * Poll  List contract pListC
  // No contract has List as an owner
  function NewListContract(address newListContractA) external IsAdminCaller {
    require(pIsContractB(newListContractA)); // Checks that contractA is a contract. The following ChangeContractMO() call checks that it is not one of the current contracts.
    require(pOpManC.ChangeContractMO(LIST_CONTRACT_X, newListContractA)); // MO which also checks that newListContractA is not a duplicateContract
    emit NewListContractV(pListC, newListContractA);
    pListC = I_ListHub(newListContractA);
     pSaleC.NewListContract(newListContractA);
    pTokenC.NewListContract(newListContractA);
    pMfundC.NewListContract(newListContractA);
     pPollC.NewListContract(newListContractA);
  }

  // If a New Token contract is deployed
  // ***********************************
  // Hub.NewTokenContract()
  // ----------------------
  // To be called manually. Token needs to be initialised after this.
  // function NewTokenContract(address vNewTokenContractA) external IsAdminCaller {
  //   pTokenC.NewTokenContract(vNewTokenContractA); // Changes Owner2 of the List contract to the new Token contract
  //   pTokenC = I_TokenHub(vNewTokenContractA);
  // }

  // Hub.pIsContractB() private
  // ------------------
  // Checks that contractA is a contract
  function pIsContractB(address contractA) private view returns (bool) {
    uint256 codeSize;
    assembly {codeSize := extcodesize(contractA)}
    return codeSize > 0;
  }

  // Functions for Calling List IsHubContractCaller Functions
  // ========================================================
  // Hub.Browse()
  // ------------
  // Returns address and type of the list entry being browsed to
  // Parameters:
  // - currentA  Address of the current entry, ignored for vActionN == First | Last
  // - vActionN  BROWSE_FIRST, BROWSE_LAST, BROWSE_NEXT, BROWSE_PREV  Browse action to be performed
  // Returns:
  // - retA   address of the list entry found, 0x0 if none
  // - bits   of the entry
  // Note: Browsing for a particular type of entry is not implemented as that would involve looping -> gas problems.
  //       The calling app will need to do the looping if necessary, thus the return of typeN.
  function Browse(address currentA, uint8 vActionN) external view IsWebOrAdminCaller returns (address retA, uint32 bits) {
    return pListC.Browse(currentA, vActionN);
  }
  // Hub.NextEntry()
  // ---------------
  function NextEntry(address accountA) external view IsWebOrAdminCaller returns (address) {
    return pListC.NextEntry(accountA);
  }
  // Hub.PrevEntry()
  // ---------------
  function PrevEntry(address accountA) external view IsWebOrAdminCaller returns (address) {
    return pListC.PrevEntry(accountA);
  }

  // Hub.CreateListEntry()
  // ---------------------
  // Create a new list entry, and add it into the doubly linked list.
  // accountA Must be defined and not be a any of the contracts or Admin
  // List.CreateListEntry() sets the LE_REGISTERED_B bit so there is no need to include that in vBits
  function CreateListEntry(address accountA, uint32 vBits, uint32 dbId) external IsWebOrAdminCaller IsActive returns (bool) {
    require(pIsAccountOkB(accountA)); // Check that accountA is defined and is not a contract or Admin or Web or pPclAccountA
    return pListC.CreateListEntry(accountA, vBits, dbId);
  }

  // Hub.pIsAccountOkB() private
  // -------------------
  // Checks that accountA is defined and is not a contract or Admin or Web or pPclAccountA
  // Owners: Deployer OpMan Hub (Self) 3: Admin 4: Sale 5: Poll  6: Web
  function pIsAccountOkB(address accountA) private view returns (bool) {
    uint256 codeSize;
    assembly {codeSize := extcodesize(accountA)}
    require(codeSize == 0
         && accountA != address(0)
         && accountA != iOwnersYA[ADMIN_OWNER_X]
         && accountA != iOwnersYA[HUB_WEB_OWNER_X]
       //&& accountA != pMfundC.PclAccount(), 'Account conflict');
         && accountA != pPclAccountA, 'Invalid Account');
    return true;
  }

  // Hub.Downgrade()
  // ---------------
  // Downgrades an entry from whitelisted
  function Downgrade(address accountA, uint32 vDownT) external IsWebOrAdminCaller IsActive returns (bool) {
    pListC.Downgrade(accountA, vDownT);
    return true;
  }
  // Hub.SetBonus()
  // --------------
  // Sets bonusCentiPc Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
  function SetBonus(address accountA, uint32 vBonusPc) external IsWebOrAdminCaller IsActive returns (bool) {
    pListC.SetBonus(accountA, vBonusPc);
    return true;
  }

  // Hub.SetTransfersOkByDefault()
  // -----------------------------
  // To set/unset List.pTransfersOkB
  function SetTransfersOkByDefault(bool B) external IsAdminCaller returns (bool) {
    pListC.SetTransfersOkByDefault(B);
    return true;
  }

  // Hub.SetListEntryTransferOk()
  // -------------------
  // To set LE_FROM_TRANSFER_OK_B bit of entry accountA on if B is true, or unset the bit if B is false
  function SetListEntryTransferOk(address accountA, bool B) external IsWebOrAdminCaller IsActive returns (bool) {
    pListC.SetListEntryTransferOk(accountA, B);
    return true;
  }

  // Hub.SetListEntryBitsMO()
  // -----------------------
  // Managed operation to set/unset bits in a list entry
  function SetListEntryBitsMO(address accountA, uint32 bitsToSet, bool unsetB) external IsAdminCaller IsActive returns (bool) {
    require(pOpManC.IsManOpApproved(HUB_SET_LIST_ENTRY_BITS_MO_X));
    pListC.SetListEntryBits(accountA, bitsToSet, unsetB);
    // List.SetListEntryBits emits List.SetListEntryBitsV(accountA, bitsToSet, unsetB, bits, rsEntryR.bits);
    return true;
  }

  // Hub Fallback function
  // =====================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Hub contract other than via the defined methods with their testing for valid access
  }

} // End Hub contract
