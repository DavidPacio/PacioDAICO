/* \Hub\Hub.sol 2018.07.13 started

The hub or management contract for the Pacio DAICO

Owned by 0 Deployer, 1 OpMan, 2 Admin, 3 Sale, 4 VoteTap, 5 VoteEnd, 6 Web

Calls
OpMan; Sale; Token; List; Mfund; Pfund;
VoteTap; VoteEnd; Mvp djh??

djh??

• fns for replacing contracts - all of them
• Provide an emergency reset of the pRefundInProgressB bools

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
import "../OpMan/I_OpMan.sol";
import "../Sale/I_Sale.sol";
import "../Token/I_TokenHub.sol";
import "../List/I_ListHub.sol";
import "../Funds/I_MfundHub.sol";
import "../Funds/I_PfundHub.sol";
//port "../Votes/I_VoteTap.sol";
//port "../Votes/I_VoteEnd.sol";
import "../Mvp/I_Mvp.sol";

contract Hub is OwnedHub, Math {
  string public name = "Pacio DAICO Hub"; // contract name
  uint32     private pState;  // DAICO state using the STATE_ bits. Passed through to Sale, Token, Mfund, and Pfund on change
  I_OpMan    private pOpManC; // the OpMan contract
  I_Sale     private pSaleC;  // the Sale contract
  I_TokenHub private pTokenC; // the Token contract
  I_ListHub  private pListC;  // the List contract
  I_MfundHub private pMfundC; // the Mfund contract
  I_PfundHub private pPfundC; // the Pfund contract
  bool private pRefundInProgressB; // to prevent re-entrant refund calls
  uint256 private pRefundId;       // Refund Id

  // No Constructor
  // ==============

  // View Methods
  // ============
  // Hub.State()
  function State() external view returns (uint32) {
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
  event InitialiseV(address OpManContract, address SaleContract, address TokenContract, address ListContractt, address PfundContract, address MfundContract);
  event StateChangeV(uint32 PrevState, uint32 NewState);
  event SetSaleDatesV(uint32 StartTime, uint32 EndTime);
  event SoftCapReachedV();
  event EndSaleV();
  event RefundV(uint256 indexed RefundId, address indexed Account, uint256 RefundWei, uint32 RefundBit);
  event PfundRefundingCompleteV();
  event MfundRefundingCompleteV();

  // Initialisation/Setup Methods
  // ============================

  // Owned by 0 Deployer, 1 OpMan, 2 Admin, 3 Sale, 4 VoteTap, 5 VoteEnd, 6 Web
  // Owners must first be set by deploy script calls:
  //   Hub.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
  //   Hub.ChangeOwnerMO(ADMIN_OWNER_X,  PCL hw wallet account address as Admin)
  //   Hub.ChangeOwnerMO(SALE_OWNER_X,   Sale address)
  //   Hub.ChangeOwnerMO(VOTE_TAP_OWNER_X , VoteTap address);
  //   Hub.ChangeOwnerMO(VOTE_END_OWNER_X , VoteEnd address);
  //   Hub.ChangeOwnerMO(WEB_OWNER_X, Web account address)

  // Hub.Initialise()
  // ----------------
  // To be called by the deploy script to set the contract address variables.
  function Initialise() external IsInitialising {
    pOpManC = I_OpMan(iOwnersYA[OP_MAN_OWNER_X]);
    pSaleC  =  I_Sale(iOwnersYA[SALE_OWNER_X]);
    pTokenC = I_TokenHub(pOpManC.ContractXA(TOKEN_CONTRACT_X));
    pListC  =  I_ListHub(pOpManC.ContractXA(LIST_CONTRACT_X));
    pPfundC = I_PfundHub(pOpManC.ContractXA(PFUND_CONTRACT_X));
    pMfundC = I_MfundHub(pOpManC.ContractXA(MFUND_CONTRACT_X));
    emit InitialiseV(pOpManC, pSaleC, pTokenC, pListC, pPfundC, pMfundC);
    iPausedB       =        // make active
    iInitialisingB = false;
  }

  // Hub.PresaleIssue()
  // ------------------
  // To be called repeatedly for all Seed Presale and Private Placement contributors (aggregated) to initialise the DAICO for tokens issued in the Seed Presale and the Private Placement`
  // no pPicosCap check
  // Expects list account not to exist - multiple Seed Presale and Private Placement contributions to same account should be aggregated for calling this fn
  function PresaleIssue(address toA, uint256 vPicos, uint256 vWei, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external IsWebOrAdminCaller {
    require(pListC.CreatePresaleEntry(toA, vDbId, vAddedT, vNumContribs));
    pSaleC.PresaleIssue(toA, vPicos, vWei, vDbId, vAddedT, vNumContribs); // reverts if sale has started
  }

  // Hub.SetSaleDates()
  // ------------------
  // To be called manually by Admin to set the sale dates. Can be called well before start time which allows registration, Prepurchase escrow deposits, and white listing but wo PIOs being issued until that is done after the sale opens
  // Can also be called to adjust settings.
  // The STATE_OPEN_B state bit gets set when the first Sale.Buy() transaction >= Sale.pStartT comes through, or here on a restart after a close.
  // Initialise(), Sale.SetCapsAndTranchesMO(), Sale.SetUsdEtherPrice(), Sale.EndInitialise(), Mfund.SetPclAccountMO(), Mfund.EndInitialise() and PresaleIssue() multiple times must have been called before this.
  function SetSaleDates(uint32 vStartT, uint32 vEndT) external IsAdminCaller {
    // Could Have previous state settings = a restart
    // Unset everything except for STATE_S_CAP_REACHED_B.  Should not allow 2 soft cap state changes.
    pSetState((pState & STATE_S_CAP_REACHED_B > 0 ? STATE_S_CAP_REACHED_B : 0) + (uint32(now) >= vStartT ? STATE_OPEN_B : STATE_PRIOR_TO_OPEN_B));
    pSaleC.SetSaleDates(vStartT, vEndT);
    emit SetSaleDatesV(vStartT, vEndT);
  }

  // Hub.pSetState()
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
    //pVoteTapC.StateChange(vState); /- These can get state from Hub
    //pVoteEndC.StateChange(vState); |
      emit StateChangeV(pState, vState);
      pState = vState;
    }
  }

  // Hub.StartSaleMO()
  // -----------------
  // Is called from Sale.Buy() when the first buy arrives after the sale pStartT
  // Can be called manually by Admin as a managed op if necessary.
  function StartSaleMO() external {
    require(iIsSaleContractCallerB() || (iIsAdminCallerB() && pOpManC.IsManOpApproved(HUB_START_SALE_X)));
    pSetState(STATE_OPEN_B);
    emit SoftCapReachedV();
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
  // Is called from Sale.pCloseSale() to end the sale on hard cap being reached vBit == STATE_CLOSED_H_CAP_B, or time up vBit == STATE_CLOSED_TIME_UP_B
  // Can be called manually by Admin to end the sale prematurely as a managed op if necessary. In that case vBit is not used and the STATE_CLOSED_MANUAL_B state bit is used
  function CloseSaleMO(uint32 vBit) external {
    if (iIsSaleContractCallerB())
      pSetState(vBit);
    else if (iIsAdminCallerB() && pOpManC.IsManOpApproved(HUB_CLOSE_SALE_MO_X))
      pSetState(STATE_CLOSED_MANUAL_B);
    else
      revert();
    emit EndSaleV();
  }

  // Hub.TransferToPacioBlockchainMO()
  // ---------------------------------
  // To be called by Admin as a managed op when starting the process of transferring to the Pacio Blockchain with vBit = STATE_TRANSFER_TO_PB_B
  //                                                                        and when the process is finished with vBit = STATE_TRANSFERRED_TO_PB_B
  function TransferToPacioBlockchainMO(uint32 vBit) external IsVoteEndContractCaller {
    require((vBit == STATE_TRANSFER_TO_PB_B || vBit == STATE_TRANSFERRED_TO_PB_B)
         && iIsAdminCallerB()
         && pOpManC.IsManOpApproved(HUB_TRANSFER_TO_PB_MO_X));
    pSetState(pState |= vBit);
    I_Mvp(pOpManC.ContractXA(MVP_CONTRACT_X)).StateChange(pState);
  }

  // Hub.TerminateVote()
  // -------------------
  // Called when a VoteEnd vote has voted to end the project, Mfund funds to be refunded in proportion to Picos held
  // After this only refunds and view functions should work. No transfers. No Deposits.
  function TerminateVote() external IsVoteEndContractCaller {
    pSetState(pState |= STATE_TERMINATE_REFUND_B);
    pOpManC.PauseContract(SALE_CONTRACT_X); // IsHubContractCallerOrConfirmedSigner
    pListC.SetTransfersOkByDefault(false);
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
    return (bits & LE_P_FUND_B > 0 && pState & STATE_OPEN_B > 0) ? pPMtransfer(accountA) // Case c) Pfund -> Mfund with PIOs issued
                                                                 : true; // cases a, b, d
  }

  // Hub.PMtransfer()
  // ----------------
  // Called by Admin or from web to transfer a Pfund whitelisted account that was still in Pfund because the sale had not opened yet, to Mfund with PIOs issued following opening of the sale.
  function PMtransfer(address accountA) external IsWebOrAdminCaller IsActive returns (bool) {
    uint32  bits = pListC.EntryBits(accountA);
    require(bits > 0, 'Unknown account');
    require(bits & LE_WHITELISTED_B > 0, 'Not whitelisted');
    require(bits & LE_P_FUND_B > 0 && pState & STATE_OPEN_B > 0, 'Invalid PMtransfer call');
    return pPMtransfer(accountA);
  }

  // Hub.pPMtransfer() private
  // -----------------
  // Cases:
  // a. Hub.Whitelist()  -> here -> Sale.PMtransfer() -> Sale.pBuy()-> Token.Issue() -> List.Issue() for Pfund to Mfund transfers on whitelisting
  // b. Hub.PMtransfer() -> here -> Sale.PMtransfer() -> Sale.pBuy()-> Token.Issue() -> List.Issue() for Pfund to Mfund transfers for an entry which was whitelisted and ready prior to opening of the sale which has now happened
  // then finally transfer the Ether from P to M
  function pPMtransfer(address accountA) private returns (bool) {
    uint256 weiContributed = Min(pListC.WeiContributed(accountA), pPfundC.FundWei());
      pSaleC.PMtransfer(accountA, weiContributed);  // processes the issue
    pPfundC.PMTransfer(accountA, weiContributed); // transfers weiContribured from the Pfund to the Mfund
    // Pfund.PMTransfer() emits an event
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

  // Hub.pRefund()
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
    require(bits > 0 && bits & LE_NO_REFUND_COMBO_B == 0          // LE_NO_REFUND_COMBO_B is not a complete check
         && (vOnceOffB || pState & STATE_REFUNDING_COMBO_B > 0));
    if (bits & LE_P_FUND_B > 0) {
      // Pfund Refund
      pfundB = true;
      if (vOnceOffB)
        refundBit = LE_P_REFUND_ONCE_OFF_B;
      else if (pState & STATE_S_CAP_MISS_REFUND_B > 0)
        refundBit = LE_P_REFUND_S_CAP_MISS_B;
      else if (pState & STATE_CLOSED_COMBO_B > 0)
        refundBit = LE_P_REFUND_SALE_CLOSE_B;
      if (refundBit > 0)
        refundWei = Min(pListC.WeiContributed(toA), pPfundC.FundWei());
    }else if (bits & LE_PICOS_B > 0) {
      // Mfund or Presale Refund
      if (bits & LE_EVER_PRESALE_COMBO_B == 0)
        (refundPicos, refundWei, refundBit) = pMfundC.RefundInfo(pRefundId, toA);
      // else no refund for a Presale investor unless done manually
      if (vOnceOffB)
        refundBit = LE_M_REFUND_ONCE_OFF_B;
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

/*
djh??
  // If a New List contract is deployed
  // **********************************
  // Hub.NewListContract()
  // ---------------------
  // To be called manually to change the List contract here and in the Token contract.
  // The new List contract would need to have been initialised
  // pTokenC must have been set before this via Initialise() call.
  function NewListContract(address vNewListContractA) external IsAdminCaller {
    require(vNewListContractA != address(0)
         && vNewListContractA != address(this)
         && vNewListContractA != address(pTokenC));
    pListC = I_ListHub(vNewListContractA);
    pTokenC.NewListContract(vNewListContractA);
    emit NewListContractV(vNewListContractA);
  }

  // If a New Sale contract is deployed
  // **********************************
  // Hub.NewSaleContract()
  // ---------------------
  // To be called manually via the old Sale to change to the new Sale.
  // Expects the old Sale contract to have been paused
  // Calling NewSaleContract() will stop calls from the old Sale contract to the Token contract IsSaleContractCaller functions from working
  function NewSaleContract(address vNewSaleContractA) external IsAdminCaller {
    require(iPausedB);
    pTokenC.NewSaleContract(vNewSaleContractA); // which creates a new Sale list entry and transfers the old Sale picos to the new entry
    pListC.ChangeOwner1(vNewSaleContractA);
  }

  // If a New Token contract is deployed
  // ***********************************
  // Hub.NewTokenContract()
  // ----------------------
  // To be called manually. Token needs to be initialised after this.
  function NewTokenContract(address vNewTokenContractA) external IsAdminCaller {
    pTokenC.NewTokenContract(vNewTokenContractA); // Changes Owner2 of the List contract to the new Token contract
    pTokenC = I_TokenHub(vNewTokenContractA);
  }
*/

  // Functions for Calling List IsHubContractCaller Functions
  // ================================================
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
  // Hub.Proxy()
  // -----------
  function Proxy(address accountA) external view IsWebOrAdminCaller returns (address) {
    return pListC.Proxy(accountA);
  }

  // Hub.CreateListEntry()
  // ---------------------
  // Create a new list entry, and add it into the doubly linked list.
  // List.CreateListEntry() sets the LE_REGISTERED_B bit so there is no need to include that in vBits
  function CreateListEntry(address accountA, uint32 vBits, uint32 vDbId) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.CreateListEntry(accountA, vBits, vDbId);
  }

  // Hub.Downgrade()
  // ---------------
  // Downgrades an entry from whitelisted
  function Downgrade(address accountA, uint32 vDownT) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.Downgrade(accountA, vDownT);
  }
  // Hub.SetBonus()
  // --------------
  // Sets bonusCentiPc Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
  function SetBonus(address accountA, uint32 vBonusPc) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.SetBonus(accountA, vBonusPc);
  }
  // Hub.SetProxy()
  // --------------
  // Sets the proxy address of entry accountA to vProxyA plus updates bits and pNumProxies
  // vProxyA = 0x0 to unset or remove a proxy
  function SetProxy(address accountA, address vProxyA) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.SetProxy(accountA, vProxyA);
  }

  // Hub.SetTransfersOkByDefault()
  // -----------------------------
  // To set/unset List.pTransfersOkB
  function SetTransfersOkByDefault(bool B) external IsAdminCaller returns (bool) {
    return pListC.SetTransfersOkByDefault(B);
  }

  // Hub.SetTransferOk()
  // -------------------
  // To set LE_FROM_TRANSFER_OK_B bit of entry accountA on if B is true, or unset the bit if B is false
  function SetTransferOk(address accountA, bool B) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.SetTransferOk(accountA, B);
  }

  // Hub Fallback function
  // =====================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Hub contract other than via the defined methods with their testing for valid access
  }

} // End Hub contract

