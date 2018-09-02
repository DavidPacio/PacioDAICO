/* \Sale\Sale.sol 2018.06.06 started

The Sale contract for the Pacio DAICO

Owners: Deployer OpMan Hub Admin Poll

djh
TRA x -> #s?
sum needed?
finish BuyTranch1()



Pause/Resume
============
OpMan.PauseContract(SALE_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(SALE_CONTRACT_X) IsConfirmedSigner which is a managed op

Sale Fallback function
======================
Sending Ether is allowed - calls pBuy()

*/

pragma solidity ^0.4.24;
//pragma experimental "v0.5.0";

import "../lib/OwnedSale.sol";
import "../lib/Math.sol";
import "../Hub/I_Hub.sol";
import "../List/I_ListSale.sol";
import "../Token/I_TokenSale.sol";
import "../Funds/I_MfundSale.sol";
import "../Funds/I_PfundSale.sol";

// Tranches
// 1. 32 million PIOs for >=  50 ETH             at 7.50 Cents
// 2. 32 million PIOs for >=   5 ETH && < 50 ETH at 8.75 Cts
// 3. 350 million     for >= 0.1 ETH && < 5 ETH  at 10 Cents

contract Sale is OwnedSale, Math {
  string  public  name = "Pacio DAICO Sale";
  uint256 private constant NUM_TRNCHS = 5;         // number of tranches: Presale, T1, T2, T3, T4
  uint256 private constant TRNCH_PRESALE_X = 0;    // presale tranche, #s 1 to 4 used for tranches 1 to 4
  uint32  private pState;                          // DAICO state using the STATE_ bits. Replicated from Hub on a change
  uint256 private pSaleStartT;                     // i Sale start time
  uint256 private pSaleEndT;                       // i Sale end time.            Can be changed by a POLL_CHANGE_SALE_END_TIME_N poll
  uint256 private pUsdSoftCap;                     // i USD soft cap $8,000,000   Can be changed by a POLL_CHANGE_S_CAP_USD_N poll
  uint256 private pPicoSoftCap;                    // i Pico soft cap             Can be changed by a POLL_CHANGE_S_CAP_PIO_N poll
  uint256 private pUsdHardCap;                     // i USD hard cap $42,300,000  Can be changed by a POLL_CHANGE_H_CAP_USD_N poll
  uint256 private pPicoHardCap;                    // i Pico hard cap             Can be changed by a POLL_CHANGE_H_CAP_PIO_N poll
  uint256 private pPicosSold;                      // s Total Picos sold = sum of pPicosSoldTrnchsA[]
  uint256 private pWeiRaised;                      // s Cumulative wei raised for picos issued. Does not include prepurchases -> Pfund. Does not get reduced for refunds. USD Raised = pWeiRaised * pUsdEtherPrice / 10**18
  uint256 private pUsdRaised;                      // c pWeiRaised @ current pUsdEtherPrice = pWeiRaised * pUsdEtherPrice / 10**18
  uint256 private pUsdEtherPrice;                  // u Current US$ Ether price used for calculating pPicosPerEth? and USD calcs
  address private pPclAccountA;                    // i The PCL account (wallet or multi sig contract) for Tranche 1 deposits
  uint256[NUM_TRNCHS] private pPicoHardCapTrnchsA; // i Pico hard caps            tranches 1 to 4
  uint256[NUM_TRNCHS] private pMinWeiTrnchsA;      // i Minimum wei contribution  tranches 1 to 4
  uint256[NUM_TRNCHS] private pPriceCCentsTrnchsA; // i PIO price                 tranches 1 to 4 in centi-cents i.e.  750 for 7.50
  uint256[NUM_TRNCHS] private pPicosPerEthTrnchsA; // c Picos per Ether           tranches 1 to 4 pUsdEtherPrice * 10**16 / pPriceCCentsTrnchsA[x]
  uint256[NUM_TRNCHS] private pPicosSoldTrnchsA;   // s Picos sold in             tranches 0 to 4
                                                   // |- i  initialised via setup fn calls
                                                   // |- c calculated
                                                   // |- s summed
                                                   // |- u updated during running
  I_ListSale  private pListC;  // the List contract  -  read only use so List does not need to have Sale as an owner
  I_Hub       private pHubC;   // the Hub contract   /- Sale makes state changing calls to these contracts so they need to have Sale as an owner. Hub does.
  I_TokenSale private pTokenC; // the Token contract |  Token is owned by Owners Deployer OpMan Hub Sale Admin     so includes Sale
  I_MfundSale private pMfundC; // the Mfund contract |  Mfund is owned by Deployer OpMan Hub Sale Poll Pfund Admin so includes Sale
  I_PfundSale private pPfundC; // the Pfund contract |  Pfund is owned by Deployer, OpMan, Hub, Sale               so includes Sale

  // No constructor
  // ==============
  // Just the Owned constructor applies to set iOwnerA. iPausedB in Pausable is not set so the contract starts active but owned.

  // View Methods
  // ============
  // Sale.DaicoState()  Should be the same as Hub.DaicoState()
  function DaicoState() external view returns (uint32) {
    return pState;
  }
  // Sale.SaleStartTime()
  function SaleStartTime() external view returns (uint32) {
    return uint32(pSaleStartT);
  }
  // Sale.SaleEndTime()
  function SaleEndTime() external view returns (uint32) {
    return uint32(pSaleEndT);
  }
  // Sale.UsdSoftCap()
  function UsdSoftCap() external view returns (uint32) {
    return uint32(pUsdSoftCap);
  }
  // Sale.PioSoftCap()
  function PioSoftCap() external view returns (uint32) {
    return uint32(pPicoSoftCap / 10**12);
  }
  // Sale.UsdHardCap()
  function UsdHardCap() external view returns (uint32) {
    return uint32(pUsdHardCap);
  }
  // Sale.PioHardCap()
  function PioHardCap() external view returns (uint32) {
    return uint32(pPicoHardCap / 10**12);
  }
  // Sale.PioHardCapTrancheX()
  function PioHardCapTrancheX(uint32 tX) external view returns (uint32) {
    return tX < NUM_TRNCHS ? uint32(pPicoHardCapTrnchsA[tX] / 10**12) : 0;
  }
  // Sale.MinWeiTrancheX()
  function MinWeiTrancheX(uint32 tX) external view returns (uint256) {
    return tX < NUM_TRNCHS ? pMinWeiTrnchsA[tX] : 0;
  }
  // Sale.PioPriceCentiCentsTrancheX()
  function PioPriceCentiCentsTrancheX(uint32 tX) external view returns (uint32) {
    return tX < NUM_TRNCHS ? uint32(pPriceCCentsTrnchsA[tX]) : 0; // PIO price for tranche in centi-cents i.e.  750 for 7.50
  }
  // Sale.PicosPerEtherTranchX()
  function PicosPerEtherTranchX(uint32 tX) external view returns (uint32) {
    return tX < NUM_TRNCHS ? uint32(pPicosPerEthTrnchsA[tX]) : 0;
  }
  // Sale.PicosSold() -- should == Token.pPicosIssued unless refunding/transferring to Pacio Blockchain happens
  function PicosSold() external view returns (uint256) {
    return pPicosSold;
  }
  // Sale.PicosSoldTranches()
  function PicosSoldTranches() external view returns (uint256[NUM_TRNCHS]) {
    return pPicosSoldTrnchsA;
  }
  // Sale.WeiRaised()
  function WeiRaised() external view returns (uint256) {
    return pWeiRaised;
  }
  // Sale.UsdRaised()
  function UsdRaised() external view returns (uint32) {
    return uint32(pUsdRaised);
  }
  // Sale.FundWei()
  function FundWei() external view returns (uint256) {
    return pMfundC.FundWei();
  }
  // Sale.PrepurchaseFundWei()
  function PrepurchaseFundWei() external view returns (uint256) {
    return pPfundC.FundWei();
  }
  // Sale.UsdEtherPrice()
  function UsdEtherPrice() external view returns (uint256) {
    return pUsdEtherPrice; // Current US$ Ether price used for calculating pPicosPerEth? and USD calcs
  }
  // Sale.IsSaleOpen()
  function IsSaleOpen() external view returns (bool) {
    return pState & STATE_SALE_OPEN_B > 0;
  }
  // Sale.IsSoftCapReached()
  function IsSoftCapReached() external view returns (bool) {
    return pState & STATE_S_CAP_REACHED_B > 0;
  }
  // Sale.IsHardCapReached()
  function IsHardCapReached() external view returns (bool) {
    return pState & STATE_CLOSED_H_CAP_B > 0;
  }

  // Events
  // ======
  event InitialiseV(address TokenContract, address ListContract, address MfundContract, address PfundContract);
  event SetCapsAndTranchesV(uint32[NUM_TRNCHS] PioHardCapTranches, uint32 UsdSoftCap, uint32 PioSoftCap, uint32 UsdHardCap, uint32 PioHardCap,
                           uint256[NUM_TRNCHS] MinWeiTranches, uint256[NUM_TRNCHS] PioPriceCCentsTranches);
  event SetUsdEtherPriceV(uint256 UsdEtherPrice, uint256[NUM_TRNCHS] PicosPerEthTranches, uint256 UsdRaised);
  event SetPclAccountV(address PclAccount);
  event PresaleIssueV(address indexed toA, uint256 vPicos, uint256 vWei, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs);
  event StateChangeV(uint32 PrevState, uint32 NewState);
  event SetSaleTimesV(uint32 SaleStartTime, uint32 SaleEndTime);
  event PrepurchaseDepositV(address indexed Contributor, uint256 Wei);
  event SaleV(address indexed Contributor, uint256 Picos, uint256 SaleWei, uint32 Tranche, uint256 UsdEtherPrice, uint32 bonusCentiPc);
  event SoftCapReachedV(uint256 PicosSold, uint256 WeiRaised, uint256 UsdRaised, uint256 PicoSoftCap, uint256 UsdSoftCap);
  event HardCapReachedV(uint256 PicosSold, uint256 WeiRaised, uint256 UsdRaised, uint256 PicoHardCap, uint256 UsdHardCap);
  event         TimeUpV(uint256 PicosSold, uint256 WeiRaised, uint256 UsdRaised);
  event PollSetSaleEndTimeV(uint32 SaleEndTime);
  event PollSetUsdSoftCapV(uint32 UsdSoftCap);
  event PollSetPioSoftCapV(uint32 PioSoftCap);
  event PollSetUsdHardCapV(uint32 UsdHardCap);
  event PollSetPioHardCapV(uint32 PioHardCap);

  // Initialisation/Setup Methods
  // ============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Admin, 4 Poll
  // Owners must first be set by deploy script calls:
  //   Sale.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
  //   Sale.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Sale.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
  //   Sale.ChangeOwnerMO(POLL_OWNER_X, Poll address)

  // Sale.Initialise()
  // -----------------
  // To be called by the deploy script to set the contract address variables.
  function Initialise() external IsInitialising {
    I_OpMan opManC = I_OpMan(iOwnersYA[OP_MAN_OWNER_X]);
    pHubC   = I_Hub(iOwnersYA[HUB_OWNER_X]);
    pTokenC = I_TokenSale(opManC.ContractXA(TOKEN_CONTRACT_X));
    pListC  = I_ListSale(opManC.ContractXA(LIST_CONTRACT_X));
    pMfundC = I_MfundSale(opManC.ContractXA(MFUND_CONTRACT_X));
    pPfundC = I_PfundSale(opManC.ContractXA(PFUND_CONTRACT_X));
    emit InitialiseV(pTokenC, pListC, pMfundC, pPfundC);
  //iInitialisingB = false; No. Leave in initialising state
  }

  // Sale.SetCapsAndTranchesMO()
  // ---------------------------
  // Called by the deploy script when initialising or manually as Admin as a managed op to set Sale caps and tranches.
  function SetCapsAndTranchesMO(uint32[NUM_TRNCHS] vPioHardCapTrnchsA, uint32 vUsdSoftCap, uint32 vPioSoftCap, uint32 vUsdHardCap, uint32 vPioHardCap,
                               uint256[NUM_TRNCHS] vMinWeiTrnchsA, uint256[NUM_TRNCHS] vPriceCCentsTrnchsA) external {
    require(iIsInitialisingB() || (iIsAdminCallerB() && I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(SALE_SET_CAPS_TRANCHES_MO_X)));
    for (uint256 j=0; j<NUM_TRNCHS; j++) {
      pPicoHardCapTrnchsA[j] = vPioHardCapTrnchsA[j-1] * 10**12; // Hard cap for the sale tranches 1-4
      pMinWeiTrnchsA[j]      = vMinWeiTrnchsA[j-1];
      pPriceCCentsTrnchsA[j] = vPriceCCentsTrnchsA[j-1];
    }
    pUsdSoftCap    = vUsdSoftCap; // USD soft cap $8,000,000
    pPicoSoftCap   = vPioSoftCap * 10**12;
    pUsdHardCap    = vUsdHardCap; // USD soft cap $42,300,000
    pPicoHardCap   = vPioHardCap * 10**12;
    emit SetCapsAndTranchesV(vPioHardCapTrnchsA, vUsdSoftCap, vPioSoftCap, vUsdHardCap, vPioHardCap, vMinWeiTrnchsA,  vPriceCCentsTrnchsA);
  }

  // Sale.SetPclAccount()
  // --------------------
  // Called from Hub.SetPclAccountMO() to set/update the PCL withdrawal account
  function SetPclAccount(address vPclAccountA) external IsHubContractCaller IsActive {
    require(vPclAccountA != address(0));
    pPclAccountA = vPclAccountA;
    emit SetPclAccountV(vPclAccountA);
  }

  // Sale.SetUsdEtherPrice()
  // -----------------------
  // Called by the deploy script when initialising or manually by Admin on significant Ether price movement to set the price
  function SetUsdEtherPrice(uint256 vUsdEtherPrice) external {
    require(iIsInitialisingB() || iIsAdminCallerB());
    pUsdEtherPrice = vUsdEtherPrice; // e.g. 500
    pUsdRaised     = safeMul(pWeiRaised, pUsdEtherPrice) / 10**18;
    for (uint256 j=1; j<NUM_TRNCHS; j++)
      pPicosPerEthTrnchsA[j] = pUsdEtherPrice * 10**16 / pPriceCCentsTrnchsA[j]; // Picos per Ether for tranche 1 = pUsdEtherPrice * 10**16 / pPriceCCents   16 = 12 (picos per Pio) + 4 from pPriceCCents -> $s = 6,666,666,666,666,666
    emit SetUsdEtherPriceV(pUsdEtherPrice, pPicosPerEthTrnchsA, pUsdRaised);
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
  // no soft or hard cap check
  // Expects list account not to exist - multiple Seed Presale and Private Placement contributions to same account should be aggregated for calling this fn
  function PresaleIssue(address toA, uint256 vPicos, uint256 vWei, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external IsHubContractCaller IsActive {
    require(pState == 0 || pState & STATE_PRIOR_TO_OPEN_B > 0); // check that sale hasn't started yet
    pTokenC.Issue(toA, vPicos, vWei, 0); // 0 for tranche1Bit. Token.Issue() calls List.Issue()
    pWeiRaised = safeAdd(pWeiRaised, vWei);
    pPicosSoldTrnchsA[TRNCH_PRESALE_X] += vPicos; // ok wo overflow protection as pTokenC.Issue() would have thrown on overflow
    pPicosSold    += vPicos;
    emit PresaleIssueV(toA, vPicos, vWei, vDbId, vAddedT, vNumContribs);
  }

  // Sale.SetSaleTimes()
  // -------------------
  // Called from Hub.SetSaleTimes() to set sale times
  // Initialise(), SetCapsAndTranchesMO(), SetUsdEtherPrice(), and PresaleIssue() multiple times must have been called before this.
  // Hub.SetSaleTimes() will first have set state bit STATE_PRIOR_TO_OPEN_B or STATE_SALE_OPEN_B
  function SetSaleTimes(uint32 vSaleStartT, uint32 vSaleEndT) external IsHubContractCaller {
    pSaleStartT = vSaleStartT;
    pSaleEndT   = vSaleEndT;
    emit SetSaleTimesV(vSaleStartT, vSaleEndT);
  }

  // State changing external methods
  // ===============================

  // Sale.StateChange()
  // ------------------
  // Called from Hub.pSetState() on a change of state to replicate the new state setting and take any required actions
  function StateChange(uint32 vState) external IsHubContractCaller {
    if ((vState & STATE_S_CAP_REACHED_B) > 0 && (pState & STATE_S_CAP_REACHED_B) == 0)
      // Change of state for Soft Cap being reached.
      // Can be as a call back from Hub via pSoftCapReached() here -> Hub.SoftCapReachedMO() or manually by Admin as a managed op via Hub.SoftCapReachedMO()
      emit SoftCapReachedV(pPicosSold, pWeiRaised, pUsdRaised, pPicoSoftCap, pUsdSoftCap);
    emit StateChangeV(pState, vState);
    pState = vState;
  }

  // Sale.PollSetSaleEndTime()
  // ------------------------
  // Called from Poll.pClosePoll() on a POLL_CHANGE_SALE_END_TIME_N yes
  function PollSetSaleEndTime(uint32 vSaleEndT) external IsPollContractCaller {
    pSaleEndT = vSaleEndT;
    emit PollSetSaleEndTimeV(vSaleEndT);
  }

  // Sale.PollSetUsdSoftCap()
  // ------------------------
  // Called from Poll.pClosePoll() on a POLL_CHANGE_S_CAP_USD_N yes
  function PollSetUsdSoftCap(uint32 vUsdSoftCap) external IsPollContractCaller {
    pUsdSoftCap = vUsdSoftCap; // USD soft cap $8,000,000
    emit PollSetUsdSoftCapV(vUsdSoftCap);
  }

  // Sale.PollSetPioSoftCap()
  // ------------------------
  // Called from Poll.pClosePoll() on a POLL_CHANGE_S_CAP_PIO_N yes
  function PollSetPioSoftCap(uint32 vPioSoftCap) external IsPollContractCaller {
    pPicoSoftCap = vPioSoftCap * 10**12;
    emit PollSetPioSoftCapV(vPioSoftCap);
  }

  // Sale.PollSetUsdHardCap()
  // ------------------------
  // Called from Poll.pClosePoll() on a POLL_CHANGE_H_CAP_USD_N yes
  function PollSetUsdHardCap(uint32 vUsdHardCap) external IsPollContractCaller {
    pUsdHardCap = vUsdHardCap; // USD soft cap $8,000,000
    emit PollSetUsdHardCapV(vUsdHardCap);
  }

  // Sale.PollSetPioHardCap()
  // ------------------------
  // Called from Poll.pClosePoll() on a POLL_CHANGE_H_CAP_PIO_N yes
  function PollSetPioHardCap(uint32 vPioHardCap) external IsPollContractCaller {
    pPicoSoftCap = vPioHardCap * 10**12;
    emit PollSetPioHardCapV(vPioHardCap);
  }

  // Sale.BuyTranche1()
  // ------------------
  // Function for funds being sent to the DAICO to buy the Tranche1 deal
  // A list entry for msg.sender is expected to exist for msg.sender created via a Hub.CreateListEntry() call. Could be not whitelisted.
  // Cases:
  // - sending when not yet whitelisted                  -> Pfund whether sale open or not
  // - sending when whitelisted but sale is not yet open -> Pfund
  // - sending when whitelisted and sale is open         -> Mfund via pProcess()
  function BuyTranche1() payable external {
    pBuy(true);
  }

  // Sale.pBuy() private
  // -----------
  // Function for funds being sent to the DAICO
  // Called from fallback() with tranche1B false and BuyTranche1() with tranche1B true
  // A list entry for msg.sender is expected to exist for msg.sender created via a Hub.CreateListEntry() call. Could be not whitelisted.
  // Cases:
  // - sending when not yet whitelisted                  -> Pfund whether sale open or not
  // - sending when whitelisted but sale is not yet open -> Pfund
  // - sending when whitelisted and sale is open         -> Mfund via pProcess()
  function pBuy(bool tranche1B) private IsActive returns (bool) { // public because it is called from the fallback fn
    require(pState & STATE_DEPOSIT_OK_B > 0, 'Sale has closed'); // STATE_PRIOR_TO_OPEN_B | STATE_SALE_OPEN_B
    (uint32 bonusCentiPc, uint32 bits) = pListC.BonusPcAndBits(msg.sender);
    require(bits > 0, 'Account not registered');
    require(bits & LE_SEND_FUNDS_NOK_B == 0, 'Sending not allowed');
    if (tranche1B) {
      // Here from BuyTranche1()
      require(msg.value >= pMinWeiTrnchsA[1], "Ether less than minimum"); // check that sent >= tranche 1 min ETH
      // Can't buy Tranche 1 if have already made T2 to T4 purchases unless soft cap has been reached
      require(bits & LE_M_FUND_B == 0 || pState & STATE_S_CAP_REACHED_B > 0, 'Cant buy T1 before soft cap as have soft cap miss refundable funds');
      // need to set bit LE_TRANCH1_B
    }else{
      // Here for std buy from fallback()
      require(msg.value >= pMinWeiTrnchsA[4], "Ether less than minimum"); // check that sent >= tranche 4 min ETH
      require(bits & LE_PRESALE_TRANCH1_B == 0 || pState & STATE_S_CAP_REACHED_B > 0, 'Cant buy T2-4 before soft cap as have soft cap miss non-refundable funds');
    }
    if (pState & STATE_PRIOR_TO_OPEN_B > 0 && now >= pSaleStartT)
      // Sale hasn't started yet but the time come
      pHubC.StartSaleMO(); // changes state to STATE_SALE_OPEN_B
    if (bits & LE_WHITELISTED_B == 0 || pState & STATE_PRIOR_TO_OPEN_B > 0) {
      // Not whitelisted yet || sale hasn't started yet -> Prepurchase
      pListC.PrepurchaseDeposit(msg.sender, msg.value, tranche1B ? LE_TRANCH1_B : 0); // updates the list entry
      pPfundC.Deposit.value(msg.value)(msg.sender);     // transfers msg.value to the Prepurchase escrow account
      emit PrepurchaseDepositV(msg.sender, msg.value);
      return true;
    }
    // Whitelisted and ok to buy
    pProcess(msg.sender, msg.value, bonusCentiPc, tranche1B ? 1 : 0);
    if (tranche1B)
    //pPclAccountA.transfer(this.balance);
      pPclAccountA.transfer(msg.value);
    else
      pMfundC.Deposit.value(msg.value)(msg.sender); // transfers msg.value to the Mfund account
    return true;
  } // end pBuy()

  // Sale.pProcess() private to process the buy/transfer operation, issue the PIOs, and check for caps being reached
  // ------------
  // a. Sale.pBuy()                                                -> here -> Token.Issue() -> List.Issue() for normal buying
  // b. Hub.Whitelist()  -> Hub.pPMtransfer() -> Sale.PMtransfer() -> here -> Token.Issue() -> List.Issue() for Pfund to Mfund transfers on whitelisting
  // c. Hub.PMtransfer() -> Hub.pPMtransfer() -> Sale.PMtransfer() -> here -> Token.Issue() -> List.Issue() for Pfund to Mfund transfers for an entry which was whitelisted and ready prior to opening of the sale which has now happened
  // Decides on the tranche, calculates the picos, checks for softcap being reached, or the sale ending via hard cap being reached or time being up
  function pProcess(address senderA, uint256 weiContributed, uint32 bonusCentiPc, uint32 tranche) private {
    // Which tranche? Can be set as 1 BuyTranche1() or 1-4 via TokenSwapAndBountyIssue() or 0 othwrwise meaning work it out here
    if (tranche == 0) {
      tranche = 4; // assume 4 to start, the most likely
      if (weiContributed >= pMinWeiTrnchsA[3]) {
        // Tranche 2 or 3
        if (weiContributed >= pMinWeiTrnchsA[2] && pPicosSoldTrnchsA[2] < pPicoHardCapTrnchsA[2])
          tranche = 2;
        else if (pPicosSoldTrnchsA[3] < pPicoHardCapTrnchsA[3])
          tranche = 3;
        // else 4 as tranches 2 and 3 don't pass
      }
    }
    uint256 picos = safeMul(pPicosPerEthTrnchsA[tranche], weiContributed) / 10**18; // Picos = Picos per ETH * Wei / 10^18
    // Bonus?
    if (bonusCentiPc > 0) // 675 for 6.75%
      picos += safeMul(picos, bonusCentiPc) / 10000;
    pWeiRaised = safeAdd(pWeiRaised, weiContributed);
    pTokenC.Issue(senderA, picos, weiContributed, tranche == 1 ? LE_TRANCH1_B : 0); // which calls List.Issue()
    pUsdRaised = safeMul(pWeiRaised, pUsdEtherPrice) / 10**18;
    emit SaleV(senderA, picos, weiContributed, tranche, pUsdEtherPrice, bonusCentiPc);
    pPicosSoldTrnchsA[tranche] += picos; // ok wo overflow protection as pTokenC.Issue() would have thrown on overflow
    pPicosSold += picos;
    // Test for reaching soft cap
    if (pState & STATE_S_CAP_REACHED_B == 0 && (pPicosSold >= pPicoSoftCap || pUsdRaised >= pUsdSoftCap))
      pSoftCapReached(); // event is emitted on the state change as reaching soft cap can be set via Hub
    // Test for reaching hard cap
    if (pPicosSold >= pPicoHardCap || pUsdRaised >= pUsdHardCap) {
      pCloseSale(STATE_CLOSED_H_CAP_B);
      emit HardCapReachedV(pPicosSold, pWeiRaised, pUsdRaised, pPicoHardCap, pUsdHardCap);
    } else if (now >= pSaleEndT && (pState & STATE_CLOSED_H_CAP_B == 0)) {
      // Time is up wo hard cap having been reached. Do this check after processing rather than doing an initial revert on the condition being met as then pCloseSale() wouldn't be run. Does allow one tran over time.
      pCloseSale(STATE_CLOSED_TIME_UP_B);
      emit TimeUpV(pPicosSold, pWeiRaised, pUsdRaised);
    }
  } // end pProcess()

  // Sale.PMtransfer()
  // -----------------
  // Cases:
  // a. Hub.Whitelist()  -> Hub.pPMtransfer() -> here -> Sale.pProcess()-> Token.Issue() -> List.Issue() for Pfund to Mfund transfers on whitelisting
  // b. Hub.PMtransfer() -> Hub.pPMtransfer() -> here -> Sale.pProcess()-> Token.Issue() -> List.Issue() for Pfund to Mfund transfers for an entry which was whitelisted and ready prior to opening of the sale which has now happened
  // then finally Hub.pPMtransfer() transfers the Ether from Pfund to Mfund
  function PMtransfer(address senderA, uint256 weiContributed) external IsHubContractCaller {
    (uint32 bonusCentiPc, uint32 bits) = pListC.BonusPcAndBits(msg.sender);
    require(bits > 0 && bits & LE_WHITELISTED_P_FUND_B > 0 && pState & STATE_SALE_OPEN_B > 0); // Checked by Hub.Whitelist()/Hub.PMtransfer() so expected to be ok here
    pProcess(senderA, weiContributed, bonusCentiPc, bits & LE_TRANCH1_B > 0 ? 1 : 0);
  }

  // Sale.TokenSwapAndBountyIssue()
  // ------------------------------
  // Hub.TokenSwap()   -> here -> Sale.pProcess()-> Token.Issue() -> List.Issue()
  // Hub.BountyIssue() -> here -> Sale.pProcess()-> Token.Issue() -> List.Issue()
  // Hub.TokenSwap() and Hub.BountyIssue() emit events
  function TokenSwapAndBountyIssue(address toA, uint256 picos, uint32 tranche) external IsHubContractCaller IsActive {
    // Bits and state are checked by Checked by Hub.TokenSwap()/Hub.BountyIssue()
    // weiContributed = Picos * 10^18 / Picos per Ether
    pProcess(toA, picos * 10**18 / pPicosPerEthTrnchsA[tranche], 0, tranche); // 0 for bonusCentiPc
  }

  // Sale.pSoftCapReached()
  // ----------------------
  function pSoftCapReached() private {
    pHubC.SoftCapReachedMO(); // This will cause a StateChange() callback
  }

  // Sale.pCloseSale()
  // -----------------
  // Called from pBuy() for hard cap reached or time up
  function pCloseSale(uint32 vBit) private {
    pHubC.CloseSaleMO(vBit);
  }

  // Sale.NewListContract()
  // ----------------------
  // To be called manually via Hub.NewListContract() if the List contract is changed. newListContractA is checked and logged by Hub.NewListContract()
  // Only to be done if a new list contract has been constructed and data transferred
  function NewListContract(address newListContractA) external IsHubContractCaller {
    pListC = I_ListSale(newListContractA); // The List contract
  }

  // Sale Fallback function
  // ======================
  // Allow buying via the fallback fn
  function () payable external {
    pBuy(false); // false == not tranche1 deal
  }

} // End Sale contract
