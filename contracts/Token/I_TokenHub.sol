/* \Token\I_TokenHub.sol 2018.007.11 started

Interface for the Token contract for the external functions called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_TokenHub {
  function SetPause(bool B) external;
  function Initialise() external;
  function StartSale() external;
  function EndSale() external;
  function NewSaleContract(address vNewSaleContractA) external;
  function NewListContract(address vNewListContractA) external;
  function NewTokenContract(address vNewTokenContractA) external;
}
// End I_TokenHub interface

