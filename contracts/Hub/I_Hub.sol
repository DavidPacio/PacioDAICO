/* \Hub\I_Hub.sol 2018.007.13 started

Interface for the Hub contract for the external functions called from the Sale contract.

*/

pragma solidity ^0.4.24;

interface I_Hub {
  function StartSaleMO() external;
  function SoftCapReachedMO() external;
  function CloseSaleMO(uint32 vBit) external;
}
// End I_Hub interface

