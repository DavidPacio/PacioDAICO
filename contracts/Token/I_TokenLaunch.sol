/* \Token\I_TokenLaunch.sol 2018.007.11 started

Interface for the Token contract for the external functions called from the Sale contract.

*/

pragma solidity ^0.4.24;

interface I_TokenLaunch {
  function Burn() external;
  function Destroy(uint256 vPicos) external;
}
// End I_TokenLaunch interface

