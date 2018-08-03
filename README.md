# PacioDAICO

Contracts for the Pacio DAICO

This is a WIP Repository. The code is NOT ready for use.

```
Contracts
=========
Contract Description                                      Owned By                                            External Calls
-------- -----------                                      --------                                            --------------
OpMan    Operations management: multisig for critical ops Deployer, Self,  Admin                              All including self
Hub      Hub or management contract                       Deployer, OpMan, Admin, Sale, VoteTap, VoteEnd, Web OpMan; Sale; Token; List; Escrow; Grey; VoteTap; VoteEnd; Mvp
Sale     Sale                                             Deployer, OpMan, Hub, Admin                         OpMan; Hub -> Token,List,Escrow,Grey,VoteTap,VoteEnd,Mvp; List; Token -> List; Escrow; Grey
Token    Token contract with EIP-20 functions             Deployer, OpMan, Hub, Sale, Mvp                     OpMan; List
List     List of participants                             Deployer, OpMan, Hub, Sale, Token, Escrow, Grey     OpMan
Escrow   Escrow management of white list funds            Deployer, OpMan, Hub, Sale, Admin                   OpMan
Grey     Escrow management of funds grey list funds       Deployer, OpMan, Hub, Sale                          OpMan
VoteTap  For a tap vote                                   Deployer, OpMan, Hub                                OpMan; Hub -> Escrow, List
VoteEnd  For a terminate and refund vote                  Deployer, OpMan, Hub                                OpMan; Hub -> Escrow, List
Mvp      Re MVP launch and transferring PIOEs to PIOs     Deployer, OpMan, Hub                                OpMan; List; Token -> List

where Deployer is the PCL account used to deploy the contracts = ms.sender in the constructors and Truffle deploy script
where Admin is a PCL hardware wallet
      Web is a PCL wallet being used for Pacio DAICO web site access to Hub re white listing etc
```
