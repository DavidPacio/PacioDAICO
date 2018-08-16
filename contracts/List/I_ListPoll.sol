/* \List\I_ListPoll.sol

Interface for the List contract external functions which are called from the Poll contract.

*/

pragma solidity ^0.4.24;

interface I_ListPoll {
  function NumberOfPacioMembers() external view returns (uint32);
  function IsMember(address accountA) external view returns (bool);
  function PicosBalance(address accountA) external view returns (uint256);
  function SetMaxVotePerMember(uint256 pMaxPicosVote) external;
  function Proxy(address accountA) external view returns (address);
  function UpdatePioVotesDelegated(address entryA) external;
  function SetProxy(address vEntryA, address vProxyA) external returns (bool);
  function Vote(address voterA, uint32 vPollId, uint8 voteN) external returns (uint32 piosVoted);
  function RevokeVote(address voterA, uint32 vPollId) external returns (int32 piosVoted);
}
// End I_ListPoll interface
