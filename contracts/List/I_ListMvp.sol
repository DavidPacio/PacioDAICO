/* \List\I_ListSale.sol

Interface for the List contract external functions which are called from the Mvp contract.

Only one view function so there is no need for owner protection in List for Mvp

*/

pragma solidity ^0.4.24;

interface I_ListMvp {
  function PicosBalance(address accountA) external view returns (uint256 balance);
}
// End I_ListMvp interface
