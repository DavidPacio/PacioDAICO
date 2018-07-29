/* \Sale\I_Sale.sol 2018.007.13 started

Interface for the Sale contract for the external functions called from the Hub contract.

*/

pragma solidity ^0.4.24;

interface I_Sale {
  function SetCapsAndTranches(uint256 vPicosCapT1, uint256 vPicosCapT2, uint256 vPicosCapT3, uint256 vUsdSoftCap, uint256 vUsdHardCap,
                              uint256 vMinWeiT1, uint256 vMinWeiT2, uint256 vMinWeiT3, uint256 vPriceCCentsT1, uint256 vPriceCCentsT2, uint256 vPriceCCentsT3) external;
  function IsSaleOpen() external view returns (bool);
  function SetUsdEtherPrice(uint256 vUsdEtherPrice) external;
  function PresaleIssue(address toA, uint256 vPicos, uint256 vWei, uint32 vDbId, uint32 vAddedT, uint32 vNumContribs) external;
  function StartSale(uint32 vStartT, uint32 vEndT) external;
  function SetUsdHardCapB(bool B) external;
  function SoftCapReached() external;
  function EndSale() external;
}
// End I_Sale interface

