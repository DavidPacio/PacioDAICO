// lib\OwnedList.sol
//
// Version of Owned for List which is owned by Deployer OpMan Hub Token Sale Poll
// Is NOT pausable

pragma solidity ^0.4.24;

import "./Constants.sol";

contract OwnedList is Constants {
  uint256 internal constant NUM_OWNERS = 6;
  bool    internal iInitialisingB = true; // Starts in the initialising state
  address[NUM_OWNERS] internal iOwnersYA;

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
  function pIsContractCallerB() private view returns (bool) {
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
  modifier IsHubContractCaller {
    require(msg.sender == iOwnersYA[HUB_OWNER_X] && pIsContractCallerB(), "Not required Hub caller");
    _;
  }
  modifier IsSaleContractCaller {
    require(msg.sender == iOwnersYA[SALE_OWNER_X] && pIsContractCallerB(), "Not required Sale caller");
    _;
  }
  modifier IsPollContractCaller {
    require(msg.sender == iOwnersYA[LIST_POLL_OWNER_X] && pIsContractCallerB(), "Not required Poll caller");
    _;
  }
  modifier IsTokenContractCaller {
    require(msg.sender == iOwnersYA[TOKEN_OWNER_X] && pIsContractCallerB(), "Not required Token caller");
    _;
  }

  // Events
  // ------
  event ChangeOwnerV(address indexed PreviousOwner, address NewOwner, uint256 OwnerId);

  // State changing external methods
  // -------------------------------
  // SetOwnerIO()
  // ------------
  // Can be called only during deployment when initialising
  function SetOwnerIO(uint256 vOwnerX, address ownerA) external IsInitialising {
    for (uint256 j=0; j<NUM_OWNERS; j++)
      require(ownerA != iOwnersYA[j], 'Duplicate owner');
    emit ChangeOwnerV(0x0, ownerA, vOwnerX);
    iOwnersYA[vOwnerX] = ownerA;
  }

} // End OwnedList contract
