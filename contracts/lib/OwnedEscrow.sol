// lib\OwnedEscrow.sol
//
// Version of Owned for Escrow and Grey which is owned by Deployer, OpMan, Hub, Sale, Admin
// Is pausable

pragma solidity ^0.4.24;

import "./Constants.sol";
import "../OpMan/I_OpMan.sol";

contract OwnedEscrow is Constants {
  uint256 internal constant NUM_OWNERS = 5;
  bool    internal iInitialisingB = true; // Starts in the initialising state
  bool    internal iPausedB = true;       // Starts paused
  address[NUM_OWNERS] internal iOwnersYA; // 0 Deployer
                                          // 1 OpMan owner
                                          // 2 Hub owner
                                          // 3 Sale  owner
                                          // 4 Admin owner
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
  function iIsOpManCallerB() private view returns (bool) {
    return msg.sender == iOwnersYA[OP_MAN_OWNER_X];
  }
  function iIsAdminCallerB() internal view returns (bool) {
    return msg.sender == iOwnersYA[ESCROW_ADMIN_OWNER_X];
  }

  // Modifier functions
  // ------------------
  modifier IsInitialising {
    require(iIsInitialisingB(), "Not initialising");
    _;
  }
  modifier IsOpManCaller {
    require(iIsOpManCallerB(), "Not required OpMan caller");
    _;
  }
  modifier IsHubCaller {
    require(msg.sender == iOwnersYA[HUB_OWNER_X], "Not required Hub caller");
    _;
  }
  modifier IsSaleCaller {
    require(msg.sender == iOwnersYA[SALE_OWNER_X], "Not required Sale caller");
    _;
  }
  modifier IsAdminCaller {
    require(iIsAdminCallerB(), "Not required Admin caller");
    _;
  }
  modifier IsActive {
    require(!iPausedB, "Contract is Paused");
    _;
  }
  modifier IsNotContractCaller {
    address callerA = msg.sender; // need this because compilation fails on the '.' for extcodesize(msg.sender)
    uint256 codeSize;
    assembly {codeSize := extcodesize(callerA)}
    require(codeSize == 0, 'No contract callers');
    _;
  }

  // Events
  // ------
  event ChangeOwnerV(address indexed PreviousOwner, address NewOwner, uint256 OwnerId);
  event PausedV();
  event ResumedV();

  // State changing external methods
  // -------------------------------
  // ChangeOwnerMO()
  // ---------------
  // Called by OpMan.ChangeContractOwnerMO(vContractX, vOwnerX) IsAdminCaller IsConfirmedSigner which is a managed op
  // Can be called directly during deployment when initialising
  function ChangeOwnerMO(uint256 vOwnerX, address vNewOwnerA) external {
    require(iIsInitialisingB() || (iIsOpManCallerB() && I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(vOwnerX)));
    for (uint256 j=0; j<NUM_OWNERS; j++)
      require(vNewOwnerA != iOwnersYA[j], 'Duplicate owner');
    emit ChangeOwnerV(iOwnersYA[vOwnerX], vNewOwnerA, vOwnerX);
    iOwnersYA[vOwnerX] = vNewOwnerA;
  }

  // Pause()
  // -------
  // Called by OpMan.PauseContract(vContractX) IsHubCallerOrConfirmedSigner. Not a managed op.
  function Pause() external IsOpManCaller IsActive {
    iPausedB = true;
    emit PausedV();
  }

  // ResumeMO()
  // ----------
  // Called by OpMan.ResumeContractMO(vContractX) IsConfirmedSigner which is a managed op
  function ResumeMO() external IsOpManCaller {
    require(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(RESUME_X));
    iPausedB = false;
    emit ResumedV();
  }
} // End OwnedEscrow contract
