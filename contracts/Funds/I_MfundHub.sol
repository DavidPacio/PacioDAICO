/* \Funds\I_MfundHub.sol started 2018.07.11

Interface for the Mfund contract external functions which are called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_MfundHub {
  function FundWei() external view returns (uint256);
//function PclAccount() external view returns (address);
  function SetPclAccount(address vPclAccountA) external;
  function StateChange(uint32 vState) external;
  function RefundInfo(uint256 vRefundId, address accountA) external returns (uint256 refundPicos, uint256 refundWei, uint32 refundBit);
  function Refund(uint256 vRefundId, address toA, uint256 vRefundPicos, uint256 vRefundWei, uint32 refundBit) external returns (bool);
  function NewOwner(uint256, address) external;
  function NewListContract(address newListContractA) external;
}
// End I_MfundHub interface
