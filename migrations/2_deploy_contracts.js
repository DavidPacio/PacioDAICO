var OpMan = artifacts.require("./OpMan/OpMan.sol");

/* djh??
// To be changed to deploy all the contracts, recording their addresses, then to call the Initialise() functions.

Contracts
=========
Contract  Description                                                Owned By                         External Calls
--------  -----------                                                --------                         --------------
OpMan     Operations management - multisig approval of critical ops  Deployer, Self,  Admin           All including self
Hub       Hub or management contract                                 Deployer, OpMan, Admin, Sale     OpMan; Sale; Token; List; Escrow; Grey; VoteTap; VoteEnd; Mvp
Sale      Sale                                                       Deployer, OpMan, Hub             OpMan; Hub -> Token,List,Escrow,Grey,VoteTap,VoteEnd,Mvp; List; Token -> List; Escrow; Grey
Token     Token contract with EIP-20 functions                       Deployer, OpMan, Hub, Sale, Mvp  OpMan; List
List      List of participants                                       Deployer, OpMan, Hub, Token      OpMan
Escrow    Escrow management of funds from whitelisted participants   Deployer, OpMan, Hub, Sale       OpMan
Grey      Escrow management of funds from grey list participants     Deployer, OpMan, Hub, Sale       OpMan
VoteTap   For a tap vote                                             Deployer, OpMan, Hub             OpMan; Hub -> Escrow, List
VoteEnd   For a terminate and refund vote                            Deployer, OpMan, Hub             OpMan; Hub -> Escrow, List
Mvp       Re MVP launch and transferring PIOEs to PIOs               Deployer, OpMan, Hub             OpMan; List; Token -> List

where Admin is a PCL hardware wallet

Initialisation and Deployment
#############################
Contracts can be constructed and deployed in any order with contract addresses being recorded by the script.

Then:

OpMan owned by 0 Deployer, 1 OpMan (self), 2 Admin
-----
OpMan.Initialise(address vAdminA, address[] vContractsYA, address[] vSignersYA) IsDeployerCaller
  to set Admin owner, and add initial contracts, signers, and add the OpMan manOps
  After this call all of OpMan's owners are set.
  Arguments:
  - vAdminA       PCL hardware wallet address for Admin owner
  - vContractsYA  Array of contract addresses for Hub, Sale, Token, List, Escrow, Grey, VoteTap, VoteEnd, Mvp in that order. Note, NOT OpMan which the fn uses this for.
  - vSignersYA    Array of the addresses of the initial signers. These will need to be confirmed before they can be used for granting approvals.

  Admin owner needs to be set this way because it can't be be set from the deploy script as ChangeOwnerMO() requires IsOpManCaller.
  Other contracts can have all their owners set via the deploy script because their constructor set OpMan owner to msg.sender (deployment account) initially,
  so 'ChangeOwnerMO() IsOpManCaller' calls can be made by the deploy script, provided that OpMan owner is set last.

Hub owned by 0 Deployer, 1 OpMan, 2 Admin, 3 Sale
---
Hub.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet address as Admin)
Hub.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Hub.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address) <=== Must come after ADMIN_OWNER_X, SALE_OWNER_X have been set
Hub.Initialise() IsDeployerCaller to set the contract address variables.

Sale owned by 0 Deployer, 1 OpMan, 2 Hub
----
Sale.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Sale.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address) <=== Must come after HUB_OWNER_X has been set
Sale.Initialise()  to set the contract address variables.

List owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Token
----
List.ChangeOwnerMO(HUB_OWNER_X, Hub address)
List.ChangeOwnerMO(TOKEN_OWNER_X, Token address)
List.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address) <=== Must come after HUB_OWNER_X, TOKEN_OWNER_X have been set
List.Initialise()  to set the contract address variables.

Token owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Mvp
-----
Token.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Token.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Token.ChangeOwnerMO(MVP_OWNER_X, Mvp address)
Token.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address) <=== Must come after HUB_OWNER_X, SALE_OWNER_X, MVP_OWNER_X have been set
Token.Initialise() To set the contract variable, and do the PIOE minting.

Escrow owned by Deployer, OpMan, Hub, Sale
------
Escrow.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Escrow.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Escrow.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address) <=== Must come after HUB_OWNER_X, SALE_OWNER_X have been set
Escrow.Initialise() to initialise the Escrow contract

Grey owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale
----
Grey.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Grey.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Grey.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address) <=== Must come after HUB_OWNER_X, SALE_OWNER_X have been set
Grey.Initialise() to initialise the Grey contract

VoteTap owned by 0 Deployer, 1 OpMan, 2 Hub
-------
VoteTap.ChangeOwnerMO(HUB_OWNER_X, Hub address)
VoteTap.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address) <=== Must come after HUB_OWNER_X have been set
VoteTap.Initialise() to initialise the VoteTap contract

VoteEnd owned by 0 Deployer, 1 OpMan, 2 Hub
-------
VoteEnd.ChangeOwnerMO(HUB_OWNER_X, Hub address)
VoteEnd.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address) <=== Must come after HUB_OWNER_X have been set
VoteEnd.Initialise() to initialise the VoteEnd contract

Mvp owned by 0 Deployer, 1 OpMan, 2 Hub
---
Mvp.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Mvp.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address) <=== Must come after HUB_OWNER_X have been set
Mvp.Initialise() to initialise the Mvp contract


Hub.InitContracts(...)
Hub.InitEscrow(...)
Hub.SetUsdEtherPrice()
Hub.Issue() to be called repeatedly for all Seed Presale and Private Placement contributors
Hub.StartSale()

*/

module.exports = function(deployer) {
 console.log('Creating OpMan');
           // constructor(address[] vContractsYA, address[] vSignersYA) internal {
//deployer.deploy(OpMan, ['0x324D03c986917483cE053Cd647e697e8917399bC', '0x324D03c986917483cE053Cd647e697e8917399b2'], ['0x324D03c986917483cE053Cd647e697e8917399bC', '0x324D03c986917483cE053Cd647e697e8917399b3'], {gas:7300000});
  deployer.deploy(OpMan);
};
