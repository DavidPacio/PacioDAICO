/* \Sale\I_SalePoll.sol 2018.07.13 started

Interface for the Sale contract for the external functions called from the Poll contract.

*/

pragma solidity ^0.4.24;

interface I_SalePoll {
  function UsdSoftCap() external view returns (uint32);
  function UsdHardCap() external view returns (uint32);
  function SaleStartTime() external view returns (uint32);
  function PioSoftCap() external view returns (uint32);
  function PioHardCap() external view returns (uint32);
  function SaleEndTime() external view returns (uint32);
  function UsdRaised() external view returns (uint32);
  function PicosSold() external view returns (uint256);
}
// End I_SalePoll interface

