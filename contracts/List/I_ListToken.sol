/* \List\I_ListToken.sol

Interface for the List contract external functions which are called from the Token contract, not  the others.

*/

pragma solidity ^0.4.24;

interface I_ListToken {
  function PicosBalance(address accountA) external view returns (uint256 balance);
  function PicosBought(address accountA) external view returns (uint256 balance);
  function IsTransferAllowedByDefault() external view returns (bool);
  function CreateSaleContractEntry(uint256 vPicos) external returns (bool);
  function Issue(address toA, uint256 vPicos, uint256 vWei, uint32 tranche1Bit) external returns (bool);
  function Refund(address toA, uint256 vRefundWei, uint32 vRefundBit) external returns (uint256 refundPicos);
  function Transfer(address frA, address toA, uint256 value) external returns (bool success);
  function TransferIssuedPIOsToPacioBc(address accountA) external;
  function TransferUnIssuedPIOsToPacioBc(uint256 vPicos) external;
  function NewSaleContract(address newSaleContractA) external;
}
 // End I_ListToken interface
