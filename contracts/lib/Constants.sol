/* lib\Constants.sol

Contract to centralise declaration of constants.

Did not use enums because they can't be used with interface contracts. Would have needed to use intrinsic types e.g. uint8 for parameters in interfaces -> possible explicit enum to int conversion issues
*/

pragma solidity ^0.4.24;

contract Constants {
  // Contract  Indices
  uint256 internal constant OP_MAN_X     = 0;
  uint256 internal constant HUB_X        = 1;
  uint256 internal constant SALE_X       = 2;
  uint256 internal constant TOKEN_X      = 3;
  uint256 internal constant LIST_X       = 4;
  uint256 internal constant ESCROW_X     = 5;
  uint256 internal constant GREY_X       = 6;
  uint256 internal constant VOTE_TAP_X   = 7;
  uint256 internal constant VOTE_END_X   = 8;
  uint256 internal constant MVP_LAUNCH_X = 9;

  // Owner Indices
  // Contract  Owned By
  //           0         1      2      3     4        5        6
  // OpMan     Deployer, Self,  Admin
  // Hub       Deployer, OpMan, Admin, Sale, VoteTap, VoteEnd, Web
  // Sale      Deployer, OpMan, Hub,   Admin
  // Token     Deployer, OpMan, Hub,   Sale, Mvp
  // List      Deployer, OpMan, Hub,   Sale, Token,   Escrow,  Grey
  // Escrow    Deployer, OpMan, Hub,   Sale, Admin
  // Grey      Deployer, OpMan, Hub,   Sale
  // VoteTap   Deployer, OpMan, Hub
  // VoteEnd   Deployer, OpMan, Hub
  // Mvp       Deployer, OpMan, Hub
  uint256 internal constant DEPLOYER_X       = 0;
  uint256 internal constant OP_MAN_OWNER_X   = 1;
  uint256 internal constant HUB_OWNER_X      = 2;
  uint256 internal constant ADMIN_OWNER_X    = 2;
  uint256 internal constant SALE_ADMIN_OWNER_X   = 3;
  uint256 internal constant ESCROW_ADMIN_OWNER_X = 4;
  uint256 internal constant SALE_OWNER_X     = 3;
  uint256 internal constant VOTE_TAP_OWNER_X = 4;
  uint256 internal constant VOTE_END_OWNER_X = 5;
  uint256 internal constant WEB_OWNER_X      = 6;
  uint256 internal constant TOKEN_OWNER_X    = 4;
  uint256 internal constant ESCROW_OWNER_X   = 5;
  uint256 internal constant GREY_OWNER_X     = 6;
  uint256 internal constant MVP_OWNER_X      = 4;

  // Managed Operation Indices
  uint256 internal constant RESUME_X                 =  0; // ResumeMO()
  uint256 internal constant CHANGE_OWNER_BASE_X      =  0; // ChangeOwnerMO() -> 1 and up because actual ManOpX will always be +1 at least, 0 for deployer not being allowed, -> range 1 to 4 allowing for a max of 4 owners after deployer as required for Token
  // Individual contract indices start from 5 after allowing for up to 4 owners after the deployer
  uint256 internal constant OP_MAN_ADD_CONTRACT_X    =  5; // AddContractMO()
  uint256 internal constant OP_MAN_ADD_SIGNER_X      =  6; // AddSignerMO()
  uint256 internal constant OP_MAN_ADD_MAN_OP_X      =  7; // AddManOpMO
  uint256 internal constant OP_MAN_CHANGE_SIGNER_X   =  8; // ChangeSignerMO()
  uint256 internal constant OP_MAN_UPDATE_CONTRACT_X =  9; // UpdateContractMO()
  uint256 internal constant OP_MAN_UPDATE_MAN_OP_X   = 10; // UpdateManOpMO()
  uint256 internal constant HUB_SOFT_CAP_REACHED_X   =  5; // Hub.SoftCapReachedMO()
  uint256 internal constant HUB_END_SALE_X           =  6; // Hub.EndSaleMO()
  uint256 internal constant SALE_SET_CAPS_TRANCHES_X =  5; // Sale.SetCapsAndTranchesMO()
  uint256 internal constant ESCROW_SET_PCL_ACCOUNT_X =  5; // Escrow.SetPclAccountMO()
  uint256 internal constant ESCROW_WITHDRAW_X        =  6; // Escrow.WithdrawMO()

    // Time
  uint32 internal constant DAY         = 86400;
  uint32 internal constant HOUR        =  3600;
  uint256 internal constant MONTH    = 2629800; // 365.25 * 24 * 3600 / 12

  // List Contract bits                                  /- bit and bit setting description
  uint32 internal constant PRESALE              =  1; // 0 A Presale List entry - Pacio Seed Presale or Pacio internal Placement
  uint32 internal constant TRANSFER_OK          =  2; // 1 Transfers allowed for this member even if pTransfersOkB is false
  uint32 internal constant HAS_PROXY            =  4; // 2 This entry has a Proxy appointed
  uint32 internal constant BURNT                =  8; // 3 This entry has had its PIOs burnt
  uint32 internal constant REFUND_SOFT_CAP_MISS = 16; // 4 Refund of all funds due to soft cap not being reached
  uint32 internal constant REFUND_TERMINATION   = 32; // 5 Refund of remaining funds proportionately following a yes vote for project termination
  uint32 internal constant REFUND_GREY          = 64; // 6 Refund of grey escrow funds that have not been white listed by the time that the sale closes

  // List Contract Browsing actions
  uint8 internal constant BROWSE_FIRST = 1;
  uint8 internal constant BROWSE_LAST  = 2;
  uint8 internal constant BROWSE_NEXT  = 3;
  uint8 internal constant BROWSE_PREV  = 4;

  // List Contract entry types
  // -------------------------
  uint8 internal constant ENTRY_NONE       = 0; // An undefined entry with no add date
  uint8 internal constant ENTRY_CONTRACT   = 1; // Contract (Sale) list entry for Minted tokens. Has dbId == 1
  uint8 internal constant ENTRY_GREY       = 2; // Grey listed, initial default, not whitelisted, not contract, not presale, not refunded, not downgraded, not member
  uint8 internal constant ENTRY_PRESALE    = 3; // Seed presale or internal placement entry. Has PRESALE bit set. whiteT is not set
  uint8 internal constant ENTRY_REFUNDED   = 4; // Contributed funds have been refunded at refundedT. Must have been Presale or Member previously.
  uint8 internal constant ENTRY_DOWNGRADED = 5; // Has been downgraded from White or Member
  uint8 internal constant ENTRY_BURNT      = 6; // Has been burnt
  uint8 internal constant ENTRY_WHITE      = 7; // Whitelisted with no picosBalance
  uint8 internal constant ENTRY_MEMBER     = 8; // Whitelisted with a picosBalance

} // End Constants Contract
