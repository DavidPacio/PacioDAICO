/* \List\List.sol 2018.06.06 started

List of people/addresses to do with Pacio

Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Token

djh??
- add vote count data

Member info [Struct order is different to minimise slots used]
address nextEntryA;    // Address of the next entry     - 0 for the last  one
address prevEntryA;    // Address of the previous entry - 0 for the first one
address proxyA;        // Address of proxy for voting purposes
uint32  bits;          // Bit settings
uint32  addedT;        // Datetime when added
uint32  whiteT;        // Datetime when whitelisted
uint32  firstContribT; // Datetime when first contribution made. Can be a prepurchase contribution
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
  uint256 private pNumEntries;    // Number of list entries        /- no pNum* counts for those effectively counted by Id i.e. RefundId, TransferToPbId
  uint256 private pNumPfund;      // Number of Pfund list entries  V
  uint256 private pNumWhite;      // Number of whitelist entries
  uint256 private pNumMembers;    // Number of Pacio members
  uint256 private pNumPresale;    // Number of presale list entries = seed presale and private placement entries
  uint256 private pNumProxies;    // Number of entries with a Proxy set
  uint256 private pNumDowngraded; // Number downgraded (from whitelist)
  address private pSaleA;         // the Sale contract address - only used as an address here i.e. don't need pSaleC
  bool    private pTransfersOkB;  // false when sale is running = transfers are stopped by default but can be enabled manually globally or for particular members;

// Struct to hold member data, with a doubly linked list of the List entries to permit traversing
// Each member requires 6 storage slots.
struct R_List{        // Bytes Storage slot  Comment
  address nextEntryA;    // 20 0 Address of the next entry     - 0 for the last  one
  uint32  bits;          //  4 0 Bit settings
  uint32  addedT;        //  4 0 Datetime when added
  uint32  whiteT;        //  4 0 Datetime when whitelisted
  address prevEntryA;    // 20 1 Address of the previous entry - 0 for the first one
  uint32  firstContribT; //  4 1 Datetime when first contribution made. Can be a prepurchase contribution.
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
  // List.DaicoState()  Should be the same as Hub.DaicoState()
  function DaicoState() external view returns (uint32) {
    return pState;
  }
  function NumberOfKnownAccounts() external view returns (uint256) {
    return pNumEntries;
  }
  function NumberOfManagedFundAccounts() external view returns (uint256) {
    return pNumEntries - pNumPfund; // Not the same as the number of with the LE_M_FUND_B bit set due to the sale contract entry plus dormant entries i.e. those whose picos have been transferred or refunded
  }
  function NumberOfPrepurchaseFundAccounts() external view returns (uint256) {
    return pNumPfund;
  }
  function NumberOfWhitelistEntries() external view returns (uint256) {
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
  function NumberOfWhitelistDowngrades() external view returns (uint256) {
    return pNumDowngraded;
  }
  function EntryBits(address accountA) external view returns (uint32) {
    return pListMR[accountA].bits;
  }
  function IsMember(address accountA) external view returns (bool) {
    return pListMR[accountA].bits & LE_MEMBER_B > 0;
  }
  function IsPrepurchase(address accountA) external view returns (bool) {
    return pListMR[accountA].bits & LE_P_FUND_B > 0;
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
  function BonusPcAndBits(address accountA) external view returns (uint32 bonusCentiPc, uint32 bits) {
    return (pListMR[accountA].bonusCentiPc, pListMR[accountA].bits);
  }
  function IsTransferFromAllowedByDefault() external view returns (bool) {
    return pTransfersOkB;
  }
  function IsTransferFromAllowed(address frA) external view returns (bool) {
    return (pTransfersOkB                                   // Transfers can be made
         || pListMR[frA].bits & LE_FROM_TRANSFER_OK_B > 0); // or they are allowed for this member
  }
  // List.Browse()
  // -------------
  // Returns address and type of the list entry being browsed to
  // Requires Sender to be Hub
  // Parameters:
  // - currentA  Address of the current entry, ignored for vActionN == First | Last
  // - vActionN { First, Last, Next, Prev} Browse action to be performed
  // Returns:
  // - retA   address of the list entry found, 0x0 if none with bits 0 too
  // - bits   bits of the entry
  // Note: Browsing for a particular type of entry is not implemented as that would involve looping -> gas problems.
  //       The calling app will need to do the looping if necessary, thus the return of bits.
  function Browse(address currentA, uint8 vActionN) external view IsHubContractCaller returns (address retA, uint32 bits) {
         if (vActionN == BROWSE_FIRST) retA = pFirstEntryA;
    else if (vActionN == BROWSE_LAST)  retA = pLastEntryA;
    else if (vActionN == BROWSE_NEXT)  retA = pListMR[currentA].nextEntryA;
    else                               retA = pListMR[currentA].prevEntryA; // Prev
    return (retA, pListMR[retA].bits); // retA 0x0 abd bits 0 at the end either going forwards or backwards
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
  event PrepurchaseDepositV(address indexed To, uint256 Wei);

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
  // Called from Hub.SetTransferOk to set LE_FROM_TRANSFER_OK_B bit of entry vEntryA on if B is true, or unset the bit if B is false
  function SetTransferOk(address vEntryA, bool B) external IsHubContractCaller returns (bool) {
    require(pListMR[vEntryA].bits > 0, 'Unknown account'); // Entry is expected to exist
    if (B) // Set
      pListMR[vEntryA].bits |= LE_FROM_TRANSFER_OK_B;
    else   // Unset
      pListMR[vEntryA].bits &= ~LE_FROM_TRANSFER_OK_B;
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
    R_List storage rsEntryR = pListMR[frA];  // the frA entry
    require(// vPicos > 0                    // Non-zero transfer No! The EIP-20 std says: Note Transfers of 0 vPicoss MUST be treated as normal transfers and fire the Transfer event
      // && toA != frA                       // Destination is different from source. Not here. Is checked in calling fn.
            rsEntryR.bits > 0                // frA exists
         && pListMR[toA].whiteT > 0          // toA exists and is whitelisted
         && (pTransfersOkB || rsEntryR.bits  // Transfers can be made                /- ok to transfer from frA
             & LE_FROM_TRANSFER_OK_B > 0)    // or they are allowed for this member  |
         && rsEntryR.picosBalance >= vPicos, // frA has the picos available
            "Transfer not allowed");
    _;
  }

  // State changing methods
  // ======================

  // List.CreateListEntry()
  // ----------------------
  // Create a new list entry, and add it into the doubly linked list
  // Is called from Hub.CreateListEntry()
  function CreateListEntry(address vEntryA, uint32 vBits, uint32 vDbId) external IsHubContractCaller returns (bool) {
    return pCreateEntry(vEntryA, vBits, vDbId);
  }

  // List.pCreateEntry() private
  // -------------------
  // Create a new list entry, and add it into the doubly linked list
  // Is called from Hub.CreateListEntry() -> List.CreateListEntry()         -> here to create a list entry for a new participant via web or admin
  //              Token.Initialise()      -> List.CreateSaleContractEntry() -> here to create the Sale contract list entry which holds the minted Picos. pSaleA is the Sale sale contract
  //              Token.NewSaleContract() -> List.CreateSaleContractEntry() -> here to create the new Sale contract list entry djh?? wip
  //                Hub.PresaleIssue()    -> CreatePresaleEntry()           -> here to create a Seed Presale or Private Placement list entry
  // Sets the LE_REGISTERED_B bit always so that bits for any entry which exists is > 0
  // Validity of vEntryA (defined and not any of the contracts or Admin) is checked by Hub.CreateListEntry() and Hub.PresaleIssue()
  // There is one exception for vEntryA being a contract which is for the Sale contract case for holding the minted PIOs, creatred via a List.CreateSaleContractEntry() call.
  function pCreateEntry(address vEntryA, uint32 vBits, uint32 vDbId) private returns (bool) {
    require(pListMR[vEntryA].bits == 0, "Account already exists"); // Require account not to already exist
    pListMR[vEntryA] = R_List(
      address(0),               // address nextEntryA;    // 20 0 Address of the next entry     - 0 for the last  one
      vBits |= LE_REGISTERED_B, // uint32  bits;          //  4 0 Bit settings
      uint32(now),              // uint32  addedT;        //  4 0 Datetime when added
      0,                        // uint32  whiteT;        //  4 0 Datetime when whitelisted
      pLastEntryA,              // address prevEntryA;    // 20 1 Address of the previous entry - 0 for the first one
      0,                        // uint32  firstContribT; //  4 1 Datetime when first contribution made
      0,                        // uint32  refundT;       //  4 1 Datetime when refunded
      0,                        // uint32  downT;         //  4 1 Datetime when downgraded
      0,                        // address proxyA;        // 20 2 Address of proxy for voting purposes
      0,                        // uint32  bonusCentiPc;  //  4 2 Bonus percentage * 100 i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
      vDbId,                    // uint32  dbId;          //  4 2 Id in DB for name and KYC info
      0,                        // uint32  contributions; //  4 2 Number of separate contributions made
      0,                        // uint256 weiContributed;// 32 3 wei contributed
      0,                        // uint256 weiRefunded;   // 32 4 wei refunded
      0,                        // uint256 picosBought;   // 32 5 Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
      0);                       // uint256 picosBalance;  // 32 6 Current token balance - determines who is a Pacio Member |
    // Update other state vars
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
  // Called from Token.Initialise() to create the Sale contract list entry which holds the minted Picos. pSaleA is the Sale contract
  // Called from Token.NewSaleContract() to create a new Sale contract list entry djh?? wip
  // Have a special transfer fn TransferSaleContractBalance() for the case of a new Sale contract  djh?? wip
  // Transfers from it are done for issuing PIOs so set LE_FROM_TRANSFER_OK_B
  // Transfers to it are done for refunds involving PIOs by List.Refund()
  function CreateSaleContractEntry(uint256 vPicos, uint32 vDbId) external IsTokenContractCaller returns (bool) {
    require(pCreateEntry(pSaleA, LE_SALE_CONTRACT_B | LE_PICOS_B | LE_FROM_TRANSFER_OK_B, vDbId));
    pListMR[pSaleA].picosBalance = vPicos;
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
  // Called from Hub.Whitelist() to whitelist an entry
  // Hub.Whitelist() carries on in the case of a Pfund not whitelisted account with sale open to issue the Picos and do a P to M transfer
  function Whitelist(address vEntryA, uint32 vWhiteT) external IsHubContractCaller returns (bool) {
    uint32 bitsToSet = LE_WHITELISTED_B;
    R_List storage rsEntryR = pListMR[vEntryA];
    require(rsEntryR.bits > 0, 'Unknown account'); // Entry is expected to exist
    if (rsEntryR.whiteT == 0) { // if not just changing the whitelist date then decrement prepurchases and incr white
      pNumWhite++;
      if (rsEntryR.picosBalance > 0) { // could be here for a presale entry with a balance now being whitelisted
        pNumMembers++;
        bitsToSet |= LE_MEMBER_B;
      }
    }
    if (rsEntryR.bits & LE_PRESALE_B > 0) {
      // Presale entry now whitelisted. Unset LE_PRESALE_B and set LE_WAS_PRESALE_B bits
      rsEntryR.bits &= ~LE_PRESALE_B;
      bitsToSet |= LE_WAS_PRESALE_B;
    }
    rsEntryR.whiteT = vWhiteT;
    rsEntryR.bits |= bitsToSet;
    emit WhitelistV(vEntryA, vWhiteT);
    return true;
  }

  // List.Downgrade()
  // ----------------
  // Downgrades an entry from whitelisted
  function Downgrade(address vEntryA, uint32 vDownT) external IsHubContractCaller returns (bool) {
    R_List storage rsEntryR = pListMR[vEntryA];
    require(rsEntryR.bits & LE_WHITELISTED_B > 0, 'Account not whitelisted'); // Entry is expected to exist and be whitelisted
    if (rsEntryR.downT == 0) { // if not just changing the downgrade date then decrement white and incr downgraded
      if (rsEntryR.bits & LE_MEMBER_B > 0)
        pNumMembers = subMaxZero(pNumMembers, 1);
      rsEntryR.bits &= ~LE_WHITELISTED_MEMBER_B; // unset LE_WHITELISTED_B and LE_MEMBER_B bits
      pNumWhite = subMaxZero(pNumWhite, 1);
      rsEntryR.bits |= LE_DOWNGRADED_B;
      pNumDowngraded++;
    }
    rsEntryR.downT = vDownT;
    emit DowngradeV(vEntryA, vDownT);
    return true;
  }

  // List.SetBonus()
  // ---------------
  // Sets bonusCentiPc Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
  function SetBonus(address vEntryA, uint32 vBonusPc) external IsHubContractCaller returns (bool) {
    require(pListMR[vEntryA].bits > 0, 'Unknown account'); // Entry is expected to exist
    pListMR[vEntryA].bonusCentiPc = vBonusPc;
    emit SetBonusV(vEntryA, vBonusPc);
    return true;
  }

  // List.SetProxy()
  // ---------------
  // Sets the proxy address of entry vEntryA to vProxyA plus updates bits and pNumProxies
  // vProxyA = 0x0 to unset or remove a proxy
  function SetProxy(address vEntryA, address vProxyA) external IsHubContractCaller returns (bool) {
    R_List storage rsEntryR = pListMR[vEntryA];
    require(rsEntryR.bits > 0, 'Unknown account'); // Entry is expected to exist
    bool proxySetB = rsEntryR.bits & LE_HAS_PROXY_B > 0;
    if (vProxyA == address(0)) {
      // Unset or remove proxy
      if (proxySetB) {
        // Did have a proxy set
        rsEntryR.bits ^= LE_HAS_PROXY_B; // unset the LE_HAS_PROXY_B bit which we know is set
        pNumProxies = subMaxZero(pNumProxies, 1);
      }
    }else{
      // Set proxy
      if (!proxySetB) {
        // Didn't previously have a proxy
        pNumProxies++;
        rsEntryR.bits |= LE_HAS_PROXY_B;
      }
    }
    rsEntryR.proxyA = vProxyA;
    emit SetProxyV(vEntryA, vProxyA);
    return true;
  }

  // List.Issue()
  // ------------
  // Cases:
  // a. Hub.PresaleIssue() -> Sale.PresaleIssue()                                 -> Token.Issue() -> here for all Seed Presale and Private Placement pContributors (aggregated)
  // b. Sale.Buy()                                                 -> Sale.pBuy() -> Token.Issue() -> here for normal buying
  // c. Hub.Whitelist()  -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pBuy() -> Token.Issue() -> here for Pfund to Mfund transfers on whitelisting
  // d. Hub.PMtransfer() -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pBuy() -> Token.Issue() -> here for Pfund to Mfund transfers for an entry which was whitelisted and ready prior to opening of the sale which has now happened
  function Issue(address toA, uint256 vPicos, uint256 vWei) external IsTokenContractCaller returns (bool) {
    R_List storage rsEntryR = pListMR[toA];
    uint32 bits = rsEntryR.bits;
    uint32 bitsToSet = LE_M_FUND_B | LE_PICOS_B;
    require(bits > 0 && bits & LE_NO_SEND_FUNDS_COMBO_B == 0 && bits & LE_WHITELISTED_B > 0); // already checked by Sale.Buy() so expected to be ok
    require(pListMR[pSaleA].picosBalance >= vPicos, "Picos not available"); // Check that the Picos are available
    require(vPicos > 0, "Cannot issue 0 picos");  // Make sure not here for 0 picos re counts below
    if (bits & LE_P_FUND_B > 0) {
      // Cases c and d Pfund to Mfund transfers
      // c. Hub.Whitelist()  -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pBuy() -> Token.Issue() -> here for Pfund to Mfund transfers on whitelisting
      // d. Hub.PMtransfer() -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pBuy() -> Token.Issue() -> here for Pfund to Mfund transfers for an entry which was whitelisted and ready prior to opening of the sale which has now happened
      // List.PrepurchaseDeposit() has been run so firstContribT, pNumPfund, weiContributed, contributions have been updated and the LE_P_FUND_B bit set
      rsEntryR.bits &= ~LE_P_FUND_B;        // unset the Pfund bit
      pNumPfund = subMaxZero(pNumPfund, 1); // decrement pNumPfund
    }else{
      // Cases a and b
      // a. Hub.PresaleIssue() -> Sale.PresaleIssue() -> Token.Issue() -> here for all Seed Presale and Private Placement pContributors (aggregated)
      // b. Sale.Buy()         -> Sale.pBuy()         -> Token.Issue() -> here for normal buying
      if (rsEntryR.weiContributed == 0) {
        rsEntryR.firstContribT = uint32(now);
        if (rsEntryR.whiteT > 0) { // case b
          bitsToSet |= LE_MEMBER_B;
          pNumMembers++;
        } // else case a here for a presale issue not yet whitelisted in which case don't set LE_MEMBER_B or incr pNumMembers - that is done when entry is whitelisted
      }
      rsEntryR.weiContributed = safeAdd(rsEntryR.weiContributed, vWei);
      rsEntryR.contributions++;
    }
    // All cases
    rsEntryR.bits        |= bitsToSet;
    rsEntryR.picosBought  = safeAdd(rsEntryR.picosBought, vPicos);
    rsEntryR.picosBalance = safeAdd(rsEntryR.picosBalance, vPicos);
    pListMR[pSaleA].picosBalance -= vPicos; // There is no need to check this for underflow via a safeSub() call given the pListMR[pSaleA].picosBalance >= vPicos check
    return true;                            // Should never go to zero for the Pacio DAICO given reserves held
    // Token.Issue() emits an IssueV() event
  }

  // List.PrepurchaseDeposit()
  // -------------------------
  // Is called from Sale.Buy() for prepurchase funds being deposited
  //   In this case Sale.Buy() also calls Pfund.Deposit()
  function PrepurchaseDeposit(address toA, uint256 vWei) external IsSaleContractCaller returns (bool) {
    R_List storage rsEntryR = pListMR[toA];
    uint32 bits = rsEntryR.bits;
    require(bits > 0 && bits & LE_NO_SEND_FUNDS_COMBO_B == 0 && (bits & LE_WHITELISTED_B == 0 || pState & STATE_PRIOR_TO_OPEN_B > 0)); // already checked by Sale.Buy() so expected to be ok
    if (rsEntryR.weiContributed == 0) {
      rsEntryR.firstContribT = uint32(now);
      pNumPfund++;
    }
    rsEntryR.weiContributed = safeAdd(rsEntryR.weiContributed, vWei);
    rsEntryR.contributions++;
    rsEntryR.bits |= LE_P_FUND_B; // means funded too
    emit PrepurchaseDepositV(toA, vWei);
    return true;
  }

  // List.Transfer()
  // ---------------
  // Is called for EIP20 transfers from EIP20Token.transfer() and EIP20Token.transferFrom()
  function Transfer(address frA, address toA, uint256 vPicos) external IsTransferOK(frA, toA, vPicos) IsTokenContractCaller returns (bool success) {
    // From
    R_List storage rsEntryR = pListMR[frA];
    if ((rsEntryR.picosBalance -= vPicos) == 0) { // There is no need to check this for underflow via a safeSub() call given the IsTransferOK pListMR[frA].picosBalance >= vPicos check
      // frA now has no picos
      if (rsEntryR.bits & LE_MEMBER_B > 0)
        pNumMembers = subMaxZero(pNumMembers, 1);
      rsEntryR.bits &= ~LE_M_FUND_PICOS_MEMBER_B; // unset the toA LE_M_FUND_PICOS_MEMBER_B, LE_PICOS_B and LE_MEMBER_B bits
    }
    // To
    rsEntryR = pListMR[toA];
    // toA becomes a member because it has picos and it must be whitelisted for IsTransferOK() to pass
    rsEntryR.picosBalance = safeAdd(rsEntryR.picosBalance, vPicos);
    rsEntryR.bits |= LE_M_FUND_PICOS_MEMBER_B; // set the toA LE_M_FUND_B, LE_PICOS_B and LE_MEMBER_B bits
    pNumMembers++;
    return true;
  }

  // // List.TransferSaleContractBalance()  djh?? wip
  // // ----------------------------------
  // // Special transfer fn for the case of a new Sale being setup via manual call of the old Sale.NewSaleContract() -> Token.NewSaleContract() -> here
  // // pSaleA is still the old Sale when this is called
  // function TransferSaleContractBalance(address vNewSaleContractA) external IsTokenContractCaller returns (bool success) {
  //   pListMR[vNewSaleContractA].picosBalance = pListMR[pSaleA].picosBalance;
  //   pListMR[pSaleA].picosBalance = 0;
  //   return true;
  // }

  // List.Refund()
  // -------------
  // Called from Token.Refund() IsHubContractCaller which is called from Hub.Refund()     IsNotContractCaller via Hub.pRefund()
  //                                                                  or Hub.PushRefund() IsWebOrAdminCaller  via Hub.pRefund()
  // vRefundWei can be less than or greater than List.WeiContributed() for termination case where the wei is a proportional calc based on picos held re transfers, not wei contributed
  // Refunded PIOs are transferred back to the Sale contract account. They are not burnt or destroyed.
  function Refund(address toA, uint256 vRefundWei, uint32 vRefundBit) external IsTokenContractCaller returns (uint256 refundPicos)  {
    R_List storage rsEntryR = pListMR[toA];
    uint32 bits = rsEntryR.bits;
    require(bits > 0 && bits & LE_NO_REFUND_COMBO_B == 0); // Already checked by Hub.pRefund() so expected to be ok
    if (vRefundBit >= LE_P_REFUND_S_CAP_MISS_B) {
      // Pfund refundBit
      require(bits & LE_P_FUND_B > 0, "Invalid list type for Prepurchase Refund");
      require(rsEntryR.weiContributed == vRefundWei, "Invalid List Prepurchase Refund call");
      rsEntryR.bits &= ~LE_P_FUND_B;        // unset the prepurchase bit
      pNumPfund = subMaxZero(pNumPfund, 1); // decrement pNumPfund
    }else{
      // Mfund refund bit
      require(bits & LE_PICOS_B > 0, "Invalid list type for Refund");
      refundPicos = rsEntryR.picosBalance;
      require(refundPicos > 0 && vRefundWei > 0, "Invalid Mfund refund call");
      pListMR[pSaleA].picosBalance = safeAdd(pListMR[pSaleA].picosBalance, refundPicos); // transfer the Picos back to the sale contract. Token.Refund() emits a Transfer() event for this.
      rsEntryR.picosBalance = 0;
      if (bits & LE_MEMBER_B > 0)
        pNumMembers = subMaxZero(pNumMembers, 1);
      rsEntryR.bits &= ~LE_M_FUND_PICOS_MEMBER_B; // unset the frA LE_M_FUND_B, LE_PICOS_B and LE_MEMBER_B bits
    }
    rsEntryR.refundT = uint32(now);
    rsEntryR.weiRefunded = vRefundWei; // No need to add as can come here only once since will fail LE_NO_REFUND_COMBO_B after thids
    rsEntryR.bits |= vRefundBit;
    // Token.Refund() emits RefundV(vRefundId, toA, refundPicos, vRefundWei, vRefundBit);
  }

  // List.TransferIssuedPIOsToPacioBc()
  // ------------------------------------------
  // For use when transferring issued PIOs to the Pacio blockchain
  // Is called by Token.TransferIssuedPIOsToPacioBc()
  function TransferIssuedPIOsToPacioBc(address accountA) external IsTokenContractCaller {
    R_List storage rsEntryR = pListMR[accountA];
    require(pState & STATE_TRANSFER_TO_PB_B > 0 // /- also checked by Token.TransferIssuedPIOsToPacioBc() so no fail msg
         && rsEntryR.bits > 0);                 // |
    rsEntryR.picosBalance = 0;
    rsEntryR.bits |= LE_TRANSFERRED_TO_PB_B;
    if (rsEntryR.bits & LE_MEMBER_B > 0)    pNumMembers = subMaxZero(pNumMembers, 1);
    if (rsEntryR.bits & LE_HAS_PROXY_B > 0) pNumProxies = subMaxZero(pNumProxies, 1);
    rsEntryR.bits &= ~LE_M_FUND_PICOS_MEMBER_B; // unset the frA LE_M_FUND_B, LE_PICOS_B and LE_MEMBER_B bits
    // Token.TransferIssuedPIOsToPacioBc() emits TransferIssuedPIOsToPacioBcV(++pTransferToPbId, accountA, picos);
  }

  // List.TransferUnIssuedPIOsToPacioBc()
  // ------------------------------------
  // For use when transferring unissued PIOs to the Pacio Blockchain to decrement the Sale contract store of minted PIOs
  // Is called by Token.TransferUnIssuedPIOsToPacioBc() -> here to decrement unissued Sale (pSaleA) picos
  function TransferUnIssuedPIOsToPacioBc(uint256 vPicos) external IsTokenContractCaller {
    require(pState & STATE_TRANSFERRED_TO_PB_B > 0); // also checked by Token.TransferUnIssuedPIOsToPacioBcMO() so no fail msg
    R_List storage rsEntryR = pListMR[pSaleA];
    require(rsEntryR.bits & LE_SALE_CONTRACT_B > 0, "Not the Sale contract list entry");
    if ((rsEntryR.picosBalance = subMaxZero(rsEntryR.picosBalance, vPicos)) == 0)
      rsEntryR.bits &= ~LE_PICOS_B; // unset the LE_PICOS_B bit
  }

  // List.Fallback function
  // ======================
  // No sending ether to this contract!
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the List contract other than via the defined methods with their testing for valid access
  }

} // End List contract
