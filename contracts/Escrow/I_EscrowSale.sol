/* \Escrow\I_EscrowSale.sol started 2018.07.11

Interface for the Escrow contract external functions which are called from the Sale contract.

*/

pragma solidity ^0.4.24;

interface I_EscrowSale {
  function EscrowWei() external view returns (uint256);
  function Deposit(address vSenderA) external payable;
  function EndSale() external;
}
// End I_EscrowSale interface
