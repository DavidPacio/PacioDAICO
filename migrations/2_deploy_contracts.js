var OpMan = artifacts.require("./OpMan/OpMan.sol");

/* djh??
// To be changed to deploy all the contracts, recording their addresses, then to call the Initialise() functions.

Initialisation and Deployment
#############################
Contracts can be constructed and deployed in any order.

Then call:

Hub.ChangeOwnerMO(1, PCL hw wallet address)
Hub.ChangeOwnerMO(2, Sale address)
Hub.ChangeOwnerMO(0, OpMan address) <=== Must come after 1, 2 have been set

Sale.ChangeOwnerMO(1, Hub address)
Sale.ChangeOwnerMO(0, OpMan address) <=== Must come after 1 has been set

Token.ChangeOwnerMO(1, Hub address)
Token.ChangeOwnerMO(2, Sale address)
Token.ChangeOwnerMO(3, Mvp address)
Token.ChangeOwnerMO(0, OpMan address) <=== Must come after 1, 2, 3 have been set

List.ChangeOwnerMO(1, Hub address)
List.ChangeOwnerMO(2, Token address)
List.ChangeOwnerMO(0, OpMan address) <=== Must come after 1, 2 have been set

Escrow.ChangeOwner1('Hub address')   Escrow.Owner1 = Hub
Escrow.ChangeOwner2('Sale address')  Escrow.Owner2 = Sale

  Grey.ChangeOwner1('Hub address')     Grey.Owner1 = Hub
  Grey.ChangeOwner2('Sale address')    Grey.Owner2 = Sale

VoteTap.ChangeOwner('Hub address')  VoteTap.Owner  = Hub
VoteEnd.ChangeOwner('Hub address')  VoteTap.Owner  = Hub

Mvp.ChangeOwner('Hub address')          Mvp.Owner  = Hub

Then
OpMan.Initialise(address vAdminA, address[] vContractsYA, address[] vSignersYA)
  - vAdminA       PCL hardware wallet address
  - vContractsYA  Array of contract addresses for Hub, Sale, Token, List, Escrow, Grey, VoteTap, VoteEnd, Mvp in that order. Note, NOT OpMan which the fn uses this for.
  - vSignersYA    Array of the addresses of the initial signers. These will need to be confirmed before they can be used for granting approvals.

Hub.Initialise()

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
