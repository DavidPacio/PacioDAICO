/* \Escrow\I_PescrowHub.sol started 2018.07.11

Interface for the Pescrow contract external functions which are called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_PescrowHub {
  function EscrowWei() external view returns (uint256);
  function StateChange(uint32 vState) external;
  function Refund(uint256 vRefundId, address toA, uint256 vRefundWei) external returns (bool);
  function Refund(uint256 vRefundId, address toA, uint256 vRefundWei, uint32 vRefundBit) external returns (bool);
}
// End I_PescrowHub interface
