var Token = artifacts.require("./Token/Token.sol");

module.exports = function(deployer) {
 console.log('Creating Token');
  deployer.deploy(Token);
};
