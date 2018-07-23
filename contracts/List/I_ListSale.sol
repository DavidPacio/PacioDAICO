/* \List\I_ListSale.sol

Interface for the List contract external functions which are called from the Sale contract.

Only one view function so there is no need for owner protection in List for Sale

*/

pragma solidity ^0.4.24;

interface I_ListSale {
  function BonusPcAndType(address accountA) external view returns (uint32 bonusCentiPc, uint8 typeN);
}
// End I_ListSale interface
