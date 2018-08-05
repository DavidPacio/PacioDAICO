/* lib\Constants.sol

Contract to centralise declaration of constants.

Did not use enums because they can't be used with interface contracts. Would have needed to use intrinsic types e.g. uint8 for parameters in interfaces -> possible explicit enum to int conversion issues
*/

pragma solidity ^0.4.24;

contract Constants {
  // State Bits for use with pState                            /- Bit and description
  // All zero                                        =           Nothing started yet
  uint32 internal constant STATE_PRIOR_TO_OPEN_B     =   1; // 0 Open for registration, Grey escrow deposits, and white listing which causes Grey -> Escrow transfer but wo PIOs being issued
  uint32 internal constant STATE_OPEN_B              =   2; // 1 Sale is open. Is unset on any of the closes
  uint32 internal constant STATE_S_CAP_REACHED_B     =   4; // 2 Soft cap reached -> initial draw
  uint32 internal constant STATE_CLOSED_H_CAP_B      =   8; // 3 Sale closed due to hitting hard cap
  uint32 internal constant STATE_CLOSED_TIME_UP_B    =  16; // 4 Sale closed due to running out of time
  uint32 internal constant STATE_CLOSED_MANUAL_B     =  32; // 5 Sale closed manually for whatever reason
  uint32 internal constant STATE_TAPS_OK_B           =  64; // 6 Sale closed with Soft Cap reached.  STATE_S_CAP_REACHED_B and one of the closes must be set. STATE_OPEN_B must be unset.
  uint32 internal constant STATE_S_CAP_MISS_REFUND_B = 128; // 7 Failed to reach soft cap, contributions being refunded.                    STATE_CLOSED_TIME_UP_B || STATE_CLOSED_MANUAL_B must be set and STATE_OPEN_B unset
  uint32 internal constant STATE_TERMINATE_REFUND_B  = 256; // 8 A VoteEnd vote has voted to end the project, contributions being refunded. Any of the closes must be set and STATE_OPEN_B unset
  uint32 internal constant STATE_ESCROW_EMPTY_B      = 512; // 9 Escrow is empty as a result of refunds or withdrawals emptying the pot
  uint32 internal constant STATE_GREY_EMPTY_B       = 1024; // A Grey escrow is empty as a result of refunds or withdrawals emptying the pot
  // Combos for anding checks
  uint32 internal constant STATE_DEPOSIT_OK_COMBO_B =    3; // STATE_PRIOR_TO_OPEN_B | STATE_OPEN_B
  uint32 internal constant STATE_CLOSED_COMBO_B     =   56; // Sale closed = STATE_CLOSED_H_CAP_B | STATE_CLOSED_TIME_UP_B | STATE_CLOSED_MANUAL_B. Not STATE_OPEN_B is subtly different as that could be before anything starts.
  uint32 internal constant STATE_REFUNDING_COMBO_B  =  384; // STATE_S_CAP_MISS_REFUND_B | STATE_TERMINATE_REFUND_B

  // Contract Indices
  uint256 internal constant OP_MAN_CONTRACT_X   = 0;
  uint256 internal constant HUB_CONTRACT_X      = 1;
  uint256 internal constant SALE_CONTRACT_X     = 2;
  uint256 internal constant TOKEN_CONTRACT_X    = 3;
  uint256 internal constant LIST_CONTRACT_X     = 4;
  uint256 internal constant ESCROW_CONTRACT_X   = 5;
  uint256 internal constant GREY_CONTRACT_X     = 6;
  uint256 internal constant VOTE_TAP_CONTRACT_X = 7;
  uint256 internal constant VOTE_END_CONTRACT_X = 8;
  uint256 internal constant MVP_CONTRACT_X      = 9;

  // Owner Indices
  // Contract  Owned By
  //           0         1      2      3     4        5        6
  // OpMan     Deployer, Self,  Admin
  // Hub       Deployer, OpMan, Admin, Sale, VoteTap, VoteEnd, Web
  // Sale      Deployer, OpMan, Hub,   Admin
  // Token     Deployer, OpMan, Hub,   Sale, Mvp
  // List      Deployer, OpMan, Hub,   Sale, Token
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
  uint256 internal constant MVP_OWNER_X      = 4;

  // Managed Operation Indices
  uint256 internal constant RESUME_MO_X                 =  0; // ResumeMO()
  uint256 internal constant CHANGE_OWNER_BASE_MO_X      =  0; // ChangeOwnerMO() -> 1 and up because actual ManOpX will always be +1 at least, 0 for deployer not being allowed, -> range 1 to 4 allowing for a max of 4 owners after deployer as required for Token
  // Individual contract indices start from 5 after allowing for up to 4 owners after the deployer
  uint256 internal constant OP_MAN_ADD_CONTRACT_MO_X    =  5; // AddContractMO()
  uint256 internal constant OP_MAN_ADD_SIGNER_MO_X      =  6; // AddSignerMO()
  uint256 internal constant OP_MAN_ADD_MAN_OP_MO_X      =  7; // AddManOpMO
  uint256 internal constant OP_MAN_CHANGE_SIGNER_MO_X   =  8; // ChangeSignerMO()
  uint256 internal constant OP_MAN_UPDATE_CONTRACT_MO_X =  9; // UpdateContractMO()
  uint256 internal constant OP_MAN_UPDATE_MAN_OP_MO_X   = 10; // UpdateManOpMO()
  uint256 internal constant HUB_SOFT_CAP_REACHED_MO_X   =  5; // Hub.SoftCapReachedMO()
  uint256 internal constant HUB_END_SALE_MO_X           =  6; // Hub.EndSaleMO()
  uint256 internal constant SALE_SET_CAPS_TRANCHES_MO_X =  5; // Sale.SetCapsAndTranchesMO()
  uint256 internal constant ESCROW_SET_PCL_ACCOUNT_MO_X =  5; // Escrow.SetPclAccountMO()
  uint256 internal constant ESCROW_WITHDRAW_MO_X        =  6; // Escrow.WithdrawMO()

    // Time
  uint32 internal constant DAY         = 86400;
  uint32 internal constant HOUR        =  3600;
  uint256 internal constant MONTH    = 2629800; // 365.25 * 24 * 3600 / 12

  // List Entry Bits                                                /- bit and bit setting description
  uint32 internal constant LE_PRESALE_B                   =   1; // 0 A Presale List entry - Pacio Seed Presale or Pacio internal Placement
  uint32 internal constant LE_TRANSFER_OK_B               =   2; // 1 Transfers allowed for this member even if pTransfersOkB is false
  uint32 internal constant LE_HAS_PROXY_B                 =   4; // 2 This entry has a Proxy appointed
  uint32 internal constant LE_BURNT_B                     =   8; // 3 This entry has had its PIOs burnt
  uint32 internal constant LE_REFUND_ESCROW_S_CAP_MISS_B  =  16; // 4 Refund of all Escrow funds due to soft cap not being reached
  uint32 internal constant LE_REFUND_ESCROW_TERMINATION_B =  32; // 5 Refund of remaining Escrow funds proportionately following a yes vote for project termination
  uint32 internal constant LE_REFUND_ESCROW_ONCE_OFF_B    =  64; // 6 Once off Escrow refund for whatever reason including downgrade from whitelisted
  uint32 internal constant LE_REFUND_GREY_S_CAP_MISS_B    = 128; // 7 Refund of Grey escrow funds due to soft cap not being reached
  uint32 internal constant LE_REFUND_GREY_SALE_CLOSE_B    = 256; // 8 Refund of Grey escrow funds that have not been white listed by the time that the sale closes. No need for a Grey termination case as sale must be closed before atermination vote can occur
  uint32 internal constant LE_REFUND_GREY_ONCE_OFF_B      = 512; // 9 Once off Admin/Manual Grey escrow refund for whatever reason

  // List Browsing actions
  uint8 internal constant BROWSE_FIRST = 1;
  uint8 internal constant BROWSE_LAST  = 2;
  uint8 internal constant BROWSE_NEXT  = 3;
  uint8 internal constant BROWSE_PREV  = 4;

  // List Entry Types
  uint8 internal constant LE_TYPE_NONE       = 0; // An undefined entry with no add date
  uint8 internal constant LE_TYPE_CONTRACT   = 1; // Contract (Sale) list entry for Minted tokens. Has dbId == 1
  uint8 internal constant LE_TYPE_GREY       = 2; // Grey listed, initial default, not whitelisted, not contract, not presale, not refunded, not downgraded, not member
  uint8 internal constant LE_TYPE_PRESALE    = 3; // Seed presale or internal placement entry. Has LE_PRESALE_B bit set. whiteT is not set
  uint8 internal constant LE_TYPE_REFUNDED   = 4; // Funds have been refunded at refundedT, either in full or in part if a Project Termination refund.
  uint8 internal constant LE_TYPE_DOWNGRADED = 5; // Has been downgraded from White or Member and refunded
  uint8 internal constant LE_TYPE_BURNT      = 6; // Has been burnt
  uint8 internal constant LE_TYPE_WHITE      = 7; // Whitelisted with no picosBalance
  uint8 internal constant LE_TYPE_MEMBER     = 8; // Whitelisted with a picosBalance

} // End Constants Contract
