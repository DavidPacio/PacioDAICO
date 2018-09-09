// lib\OwnedSale.sol
//
// Version of Owned for Sale which is owned by Deployer, OpMan, Hub, Admin, Poll
// Is pausable

pragma solidity ^0.4.24;

import "./Constants.sol";

contract OwnedSale is Constants {
  uint256 internal constant NUM_OWNERS = 5;
  bool    internal iInitialisingB = true; // Starts in the initialising state
  bool    internal iPausedB = true;       // Starts paused
  address[NUM_OWNERS] internal iOwnersYA; // 0 Deployer
                                          // 1 OpMan owner
                                          // 2 Hub owner
                                          // 3 Admin owner
                                          // 4 Poll owner
                                          // |- owner X
  // Constructor NOT payable
  // -----------
  constructor() internal {
    iOwnersYA[DEPLOYER_X] = msg.sender;  // only need Deployer to be set here
  }

  // View Methods
  // ------------
  function Owners() external view returns (address[NUM_OWNERS]) {
    return iOwnersYA;
  }
  function Paused() external view returns (bool) {
    return iPausedB;
  }
  function iIsInitialisingB() internal view returns (bool) {
    return iInitialisingB && msg.sender == iOwnersYA[DEPLOYER_X];
  }
  function pIsOpManContractCallerB() private view returns (bool) {
    return msg.sender == iOwnersYA[OPMAN_OWNER_X] && pIsContractCallerB();
  }
  function iIsAdminCallerB() internal view returns (bool) {
    return msg.sender == iOwnersYA[ADMIN_OWNER_X] && !pIsContractCallerB();
  }
  function pIsContractCallerB() private view returns (bool) {
    address callerA = msg.sender; // need this because compilation fails on the '.' for extcodesize(msg.sender)
    uint256 codeSize;
    assembly {codeSize := extcodesize(callerA)}
    return codeSize > 0;
  }

  // Modifier functions
  // ------------------
  modifier IsInitialising {
    require(iIsInitialisingB(), "Not initialising");
    _;
  }
  modifier IsOpManContractCaller {
    require(pIsOpManContractCallerB(), "Not required OpMan caller");
    _;
  }
  modifier IsHubContractCaller {
    require(msg.sender == iOwnersYA[HUB_OWNER_X] && pIsContractCallerB(), "Not required Hub caller");
    _;
  }
  modifier IsAdminCaller {
    require(iIsAdminCallerB(), "Not required Admin caller");
    _;
  }
  modifier IsPollContractCaller {
    require(msg.sender == iOwnersYA[SALE_POLL_OWNER_X] && pIsContractCallerB(), "Not required Poll caller");
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
} // End OwnedSale contract
