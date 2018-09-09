// \OpMan\I_OpManHub.sol 2018.08.02 started
//
// Interface for the OpMan contract for the external functions called from the Hub contracts.
//
pragma solidity ^0.4.24;
interface I_OpManHub {
  function Paused() external view returns (bool);
  function ContractXA(uint256) external view returns (address);
  function PauseContract(uint256) external returns (bool);
  function IsManOpApproved(uint256) external returns (bool);
  function ChangeContract(uint256, address) external returns (bool);
  function NewOwner(uint256, address) external;
}
// End I_OpManHub interface
