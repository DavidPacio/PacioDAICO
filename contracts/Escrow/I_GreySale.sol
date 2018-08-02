/* \Escrow\I_GreySale.sol started 2018.07.11

Interface for the Grey contract external functions which are called from the Sale contract.

*/

pragma solidity ^0.4.24;

interface I_GreySale {
  function EscrowWei() external view returns (uint256);
  function Deposit(address vSenderA) external payable;
}
// End I_GreySale interface
