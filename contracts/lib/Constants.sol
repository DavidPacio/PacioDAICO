/* lib\Constants.sol

Contract to centralise declaration of constants.

Did not use enums because they can't be used with interface contracts. Would have needed to use intrinsic types e.g. uint8 for parameters in interfaces -> possible explicit enum to int conversion issues
*/

pragma solidity ^0.4.24;

contract Constants {
  // State Bits for use with pState                               /- Bit and description
  // All zero                                        =              Nothing started yet
  uint32 internal constant STATE_PRIOR_TO_OPEN_B     =     1; //  0 Open for registration, Prepurchase escrow deposits, and white listing
  uint32 internal constant STATE_OPEN_B              =     2; //  1 Sale is open. Is unset on any of the closes
  uint32 internal constant STATE_S_CAP_REACHED_B     =     4; //  2 Soft cap reached -> initial draw
  uint32 internal constant STATE_CLOSED_H_CAP_B      =     8; //  3 Sale closed due to hitting hard cap
  uint32 internal constant STATE_CLOSED_TIME_UP_B    =    16; //  4 Sale closed due to running out of time
  uint32 internal constant STATE_CLOSED_POLL_B       =    32; //  5 Sale closed as the result of Yes Poll to close the sale
  uint32 internal constant STATE_CLOSED_MANUAL_B     =    64; //  6 Sale closed manually for whatever reason
  uint32 internal constant STATE_TAPS_OK_B           =   128; //  7 Sale closed with Soft Cap reached.  STATE_S_CAP_REACHED_B and one of the closes must be set. STATE_OPEN_B must be unset.
  uint32 internal constant STATE_S_CAP_MISS_REFUND_B =   256; //  8 Failed to reach soft cap, contributions being refunded.                    STATE_CLOSED_TIME_UP_B || STATE_CLOSED_MANUAL_B must be set and STATE_OPEN_B unset
  uint32 internal constant STATE_TERMINATE_REFUND_B  =   512; //  9 A Terminate poll has voted to end the project, contributions being refunded. Any of the closes must be set and STATE_OPEN_B unset
  uint32 internal constant STATE_MFUND_EMPTY_B       =  1024; // 10 Mfund is empty as a result of refunds or withdrawals emptying the pot
  uint32 internal constant STATE_PFUND_EMPTY_B       =  2048; // 11 Pfund is empty as a result of refunds or withdrawals emptying the pot
  uint32 internal constant STATE_TRANSFER_TO_PB_B    =  4096; // 12 PIOs are being transferred to the Pacio Blockchain
  uint32 internal constant STATE_TRANSFERRED_TO_PB_B =  8192; // 13 All PIOs have been transferred to the Pacio Blockchain = PIO is dead as an ERC-20/EIP-20 token
  uint32 internal constant STATE_POLL_RUNNING_B      = 16384; // 14 A Poll is running. See the Poll contract for details

  // Combos for anding checks
  uint32 internal constant STATE_DEPOSIT_OK_COMBO_B =    3; // STATE_PRIOR_TO_OPEN_B | STATE_OPEN_B
  uint32 internal constant STATE_CLOSED_COMBO_B     =   56; // Sale closed = STATE_CLOSED_H_CAP_B | STATE_CLOSED_TIME_UP_B | STATE_CLOSED_POLL_B | STATE_CLOSED_MANUAL_B. Not STATE_OPEN_B is subtly different as that could be before anything starts.
  uint32 internal constant STATE_REFUNDING_COMBO_B  =  384; // STATE_S_CAP_MISS_REFUND_B | STATE_TERMINATE_REFUND_B

  // Contract Indices
  uint256 internal constant OP_MAN_CONTRACT_X   = 0;
  uint256 internal constant HUB_CONTRACT_X      = 1;
  uint256 internal constant SALE_CONTRACT_X     = 2;
  uint256 internal constant TOKEN_CONTRACT_X    = 3;
  uint256 internal constant LIST_CONTRACT_X     = 4;
  uint256 internal constant MFUND_CONTRACT_X    = 5;
  uint256 internal constant PFUND_CONTRACT_X    = 6;
  uint256 internal constant POLL_CONTRACT_X     = 7;

  // Owner Indices
  // Contract Owned By
  //          0        1     2     3     4       5     6
  // OpMan    Deployer Self  Admin
  // Hub      Deployer OpMan Admin Sale  Poll   Web
  // Sale     Deployer OpMan Hub   Admin Poll
  // Token    Deployer OpMan Hub   Sale  Admin
  // List     Deployer OpMan Hub   Sale  Poll   Token
  // Mfund    Deployer OpMan Hub   Sale  Poll   Pfund  Admin
  // Pfund    Deployer OpMan Hub   Sale
  // Poll     Deployer OpMan Hub   Admin Web

  uint256 internal constant DEPLOYER_X          = 0; // /- same in all contracts where used
  uint256 internal constant OP_MAN_OWNER_X      = 1; // V
  uint256 internal constant HUB_OWNER_X         = 2;
  uint256 internal constant ADMIN_OWNER_X       = 2;
  uint256 internal constant SALE_OWNER_X        = 3;
  uint256 internal constant POLL_OWNER_X        = 4;
  uint256 internal constant HUB_WEB_OWNER_X     = 5; // /- specific to first contract in the name
  uint256 internal constant SALE_ADMIN_OWNER_X  = 3; // V
  uint256 internal constant TOKEN_ADMIN_OWNER_X = 4;
  uint256 internal constant LIST_TOKEN_OWNER_X  = 5;
  uint256 internal constant MFUND_PFUND_OWNER_X = 5;
  uint256 internal constant MFUND_ADMIN_OWNER_X = 6;
  uint256 internal constant POLL_ADMIN_OWNER_X  = 3;
  uint256 internal constant POLL_WEB_OWNER_X    = 4;

  // Managed Operation Indices
  uint32 internal constant RESUME_MO_X                   =  0; // ResumeMO()
  uint32 internal constant CHANGE_OWNER_BASE_MO_X        =  0; // ChangeOwnerMO() -> 1 and up because actual ManOpX will always be +1 at least, 0 for deployer not being allowed, -> range 1 to 4 allowing for a max of 4 owners after deployer as required for Token
  // Individual contract indices start from 5 after allowing for up to 4 owners after the deployer
  uint32 internal constant OP_MAN_ADD_CONTRACT_MO_X       =  5; // AddContractMO()
  uint32 internal constant OP_MAN_ADD_SIGNER_MO_X         =  6; // AddSignerMO()
  uint32 internal constant OP_MAN_ADD_MAN_OP_MO_X         =  7; // AddManOpMO
  uint32 internal constant OP_MAN_CHANGE_SIGNER_MO_X      =  8; // ChangeSignerMO()
  uint32 internal constant OP_MAN_UPDATE_CONTRACT_MO_X    =  9; // UpdateContractMO()
  uint32 internal constant OP_MAN_UPDATE_MAN_OP_MO_X      = 10; // UpdateManOpMO()
  uint32 internal constant HUB_START_SALE_X               =  5; // Hub.StartSaleMO();
  uint32 internal constant HUB_SOFT_CAP_REACHED_MO_X      =  6; // Hub.SoftCapReachedMO()
  uint32 internal constant HUB_CLOSE_SALE_MO_X            =  7; // Hub.CloseSaleMO()
  uint32 internal constant HUB_SET_TRAN_TO_PB_STATE_MO_X  =  8; // Hub.SetTransferToPacioBcStateMO()
  uint32 internal constant SALE_SET_CAPS_TRANCHES_MO_X    =  5; // Sale.SetCapsAndTranchesMO()
  uint32 internal constant MFUND_SET_PCL_ACCOUNT_MO_X     =  5; // Mfund.SetPclAccountMO()
  uint32 internal constant MFUND_WITHDRAW_MO_X            =  6; // Mfund.WithdrawMO()
  uint32 internal constant POLL_CLOSE_YES_MO_X            =  5; // Poll.ClosePollYesMO()
  uint32 internal constant POLL_CLOSE_NO_MO_X             =  6; // Poll.ClosePollNoMO()
  uint32 internal constant TOKEN_TRAN_UNISSUED_TO_PB_MO_X =  5; // Token.TransferUnIssuedPIOsToPacioBcMO()

  // Time
  uint32  internal constant HOUR       =  3600;
  uint32  internal constant DAY        = 86400;
  uint256 internal constant MONTH    = 2629800; // 365.25 * 24 * 3600 / 12
  //                                                                /--- Not applicable after soft cap hit
  // Poll 'Enum'                                                    |/- Not applicable after sale close
  uint8 internal constant POLL_CLOSE_SALE_N               =  1; //  c Close the sale
  uint8 internal constant POLL_CHANGE_S_CAP_USD_N         =  2; // sc Change Sale.pUsdSoftCap  the USD soft cap
  uint8 internal constant POLL_CHANGE_S_CAP_PIO_N         =  3; // sc Change Sale.pPicoSoftCap the Pico (PIO) soft cap
  uint8 internal constant POLL_CHANGE_H_CAP_USD_N         =  4; //  c Change Sale.pUsdHardCap  the USD hard cap
  uint8 internal constant POLL_CHANGE_H_CAP_PIO_N         =  5; //  c Change Sale.pPicoHardCap the Pico (PIO) hard cap
  uint8 internal constant POLL_CHANGE_SALE_END_TIME_N     =  6; //  c Change Sale.pSaleEndT   the sale end time
  uint8 internal constant POLL_CHANGE_S_CAP_DISP_PC_N     =  7; // sc Change Mfund.pSoftCapDispersalPc the soft cap reached dispersal %
  uint8 internal constant POLL_CHANGE_TAP_RATE_N          =  8; //    Change Mfund.pTapRateEtherPm     the Tap rate in Ether per month. A change to 0 stops withdrawals as a softer halt than a termination poll since the tap can be adjusted back up again to resume funding
  uint8 internal constant POLL_CHANGE_REQUEST_NUM_N       =  9; //    Change Poll.pRequestsToStartPoll      `  Number of Members required to request a poll for it to start automatically
  uint8 internal constant POLL_CHANGE_REQUEST_DAYS_N      = 10; //    Change Poll.pPollRequestConfirmDays      Days in which a request for a Poll must be confirmed by Poll.pRequestsToStartPoll Members for it to start, or else to lapse
  uint8 internal constant POLL_CHANGE_POLL_DAYS_N         = 11; //    Change Poll.pPollRunDays                 Days for which a poll runs
  uint8 internal constant POLL_CHANGE_REPEAT_DAYS_N       = 12; //    Change Poll.pDaysBeforePollRepeat        Days which must elapse before any particular poll can be repeated
  uint8 internal constant POLL_CHANGE_MAX_VOTE_PC_N       = 13; //    Change Poll.pMaxVoteHardCapCentiPc       CentiPercentage of hard cap PIOs as the maximum voting PIOs per Member
  uint8 internal constant POLL_CHANGE_VALID_MEMS_XRT_PC_N = 14; //    Change Poll.pValidMemsExclRrrTermPollsPc Percentage of Members to vote for polls other than Release reserve & restart and Termination ones to be valid
  uint8 internal constant POLL_CHANGE_PASS_XRT_PC_N       = 15; //    Change Poll.pPassVoteExclRrrTermPollsPc  Percentage of yes votes of PIOs voted to approve polls other than Release reserve & restart and Termination ones
  uint8 internal constant POLL_CHANGE_VALID_MEMS_RT_PC_N  = 16; //    Change Poll.pValidMemsRrrTermPollsPc     Percentage of Members to vote for a Release reserve & restart or Termination poll to be valid
  uint8 internal constant POLL_CHANGE_PASS_RT_PC_N        = 17; //    Change Poll.pPassVoteRrrTermPollsPc      Percentage of yes votes of PIOs voted to approve a Release reserve & restart or Termination poll
  uint8 internal constant POLL_RELEASE_RESERVE_PIOS_N     = 18; //  c Release some of the PIOs held in reserve and restart the DAICO
  uint8 internal constant POLL_TERMINATE_FUNDING_N        = 19; //  c Terminate funding and refund all remaining funds in MFund in proportion to PIOs held
                                                                //  |- Require sale to have closed
  uint8 internal constant NUM_POLLS = POLL_TERMINATE_FUNDING_N; // Number of polls

  // Vote 'Enum'
  uint8 internal constant VOTE_YES_N    = 1; // Vote Yes
  uint8 internal constant VOTE_NO_N     = 2; // Vote No
  uint8 internal constant VOTE_REVOKE_N = 3; // Revoke previous vote in the current poll
  // Poll 'Enum'
  uint8 internal constant POLL_YES_N    = 1; // Poll Yes result == VOTE_YES_N
  uint8 internal constant POLL_NO_N     = 2; // Poll No  result == VOTE_NO_N
  uint8 internal constant POLL_INVALID  = 3; // Poll result was invalid due to insufficient members voting

  // List Entry Bits                                                /- bit and bit setting description
  // Zero                                                           | Undefined so can be used a test for an entry existing
  uint32 internal constant LE_REGISTERED_B            =      1; //  0 Entry has been registered with addedT set but nothing more
  uint32 internal constant LE_SALE_CONTRACT_B         =      2; //  1 Is the Sale Contract entry - where the minted PIOs are held. Has dbId == 1
  uint32 internal constant LE_M_FUND_B                =      4; //  2 Mfund funded whitelisted with picos entry or unfunded whitelisted with picos entry. See below for more.
  uint32 internal constant LE_PICOS_B                 =      8; //  3 Holds Picos. Can be set wo LE_M_FUND_B being set for a presale entry
  uint32 internal constant LE_P_FUND_B                =     16; //  4 Pfund prepurchase entry, always funded. There are 4 types of prepurchase entries as below. If unset then entry is an escrow entry, and must then have either LE_WHITELISTED_B or LE_PRESALE_B set or both.
  uint32 internal constant LE_WHITELISTED_B           =     32; //  5 Has been whitelisted
  uint32 internal constant LE_MEMBER_B                =     64; //  6 Is a Pacio Member: Whitelisted with a picosBalance
  uint32 internal constant LE_PRESALE_B               =    128; //  7 A Presale List entry - Pacio Seed Presale or Pacio Private Placement - not yet whitelisted
  uint32 internal constant LE_WAS_PRESALE_B           =    256; //  8 Was a Presale entry which has been whitelisted
  uint32 internal constant LE_FROM_TRANSFER_OK_B      =    512; //  9 Transfers from this entry allowed entry even if pTransfersOkB is false. Is set for the Sale contract entry.
  uint32 internal constant LE_PROXY_APPOINTER_B       =   1024; // 10 This entry has appointed a Proxy. Need not be a Member.                                              /- one entry can have both bits set
  uint32 internal constant LE_PROXY_B                 =   2048; // 11 This entry is a Proxy i.e. one or more other entries have appointed it as a proxy. Must be a Member. |  as a proxy can appoint a proxy
  uint32 internal constant LE_DOWNGRADED_B            =   4096; // 12 This entry has been downgraded from whitelisted. Refunding candidate.
  uint32 internal constant LE_TRANSFERRED_TO_PB_B     =   8192; // 13 This entry has had its PIOs transferred to the Pacio Blockchain
  uint32 internal constant LE_P_REFUND_S_CAP_MISS_B   =  16384; // 14 Pfund funds Refund due to soft cap not being reached
  uint32 internal constant LE_P_REFUND_SALE_CLOSE_B   =  32768; // 15 Pfund funds Refund due to not being whitelisted by the time that the sale closes
  uint32 internal constant LE_P_REFUND_ONCE_OFF_B     =  65536; // 16 Pfund funds Refund once off manually for whatever reason
  uint32 internal constant LE_MNP_REFUND_S_CAP_MISS_B = 131072; // 17 Mfund but not presale Refund due to soft cap not being reached
  uint32 internal constant LE_M_REFUND_TERMINATION_B  = 262144; // 18 Mfund or Presale with picos Refund proportionately according to Picos held following a vote for project termination
  uint32 internal constant LE_M_REFUND_ONCE_OFF_B     = 524288; // 19 Mfund funds Refunded once off manually for whatever reason including downgrade from whitelisted
  // Combos
  uint32 internal constant LE_M_FUND_PICOS_MEMBER_B       =   76; // LE_M_FUND_B | LE_PICOS_B | LE_MEMBER_B
  uint32 internal constant LE_WHITELISTED_MEMBER_B        =   96; // LE_WHITELISTED_B | LE_MEMBER_B
  uint32 internal constant LE_EVER_PRESALE_COMBO_B        =  384; // LE_PRESALE_B | LE_WAS_PRESALE_B
  uint32 internal constant LE_PROXY_INVOLVED_COMBO_B      = 3072; // LE_PROXY_APPOINTER_B | LE_PROXY_B
  uint32 internal constant LE_M_FUND_PICOS_MEMBER_PROXY_B = 3148; // LE_M_FUND_B | LE_PICOS_B | LE_MEMBER_B | LE_PROXY_INVOLVED_COMBO_B
  uint32 internal constant LE_REFUNDED_COMBO_B         = 1032192; // LE_P_REFUND_S_CAP_MISS_B | LE_P_REFUND_SALE_CLOSE_B | LE_P_REFUND_ONCE_OFF_B | LE_MNP_REFUND_S_CAP_MISS_B | LE_M_REFUND_TERMINATION_B | LE_M_REFUND_ONCE_OFF_B
  uint32 internal constant LE_DEAD_COMBO_B             = 1040384; // LE_TRANSFERRED_TO_PB_B | LE_REFUNDED_COMBO_B  or bits >= 8192
  uint32 internal constant LE_NO_SEND_FUNDS_COMBO_B    = 1044610; // LE_DEAD_COMBO_B | LE_SALE_CONTRACT_B | LE_PRESALE | LE_DOWNGRADED_B
  uint32 internal constant LE_NO_REFUND_COMBO_B        = 1040386; // LE_DEAD_COMBO_B | LE_SALE_CONTRACT_B Starting point check. Could also be more i.e. no funds or no PIOs

  // LE_M_FUND_B Mfund funded whitelisted with picos entry as a result of funds and picos via Sale.Buy() or a Pfund to Mfund transfer or the whitelisting of a presale entry
  //              or unfunded whitelisted with picos entry as a result of a Transfer of picos. There is no bit for telling the difference as this doesn't affect any ops, Mfund refunds and voting being based only on the picos balance.
  // There is no need for a Prepurchase refund termination bit as the sale must be closed before a termination vote can occur -> any prepurchase amounts being refundable anyway.

  // Pfund Entry Types: All are funded.
  // uint8 internal constant LE_PF_TYPE_NWL_SNO = 1; // Pfund entry, not whitelisted, sale not open
  // uint8 internal constant LE_PF_TYPE_NWL_SO  = 2; // Pfund entry, not whitelisted, sale open
  // uint8 internal constant LE_PF_TYPE_WL_SNO  = 3; // Pfund entry, whitelisted, sale not open
  // uint8 internal constant LE_PF_TYPE_WL_SO   = 4; // Pfund entry, whitelisted, sale open - temporary to be transferred to Mfund with PIOs issued via Admin or Web op immediately after sale opens

  // List Browsing actions
  uint8 internal constant BROWSE_FIRST = 1;
  uint8 internal constant BROWSE_LAST  = 2;
  uint8 internal constant BROWSE_NEXT  = 3;
  uint8 internal constant BROWSE_PREV  = 4;

} // End Constants Contract
