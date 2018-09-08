/* \Sale\I_Sale.sol 2018.07.13 started

Interface for the Sale contract for the external functions called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_Sale {
  function Paused() external view returns (bool);
  function StateChange(uint32 vState) external;
  function SetPclAccount(address vPclAccountA) external;
  function PresaleIssue(address toA, uint256 vPicos, uint256 vWei, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external;
  function SetSaleTimes(uint32 vStartT, uint32 vEndT) external;
  function TokenSwapAndBountyIssue(address toA, uint256 picos, uint32 tranche) external;
  function PMtransfer(address senderA, uint256 weiContributed) external;
  function NewOpManContract(address newOpManContract) external;
  function NewTokenContract(address newTokenContractA) external;
  function  NewListContract(address newListContractA) external;
}
// End I_Sale interface

