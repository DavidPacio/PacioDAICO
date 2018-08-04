/* \Escrow\I_EscrowHub.sol started 2018.07.11

Interface for the Escrow contract external functions which are called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_EscrowHub {
  function EscrowWei() external view returns (uint256);
  function StartSale() external;
  function SoftCapReached() external;
  function EndSale() external;
  function RefundInfo(address accountA, uint256 vRefundId) external returns (uint256 refundWei, uint32 refundBit);
  function Refund(address toA, uint256 vRefundWei, uint256 vRefundId) external returns (bool);
  function Terminate(uint256 vPicosIssued) external;
}
// End I_EscrowHub interface
