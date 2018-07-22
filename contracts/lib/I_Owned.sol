// \lib\I_Owned.sol 2018.007.21 started
//
// Interface for the Owned contracts for the external functions called from OpMan
//
pragma solidity ^0.4.24;
interface I_Owned {
  function ChangeOwnerMO(uint256 vOwnerId, address vNewOwnerA) external;
  function Pause() external;
  function ResumeMO() external;
}
// End I_Owned interface
