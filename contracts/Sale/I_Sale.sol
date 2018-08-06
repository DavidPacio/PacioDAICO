/* \Sale\I_Sale.sol 2018.07.13 started

Interface for the Sale contract for the external functions called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_Sale {
  function StateChange(uint32 vState) external;
  function PresaleIssue(address toA, uint256 vPicos, uint256 vWei, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external;
  function SetSaleDates(uint32 vStartT, uint32 vEndT) external;
}
// End I_Sale interface

