/* \List\I_ListPoll.sol

Interface for the List contract external functions which are called from the Poll contract.

*/

pragma solidity ^0.4.24;

interface I_ListPoll {
  function IsMember(address accountA) external view returns (bool);
  function PicosBalance(address accountA) external view returns (uint256);
}
// End I_ListPoll interface
