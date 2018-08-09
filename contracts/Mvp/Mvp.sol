/* \Mvp\Mvp.sol 2018.07.13 started

The MVP launch contract for the Pacio DAICO

Owned by Deployer, OpMan, Hub, Admin

djh??
To be completed


Calls
OpMan
List
Token -> List

Pause/Resume
============
OpMan.PauseContract(MVP_CONTRACT_X) IsHubContractCallerOrConfirmedSigner
OpMan.ResumeContractMO(MVP_CONTRACT_X) IsConfirmedSigner which is a managed op

Mvp Fallback function
=====================
Sending Ether is not allowed

*/

pragma solidity ^0.4.24;

import "../lib/OwnedByOpManAndHub.sol";
import "../Token/I_TokenMvp.sol";
import "../List/I_ListMvp.sol";

contract Mvp is OwnedByOpManAndHub {
  string  public name = "Pacio MVP Launch"; // contract name
  uint32  private pState;     // DAICO state using the STATE_ bits. Replicated from Hub only on a on a change
  I_ListMvp  private pListC;  // the List contract
  I_TokenMvp private pTokenC; // the Token contract

  // View Methods
  // ============
  // Mvp.State()
  function State() external view returns (uint32) {
    return pState;
  }

  // Events
  // ======
  event TransferIssuedPIOsToPacioBcV(address Account, uint256 Picos);
  event TransferUnIssuedPIOsToPacioBcV(uint256 Picos);

  // Initialisation/Setup Functions
  // ==============================
  // Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Admin
  // Owners must first be set by deploy script calls:
  //   Mvp.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
  //   Mvp.ChangeOwnerMO(HUB_OWNER_X, Hub address)
  //   Mvp.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)

  // Mvp.Initialise()
  // ----------------
  // Called from the deploy script to initialise the Mvp contract
  function Initialise() external IsInitialising {
    I_OpMan opManC = I_OpMan(iOwnersYA[OP_MAN_OWNER_X]);
    pTokenC = I_TokenMvp(opManC.ContractXA(TOKEN_CONTRACT_X));
    pListC  =  I_ListMvp(opManC.ContractXA(LIST_CONTRACT_X));
  //iPausedB       =         // leave inactive
    iInitialisingB = false;
  }

  // State changing external methods
  // ===============================

  // Mvp.TransferIssuedPIOsToPacioBc()
  // -----------------------------------------
  // For use when transferring issued PIOs to the Pacio Blockchain.
  // Is to be called by the owner of the PIOs. This will need to be integrated with an import of the PIOs into the Pacio Blockchain
  // Must be in the STATE_TRANSFER_TO_PB_B state for this to run.
  function TransferIssuedPIOsToPacioBc() external IsNotContractCaller {
    require(pState & STATE_TRANSFER_TO_PB_B > 0, 'Not in Transfer to PB state');
    uint256 picos = pListC.PicosBalance(msg.sender);
    require(picos > 0, "No PIOEs to transfer"); // is also a check for account existing
    pTokenC.TransferIssuedPIOsToPacioBc(msg.sender);
    emit TransferIssuedPIOsToPacioBcV(msg.sender, picos);
  }

  // Mvp.TransferUnIssuedPIOsToPacioBcMO()
  // ---------------------------------------------
  // For use when transferring unissued PIOs to the Pacio Blockchain
  // Is to be called by Admin as a managed operation
  // Must be in the STATE_TRANSFERRED_TO_PB_B state for this to run.
  function TransferUnIssuedPIOsToPacioBcMO(uint256 vPicos) external IsAdminCaller {
    require(pState & STATE_TRANSFERRED_TO_PB_B > 0, 'Not in Transferred to PB state');
    require(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(MVP_TRAN_UNISSUED_TO_PB_MO_X));
    pTokenC.TransferUnIssuedPIOsToPacioBc(vPicos);
    emit TransferUnIssuedPIOsToPacioBcV(vPicos);
  }

  // Mvp Fallback function
  // =====================
  // Not payable so trying to send ether will throw
  function() external {
    revert(); // reject any attempt to access the Mvp contract other than via the defined methods with their testing for valid access
  }

} // End Mvp contract

