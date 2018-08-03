/* \Token\I_TokenHub.sol 2018.07.11 started

Interface for the Token contract for the external functions called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_TokenHub {
  function PicosIssued() external view returns (uint256);
  function StartSale() external;
  function EndSale() external;
}
// End I_TokenHub interface

