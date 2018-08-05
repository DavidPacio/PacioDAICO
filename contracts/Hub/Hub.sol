/* \Hub\Hub.sol 2018.07.13 started

The hub or management contract for the Pacio DAICO

Owned by 0 Deployer, 1 OpMan, 2 Admin, 3 Sale, 4 VoteTap, 5 VoteEnd, 6 Web

Calls
OpMan; Sale; Token; List; Escrow; Grey;
VoteTap; VoteEnd; Mvp djh??

djh??
• The STATE_OPEN_B state bit gets set when the first Sale.Buy() transaction >= Sale.pStartT comes through, or here on a restart after a close.

• fns for replacing contracts - all of them
• Provide a way for grey -> escrow on whitelisting before sale opens and -> PIOs issued
• add manual account creation
• Hub.Destroy() ?
• Add Ids for Issues and Deposits as for Refunds and Burns
  • Escrow
  . Grey
  . Token
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
import "../Escrow/I_EscrowHub.sol";
import "../Escrow/I_GreyHub.sol";
//import "../Vote/I_VoteTap.sol";
//import "../Vote/I_VoteEnd.sol";
//import "../Mvp/I_Mvp.sol";

contract Hub is OwnedHub, Math {
  string  public name = "Pacio DAICO Hub"; // contract name
  uint32      private pState;    // DAICO state using the STATE_ bits. Passed through to Sale, Token, Escrow, and Grey on change
  I_OpMan     private pOpManC;   // the OpMan contract
  I_Sale      private pSaleC;    // the Sale contract
  I_TokenHub  private pTokenC;   // the Token contract
  I_ListHub   private pListC;    // the List contract
  I_EscrowHub private pEscrowC;  // the Escrow contract
  I_GreyHub   private pGreyC;    // the Grey escrow contract
  bool        private pRefundInProgressB; // to prevent re-entrant refund calls
  uint256     private pRefundId; // Refund Id

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
  event InitialiseV(address OpManContract, address SaleContract, address TokenContract, address ListContractt, address EscrowContract);
  event StateChangeV(uint32 PrevState, uint32 NewState);
  event StartSaleV(uint32 StartTime, uint32 EndTime);
  event SoftCapReachedV();
  event EndSaleV();
  event RefundV(uint256 indexed RefundId, address indexed Account, uint256 RefundWei, uint32 RefundBit);
  event GreyRefundingCompleteV();
  event EscrowRefundingCompleteV();

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
    pOpManC  = I_OpMan(iOwnersYA[OP_MAN_OWNER_X]);
    pSaleC   =  I_Sale(iOwnersYA[SALE_OWNER_X]);
    pTokenC  =  I_TokenHub(pOpManC.ContractXA(TOKEN_CONTRACT_X));
    pListC   =   I_ListHub(pOpManC.ContractXA(LIST_CONTRACT_X));
    pEscrowC = I_EscrowHub(pOpManC.ContractXA(ESCROW_CONTRACT_X));
    pGreyC   =   I_GreyHub(pOpManC.ContractXA(GREY_CONTRACT_X));
    emit InitialiseV(pOpManC, pSaleC, pTokenC, pListC, pEscrowC);
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

  // Hub.StartSale()
  // ---------------
  // To be called manually by Admin to start the sale going. Can be called well before start time which allows registration, Grey escrow deposits, and white listing but wo PIOs being issued until tthat is done after the sale opens
  // Can also be called to adjust settings.
  // The STATE_OPEN_B state bit gets set when the first Sale.Buy() transaction >= Sale.pStartT comes through, or here on a restart after a close.
  // Initialise(), Sale.SetCapsAndTranchesMO(), Sale.SetUsdEtherPrice(), Sale.EndInitialise(), Escrow.SetPclAccountMO(), Escrow.EndInitialise() and PresaleIssue() multiple times must have been called before this.
  function StartSale(uint32 vStartT, uint32 vEndT) external IsAdminCaller {
    // Could Have previous state settings = a restart
    // Unset everything except for STATE_S_CAP_REACHED_B.  Should not allow 2 soft cap state changes.
    pSetState((pState & STATE_S_CAP_REACHED_B > 0 ? STATE_S_CAP_REACHED_B : 0) + (uint32(now) >= vStartT ? STATE_OPEN_B : STATE_PRIOR_TO_OPEN_B));
    pSaleC.StartSale(vStartT, vEndT);
    emit StartSaleV(vStartT, vEndT);
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
      pEscrowC.StateChange(vState);
      pGreyC.StateChange(vState);
    //pVoteTapC.StateChange(vState); /- These can get state from Hub
    //pVoteEndC.StateChange(vState); |
      emit StateChangeV(pState, vState);
      pState = vState;
    }
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

  // Hub.EndSaleMO()
  // ---------------
  // Is called from Sale.pEndSale() to end the sale on hard cap being reached vBit == STATE_CLOSED_H_CAP_B, or time up vBit == STATE_CLOSED_TIME_UP_B
  // Can be called manually by Admin to end the sale prematurely as a managed op if necessary. In that case vBit is not used and the STATE_CLOSED_MANUAL_B state bit is used
  function EndSaleMO(uint32 vBit) external {
    if (iIsSaleContractCallerB())
      pSetState(vBit);
    else if (iIsAdminCallerB() && pOpManC.IsManOpApproved(HUB_END_SALE_MO_X))
      pSetState(STATE_CLOSED_MANUAL_B);
    else
      revert();
    emit EndSaleV();
  }

  // Hub.Terminate()
  // ---------------
  // Called when a VoteEnd vote has voted to end the project, Escrow funds to be refunded in proportion to Picos held
  // After this only refunds and view functions should work. No transfers. No Deposits.
  function Terminate() external IsVoteEndContractCaller {
  //pEscrowC.Terminate(pTokenC.PicosIssued()); No. Done via StateChange() call
    pOpManC.PauseContract(SALE_CONTRACT_X); // IsHubContractCallerOrConfirmedSigner
    pOpManC.PauseContract(TOKEN_CONTRACT_X);
    pOpManC.PauseContract(ESCROW_CONTRACT_X);
    pOpManC.PauseContract(GREY_CONTRACT_X);
    pListC.SetTransfersOkByDefault(false); // shouldn't matter with Token paused but set everything off...
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
  // Calls: List.EntryType()                - for type info
  //        Escrow/Grey.RefundInfo()        - for refund info: amount and bit for one of the above cases
  //        Token.Refund() -> List.Refund() - to update Token and List data, in the reverse of an Issue
  //        Escrow/Grey.Refund()            - to do the actual refund
  function pRefund(address toA, bool vOnceOffB) private returns (bool) {
    require(!pRefundInProgressB, 'Refund already in Progress'); // Prevent re-entrant calls
    pRefundInProgressB = true;
    uint256 refundPicos;
    uint256 refundWei;
    uint32  refundBit;
    uint8   typeN = pListC.EntryType(toA);
    pRefundId++;
    if (typeN == LE_TYPE_GREY) {
      // Grey Refund
      if (vOnceOffB)
        refundBit = LE_REFUND_GREY_ONCE_OFF_B;
      else if (pState & STATE_S_CAP_MISS_REFUND_B > 0)
        refundBit = LE_REFUND_GREY_S_CAP_MISS_B;
      else if (pState & STATE_CLOSED_COMBO_B > 0)
        refundBit = LE_REFUND_GREY_SALE_CLOSE_B;
      if (refundBit > 0)
        refundWei = Min(pListC.WeiContributed(toA), pGreyC.EscrowWei());
    }else if (typeN >= LE_TYPE_WHITE || typeN == LE_TYPE_PRESALE) {
      // Escrow Refund
      (refundPicos, refundWei, refundBit) = pEscrowC.RefundInfo(pRefundId, toA);
      if (vOnceOffB)
        refundBit = LE_REFUND_ESCROW_ONCE_OFF_B;
    }
    require(refundWei > 0, 'No refund available');
    pTokenC.Refund(pRefundId, toA, refundWei, refundBit); // IsHubContractCaller IsActive -> List.refund()
    if (typeN == LE_TYPE_GREY) {
      if (!pGreyC.Refund(pRefundId, toA, refundWei, refundBit)) {
        if (pGreyC.EscrowWei() == 0) {
          pSetState(pState |= STATE_GREY_EMPTY_B);
          emit GreyRefundingCompleteV();
        }
      }
    }else{
      if (!pEscrowC.Refund(pRefundId, toA, refundPicos, refundWei, refundBit)) {
        if (pEscrowC.EscrowWei() == 0) {
          pSetState(pState |= STATE_ESCROW_EMPTY_B);
          emit EscrowRefundingCompleteV();
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
  // - retA   address and type of the list entry found, 0x0 if none
  // - typeN  type of the entry { None, Contract, Grey, White, Presale, Member, Refunded, White, Downgraded }
  // Note: Browsing for a particular type of entry is not implemented as that would involve looping -> gas problems.
  //       The calling app will need to do the looping if necessary, thus the return of typeN.
  function Browse(address currentA, uint8 vActionN) external view IsWebOrAdminCaller returns (address retA, uint8 typeN) {
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
  // Create a new list entry, and add it into the doubly linked list
  function CreateListEntry(address vEntryA, uint32 vBits, uint32 vDbId) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.CreateListEntry(vEntryA, vBits, vDbId);
  }

  // Hub.Whitelist()
  // ---------------
  // Whitelist an entry
  function Whitelist(address vEntryA, uint32 vWhiteT) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.Whitelist(vEntryA, vWhiteT);
  }
  // Hub.Downgrade()
  // ---------------
  // Downgrades an entry from whitelisted
  function Downgrade(address vEntryA, uint32 vDownT) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.Downgrade(vEntryA, vDownT);
  }
  // Hub.SetBonus()
  // --------------
  // Sets bonusCentiPc Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
  function SetBonus(address vEntryA, uint32 vBonusPc) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.SetBonus(vEntryA, vBonusPc);
  }
  // Hub.SetProxy()
  // --------------
  // Sets the proxy address of entry vEntryA to vProxyA plus updates bits and pNumProxies
  // vProxyA = 0x0 to unset or remove a proxy
  function SetProxy(address vEntryA, address vProxyA) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.SetProxy(vEntryA, vProxyA);
  }

  // Hub.SetTransfersOkByDefault()
  // -----------------------------
  // To set/unset List.pTransfersOkB
  function SetTransfersOkByDefault(bool B) external IsAdminCaller returns (bool) {
    return pListC.SetTransfersOkByDefault(B);
  }

  // Hub.SetTransferOk()
  // -------------------
  // To set LE_TRANSFER_OK_B bit of entry vEntryA on if B is true, or unset the bit if B is false
  function SetTransferOk(address vEntryA, bool B) external IsWebOrAdminCaller IsActive returns (bool) {
    return pListC.SetTransferOk(vEntryA, B);
  }

  // Others
  // ======


  // Hub Fallback function
  // =====================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Hub contract other than via the defined methods with their testing for valid access
  }

} // End Hub contract

