/* \Token\I_TokenEscrow.sol 2018.07.11 started

Interface for the Token contract for the external functions called from the Escrow contract.

*/

pragma solidity ^0.4.24;

interface I_TokenEscrow {
  function PicosIssued() external view returns (uint256);
}
// End I_TokenEscrow interface

