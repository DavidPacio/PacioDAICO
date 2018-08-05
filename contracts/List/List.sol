/* \List\List.sol 2018.06.06 started

List of people/addresses to do with Pacio

Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Token

djh??
• burn refunded PIOs
• change refund to be on the basis of PIOs held
• From Marcell: I am for option c.) store the Eth, only send PIO if and when there is an account. And have a manual send back Eth process just in case.
- other owners e.g. voting contract?
- add vote count data

Member types -  see Constants.sol
None,       // 0 An undefined entry with no add date
Contract,   // 1 Contract (Sale) list entry for Minted tokens. Has dbId == 1
Grey,       // 2 Grey listed, initial default, not whitelisted, not contract, not presale, not refunded, not downgraded, not member
Presale,    // 3 Seed presale or private placement entry. Has LE_PRESALE_B bit set. whiteT is not set
Refunded,   // 4 Funds have been refunded at refundedT, either in full or in part if a Project Termination refund.
Downgraded, // 5 Has been downgraded from White or Member and refunded
White,      // 6 Whitelisted with no picosBalance
Member      // 7 Whitelisted with a picosBalance

Member info [Struct order is different to minimise slots used]
address nextEntryA;    // Address of the next entry     - 0 for the last  one
address prevEntryA;    // Address of the previous entry - 0 for the first one
address proxyA;        // Address of proxy for voting purposes
uint32  bits;          // Bit settings
uint32  addedT;        // Datetime when added
uint32  whiteT;        // Datetime when whitelisted
uint32  firstContribT; // Datetime when first contribution made. Can be a grey contribution
uint32  refundT;       // Datetime when refunded
uint32  downT;         // Datetime when downgraded
uint32  bonusCentiPc,  // Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
uint32  dbId;          // Id in DB for name and KYC info
uint32  contributions; // Number of separate contributions made
uint256 weiContributed;// wei contributed
uint256 weiRefunded;   // wei refunded
uint256 picosBought;   // Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
uint256 picosBalance;  // Current token balance - determines who is a Pacio Member |
*/

pragma solidity ^0.4.24;

import "../lib/OwnedList.sol";
import "../lib/Math.sol";
import "../lib/Constants.sol";
import "../OpMan/I_OpMan.sol";

contract List is OwnedList, Math {
  string  public  name = "Pacio DAICO Participants List";
  uint32  private pState;         // DAICO state using the STATE_ bits. Replicated from Hub on a change
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
  bool    private pTransfersOkB;  // false when sale is running = transfers are stopped by default but can be enabled manually globally or for particular members;
//bool    private pSoftCapB;      // Set to true when softcap is reached in Sale

  // Struct to hold member data, with a doubly linked list of List to permit traversing List
  // Each member requires 6 storage slots.
  struct R_List{        // Bytes Storage slot  Comment
    address nextEntryA;    // 20 0 Address of the next entry     - 0 for the last  one
    uint32  bits;          //  4 0 Bit settings
    uint32  addedT;        //  4 0 Datetime when added
    uint32  whiteT;        //  4 0 Datetime when whitelisted
    address prevEntryA;    // 20 1 Address of the previous entry - 0 for the first one
    uint32  firstContribT; //  4 1 Datetime when first contribution made. Can be a grey contribution.
    uint32  refundT;       //  4 1 Datetime when refunded
    uint32  downT;         //  4 1 Datetime when downgraded
    address proxyA;        // 20 2 Address of proxy for voting purposes
    uint32  bonusCentiPc;  //  4 2 Bonus percentage * 100 i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
    uint32  dbId;          //  4 2 Id in DB for name and KYC info
    uint32  contributions; //  4 2 Number of separate contributions made
    uint256 weiContributed;// 32 3 wei contributed
    uint256 weiRefunded;   // 32 4 wei refunded
    uint256 picosBought;   // 32 5 Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
    uint256 picosBalance;  // 32 6 Current token balance - determines who is a Pacio Member |
  }
  mapping (address => R_List) private pListMR; // Pacio List indexed by Ethereum account address

  // View Methods
  // ============
  function NumberOfListEntries() external view returns (uint256) {
    return pNumEntries;
  }
  function NumberOfGreyListEntries() external view returns (uint256) {
    return pNumGrey;
  }
  function NumberOfWhiteListEntries() external view returns (uint256) {
    return pNumWhite;
  }
  function NumberOfPacioMembers() external view returns (uint256) {
    return pNumMembers;
  }
  function NumberOfPresaleEntries() external view returns (uint256) {
    return pNumPresale;
  }
  function NumberOfMembersWithProxy() external view returns (uint256) {
    return pNumProxies;
  }
  function NumberOfRefunds() external view returns (uint256) {
    return pNumRefunded;
  }
  function NumberOfBurns() external view returns (uint256) {
    return pNumBurnt;
  }
  function NumberOfDowngrades() external view returns (uint256) {
    return pNumDowngraded;
  }
  function IsTransferAllowedByDefault() external view returns (bool) {
    return pTransfersOkB;
  }
  function IsTransferAllowed(address frA) private view returns (bool) {
    return (pTransfersOkB                           // Transfers can be made
         || (pListMR[frA].bits & LE_TRANSFER_OK_B) > 0); // or they are allowed for this member
  }
  function ListEntryExists(address accountA) external view returns (bool) {
    return pListMR[accountA].addedT > 0;
  }
  function WeiContributed(address accountA) external view returns (uint256) {
    return pListMR[accountA].weiContributed;
  }
  function WeiRefunded(address accountA) external view returns (uint256) {
    return pListMR[accountA].weiRefunded;
  }
  function PicosBalance(address accountA) external view returns (uint256) {
    return pListMR[accountA].picosBalance;
  }
  function PicosBought(address accountA) external view returns (uint256) {
    return pListMR[accountA].picosBought;
  }
  function BonusPcAndType(address accountA) external view returns (uint32 bonusCentiPc, uint8 typeN) {
    return (pListMR[accountA].bonusCentiPc, EntryType(accountA));
  }
  // List.EntryType()
  // ----------------
  // Returns the entry type of the accountA list entry as one of the LE_TYPE_ constants:
  // LE_TYPE_NONE       0 An undefined entry with no add date
  // LE_TYPE_CONTRACT   1 Contract (Sale) list entry for Minted tokens. Has dbId == 1
  // LE_TYPE_GREY       2 Grey listed, initial default, not whitelisted, not contract, not presale, not refunded, not downgraded, not member
  // LE_TYPE_PRESALE    3 Seed presale or internal placement entry. Has LE_PRESALE_B bit set. whiteT is not set
  // LE_TYPE_REFUNDED   4 Funds have been refunded at refundedT, either in full or in part if a Project Termination refund.
  // LE_TYPE_DOWNGRADED 5 Has been downgraded from White or Member and refunded
  // LE_TYPE_BURNT      6 Has been burnt
  // LE_TYPE_WHITE      7 Whitelisted with no picosBalance
  // LE_TYPE_MEMBER     8 Whitelisted with a picosBalance
  function EntryType(address accountA) public view returns (uint8 typeN) {
    R_List storage rsEntryR = pListMR[accountA];
    return rsEntryR.addedT == 0 ? LE_TYPE_NONE :
      (rsEntryR.bits & LE_BURNT_B > 0 ? LE_TYPE_BURNT :
        (rsEntryR.refundT > 0 ? LE_TYPE_REFUNDED :
         (rsEntryR.downT > 0 ? LE_TYPE_DOWNGRADED :
          (rsEntryR.whiteT > 0 ? (rsEntryR.picosBalance > 0 ? LE_TYPE_MEMBER : LE_TYPE_WHITE) :
           (rsEntryR.bits & LE_PRESALE_B > 0 ? LE_TYPE_PRESALE : (rsEntryR.dbId == 1 ? LE_TYPE_CONTRACT : LE_TYPE_GREY))))));
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
  function Browse(address currentA, uint8 vActionN) external view IsHubContractCaller returns (address retA, uint8 typeN) {
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
  function NextEntry(address accountA) external view IsHubContractCaller returns (address) {
    return pListMR[accountA].nextEntryA;
  }
  // List.PrevEntry()
  // ----------------
  // Requires Sender to be Hub
  function PrevEntry(address accountA) external view IsHubContractCaller returns (address) {
    return pListMR[accountA].prevEntryA;
  }
  // List.Proxy()
  // ------------
  // Requires Sender to be Hub
  function Proxy(address accountA) external view IsHubContractCaller returns (address) {
    return pListMR[accountA].proxyA;
  }
  // List.Lookup()
  // -------------
  // Returns information about the accountA list entry - all except for the addresses
  function Lookup(address accountA) external view returns (
    uint32  bits,          // Bit settings                                     /- All of R_List except for nextEntryA, prevEntryA, proxyA
    uint32  addedT,        // Datetime when added                              |
    uint32  whiteT,        // Datetime when whitelisted                        V
    uint32  firstContribT, // Datetime when first contribution made
    uint64  refundTnDownT, // refundT and downT packed because of stack overflow issues
    uint32  bonusCentiPc,  // Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
    uint32  dbId,          // Id in DB for name and KYC info
    uint32  contributions, // Number of separate contributions made
    uint256 weiContributed,// wei contributed
    uint256 weiRefunded,   // wei refunded
    uint256 picosBought,   // Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
    uint256 picosBalance) {// Current token balance - determines who is a Pacio Member |
    R_List storage rsEntryR = pListMR[accountA]; //  2,000,000,000   2000000000    Or could have used bit shifting.
                                                 //  1,527,066,000   1527066000 a current T 2018.05.23 09:00
                                                 //  3,054,132,001,527,066,000  for 2018.05.23 09:00 twice
                                                 // 18,446,744,073,709,551,615 max unsigned 64 bit int
    return (rsEntryR.bits, rsEntryR.addedT, rsEntryR.whiteT, rsEntryR.firstContribT, uint64(rsEntryR.refundT) * 2000000000 + uint64(rsEntryR.downT), rsEntryR.bonusCentiPc,
            rsEntryR.dbId, rsEntryR.contributions, rsEntryR.weiContributed, rsEntryR.weiRefunded, rsEntryR.picosBought, rsEntryR.picosBalance);
  }

  // Events
  // ======
  event StateChangeV(uint32 PrevState, uint32 NewState);
   event NewEntryV(address indexed Entry, uint32 Bits, uint32 DbId);
  event WhitelistV(address indexed Entry, uint32 WhitelistT);
  event DowngradeV(address indexed Entry, uint32 DowngradeT);
   event SetBonusV(address indexed Entry, uint32 bonusCentiPc);
   event SetProxyV(address indexed Entry, address Proxy);
  event SetTransfersOkByDefaultV(bool On);
  event SetTransferOkV(address indexed Entry, bool On);
  event IssueV(address indexed To, uint256 Picos, uint256 Wei);
  event RefundV(uint256 indexed RefundId, address indexed To, uint256 RefundPicos, uint256 RefundWei, uint32 Bit);
  event GreyDepositV(address indexed To, uint256 Wei);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Token
  // Owners must first be set by deploy script calls:
  //   List.ChangeOwnerMO(OP_MAN_OWNER_X  OpMan address)
  //   List.ChangeOwnerMO(HUB_OWNER_X,    Hub address)
  //   List.ChangeOwnerMO(SALE_OWNER_X,   Sale address)
  //   List.ChangeOwnerMO(TOKEN_OWNER_X,  Token address)

  // List.Initialise()
  // -----------------
  // To be called by the deploy script to set the contract address variables.
  function Initialise() external IsInitialising {
  //pSaleA = I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(SALE_CONTRACT_X);
    pSaleA = iOwnersYA[SALE_OWNER_X];
    iInitialisingB = false;
  }

  // List.StateChange()
  // ------------------
  // Called from Hub.pSetState() on a change of state to replicate the new state setting and take any required actions
  function StateChange(uint32 vState) external IsHubContractCaller {
    emit StateChangeV(pState, vState);
    pState = vState;
  }

  // List.StartSale()
  // -----------------
  // Called only from Hub.StartSale()
  function StartSale() external IsHubContractCaller {
    pTransfersOkB = false; // Stop transfers by default
  }

  // List.SetTransfersOkByDefault()
  // ------------------------------
  // Callable only from Hub to set/unset pTransfersOkB
  function SetTransfersOkByDefault(bool B) external IsHubContractCaller returns (bool) {
    if (B)
      require(pState & STATE_S_CAP_REACHED_B > 0, 'Requires Softcap');
    pTransfersOkB = B;
    emit SetTransfersOkByDefaultV(B);
    return true;
  }

  // List.SetTransferOk()
  // --------------------
  // Callable only from Hub to set LE_TRANSFER_OK_B bit of entry vEntryA on if B is true, or unset the bit if B is false
  function SetTransferOk(address vEntryA, bool B) external IsHubContractCaller returns (bool) {
    require(pListMR[vEntryA].addedT > 0, "Account not known"); // Entry is expected to exist
    if (B) // Set
      pListMR[vEntryA].bits |= LE_TRANSFER_OK_B;
    else   // Unset
      pListMR[vEntryA].bits &= ~LE_TRANSFER_OK_B;
    emit SetTransferOkV(vEntryA, B);
    return true;
  }

  // Modifier functions
  // ==================
  // IsTransferOK
  // ------------
  // Checks that both frA and toA exist; transfer from frA is ok; transfer to toA is ok (toA is whitelisted); and that frA has the tokens available
  // Also have an IsTransferOK modifier in EIP20Token
  modifier IsTransferOK(address frA, address toA, uint256 vPicos) {
    require(vPicos > 0                              // Non-zero transfer No! The EIP-20 std says: Note Transfers of 0 vPicoss MUST be treated as normal transfers and fire the Transfer event
      // && toA != frA                              // Destination is different from source. Not here. Is checked in calling fn.
         && pListMR[frA].addedT > 0                 // frA exists
         && pListMR[toA].whiteT > 0                 // toA exists and is whitelisted
         && (pTransfersOkB                          // Transfers can be made                /- ok to transfer from frA
          || (pListMR[frA].bits & LE_TRANSFER_OK_B) > 0) // or they are allowed for this member  |
         && pListMR[frA].picosBalance >= vPicos,    // frA has the picos available
            "Transfer not allowed");
    _;
  }

  // State changing methods
  // ======================

  // List.CreateListEntry()
  // ----------------------
  // Create a new list entry, and add it into the doubly linked list
  // Is called from Hub
  // 0 OpMan, 1 Hub, 2 Sale, 3 Token
  function CreateListEntry(address vEntryA, uint32 vBits, uint32 vDbId) external IsHubContractCaller returns (bool) {
    return pCreateEntry(vEntryA, vBits, vDbId);
  }

  // List.pCreateEntry() private
  // ------------------
  // Create a new list entry, and add it into the doubly linked list
  // Is called from Hub via List.CreateListEntry()
  //    and locally from CreateSaleContractEntry() and CreatePresaleEntry()
  // 0 Deployer, 1 OpMan, 2 Hub, 3 Token
  function pCreateEntry(address vEntryA, uint32 vBits, uint32 vDbId) private returns (bool) {
    require(vEntryA != address(0)     // Defined
         && vEntryA != iOwnersYA[OP_MAN_OWNER_X] // Not OpMan
         && vEntryA != iOwnersYA[HUB_OWNER_X]    // Not Hub
      // && vEntryA != pSaleA                    // Not Sale - No as we do create a Sale contract entry
         && vEntryA != iOwnersYA[TOKEN_OWNER_X]  // Not Token
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
      0,            // uint32  contributions; //  4 2 Number of separate contributions made
      0,            // uint256 weiContributed;// 32 3 wei contributed
      0,            // uint256 weiRefunded;   // 32 4 wei refunded
      0,            // uint256 picosBought;   // 32 5 Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
      0);           // uint256 picosBalance;  // 32 6 Current token balance - determines who is a Pacio Member |
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
  function CreateSaleContractEntry(uint256 vPicos) external IsTokenContractCaller returns (bool) {
    require(pCreateEntry(pSaleA, LE_TRANSFER_OK_B, 1)); // DbId of 1 assumed for Sale sale contract
    pListMR[pSaleA].picosBalance = vPicos;
    pNumGrey--;  // No need for subMaxZero(pNumGrey, 1) here as the pCreateEntry() call has just incremented this
    return true;
  }

  // List.CreatePresaleEntry()
  // -------------------------
  // Create a Seed Presale or Private Placement list entry, called from Hub.PresaleIssue()
  function CreatePresaleEntry(address vEntryA, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external IsHubContractCaller returns (bool) {
    require(pCreateEntry(vEntryA, LE_PRESALE_B, vDbId));
    pListMR[vEntryA].addedT        =
    pListMR[vEntryA].firstContribT = vAddedT; // firstContribT assumed to be the same as addedT for presale entries
    if (vNumContribs > 1)
      pListMR[vEntryA].contributions = vNumContribs - 1; // -1 because List.Issue() called subsequently will increment this
    pNumPresale++;
    return true;
  }

  // List.Whitelist()
  // ----------------
  // Whitelist an entry
  function Whitelist(address vEntryA, uint32 vWhiteT) external IsHubContractCaller returns (bool) {
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
  function Downgrade(address vEntryA, uint32 vDownT) external IsHubContractCaller returns (bool) {
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
  function SetBonus(address vEntryA, uint32 vBonusPc) external IsHubContractCaller returns (bool) {
    require(pListMR[vEntryA].addedT > 0, "Account not known"); // Entry is expected to exist
    pListMR[vEntryA].bonusCentiPc = vBonusPc;
    emit SetBonusV(vEntryA, vBonusPc);
    return true;
  }

  // List.SetProxy()
  // ---------------
  // Sets the proxy address of entry vEntryA to vProxyA plus updates bits and pNumProxies
  // vProxyA = 0x0 to unset or remove a proxy
  function SetProxy(address vEntryA, address vProxyA) external IsHubContractCaller returns (bool) {
    require(pListMR[vEntryA].addedT > 0, "Account not known"); // Entry is expected to exist
    if (vProxyA == address(0)) {
      // Unset or remove proxy
      if (pListMR[vEntryA].proxyA >= address(0)) {
        // Did have a proxy set
        pListMR[vEntryA].bits &= ~LE_HAS_PROXY_B; // rather than ^= LE_HAS_PROXY_B in case the LE_HAS_PROXY_B bit is wrongly not set
        pNumProxies = subMaxZero(pNumProxies, 1);
      }
    }else{
      // Set proxy
      if (pListMR[vEntryA].proxyA == address(0))
        // Didn't previously have one set
        pNumProxies++;
      // else changing proxy
      pListMR[vEntryA].bits |= LE_HAS_PROXY_B;
    }
    pListMR[vEntryA].proxyA = vProxyA;
    emit SetProxyV(vEntryA, vProxyA);
    return true;
  }

  // List.Issue()
  // ------------
  // Is called from Token.Issue() which is called from Sale.Buy() or Sale.PresaleIssue()
  //                                                   Sale.Buy() also calls Escrow.Deposit()
  function Issue(address toA, uint256 vPicos, uint256 vWei) external IsTokenContractCaller returns (bool) {
    uint8 typeN = EntryType(toA);
    require(typeN >= LE_TYPE_WHITE || typeN == LE_TYPE_PRESALE, "Invalid list type for issue"); // sender is White or Member or a presale contributor not yet white listed = ok to buy
    require(pListMR[pSaleA].picosBalance >= vPicos, "Picos not available"); // Check that the Picos are available
    require(vPicos > 0, "Cannot issue 0 picos");  // Make sure not here for 0 picos re counts below
    R_List storage rsEntryR = pListMR[toA];
    if (rsEntryR.weiContributed == 0) {
      rsEntryR.firstContribT = uint32(now);
      if (rsEntryR.whiteT > 0) // could be here for a presale issue not yet whitelisted in which case don't incr pNumMembers - that is done when entry is whitelisted
        pNumMembers++;
    }
    rsEntryR.picosBought    = safeAdd(rsEntryR.picosBought, vPicos);
    rsEntryR.picosBalance   = safeAdd(rsEntryR.picosBalance, vPicos);
    rsEntryR.weiContributed = safeAdd(rsEntryR.weiContributed, vWei);
    rsEntryR.contributions++;
    pListMR[pSaleA].picosBalance -= vPicos; // There is no need to check this for underflow via a safeSub() call given the pListMR[pSaleA].picosBalance >= vPicos check
    emit IssueV(toA, vPicos, vWei);
    return true;
  }

  // List.GreyDeposit()
  // ------------------
  // Is called from Sale.Buy() for grey funds being deposited
  //                Sale.Buy() also calls Grey.Deposit()
  function GreyDeposit(address toA, uint256 vWei) external IsSaleContractCaller returns (bool) {
    uint8 typeN = EntryType(toA);
    require(typeN == LE_TYPE_GREY, 'Invalid list type for Grey deposit');
    R_List storage rsEntryR = pListMR[toA];
    if (rsEntryR.weiContributed == 0)
      rsEntryR.firstContribT = uint32(now);
    rsEntryR.weiContributed = safeAdd(rsEntryR.weiContributed, vWei);
    rsEntryR.contributions++;
    emit GreyDepositV(toA, vWei);
    return true;
  }

  // List.Transfer()
  // ---------------
  // Is called for EIP20 transfers from EIP20Token.transfer() and EIP20Token.transferFrom()
  function Transfer(address frA, address toA, uint256 vPicos) external IsTransferOK(frA, toA, vPicos) IsTokenContractCaller returns (bool success) {
    pListMR[frA].picosBalance -= vPicos; // There is no need to check this for underflow via a safeSub() call given the IsTransferOK pListMR[frA].picosBalance >= vPicos check
    pListMR[toA].picosBalance = safeAdd(pListMR[toA].picosBalance, vPicos);
    if (vPicos > 0 && pListMR[frA].picosBalance == 0) // vPicos > 0 check because EIP-20 allows transfers of 0
      pNumMembers = subMaxZero(pNumMembers, 1);
    return true;
  }

  // List.TransferSaleContractBalance()
  // ----------------------------------------
  // Special transfer fn for the case of a new Sale being setup via manual call of the old Sale.NewSaleContract() -> Token.NewSaleContract() -> here
  // pSaleA is still the old Sale when this is called
  function TransferSaleContractBalance(address vNewSaleContractA) external IsTokenContractCaller returns (bool success) {
    pListMR[vNewSaleContractA].picosBalance = pListMR[pSaleA].picosBalance;
    pListMR[pSaleA].picosBalance = 0;
    return true;
  }

  // List.Refund()
  // -------------
  // Called from Token.Refund() IsHubContractCaller which is called from Hub.Refund()     IsNotContractCaller via Hub.pRefund()
  //                                                                  or Hub.PushRefund() IsWebOrAdminCaller  via Hub.pRefund()
  // vRefundWei can be less than or greater than List.WeiContributed() for termination case where the wei is a proportional calc based on picos held re transfers, not wei contributed
  function Refund(uint256 vRefundId, address toA, uint256 vRefundWei, uint32 vRefundBit) external IsTokenContractCaller returns (uint256 refundPicos)  {
    R_List storage rsEntryR = pListMR[toA];
    require(rsEntryR.addedT > 0, "Account not known"); // Entry is expected to exist
    uint8 typeN = EntryType(toA);
    if (vRefundBit >= LE_REFUND_GREY_S_CAP_MISS_B) {
      require(typeN == LE_TYPE_GREY, "Invalid list type for Grey Refund");
      require(rsEntryR.weiContributed == vRefundWei, "Invalid List Grey refund call");
    }else{
      require(typeN == LE_TYPE_PRESALE || typeN >= LE_TYPE_WHITE, "Invalid list type for Refund"); // sender is White or Member or a presale contributor not yet white listed = ok to buy
      refundPicos = rsEntryR.picosBalance;
      require(refundPicos > 0 && vRefundWei > 0, "Invalid List Escrow refund call");
      pListMR[pSaleA].picosBalance = safeAdd(pListMR[pSaleA].picosBalance, refundPicos);
      rsEntryR.picosBalance   = 0;
    }
    rsEntryR.refundT = uint32(now);
    rsEntryR.weiRefunded = vRefundWei; // No need to add as can come here only once since type -> LE_TYPE_REFUNDED after this
    rsEntryR.bits |= vRefundBit;                                       // LE_REFUND_ESCROW_S_CAP_MISS_B  Refund of all Escrow funds due to soft cap not being reached
    emit RefundV(vRefundId, toA, refundPicos, vRefundWei, vRefundBit); // LE_REFUND_ESCROW_TERMINATION_B Refund of remaining Escrow funds proportionately following a yes vote for project termination
    pNumRefunded++;                                                    // LE_REFUND_ESCROW_ONCE_OFF_B    Once off Escrow refund for whatever reason including downgrade from whitelisted
  }                                                                    // LE_REFUND_GREY_S_CAP_MISS_B    Refund of Grey escrow funds due to soft cap not being reached
                                                                       // LE_REFUND_GREY_SALE_CLOSE_B    Refund of Grey escrow funds that have not been white listed by the time that the sale closes. No need for a Grey termination case as sale must be closed before atermination vote can occur
                                                                       // LE_REFUND_GREY_ONCE_OFF_B      Once off Admin/Manual Grey escrow refund for whatever reason
  // List.Burn()
  // -----------
  // For use when transferring issued PIOEs to PIOs
  // Is called by Mvp.Burn() -> Token.Burn() -> here thus use of tx.origin rather than msg.sender
  // There is no security risk associated with the use of tx.origin here as it is not used in any ownership/authorisation test
  // The event call is made by Mvp.Burn() where a Burn Id is updated and logged
  // Deployment Gas usage: 3142286. When done using pListMR[tx.origin] throughtout rather than the rsEntryR pointer, the deployment gas usage was more at 3143422. Presumably the gas usage would be less at run time too.
  function Burn() external IsTokenContractCaller {
    R_List storage rsEntryR = pListMR[tx.origin];
    require(rsEntryR.addedT > 0, "Account not known"); // Entry is expected to exist
    rsEntryR.bits |= LE_BURNT_B;
    rsEntryR.picosBalance = 0;
    pNumBurnt++;
  }

  // List.Destroy()
  // --------------
  // For use when transferring unissued PIOs to the Pacio Blockchain
  // Is called by Mvp.Destroy() -> Token.Destroy() -> here to destroy unissued Sale (pSaleA) picos
  // The event call is made by Mvp.Destroy()
  function Destroy(uint256 vPicos) external IsTokenContractCaller {
    require(pListMR[pSaleA].bits & LE_TYPE_CONTRACT > 0, "Not a contract list entry");
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
