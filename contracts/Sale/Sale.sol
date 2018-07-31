/* \Sale\Sale.sol 2018.06.06 started

The sale contract for the Pacio DAICO

Owners:
0 Deployer
1 OpMan
2 Hub
3 Admin

Calls: OpMan; Hub -> Token,List,Escrow,Grey,VoteTap,VoteEnd,Mvp; List; Token -> List; Escrow; Grey

View Methods
============
Sale.Name() external view returns (string)
Sale.StartTime() external view returns (uint32)
Sale.UsdSoftCap) external view returns (uint256)
Sale.UsdHardCap) external view returns (uint256)
Sale.PicosCapTranche1() external view returns (uint256)
Sale.PicosCapTranche2() external view returns (uint256)
Sale.PicosCapTranche3() external view returns (uint256)
Sale.MinWeiTranche1() external view returns (uint256)
Sale.MinWeiTranche2() external view returns (uint256)
Sale.MinWeiTranche3() external view returns (uint256)
Sale.PioePriceCentiCentsTranche1() external view returns (uint256)
Sale.PioePriceCentiCentsTranche2() external view returns (uint256)
Sale.PioePriceCentiCentsTranche3() external view returns (uint256)
Sale.PicosPerEtherTranch1() external view returns (uint256)
Sale.PicosPerEtherTranch2() external view returns (uint256)
Sale.PicosPerEtherTranch3() external view returns (uint256)
Sale.PicosSoldPresale()  external view returns (uint256)
Sale.PicosSoldTranche1() external view returns (uint256)
Sale.PicosSoldTranche2() external view returns (uint256)
Sale.PicosSoldTranche3() external view returns (uint256)
Sale.WeiRaised() external view returns (uint256)
Sale.WeiInEscrow() external view returns (uint256)
Sale.WeiInGreyEscrow() external view returns (uint256)
Sale.UsdEtherPrice() external view returns (uint256)
Sale.HardCapByUsd() external view returns (bool)
Sale.IsSoftCapReached() external view returns (bool)
Sale.IsHardCapReached() external view returns (bool)
Sale.IsSaleOpen() external view returns (bool)

Initialisation/Setup Functions
==============================

State changing external methods
===============================
Sale.Buy() payable public IsActive
Sale.HardCapReached() private

Pause/Resume
============
OpMan.Pause(SALE_X) IsConfirmedSigner
OpMan.ResumeContractMO(SALE_X) IsConfirmedSigner which is a managed op

Sale Fallback function
======================
Sending Ether is allowed - calls Buy()

Events
======

*/

pragma solidity ^0.4.24;
//pragma experimental "v0.5.0";

import "../lib/OwnedSale.sol";
import "../lib/Math.sol";
import "../Hub/I_Hub.sol";
import "../List/I_ListSale.sol";
import "../Token/I_TokenSale.sol";
import "../Escrow/I_EscrowSale.sol";
import "../Escrow/I_GreySale.sol";

// Tranches
// 1. 32 million PIOEs for >=  50 ETH             at 7.50 Cents
// 2. 32 million PIOEs for >=   5 ETH && < 50 ETH at 8.75 Cts
// 3. 350 million      for >= 0.1 ETH && < 5 ETH  at 10 Cents

contract Sale is OwnedSale, Math {
  string  public  name = "Pacio DAICO Sale";
  uint256 private pStartT;        // i Sale start time
  uint256 private pEndT;          // i Sale end time
  uint256 private pPicosCapT1;    // i Hard cap for the sale tranche 1  32 million PIOEs =  32,000,000, 000,000,000,000 picos
  uint256 private pPicosCapT2;    // i Hard cap for the sale tranche 2  32 million PIOEs =  32,000,000, 000,000,000,000 picos
  uint256 private pPicosCapT3;    // i Hard cap for the sale tranche 3 350 million PIOEs = 350,000,000, 000,000,000,000 picos
  uint256 private pUsdSoftCap;    // i USD soft cap $8,000,000
  uint256 private pUsdHardCap;    // i USD soft cap $42,300,000
  uint256 private pMinWeiT1;      // i Minimum wei contribution for tranche 1  50 Ether = 50,000,000,000,000,000,000 wei
  uint256 private pMinWeiT2;      // i Minimum wei contribution for tranche 2   5 Ether =  5,000,000,000,000,000,000 wei
  uint256 private pMinWeiT3;      // i Minimum wei contribution for tranche 3 0.1 Ether =    100,000,000,000,000,000 wei
  uint256 private pPriceCCentsT1; // i PIOE price for tranche 1 in centi-cents i.e.  750 for 7.50
  uint256 private pPriceCCentsT2; // i PIOE price for tranche 2 in centi-cents i.e.  875 for 8.75
  uint256 private pPriceCCentsT3; // i PIOE price for tranche 3 in centi-cents i.e. 1000 for 10.00
  uint256 private pPicosPerEthT1; // c Picos per Ether for tranche 1 = pUsdEtherPrice * 10**16 / pPriceCCentsT1   16 = 12 (picos per Pioe) + 4 from pPriceCCentsT1 -> $s = 6,666,666,666,666,666
  uint256 private pPicosPerEthT2; // c Picos per Ether for tranche 2
  uint256 private pPicosPerEthT3; // c Picos per Ether for tranche 3  // 5,000,000,000,000,000 for ETH = $500 and target PIOE price = $0.10
  uint256 private pPicosPresale;  // s Picos sold in seed presale and private placement
  uint256 private pPicosSoldT1;   // s Picos sold in tranche 1 /- sum should == Token.pPicosIssued
  uint256 private pPicosSoldT2;   // s Picos sold in tranche 2 |
  uint256 private pPicosSoldT3;   // s Picos sold in tranche 3 |
  uint256 private pWeiRaised;     // s cumulative wei raised  USD Raised = pWeiRaised * pUsdEtherPrice / 10**18
  uint256 private pUsdEtherPrice; // u Current US$ Ether price used for calculating pPicosPerEth? and USD calcs
  bool    private pUsdHardCapB;   // t True: reaching hard cap is based on USD @ current pUsdEtherPrice vs pUsdHardCap; False: reaching hard cap is based on picos sold vs pico caps for the 3 tranches
  bool    private pSoftCapB;      // f Set to true when softcap is reached based on USD @ current pUsdEtherPrice vs pUsdSoftCap
  bool    private pHardCapB;      // f Set to true when hardcap is reached by either method
  bool    private pSaleOpenB;     // f Set to true when the sale is started and bacl to false when the sate is closed
                                  // |- i  initialised via setup fn calls
                                  // |- c calculated when pUsdEtherPrice is set/updated
                                  // |- s summed
                                  // |- u updated during running
                                  // |- t initialised to true but can be changed manually
                                  // |- f initialised to false
  I_ListSale   private pListC;   // the List contract        -  read only use so List does not need to have Sale as an owner
  I_TokenSale  private pTokenC;  // the Token contract       /- make state changing calls so need to have Sale as an owner
  I_EscrowSale private pEscrowC; // the Escrow contract      |
  I_GreySale   private pGreyC;   // the Grey escrow contract |
                                 // Don't need I_Hub pHubC as iOwnersYA[HUB_OWNER_X] is the Hub contract

  // No constructor
  // ==============
  // Just the Owned constructor applies to set iOwnerA. iPausedB in Pausable is not set so the contract starts active but owned.

  // Events
  // ======
  event InitialiseV(address TokenContract, address ListContract, address EscrowContract, address GreyContract);
  event SetCapsAndTranchesV(uint256 PicosCap1, uint256 PicosCap2, uint256 PicosCap3, uint256 UsdSoftCap, uint256 UsdHardCap,
                            uint256 MinWei1, uint256 MinWei2, uint256 MinWei3, uint256 PioePriceCCents1, uint256 PioePriceCCents2, uint256 vPriceCCentsT3);
  event SetUsdHardCapBV(bool HardCapMethodB);
  event SetUsdEtherPriceV(uint256 UsdEtherPrice, uint256 PicosPerEth1, uint256 PicosPerEth2, uint256 PicosPerEth3);
  event PresaleIssueV(address indexed toA, uint256 vPicos, uint256 vWei, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs);
  event StartSaleV(uint32 StartTime, uint32 EndTime);
  event GreyDepositV(address indexed Contributor, uint256 Wei);
  event SaleV(address indexed Contributor, uint256 Picos, uint256 SaleWei, uint32 Tranche, uint256 UsdEtherPrice, uint256 PicosPerEth, uint32 bonusCentiPc);
  event SoftCapReachedV(uint256 PicosSoldT1, uint256 PicosSoldT2, uint256 PicosSoldT3, uint256 WeiRaised, uint256 UsdEtherPrice);
  event HardCapReachedV(uint256 PicosSoldT1, uint256 PicosSoldT2, uint256 PicosSoldT3, uint256 WeiRaised, uint256 UsdEtherPrice, bool UsdHardCapB);
  event TimeUpV(uint256 PicosSoldT1, uint256 PicosSoldT2, uint256 PicosSoldT3, uint256 WeiRaised);
  event EndSaleV();

  // Initialisation/Setup Methods
  // ============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Admin
  // Owners must first be set by deploy script calls:
  //   Sale.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
  //   Sale.ChangeOwnerMO(HUB_OWNER_X, Hub address)

  // Sale.Initialise()
  // -----------------
  // To be called by the deploy script to set the contract address variables.
  function Initialise() external IsInitialising {
    I_OpMan opManC = I_OpMan(iOwnersYA[OP_MAN_OWNER_X]);
    pTokenC  = I_TokenSale(opManC.ContractXA(TOKEN_X));
    pListC   = I_ListSale(opManC.ContractXA(LIST_X));
    pEscrowC = I_EscrowSale(opManC.ContractXA(ESCROW_X));
    pGreyC   = I_GreySale(opManC.ContractXA(GREY_X));
    emit InitialiseV(pTokenC, pListC, pEscrowC, pGreyC);
  //iInitialisingB = false; No. Leave in initialising state
  }

  // Sale.SetCapsAndTranchesMO()
  // ---------------------------
  // Called by the deploy script when initialising or manually as Admin as a managed op to set Sale caps and tranches.
  function SetCapsAndTranchesMO(uint256 vPicosCapT1, uint256 vPicosCapT2, uint256 vPicosCapT3, uint256 vUsdSoftCap, uint256 vUsdHardCap,
                                uint256 vMinWeiT1, uint256 vMinWeiT2, uint256 vMinWeiT3, uint256 vPriceCCentsT1, uint256 vPriceCCentsT2, uint256 vPriceCCentsT3) external {
    require(iIsInitialisingB() || (iIsAdminCallerB() && I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(SALE_SET_CAPS_TRANCHES_X)));
    // Caps stuff
    pPicosCapT1  = vPicosCapT1;  // Hard cap for the sale tranche 1  32 million PIOEs =  32,000,000, 000,000,000,000 picos
    pPicosCapT2  = vPicosCapT2;  // Hard cap for the sale tranche 2  32 million PIOEs =  32,000,000, 000,000,000,000 picos
    pPicosCapT3  = vPicosCapT3;  // Hard cap for the sale tranche 3 350 million PIOEs = 350,000,000, 000,000,000,000 picos
    pUsdSoftCap  = vUsdSoftCap; // USD soft cap $8,000,000
    pUsdHardCap  = vUsdHardCap; // USD soft cap $42,300,000
    pUsdHardCapB = true;        // True: reaching hard cap is based on USD @ current pUsdEtherPrice vs pUsdHardCap; False: reaching hard cap is based on picos sold vs pico caps for the 3 tranches
  //pSoftCapB    = false;       // Set to true when softcap is reached based on USD @ current pUsdEtherPrice vs pUsdSoftCap
  //pHardCapB    = false;       // Set to true when hardcap is reached by either method
    // Tranches
    pMinWeiT1      = vMinWeiT1;      // Minimum wei contribution for tranche 1  50 Ether = 50,000,000,000,000,000,000 wei
    pMinWeiT2      = vMinWeiT2;      // Minimum wei contribution for tranche 2   5 Ether =  5,000,000,000,000,000,000 wei
    pMinWeiT3      = vMinWeiT3;      // Minimum wei contribution for tranche 3 0.1 Ether =    100,000,000,000,000,000 wei
    pPriceCCentsT1 = vPriceCCentsT1; // PIOE price for tranche 1 in centi-cents i.e.  750 for 7.50
    pPriceCCentsT2 = vPriceCCentsT2; // PIOE price for tranche 2 in centi-cents i.e.  875 for 8.75
    pPriceCCentsT3 = vPriceCCentsT3; // PIOE price for tranche 3 in centi-cents i.e. 1000 for 10.00
    emit SetCapsAndTranchesV(vPicosCapT1, vPicosCapT2, vPicosCapT3, vUsdSoftCap, vUsdHardCap, vMinWeiT1, vMinWeiT2, vMinWeiT3, vPriceCCentsT1, vPriceCCentsT2, vPriceCCentsT3);
    emit SetUsdHardCapBV(true);
  }

  // Sale.SetUsdEtherPrice()
  // -----------------------
  // Called by the deploy script when initialising or manually by Admin on significant Ether price movement to set the price
  function SetUsdEtherPrice(uint256 vUsdEtherPrice) external {
    require(iIsInitialisingB() || iIsAdminCallerB());
    pUsdEtherPrice = vUsdEtherPrice; // 500
    pPicosPerEthT1 = pUsdEtherPrice * 10**16 / pPriceCCentsT1; // Picos per Ether for tranche 1 = pUsdEtherPrice * 10**16 / pPriceCCentsT1   16 = 12 (picos per Pioe) + 4 from pPriceCCentsT1 -> $s = 6,666,666,666,666,666
    pPicosPerEthT2 = pUsdEtherPrice * 10**16 / pPriceCCentsT2; // Picos per Ether for tranche 2
    pPicosPerEthT3 = pUsdEtherPrice * 10**16 / pPriceCCentsT3; // Picos per Ether for tranche 3  // 5,000,000,000,000,000 for ETH = $500 and target PIOE price = $0.10
    emit SetUsdEtherPriceV(pUsdEtherPrice, pPicosPerEthT1, pPicosPerEthT2, pPicosPerEthT3);
  }

  // Sale.EndInitialise()
  // --------------------
  // To be called by the deploy script to end initialising
  function EndInitialising() external IsInitialising {
    iPausedB       =        // make active
    iInitialisingB = false;
  }

  // Sale.PresaleIssue()
  // -------------------
  // To be called repeatedly from Hub.PresaleIssue() for all Seed Presale and Private Placement contributors (aggregated) to initialise the DAICO for tokens issued in the Seed Presale and the Private Placement`
  // no pPicosCap check
  // Expects list account not to exist - multiple Seed Presale and Private Placement contributions to same account should be aggregated for calling this fn
  function PresaleIssue(address toA, uint256 vPicos, uint256 vWei, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external IsHubCaller IsActive {
    require(pStartT == 0); // sale hasn't started yet
    pTokenC.Issue(toA, vPicos, vWei);
    pWeiRaised = safeAdd(pWeiRaised, vWei);
    pPicosPresale += vPicos; // ok wo overflow protection as pTokenC.Issue() would have thrown on overflow
    emit PresaleIssueV(toA, vPicos, vWei, vDbId, vAddedT, vNumContribs);
    // No event emit as List.Issue() does it
  }

  // Sale.StartSale()
  // ----------------
  // Called from Hub.StartSale() to start the sale going
  // Initialise(), SetCapsAndTranchesMO(), SetUsdEtherPrice(), and PresaleIssue() multiple times must have been called before this.
  function StartSale(uint32 vStartT, uint32 vEndT) external IsHubCaller {
    pStartT  = vStartT;
    pEndT    = vEndT;
    iPausedB = false;
    pSaleOpenB = true; // Set to false when the sale is closed by any method
    emit StartSaleV(vStartT, vEndT);
  }

  // Sale.SetUsdHardCapB()
  // ---------------------
  // Called by Admin to set/unset Sale.pUsdHardCapB:
  // True:  reaching hard cap is based on USD @ current pUsdEtherPrice vs pUsdHardCap
  // False: reaching hard cap is based on picos sold vs pico caps for the 3 tranches
  function SetUsdHardCapB(bool B) external IsAdminCaller {
    pUsdHardCapB = B;
    emit SetUsdHardCapBV(B);
  }

  // View Methods
  // ============
  // Sale.StartTime()
  function StartTime() external view returns (uint32) {
    return uint32(pStartT);
  }
  // Sale.EndTime()
  function EndTime() external view returns (uint32) {
    return uint32(pEndT);
  }
  // Sale.UsdSoftCap()
  function UsdSoftCap() external view returns (uint256) {
    return pUsdSoftCap;  // USD soft cap $8,000,000
  }
  // Sale.UsdHardCap()
  function UsdHardCap() external view returns (uint256) {
    return pUsdHardCap;  // USD hard cap $42,300,000
  }
  // Sale.PicosCapTranche1()
  function PicosCapTranche1() external view returns (uint256) {
    return pPicosCapT1;
  }
  // Sale.PicosCapTranche2()
  function PicosCapTranche2() external view returns (uint256) {
    return pPicosCapT2;
  }
  // Sale.PicosCapTranche3()
  function PicosCapTranche3() external view returns (uint256) {
    return pPicosCapT3;
  }
  // Sale.MinWeiTranche1()
  function MinWeiTranche1() external view returns (uint256) {
    return pMinWeiT1; // Minimum wei contribution for tranche 1  50 Ether = 50,000,000,000,000,000,000 wei
  }
  // Sale.MinWeiTranche2()
  function MinWeiTranche2() external view returns (uint256) {
    return pMinWeiT2; // Minimum wei contribution for tranche 2   5 Ether =  5,000,000,000,000,000,000 wei
  }
  // Sale.MinWeiTranche3()
  function MinWeiTranche3() external view returns (uint256) {
    return pMinWeiT3; // Minimum wei contribution for tranche 3 0.1 Ether =    100,000,000,000,000,000 wei
  }
  // Sale.PioePriceCentiCentsTranche1()
  function PioePriceCentiCentsTranche1() external view returns (uint256) {
    return pPriceCCentsT1; // PIOE price for tranche 1 in centi-cents i.e.  750 for 7.50
  }
  // Sale.PioePriceCentiCentsTranche2()
  function PioePriceCentiCentsTranche2() external view returns (uint256) {
    return pPriceCCentsT2; // PIOE price for tranche 2 in centi-cents i.e.  875 for 8.75
  }
  // Sale.PioePriceCentiCentsTranche3()
  function PioePriceCentiCentsTranche3() external view returns (uint256) {
    return pPriceCCentsT3; // PIOE price for tranche 3 in centi-cents i.e. 1000 for 10.00
  }
  // Sale.PicosPerEtherTranch1()
  function PicosPerEtherTranch1() external view returns (uint256) {
    return pPicosPerEthT1; // Picos per Ether for tranche 1
  }
  // Sale.PicosPerEtherTranch2()
  function PicosPerEtherTranch2() external view returns (uint256) {
    return pPicosPerEthT2; // Picos per Ether for tranche 2
  }
  // Sale.PicosPerEtherTranch3()
  function PicosPerEtherTranch3() external view returns (uint256) {
    return pPicosPerEthT3; // Picos per Ether for tranche 3
  }
  // Sale.PicosSoldPresale()
  function PicosSoldPresale() external view returns (uint256) {
    return pPicosPresale; // Picos sold in seed presale and private placement
  }
  // Sale.PicosSoldTranche1()
  function PicosSoldTranch1() external view returns (uint256) {
    return pPicosSoldT1; // Picos sold in tranche 1
  }
  // Sale.PicosSoldTranche2()
  function PicosSoldTranch2() external view returns (uint256) {
    return pPicosSoldT2; // Picos sold in tranche 2
  }
  // Sale.PicosSoldTranche3()
  function PicosSoldTranch3() external view returns (uint256) {
    return pPicosSoldT3; // Picos sold in tranche 3
  }
  // Sale.WeiRaised()
  function WeiRaised() external view returns (uint256) {
    return pWeiRaised;
  }
  // Sale.WeiInEscrow()
  function WeiInEscrow() external view returns (uint256) {
    return pEscrowC.WeiInEscrow();
  }
  // Sale.WeiInGreyEscrow()
  function WeiInGreyEscrow() external view returns (uint256) {
    return pGreyC.WeiInEscrow();
  }
  // Sale.UsdEtherPrice()
  function UsdEtherPrice() external view returns (uint256) {
    return pUsdEtherPrice; // Current US$ Ether price used for calculating pPicosPerEth? and USD calcs
  }
  // Sale.HardCapByUsd()
  function HardCapByUsd() external view returns (bool) {
    return pUsdHardCapB; // Hard cap check method
  }
  // Sale.IsSoftCapReached()
  function IsSoftCapReached() external view returns (bool) {
    return pSoftCapB;
  }
  // Sale.IsHardCapReached()
  function IsHardCapReached() external view returns (bool) {
    return pHardCapB;
  }
  // Sale.IsSaleOpen()
  function IsSaleOpen() external view returns (bool) {
    return pSaleOpenB;
  }

  // State changing external methods
  // ===============================

  // Sale.Buy()
  // ----------
  function Buy() payable public IsActive returns (bool) { // public because it is called from the fallback fn
    require(now >= pStartT, "Sale not open yet");  // sale is running (in conjunction with the IsActive test) tho this call could trigger soft cap, hard cap, over time
    require(msg.value >= pMinWeiT3, "Ether less than minimum"); // sent >= tranche 3 min ETH
    require(pSaleOpenB, "Sale has closed");
    (uint32 bonusCentiPc, uint8 typeN) = pListC.BonusPcAndType(msg.sender);
    if (typeN == ENTRY_GREY) {
      pGreyC.Deposit.value(msg.value)(msg.sender);
      emit GreyDepositV(msg.sender, msg.value);      return true;
    }
    require(typeN >= ENTRY_WHITE, "Not whitelisted"); // sender is White or Member = whitelisted and ok to buy
    // Which tranche?
    uint32  tranche = 3;                 // assume 3 to start, the most likely
    uint256 picosPerEth = pPicosPerEthT3;
    if (msg.value >= pMinWeiT2) {
      // Tranche 2 or 1 if not filled
      if (msg.value >= pMinWeiT1 && pPicosSoldT1 < pPicosCapT1) {
        tranche = 1;
        picosPerEth = pPicosPerEthT1;
      } else if (pPicosSoldT2 < pPicosCapT2) {
        tranche = 2;
        picosPerEth = pPicosPerEthT2;
      } // else 3 as tranche by size is filled
    }
    uint256 picos = safeMul(picosPerEth, msg.value) / 10**18; // Picos = Picos per ETH * Wei / 10^18
    // Bonus?
    if (bonusCentiPc > 0) // 675 for 6.75%
      picos += safeMul(picos, bonusCentiPc) / 10000;
    pWeiRaised = safeAdd(pWeiRaised, msg.value);
    pTokenC.Issue(msg.sender, picos, msg.value);
    pEscrowC.Deposit.value(msg.value)(msg.sender);
    uint256 usdRaised = safeMul(pWeiRaised, pUsdEtherPrice) / 10**18;
    emit SaleV(msg.sender, picos, msg.value, tranche, pUsdEtherPrice, picosPerEth, bonusCentiPc);
    if (!pSoftCapB && usdRaised >= pUsdSoftCap)
      SoftCapReachedLocal();
    if (tranche == 3)
      pPicosSoldT3 += picos; // ok wo overflow protection as pTokenC.Issue() would have thrown on overflow
    else if (tranche == 2)
      pPicosSoldT2 += picos;
    else
      pPicosSoldT1 += picos;
    if (pUsdHardCapB) {
      // Test for reaching hard cap on basis of USD raised at current Ether price
      if (usdRaised >= pUsdHardCap)
        HardCapReached();
    }else{
      // Test for reaching hard cap on basis of tranche pico caps
      if (pPicosSoldT3 >= pPicosCapT3 && pPicosSoldT2 >= pPicosCapT2 && pPicosSoldT1 >= pPicosCapT1)
        HardCapReached();
    }
    if (now >= pEndT && !pHardCapB) {
      // Time is up. Do this check after processing rather than doing an initial revert on the condition being met as then EndSale() wouldn't be run. Does allow one tran over time.
      EndSaleLocal();
      emit TimeUpV(pPicosSoldT1, pPicosSoldT2, pPicosSoldT3, pWeiRaised);
    }
    return true;
  }

  // Sale.SoftCapReachedLocal()
  // --------------------------
  function SoftCapReachedLocal() private {
    pSoftCapB = true;
    I_Hub(iOwnersYA[HUB_OWNER_X]).SoftCapReachedMO();
  }
  // Sale.SoftCapReached()
  // ---------------------
  // Called from Hub.SoftCapReached()
  function SoftCapReached() external IsHubCaller {
    pSoftCapB = true;
    emit SoftCapReachedV(pPicosSoldT1, pPicosSoldT2, pPicosSoldT3, pWeiRaised, pUsdEtherPrice);
  }

  // Sale.HardCapReached()
  // ---------------------
  function HardCapReached() private {
    // Cap reached so end the sale
    pHardCapB = true;
    EndSaleLocal();
    emit HardCapReachedV(pPicosSoldT1, pPicosSoldT2, pPicosSoldT3, pWeiRaised, pUsdEtherPrice, pUsdHardCapB);
  }
  // Sale.EndSaleLocal()
  // -------------------
  function EndSaleLocal() private {
    pSaleOpenB = false;
    I_Hub(iOwnersYA[HUB_OWNER_X]).EndSaleMO();
  }
  // Sale.EndSale()
  // --------------
  // Called from Hub.EndSale()
  function EndSale() external IsHubCaller {
    pSaleOpenB = false;
    emit EndSaleV();
  }

  // Sale Fallback function
  // ======================
  // Allow buying via the fallback fn
  function () payable external {
    Buy();
  }

} // End Sale contract
