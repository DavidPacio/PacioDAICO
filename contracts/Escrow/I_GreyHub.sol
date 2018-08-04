/* \Escrow\I_GreyHub.sol started 2018.07.11

Interface for the Grey contract external functions which are called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_GreyHub {
  function EscrowWei() external view returns (uint256);
  function EndSale() external;
  function RefundInfo(address accountA, uint256 vRefundId) external returns (uint256 refundWei, uint32 refundBit);
  function Refund(address toA, uint256 vRefundWei, uint256 vRefundId) external returns (bool);
}
// End I_GreyHub interface
