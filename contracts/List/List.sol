/* \List\List.sol 2018.06.06 started

List of people/addresses to do with Pacio

Owned by Deployer OpMan Hub Token Sale Poll
*/

pragma solidity ^0.4.24;

import "../lib/OwnedList.sol";
import "../lib/Math.sol";
import "../lib/Constants.sol";

contract List is OwnedList, Math {
  string  public  name = "Pacio DAICO Participants List";
  uint32  private pState;         // DAICO state using the STATE_ bits. Replicated from Hub on a change
  address private pFirstEntryA;   // Address of first entry
  address private pLastEntryA;    // Address of last entry
  uint32  private pNumEntries;    // Number of list entries        /- no pNum* counts for those effectively counted by Id i.e. RefundId, TransferToPbId
  uint32  private pNumPfund;      // Number of Pfund list entries  V
  uint32  private pNumWhite;      // Number of whitelist entries
  uint32  private pNumMembers;    // Number of Pacio members
  uint32  private pNumPresale;    // Number of presale list entries = seed presale and private placement entries
  uint32  private pNumProxyAppointers; // Number of proxy appointers oe entries with a proxy appointed. Isn't members as a non-member can appoint a proxy in anticipation of becoming a member
  uint32  private pNumProxies;    // Number of proxy members or proxy appointees
  uint32  private pNumDowngraded; // Number downgraded (from whitelist)
  uint256 private pMaxPicosVote;  // Maximum vote in picos for a member = Sale.pPicoHardCap * Poll.pMaxVoteHardCapCentiPc / 100
  address private pSaleA;         // the Sale contract address - only used as an address here i.e. don't need C form here
  bool    private pTransfersOkB;  // false when sale is running = transfers are stopped by default but can be enabled manually globally or for particular members;

// Struct to hold member data, with a doubly linked list of the List entries to permit traversing
// Each entry uses 8 storage slots.
struct R_List {   // Bytes Storage slot  Comment
  address nextEntryA;        // 20 0 Address of the next entry     - 0 for the last  one
  uint32  bits;              //  4 0 Bit settings
  uint32  addedT;            //  4 0 Datetime when added
  uint32  whiteT;            //  4 0 Datetime when whitelisted
  address prevEntryA;        // 20 1 Address of the previous entry - 0 for the first one
  uint32  firstContribT;     //  4 1 Datetime when first contribution made. Can be a prepurchase contribution.
  uint32  refundT;           //  4 1 Datetime when refunded
  uint32  downT;             //  4 1 Datetime when downgraded
  address proxyA;            // 20 2 Address of proxy for voting purposes
  uint32  bonusCentiPc;      //  4 2 Bonus percentage * 100 i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
  uint32  dbId;              //  4 2 Id in DB for name and KYC info
  uint32  contributions;     //  4 2 Number of separate contributions made
  uint256 weiContributed;    // 32 3 wei contributed
  uint256 weiRefunded;       // 32 4 wei refunded
  uint256 picosBought;       // 32 5 Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
  uint256 picosBalance;      // 32 6 Current token balance - determines who is a Pacio Member |
  uint32  numProxyVotesFor;  //  4 7 Number of entries who have appointed this member as proxy i.e. the count of how many entries this member is a proxy for
  uint32  pioVotesDelegated; //  4 7 Pio votes delegated if entry has appointed a proxy            /- an entry can have both set   --- set by     pUpdateProxyData()
  uint32  sumVotesDelegated; //  4 7 Sum of pio votes delegated by appointers if entry is a proxy  |                               --- updated by pUpdateProxyData()
  uint32  numTimesVoted;     //  4 7 Number of non-revoked times a member has voted (Must be a member to vote)
  uint32  voteT;             //  4 7 Time of vote             /- last vote. Previous vote info available via log
  uint32  piosVoted;         //  4 7 Pios voted               |
  uint32  pollId;            //  4 7 Id of last poll voted in |
  uint8   voteN;             //  1 7 VoteN                    |
}
mapping (address => R_List) private pListMR; // Pacio List indexed by Ethereum account address

  // View Methods
  // ============
  // List.DaicoState()  Should be the same as Hub.DaicoState()
  function DaicoState() external view returns (uint32) {
    return pState;
  }
  function NumberOfKnownAccounts() external view returns (uint32) {
    return pNumEntries;
  }
  function NumberOfManagedFundAccounts() external view returns (uint32) {
    return pNumEntries - pNumPfund; // Not the same as the number of with the LE_M_FUND_B bit set due to the sale contract entry plus dormant entries i.e. those whose picos have been transferred or refunded
  }
  function NumberOfPrepurchaseFundAccounts() external view returns (uint32) {
    return pNumPfund;
  }
  function NumberOfWhitelistEntries() external view returns (uint32) {
    return pNumWhite;
  }
  function NumberOfPacioMembers() external view returns (uint32) {
    return pNumMembers;
  }
  function NumberOfProxyAppointers() external view returns (uint32) {
    return pNumProxyAppointers;
  }
  function NumberOfProxyMembers() external view returns (uint32) {
    return pNumProxies;
  }
  function NumberOfPresaleEntries() external view returns (uint32) {
    return pNumPresale;
  }
  function NumberOfWhitelistDowngrades() external view returns (uint32) {
    return pNumDowngraded;
  }
  function MaxPiosVotePerMember() external view returns (uint32) {
    return uint32(pMaxPicosVote / 10**12);
  }
  function EntryBits(address entryA) external view returns (uint32) {
    return pListMR[entryA].bits;
  }
  function IsMember(address entryA) public view returns (bool) {
    return pListMR[entryA].bits & LE_MEMBER_B > 0;
  }
  function IsPrepurchase(address entryA) external view returns (bool) {
    return pListMR[entryA].bits & LE_P_FUND_B > 0;
  }
  function WeiContributed(address entryA) external view returns (uint256) {
    return pListMR[entryA].weiContributed;
  }
  function PicosBalance(address entryA) external view returns (uint256) {
    return pListMR[entryA].picosBalance;
  }
  function PicosBought(address entryA) external view returns (uint256) {
    return pListMR[entryA].picosBought;
  }
  function WeiRefunded(address entryA) external view returns (uint256) {
    return pListMR[entryA].weiRefunded;
  }
  function ProxyAppointed(address entryA) external view returns (address) {
    return pListMR[entryA].proxyA;
  }
  function BonusPcAndBits(address entryA) external view returns (uint32 bonusCentiPc, uint32 bits) {
    return (pListMR[entryA].bonusCentiPc, pListMR[entryA].bits);
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
  function NextEntry(address entryA) external view IsHubContractCaller returns (address) {
    return pListMR[entryA].nextEntryA;
  }
  // List.PrevEntry()
  // ----------------
  // Requires Sender to be Hub
  function PrevEntry(address entryA) external view IsHubContractCaller returns (address) {
    return pListMR[entryA].prevEntryA;
  }
  // List.Lookup()
  // -------------
  // Returns information about the entryA list entry - all except for the addresses and polling/proxy info
  function Lookup(address entryA) external view returns (
    uint32  bits,          // Bit settings                                     /- All of R_List except for nextEntryA, prevEntryA, and proxyA/poll stuff
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
    R_List storage rsEntryR = pListMR[entryA]; //  2,000,000,000   2000000000    Or could have used bit shifting.
                                               //  1,527,066,000   1527066000 a current T 2018.05.23 09:00
                                               //  3,054,132,001,527,066,000  for 2018.05.23 09:00 twice
                                               // 18,446,744,073,709,551,615 max unsigned 64 bit int
    return (rsEntryR.bits, rsEntryR.addedT, rsEntryR.whiteT, rsEntryR.firstContribT, uint64(rsEntryR.refundT) * 2000000000 + uint64(rsEntryR.downT), rsEntryR.bonusCentiPc,
            rsEntryR.dbId, rsEntryR.contributions, rsEntryR.weiContributed, rsEntryR.weiRefunded, rsEntryR.picosBought, rsEntryR.picosBalance);
  }
  // List.LookupPollInfo()
  // ---------------------
  // Returns polling and proxy information about the entryA list entry
  function LookupPollInfo(address entryA) external view returns (
    uint32  bits,              // Bit settings
    address proxyA,            // Address of proxy for voting purposes
    uint32  numProxyVotesFor,  // Number of entries who have appointed this member as proxy i.e. the count of how many entries this member is a proxy for
    uint32  pioVotesDelegated, // Pio votes delegated if entry has appointed a proxy            /- an entry can have both set   --- set by     pUpdateProxyData()
    uint32  sumVotesDelegated, // Sum of pio votes delegated by appointers if entry is a proxy  |                               --- updated by pUpdateProxyData()
    uint32  numTimesVoted,     // Number of non-revoked times a member has voted (Must be a member to vote)
    uint32  voteT,             //  4 7 Time of vote             /- last vote. Previous vote info available via log
    uint32  piosVoted,         //  4 7 Pios voted               |
    uint32  pollId,            //  4 7 Id of last poll voted in |
    uint8   voteN) {           //  1 7 VoteN                    |
    R_List storage rsEntryR = pListMR[entryA];
    return (rsEntryR.bits, rsEntryR.proxyA, rsEntryR.numProxyVotesFor, rsEntryR.pioVotesDelegated, rsEntryR.sumVotesDelegated, rsEntryR.numTimesVoted, rsEntryR.voteT, rsEntryR.piosVoted, rsEntryR.pollId, rsEntryR.voteN);
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
  event UpdateProxyAppointerV(address indexed Entry, uint32 OldPioVotesDelegated, uint32 NewPioVotesDelegated, uint32 NumberWithProxyAppointed);
  event          UpdateProxyV(address indexed Proxy, uint32 OldSumVotesDelegated, uint32 NewSumVotesDelegated, uint32 OldNumProxyVotesFor, uint32 NewNumProxyVotesFor, uint32 NumProxies);
  event VoteV(address indexed Voter, uint32 PollId, uint8 VoteN, uint32 PiosVoted, uint32 NumMembersVotedFor, uint8 VoteRevokedN);
  event SetListEntryBitsV(address indexed Entry, uint32 BitsToSet, bool UnsetB, uint32 BitsBefore, uint32 BitsAfter);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by Deployer Poll Hub Token Sale
  // Owners must first be set by deploy script calls:
  //   List.SetOwnerIO(LIST_POLL_OWNER_X, Poll address)
  //   List.SetOwnerIO(HUB_OWNER_X,   Hub address)
  //   List.SetOwnerIO(TOKEN_OWNER_X, Token address)
  //   List.SetOwnerIO(SALE_OWNER_X,  Sale address)

  // List.Initialise()
  // -----------------
  // To be called by the deploy script to set the contract address variable.
  function Initialise() external IsInitialising {
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
  function SetTransfersOkByDefault(bool B) external IsHubContractCaller {
    if (B)
      require(pState & STATE_S_CAP_REACHED_B > 0, 'Requires Softcap');
    pTransfersOkB = B;
    emit SetTransfersOkByDefaultV(B);
  }

  // Modifier functions
  // ==================
  // IsTransferOK
  // ------------
  // Checks that both frA and toA exist; transfer from frA is ok; state does not prohibit transfers; transfers are not prohibited from frA; transfer to toA is ok (toA is whitelisted); and that frA has the tokens available
  // Also have an IsTransferOK modifier in EIP20Token
  modifier IsTransferOK(address frA, address toA, uint256 vPicos) {
    R_List storage rsEntryR = pListMR[frA];        // the frA entry
    uint32 bits = rsEntryR.bits;
    require(// vPicos > 0                          // Non-zero transfer No! The EIP-20 std says: Note Transfers of 0 vPicoss MUST be treated as normal transfers and fire the Transfer event
      // && toA != frA                             // Destination is different from source. Not here. Is checked in calling fn.
            bits > 0                               // frA exists
         && pState & STATE_TRANS_ISSUES_NOK_B == 0 // State does not prohibit transfers
         && bits & LE_TRANSFERS_NOK_B == 0         // transfers are not prohibited from frA
         && pListMR[toA].whiteT > 0                // toA exists and is whitelisted
         && (pTransfersOkB || bits & LE_FROM_TRANSFER_OK_B > 0) // Transfers can be made or they are allowed for this entry
         && rsEntryR.picosBalance >= vPicos,       // frA has the picos available
            "Transfer not allowed");
    _;
  }

  // State changing methods
  // ======================

  // List.CreateListEntry()
  // ----------------------
  // Create a new list entry, and add it into the doubly linked list
  // Is called from Hub.CreateListEntry()
  function CreateListEntry(address entryA, uint32 vBits, uint32 vDbId) external IsHubContractCaller returns (bool) {
    return pCreateEntry(entryA, vBits, vDbId);
  }

  // List.pCreateEntry() private
  // -------------------
  // Create a new list entry, and add it into the doubly linked list
  // Is called from Hub.CreateListEntry() -> List.CreateListEntry()         -> here to create a list entry for a new participant via web or admin
  //                Hub.PresaleIssue()    -> CreatePresaleEntry()           -> here to create a Seed Presale or Private Placement list entry
  //              Token.Initialise()      -> List.CreateSaleContractEntry() -> here to create the Sale contract list entry which holds the minted Picos. pSaleA is the Sale sale contract
  //              Token.NewSaleContract() -> List.NewSaleContract()         -> here to create the new Sale contract list entry
  // Sets the LE_REGISTERED_B bit always so that bits for any entry which exists is > 0
  // Validity of entryA (defined and not any of the contracts or Admin) is checked by Hub.CreateListEntry() and Hub.PresaleIssue()
  // There is one exception for entryA being a contract which is for the Sale contract case for holding the minted PIOs, creatred via a List.CreateSaleContractEntry() call.
  function pCreateEntry(address entryA, uint32 vBits, uint32 vDbId) private returns (bool) {
    require(pListMR[entryA].bits == 0, "Account already exists"); // Require account not to already exist
    pListMR[entryA] = R_List(
      address(0),               // address nextEntryA;        // 20 0 Address of the next entry     - 0 for the last  one
      vBits |= LE_REGISTERED_B, // uint32  bits;              //  4 0 Bit settings
      uint32(now),              // uint32  addedT;            //  4 0 Datetime when added
      0,                        // uint32  whiteT;            //  4 0 Datetime when whitelisted
      pLastEntryA,              // address prevEntryA;        // 20 1 Address of the previous entry - 0 for the first one
      0,                        // uint32  firstContribT;     //  4 1 Datetime when first contribution made
      0,                        // uint32  refundT;           //  4 1 Datetime when refunded
      0,                        // uint32  downT;             //  4 1 Datetime when downgraded
      0,                        // address proxyA;            // 20 2 Address of proxy for voting purposes
      0,                        // uint32  bonusCentiPc;      //  4 2 Bonus percentage * 100 i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
      vDbId,                    // uint32  dbId;              //  4 2 Id in DB for name and KYC info
      0,                        // uint32  contributions;     //  4 2 Number of separate contributions made
      0,                        // uint256 weiContributed;    // 32 3 wei contributed
      0,                        // uint256 weiRefunded;       // 32 4 wei refunded
      0,                        // uint256 picosBought;       // 32 5 Tokens bought/purchased                                  /- picosBought - picosBalance = number transferred or number refunded if refundT is set
      0,                        // uint256 picosBalance;      // 32 6 Current token balance - determines who is a Pacio Member |
      0,                        // uint32  numProxyVotesFor;  //  4 7 Number of entries who have appointed this member as proxy i.e. the count of how many entries this member is a proxy for
      0,                        // uint32  pioVotesDelegated; //  4 7 Pio votes delegated if entry has appointed a proxy            /- an entry can have both set
      0,                        // uint32  sumVotesDelegated; //  4 7 Sum of pio votes delegated by appointers if entry is a proxy  |
      0,                        // uint32  numTimesVoted;     //  4 7 Number of non-revoked times a member has voted (Must be a member to vote)
      0,                        // uint32  voteT;             //  4 7 Time of last vote
      0,                        // uint32  piosVoted;         //  4 7 Pios voted in last vote
      0,                        // uint32  pollId;            //  4 7 Id of last poll voted in
      0);                       // uint8   voteN;             //  1 7 VoteN of last vote
// Update other state vars
    if (++pNumEntries == 1) // Number of list entries
      pFirstEntryA = entryA;
    else
      pListMR[pLastEntryA].nextEntryA = entryA;
    pLastEntryA = entryA;
    emit NewEntryV(entryA, vBits, vDbId);
    return true;
  }

  // List.CreateSaleContractEntry()
  // ------------------------------
  // Called from Token.Initialise() to create the Sale contract list entry which holds the minted Picos. pSaleA is the Sale contract
  // Called from Token.NewSaleContract() to create a new Sale contract list entry
  // Have a special transfer fn TransferSaleContractBalance() for the case of a new Sale contract  djh?? wip
  // Transfers from it are done for issuing PIOs so set LE_FROM_TRANSFER_OK_B
  // Transfers to it are done for refunds involving PIOs by List.Refund()
  function CreateSaleContractEntry(uint256 vPicos) external IsTokenContractCaller returns (bool) {
    require(pCreateEntry(pSaleA, LE_SALE_CON_PICOS_FR_TRAN_OK_B, 1)); // assuming 1 for Sale contract Db ID. LE_SALE_CON_PICOS_FR_TRAN_OK_B =  LE_SALE_CONTRACT_B | LE_HOLDS_PICOS_B | LE_FROM_TRANSFER_OK_B for the sale contract bit settings
    pListMR[pSaleA].picosBalance = vPicos;
    return true;
  }

  // List.CreatePresaleEntry()
  // -------------------------
  // Create a Seed Presale or Private Placement list entry, called from Hub.PresaleIssue()
  function CreatePresaleEntry(address entryA, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external IsHubContractCaller returns (bool) {
    require(pCreateEntry(entryA, LE_PRESALE_B, vDbId));
    pListMR[entryA].addedT        =
    pListMR[entryA].firstContribT = vAddedT; // firstContribT assumed to be the same as addedT for presale entries
    if (vNumContribs > 1)
      pListMR[entryA].contributions = vNumContribs - 1; // -1 because List.Issue() called subsequently will increment this
    pNumPresale++;
    return true;
  }

  // List.Whitelist()
  // ----------------
  // Called from Hub.Whitelist() to whitelist an entry
  // Hub.Whitelist() carries on in the case of a Pfund not whitelisted account with sale open to issue the Picos and do a P to M transfer
  function Whitelist(address entryA, uint32 vWhiteT) external IsHubContractCaller {
    uint32 bitsToSet = LE_WHITELISTED_B;
    R_List storage rsEntryR = pListMR[entryA];
    uint32 bits = rsEntryR.bits;
    require(bits > 0, 'Unknown account'); // Entry is expected to exist
    if (rsEntryR.whiteT == 0) { // if not just changing the whitelist date then decrement prepurchases and incr white
      pNumWhite++;
      if (rsEntryR.picosBalance > 0) { // could be here for a presale entry with a balance now being whitelisted
        pNumMembers++;
        bitsToSet |= LE_MEMBER_B;
        if (bits & LE_PROXY_APPOINTER_B > 0)
          // Has a proxy appointed and has a picos balance so update the proxy
          pUpdateProxyData(entryA, rsEntryR.picosBalance, 0); // 0 for no change to numProxyVotesFor
      }
    }
    rsEntryR.whiteT = vWhiteT;
    rsEntryR.bits |= bitsToSet;
    emit WhitelistV(entryA, vWhiteT);
  } // End of WhiteList()

  // List.Downgrade()
  // ----------------
  // Downgrades an entry from whitelisted
  function Downgrade(address entryA, uint32 vDownT) external IsHubContractCaller {
    R_List storage rsEntryR = pListMR[entryA];
    uint32 bits = rsEntryR.bits;
    require(bits & LE_WHITELISTED_B > 0, 'Account not whitelisted'); // Entry is expected to exist and be whitelisted
    if (rsEntryR.downT == 0) { // if not just changing the downgrade date then decrement white and incr downgraded
      if (bits & LE_MEMBER_B > 0)
        pNumMembers = decrementMaxZero(pNumMembers);
      if (bits & LE_PROXY_APPOINTER_B > 0 && rsEntryR.picosBalance > 0)
        // Had a proxy appointed and has a picos balance so update the proxy
        pUpdateProxyData(entryA, 0, 0); // 0 for no change to numProxyVotesFor
      rsEntryR.bits &= ~LE_WHITELISTED_MEMBER_B; // unset LE_WHITELISTED_B and LE_MEMBER_B bits
      pNumWhite = decrementMaxZero(pNumWhite);
      rsEntryR.bits |= LE_DOWNGRADED_B;
      pNumDowngraded++;
    }
    rsEntryR.downT = vDownT;
    emit DowngradeV(entryA, vDownT);
  }

  // List.SetBonus()
  // ---------------
  // Sets bonusCentiPc Bonus percentage in centi-percent i.e. 675 for 6.75%. If set means that this person is entitled to a bonusCentiPc bonus on next purchase
  function SetBonus(address entryA, uint32 vBonusPc) external IsHubContractCaller {
    require(pListMR[entryA].bits > 0, 'Unknown account'); // Entry is expected to exist
    pListMR[entryA].bonusCentiPc = vBonusPc;
    emit SetBonusV(entryA, vBonusPc);
  }

  // List.Issue()
  // ------------
  // Cases:
  // a. Hub.PresaleIssue()                                     -> Sale.PresaleIssue() -> Token.Issue() -> here for all Seed Presale and Private Placement pContributors (aggregated)
  // b. Sale.pBuy()                                                -> Sale.pProcess() -> Token.Issue() -> here for normal buying
  // c. Hub.Whitelist()  -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pProcess() -> Token.Issue() -> here for Pfund to Mfund transfers on whitelisting
  // d. Hub.PMtransfer() -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pProcess() -> Token.Issue() -> here for Pfund to Mfund transfers for an entry which was whitelisted and ready prior to opening of the sale which has now happened
  // with transche1B set if this is a Tranche 1 issue
  function Issue(address toA, uint256 vPicos, uint256 vWei, uint32 tranche1Bit) external IsTokenContractCaller {
    R_List storage rsEntryR = pListMR[toA];
    uint32 bits = rsEntryR.bits;
    uint32 bitsToSet = LE_FUNDED_M_FUND_PICOS_B | tranche1Bit; // LE_FUNDED_B will already be set for cases c and d
    require(bits > 0 && bits & LE_SEND_FUNDS_NOK_B == 0 && bits & LE_WHITELISTED_B > 0); // already checked by Sale.pProcess() so expected to be ok
    require(pListMR[pSaleA].picosBalance >= vPicos, "Picos not available"); // Check that the Picos are available
    require(vPicos > 0, "Cannot issue 0 picos");  // Make sure not here for 0 picos re counts below
    if (bits & LE_P_FUND_B > 0) {
      // Cases c and d Pfund to Mfund transfers
      // c. Hub.Whitelist()  -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pProcess() -> Token.Issue() -> here for Pfund to Mfund transfers on whitelisting
      // d. Hub.PMtransfer() -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pProcess() -> Token.Issue() -> here for Pfund to Mfund transfers for an entry which was whitelisted and ready prior to opening of the sale which has now happened
      // List.PrepurchaseDeposit() has been run so firstContribT, pNumPfund, weiContributed, contributions have been updated and the LE_P_FUND_B bit set
      rsEntryR.bits &= ~LE_P_FUND_B;           // unset the Pfund bit
      pNumPfund = decrementMaxZero(pNumPfund); // decrement pNumPfund
    }else{
      // Cases a and b
      // a. Hub.PresaleIssue() -> Sale.PresaleIssue() -> Token.Issue() -> here for all Seed Presale and Private Placement pContributors (aggregated)
      // b. Sale.pBuy()        -> Sale.pProcess()     -> Token.Issue() -> here for normal buying
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
    if (bits & LE_PROXY_APPOINTER_B > 0)
      // Has a proxy appointed so update the proxy for the vote change
      pUpdateProxyData(toA, rsEntryR.picosBalance, 0); // 0 for no change to numProxyVotesFor
    pListMR[pSaleA].picosBalance -= vPicos; // There is no need to check this for underflow via a safeSub() call given the pListMR[pSaleA].picosBalance >= vPicos check
    // Token.Issue() emits an IssueV() event    Should never go to zero for the Pacio DAICO given reserves held
  } // End of Issue()

  // List.PrepurchaseDeposit()
  // -------------------------
  // Is called from Sale.pBuy() for prepurchase funds being deposited, with tranche1Bit set if from Sale.BuyTranche1()
  //   In this case Sale.pBuy() also calls Pfund.Deposit()
  function PrepurchaseDeposit(address toA, uint256 vWei, uint32 tranche1Bit) external IsSaleContractCaller {
    R_List storage rsEntryR = pListMR[toA];
    uint32 bits = rsEntryR.bits;
    require(bits > 0 && bits & LE_SEND_FUNDS_NOK_B == 0 && (bits & LE_WHITELISTED_B == 0 || pState & STATE_PRIOR_TO_OPEN_B > 0)); // already checked by Sale.pBuy() so expected to be ok
    if (rsEntryR.weiContributed == 0) {
      rsEntryR.firstContribT = uint32(now);
      pNumPfund++;
    }
    rsEntryR.weiContributed = safeAdd(rsEntryR.weiContributed, vWei);
    rsEntryR.contributions++;
    rsEntryR.bits |= LE_FUNDED_P_FUND_B | tranche1Bit; // means funded too
    emit PrepurchaseDepositV(toA, vWei);
  }

  // List.Transfer()
  // ---------------
  // Is called for EIP20 transfers from EIP20Token.transfer() and EIP20Token.transferFrom() which emit a Transfer() event
  function Transfer(address frA, address toA, uint256 vPicos) external IsTransferOK(frA, toA, vPicos) IsTokenContractCaller returns (bool success) {
    // From
    R_List storage rsEntryR = pListMR[frA];
    uint32 bits;
    if ((rsEntryR.picosBalance -= vPicos) == 0) { // There is no need to check this for underflow via a safeSub() call given the IsTransferOK pListMR[frA].picosBalance >= vPicos check
      // frA now has no picos
      bits = rsEntryR.bits;
      if (bits & LE_MEMBER_B > 0)
        pNumMembers = decrementMaxZero(pNumMembers);
      if (bits & LE_PROXY_APPOINTER_B > 0) {
        pUpdateProxyData(frA, 0, -int32(rsEntryR.numProxyVotesFor + (bits & LE_MEMBER_B > 0 ? 1 : 0)));
        rsEntryR.proxyA = address(0);
        pNumProxyAppointers = decrementMaxZero(pNumProxyAppointers);
      }
      // Don't do anything about LE_PROXY_B because removing this as a proxy could disenfranchise entries who have appointed this member as their proxy.
      rsEntryR.bits &= ~LE_MF_PICOS_MEMBER_PROXY_APP_B; // LE_M_FUND_B | LE_HOLDS_PICOS_B | LE_MEMBER_B | LE_PROXY_APPOINTER_B
    }
    // To
    rsEntryR = pListMR[toA];
    rsEntryR.picosBalance = safeAdd(rsEntryR.picosBalance, vPicos);
    // toA becomes a member because it has picos and it must be whitelisted for IsTransferOK() to pass
    bits = rsEntryR.bits;
    if (bits & LE_MEMBER_B == 0) {
      // it wasn't previously a member
      pNumMembers++;
      if (bits & LE_PROXY_APPOINTER_B > 0)
        // but it had appointed a proxy so do a proxy update now that it is has votes
        pUpdateProxyData(toA, rsEntryR.picosBalance, 1); // +1 change for this entry becoming a member
    }
    rsEntryR.bits |= LE_M_FUND_PICOS_MEMBER_B; // set the toA LE_M_FUND_B, LE_HOLDS_PICOS_B and LE_MEMBER_B bits
    return true;
  } // End Transfer()

  // List.NewSaleContract()
  // ----------------------
  // Special transfer fn for the case of a new Sale being setup via manual call of the old Sale.NewSaleContract() -> Token.NewSaleContract() -> here
  // pSaleA is still the old Sale when this is called
  function NewSaleContract(address newSaleContractA) external IsTokenContractCaller {
    require(pCreateEntry(newSaleContractA, LE_SALE_CON_PICOS_FR_TRAN_OK_B, 1)); // assuming 1 for Sale contract Db ID. LE_SALE_CON_PICOS_FR_TRAN_OK_B =  LE_SALE_CONTRACT_B | LE_HOLDS_PICOS_B | LE_FROM_TRANSFER_OK_B for the sale contract bit settings
    pListMR[newSaleContractA].picosBalance = pListMR[pSaleA].picosBalance;
    pListMR[pSaleA].picosBalance = 0;
    pListMR[pSaleA].bits &= ~LE_SALE_CON_PICOS_FR_TRAN_OK_B;
    pSaleA                  =
    iOwnersYA[SALE_OWNER_X] = newSaleContractA;
  }

  // List.Refund()
  // -------------
  // Called from Token.Refund() IsHubContractCaller which is called from Hub.Refund()     IsNotContractCaller via Hub.pRefund()
  //                                                                  or Hub.PushRefund() IsWebOrAdminCaller  via Hub.pRefund()
  // vRefundWei can be less than or greater than List.WeiContributed() for termination case where the wei is a proportional calc based on picos held re transfers, not wei contributed
  // Refunded PIOs are transferred back to the Sale contract account. They are not burnt or destroyed.
  function Refund(address toA, uint256 vRefundWei, uint32 vRefundBit) external IsTokenContractCaller returns (uint256 refundPicos)  {
    R_List storage rsEntryR = pListMR[toA];
    uint32 bits = rsEntryR.bits;
    require(bits > 0 && bits & LE_REFUNDS_NOK_B == 0); // Already checked by Hub.pRefund() so expected to be ok
    if (vRefundBit >= LE_P_REFUNDED_S_CAP_MISS_B) {
      // Pfund refundBit
      require(bits & LE_P_FUND_B > 0, "Invalid list type for Prepurchase Refund");
      require(rsEntryR.weiContributed == vRefundWei, "Invalid List Prepurchase Refund call");
      rsEntryR.bits &= ~LE_P_FUND_B;           // unset the prepurchase bit
      pNumPfund = decrementMaxZero(pNumPfund); // decrement pNumPfund
    }else{
      // Mfund refund bit
      require(bits & LE_HOLDS_PICOS_B > 0, "Invalid list type for Refund");
      refundPicos = rsEntryR.picosBalance;
      require(refundPicos > 0 && vRefundWei > 0, "Invalid Mfund refund call");
      pListMR[pSaleA].picosBalance = safeAdd(pListMR[pSaleA].picosBalance, refundPicos); // transfer the Picos back to the sale contract. Token.Refund() emits a Transfer() event for this.
      rsEntryR.picosBalance = 0;
      if (bits & LE_MEMBER_B > 0)
        pNumMembers = decrementMaxZero(pNumMembers);
      if (bits & LE_PROXY_APPOINTER_B > 0) {
        // Remove appointer from proxy
        pUpdateProxyData(toA, 0, -int32(rsEntryR.numProxyVotesFor + (bits & LE_MEMBER_B > 0 ? 1 : 0)));
        rsEntryR.proxyA = address(0);
        pNumProxyAppointers = decrementMaxZero(pNumProxyAppointers);
      }
      rsEntryR.bits &= ~LE_MF_PICOS_MEMBER_PROXY_APP_B; // LE_M_FUND_B | LE_HOLDS_PICOS_B | LE_MEMBER_B | LE_PROXY_APPOINTER_B
    }
    rsEntryR.refundT = uint32(now);
    rsEntryR.weiRefunded = vRefundWei; // No need to add as can come here only once since will fail LE_REFUNDS_NOK_B after thids
    rsEntryR.bits |= vRefundBit;
    // Token.Refund() emits RefundV(vRefundId, toA, refundPicos, vRefundWei, vRefundBit);
  }

  // List.SetMaxVotePerMember()
  // --------------------------
  // Called from Poll.pSetMaxVotePerMember() to set pMaxPicosVote
  // After a call to SetMaxVotePerMember() an admin traverse of List is required to update list entry.sumVotesDelegated for Members who are proxies
  function SetMaxVotePerMember(uint256 vMaxPicosVote) external IsPollContractCaller {
     pMaxPicosVote = vMaxPicosVote; // Maximum vote in picos for a member = Sale.pPicoHardCap * Poll.pMaxVoteHardCapCentiPc / 100
  }

  // List.UpdatePioVotesDelegated()
  // ------------------------------
  // Called from Poll.UpdatePioVotesDelegated() on a traverse of the List for proxy appointers to update list pioVotesDelegated and sumVotesDelegated up the line following a pMaxPicosVote change
  function UpdatePioVotesDelegated(address entryA) external IsPollContractCaller {
    R_List storage rsEntryR = pListMR[entryA];
    require(rsEntryR.bits & LE_PROXY_APPOINTER_B > 0, 'Not proxy appointer');
    pUpdateProxyData(entryA, rsEntryR.picosBalance, 0); // 0 change
  }

  // pUpdateProxyData() private
  // ------------------
  // Called from List.UpdatePioVotesDelegated() for a proxy appointer to adjust pioVotesDelegated and sumVotesDelegated up the line following a pMaxPicosVote change
  //             List.SetProxy() for setting a proxy, changing a proxy, or removing a proxy
  // Also updates numProxyVotesFor according to vNumProxyVotesForChange
  // WARNING: The gas usage is unknown as there is a loop involved. MUST be called with a high gas limit set.
  // uint32 pioVotesDelegated  Pio votes delegated if entry has appointed a proxy            /- an entry can have both set    --- set here
  // uint32 sumVotesDelegated  Sum of pio votes delegated by appointers if entry is a proxy  |                                --- updated here
  function pUpdateProxyData(address entryA, uint256 vPicosBalance, int32 vNumProxyVotesForChange) private {
    R_List storage rsEntryR = pListMR[entryA]; // the entry which has appointed a proxy
    if (rsEntryR.bits & LE_PROXY_APPOINTER_B == 0) return; // Expected to be a Proxy appointer
    uint32 newPioVotesDelegated = uint32(Min(vPicosBalance, pMaxPicosVote) / 10**12);
    int32 piosToVoteChange = int32(newPioVotesDelegated) - int32(rsEntryR.pioVotesDelegated);
    emit UpdateProxyAppointerV(entryA, rsEntryR.pioVotesDelegated, newPioVotesDelegated, pNumProxyAppointers);
    rsEntryR.pioVotesDelegated = newPioVotesDelegated;
    // Pass the change up the line
    while (rsEntryR.bits & LE_PROXY_APPOINTER_B > 0) {
      address proxyA = rsEntryR.proxyA;
      if (proxyA == address(0)) return; // expected to have a Proxy
      rsEntryR = pListMR[proxyA]; // entry of the proxy
      uint32 newNumProxyVotesFor = rsEntryR.numProxyVotesFor;
      if (vNumProxyVotesForChange != 0) {
        if (vNumProxyVotesForChange > 0)
          newNumProxyVotesFor += uint32(vNumProxyVotesForChange);
        else if (vNumProxyVotesForChange < 0)
          newNumProxyVotesFor = subMaxZero32(newNumProxyVotesFor, uint32(-vNumProxyVotesForChange));
        if (newNumProxyVotesFor > 0) {
          // Is voting on behalf of appointers so set as a proxy if not already one
          if (rsEntryR.bits & LE_PROXY_B == 0) {
            // Becoming a proxy
            rsEntryR.bits |= LE_PROXY_B; // set the proxy bit
            pNumProxies++;
          }
        }else{
          // newNumProxyVotesFor == 0
          // Is not now voting on behalf of any appointers so unset as a proxy if set
          if (rsEntryR.bits & LE_PROXY_B > 0) {
            // was set as a proxy so unset
            rsEntryR.bits &= ~LE_PROXY_B; // unset the proxy bit
            pNumProxies = decrementMaxZero(pNumProxies);
          }
        }
      }
      uint32 newSumVotesDelegated = piosToVoteChange >= 0 ? rsEntryR.sumVotesDelegated + uint32(piosToVoteChange)
                                                          : subMaxZero32(rsEntryR.sumVotesDelegated, uint32(-piosToVoteChange));
      // Valid   newSumVotesDelegated  newNumProxyVotesFor
      //         0                     0
      //         0                     > 0
      //         > 0                   > 0
      // Invalid newSumVotesDelegated  newNumProxyVotesFor
      //         > 0                   0
      // So have just one case to check for!
      require(!(newSumVotesDelegated > 0 && newNumProxyVotesFor == 0), 'newSumVotesDelegated & newNumProxyVotesFor error');
      emit UpdateProxyV(proxyA, rsEntryR.sumVotesDelegated, newSumVotesDelegated, rsEntryR.numProxyVotesFor, newNumProxyVotesFor, pNumProxies);
      rsEntryR.sumVotesDelegated = newSumVotesDelegated;
      rsEntryR.numProxyVotesFor  = newNumProxyVotesFor;
    }
  }

  // List.SetProxy()
  // ---------------
  // Sets, changes, or removes the proxy address of entry entryA to vProxyA plus updates bits and pNumProxyAppointers
  // vProxyA = 0x0 to remove a proxy
  // There are 4 cases re proxies:  Votes  LE_PROXY_INVOLVED_B    LE_PROXY_APPOINTER_B LE_PROXY_B  proxyA  pioVotesDelegated  sumVotesDelegated  numProxyVotesFor
  // Proxy not involved             Yes    unset                        unset                unset       0x0     0                  0                  0
  // Proxy appointer                No     == LE_PROXY_APPOINTER_B      set                  unset       set     > 0                0                  0
  // Proxy                          Yes    == LE_PROXY_B                unset                set         0x0     0                  > 0                0 or > 0
  // Both proxy appointer and Proxy No     == LE_PROXY_INVOLVED_B set                  set         set     > 0                > 0                0 or > 0
  // where pioVotesDelegated for one entry is uint32(Min(rsEntryR.picosBalance, pMaxPicosVote) / 10**12)
  // and Yes to Votes also requires the entry to be a Member
  function SetProxy(address entryA, address vProxyA) external IsPollContractCaller {
    R_List storage rsEntryR = pListMR[entryA]; // the entry which has appointed or is appointing a proxy
    uint32 bits = rsEntryR.bits;
    require(bits > 0, 'Unknown account'); // Entry is expected to exist. doesn't have to be a Member. (Can appoint a proxy on registering)
    bool   proxyAppointedB = bits & LE_PROXY_APPOINTER_B > 0;
    int32  numberThisVotesFor = int32(rsEntryR.numProxyVotesFor + (bits & LE_MEMBER_B > 0 ? 1 : 0)); // rsEntryR.numProxyVotesFor because this could be a proxy appoitning/removing/changing a proxy
    if (vProxyA == address(0)) {
      // Remove appointed proxy
      require(proxyAppointedB, 'Not proxy appointer');
      // Did have a proxy appointed as expected so update old to remove this appointer
      // dateProxyData( entryA, vPicosBalance, vNumProxyVotesForChange)
      pUpdateProxyData(entryA, 0, -numberThisVotesFor);
      rsEntryR.bits ^= LE_PROXY_APPOINTER_B; // unset the LE_PROXY_APPOINTER_B bit which we know is set
      rsEntryR.proxyA = address(0);
      pNumProxyAppointers = decrementMaxZero(pNumProxyAppointers);
    }else{
      // Set proxy which is expected to be a Member
      require(IsMember(vProxyA), 'Proxy not member'); // Proxy is expected to be a Member
      if (proxyAppointedB)
        // Changing proxy so update old to remove this appointer
        // dateProxyData(entryA, vPicosBalance, vNumProxyVotesForChange)
        pUpdateProxyData(entryA, 0, -numberThisVotesFor); // remove from old proxy, then will add new below
      else{
        // Didn't previously have a proxy so just add new one
        rsEntryR.bits |= LE_PROXY_APPOINTER_B;
        pNumProxyAppointers++;
      }
      rsEntryR.proxyA = vProxyA;
      // Add appointer
      // dateProxyData( entryA, vPicosBalance, vNumProxyVotesForChange)
      pUpdateProxyData(entryA, rsEntryR.picosBalance, numberThisVotesFor);
    }
    emit SetProxyV(entryA, vProxyA);
  }

  // List.SetListEntryTransferOk()
  // -----------------------------
  // Called from Hub.SetListEntryTransferOk to set LE_FROM_TRANSFER_OK_B bit of entry entryA on if B is true, or unset the bit if B is false
  // Could also be done via SetListEntryBits()
  function SetListEntryTransferOk(address entryA, bool setB) external IsHubContractCaller {
    require(pListMR[entryA].bits > 0, 'Unknown account'); // Entry is expected to exist
    if (setB)
      pListMR[entryA].bits |= LE_FROM_TRANSFER_OK_B;
    else
      pListMR[entryA].bits &= ~LE_FROM_TRANSFER_OK_B;
    emit SetTransferOkV(entryA, setB);
  }

  // List.SetListEntryBits()
  // -----------------------
  // Called from Hub.SetListEntryBitsMO() managed operation to set/unset bits in a list entry
  function SetListEntryBits(address entryA, uint32 bitsToSet, bool setB) external IsHubContractCaller {
    R_List storage rsEntryR = pListMR[entryA];
    uint32 bits = rsEntryR.bits;
    require(bits > 0, 'Unknown account'); // Entry is expected to exist
    if (setB)
      rsEntryR.bits |= bitsToSet;
    else
      rsEntryR.bits &= ~bitsToSet;
    emit SetListEntryBitsV(entryA, bitsToSet, setB, bits, rsEntryR.bits);
  }

  // List.Vote()
  // -----------
  // Called from Poll.RequestPoll() and Poll.pVote() to make or revoke a vote in a current poll
  // Needs to be a member if not a proxy. (A proxy can still vote even if no longer a member so as not to disenfranchise appointers of the person as a proxy.)
  // Returns pios voted
  // There are 4 cases re proxies:  Votes  LE_PROXY_INVOLVED_B    LE_PROXY_APPOINTER_B LE_PROXY_B  proxyA  pioVotesDelegated  sumVotesDelegated  numProxyVotesFor
  // Proxy not involved             Yes    unset                        unset                unset       0x0     0                  0                  0
  // Proxy appointer                No     == LE_PROXY_APPOINTER_B      set                  unset       set     > 0                0                  0
  // Proxy                          Yes    == LE_PROXY_B                unset                set         0x0     0                  > 0                0 or > 0
  // Both proxy appointer and Proxy No     == LE_PROXY_INVOLVED_B set                  set         set     > 0                > 0                0 or > 0
  // where pioVotesDelegated for one entry is uint32(Min(rsEntryR.picosBalance, pMaxPicosVote) / 10**12)
  // and Yes to Votes also requires the entry to be a Member
  function Vote(address voterA, uint32 vPollId, uint8 voteN) external IsPollContractCaller returns (uint32 retPiosVoted, uint32 retNumMembersVotedFor, uint8 retVoteN)  {
    R_List storage rsEntryR = pListMR[voterA];
    uint32 bits = rsEntryR.bits;
    if (bits & LE_MEMBER_PROXY_B > 0             // Is a Member or a Proxy
     && bits & LE_PROXY_APP_VOTE_BLOCK_B == 0) { //  who has not appointed a proxy or been blocked from voting
     // Is a Member or proxy who has not appointes a proxy
     retNumMembersVotedFor = 1 + rsEntryR.numProxyVotesFor;
     if (voteN == VOTE_REVOKE_N) {
        if (rsEntryR.pollId == vPollId && rsEntryR.piosVoted != 0 && rsEntryR.numTimesVoted > 0) {
          // has voted in the current poll && vote hasn't already been revoked
          retPiosVoted = rsEntryR.piosVoted;
          retVoteN     = rsEntryR.voteN; // return what the previous vote was in the Revoke case
          rsEntryR.piosVoted = 0;
          rsEntryR.voteN == VOTE_REVOKE_N;
          rsEntryR.numTimesVoted--;
        }
     } else if  (voteN == VOTE_YES_N || voteN == VOTE_NO_N) { // and voteN is as expected
        // Yes or No VOTE_YES_N, VOTE_NO_N
        // retVoteN stays unset for the vote case
        rsEntryR.voteT = uint32(now);
        rsEntryR.numTimesVoted++;
        rsEntryR.pollId = vPollId;
        rsEntryR.voteN  = voteN;
        retPiosVoted = rsEntryR.sumVotesDelegated + uint32(Min(rsEntryR.picosBalance, pMaxPicosVote) / 10**12);
        rsEntryR.piosVoted = retPiosVoted;
      }
    } // else not a member or proxy, has appointed a proxy, or is not a valid voteN -> an error return
    emit VoteV(voterA, vPollId, voteN, retPiosVoted, retNumMembersVotedFor, retVoteN); // emitted for error return (retPiosVoted = 0) cases too
  }

  // List.TransferIssuedPIOsToPacioBc()
  // ----------------------------------
  // For use when transferring issued PIOs to the Pacio Blockchain
  // Is called by Token.TransferIssuedPIOsToPacioBc()
  function TransferIssuedPIOsToPacioBc(address entryA) external IsTokenContractCaller {
    R_List storage rsEntryR = pListMR[entryA];
    uint32 bits = rsEntryR.bits;
    require(pState & STATE_TRANSFER_TO_PB_B > 0 // /- also checked by Token.TransferIssuedPIOsToPacioBc() so no fail msg
         && bits > 0);                          // |
    rsEntryR.picosBalance = 0;
    if (bits & LE_PROXY_APPOINTER_B > 0) {
      // Remove appointer from proxy
      pUpdateProxyData(entryA, 0, -int32(rsEntryR.numProxyVotesFor + (bits & LE_MEMBER_B > 0 ? 1 : 0)));
      rsEntryR.proxyA = address(0);
      pNumProxyAppointers = decrementMaxZero(pNumProxyAppointers);
    }
    if (bits & LE_MEMBER_B > 0) pNumMembers = decrementMaxZero(pNumMembers);
    if (bits & LE_PROXY_B > 0)  pNumProxies = decrementMaxZero(pNumProxies);
    rsEntryR.bits &= ~LE_MF_PICOS_MEMBER_PROXY_ALL_B; // LE_M_FUND_B | LE_HOLDS_PICOS_B | LE_MEMBER_B | LE_PROXY_INVOLVED_B
    // Token.TransferIssuedPIOsToPacioBc() emits TransferIssuedPIOsToPacioBcV(++pTransferToPbId, entryA, picos);
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
      rsEntryR.bits &= ~LE_HOLDS_PICOS_B; // unset the LE_HOLDS_PICOS_B bit
  }

  // List.NewTokenContract()
  // -----------------------
  // Called from Hub.NewTokenContract() to change TOKEN_OWNER_X of the List contract to the new Token contract
  function NewTokenContract(address newTokenContractA) external IsHubContractCaller {
    iOwnersYA[TOKEN_OWNER_X] = newTokenContractA;
  }

  // List.Fallback function
  // ======================
  // No sending ether to this contract!
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the List contract other than via the defined methods with their testing for valid access
  }

} // End List contract
