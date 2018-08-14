/* \Token\Token.sol 2018.06.04 started

The Pacio Token named PIOE for the Pacio DAICO

Owners: Deployer OpMan Hub Sale Admin

Calls
OpMan  for IsManOpApproved() calls from Owned.ChangeOwnerMO() and  Owned.ResumeMO
List   as the contract for the list of participants

To Do djh??
- Add functions for changing contracts

Pause/Resume
============
OpMan.PauseContract(TOKEN_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(TOKEN_CONTRACT_X) IsConfirmedSigner which is a managed op

Fallback function
=================
No sending ether to this contract

*/

pragma solidity ^0.4.24;

import "../lib/Math.sol";
import "../OpMan/I_OpMan.sol";
import "../List/I_ListToken.sol";
import "./EIP20Token.sol"; // Owned via OwnedToken.sol

contract Token is EIP20Token, Math {
  uint32  private pState;            // DAICO state using the STATE_ bits. Replicated from Hub on a change
  uint256 private pPicosIssued;      // Picos issued = picos in circulation. Should == Sale.PicosSold() unless refunding/transferring to Pacio Blockchain happens
  uint256 private pWeiRaised;        // cumulative wei raised. Should == Sale.pWeiRaised
  uint256 private pWeiRefunded;      // cumulative wei refunded. No Sale equivalent
  uint256 private pPicosAvailable;   // Picos available = total supply less allocated and issued tokens
  uint256 private pContributors;     // Number of contributors
  uint256 private pPclPicosAllocated;// PCL Picos allocated
  uint256 private pIssueId;          // Issue Id
  uint256 private pTransferToPbId;   // Transfer to Pacio Blockchain Id
  address private pSaleA;            // the Sale contract address - only used as an address here i.e. don't need pSaleC

  // No Constructor
  // --------------

  // View Methods
  // ============
  // Token.DaicoState() Should be the same as Hub.DaicoState()
  function DaicoState() external view returns (uint32) {
    return pState;
  }
  // Token.IsSaleOpen()
  function IsSaleOpen() external view returns (bool) {
    return pState & STATE_OPEN_B > 0;
  }
  // Token.PicosIssued()
  function PicosIssued() external view returns (uint256) {
    return pPicosIssued;
  }
  // Token.PicosAvailable()
  function PicosAvailable() external view returns (uint256) {
    return pPicosAvailable;
  }
  // Token.IssueId()
  function IssueId() external view returns (uint256) {
    return pIssueId;
  }
  // Token.WeiRaised()
  function WeiRaised() external view returns (uint256) {
    return pWeiRaised;
  }
  // Token.WeiRefunded()
  function WeiRefunded() external view returns (uint256) {
    return pWeiRefunded;
  }
  // Token.Contributors()
  function Contributors() external view returns (uint256) {
    return pContributors;
  }
  // Token.PclPicosAllocated()
  function PclPicosAllocated() external view returns (uint256) {
    return pPclPicosAllocated;
  }
  // Token.IsTransferAllowedByDefault()
  function IsTransferAllowedByDefault() external view returns (bool) {
    return iListC.IsTransferAllowedByDefault();
  }

  // Events
  // ------
  event StateChangeV(uint32 PrevState, uint32 NewState);
  event  IssueV(uint256 indexed IssueId,  address indexed To, uint256 Picos, uint256 Wei);
  event RefundV(uint256 indexed RefundId, address indexed To, uint256 RefundPicos, uint256 RefundWei, uint32 Bit);
  event TransferIssuedPIOsToPacioBcV(uint256 indexed TransferToPbId, address Account, uint256 Picos);
  event TransferUnIssuedPIOsToPacioBcV(uint256 Picos);
//event Transfer(address indexed From, address indexed To, uint256 Value);          /- In EIP20Token
//event Approval(address indexed Account, address indexed Spender, uint256 Value);  |

  // Initialisation/Settings Methods
  // ===============================
  // Token.Initialise()
  // ------------------
  // To be called by the deploy script to set the contract variable, and do the PIOE minting.
  // Can only be called once.
  // Owners Deployer OpMan Hub Sale Admin
  // Owners must first be set by deploy script calls:
  //   Token.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
  //   Token.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Token.ChangeOwnerMO(SALE_OWNER_X, Sale address)
  //   Token.ChangeOwnerMO(TOKEN_ADMIN_OWNER_X, PCL hw wallet account address as Admin)
  //    List.ChangeOwnerMO(LIST_TOKEN_OWNER_X, Token address)
  function Initialise(uint32 vDbId) external IsInitialising {
    iPausedB = false; // make active
    iListC   = I_ListToken(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(LIST_CONTRACT_X)); // The List contract
    pSaleA   = iOwnersYA[SALE_OWNER_X];
    // Mint and create the owners account in List
    totalSupply = 10**21; // 1 Billion PIOEs = 1e21 Picos, all minted
    // Create the Sale sale contract list entry
    iListC.CreateSaleContractEntry(10**21, vDbId);
    // 10^20 = 100,000,000,000,000,000,000 picos
    //       = 100,000,000 or 100 million PIOEs
    // 10^19 = 10,000,000,000,000,000,000 picos
    //       = 10,000,000 or 10 million PIOEs
    pPclPicosAllocated = 25*(10**19); // 250 million = 25 x 10 million
    pPicosAvailable    = 75*(10**19); // 750 million
    // From the EIP20 Standard: A token contract which creates new tokens SHOULD trigger a Transfer event with the _from address set to 0x0 when tokens are created.
    emit Transfer(0x0, pSaleA, 10**21); // log event 0x0 from == minting. pSaleA is the Sale contract
    iInitialisingB = false;
  }

  // State changing external methods
  // ===============================

  // Token.StateChange()
  // -------------------
  // Called from Hub.pSetState() on a change of state to replicate the new state setting
  function StateChange(uint32 vState) external IsHubContractCaller {
    emit StateChangeV(pState, vState);
    pState = vState;
  }

  // Token.Issue()
  // -------------
  // Cases:
  // a. Hub.PresaleIssue() -> Sale.PresaleIssue()                                 -> here for all Seed Presale and Private Placement pContributors (aggregated)
  // b. Sale.Buy()-> Sale.pBuy()                                                  -> here for normal buying
  // c. Hub.Whitelist()  -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pBuy() -> here for Pfund to Mfund transfers on whitelisting
  // d. Hub.PMtransfer() -> Hub.pPMtransfer() -> Sale.PMtransfer() -> Sale.pBuy() -> here for Pfund to Mfund transfers for an entry which was whitelisted and ready prior to opening of the sale which has now happened
  function Issue(address toA, uint256 vPicos, uint256 vWei) external IsSaleContractCaller IsActive returns (bool) {
    if (iListC.PicosBought(toA) == 0)
      pContributors++;
    iListC.Issue(toA, vPicos, vWei); // Transfers from Sale as the minted tokens owner
    pPicosIssued    = safeAdd(pPicosIssued,    vPicos);
    pPicosAvailable = safeSub(pPicosAvailable, vPicos); // Should never go neg due to reserve, even if final Buy() goes over the hardcap
    pWeiRaised      = safeAdd(pWeiRaised, vWei);
    emit Transfer(pSaleA, toA, vPicos); // Was missing from the Presale contract
    emit IssueV(++pIssueId, toA, vPicos, vWei);
    return true;
  }

  // Token.Refund() Reverse of Issue
  // --------------
  // Called by:
  // . Hub.Refund()     IsNotContractCaller
  //   Hub.PushRefund() IsWebOrAdminCaller
  function Refund(uint256 vRefundId, address toA, uint256 vRefundWei, uint32 vRefundBit) external IsHubContractCaller IsActive returns (bool) {
    uint256 refundPicos = iListC.Refund(toA, vRefundWei, vRefundBit); // Transfers Picos (if any) from tA back to Sale as the minted tokens owner
    pWeiRefunded = safeAdd(pWeiRefunded, vRefundWei);
    if (refundPicos > 0) {
      pPicosIssued    = safeSub(pPicosIssued,    refundPicos);
      pPicosAvailable = safeAdd(pPicosAvailable, refundPicos);
      emit Transfer(toA, pSaleA, refundPicos);
    }
    emit RefundV(vRefundId, toA, refundPicos, vRefundWei, vRefundBit);
    return true;
  }

  // Functions for calling via same name function in Hub()
  // =====================================================

  // Functions for calling at MVP Launch Time
  // ========================================

  // Token.TransferIssuedPIOsToPacioBc()
  // -----------------------------------
  // For use when transferring issued PIOs to the Pacio Blockchain. Takes the picos out of circulation.
  // Is to be called by the owner of the PIOs. This will need to be integrated with an import of the PIOs into the Pacio Blockchain
  // Must be in the STATE_TRANSFER_TO_PB_B state for this to run.
  // Cannot be called by a contract.
  function TransferIssuedPIOsToPacioBc() external IsNotContractCaller {
    require(pState & STATE_TRANSFER_TO_PB_B > 0, 'Not in Transfer to PB state');
    uint256 picos = iListC.PicosBalance(msg.sender);
    require(picos > 0, "No PIOEs to transfer"); // is also a check for account existing
    iListC.TransferIssuedPIOsToPacioBc(msg.sender); // reverts if a list entry doesn't exist
    pPicosIssued = subMaxZero(pPicosIssued, picos);
    totalSupply  = subMaxZero(totalSupply,  picos);
    emit TransferIssuedPIOsToPacioBcV(++pTransferToPbId, msg.sender, picos);
    // Does not affect pPicosAvailable or the Sale contract balance as these are issued tokens that are being removed.
  }

  // Token.TransferUnIssuedPIOsToPacioBcMO()
  // ---------------------------------------
  // For use when transferring unissued PIOs to the Pacio Blockchain
  // Is to be called by Admin as a managed operation
  // Must be in the STATE_TRANSFERRED_TO_PB_B state for this to run.
  function TransferUnIssuedPIOsToPacioBcMO(uint256 vPicos) external IsAdminCaller {
    require(pState & STATE_TRANSFERRED_TO_PB_B > 0, 'Not in Transferred to PB state');
    require(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(TOKEN_TRAN_UNISSUED_TO_PB_MO_X));
    iListC.TransferUnIssuedPIOsToPacioBc(vPicos);
    totalSupply     = subMaxZero(totalSupply,     vPicos);
    pPicosAvailable = subMaxZero(pPicosAvailable, vPicos);
    emit TransferUnIssuedPIOsToPacioBcV(vPicos);
  }

  // Token.Fallback function
  // =======================
  // No sending ether to this contract!
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the token contract other than via the defined methods with their testing for valid access
  }

} // End Token contract
