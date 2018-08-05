/* \Token\I_TokenHub.sol 2018.07.11 started

Interface for the Token contract for the external functions called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_TokenHub {
  function StartSale() external;
  function EndSale() external;
  function Refund(address toA, uint256 vRefundWei, uint32 vRefundBit) external returns (bool);
}
// End I_TokenHub interface

