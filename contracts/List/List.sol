/* \List\List.sol 2018.06.06 started

List of people/addresses to do with Pacio

Owned by
0 Deployer
1 OpMan
2 Hub
3 Token

djh??
- other owners e.g. voting contract?
- add vote count data

Member types -  see Constants.sol
None,       // 0 An undefined entry with no add date
Contract,   // 1 Contract (Sale) list entry for Minted tokens. Has dbId == 1
Grey,       // 2 Grey listed, initial default, not whitelisted, not contract, not presale, not refunded, not downgraded, not member
Presale,    // 3 Seed presale or private placement entry. Has PRESALE bit set. whiteT is not set
Refunded,   // 4 Contributed funds have been refunded at refundedT. Must have been Presale or Member previously.
Downgraded, // 5 Has been downgraded from White or Member
White,      // 6 Whitelisted with no picosBalance
Member      // 7 Whitelisted with a picosBalance

Member info [Struct order is different to minimise slots used]
address nextEntryA;    // Address of the next entry     - 0 for the last  one
address prevEntryA;    // Address of the previous entry - 0 for the first one
address proxyA;        // Address of proxy for voting purposes
uint32  bits;          // Bit settings
uint32  addedT;        // Datetime when added
uint32  whiteT;        // Datetime when whitelisted
uint32  firstContribT; // Datetime when first contribution made
uint32  refundT;       // Datetime when refunded
uint32  downT;         // Datetime when downgraded
uint32  bonusCentiPc,  // Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
uint32  dbId;          // Id in DB for name and KYC info
uint32  numContribs;   // Number of separate contributions made
uint256 weiContributed;// wei contributed
uint256 picosBought;   // Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
uint256 picosBalance;  // Current token balance - determines who is a Pacio Member |
*/

pragma solidity ^0.4.24;

import "../lib/OwnedList.sol";
import "../lib/Math.sol";
import "../lib/Constants.sol";
import "../OpMan/I_OpMan.sol";

contract List is Owned, Math {
  string  public  name = "Pacio DAICO Participants List";
  bool    private pTransfersOkB;  // false when sale is running = transfers are stopped by default but can be enabled manually globally or for particular members;
  address private pFirstEntryA;   // Address of first entry
  address private pLastEntryA;    // Address of last entry
  uint256 private pNumEntries;    // Number of list entries
  uint256 private pNumGrey;       // Number of grey list entries
  uint256 private pNumWhite;      // Number of white list entries - includes pNumMembers + pNumDowngraded + (those pNumRefunded ones that were not refunded from the Presale state)
  uint256 private pNumMembers;    // Number of Pacio members
  uint256 private pNumPresale;    // Number of presale list entries = seed presale and private placement entries
  uint256 private pNumProxies;    // Number of entries with a Proxy set
  uint256 private pNumRefunded;   // Number refunded
  uint256 private pNumBurnt;      // Number burnt
  uint256 private pNumDowngraded; // Number downgraded (from white list)
  address private pSaleA;         // the Sale contract address - only used as an address here i.e. don't need pSaleC
  bool    private pSoftCapB;      // Set to true when softcap is reached in Sale

  // Struct to hold member data, with a doubly linked list of List to permit traversing List
  // Each member requires 6 storage slots.
  struct R_List{        // Bytes Storage slot  Comment
    address nextEntryA;    // 20 0 Address of the next entry     - 0 for the last  one
    uint32  bits;          //  4 0 Bit settings
    uint32  addedT;        //  4 0 Datetime when added
    uint32  whiteT;        //  4 0 Datetime when whitelisted
    address prevEntryA;    // 20 1 Address of the previous entry - 0 for the first one
    uint32  firstContribT; //  4 1 Datetime when first contribution made
    uint32  refundT;       //  4 1 Datetime when refunded
    uint32  downT;         //  4 1 Datetime when downgraded
    address proxyA;        // 20 2 Address of proxy for voting purposes
    uint32  bonusCentiPc;  //  4 2 Bonus percentage * 100 i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
    uint32  dbId;          //  4 2 Id in DB for name and KYC info
    uint32  numContribs;   //  4 2 Number of separate contributions made
    uint256 weiContributed;// 32 3 wei contributed
    uint256 picosBought;   // 32 4 Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
    uint256 picosBalance;  // 32 5 Current token balance - determines who is a Pacio Member |
  }
  mapping (address => R_List) private pListMR; // Pacio List indexed by Ethereum account address

  // Events
  // ======
   event NewEntryV(address indexed Entry, uint32 Bits, uint32 DbId);
  event WhitelistV(address indexed Entry, uint32 WhitelistT);
  event DowngradeV(address indexed Entry, uint32 DowngradeT);
   event SetBonusV(address indexed Entry, uint32 bonusCentiPc);
   event SetProxyV(address indexed Entry, address Proxy);
  event SetTransfersOkByDefaultV(bool On);
  event SetTransferOkV(address indexed Entry, bool On);
  event IssueV(address indexed To, uint256 Picos, uint256 Wei);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Token
  // Owners must first be set by deploy script calls:
  //   List.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   List.ChangeOwnerMO(TOKEN_OWNER_X, Token address)
  //   List.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address) <=== Must come after HUB_OWNER_X, TOKEN_OWNER_X have been set

  // List.Initialise()
  // -----------------
  // To be called by the deploy script to set the contract address variables.
  function Initialise() external IsDeployerCaller {
    require(iInitialisingB); // To enforce being called only once
    pSaleA = I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(SALE_X);
    iInitialisingB = false;
  }
  // List.StartSale()
  // -----------------
  // Called only from Hub.StartSale()
  function StartSale() external IsHubCaller {
    pTransfersOkB = false; // Stop transfers by default
  }

  // List.SoftCapReached()
  // ---------------------
  // Is called from Hub.SoftCapReached() when soft cap is reached
  function SoftCapReached() external IsHubCaller {
    pSoftCapB = true;
  }

  // List.SetTransfersOkByDefault()
  // ------------------------------
  // Callable only from Hub to set/unset pTransfersOkB
  function SetTransfersOkByDefault(bool B) external IsHubCaller returns (bool) {
    if (B)
      require(pSoftCapB, 'Requires Softcap');
    pTransfersOkB = B;
    emit SetTransfersOkByDefaultV(B);
    return true;
  }

  // List.SetTransferOk()
  // --------------------
  // Callable only from Hub to set TRANSFER_OK bit of entry vEntryA on if B is true, or unset the bit if B is false
  function SetTransferOk(address vEntryA, bool B) external IsHubCaller returns (bool) {
    require(pListMR[vEntryA].addedT > 0, "Account not known"); // Entry is expected to exist
    if (B) // Set
      pListMR[vEntryA].bits |= TRANSFER_OK;
    else   // Unset
      pListMR[vEntryA].bits &= ~TRANSFER_OK;
    emit SetTransferOkV(vEntryA, B);
    return true;
  }

  // View Methods
  // ============
  function ListEntriesNumber() external view returns (uint256) {
    return pNumEntries;
  }
  function GreyListNumber() external view returns (uint256) {
    return pNumGrey;
  }
  function WhiteListNumber() external view returns (uint256) {
    return pNumWhite;
  }
  function PacioMemberNumber() external view returns (uint256) {
    return pNumMembers;
  }
  function PresaleNumber() external view returns (uint256) {
    return pNumPresale;
  }
  function ProxiesNumber() external view returns (uint256) {
    return pNumProxies;
  }
  function RefundedNumber() external view returns (uint256) {
    return pNumRefunded;
  }
  function BurntNumber() external view returns (uint256) {
    return pNumBurnt;
  }
  function DowngradedNumber() external view returns (uint256) {
    return pNumDowngraded;
  }
  function IsTransferAllowedByDefault() external view returns (bool) {
    return pTransfersOkB;
  }
  function IsTransferAllowed(address frA) private view returns (bool) {
    return (pTransfersOkB                           // Transfers can be made
         || (pListMR[frA].bits & TRANSFER_OK) > 0); // or they are allowed for this member
  }
  function ListEntryExists(address accountA) external view returns (bool) {
    return pListMR[accountA].addedT > 0;
  }
  function PicosBalance(address accountA) external view returns (uint256 balance) {
    return pListMR[accountA].picosBalance;
  }
  function PicosBought(address accountA) external view returns (uint256 balance) {
    return pListMR[accountA].picosBought;
  }
  function BonusPcAndType(address accountA) external view returns (uint32 bonusCentiPc, uint8 typeN) {
    return (pListMR[accountA].bonusCentiPc, EntryType(accountA));
  }
  // List.EntryType()
  // ----------------
  // Returns the entry type of the accountA list entry as one of the ENTRY_ constants
  // Member types
  // - ENTRY_NONE       0 An undefined entry with no add date
  // - ENTRY_CONTRACT   1 Contract (Sale) list entry for Minted tokens. Has dbId == 1
  // - ENTRY_GREY       2 Grey listed, initial default, not whitelisted, not contract, not presale, not refunded, not downgraded, not member
  // - ENTRY_PRESALE    3 Seed presale or internal placement entry. Has PRESALE bit set. whiteT is not set
  // - ENTRY_REFUNDED   4 Contributed funds have been refunded at refundedT. Must have been Presale or Member previously.
  // - ENTRY_DOWNGRADED 5 Has been downgraded from White or Member
  // - ENTRY_BURNT      6 Has been burnt
  // - ENTRY_WHITE      7 Whitelisted with no picosBalance
  // - ENTRY_MEMBER     8 Whitelisted with a picosBalance
  function EntryType(address accountA) public view returns (uint8 typeN) {
    R_List storage rsEntryR = pListMR[accountA];
    return rsEntryR.addedT == 0 ? ENTRY_NONE :
      (rsEntryR.bits & BURNT > 0 ? ENTRY_BURNT :
        (rsEntryR.refundT > 0 ? ENTRY_REFUNDED :
         (rsEntryR.downT > 0 ? ENTRY_DOWNGRADED :
          (rsEntryR.whiteT > 0 ? (rsEntryR.picosBalance > 0 ? ENTRY_MEMBER : ENTRY_WHITE) :
           (rsEntryR.bits & PRESALE > 0 ? ENTRY_PRESALE : (rsEntryR.dbId == 1 ? ENTRY_CONTRACT : ENTRY_GREY))))));
  }
  // List.Browse()
  // -------------
  // Returns address and type of the list entry being browsed to
  // Requires Sender to be Hub
  // Parameters:
  // - currentA  Address of the current entry, ignored for vActionN == First | Last
  // - vActionN { First, Last, Next, Prev} Browse action to be performed
  // Returns:
  // - retA   address and type of the list entry found, 0x0 if none
  // - typeN  type of the entry { None, Contract, Grey, Presale, Refunded, Downgraded, White, Member }
  // Note: Browsing for a particular type of entry is not implemented as that would involve looping -> gas problems.
  //       The calling app will need to do the looping if necessary, thus the return of typeN.
  function Browse(address currentA, uint8 vActionN) external view IsHubCaller returns (address retA, uint8 typeN) {
    if (vActionN == BROWSE_FIRST) {
      retA = pFirstEntryA;
    }else if (vActionN == BROWSE_LAST) {
      retA = pLastEntryA;
    }else if (vActionN == BROWSE_NEXT) {
      retA = pListMR[currentA].nextEntryA;
    }else{ // Prev
      retA = pListMR[currentA].prevEntryA;
    }
    return (retA, EntryType(retA));
  }
  // List.NextEntry()
  // ----------------
  // Requires Sender to be Hub
  function NextEntry(address accountA) external view IsHubCaller returns (address) {
    return pListMR[accountA].nextEntryA;
  }
  // List.PrevEntry()
  // ----------------
  // Requires Sender to be Hub
  function PrevEntry(address accountA) external view IsHubCaller returns (address) {
    return pListMR[accountA].prevEntryA;
  }
  // List.Proxy()
  // ------------
  // Requires Sender to be Hub
  function Proxy(address accountA) external view IsHubCaller returns (address) {
    return pListMR[accountA].proxyA;
  }
  // List.Lookup()
  // -------------
  // Returns information about the accountA list entry - all except for the addresses
  function Lookup(address accountA) external view returns (
    uint32  bits,          // Bit settings                                     /- All of R_List except for nextEntryA, prevEntryA, proxyA
    uint32  addedT,        // Datetime when added                              |  Can't include all unless packing some together re Solidity stack size
    uint32  whiteT,        // Datetime when whitelisted                        V
    uint32  firstContribT, // Datetime when first contribution made
    uint32  refundT,       // Datetime when refunded
    uint32  downT,         // Datetime when downgraded
    uint32  bonusCentiPc,  // Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
    uint32  dbId,          // Id in DB for name and KYC info
    uint32  numContribs,   // Number of separate contributions made
    uint256 weiContributed,// wei contributed
    uint256 picosBought,   // Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
    uint256 picosBalance) {// Current token balance - determines who is a Pacio Member |
    R_List storage rsEntryR = pListMR[accountA];
    return (rsEntryR.bits, rsEntryR.addedT, rsEntryR.whiteT, rsEntryR.firstContribT, refundT, rsEntryR.downT, rsEntryR.bonusCentiPc,
            rsEntryR.dbId, rsEntryR.numContribs, rsEntryR.weiContributed, rsEntryR.picosBought, rsEntryR.picosBalance);
  }

  // Modifier functions
  // ==================
  // IsTransferOK
  // ------------
  // Checks that the list is active; both frA and toA exist; transfer from frA is ok; transfer to toA is ok (toA is whitelisted); and that frA has the tokens available
  // Also have an IsTransferOK modifier in EIP20Token
  modifier IsTransferOK(address frA, address toA, uint256 value) {
    require(value > 0                               // Non-zero transfer No! The EIP-20 std says: Note Transfers of 0 values MUST be treated as normal transfers and fire the Transfer event
      // && toA != frA                              // Destination is different from source. Not here. Is checked in calling fn.
         && pListMR[frA].addedT > 0                 // frA exists
         && pListMR[toA].whiteT > 0                 // toA exists and is whitelisted
         && (pTransfersOkB                          // Transfers can be made                /- ok to transfer from frA
          || (pListMR[frA].bits & TRANSFER_OK) > 0) // or they are allowed for this member  |
         && pListMR[frA].picosBalance >= value,     // frA has the picos available
            "Transfer not allowed");
    _;
  }


  // State changing methods
  // ======================

  // List.CreateEntry()
  // ------------------
  // Create a new list entry, and add it into the doubly linked list
  // Is called from Hub
  // 0 OpMan, 1 Hub, 2 Sale, 3 Token
  function CreateEntry(address vEntryA, uint32 vBits, uint32 vDbId) external IsHubCaller returns (bool) {
    return pCreateEntry(vEntryA, vBits, vDbId);
  }

  // List.pCreateEntry() private
  // ------------------
  // Create a new list entry, and add it into the doubly linked list
  // Is called from Hub via List.CreateEntry()
  //    and locally from CreateSaleContractEntry() and CreatePresaleEntry()
  // 0 Deployer, 1 OpMan, 2 Hub, 3 Token
  function pCreateEntry(address vEntryA, uint32 vBits, uint32 vDbId) private returns (bool) {
    require(vEntryA != address(0)     // Defined
         && vEntryA != iOwnersYA[OP_MAN_OWNER_X] // Not OpMan
         && vEntryA != iOwnersYA[HUB_OWNER_X]    // Not Hub
         && vEntryA != iOwnersYA[TOKEN_OWNER_X]  // Not Token
      // && vEntryA != pSaleA         // Not Sale - No as we do create a Sale contract entry
         && vEntryA != address(this), // Not this list contract
            'Invalid account address');
    require(pListMR[vEntryA].addedT == 0, "Account already exists"); // Not already in existence
    pListMR[vEntryA] = R_List(
      address(0),   // address nextEntryA;    // 20 0 Address of the next entry     - 0 for the last  one
      vBits,        // uint32  bits;          //  4 0 Bit settings
      uint32(now),  // uint32  addedT;        //  4 0 Datetime when added
      0,            // uint32  whiteT;        //  4 0 Datetime when whitelisted
      pLastEntryA,  // address prevEntryA;    // 20 1 Address of the previous entry - 0 for the first one
      0,            // uint32  firstContribT; //  4 1 Datetime when first contribution made
      0,            // uint32  refundT;       //  4 1 Datetime when refunded
      0,            // uint32  downT;         //  4 1 Datetime when downgraded
      0,            // address proxyA;        // 20 2 Address of proxy for voting purposes
      0,            // uint32  bonusCentiPc;  //  4 2 Bonus percentage * 100 i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
      vDbId,        // uint32  dbId;          //  4 2 Id in DB for name and KYC info
      0,            // uint32  numContribs;   //  4 2 Number of separate contributions made
      0,            // uint256 weiContributed;// 32 3 wei contributed
      0,            // uint256 picosBought;   // 32 4 Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
      0);           // uint256 picosBalance;  // 32 5 Current token balance - determines who is a Pacio Member |
    // Update other state vars
    pNumGrey++;     // Assumed grey initially
    if (++pNumEntries == 1) // Number of list entries
      pFirstEntryA = vEntryA;
    else
      pListMR[pLastEntryA].nextEntryA = vEntryA;
    pLastEntryA = vEntryA;
    emit NewEntryV(vEntryA, vBits, vDbId);
    return true;
  }

  // List.CreateSaleContractEntry()
  // ------------------------------
  // Called from Token.Initialise() to create the Sale contract list entry which holds the minted Picos. pSaleA is the Sale sale contract
  // Called from Token.NewSaleContract() to create the new Sale contract list entry
  // Not whitelisted so that transfers from it cannot be done. Decrementing happens via Issue().
  // Have a special transfer fn TransferSaleContractBalance() for the case of a new Sale contract
  function CreateSaleContractEntry(uint256 vPicos) external IsTokenCaller returns (bool) {
    require(pCreateEntry(pSaleA, TRANSFER_OK, 1)); // DbId of 1 assumed for Sale sale contract
    pListMR[pSaleA].picosBalance = vPicos;
    pNumGrey--;  // No need for subMaxZero(pNumGrey, 1) here as the pCreateEntry() call has just incremented this
    return true;
  }

  // List.CreatePresaleEntry()
  // -------------------------
  // Create a Seed Presale or Private Placement list entry, called from Hub.PresaleIssue()
  function CreatePresaleEntry(address vEntryA, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external IsHubCaller returns (bool) {
    require(pCreateEntry(vEntryA, PRESALE, vDbId));
    pListMR[vEntryA].addedT        =
    pListMR[vEntryA].firstContribT = vAddedT; // firstContribT assumed to be the same as addedT for presale entries
    if (vNumContribs > 1)
      pListMR[vEntryA].numContribs = vNumContribs - 1; // -1 because List.Issue() called subsequently will increment this
    pNumPresale++;
    return true;
  }

  // List.Whitelist()
  // ----------------
  // Whitelist an entry
  function Whitelist(address vEntryA, uint32 vWhiteT) external IsHubCaller returns (bool) {
    require(pListMR[vEntryA].addedT > 0, "Account not known"); // Entry is expected to exist
    if (pListMR[vEntryA].whiteT == 0) { // if not just changing the white list date then decrement grey and incr white
      pNumGrey = subMaxZero(pNumGrey, 1);
      pNumWhite++;
      if (pListMR[vEntryA].picosBalance > 0) // could be here for a presale entry with a balance now being whitelisted
        pNumMembers++;
    }
    pListMR[vEntryA].whiteT = vWhiteT;
    emit WhitelistV(vEntryA, vWhiteT);
    return true;
  }

  // List.Downgrade()
  // ----------------
  // Downgrades an entry from whitelisted
  function Downgrade(address vEntryA, uint32 vDownT) external IsHubCaller returns (bool) {
    require(pListMR[vEntryA].addedT > 0, "Account not known"); // Entry is expected to exist
    if (pListMR[vEntryA].downT == 0) { // if not just changing the downgrade date then decrement grey and incr white
      pNumWhite = subMaxZero(pNumWhite, 1);
      pNumDowngraded++;
    }
    pListMR[vEntryA].downT = vDownT;
    emit DowngradeV(vEntryA, vDownT);
    return true;
  }

  // List.SetBonus()
  // ---------------
  // Sets bonusCentiPc Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
  function SetBonus(address vEntryA, uint32 vBonusPc) external IsHubCaller returns (bool) {
    require(pListMR[vEntryA].addedT > 0, "Account not known"); // Entry is expected to exist
    pListMR[vEntryA].bonusCentiPc = vBonusPc;
    emit SetBonusV(vEntryA, vBonusPc);
    return true;
  }

  // List.SetProxy()
  // ---------------
  // Sets the proxy address of entry vEntryA to vProxyA plus updates bits and pNumProxies
  // vProxyA = 0x0 to unset or remove a proxy
  function SetProxy(address vEntryA, address vProxyA) external IsHubCaller returns (bool) {
    require(pListMR[vEntryA].addedT > 0, "Account not known"); // Entry is expected to exist
    if (vProxyA == address(0)) {
      // Unset or remove proxy
      if (pListMR[vEntryA].proxyA >= address(0)) {
        // Did have a proxy set
        pListMR[vEntryA].bits &= ~HAS_PROXY; // rather than ^= HAS_PROXY in case the HAS_PROXY bit is wrongly not set
        pNumProxies = subMaxZero(pNumProxies, 1);
      }
    }else{
      // Set proxy
      if (pListMR[vEntryA].proxyA == address(0))
        // Didn't previously have one set
        pNumProxies++;
      // else changing proxy
      pListMR[vEntryA].bits |= HAS_PROXY;
    }
    pListMR[vEntryA].proxyA = vProxyA;
    emit SetProxyV(vEntryA, vProxyA);
    return true;
  }

  // List.Issue()
  // ------------
  // Is called from Token.Issue() which is called from Sale.PresaleIssue() or Sale.Buy()
  function Issue(address toA, uint256 vPicos, uint256 vWei) external IsTokenCaller returns (bool) {
    require(pListMR[toA].addedT > 0, "Account not known"); // Entry is expected to exist
    require(pListMR[pSaleA].picosBalance >= vPicos, "Picos not available"); // Picos are available
    require(vPicos > 0, "Cannot issue 0 picos");  // Make sure not here for 0 picos re counts below
    if (pListMR[toA].picosBalance == 0) {
      if (pListMR[toA].firstContribT == 0) // first time for this entry
        pListMR[toA].firstContribT = uint32(now);
      if (pListMR[toA].whiteT > 0) // could be here for a presale issue not yet whitelisted in which case don't incr pNumMembers - that is done when entry is whitelisted
        pNumMembers++;
    }
    pListMR[toA].picosBought    = safeAdd(pListMR[toA].picosBought, vPicos);
    pListMR[toA].picosBalance   = safeAdd(pListMR[toA].picosBalance, vPicos);
    pListMR[toA].weiContributed = safeAdd(pListMR[toA].weiContributed, vWei);
    pListMR[toA].numContribs++;
    pListMR[pSaleA].picosBalance -= vPicos; // There is no need to check this for underflow via a safeSub() call given the pListMR[pSaleA].picosBalance >= vPicos check
    emit IssueV(toA, vPicos, vWei);
    return true;
  }

  // List.Transfer()
  // ---------------
  // Is called for all transfers including EIP20 ones
  function Transfer(address frA, address toA, uint256 value) external IsTransferOK(frA, toA, value) IsTokenCaller returns (bool success) {
    pListMR[frA].picosBalance -= value; // There is no need to check this for underflow via a safeSub() call given the IsTransferOK pListMR[frA].picosBalance >= value check
    pListMR[toA].picosBalance = safeAdd(pListMR[toA].picosBalance, value);
    if (value > 0 && pListMR[frA].picosBalance == 0) // value > 0 check because EIP-20 allows transfers of 0
      pNumMembers = subMaxZero(pNumMembers, 1);
    return true;
  }

  // List.TransferSaleContractBalance()
  // ----------------------------------------
  // Special transfer fn for the case of a new Sale being setup via manual call of the old Sale.NewSaleContract() -> Token.NewSaleContract() -> here
  // pSaleA is still the old Sale when this is called
  function TransferSaleContractBalance(address vNewSaleContractA) external IsTokenCaller returns (bool success) {
    pListMR[vNewSaleContractA].picosBalance = pListMR[pSaleA].picosBalance;
    pListMR[pSaleA].picosBalance = 0;
    return true;
  }

  // List.Burn()
  // -----------
  // For use when transferring issued PIOEs to PIOs
  // Is called by Mvp.Burn() -> Token.Burn() -> here thus use of tx.origin rather than msg.sender
  // There is no security risk associated with the use of tx.origin here as it is not used in any ownership/authorisation test
  // The event call is made by Mvp.Burn() where a Burn Id is updated and logged
  // Deployment Gas usage: 3142286. When done using pListMR[tx.origin] throughtout rather than the rsEntryR pointer, the deployment gas usage was more at 3143422. Presumably the gas usage would be less at run time too.
  function Burn() external IsTokenCaller {
    R_List storage rsEntryR = pListMR[tx.origin];
    require(rsEntryR.addedT > 0, "Account not known"); // Entry is expected to exist
    rsEntryR.bits |= BURNT;
    rsEntryR.picosBalance = 0;
    pNumBurnt++;
  }

  // List.Destroy()
  // --------------
  // For use when transferring unissued PIOEs to PIOs
  // Is called by Mvp.Destroy() -> Token.Destroy() -> here to destroy unissued Sale (pSaleA) picos
  // The event call is made by Mvp.Destroy()
  function Destroy(uint256 vPicos) external IsTokenCaller {
    require(pListMR[pSaleA].bits & ENTRY_CONTRACT > 0, "Not a contract list entry");
    pListMR[pSaleA].picosBalance = subMaxZero(pListMR[pSaleA].picosBalance, vPicos);
  }

  // List.Fallback function
  // ======================
  // No sending ether to this contract!
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the List contract other than via the defined methods with their testing for valid access
  }

} // End List contract
