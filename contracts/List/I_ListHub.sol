/* \List\I_ListHub.sol

Interface for the List contract external functions which are called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_ListHub {
  // View
  function EntryBits(address entryA) external view returns (uint32 bits);
  function Browse(address currentA, uint8 vActionN) external view returns (address retA, uint8 typeN);
  function NextEntry(address entryA) external view returns (address);
  function PrevEntry(address entryA) external view returns (address);
  function WeiContributed(address entryA) external view returns (uint256);
  function IsTransferAllowedByDefault() external view returns (bool);
  // State changing
  function StateChange(uint32 vState) external;
  function CreateListEntry(address entryA, uint32 vBits, uint32 vDbId) external returns (bool);
  function CreatePresaleEntry(address entryA, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external returns (bool);
  function Whitelist(address entryA, uint32 vWhiteT) external;
  function Downgrade(address entryA, uint32 vDownT)  external;
  function SetBonus(address entryA, uint32 vBonusPc) external;
  function SetTransfersOkByDefault(bool B) external;
  function SetListEntryTransferOk(address entryA, bool B) external;
  function SetListEntryBits(address entryA, uint32 bitsToSet, bool setB) external;
  function NewTokenContract(address newTokenContractA) external;
}
// End I_ListHub interface
