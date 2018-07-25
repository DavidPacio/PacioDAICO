// lib\OwnedList.sol
//
// Version of Owned for List which is owned by OpMan, Hub, Sale, Token
// Is NOT pausable

pragma solidity ^0.4.24;

import "./Constants.sol";
import "../OpMan/I_OpMan.sol";

contract Owned is Constants {
  uint256 internal constant NUM_OWNERS = 3;
  bool    internal iInitialisingB = true; // Starts in the initialising state
  address[NUM_OWNERS] internal iOwnersYA; // 0 OpMan owner, in this OpMan case is self
                                          // 1 Hub   owner
                                          // 2 Token owner
                                          // |- owner X
  // Constructor NOT payable
  // -----------
  constructor() internal {
    iOwnersYA = [msg.sender, msg.sender, msg.sender];
  }

  // View Methods
  // ------------
  function Owners() external view returns (address[NUM_OWNERS]) {
    return iOwnersYA;
  }
  function Initialising() external view returns (bool) {
    return iInitialisingB;
  }

  // Modifier functions
  // ------------------
  modifier IsOpManOwner {
    require(msg.sender == iOwnersYA[0], "Not required OpMan caller");
    _;
  }
  modifier IsHubOwner {
    require(msg.sender == iOwnersYA[1], "Not required Hub caller");
    _;
  }
  modifier IsTokenOwner {
    require(msg.sender == iOwnersYA[2], "Not required Token caller");
    _;
  }

  // Events
  // ------
  event ChangeOwnerV(address indexed PreviousOwner, address NewOwner, uint256 OwnerId);

  // State changing external methods
  // -------------------------------
  // ChangeOwnerMO()
  // ---------------
  // Called by OpMan.ChangeContractOwnerMO(vContractX, vOwnerX) IsAdminOwner IsConfirmedSigner which is a managed op
  // Can be called during deployment when iInitialisingB is set and msg.sender is the same as that for the constructor call to set the owners, if OpMan is set last.
  function ChangeOwnerMO(uint256 vOwnerX, address vNewOwnerA) external IsOpManOwner {
    require((iInitialisingB || I_OpMan(iOwnersYA[0]).IsManOpApproved(CHANGE_OWNER_BASE_X + vOwnerX))
         && vNewOwnerA != iOwnersYA[0]
         && vNewOwnerA != iOwnersYA[1]
         && vNewOwnerA != iOwnersYA[2]);
    emit ChangeOwnerV(iOwnersYA[vOwnerX], vNewOwnerA, vOwnerX);
    iOwnersYA[vOwnerX] = vNewOwnerA;
  }

} // End Owned contract - OwnedList.sol version
