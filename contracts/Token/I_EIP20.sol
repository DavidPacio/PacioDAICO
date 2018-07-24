/* \EIP20\I_EIP20.sol

https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
https://github.com/ConsenSys/Tokens/blob/master/contracts/eip20/EIP20Interface.sol

EIP 20 Interface

Not used .......

*/

pragma solidity ^0.4.24;

interface I_EIP20 {
  function balanceOf(address _owner) external view returns (uint256 balance);
  function allowance(address _owner, address _spender) external view returns (uint256 remaining);
  function transfer(address _to, uint256 _value) external returns (bool success);
  function transferFrom(address _fr, address _to, uint256 _value) external returns (bool success);
  function approve(address _spender, uint256 _value) external returns (bool success);

  // Events
  // ------
  event Transfer(address indexed _fr, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
