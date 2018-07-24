/* \Token\Token.sol 2018.06.04 started

The Pacio Token named PIOE for the Pacio DAICO

Called from 4 owners:
0 OpMan.sol
1 Hub.sol
2 Sale.sol
3 Mvp.sol for burning/destroying with the transfer of PIOEs to PIOs

Calls
List.sol as the contract for the list of participants

djh??


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
Token.Initialise(address vListA) external IsHubOwner {

State changing external methods
===============================
Token.Issue(address toA, uint256 vPicos, uint256 vWei) external IsOwner2 returns (bool)

Functions for calling via same name function in Hub
===================================================
Token.NewSaleContract(address vNewSaleContractA) external // IsOwner2 c/o the ChangeOwner() call
Token.NewListContract(address vNewListContractA) external IsHubOwner
Token.NewTokenContract(address vNewTokenContractA) external IsHubOwner
Token.EndSale() external IsHubOwner IsActive

Functions for calling via same name function in Mvp
===================================================
Token.Burn() external IsMvpOwner
Token.Destroy(uint256 vPicos) external IsMvpOwner

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
  // To be called by Hub.Initialise()
  // Can only be called once.
  // 0. OpMan.sol
  // 1. Hub.sol
  // 2. Sale.sol
  // 3. Mvp.sol for burning/destroying with the transfer of PIOEs to PIOs
  // Token Owner 1 must have been set to Hub   via a deployment call of Token.ChangeOwnerMO(1, Hub address)
  // Token Owner 2 must have been set to Sale  via a deployment call of Token.ChangeOwnerMO(2, Sale address)
  // Token Owner 3 must have been set to Mvp   via a deployment call of Token.ChangeOwnerMO(3, Mvp address)
  // Token Owner 0 must have been set to OpMan via a deployment call of Token.ChangeOwnerMO(0, OpMan address) <=== Must come after 1, 2, 3 have been set
  // List  Owner 3 must have been set to Token via a deployment call of  List.ChangeOwnerMO(3, Token address)
  function Initialise() external IsHubOwner {
    require(uInitialisingB); // To enforce being called only once
    iPausedB = false; // make active
    iListC   = I_ListToken(I_OpMan(iOwnersYA[0]).ContractXA(LIST_X)); // The List contract
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
    emit Transfer(0x0, iOwnersYA[2], 10**21); // log event 0x0 from == minting. iOwnersYA[2] is the Sale contract
    uInitialisingB = false;
  }
  // Token.StartSale()
  // ---------------
  // Is called from Hub
  function StartSale() external IsHubOwner IsActive {
    pSaleOpenB = true;
    emit StartSaleV();
  }
  // Token.EndSale()
  // ---------------
  // Is called from Sale via Hub after hard cap is reached, time has expired, or the sale is ended manually
  function EndSale() external IsHubOwner IsActive {
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
  // . Repeatedly via Hub.PresaleIssue() -> Sale.PresaleIssue() -> here for all Seed Presale and Private Placement pContributors (aggregated) to initialise the DAICO for tokens issued in the Seed Presale and the Private Placement`
  //   List entry is created by Hub.Presale.Issue() which checks toA
  // . from Sale.Buy() which checks toA
  function Issue(address toA, uint256 vPicos, uint256 vWei) external IsSaleOwner IsActive returns (bool) {
    if (iListC.PicosBought(toA) == 0)
      pContributors++;
    iListC.Issue(toA, vPicos, vWei); // Transfers from Sale as the minted tokens owner
    pPicosIssued    = safeAdd(pPicosIssued,    vPicos);
    pPicosAvailable = safeSub(pPicosAvailable, vPicos); // Should never go neg due to reserve, even if final Buy() goes over the hardcap
    pWeiRaised      = safeAdd(pWeiRaised, vWei);
    // No event emit as iListC.Issue() does it
    return true;
  }

  // Functions for manual calling via same name function in Hub()
  // ============================================================
/*
Wip djh?? To be completed
  // Token.NewSaleContract()
  // -----------------------
  // Called manually via the old Sale.NewSaleContract() to change the owner of the Token contract to a new Sale.
  // Transfers any minted tokens from old Sale to new Sale
  function NewSaleContract(address vNewSaleContractA) external { // IsOwner2 check c/o the ChangeOwner2() call
    // Create a new sale contract entry with the current PicosBalance
    iListC.CreateSaleContractEntry(0);
    iListC.TransferSaleContractBalance(vNewSaleContractA);
    emit Transfer(iOwnersYA[2], vNewSaleContractA, iListC.PicosBalance(iOwnersYA[2])); // iOwnersYA[2] is still the old Sale
    //djh?? this.ChangeOwner(2, vNewSaleContractA); // Change Token contract's Owner2 to the new Sale contract
  }

  // Token.NewListContract()
  // -----------------------
  // To be called manually via Hub.NewListContract() if the List contract is changed. vNewListContractA is checked and logged by Sale.NewListContract()
  // Only to be done if a new list contract has been constructed and data transferred
  function NewListContract(address vNewListContractA) external IsHubOwner {
    iListC = I_ListToken(vNewListContractA); // The List contract
  }

  // Token.NewTokenContract()
  // ------------------------
  // To be called manually via Hub.NewTokenContract() to change Owner2 of the List contract to the new Token contract
  function NewTokenContract(address vNewTokenContractA) external IsHubOwner {
    //djh?? iListC.ChangeOwner(2, vNewTokenContractA);
  }
*/

  // Functions for calling via same name function in Mvp
  // ===================================================
  // Token.Burn()
  // ------------
  // For use when transferring issued PIOEs to PIOs. Burns the picos held by tx.origin
  // Is called by Mvp.Burn() -> here thus use of tx.origin rather than msg.sender
  // There is no security risk associated with the use of tx.origin here as it is not used in any ownership/authorisation test
  // The event call is made by Mvp.Burn()
  function Burn() external IsMvpOwner {
    require(!pSaleOpenB, "Sale not closed");
    uint256 picos = iListC.PicosBalance(tx.origin);
  //require(picos > 0, "No PIOEs to burn"); Not needed here as already done by Mvp.Burn()
    iListC.Burn(); // reverts if a tx.origin list entry doesn't exist
    pPicosIssued = subMaxZero(pPicosIssued, picos);
    totalSupply  = subMaxZero(totalSupply,  picos);
    // Does not affect pPicosAvailable or the Sale (iOwnerA) balance as these are issued tokens that are being burnt
  }

  // Token.Destroy()
  // ---------------
  // For use when transferring unissued PIOEs to PIOs
  // Is called by Mvp.Destroy() -> here to destroy unissued Sale picos
  // The event call is made by Mvp.Destroy()
  function Destroy(uint256 vPicos) external IsMvpOwner {
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
