/* \Token\Token.sol 2018.06.04 started

The Pacio Token named PIOE for the Pacio DAICO

Owners:
0 Deployer
1 OpMan
2 Hub
3 Sale
4 Mvp for burning/destroying with the transfer of PIOs to the Pacio Blockchain

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
  uint256 private pPicosIssued;      // Picos issued = picos in circulation. Should == Sale.PicosSold() unless refunding/burning/destroying happens
  uint256 private pWeiRaised;        // cumulative wei raised. Should == Sale.pWeiRaised
  uint256 private pWeiRefunded;      // cumulative wei refunded. No Sale equivalent
  uint256 private pPicosAvailable;   // Picos available = total supply less allocated and issued tokens
  uint256 private pContributors;     // Number of contributors
  uint256 private pPclPicosAllocated;// PCL Picos allocated
  address private pSaleA;            // the Sale contract address - only used as an address here i.e. don't need pSaleC

  // No Constructor
  // --------------

  // View Methods
  // ============
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
//event Transfer(address indexed From, address indexed To, uint256 Value);          /- In EIP20Token
//event Approval(address indexed Account, address indexed Spender, uint256 Value);  |

  // Initialisation/Settings Methods
  // ===============================
  // Token.Initialise()
  // ------------------
  // To be called by the deploy script to set the contract variable, and do the PIOE minting.
  // Can only be called once.
  // Owners 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Mvp
  // Owners must first be set by deploy script calls:
  //   Token.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
  //   Token.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Token.ChangeOwnerMO(SALE_OWNER_X, Sale address)
  //   Token.ChangeOwnerMO(MVP_OWNER_X, Mvp address)
  //    List.ChangeOwnerMO(TOKEN_OWNER_X, Token address)
  function Initialise() external IsInitialising {
    iPausedB = false; // make active
    iListC   = I_ListToken(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(LIST_CONTRACT_X)); // The List contract
    pSaleA   = iOwnersYA[SALE_OWNER_X];
    // Mint and create the owners account in List
    totalSupply = 10**21; // 1 Billion PIOEs = 1e21 Picos, all minted
    // Create the Sale sale contract list entry
    iListC.CreateSaleContractEntry(10**21);
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
  // Called by:
  // . Hub.PresaleIssue() -> Sale.PresaleIssue() -> here for all Seed Presale and Private Placement pContributors (aggregated) to initialise the DAICO for tokens issued in the Seed Presale and the Private Placement`
  //   List entry is created by Hub.Presale.Issue() which checks toA
  // . Sale.Buy() which checks toA
  function Issue(address toA, uint256 vPicos, uint256 vWei) external IsSaleContractCaller IsActive returns (bool) {
    if (iListC.PicosBought(toA) == 0)
      pContributors++;
    iListC.Issue(toA, vPicos, vWei); // Transfers from Sale as the minted tokens owner
    pPicosIssued    = safeAdd(pPicosIssued,    vPicos);
    pPicosAvailable = safeSub(pPicosAvailable, vPicos); // Should never go neg due to reserve, even if final Buy() goes over the hardcap
    pWeiRaised      = safeAdd(pWeiRaised, vWei);
    emit Transfer(pSaleA, toA, vPicos); // Was missing from the Presale contract
    // iListC.Issue() makes an IssueV(toA, vPicos, vWei) event call
    return true;
  }

  // Token.Refund() Reverse of Issue
  // -------------
  // Called by:
  // . Hub.Refund()     IsNotContractCaller
  //   Hub.PushRefund() IsWebOrAdminCaller
  function Refund(uint256 vRefundId, address toA, uint256 vRefundWei, uint32 vRefundBit) external IsHubContractCaller IsActive returns (bool) {
    uint256 refundPicos = iListC.Refund(vRefundId, toA, vRefundWei, vRefundBit); // Transfers Picos (if any) from tA back to Sale as the minted tokens owner
    pPicosIssued    = safeSub(pPicosIssued,    refundPicos);
    pPicosAvailable = safeAdd(pPicosAvailable, refundPicos);
    pWeiRefunded    = safeAdd(pWeiRefunded, vRefundWei);
    if (refundPicos > 0)
      emit Transfer(toA, pSaleA, refundPicos);
    // iListC.Refund() makes a RefundV(vRefundId, toA, refundPicos, vRefundWei, vRefundBit) event call
    return true;
  }

  // Functions for calling via same name function in Hub()
  // =====================================================

  // Functions for calling via same name function in Mvp
  // ===================================================
  // Token.Burn()
  // ------------
  // For use when transferring issued PIOEs to PIOs. Burns the picos held by tx.origin
  // Is called by Mvp.Burn() -> here thus use of tx.origin rather than msg.sender
  // There is no security risk associated with the use of tx.origin here as it is not used in any ownership/authorisation test
  // The event call is made by Mvp.Burn()
  function Burn() external IsMvpContractCaller {
    require(pState & STATE_CLOSED_COMBO_B > 0, "Sale not closed");
    uint256 picos = iListC.PicosBalance(tx.origin);
  //require(picos > 0, "No PIOEs to burn"); Not needed here as already done by Mvp.Burn()
    iListC.Burn(); // reverts if a tx.origin list entry doesn't exist
    pPicosIssued = subMaxZero(pPicosIssued, picos);
    totalSupply  = subMaxZero(totalSupply,  picos);
    // Does not affect pPicosAvailable or the Sale contract balance as these are issued tokens that are being burnt
  }

  // Token.Destroy()
  // ---------------
  // For use when transferring unissued PIOs to the Pacio Blockchain
  // Is called by Mvp.Destroy() -> here to destroy unissued Sale picos
  // The event call is made by Mvp.Destroy()
  function Destroy(uint256 vPicos) external IsMvpContractCaller {
    require(pState & STATE_CLOSED_COMBO_B > 0, "Sale not closed");
    iListC.Destroy(vPicos);
    totalSupply     = subMaxZero(totalSupply,     vPicos);
    pPicosAvailable = subMaxZero(pPicosAvailable, vPicos);
  }

  // Token.Fallback function
  // =======================
  // No sending ether to this contract!
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the token contract other than via the defined methods with their testing for valid access
  }

} // End Token contract
