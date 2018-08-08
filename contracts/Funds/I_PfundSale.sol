/* \Escrow\I_PescrowSale.sol started 2018.07.11

Interface for the Pescrow contract external functions which are called from the Sale contract.

*/

pragma solidity ^0.4.24;

interface I_PescrowSale {
  function EscrowWei() external view returns (uint256);
  function Deposit(address vSenderA) external payable;
}
// End I_PescrowSale interface
