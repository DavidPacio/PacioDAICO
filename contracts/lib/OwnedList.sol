// lib\OwnedList.sol
//
// Version of Owned for List which is owned by OpMan, Hub, Sale, Token
// Is NOT pausable

pragma solidity ^0.4.24;

import "./Constants.sol";

contract Owned is Constants {
  uint256 internal constant NUM_OWNERS = 4;
  address[NUM_OWNERS] internal iOwnersYA; // 0 OpMan owner, in this OpMan case is self
                                          // 1 Hub   owner
                                          // 2 Sale  owner
                                          // 3 Token owner
                                          // |- owner X
  // Constructor NOT payable
  // -----------
  constructor() internal {
    iOwnersYA = [msg.sender, msg.sender, msg.sender, msg.sender];
  }

  // View Methods
  // ------------
  function Owners() external view returns (address[NUM_OWNERS]) {
    return iOwnersYA;
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
  modifier IsSaleOwner {
    require(msg.sender == iOwnersYA[2], "Not required Sale caller");
    _;
  }
  modifier IsTokenOwner {
    require(msg.sender == iOwnersYA[3], "Not required Token caller");
    _;
  }

  // Events
  // ------
  event ChangeOwnerV(address indexed PreviousOwner, address NewOwner, uint256 OwnerId);

  // State changing external methods
  // -----------------------------
  // ChangeOwnerMO()
  // ---------------
  // Called by OpMan.ChangeContractOwnerMO(vContractX, vOwnerX) IsAdminOwner IsConfirmedSigner which is a managed op
  // Can be called during deployment when msg.sender is the same as that for the constructor call to set the owners if OpMan is set last.
  function ChangeOwnerMO(uint256 vOwnerX, address vNewOwnerA) external IsOpManOwner {
    require(vNewOwnerA != iOwnersYA[0]
         && vNewOwnerA != iOwnersYA[1]
         && vNewOwnerA != iOwnersYA[2]
         && vNewOwnerA != iOwnersYA[3]);
    emit ChangeOwnerV(iOwnersYA[vOwnerX], vNewOwnerA, vOwnerX);
    iOwnersYA[vOwnerX] = vNewOwnerA;
  }

} // End Owned contract - OwnedToken.sol version
