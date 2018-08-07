/* \Funds\I_MFundPFund.sol started 2018.07.11

Interface for the MFund contract external functions which are called from the I_PFund contract.

*/

pragma solidity ^0.4.24;

interface I_MFundPFund {
  function Deposit(address vSenderA) external payable;
}
// End I_MFundPFund interface
