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
  function PollSetSaleEndTime(uint32 vSaleEndT) external;
  function PollSetUsdSoftCap(uint32 vUsdSoftCap) external;
  function PollSetPioSoftCap(uint32 vUsdSoftCap) external;
  function PollSetUsdHardCap(uint32 vUsdHardCap) external;
  function PollSetPioHardCap(uint32 vUsdHardCap) external;
}
// End I_SalePoll interface

