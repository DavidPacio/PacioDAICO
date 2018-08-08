var OpMan = artifacts.require("./OpMan/OpMan.sol");

/* djh??
// To be changed to deploy all the contracts, recording their addresses, then to call the Initialise() functions.

Contract Description                                      Owned By                                       External Calls
-------- -----------                                      --------                                       --------------
OpMan    Operations management: multisig for critical ops Deployer Self  Admin                           All including self
Hub      Hub or management contract                       Deployer OpMan Admin Sale  VoteTap VoteEnd Web OpMan; Sale; Token; List; Mfund; Pfund; VoteTap; VoteEnd; Mvp
Sale     Sale                                             Deployer OpMan Hub   Admin                     OpMan; Hub -> Token,List,Mfund,Pfund,VoteTap,VoteEnd,Mvp; List; Token -> List; Mfund; Pfund
Token    Token contract with EIP-20 functions             Deployer OpMan Hub   Sale  Mvp                 OpMan; List
List     List of participants                             Deployer OpMan Hub   Sale  Token               OpMan
Mfund    Managed fund for PIO purchases or transfers      Deployer OpMan Hub   Sale  Pfund   Admin       OpMan
Pfund    Prepurchases escrow fund                         Deployer OpMan Hub   Sale                      OpMan; Mfund
VoteTap  For a tap vote                                   Deployer OpMan Hub                             OpMan; Hub -> Mfund, List
VoteEnd  For a terminate and refund vote                  Deployer OpMan Hub                             OpMan; Hub -> Mfund, List
Mvp      Re MVP launch and transferring PIOEs to PIOs     Deployer OpMan Hub                             OpMan; List; Token -> List

where Deployer is the PCL account used to deploy the contracts = ms.sender in the constructors and Truffle deploy script
where Admin is a PCL hardware wallet
      Web is a PCL wallet being used for Pacio DAICO web site access to Hub re white listing etc

Initialisation and Deployment
#############################
Contracts can be constructed and deployed in any order with contract addresses being recorded by the script.

Then:

OpMan owned by 0 Deployer, 1 OpMan (self), 2 Admin
-----
OpMan.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
OpMan.Initialise(address[] vContractsYA, address[] vSignersYA) IsInitialising
  to set initial contracts, signers, and add the OpMan manOps
  After this call all of OpMan's owners are set.
  Arguments:
  - vContractsYA  Array of contract addresses for Hub, Sale, Token, List, Mfund, Pfund, VoteTap, VoteEnd, Mvp in that order. Note, NOT OpMan which the fn uses this for.
  - vSignersYA    Array of the addresses of the initial signers. These will need to be confirmed before they can be used for granting approvals.

Hub owned by 0 Deployer, 1 OpMan, 2 Admin, 3 Sale, 4 VoteTap, 5 VoteEnd, 6 Web
---
Hub.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
Hub.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
Hub.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Hub.ChangeOwnerMO(VOTE_TAP_OWNER_X , VoteTap address);
Hub.ChangeOwnerMO(VOTE_END_OWNER_X , VoteEnd address);
Hub.ChangeOwnerMO(WEB_OWNER_X, Web account address)
Hub.Initialise() to set the contract address variables and the initial STATE_PRIOR_TO_OPEN_B state

Sale owned by 0 Deployer, 1 OpMan, 2 Hub
----
Sale.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
Sale.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Sale.ChangeOwnerMO(SALE_ADMIN_OWNER_X, PCL hw wallet account address as Admin)
Sale.Initialise()  to set the contract address variables.
Sale.SetCapsAndTranchesMO(uint256 vPicosCapT1, uint256 vPicosCapT2, uint256 vPicosCapT3, uint256 vUsdSoftCap, uint256 vUsdHardCap,
                          uint256 vMinWeiT1, uint256 vMinWeiT2, uint256 vMinWeiT3, uint256 vPriceCCentsT1, uint256 vPriceCCentsT2, uint256 vPriceCCentsT3)
Sale.SetUsdEtherPrice(uint256 vUsdEtherPrice)
Sale.EndInitialise() to end initialising

List owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Token
----
List.ChangeOwnerMO(OP_MAN_OWNER_X  OpMan address)
List.ChangeOwnerMO(HUB_OWNER_X,    Hub address)
List.ChangeOwnerMO(SALE_OWNER_X,   Sale address)
List.ChangeOwnerMO(TOKEN_OWNER_X,  Token address)
List.Initialise()  to set the contract address variables.

Token owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Mvp
-----
Token.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
Token.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Token.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Token.ChangeOwnerMO(MVP_OWNER_X, Mvp address)
Token.Initialise(1) To set the contract variable, and do the PIOE minting. Assumes dbId of 1 for the Sale Contract

Mfund owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale, 4 Pfund, 5 Admin
-----
Mfund.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
Mfund.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Mfund.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Mfund.ChangeOwnerMO(MFUND_PFUND_OWNER_X, Pfund address)
Mfund.ChangeOwnerMO(MFUND_ADMIN_OWNER_X, PCL hw wallet account address as Admin)
Mfund.Initialise() to initialise the Mfund contract
Mfund.SetPclAccountMO(address vPclAccountA) external
Mfund.EndInitialise() to end initialising

Pfund owned by 0 Deployer, 1 OpMan, 2 Hub, 3 Sale
-----
Pfund.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
Pfund.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Pfund.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Pfund.Initialise()

VoteTap owned by 0 Deployer, 1 OpMan, 2 Hub
-------
VoteTap.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
VoteTap.ChangeOwnerMO(HUB_OWNER_X, Hub address)
VoteTap.Initialise()

VoteEnd owned by 0 Deployer, 1 OpMan, 2 Hub
-------
VoteEnd.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
VoteEnd.ChangeOwnerMO(HUB_OWNER_X, Hub address)
VoteEnd.Initialise()

Mvp owned by 0 Deployer, 1 OpMan, 2 Hub
---
Mvp.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
Mvp.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Mvp.Initialise()

Then Manually by Admin
----------------------
Hub.PresaleIssue() for all aggregated Seed Presale and Private Placement contributors
...
Hub.StartSale()

*/

module.exports = function(deployer) {
 console.log('Creating OpMan');
           // constructor(address[] vContractsYA, address[] vSignersYA) internal {
//deployer.deploy(OpMan, ['0x324D03c986917483cE053Cd647e697e8917399bC', '0x324D03c986917483cE053Cd647e697e8917399b2'], ['0x324D03c986917483cE053Cd647e697e8917399bC', '0x324D03c986917483cE053Cd647e697e8917399b3'], {gas:7300000});
  deployer.deploy(OpMan);
};

/*
// Spec: In Truffle, create a migration script that calls the CreateProject function after FundingHub has been deployed.

var FundingHub = artifacts.require("./FundingHub.sol");

module.exports = function(deployer) {
  deployer.deploy(FundingHub)
  .then(function() {
    return FundingHub.deployed()
  }).then(instance => {
    console.log('Creating first project');
    let nowT = new Date(), // now UTC
    deadlineSecs = nowT.getTime()/1000.0 + 3600; // 1 hour from now
    // console.log('nowT', nowT);
    // console.log('deadline secs', deadlineSecs);
    // from needs to be FundingHub owner which will be web3.eth.accounts[0]
    // Make project owner web3.eth.accounts[1]
    // function CreateProject(bytes32 vNameS, address vOwnerA, uint vTargetWei, uint vDeadlineT) FHisActiveAndSenderIsOk IsOwner returns (uint Id) {
    // console.log('CreateProject("First Project via Migrate",'+ web3.eth.accounts[1]+', '+web3.toWei(11, "ether")+', '+deadlineSecs+', '+'{from: '+web3.eth.accounts[0]+', +gas: '+1000000+'})');
    return instance.CreateProject("First Project via Migrate", web3.eth.accounts[1], web3.toWei(11, "ether"), deadlineSecs, {from: web3.eth.accounts[0], gas: 1100000});
  })
  .then(txObj => {
    console.log("First project added. Gas used", txObj.receipt.gasUsed); // 1068241
  }).catch(e => console.log('Error creating initial project in migration script', e));
};
*/
