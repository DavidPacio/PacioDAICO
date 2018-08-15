/* \Funds\I_MfundPoll.sol started 2018.07.11

Interface for the Mfund contract external functions which are called from the Poll contract.

*/

pragma solidity ^0.4.24;

interface I_MfundPoll {
  function SoftCapReachedDispersalPc() external view returns (uint32);
  function TapRateEtherPm() external view returns (uint32);
  function PollSetSoftCapDispersalPc(uint32 vSoftCapDispersalPc) external;
  function PollSetTapRateEtherPm(uint32 vTapRateEtherPm) external;
}
// End I_MfundPoll interface
