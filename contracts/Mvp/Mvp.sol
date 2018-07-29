/* \Mvp\Mvp.sol 2018.07.13 started

The MVP launch contract for the Pacio DAICO

Owned by Deployer, OpMan, Hub

djh??
To be completed


Calls
OpMan
List
Token -> List

View Methods
============

Initialisation/Setup Functions
==============================

State changing external methods
===============================

Mvp Fallback function
=====================
Sending Ether is not allowed

Events
======
*/

pragma solidity ^0.4.24;

import "../lib/OwnedByOpManAndHub.sol";
import "../Token/I_TokenMvp.sol";
import "../List/I_ListMvp.sol";


contract Mvp is Owned {
  string  public name = "Pacio MVP Launch"; // contract name
  uint32  private pBurnId; // Id for Burns, starting from 1, incremented for each burn,
  I_ListMvp  private pListC;  // the List contract
  I_TokenMvp private pTokenC; // the Token contract

  // Initialisation/Setup Functions
  // ==============================
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub
  // Owners must first be set by deploy script calls:
  //   Mvp.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Mvp.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address) <=== Must come after HUB_OWNER_X have been set

  // Mvp.Initialise()
  // ----------------
  // Called from the deploy script to initialise the Mvp contract
  function Initialise() external IsDeployerCaller {
    require(iInitialisingB); // To enforce being called only once
    I_OpMan opManC = I_OpMan(iOwnersYA[OP_MAN_OWNER_X]);
    pTokenC = I_TokenMvp(opManC.ContractXA(TOKEN_X));
    pListC  =  I_ListMvp(opManC.ContractXA(LIST_X));
  //iPausedB       =         // leave inactive
    iInitialisingB = false;
  }

  // Events
  // ======
  event BurnV(uint32 indexed BurnId, address Account, uint256 Picos); // indexed by BurnId to facilitate monitoring for transferring to PIOs
  event DestroyV(uint256 Picos);

  // View Methods
  // ============
  // Mvp.BurnId()
  function BurnId() external view returns (uint32) {
    return pBurnId;
  }

  // State changing external methods
  // ===============================

  // Mvp.Burn()
  // ----------
  // For use when transferring issued PIOEs to PIOs. Burns picos held for msg.sender
  // Is to be called by the owner of the tokens. This will need to be integrated with an import into the Pacio Blockchain as PIOs
  function Burn() external {
    uint256 picos = pListC.PicosBalance(msg.sender);
    require(picos > 0, "No PIOEs to burn");
    pTokenC.Burn();
    emit BurnV(++pBurnId, msg.sender, picos);
  }

  // Mvp.Destroy()
  // -------------
  // For use when transferring unissued PIOEs to PIOs
  // Is to be called from Hub.Destroy()
  function Destroy(uint256 vPicos) external IsHubCaller {
    pTokenC.Destroy(vPicos);
    emit DestroyV(vPicos);
  }

  // Mvp Fallback function
  // =====================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Mvp contract other than via the defined methods with their testing for valid access
  }

} // End Mvp contract

