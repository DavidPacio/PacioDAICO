/* \Token\Token.sol 2018.06.04 started

The Pacio Token named PIOE for the Pacio DAICO

Owners:
0 Deployer
1 OpMan
2 Hub
3 Sale
4 Mvp for burning/destroying with the transfer of PIOEs to PIOs

Calls
OpMan  for IsManOpApproved() calls from Owned.ChangeOwnerMO() and  Owned.ResumeMO
List   as the contract for the list of participants

To Do djh??
- Add functions for changing contracts


No Constructor
--------------

View Methods
============
Token.PicosIssued() external view returns (uint256)
Token.WeiRaised() external view returns (uint256)
Token.PicosAvailable() external view returns (uint256)
Token.Contributors() external view returns (uint256)
Token.PclPicosAllocated() external view returns (uint256)
Token.IsSaleOpen() external view returns (bool)
Token.IsTransferAllowedByDefault() external view returns (bool)
Token.BurnId() external view returns (int32)

Initialisation/Settings Methods
===============================
Token.Initialise() external IsHubCaller

State changing external methods
===============================
Token.Issue(address toA, uint256 vPicos, uint256 vWei) external IsSaleCaller IsActive returns (bool)

Functions for calling via same name function in Hub
===================================================

Functions for calling via same name function in Mvp
===================================================
Token.Burn() external IsMvpCaller
Token.Destroy(uint256 vPicos) external IsMvpCaller

Pause/Resume
============
OpMan.Pause(TOKEN_X) IsConfirmedSigner
OpMan.ResumeContractMO(TOKEN_X) IsConfirmedSigner which is a managed op

Fallback function
=================
No sending ether to this contract

Events
======
Token.StartSaleV();
Token.EndSaleV();

*/

pragma solidity ^0.4.24;

import "../lib/Math.sol";
import "../OpMan/I_OpMan.sol";
import "../List/I_ListToken.sol";
import "./EIP20Token.sol"; // Owned via OwnedToken.sol

contract Token is EIP20Token, Math {
  uint256 private pPicosIssued;      // Picos issued = picos in circulation. Should == Sale.pPicosSold
  uint256 private pWeiRaised;        // cumulative wei raised. Should == Sale.pWeiRaised
  uint256 private pPicosAvailable;   // Picos available = total supply less allocated and issued tokens
  uint256 private pContributors;     // Number of contributors
  uint256 private pPclPicosAllocated;// PCL Picos allocated
  bool    private pSaleOpenB;        // Is set to false when DAICO is complete or at least closed. Required for transfer of PIOEs to PIOs

  // Events
  // ------
  event StartSaleV();
  event EndSaleV();

  // No Constructor
  // --------------

  // Initialisation/Settings Methods
  // ===============================
  // Token.Initialise()
  // ------------------
  // To be called by the deploy script to set the contract variable, and do the PIOE minting.
  // Can only be called once.
  // Owners 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Mvp
  // Owners must first be set by deploy script calls:
  //   Token.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Token.ChangeOwnerMO(SALE_OWNER_X, Sale address)
  //   Token.ChangeOwnerMO(MVP_OWNER_X, Mvp address)
  //   Token.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address) <=== Must come after HUB_OWNER_X, SALE_OWNER_X, MVP_OWNER_X have been set
  //    List.ChangeOwnerMO(TOKEN_OWNER_X, Token address)
  function Initialise() external IsDeployerCaller {
    require(iInitialisingB); // To enforce being called only once
    iPausedB = false; // make active
    iListC   = I_ListToken(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).ContractXA(LIST_X)); // The List contract
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
    emit Transfer(0x0, iOwnersYA[SALE_OWNER_X], 10**21); // log event 0x0 from == minting. iOwnersYA[SALE_OWNER_X] is the Sale contract
    iInitialisingB = false;
  }
  // Token.StartSale()
  // ---------------
  // Is called from Hub.StartSale()
  function StartSale() external IsHubCaller IsActive {
    pSaleOpenB = true;
    emit StartSaleV();
  }
  // Token.EndSale()
  // ---------------
  // Is called from HUb.EndSale() after after hard cap is reached in Sale, time has expired in Sale, or the sale is ended manually
  function EndSale() external IsHubCaller IsActive {
    pSaleOpenB = false;
    emit EndSaleV();
  }

  // View Methods
  // ============
  // Token.PicosIssued()
  function PicosIssued() external view returns (uint256) {
    return pPicosIssued;
  }
  // Token.WeiRaised()
  function WeiRaised() external view returns (uint256) {
    return pWeiRaised;
  }
  // Token.pPicosAvailable()
  function PicosAvailable() external view returns (uint256) {
    return pPicosAvailable;
  }
  // Token.Contributors()
  function Contributors() external view returns (uint256) {
    return pContributors;
  }
  // Token.PclPicosAllocated()
  function PclPicosAllocated() external view returns (uint256) {
    return pPclPicosAllocated;
  }
  // Token.IsSaleOpen()
  function IsSaleOpen() external view returns (bool) {
    return pSaleOpenB;
  }
  // Token.IsTransferAllowedByDefault()
  function IsTransferAllowedByDefault() external view returns (bool) {
    return iListC.IsTransferAllowedByDefault();
  }

  // State changing external methods
  // ===============================

  // Token.Issue()
  // -------------
  // To be called:
  // . By Hub.PresaleIssue() -> Sale.PresaleIssue() -> here for all Seed Presale and Private Placement pContributors (aggregated) to initialise the DAICO for tokens issued in the Seed Presale and the Private Placement`
  //   List entry is created by Hub.Presale.Issue() which checks toA
  // . from Sale.Buy() which checks toA
  function Issue(address toA, uint256 vPicos, uint256 vWei) external IsSaleCaller IsActive returns (bool) {
    if (iListC.PicosBought(toA) == 0)
      pContributors++;
    iListC.Issue(toA, vPicos, vWei); // Transfers from Sale as the minted tokens owner
    pPicosIssued    = safeAdd(pPicosIssued,    vPicos);
    pPicosAvailable = safeSub(pPicosAvailable, vPicos); // Should never go neg due to reserve, even if final Buy() goes over the hardcap
    pWeiRaised      = safeAdd(pWeiRaised, vWei);
    // No event emit as iListC.Issue() does it
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
  function Burn() external IsMvpCaller {
    require(!pSaleOpenB, "Sale not closed");
    uint256 picos = iListC.PicosBalance(tx.origin);
  //require(picos > 0, "No PIOEs to burn"); Not needed here as already done by Mvp.Burn()
    iListC.Burn(); // reverts if a tx.origin list entry doesn't exist
    pPicosIssued = subMaxZero(pPicosIssued, picos);
    totalSupply  = subMaxZero(totalSupply,  picos);
    // Does not affect pPicosAvailable or the Sale contract balance as these are issued tokens that are being burnt
  }

  // Token.Destroy()
  // ---------------
  // For use when transferring unissued PIOEs to PIOs
  // Is called by Mvp.Destroy() -> here to destroy unissued Sale picos
  // The event call is made by Mvp.Destroy()
  function Destroy(uint256 vPicos) external IsMvpCaller {
    require(!pSaleOpenB);
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
