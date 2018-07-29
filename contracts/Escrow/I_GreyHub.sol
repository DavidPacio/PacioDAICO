/* \Escrow\I_GreyHub.sol started 2018.07.11

Interface for the Grey contract external functions which are called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_GreyHub {
  function WeiInEscrow() external view returns (uint256);
}
// End I_GreyHub interface
