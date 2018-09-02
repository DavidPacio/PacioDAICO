// \OpMan\I_OpManHub.sol 2018.08.02 started
//
// Interface for the OpMan contract for the external functions called from the Hub contracts.
//
pragma solidity ^0.4.24;
interface I_OpManHub {
  function ContractXA(uint256 cX) external view returns (address);
  function IsNotDuplicateContractB(address contractA) external view returns (bool);
  function PauseContract(uint256 cX) external returns (bool);
  function IsManOpApproved(uint256 vManOpX) external returns (bool);
}
// End I_OpManHub interface
