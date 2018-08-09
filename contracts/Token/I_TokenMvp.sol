/* \Token\I_TokenMvp.sol 2018.07.11 started

Interface for the Token contract for the external functions called from the Mvp contract.

*/

pragma solidity ^0.4.24;

interface I_TokenMvp {
  function TransferIssuedPIOsToPacioBc(address accountA) external;
  function TransferUnIssuedPIOsToPacioBc(uint256 vPicos) external;
}
// End I_TokenMvp interface

