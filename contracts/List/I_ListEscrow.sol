/* \List\I_ListHub.sol

Interface for the List contract external functions which are called from the Escrow annd Grey escrow contracts.

*/

pragma solidity ^0.4.24;

interface I_ListEscrow {
  function ContributedWei(address accountA) external view returns (uint256);
  function Refund(address vSenderA, uint256 vRefundWei, uint8 vEscrowStateN) external returns (uint256 refundWei);
}
// End I_ListEscrow interface
