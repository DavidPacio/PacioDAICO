// lib\OwnedOpMan.sol
//
// Version of Owned for OpMan which is owned by Deployer Self Hub  Admin
// Is pausable

pragma solidity ^0.4.24;

import "./Constants.sol";

contract OwnedOpMan is Constants {
  uint256 internal constant NUM_OWNERS = 4;
  bool    internal iInitialisingB = true; // Starts in the initialising state
  bool    internal iPausedB = true;       // Starts paused
  address[NUM_OWNERS] internal iOwnersYA;

  // Constructor NOT payable
  // -----------
  constructor() internal {
    iOwnersYA = [msg.sender, address(this)];  // only need up to 1 OpMan to be set here
  }

  // View Methods
  // ------------
  function Owners() external view returns (address[NUM_OWNERS]) {
    return iOwnersYA;
  }
  function Paused() external view returns (bool) {
    return iPausedB;
  }
  function pIsOpManContractCallerB() private view returns (bool) {
    return msg.sender == iOwnersYA[OPMAN_OWNER_X] && iIsContractCallerB();
  }
  function iIsHubContractCallerB() internal view returns (bool) {
    return msg.sender == iOwnersYA[HUB_OWNER_X] && iIsContractCallerB();
  }

  function iIsContractCallerB() internal view returns (bool) {
    address callerA = msg.sender; // need this because compilation fails on the '.' for extcodesize(msg.sender)
    uint256 codeSize;
    assembly {codeSize := extcodesize(callerA)}
    return codeSize > 0;
  }

  // Modifier functions
  // ------------------
  modifier IsInitialising {
    require(iInitialisingB && msg.sender == iOwnersYA[DEPLOYER_X], "Not initialising");
    _;
  }
  modifier IsOpManContractCaller {
    require(pIsOpManContractCallerB(), "Not required OpMan caller");
    _;
  }
  modifier IsHubContractCaller {
    require(iIsHubContractCallerB(), "Not required Hub caller");
    _;
  }
  modifier IsAdminCaller {
    require(msg.sender == iOwnersYA[ADMIN_OWNER_X] && !iIsContractCallerB(), "Not required Admin caller");
    _;
  }
  modifier IsContractCaller {
    require(iIsContractCallerB(), "Not contract caller");
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
  // -------------------------------
  // SetOwnerIO()
  // ------------
  // Can be called only during deployment when initialising
  function SetOwnerIO(uint256 ownerX, address ownerA) external IsInitialising {
    for (uint256 j=0; j<NUM_OWNERS; j++)
      require(ownerA != iOwnersYA[j], 'Duplicate owner');
    emit ChangeOwnerV(0x0, ownerA, ownerX);
    iOwnersYA[ownerX] = ownerA;
  }

  // Pause()
  // -------
  // Called by OpMan.PauseContract(vContractX) IsHubContractCallerOrConfirmedSigner. Not a managed op.
  function Pause() external IsOpManContractCaller IsActive {
    iPausedB = true;
    emit PausedV();
  }

  // ResumeMO()
  // ----------
  // Called by OpMan.ResumeContractMO(vContractX) IsConfirmedSigner which is a managed op
  function ResumeMO() external IsOpManContractCaller {
    iPausedB = false;
    emit ResumedV();
  }
} // End OwnedOpMan contract
