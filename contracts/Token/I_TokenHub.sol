/* \Token\I_TokenHub.sol 2018.07.11 started

Interface for the Token contract for the external functions called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_TokenHub {
  function StateChange(uint32 vState) external;
  function Refund(uint256 vRefundId, address toA, uint256 vRefundWei, uint32 vRefundBit) external returns (bool);
  function NewSaleContract(address newSaleContractA) external;
  function NewListContract(address newListContractA) external;
}
// End I_TokenHub interface

