var List = artifacts.require("./List/List.sol");

module.exports = function(deployer) {
 console.log('Creating List');
  deployer.deploy(List);
};
