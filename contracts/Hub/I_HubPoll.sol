/* \Hub\I_HubPoll.sol 2018.08.12 started

Interface for the Hub contract for the external functions called from the Poll contract.

*/

pragma solidity ^0.4.24;

interface I_HubPoll {
  function PollStartEnd(uint32 vPollId, uint8 vPollN) external;
  function CloseSaleMO(uint32 vBit) external;
  function PollTerminateFunding() external;
}
// End I_HubPoll interface
