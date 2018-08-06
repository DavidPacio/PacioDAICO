/* lib\Constants.sol

Contract to centralise declaration of constants.

Did not use enums because they can't be used with interface contracts. Would have needed to use intrinsic types e.g. uint8 for parameters in interfaces -> possible explicit enum to int conversion issues
*/

pragma solidity ^0.4.24;

contract Constants {
  // State Bits for use with pState                            /- Bit and description
  // All zero                                        =           Nothing started yet
  uint32 internal constant STATE_PRIOR_TO_OPEN_B     =   1; // 0 Open for registration, Prepurchase escrow deposits, and white listing which causes Grey -> Escrow transfer but wo PIOs being issued
  uint32 internal constant STATE_OPEN_B              =   2; // 1 Sale is open. Is unset on any of the closes
  uint32 internal constant STATE_S_CAP_REACHED_B     =   4; // 2 Soft cap reached -> initial draw
  uint32 internal constant STATE_CLOSED_H_CAP_B      =   8; // 3 Sale closed due to hitting hard cap
  uint32 internal constant STATE_CLOSED_TIME_UP_B    =  16; // 4 Sale closed due to running out of time
  uint32 internal constant STATE_CLOSED_MANUAL_B     =  32; // 5 Sale closed manually for whatever reason
  uint32 internal constant STATE_TAPS_OK_B           =  64; // 6 Sale closed with Soft Cap reached.  STATE_S_CAP_REACHED_B and one of the closes must be set. STATE_OPEN_B must be unset.
  uint32 internal constant STATE_S_CAP_MISS_REFUND_B = 128; // 7 Failed to reach soft cap, contributions being refunded.                    STATE_CLOSED_TIME_UP_B || STATE_CLOSED_MANUAL_B must be set and STATE_OPEN_B unset
  uint32 internal constant STATE_TERMINATE_REFUND_B  = 256; // 8 A VoteEnd vote has voted to end the project, contributions being refunded. Any of the closes must be set and STATE_OPEN_B unset
  uint32 internal constant STATE_ESCROW_EMPTY_B      = 512; // 9 Escrow is empty as a result of refunds or withdrawals emptying the pot
  uint32 internal constant STATE_PESCROW_EMPTY_B    = 1024; // A Prepurchase escrow is empty as a result of refunds or withdrawals emptying the pot
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
  uint256 internal constant PESCROW_CONTRACT_X  = 6;
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
  // Pescrow   Deployer, OpMan, Hub,   Sale
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


  // List Entry Bits                                                    /- bit and bit setting description
  // Zero                                                                 Undefined so can be used a test for an entry existing, or addedT > 0
  uint32 internal constant LE_REGISTERED_B                =      1; //  0 Entry has been registered with addedT set but nothing more
  uint32 internal constant LE_SALE_CONTRACT_B             =      2; //  1 Is the Sale Contract entry - where the minted PIOs are held. Has dbId == 1
  uint32 internal constant LE_FUNDED_B                    =      4; //  2 Funds sent
  uint32 internal constant LE_HOLDS_PIOS_B                =      8; //  3 Holds PIOs. Can be set wo LE_FUNDED_B being set as a result of a transfer
  uint32 internal constant LE_PREPURCHASE_B               =     16; //  4 Prepurchase funded entry. There are 4 types of prepurchase entries as below. If unset then entry is an escrow entry, and must then have either LE_WHITELISTED_B or LE_PRESALE_B set or both.
  uint32 internal constant LE_WHITELISTED_B               =     32; //  5 Has been whitelisted
  uint32 internal constant LE_MEMBER_B                    =     64; //  6 Is a Pacio Member: Whitelisted with a picosBalance
  uint32 internal constant LE_PRESALE_B                   =    128; //  7 A Presale List entry - Pacio Seed Presale or Pacio Private Placement - not yet whitelisted
  uint32 internal constant LE_WAS_PRESALE_B               =    256; //  8 Was a Presale entry which has been whitelisted
  uint32 internal constant LE_TRANSFER_OK_B               =    512; //  9 Transfers allowed for this entry even if pTransfersOkB is false
  uint32 internal constant LE_HAS_PROXY_B                 =   1024; // 10 This entry has a Proxy appointed
  uint32 internal constant LE_DOWNGRADED_B                =   2048; // 11 This entry has been downgraded from whitelisted. Refunding candidate.
  uint32 internal constant LE_BURNT_B                     =   4096; // 12 This entry has had its PIOs burnt
  uint32 internal constant LE_REFUND_PESCROW_S_CAP_MISS_B =   8192; // 13 Prepurchase escrow funds Refunded due to soft cap not being reached
  uint32 internal constant LE_REFUND_PESCROW_SALE_CLOSE_B =  16384; // 14 Prepurchase escrow funds Refunded due to not being whitelisted by the time that the sale closes
  uint32 internal constant LE_REFUND_PESCROW_ONCE_OFF_B   =  32768; // 15 Prepurchase escrow funds Refunded once off manually for whatever reason
  uint32 internal constant LE_REFUND_ESCROW_S_CAP_MISS_B  =  65536; // 16 Escrow funds Refunded due to soft cap not being reached
  uint32 internal constant LE_REFUND_ESCROW_TERMINATION_B = 131072; // 17 Escrow funds Refunded proportionately according to Picos held following a yes vote for project termination
  uint32 internal constant LE_REFUND_ESCROW_ONCE_OFF_B    = 262144; // 18 Escrow funds Refunded once off manually for whatever reason including downgrade from whitelisted
  // Combos for anding checks
  uint32 internal constant LE_REFUNDED_COMBO_B           =  516096; // LE_REFUND_PESCROW_S_CAP_MISS_B | LE_REFUND_PESCROW_SALE_CLOSE_B | LE_REFUND_PESCROW_ONCE_OFF_B | LE_REFUND_ESCROW_S_CAP_MISS_B | LE_REFUND_ESCROW_TERMINATION_B | LE_REFUND_ESCROW_ONCE_OFF_B
  uint32 internal constant LE_DEAD_COMBO_B               =  520192; // LE_BURNT_B | LE_REFUNDED_COMBO_B  or bits >= 4096
  uint32 internal constant LE_NO_SENDING_FUNDS_COMBO_B   =  522370; // LE_DEAD_COMBO_B | LE_SALE_CONTRACT_B | LE_PRESALE | LE_DOWNGRADED_B
  uint32 internal constant LE_NO_REFUND_COMBO_B          =  520194; // LE_DEAD_COMBO_B | LE_SALE_CONTRACT_B Starting point check. Could also be more i.e. no funds or no PIOs

  // There is no need for a Prepurchase refund termination bit as the sale must be closed before a termination vote can occur -> any prepurchase amounts being refundable anyway.

  // Prepurchase Entry Types:
  // uint8 internal constant LE_TYPE_PRE_NWL_SNO = 1; // Prepurchase entry, funded, not whitelisted, sale not open
  // uint8 internal constant LE_TYPE_PRE_NWL_SO  = 2; // Prepurchase entry, funded, not whitelisted, sale open
  // uint8 internal constant LE_TYPE_PRE_WL_SNO  = 3; // Prepurchase entry, funded, whitelisted, sale not open
  // uint8 internal constant LE_TYPE_PRE_WL_SO   = 4; // Prepurchase entry, funded, whitelisted, sale open - temporary to be transferred to Escrow with PIOs issued via Admin or Web op immediately after sale opens

  // List Browsing actions
  uint8 internal constant BROWSE_FIRST = 1;
  uint8 internal constant BROWSE_LAST  = 2;
  uint8 internal constant BROWSE_NEXT  = 3;
  uint8 internal constant BROWSE_PREV  = 4;

} // End Constants Contract
