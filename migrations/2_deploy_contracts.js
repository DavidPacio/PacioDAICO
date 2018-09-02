var OpMan = artifacts.require("./OpMan/OpMan.sol");

/* djh??
// To be changed to deploy all the contracts, recording their addresses, then to call the Initialise() functions.

Contract Description                                      Owned By                                 External Calls
-------- -----------                                      --------                                 --------------
OpMan    Operations management: multisig for critical ops Deployer Self  Admin                     All including self
Hub      Hub or management contract                       Deployer OpMan Admin Sale  Poll   Web    OpMan; Sale; Token; List; Mfund; Pfund; Poll
Sale     Sale                                             Deployer OpMan Hub   Admin               OpMan; Hub -> Token,List,Mfund,Pfund,Poll; List; Token -> List; Mfund; Pfund
Token    Token contract with EIP-20 functions             Deployer OpMan Hub   Sale  Admin         OpMan; List
List     List of participants                             Deployer OpMan Hub   Sale  Token         OpMan
Mfund    Managed fund for PIO purchases or transfers      Deployer OpMan Hub   Sale  Pfund  Admin  OpMan
Pfund    Prepurchases escrow fund                         Deployer OpMan Hub   Sale                OpMan; Mfund
Poll     For running Polls                                Deployer OpMan Hub   Admin               OpMan; Hub -> Mfund, List

where Deployer is the PCL account used to deploy the contracts = ms.sender in the constructors and Truffle deploy script
where Admin is a PCL hardware wallet
      Web is a PCL wallet being used for Pacio DAICO web site access to Hub re white listing etc
If a contract makes a state changing call to another contract the callee must have the caller as an owner.

Initialisation and Deployment
#############################
Contracts can be constructed and deployed in any order with contract addresses being recorded by the script.

Then:

OpMan owned by Deployer OpMan (self) Hub Admin
-----
The OwnedOpMan constructor sets Deployer and OpMan (self)
OpMan.ChangeOwnerMO(HUB_OWNER_X, Hub contract)
OpMan.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
OpMan.Initialise(address[] vContractsYA, address[] vSignersYA) IsInitialising
  to set initial contracts, signers, and add the OpMan manOps
  After this call all of OpMan's owners are set.
  Arguments:
  - vContractsYA  Array of contract addresses for Hub, Sale, Token, List, Mfund, Pfund, Poll in that order. Note, NOT OpMan which the fn uses this for.
  - vSignersYA    Array of the addresses of the initial signers. These will need to be confirmed before they can be used for granting approvals.

Hub owned by Deployer OpMan Self Admin Sale Poll  Web
---
Deployer and Self are set by the OwnedHub constructor
Hub.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
Hub.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
Hub.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Hub.ChangeOwnerMO(POLL_OWNER_X, Poll address)
Hub.ChangeOwnerMO(HUB_WEB_OWNER_X, Web account address)
Hub.Initialise() to set the contract address variables and the initial STATE_PRIOR_TO_OPEN_B state
Hub.SetPclAccountMO(address vPclAccountA) external

Sale owned by Deployer OpMan Hub Admin Poll
----
Sale.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
Sale.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Sale.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
Sale.ChangeOwnerMO(POLL_OWNER_X, Poll address)
Sale.Initialise()  to set the contract address variables.
Sale.SetCapsAndTranchesMO(uint32 vPioHardCapT1, uint32 vPioHardCapT2, uint32 vPioHardCapT3, uint32 vUsdSoftCap, uint32 vPioSoftCap, uint32 vUsdHardCap, uint32 vPioHardCap,
                          uint256 vMinWeiT1, uint256 vMinWeiT2, uint256 vMinWeiT3, uint256 vPriceCCentsT1, uint256 vPriceCCentsT2, uint256 vPriceCCentsT3)
Sale.SetUsdEtherPrice(uint256 vUsdEtherPrice)
Sale.EndInitialise() to end initialising

List owned by Deployer OpMan Hub Token Sale Poll
----
List.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
List.ChangeOwnerMO(HUB_OWNER_X,   Hub address)
List.ChangeOwnerMO(TOKEN_OWNER_X, Token address)
List.ChangeOwnerMO(SALE_OWNER_X,  Sale address)
List.ChangeOwnerMO(POLL_OWNER_X,  Poll address)
List.Initialise()  to set the contract address variables.

Token owned by Deployer OpMan Hub Admin Sale
-----
Token.ChangeOwnerMO(OP_MAN_OWNER_X, OpMan address)
Token.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Token.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
Token.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Token.Initialise() To set the contract variable, and do the PIOE minting

Mfund owned by Deployer OpMan Hub Admin Sale Poll Pfund
-----
Mfund.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
Mfund.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Mfund.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
Mfund.ChangeOwnerMO(SALE_OWNER_X, Sale address)
Mfund.ChangeOwnerMO(POLL_OWNER_X, Poll address)
Mfund.ChangeOwnerMO(PFUND_OWNER_X, Pfund address)
Mfund.Initialise() to initialise the Mfund contract
Mfund.EndInitialise() to end initialising

Pfund owned by Deployer OpMan Hub Sale
-----
Pfund.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
Pfund.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Pfund.ChangeOwnerMO(PFUND_SALE_OWNER_X, Sale address)
Pfund.Initialise()

Poll owned by Deployer OpMan Hub Admin Web
----
Poll.ChangeOwnerMO(OP_MAN_OWNER_X OpMan address)
Poll.ChangeOwnerMO(HUB_OWNER_X, Hub address)
Poll.ChangeOwnerMO(ADMIN_OWNER_X, PCL hw wallet account address as Admin)
Poll.ChangeOwnerMO(POLL_WEB_OWNER_X, Web address)
Poll.Initialise()

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
