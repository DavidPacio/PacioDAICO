/* \Token\EIP20Token.sol
https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
https://github.com/ConsenSys/Tokens/blob/master/contracts/eip20/EIP20.sol
With Pacio mods for the Pacio DAICO

EIP20 Methods
=============
These methods are often public in other EIP 20 implementations but they can be external which then matches the interface declarations which must be external

EIP20 View Methods
------------------
EIP20Token.balanceOf(address accountA) external view returns (uint256 balance);
EIP20Token.allowance(address accountA, address spenderA) external view returns (uint256 remaining);

EIP20 State Changing Public Methods
-----------------------------------
EIP20Token.transfer(address toA, uint256 value) external returns (bool success);
EIP20Token.transferFrom(address frA, address toA, uint256 value) external returns (bool success);
EIP20Token.approve(address spenderA, uint256 value) external returns (bool success);

EIP20 Events
------------
EIP20Token event Transfer(address indexed From, address indexed To, uint256 Value);
EIP20Token event Approval(address indexed Account, address indexed Spender, uint256 Value);

*/

pragma solidity ^0.4.24;

import "../List/I_ListToken.sol";
import "../lib/OwnedToken.sol";

contract EIP20Token is OwnedToken {
  // Data
  bool    public constant isEIP20Token = true; // Interface declaration
  string  public name     = "PIOE Token";
  string  public symbol   = "PIOE";
  uint8   public decimals = 12;
  uint256 public totalSupply;  // Total tokens minted
  I_ListToken internal iListC; // the list contract. Set by Token.Initialise()
//mapping(address => uint256) public balances;                     - replaced by List contract mapping of a struct for all member info
//mapping(address => mapping (address => uint256)) public allowed; - Public in Consensys code, but this doesn't need to be public. private used instead.
  mapping(address => mapping (address => uint256)) private allowed; // Owner of account approves the transfer of an amount to another account

  // No Constructor
  // --------------

  // Events
  // ------
  event Transfer(address indexed From, address indexed To, uint256 Value);
  event Approval(address indexed Account, address indexed Spender, uint256 Value);

  // IsTransferOK modifier function
  // ------------
  // Checks that the token is active and toA is different from frA
  // All transfer fns will also call List.IsTransferOK() which checks that the list is active; both frA and toA exist; transfer from frA is ok; transfer to toA is ok (toA is whitelisted); and that frA has the tokens available
  modifier IsTransferOK(address frA, address toA) {
    require(!iPausedB    // The token IsActive
         && toA != frA); // Destination is different from source
    _;
  }

  // EIP20 Methods
  // =============
  // These methods are often public in other EIP 20 implementations but they can be external which then matches the interface declarations which must be external

  // View Methods
  // ------------
  // EIP20Token.balanceOf()
  // ----------------------
  // Returns the token balance of account with address accountA
  function balanceOf(address accountA) external view returns (uint256 balance) {
    return iListC.PicosBalance(accountA);
  }
  // EIP20Token.allowance()
  // ----------------------
  // Returns the number of tokens approved by accountA that can be transferred ("spent") by spenderA
  function allowance(address accountA, address spenderA) external view returns (uint256 remaining) {
    return allowed[accountA][spenderA];
  }

  // State changing external methods made pause-able via IsTransferOK()
  // -----------------------------
  // EIP20Token.transfer()
  // ---------------------
  // Transfers value of sender's tokens to another account, address toA
  function transfer(address toA, uint256 value) external IsTransferOK(msg.sender, toA) returns (bool success) {
    require(iListC.Transfer(msg.sender, toA, value));
    emit Transfer(msg.sender, toA, value);
    return true;
  }

  // EIP20Token.transferFrom()
  // -------------------------
  // Sender transfers value tokens from account frA to account toA, if
  // sender had been approved by frA for a transfer of >= value tokens from frA's account
  // by a prior call to approve() with that call's sender being this call's frA,
  //  and its spenderA being this call's sender.
  function transferFrom(address frA, address toA, uint256 value) external IsTransferOK(frA, toA) returns (bool success) {
    require(allowed[frA][msg.sender] >= value); // Transfer is approved
    require(iListC.Transfer(frA, toA, value));
    allowed[frA][msg.sender] -= value; // There is no need to check this for underflow given the transfer is approved require above
    emit Transfer(frA, toA, value); //solhint-disable-line indent, no-unused-vars
    return true;
  }

  // EIP20Token.approve()
  // --------------------
  // Approves the passed address (of spenderA) to spend up to value tokens on behalf of msg.sender,
  //  in one or more transferFrom() calls
  // If this function is called again it overwrites the current allowance with value.
  function approve(address spenderA, uint256 value) external returns (bool success) {
    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(spenderA, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    // djh: This appears to be of doubtful value, and is not used in the Dappsys library though it is in the Zeppelin one. Removed.
    // require((value == 0) || (allowed[msg.sender][spenderA] == 0));
    allowed[msg.sender][spenderA] = value;
    emit Approval(msg.sender, spenderA, value); //solhint-disable-line indent, no-unused-vars
    return true;
  }

} // End EIP20Token contract

