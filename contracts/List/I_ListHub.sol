/* \List\I_ListHub.sol

Interface for the List contract external functions which are called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_ListHub {
  // View
  function EntryType(address accountA) external view returns (uint8 typeN);
  function BonusPcAndType(address accountA) external view returns (uint32 bonusCentiPc, uint8 typeN);
  function Browse(address currentA, uint8 vActionN) external view returns (address retA, uint8 typeN);
  function NextEntry(address accountA) external view returns (address);
  function PrevEntry(address accountA) external view returns (address);
  function Proxy(address accountA) external view returns (address);
  function WeiContributed(address accountA) external view returns (uint256);
  function IsTransferAllowedByDefault() external view returns (bool);
  // State changing
  function StartSale() external;
  function StateChange(uint32 vState) external;
  function CreateListEntry(address vEntryA, uint32 vBits, uint32 vDbId) external returns (bool);
  function CreatePresaleEntry(address vEntryA, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external returns (bool);
  function Whitelist(address vEntryA, uint32 vWhiteT) external returns (bool);
  function Downgrade(address vEntryA, uint32 vDownT)  external returns (bool);
  function SetBonus(address vEntryA, uint32 vBonusPc) external returns (bool);
  function SetProxy(address vEntryA, address vProxyA) external returns (bool);
  function SetTransfersOkByDefault(bool B) external returns (bool);
  function SetTransferOk(address vEntryA, bool B) external returns (bool);
}
// End I_ListHub interface
