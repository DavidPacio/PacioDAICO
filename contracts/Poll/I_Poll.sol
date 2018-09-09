/* \Poll\I_Poll started 2018.07.11

Interface for the Poll contract external functions which are called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_Poll {
  function StateChange(uint32) external;
  function NewOwner(uint256, address) external;
  function NewHubContract(address) external;
  function NewSaleContract(address) external;
  function NewListContract(address) external;
  function NewMfundContract(address) external;
}
// End I_Poll interface
