/* \Token\I_TokenSale.sol 2018.07.11 started

Interface for the Token contract for the external functions called from the Sale contract.

*/

pragma solidity ^0.4.24;

interface I_TokenSale {
  function Issue(address toA, uint256 vPicos, uint256 vWei) external;
}
// End I_TokenSale interface
