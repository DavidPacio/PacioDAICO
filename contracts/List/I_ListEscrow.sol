/* \List\I_ListEscrow.sol

Interface for the List contract external functions which are called from the Escrow contracts.

*/

pragma solidity ^0.4.24;

interface I_ListEscrow {
  function WeiContributed(address accountA) external view returns (uint256);
  function PicosBalance(address accountA) external view returns (uint256);
}
// End I_ListEscrow interface
