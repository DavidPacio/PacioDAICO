/* \Escrow\I_EscrowHub.sol started 2018.07.11

Interface for the Escrow contract external functions which are called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_EscrowHub {
  function EscrowWei() external view returns (uint256);
  function RefundInfo(address accountA, uint256 vRefundId) external returns (uint256 refundPicos, uint256 refundWei, uint32 refundBit);
  function Refund(address toA, uint256 vRefundPicos, uint256 vRefundWei, uint32 refundBit, uint256 vRefundId) external returns (bool);
}
// End I_EscrowHub interface
