/* \Poll\I_Poll started 2018.07.11

Interface for the Poll contract external functions which are called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_Poll {
  function StateChange(uint32 vState) external;
  function NewOpManContract(address newOpManContractA) external;
  function NewSaleContract(address newListContractA) external;
  function NewListContract(address newListContractA) external;
}
// End I_Poll interface
