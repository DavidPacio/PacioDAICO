/* \List\I_ListMfund.sol

Interface for the List contract external functions which are called from the Mfund contract.

*/

pragma solidity ^0.4.24;

interface I_ListMfund {
  function WeiContributed(address accountA) external view returns (uint256);
  function PicosBalance(address accountA) external view returns (uint256);
}
// End I_ListMfund interface
