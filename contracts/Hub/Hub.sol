/* \Hub\Hub.sol 2018.07.13 started

The hub or management contract for the Pacio DAICO

Owned by
0 Deployer
1 OpMan
2 Admin
3 Sale

Calls
OpMan; Sale; Token; List; Escrow; Grey;
VoteTap; VoteEnd; Mvp djh??

djh??
• review all the IsOwner calls
• pragma experimental "v0.5.0";
• fn for money to grey list entry
• fns for new Escrow, Grey, VoteTap, VoteEnd
• review all manual fns for God issues a la Binod
• Pause/Resume Token
• fn to call Escrow.SetPclAccount()
• Check manual ending of a sale

Initialisation/Setup Functions
==============================

View Methods
============

State changing external methods
===============================

Pause/Resume
============
Hub Fallback function
=====================
Sending Ether is not allowed

Events
======

*/

pragma solidity ^0.4.24;
pragma experimental "v0.5.0";

import "../lib/OwnedHub.sol";
import "../lib/Math.sol";
import "../Sale/I_Sale.sol";
import "../Token/I_TokenHub.sol";
import "../List/I_ListHub.sol";
import "../Escrow/I_EscrowHub.sol";
import "../Escrow/I_GreyHub.sol";
//import "../Vote/I_VoteTap.sol";
//import "../Vote/I_VoteEnd.sol";
//import "../Mvp/I_Mvp.sol";

contract Hub is Owned, Math {
  string  public name = "Pacio DAICO Hub"; // contract name
  I_Sale      private pSaleC;    // the Sale contract
  I_TokenHub  private pTokenC;   // the Token contract
  I_ListHub   private pListC;    // the List contract
  I_EscrowHub private pEscrowC;  // the Escrow contract
  I_GreyHub   private pGreyC;    // the Grey escrow contract

  // No Constructor
  // ==============

  // Events
  // ======
  event InitialiseV(address SaleContract, address TokenContract, address ListContract, address EscrowContract, address GreyContract);
  event InitCapsV(uint256 PicosCap1, uint256 PicosCap2, uint256 PicosCap3, uint256 UsdSoftCap, uint256 UsdHardCap);
  event InitTranchesV(uint256 MinWei1, uint256 MinWei2, uint256 MinWei3, uint256 PioePriceCCents1, uint256 PioePriceCCents2, uint256 vPriceCCentsT3);
  event InitEscrowV(uint32 TapRateEtherPm, uint32 SoftCapTapPc);
  event NewListContractV(address ListContract);
  event SetUsdEtherPriceV(uint256 UsdEtherPrice, uint256 PicosPerEth1, uint256 PicosPerEth2, uint256 PicosPerEth3);
  event PresaleIssueV(address indexed toA, uint256 vPicos, uint256 vWei, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs);
  event StartSaleV(uint32 StartTime, uint32 EndTime);
  event SoftCapReachedV();
  event EndSaleV();

  // Initialisation/Setup Methods
  // ============================

  // Owned by 0 Deployer, 1 OpMan, 2 Admin, 3 Sale
  // Owners must first be set by deploy script calls:
  //   Hub.ChangeOwnerMO(2, PCL hw wallet address as Admin)
  //   Hub.ChangeOwnerMO(3, Sale address)
  //   Hub.ChangeOwnerMO(1, OpMan address) <=== Must come after 2, 3 have been set

  // Hub.Initialise()
  // ----------------
  // To be called by the deploy script to set the contract address variables.
  // Can only be called once.
  function Initialise() external IsDeployerCaller {
    require(iInitialisingB); // To enforce being called only once
    I_OpMan opManC = I_OpMan(iOwnersYA[OP_MAN_OWNER_X]);
    pSaleC   = I_Sale(opManC.ContractXA(SALE_X));
    pTokenC  = I_TokenHub(opManC.ContractXA(TOKEN_X));
    pListC   = I_ListHub(opManC.ContractXA(LIST_X));
    pEscrowC = I_EscrowHub(opManC.ContractXA(ESCROW_X));
    pGreyC   = I_GreyHub(opManC.ContractXA(GREY_X));
    emit InitialiseV(pSaleC, pTokenC, pListC, pEscrowC, pGreyC);
    iPausedB       =        // make active
    iInitialisingB = false;
  }

  // // Hub.Initialise()
  // // ----------------
  // // To be called manually to continue initialisation. Ran out of stack doing it in one fn.
  // function Initialise(uint256 vPicosCapT1, uint256 vPicosCapT2, uint256 vPicosCapT3, uint256 vUsdSoftCap, uint256 vUsdHardCap,
  //                     uint256 vMinWeiT1, uint256 vMinWeiT2, uint256 vMinWeiT3, uint256 vPriceCCentsT1, uint256 vPriceCCentsT2, uint256 vPriceCCentsT3) external IsAdminCaller {
  //   pSaleC.Initialise(vPicosCapT1, vPicosCapT2, vPicosCapT3, vUsdSoftCap, vUsdHardCap, vMinWeiT1, vMinWeiT2, vMinWeiT3, vPriceCCentsT1, vPriceCCentsT2, vPriceCCentsT3);
  //    pTokenC.Initialise(pListC);
  //     pListC.Initialise();
  //   emit InitCapsV(vPicosCapT1, vPicosCapT2, vPicosCapT3, vUsdSoftCap, vUsdHardCap);
  //   emit InitTranchesV(vMinWeiT1, vMinWeiT2, vMinWeiT3, vPriceCCentsT1, vPriceCCentsT2, vPriceCCentsT3);
  // }
  // // Hub.InitEscrow()
  // // ----------------
  // // To be called manually to continue initialisation. Ran out of stack doing it in one fn.
  // function InitEscrow(uint32 vTapRateEtherPm, uint32 vSoftCapTapPc) external IsAdminCaller {
  //   pEscrowC.Initialise(vTapRateEtherPm, vSoftCapTapPc);
  //   pGreyC.Initialise();
  //   // No Initialise() for VoteTap, VoteEnd, Mvp
  //   emit InitEscrowV(vTapRateEtherPm, vSoftCapTapPc);
  // }

  // Hub.SetUsdEtherPrice()
  // ----------------------
  // Fn to be called on significant Ether price movement to set the price
  function SetUsdEtherPrice(uint256 vUsdEtherPrice) external IsAdminCaller {
    pSaleC.SetUsdEtherPrice(vUsdEtherPrice); // 500
  }
  // Hub.PresaleIssue()
  // ------------------
  // To be called repeatedly for all Seed Presale and Private Placement contributors (aggregated) to initialise the DAICO for tokens issued in the Seed Presale and the Private Placement`
  // no pPicosCap check
  // Expects list account not to exist - multiple Seed Presale and Private Placement contributions to same account should be aggregated for calling this fn
  function PresaleIssue(address toA, uint256 vPicos, uint256 vWei, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external IsAdminCaller {
    require(pListC.CreatePresaleEntry(toA, vDbId, vAddedT, vNumContribs));
    pSaleC.PresaleIssue(toA, vPicos, vWei, vDbId, vAddedT, vNumContribs); // reverts if sale has started
  }
  // Hub.StartSale()
  // ---------------
  // To be called manually to start the sale going
  // Can also be called to adjust settings.
  // Initialise(), SetUsdEtherPrice(), and PresaleIssue() multiple times must have been called before this.
  function StartSale(uint32 vStartT, uint32 vEndT) external IsAdminCaller {
    pSaleC.StartSale(vStartT, vEndT);
    pTokenC.StartSale();
    pListC.StartSale();
    pEscrowC.StartSale();
    // No StartSale() for Grey, VoteTap, VoteEnd, Mvp
    emit StartSaleV(vStartT, vEndT);
  }
  // Hub.SetUsdHardCapB()
  // --------------------
  function SetUsdHardCapB(bool B) external IsAdminCaller {
    pSaleC.SetUsdHardCapB(B);
  }

  // View Methods
  // ============
  // Hub.IsSaleOpen()
  function IsSaleOpen() external view returns (bool) {
    return pSaleC.IsSaleOpen();
  }
  // Hub.IsTransferAllowedByDefault()
  function IsTransferAllowedByDefault() external view returns (bool) {
    return pListC.IsTransferAllowedByDefault();
  }
  // The Contracts
  // -------------
  // Hub.TheSaleContract()
  function TheSaleContract() external view returns (address) {
    return pSaleC;
  }
  // Hub.TheTokenContract()
  function TheTokenContract() external view returns (address) {
    return pTokenC;
  }
  // Hub.TheListContract()
  function TheListContract() external view returns (address) {
    return pListC;
  }
  // Hub.TheEscrowContract()
  function TheEscrowContract() external view returns (address) {
    return pEscrowC;
  }
  // Hub.TheGreyListEscrowContract()
  function TheGreyListEscrowContract() external view returns (address) {
    return pGreyC;
  }

  // State changing external methods
  // ===============================
  // Hub.SoftCapReached()
  // --------------------
  // Is called from Sale.SoftCapReachedLocal() on soft cap being reached
  // Can be called here by Admin if necessary.
  // djh?? Should the Admin op here be an MO one?
  function SoftCapReached() external IsSaleOrAdminCaller { // Sale or Admin
      pSaleC.SoftCapReached();
   //pTokenC.SoftCapReached();
    pEscrowC.SoftCapReached();
      pListC.SoftCapReached();
    // No SoftCapReached() for Grey, VoteTap, VoteEnd, Mvp
    emit SoftCapReachedV();
  }
  // Hub.EndSale()
  // -------------
  // Is called from Sale.EndSaleLocal() to end the sale on hard cap being reached, or time up
  // Can be called here to end the sale prematurely if necessary.
  // djh?? Should the Admin op here be an MO one?
  function EndSale() external IsSaleOrAdminCaller {
    pSaleC.EndSale();
    pTokenC.EndSale();
    pEscrowC.EndSale();
    // No EndSale() for List, Grey, VoteTap, VoteEnd, Mvp
    emit EndSaleV();
  }

  // Functions to be called Manually
  // ===============================
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
  // ***************************************
  // Hub.NewSaleContract()
  // ---------------------
  // To be called manually via the old Sale to change to the new Sale.
  // Expects the old Sale contract to have been paused
  // Calling NewSaleContract() will stop calls from the old Sale contract to the Token contract IsSaleCaller functions from working
  function NewSaleContract(address vNewSaleContractA) external IsAdminCaller {
    require(iPausedB);
    pTokenC.NewSaleContract(vNewSaleContractA); // which creates a new Sale list entry and transfers the old Sale picos to the new entry
    pListC.ChangeOwner1(vNewSaleContractA);
  }

  // If a New Token contract is deployed
  // ***************************************
  // Hub.NewTokenContract()
  // ----------------------
  // To be called manually. Token needs to be initialised after this.
  function NewTokenContract(address vNewTokenContractA) external IsAdminCaller {
    pTokenC.NewTokenContract(vNewTokenContractA); // Changes Owner2 of the List contract to the new Token contract
    pTokenC = I_TokenHub(vNewTokenContractA);
  }
*/
  // Pause/Resume
  // ============
  // This contract (Hub) can be paused/resumed via SetPause() inherited from Owned

  // Hub.SetTokenPause()
  // ------------------------------
  // To be called manually to pause/resume Token
  function SetTokenPause(bool B) external IsAdminCaller {
    pTokenC.SetPause(B);
  }

  // Functions for Calling List IsOwner1 Functions
  // =============================================
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
  function Browse(address currentA, uint8 vActionN) external view IsAdminCaller returns (address retA, uint8 typeN) {
    return pListC.Browse(currentA, vActionN);
  }
  // Hub.NextEntry()
  // ---------------
  function NextEntry(address accountA) external view IsAdminCaller returns (address) {
    return pListC.NextEntry(accountA);
  }
  // Hub.PrevEntry()
  // ---------------
  function PrevEntry(address accountA) external view IsAdminCaller returns (address) {
    return pListC.PrevEntry(accountA);
  }
  // Hub.Proxy()
  // -----------
  function Proxy(address accountA) external view IsAdminCaller returns (address) {
    return pListC.Proxy(accountA);
  }

  // Hub.CreateEntry()
  // -----------------
  // Create a new list entry, and add it into the doubly linked list
  function CreateEntry(address vEntryA, uint32 vBits, uint32 vDbId) external IsAdminCaller IsActive returns (bool) {
    return pListC.CreateEntry(vEntryA, vBits, vDbId);
  }


  // Hub.Whitelist()
  // ---------------
  // Whitelist an entry
  function Whitelist(address vEntryA, uint32 vWhiteT) external IsAdminCaller IsActive returns (bool) {
    return pListC.Whitelist(vEntryA, vWhiteT);
  }
  // Hub.Downgrade()
  // ---------------
  // Downgrades an entry from whitelisted
  function Downgrade(address vEntryA, uint32 vDownT) external IsAdminCaller IsActive returns (bool) {
    return pListC.Downgrade(vEntryA, vDownT);
  }
  // Hub.SetBonus()
  // --------------
  // Sets bonusCentiPc Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
  function SetBonus(address vEntryA, uint32 vBonusPc) external IsAdminCaller IsActive returns (bool) {
    return pListC.SetBonus(vEntryA, vBonusPc);
  }
  // Hub.SetProxy()
  // --------------
  // Sets the proxy address of entry vEntryA to vProxyA plus updates bits and pNumProxies
  // vProxyA = 0x0 to unset or remove a proxy
  function SetProxy(address vEntryA, address vProxyA) external IsAdminCaller IsActive returns (bool) {
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
  // To set TRANSFER_OK bit of entry vEntryA on if B is true, or unset the bit if B is false
  function SetTransferOk(address vEntryA, bool B) external IsAdminCaller IsActive returns (bool) {
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

