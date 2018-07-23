// lib\OwnedOpMan.sol
//
// Version of Owned for OpMan which is owned by self and an Admin account
// Is pausable

pragma solidity ^0.4.24;

import "./Constants.sol";

contract Owned is Constants {
  uint256 internal constant NUM_OWNERS = 2;
  bool    internal iPausedB = true;       // Starts paused
  address[NUM_OWNERS] internal iOwnersYA; // 1 OpMan owner, in this OpMan case is self
                                          // 2 Admin owner
                                          // |- owner Id
  // Constructor NOT payable
  // -----------
  constructor() internal {
    iOwnersYA = [address(this), msg.sender];
  }

  // View Methods
  // ------------
  function Owners() external view returns (address[NUM_OWNERS]) {
    return iOwnersYA;
  }
  function Paused() external view returns (bool) {
    return iPausedB;
  }

  // Modifier functions
  // ------------------
  modifier IsOpManOwner {
    require(msg.sender == iOwnersYA[0], "Not required OpMan caller");
    _;
  }
  modifier IsAdminOwner {
    require(msg.sender == iOwnersYA[1], "Not required Admin caller");
    _;
  }
  modifier IsActive {
    require(!iPausedB, "Contract is Paused");
    _;
  }

  // Events
  // ------
  event ChangeOwnerV(address indexed PreviousOwner, address NewOwner, uint256 OwnerId);
  event PausedV();
  event ResumedV();

  // State changing external methods
  // -----------------------------
  // ChangeOwnerMO()
  // ---------------
  // Called by OpMan.ChangeContractOwnerMO(vContractX, vOwnerId) IsAdminOwner IsConfirmedSigner which is a managed op
  function ChangeOwnerMO(uint256 vOwnerId, address vNewOwnerA) public IsOpManOwner {
  //require((vOwnerId == 1 || vOwnerId == 2) // /- done by OpMan.ChangeContractOwnerMO()
  //     && vNewOwnerA != address(0));       // |
    require(vNewOwnerA != iOwnersYA[0]
         && vNewOwnerA != iOwnersYA[1]);
    emit ChangeOwnerV(iOwnersYA[vOwnerId-1], vNewOwnerA, vOwnerId);
    iOwnersYA[vOwnerId-1] = vNewOwnerA;
  }

  // Pause()
  // -------
  // Called by OpMan.Pause(vContractX) IsConfirmedSigner. Not a managed op.
  function Pause() external IsOpManOwner IsActive {
    iPausedB = true;
    emit PausedV();
  }

  // ResumeMO()
  // ----------
  // Called by OpMan.ResumeContractMO(vContractX) IsConfirmedSigner which is a managed op
  function ResumeMO() external IsOpManOwner {
    iPausedB = false;
    emit ResumedV();
  }
} // End Owned contract
