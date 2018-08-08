/* \Token\I_TokenMfund.sol 2018.07.11 started

Interface for the Token contract for the external functions called from the Mfund contract.

*/

pragma solidity ^0.4.24;

interface I_TokenMfund {
  function PicosIssued() external view returns (uint256);
}
// End I_TokenMfund interface

