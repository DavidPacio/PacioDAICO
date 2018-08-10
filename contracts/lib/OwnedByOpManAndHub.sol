// \lib\OwnedByOpManAndHub.sol

// Version of Owned owned by Deployer, OpMan, Hub, and Admin for use with the VoteTap, VoteEnd contracts
// Is pausable

pragma solidity ^0.4.24;

import "./Constants.sol";
import "../OpMan/I_OpMan.sol";

contract OwnedByOpManAndHub is Constants {
  uint256 internal constant NUM_OWNERS = 4;
  bool    internal iInitialisingB = true; // Starts in the initialising state
  bool    internal iPausedB = true;       // Starts paused
  address[NUM_OWNERS] internal iOwnersYA; // 0 Deployer
                                          // 1 OpMan owner
                                          // 2 Hub  owner
                                          // 3 Admin owner
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
    return msg.sender == iOwnersYA[OP_MAN_OWNER_X] && pIsContractCallerB();
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
  modifier IsAdminCaller {
    require(msg.sender == iOwnersYA[ADMIN_OWNER_X] && !pIsContractCallerB(), "Not required Admin caller");
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
  modifier IsNotContractCaller {
    require(!pIsContractCallerB(), 'No contract callers');
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
  // ChangeOwnerMO()
  // ---------------
  // Called by OpMan.ChangeContractOwnerMO(vContractX, vOwnerX) IsAdminCaller IsConfirmedSigner which is a managed op
  // Can be called directly during deployment when initialising
  function ChangeOwnerMO(uint256 vOwnerX, address vNewOwnerA) external {
    require(iIsInitialisingB() || (pIsOpManContractCallerB() && I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(vOwnerX)));
    for (uint256 j=0; j<NUM_OWNERS; j++)
      require(vNewOwnerA != iOwnersYA[j], 'Duplicate owner');
    emit ChangeOwnerV(iOwnersYA[vOwnerX], vNewOwnerA, vOwnerX);
    iOwnersYA[vOwnerX] = vNewOwnerA;
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
    require(I_OpMan(iOwnersYA[OP_MAN_OWNER_X]).IsManOpApproved(RESUME_MO_X));
    iPausedB = false;
    emit ResumedV();
  }
} // End OwnedOwnedByOpManAndHub contract
