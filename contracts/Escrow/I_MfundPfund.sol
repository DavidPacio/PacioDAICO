/* \Funds\I_MfundPfund.sol started 2018.08.07

Interface for the Mfund contract external functions which are called from the Pfund contract.

*/

pragma solidity ^0.4.24;

interface I_MfundPfund {
  function Deposit(address vSenderA) external payable;
}
// End I_MfundPfund interface
