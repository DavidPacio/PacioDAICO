// \lib\OwnedByOpManAndHub.sol

// Version of Owned owned by OpMan and Hub for use with the Sale, VoteTap, VoteEnd, and Mvp contracts
// Is pausable

pragma solidity ^0.4.24;

import "./Constants.sol";
import "../OpMan/I_OpMan.sol";

contract Owned is Constants {
  uint256 internal constant NUM_OWNERS = 2;
  bool    internal iInitialisingB = true; // Starts in the initialising state
  bool    internal iPausedB = true;       // Starts paused
  address[NUM_OWNERS] internal iOwnersYA; // 0 OpMan owner
                                          // 1 Hub  owner
                                          // |- owner X
  // Constructor NOT payable
  // -----------
  constructor() internal {
    iOwnersYA = [msg.sender, msg.sender];
  }

  // View Methods
  // ------------
  function Owners() external view returns (address[NUM_OWNERS]) {
    return iOwnersYA;
  }
  function Paused() external view returns (bool) {
    return iPausedB;
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
  // Called by OpMan.ChangeContractOwnerMO(vContractX, vOwnerX) IsAdminOwner IsConfirmedSigner which is a managed op
  // Can be called during deployment when iInitialisingB is set and msg.sender is the same as that for the constructor call to set the owners, if OpMan is set last.
  function ChangeOwnerMO(uint256 vOwnerX, address vNewOwnerA) external IsOpManOwner {
    require((iInitialisingB || I_OpMan(iOwnersYA[0]).IsManOpApproved(CHANGE_OWNER_BASE_X + vOwnerX))
         && vNewOwnerA != iOwnersYA[0]
         && vNewOwnerA != iOwnersYA[1]);
    emit ChangeOwnerV(iOwnersYA[vOwnerX], vNewOwnerA, vOwnerX);
    iOwnersYA[vOwnerX] = vNewOwnerA;
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
    require(I_OpMan(iOwnersYA[0]).IsManOpApproved(RESUME_X));
    iPausedB = false;
    emit ResumedV();
  }
} // End Owned contract - OwnedByOpManAndHub.sol version
