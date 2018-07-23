# PacioDAICO

Contracts for the Pacio DAICO

This is a WIP Repository. The code is NOT ready for use.

```
Contracts
=========
Contract  Description                                                Owned By               External Calls
--------  -----------                                                --------               --------------
OpMan     Operations management - multisig approval of critical ops  Self,  Admin           All including self
Hub       Hub or management contract                                 OpMan, Admin, Sale     OpMan; Sale; Token; List; Escrow; Grey; VoteTap; VoteEnd; Mvp
Sale      Sale                                                       OpMan, Hub             OpMan; Hub -> Token,List,Escrow,Grey,VoteTap,VoteEnd,Mvp; List; Token -> List; Escrow; Grey
Token     Token contract with EIP-20 functions                       OpMan, Hub, Sale, Mvp  OpMan; List
List      List of participants                                       OpMan, Hub, Token      OpMan
Escrow    Escrow management of funds from whitelisted participants   OpMan, Hub, Sale       OpMan
Grey      Escrow management of funds from grey list participants     OpMan, Hub, Sale       OpMan
VoteTap   For a tap vote                                             OpMan, Hub             OpMan; Hub -> Escrow, List
VoteEnd   For a terminate and refund vote                            OpMan, Hub             OpMan; Hub -> Escrow, List
Mvp       Re MVP launch and transferring PIOEs to PIOs               OpMan, Hub             OpMan; Token -> List

where Admin is a PCL hardware wallet
```
