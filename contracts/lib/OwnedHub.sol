// lib\OwnedHub.sol
//
// Version of Owned for Hub which is owned by 0 Deployer, 1 OpMan, 2 Admin, 3 Sale, 4 VoteTap, 5 VoteEnd, 6 Web
// Is pausable

pragma solidity ^0.4.24;

import "./Constants.sol";
import "../OpMan/I_OpMan.sol";

contract OwnedHub is Constants {
  uint256 internal constant NUM_OWNERS = 7;
  bool    internal iInitialisingB = true; // Starts in the initialising state
  bool    internal iPausedB = true;       // Starts paused
  address[NUM_OWNERS] internal iOwnersYA; // 0 Deployer
                                          // 1 OpMan owner
                                          // 2 Admin owner
                                          // 3 Sale  owner
                                          // 4 VoteTap owner
                                          // 5 VoteEnd owner
                                          // 6 Web   owner
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
  function iIsAdminCallerB() internal view returns (bool) {
    return msg.sender == iOwnersYA[ADMIN_OWNER_X] && !pIsContractCallerB();
  }
  function iIsSaleContractCallerB() internal view returns (bool) {
    return msg.sender == iOwnersYA[SALE_OWNER_X] && pIsContractCallerB();
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
  modifier IsAdminCaller {
    require(iIsAdminCallerB(), "Not required Admin caller");
    _;
  }
  modifier IsSaleContractCaller {
    require(iIsSaleContractCallerB(), "Not required Sale caller");
    _;
  }
  modifier IsVoteTapContractCaller {
    require(msg.sender == iOwnersYA[VOTE_TAP_OWNER_X] && pIsContractCallerB(), "Not required VoteTap caller");
    _;
  }
  modifier IsVoteEndContractCaller {
    require(msg.sender == iOwnersYA[VOTE_END_OWNER_X] && pIsContractCallerB(), "Not required VoteEnd caller");
    _;
  }
  modifier IsWebOrAdminCaller {
    require((msg.sender == iOwnersYA[WEB_OWNER_X] || msg.sender == iOwnersYA[ADMIN_OWNER_X]) && !pIsContractCallerB(), "Not required Web or Admin caller");
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
} // End OwnedHub contract
