/* lib\Constants.sol

Contract to centralise declaration of constants.

Did not use enums because they can't be used with interface contracts. Would have needed to use intrinsic types e.g. uint8 for parameters in interfaces -> possible explicit enum to int conversion issues
*/

pragma solidity ^0.4.24;

contract Constants {
  // State Bits for use with pState                               /- Bit and description
  // All zero                                        =              Nothing started yet
  uint32 internal constant STATE_PRIOR_TO_OPEN_B     =     1; //  0 Open for registration, Prepurchase escrow deposits, and white listing
  uint32 internal constant STATE_SALE_OPEN_B         =     2; //  1 Sale is open. Is unset on any of the closes
  uint32 internal constant STATE_S_CAP_REACHED_B     =     4; //  2 Soft cap reached -> initial draw
  uint32 internal constant STATE_CLOSED_H_CAP_B      =     8; //  3 Sale closed due to hitting hard cap
  uint32 internal constant STATE_CLOSED_TIME_UP_B    =    16; //  4 Sale closed due to running out of time
  uint32 internal constant STATE_CLOSED_POLL_B       =    32; //  5 Sale closed as the result of Yes Poll to close the sale
  uint32 internal constant STATE_CLOSED_MANUAL_B     =    64; //  6 Sale closed manually for whatever reason
  uint32 internal constant STATE_TAPS_OK_B           =   128; //  7 Sale closed with Soft Cap reached.  STATE_S_CAP_REACHED_B and one of the closes must be set. STATE_SALE_OPEN_B must be unset.
  uint32 internal constant STATE_S_CAP_MISS_REFUND_B =   256; //  8 Failed to reach soft cap, contributions being refunded.                    STATE_CLOSED_TIME_UP_B || STATE_CLOSED_MANUAL_B must be set and STATE_SALE_OPEN_B unset
  uint32 internal constant STATE_TERMINATE_REFUND_B  =   512; //  9 A Terminate poll has voted to end the project, contributions being refunded. Any of the closes must be set and STATE_SALE_OPEN_B unset
  uint32 internal constant STATE_MFUND_EMPTY_B       =  1024; // 10 Mfund is empty as a result of refunds or withdrawals emptying the pot
  uint32 internal constant STATE_PFUND_EMPTY_B       =  2048; // 11 Pfund is empty as a result of refunds or withdrawals emptying the pot
  uint32 internal constant STATE_TRANSFER_TO_PB_B    =  4096; // 12 PIOs are being transferred to the Pacio Blockchain
  uint32 internal constant STATE_TRANSFERRED_TO_PB_B =  8192; // 13 All PIOs have been transferred to the Pacio Blockchain = PIO is dead as an ERC-20/EIP-20 token
  uint32 internal constant STATE_POLL_RUNNING_B      = 16384; // 14 A Poll is running. See the Poll contract for details
  // Combos
  uint32 internal constant STATE_DEPOSIT_OK_B        =     3; // STATE_PRIOR_TO_OPEN_B | STATE_SALE_OPEN_B
  uint32 internal constant STATE_SALE_CLOSED_B       =   120; // STATE_CLOSED_H_CAP_B | STATE_CLOSED_TIME_UP_B | STATE_CLOSED_POLL_B | STATE_CLOSED_MANUAL_B. Not STATE_SALE_OPEN_B is subtly different as that could be before anything starts.
  uint32 internal constant STATE_REFUNDING_B         =   768; // STATE_S_CAP_MISS_REFUND_B | STATE_TERMINATE_REFUND_B
  uint32 internal constant STATE_TRANS_ISSUES_NOK_B  = 13056; // STATE_REFUNDING_B | STATE_TRANSFER_TO_PB_B | STATE_TRANSFERRED_TO_PB_B

  // Contract Indices
  uint256 internal constant OPMAN_CONTRACT_X = 0;
  uint256 internal constant HUB_CONTRACT_X   = 1;
  uint256 internal constant SALE_CONTRACT_X  = 2;
  uint256 internal constant TOKEN_CONTRACT_X = 3;
  uint256 internal constant LIST_CONTRACT_X  = 4;
  uint256 internal constant MFUND_CONTRACT_X = 5;
  uint256 internal constant PFUND_CONTRACT_X = 6;
  uint256 internal constant POLL_CONTRACT_X  = 7;

  // Owner Indices
  // Contract Owned By
  //          0        1     2    3     4    5     6
  // OpMan    Deployer Self  Hub  Admin
  // Hub      Deployer OpMan Self Admin Sale Poll  Web
  // Sale     Deployer OpMan Hub  Admin Poll
  // Token    Deployer OpMan Hub  Admin Sale
  // List     Deployer Poll  Hub  Token Sale
  // Mfund    Deployer OpMan Hub  Admin Sale Poll  Pfund
  // Pfund    Deployer OpMan Hub  Sale
  // Poll     Deployer OpMan Hub  Admin Web
  uint256 internal constant DEPLOYER_X    = 0;
  uint256 internal constant OPMAN_OWNER_X = 1;
  uint256 internal constant HUB_OWNER_X   = 2;
  uint256 internal constant ADMIN_OWNER_X = 3;
  uint256 internal constant TOKEN_OWNER_X = 3;
  uint256 internal constant SALE_OWNER_X  = 4;
  uint256 internal constant POLL_OWNER_X  = 5;
  uint256 internal constant PFUND_OWNER_X = 6;
  uint256 internal constant SALE_POLL_OWNER_X  = 4; // /- specific to first contract in the name
  uint256 internal constant HUB_WEB_OWNER_X    = 6; // |
  uint256 internal constant LIST_POLL_OWNER_X  = 1; // |
  uint256 internal constant PFUND_SALE_OWNER_X = 3; // |
  uint256 internal constant POLL_WEB_OWNER_X   = 4; // |

// Managed Operation Indices
uint32 internal constant RESUME_CONTRACT_MO_X           =  0; // OpMan.ResumeContractMO()
uint32 internal constant OPMAN_ADD_SIGNER_MO_X          =  1; // OpMan.AddSignerMO()
uint32 internal constant OPMAN_CHANGE_SIGNER_MO_X       =  2; // OpMan.ChangeSignerMO()
uint32 internal constant OPMAN_UPDATE_MAN_OP_MO_X       =  3; // OpMan.UpdateManOpMO()
uint32 internal constant HUB_SET_PCL_ACCOUNT_MO_X       =  1; // Hub.SetPclAccountMO()
uint32 internal constant HUB_START_SALE_MO_X            =  2; // Hub.StartSaleMO();
uint32 internal constant HUB_SOFT_CAP_REACHED_MO_X      =  3; // Hub.SoftCapReachedMO()
uint32 internal constant HUB_CLOSE_SALE_MO_X            =  4; // Hub.CloseSaleMO()
uint32 internal constant HUB_SET_TRAN_TO_PB_STATE_MO_X  =  5; // Hub.SetTransferToPacioBcStateMO()
uint32 internal constant HUB_SET_LIST_ENTRY_BITS_MO_X   =  6; // Hub.SetListEntryBitsMO()
uint32 internal constant HUB_NEW_OPMAN_CONTRACT_MO_X    =  7; // Hub.NewOpManContractMO()
uint32 internal constant HUB_NEW_HUB_CONTRACT_MO_X      =  8; // Hub.NewHubContractMO()
uint32 internal constant HUB_NEW_SALE_CONTRACT_MO_X     =  9; // Hub.NewSaleContractMO()
uint32 internal constant HUB_NEW_TOKEN_CONTRACT_MO_X    = 10; // Hub.NewTokenContractMO()
uint32 internal constant HUB_NEW_LIST_CONTRACT_MO_X     = 11; // Hub.NewListContractMO()
uint32 internal constant HUB_NEW_MFUND_CONTRACT_MO_X    = 12; // Hub.NewMfundContractMO()
uint32 internal constant HUB_NEW_PFUND_CONTRACT_MO_X    = 13; // Hub.NewPfundContractMO()
uint32 internal constant HUB_NEW_POLL_CONTRACT_MO_X     = 14; // Hub.NewPollContractMO()
uint32 internal constant SALE_SET_CAPS_TRANCHES_MO_X    =  1; // Sale.SetCapsAndTranchesMO()
uint32 internal constant TOKEN_TRAN_UNISSUED_TO_PB_MO_X =  1; // Token.TransferUnIssuedPIOsToPacioBcMO()
uint32 internal constant MFUND_WITHDRAW_TAP_MO_X        =  1; // Mfund.WithdrawTapMO()
uint32 internal constant POLL_CLOSE_YES_MO_X            =  1; // Poll.ClosePollYesMO()
uint32 internal constant POLL_CLOSE_NO_MO_X             =  2; // Poll.ClosePollNoMO()

  // Time
  uint32  internal constant MIN     =    60;
  uint32  internal constant HOUR    =  3600;
  uint32  internal constant DAY     = 86400;
  uint256 internal constant MONTH = 2629800; // 365.25 * 24 * 3600 / 12
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
  uint8 internal constant POLL_TERMINATE_FUNDING_N        = 19; //  c Terminate funding and refund all remaining funds in Mfund in proportion to PIOs held
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

  // List Entry Bits                                                     /- bit and bit setting description
  // Zero                                                                | Undefined so can be used a test for an entry existing
  uint32 internal constant LE_REGISTERED_B                =       1; //  0 Entry has been registered with addedT set but nothing more
  uint32 internal constant LE_SALE_CONTRACT_B             =       2; //  1 Is the Sale Contract entry - where the minted PIOs are held. Has dbId == 1
  uint32 internal constant LE_FUNDED_B                    =       4; //  2 Has contributed wei
  uint32 internal constant LE_HOLDS_PICOS_B               =       8; //  3 Holds Picos. Can be set wo LE_CONTRIBUTOR_B being set as the result of a transfer. Can be set wo LE_M_FUND_B being set for a presale entry
  uint32 internal constant LE_P_FUND_B                    =      16; //  4 Pfund prepurchase entry, always funded. There are 4 types of prepurchase entries as below. If unset then entry is an escrow entry, and must then have either LE_WHITELISTED_B or LE_PRESALE_B set or both.
  uint32 internal constant LE_M_FUND_B                    =      32; //  5 Mfund funded whitelisted with picos entry or unfunded whitelisted with picos entry. See below for more.
  uint32 internal constant LE_WHITELISTED_B               =      64; //  6 Has been whitelisted
  uint32 internal constant LE_MEMBER_B                    =     128; //  7 Is a Pacio Member: Whitelisted with a picosBalance
  uint32 internal constant LE_PRESALE_B                   =     256; //  8 A Presale List entry - Pacio Seed Presale or Pacio Private Placement. /- Can make Tranche 1 purchases but not Tranche 2 to 4 ones on same account
  uint32 internal constant LE_TRANCH1_B                   =     512; //  9 Was or included a Tranche 1 purchase.                                 |   until after soft cap as not entitled to soft cap miss refund                              -
  uint32 internal constant LE_FROM_TRANSFER_OK_B          =    1024; // 10 Transfers from this entry allowed entry even if pTransfersOkB is false. Is set for the Sale contract entry.
  uint32 internal constant LE_PROXY_APPOINTER_B           =    2048; // 11 This entry has appointed a Proxy. Need not be a Member.                                              /- one entry can have both bits set
  uint32 internal constant LE_PROXY_B                     =    4096; // 12 This entry is a Proxy i.e. one or more other entries have appointed it as a proxy. Must be a Member. |  as a proxy can appoint a proxy
  uint32 internal constant LE_DOWNGRADED_B                =    8192; // 13 This entry has been downgraded from whitelisted. Refunding candidate.
  uint32 internal constant LE_BLOCKED_FROM_VOTING_B       =   16384; // 14 Set if a member is blocked from voting by a PGC managed op as a result of trolling etc
  uint32 internal constant LE_TRANSFERRED_TO_PB_B         =   32768; // 15 This entry has had its PIOs transferred to the Pacio Blockchain
  uint32 internal constant LE_P_REFUNDED_S_CAP_MISS_B     =   65536; // 16 Pfund funds Refunded due to soft cap not being reached
  uint32 internal constant LE_P_REFUNDED_SALE_CLOSE_B     =  131072; // 17 Pfund funds Refunded due to not being whitelisted by the time that the sale closes
  uint32 internal constant LE_P_REFUNDED_ONCE_OFF_B       =  262144; // 18 Pfund funds Refunded once off manually for whatever reason
  uint32 internal constant LE_M_REFUNDED_S_CAP_MISS_NPT1B =  524288; // 19 Mfund funds Refunded due to soft cap not being reached. Such refunds do not apply to Mfunds from a presale or tranche 1 purchase.
  uint32 internal constant LE_M_REFUNDED_TERMINATION_B    = 1048576; // 20 Mfund or Presale with picos Refund proportionately according to Picos held following a vote for project termination
  uint32 internal constant LE_M_REFUNDED_ONCE_OFF_B       = 2097152; // 21 Mfund funds Refunded once off manually for whatever reason including downgrade from whitelisted
  // Combos
  uint32 internal constant LE_FUNDED_P_FUND_B             =      20; // LE_FUNDED_B | LE_P_FUND_B
  uint32 internal constant LE_FUNDED_M_FUND_PICOS_B       =      44; // LE_FUNDED_B | LE_M_FUND_B | LE_HOLDS_PICOS_B
  uint32 internal constant LE_M_FUND_PICOS_MEMBER_B       =     168; // LE_M_FUND_B | LE_HOLDS_PICOS_B | LE_MEMBER_B
  uint32 internal constant LE_WHITELISTED_P_FUND_B        =      80; // LE_WHITELISTED_B | LE_P_FUND_B
  uint32 internal constant LE_WHITELISTED_MEMBER_B        =     192; // LE_WHITELISTED_B | LE_MEMBER_B
  uint32 internal constant LE_PRESALE_TRANCH1_B           =     768; // LE_PRESALE_B | LE_TRANCH1_B == not eligible for a soft cap miss refund
  uint32 internal constant LE_SALE_CON_PICOS_FR_TRAN_OK_B =    1034; // LE_SALE_CONTRACT_B | LE_HOLDS_PICOS_B | LE_FROM_TRANSFER_OK_B for the sale contract bit settings
  uint32 internal constant LE_MEMBER_PROXY_B              =    4224; // LE_MEMBER_B | LE_PROXY_B
  uint32 internal constant LE_PROXY_INVOLVED_B            =    6144; // LE_PROXY_APPOINTER_B | LE_PROXY_B
  uint32 internal constant LE_PROXY_APP_VOTE_BLOCK_B      =   18432; // LE_PROXY_APPOINTER_B | LE_BLOCKED_FROM_VOTING_B
  uint32 internal constant LE_MF_PICOS_MEMBER_PROXY_APP_B =    2216; // LE_M_FUND_B | LE_HOLDS_PICOS_B | LE_MEMBER_B | LE_PROXY_APPOINTER_B
  uint32 internal constant LE_MF_PICOS_MEMBER_PROXY_ALL_B =    6312; // LE_M_FUND_B | LE_HOLDS_PICOS_B | LE_MEMBER_B | LE_PROXY_INVOLVED_B
  uint32 internal constant LE_REFUNDED_B                  = 4128768; // LE_P_REFUNDED_S_CAP_MISS_B | LE_P_REFUNDED_SALE_CLOSE_B | LE_P_REFUNDED_ONCE_OFF_B | LE_M_REFUNDED_S_CAP_MISS_NPT1B | LE_M_REFUNDED_TERMINATION_B | LE_M_REFUNDED_ONCE_OFF_B
  uint32 internal constant LE_DEAD_B                      = 4161536; // LE_TRANSFERRED_TO_PB_B | LE_REFUNDED_B  or bits >= 8192
  uint32 internal constant LE_SEND_FUNDS_NOK_B            = 4169986; // LE_DEAD_B | LE_SALE_CONTRACT_B | LE_PRESALE | LE_DOWNGRADED_B
  uint32 internal constant LE_TRANSFERS_NOK_B             = 4161538; // LE_DEAD_B | LE_SALE_CONTRACT_B Starting point check. Could also be more i.e. no PIOs
  uint32 internal constant LE_REFUNDS_NOK_B               = 4161538; // LE_DEAD_B | LE_SALE_CONTRACT_B Starting point check. Could also be more i.e. no funds or no PIOs
  // LE_M_FUND_B:
  // Mfund funded (LE_FUNDED_B set)  whitelisted (LE_WHITELISTED_B set) with picos (LE_HOLDS_PICOS_B set) entry as a result of funds and picos via Sale.pProcess() or a Pfund to Mfund transfer or the whitelisting of a presale entry
  // or unfunded (LE_FUNDED_B unset) whitelisted (LE_WHITELISTED_B set) with picos (LE_HOLDS_PICOS_B set) entry as a result of a Transfer of picos.
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
