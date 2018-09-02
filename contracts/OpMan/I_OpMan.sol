// \OpMan\I_OpMan.sol 2018.07.20 started
//
// Interface for the OpMan contract for the external functions called from other contracts.
//
pragma solidity ^0.4.24;
interface I_OpMan {
  function ContractXA(uint256 cX) external view returns (address);
  function IsManOpApproved(uint256 vManOpX) external returns (bool);
}
// End I_OpMan interface
