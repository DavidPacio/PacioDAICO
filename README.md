# PacioDAICO

Contracts for the Pacio DAICO

This is a WIP Repository. The code is NOT ready for use.

```
Contracts
=========
Contract Description                                      Owned By                                   External Calls
-------- -----------                                      --------                                   --------------
OpMan    Operations management: multisig for critical ops Deployer Self  Hub  Admin                  All including self
Hub      Hub or management contract                       Deployer OpMan Self Admin Sale Poll Web    OpMan Sale Token List Mfund Pfund Poll
Sale     Sale                                             Deployer OpMan Hub  Admin Poll             OpMan Hub List Token Mfund Pfund
Token    PIO Token with EIP-20 functions                  Deployer OpMan Hub  Admin Sale             OpMan List
List     List of participants                             Deployer Poll  Hub  Token Sale
Mfund    Managed fund for PIO purchases or transfers      Deployer OpMan Hub  Admin Sale Poll Pfund  OpMan List
Pfund    Prepurchases escrow fund                         Deployer OpMan Hub  Sale                   OpMan Mfund
Poll     For running Polls                                Deployer OpMan Hub  Admin Web              OpMan Hub Sale List Mfund

where Deployer is the PCL account used to deploy the contracts = ms.sender in the constructors and Truffle deploy script
where Admin is a PCL hardware wallet
      Web is a PCL account used for Pacio DAICO web site access to Hub re white listing etc and to Poll for voting
If a contract makes a state changing call to another contract the callee must have the caller as an owner.
```
