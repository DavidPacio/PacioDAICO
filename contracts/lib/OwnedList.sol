// lib\OwnedList.sol
//
// Version of Owned for List which is owned by Owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Token, 5 Escrow, 6 Grey
// Is NOT pausable

pragma solidity ^0.4.24;

import "./Constants.sol";
import "../OpMan/I_OpMan.sol";

contract OwnedList is Constants {
  uint256 internal constant NUM_OWNERS = 7;
  bool    internal iInitialisingB = true; // Starts in the initialising state
  address[NUM_OWNERS] internal iOwnersYA; // 0 Deployer
                                          // 1 OpMan  owner
                                          // 2 Hub    owner
                                          // 3 Sale   owner
                                          // 4 Token  owner
                                          // 5 Escrow owner
                                          // 6 Grey   owner
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
  function iIsInitialisingB() internal view returns (bool) {
    return iInitialisingB && msg.sender == iOwnersYA[DEPLOYER_X];
  }
  function iIsOpManCallerB() private view returns (bool) {
    return msg.sender == iOwnersYA[OP_MAN_OWNER_X];
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
  modifier IsTokenCaller {
    require(msg.sender == iOwnersYA[TOKEN_OWNER_X], "Not required Token caller");
    _;
  }
  modifier IsEscrowOrGreyCaller {
    require(msg.sender == iOwnersYA[ESCROW_OWNER_X] || msg.sender == iOwnersYA[GREY_OWNER_X], "Not required Escrow caller");
    _;
  }

  // Events
  // ------
  event ChangeOwnerV(address indexed PreviousOwner, address NewOwner, uint256 OwnerId);

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

} // End OwnedList contract
