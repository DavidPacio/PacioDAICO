// Math.sol

// From https://github.com/dapphub/ds-math/blob/master/src/math.sol

// Reduced version - just the fns used by Pacio
// But with add -> safeAdd, sub -> safeSub, mul -> safeMul to suit ERC223_Token.sol use and to avoid compiler warnings of
// variable being shadowed in inline assembly by an instruction of the same name

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

pragma solidity ^0.4.24;

contract Math {
  function safeAdd(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x + y) >= x);
  }

  function safeSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x - y) <= x);
  }

  function safeMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y == 0 || (z = x * y) / y == x);
  }

  // div isn't needed. Only error case is div by zero and Solidity throws on that
  // function div(uint256 x, uint256 y) internal pure returns (uint256 z) {
  //   z = x / y;
  // }

  // subMaxZero(x, y)
  // Pacio addition to avoid reverting if a subtraction would go below zero and return 0 in that case.
  function subMaxZero(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = x <= y ? 0 : x - y;
  }

  // subMaxZero32(x, y) private
  // Pacio addition to avoid reverting if a uint32 subtraction would go below zero and return 0 in that case.
  function subMaxZero32(uint32 x, uint32 y) internal pure returns (uint32 z) {
    z = x <= y ? 0 : x - y;
  }

  // decrementMaxZero(x, y)
  // Pacio addition for decrementing an int32 to avoid reverting if decrementing would go below zero and return 0 in that case.
  function decrementMaxZero(uint32 x) internal pure returns (uint32 z) {
    z = x == 0 ? 0 : --x;
  }

  // Min(x, y)
  function Min(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = x <= y ? x : y;
  }

  // Min32(x, y)
  function Min32(uint32 x, uint32 y) internal pure returns (uint32 z) {
    z = x <= y ? x : y;
  }

} // End Math Contract
