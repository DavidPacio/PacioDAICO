/* \Hub\I_HubPoll.sol 2018.08.12 started

Interface for the Hub contract for the external functions called from the Poll contract.

*/

pragma solidity ^0.4.24;

interface I_HubPoll {
  function PollStartEnd(uint32 vPollN) external;
}
// End I_HubPoll interface
