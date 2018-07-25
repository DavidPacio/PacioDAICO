
/* OpMan\OpMan.sol

OpMan is the Operations Manager for the Pacio DAICO with Multisig signing required to approve critical operations, called 'managed ops' or manOps.

All contracts, including OpMan, should use managed ops for:
- ownership changes
- any administrator type operations

OpMan Processes
1. Set Admin owner, and add initial contracts, signers, and manOps via the Initialise() method to be called from the deploy script
2. Add additional contracts, signers, and manOps as managed ops
   2.1 Admin to add additional contract as a managed op
   2.2 Admin to add additional signer as a managed op
   2.3 Admin to add additional manOp as a managed op
   2.4 Called from contract Initialise() function to add a manOp for the contract
3. Admin to change one signer to another as a managed op
4. Signer:
   4.1 Signer to confirm self as a signer
   4.2 Admin to unconfirm (pause) a signer
5. Update a contract or manOp as a managed ops
   5.1 Admin to update a contract as a managed op
   5.2 Admin to update a manOp as a managed op
6. Signer to start the approval process for a manOp
7. Signer to sign a manOp for approval
8. Approve or reject a request by a contract function to perform a managed op
9. Pause contract and ops
   9.1 Signer to pause a contract, with a call to the contract's Pause() fn if the contract has one. Not a managed op.
   9.2 Signer to pause a manOp. Not a managed op.
A. Resume contract and ops as managed ops
   A.1 Signer to resume a contract as a managed op with a call to the contract's ResumeMO() fn if the contract has one
   A.2 Signer to resume a manOp as a managed op
B. Admin signer to change a contract owner as a managed op

Owners
------
0. OpMan (self)                          - Set by OwnedToken.sol constructor
1. Admin, a PCL hardware wallet account  - Set by Initialise() here

*/

pragma solidity ^0.4.24;

import "../lib/I_Owned.sol";
import "../lib/OwnedOpMan.sol";

contract OpMan is Owned {
  // OpMan specific constants
  uint32 private constant MIN_NUM_SIGNERS = 3;

  struct R_Contract {   // for the array of contracts pContractsYR
    address contractA;  // *
    bool    pausableB;  // * true if contract is pausable i.e. that the contract has a SetPause(bool B) function
    bool    pausedB;    // * true if contract is paused
    uint32  addedT;     //
    uint32  updatedT;   // *
    uint32  numManOps;  // * number of manOps
    mapping (uint256
    => bool) manOpsOpxMB;// * To confirm ownership of manOps by contract
  }                      // |- * = can be updated via a managed op

  struct R_Signer {    // for the pSignersAddrMR mapping keyed by signer address. The address of a signer is also held in pSignersYA
    uint32 addedT;
    uint32 confirmedT; // set when a signer is confirmed
    uint32 numSigs;    // /- updated when signer approves an op
    uint32 lastSigT;   // |
  }

  struct R_ManOp {
    uint32 contractX;    // index of the contract with the operation to be approved
    uint32 sigsRequired; // number of signatures required
    uint32 secsToSign;   // secs in which signing is to be completed
    uint32 startT;       // time that an approval process started
    uint32 sigs;         // number of signatures
    uint32 approvals;    // number of times the manOp has been approved or used
    bool   pausedB;      // true if manOP is paused
    mapping(address => uint32) signedAtAddrMT; // sign time of the sigs by signer to prevent double signing
  }

  // Storage
  R_Contract[] private pContractsYR;                    // Array of the contracts
  mapping(address => uint256) private pContractsAddrMX; // Mapping of contracts by address -> cX (contract index in pContractsYR)
  mapping(uint256 => R_ManOp) private pManOpsOpkMR;     // mapping of  manOps by key manOpK = cX * 100 + manOpX keys so that opXs can repeat i.e. RESUME_X for all Pausible contracts
  uint256[] private pManOpKsYU;                         // Array of the manOps mapping keys manOpK = cX * 100 + manOpX
  mapping(address => R_Signer) private pSignersAddrMR;  // Mapping of the signers keyed by address
  address[] private pSignersYA;                         // Array of the signers to allow a traverse of pSignersAddrMR

  // Events
  // ======
  event InitialiseV(address Deployer);
  event AddContractV(uint256 ContractX, address ContractA, bool Pausable);
  event AddSignerV(address Signer);
  event AddManOpV(uint256 ContractX, uint256 ManOpX, uint32 SigsRequired, uint32 SecsToSign);
  event ChangeSignerV(address OldSignerA, address NewSignerA);
  event ConfirmSignerV(address SignerA);
  event UnConfirmSignerV(address SignerA);
  event UpdateContractV(uint256 ContractX, address ContractA, bool Pausable);
  event UpdateManOpV(uint256 ManOpK, uint32 SigsRequired, uint32 SecsToSign);
  event StartManOpApprovalV(uint256 ManOpK);
  event SignManOpV(address indexed Signer, uint256 ManOpK);
  event ManOpApprovedV(uint256 ManOpK);
  event PauseContractV(uint256 ContractX);
  event ResumeContractV(uint256 ContractX);
  event PauseManOpV(uint256 ManOpK);
  event ResumeManOpV(uint256 ManOpK);
  event ChangeContractOwnerV(uint256 ContractX, address NewOwnerA, uint256 OwnerX);

  // No Constructor (Only the Owned one)
  // ===========

  // Initialisation/Setup Functions
  // ==============================

  // Initialise()
  // ------------
  // 1. Set Admin owner, and add initial contracts, signers, and manOps via the Initialise() method to be called from the deploy script
  // Can only be called once
  // Arguments:
  // - vAdminA       PCL hardware wallet address
  // - vContractsYA  Array of contract addresses for Hub, Sale, Token, List, Escrow, Grey, VoteTap, VoteEnd, Mvp in that order. Note, NOT OpMan which the fn uses this for.
  // - vSignersYA    Array of the addresses of the initial signers. These will need to be confirmed before they can be used for granting approvals.
  function Initialise(address vAdminA, address[] vContractsYA, address[] vSignersYA) external {
    require(iInitialisingB); // To enforce being called only once
    // Set Admin owner
    this.ChangeOwnerMO(1, vAdminA); // requires IsOpManOwner
    // Add initial contracts
    pAddContract(OP_MAN_X, address(this), true); // Self
    uint256 cX = 1;
    for (uint256 j=0; j<vContractsYA.length; j++) {
      pAddContract(cX, vContractsYA[j], cX != LIST_X); // List is the only contract which isn't pausable
      cX++;
    }
    // Add initial signers
    for (j=0; j<vSignersYA.length; j++)
      pAddSigner(vSignersYA[j]);
    // Add initial (OpMan) manOps
    // pAddManOp(uint256 vContractX, uint32 vSigsRequired, uint32 vSecsToSign) private
    pAddManOp(OP_MAN_X, RESUME_X,                 3, HOUR); //  0 ResumeMO()
    pAddManOp(OP_MAN_X, CHANGE_OWNER_BASE_X,      3, HOUR); //  1 ChangeOwnerMO() 0 OpMan owner, in this OpMan case is self
    pAddManOp(OP_MAN_X, CHANGE_OWNER_BASE_X+1,    3, HOUR); //  2 ChangeOwnerMO() 1 Admin owner
    pAddManOp(OP_MAN_X, OP_MAN_ADD_CONTRACT_X,    3, HOUR); //  5 AddContractMO()
    pAddManOp(OP_MAN_X, OP_MAN_ADD_SIGNER_X,      3, HOUR); //  6 AddSignerMO()
    pAddManOp(OP_MAN_X, OP_MAN_ADD_MAN_OP_X,      3, HOUR); //  7 AddManOp()
    pAddManOp(OP_MAN_X, OP_MAN_CHANGE_SIGNER_X,   3, HOUR); //  8 ChangeSignerMO()
    pAddManOp(OP_MAN_X, OP_MAN_UPDATE_CONTRACT_X, 3, HOUR); //  9 UpdateContractMO()
    pAddManOp(OP_MAN_X, OP_MAN_UPDATE_MAN_OP_X,   3, HOUR); // 10 UpdateManOpMO()
    iInitialisingB = false;
    emit InitialiseV(msg.sender);
  }

  // View Methods
  // ============
  function NumContracts() external view returns (uint256) {
    return pContractsYR.length;
  }
  function ContractXA(uint256 cX) external view returns (address) {
    require(cX < pContractsYR.length);
    return pContractsYR[cX].contractA;
  }
  function ContractX(uint256 cX) external view returns (address contractA, bool pausableB, bool pausedB, uint32 addedT, uint32 updatedT, uint32 numManOps, uint32[] manOpsY) {
    require(cX < pContractsYR.length);
    R_Contract storage srContractR = pContractsYR[cX];
    uint32[] memory manOpsYI = new uint32[](srContractR.numManOps);
    uint32 k;
    for (uint256 j=0; j<pManOpKsYU.length; j++) {
      uint256 manOpK = pManOpKsYU[j]; // pManOpKsYU is the array of the manOps mapping keys manOpK = cX * 100 + manOpX
      if (manOpK/100 == cX)
        manOpsYI[k++] = uint32(manOpK);
    }
    return (srContractR.contractA, srContractR.pausableB, srContractR.pausedB, srContractR.addedT, srContractR.updatedT, srContractR.numManOps, manOpsYI);
  }
  function MinNumSigners() external pure returns (uint32) {
    return MIN_NUM_SIGNERS;
  }
  function NumSigners() external view returns (uint256) {
    return pSignersYA.length;
  }
  function Signers() external view returns (address[]) {
    return pSignersYA;
  }
  function NumManagedOperations() external view returns (uint256) {
    return pManOpKsYU.length;
  }
  function ManagedOperationK(uint256 vManOpK) external view returns (uint32 contractX, uint32 sigsRequired, uint32 secsToSign, uint32 startT, uint256 sigsAndApprovals, bool pausedB, address[] signersA, uint32[] signedAtT) {
    R_ManOp storage srManOpR = pManOpsOpkMR[vManOpK];
    require(srManOpR.sigsRequired > 0, 'ManOp not defined');
    address[] memory signersYA = new address[](srManOpR.sigs);
    uint32[] memory signedAtYT = new uint32[](srManOpR.sigs);
    uint32 k;
    for (uint256 j=0; j<pSignersYA.length; j++) {
      if (srManOpR.signedAtAddrMT[pSignersYA[j]] > 0) {
        signersYA[k]    = pSignersYA[j];
        signedAtYT[k++] = srManOpR.signedAtAddrMT[pSignersYA[j]];
      }
    }                                                                                        // sigs & approvals packed into sigsAndApprovals to avoid stack too deep error
    return (srManOpR.contractX, srManOpR.sigsRequired, srManOpR.secsToSign, srManOpR.startT, srManOpR.sigs * 1000 + srManOpR.approvals, srManOpR.pausedB, signersYA, signedAtYT);
  }
  function SignerX(uint256 iX) external view returns (uint32 addedT, uint32 confirmedT, uint32 numSigs, uint32 lastSigT) {
    require(iX < pSignersYA.length);
    R_Signer storage srSigR = pSignersAddrMR[pSignersYA[iX]];
    return (srSigR.addedT, srSigR.confirmedT, srSigR.numSigs, srSigR.lastSigT);
  }

  // Modifier functions
  // ==================
  modifier IsNotDuplicateContract(address vContractA) {
  //require(pContractsAddrMX[vContractA] == 0,'Duplicate contract'); Can't use this because OpMan has a cX of 0
    for (uint256 j=0; j<pContractsYR.length; j++)
      require(vContractA != pContractsYR[j].contractA, 'Duplicate contract');
    _;
  }
  modifier IsNotDuplicateSigner(address vSignerA) {
    require(pSignersAddrMR[vSignerA].addedT == 0, 'Duplicate signer');
    _;
  }
  modifier IsConfirmedSigner {
    require(pSignersAddrMR[msg.sender].confirmedT > 0, 'Not called by a confirmed signer');
    _;
  }

  // Local private functions
  // =======================
  // OpMan.pAddContract()
  // --------------------
  // Called from constructor and AddContractMO() as part of processes:
  // 1.1 Add initial contracts
  // 2.1 Admin to add additional contract as a managed op
  function pAddContract(uint256 vContractX, address vContractA, bool vPausableB) private IsNotDuplicateContract(vContractA) {
    require(pContractsYR.length == vContractX, 'AddContract call out of order');
    pContractsYR.push(R_Contract(
      vContractA,  // address contractA;  // *
      vPausableB,  // bool    pausableB;  // * true if contract is pausable i.e. that the contract has a SetPause(bool B) function
      false,       // bool    pausedB;    // * true if contract is paused
      uint32(now), // uint32  addedT;     //
      0,           // uint32  updatedT;   // *
      0));         // uint32  numManOps;  // * number of manOps
                   // mapping (uint32
                   // => bool) manOpsOpxMB;// * To confirm ownership of ops by contract
                                           // |- * = can be updated via a managed op
    pContractsAddrMX[vContractA] = vContractX; // Mapping of contracts by address -> cX (contract index in pContractsYR)
    emit AddContractV(vContractX, vContractA, vPausableB);
  }

  // OpMan.pAddSigner()
  // ------------------
  // Called for processes:                                     From:
  // 1.2 Add initial signers                                   constructor
  // 2.2 Admin to add additional signer as a managed op  AddSignertMO()
  // The IsNotDuplicateSigner() modifier call ensures that signers are unique.
  function pAddSigner(address vSignerA) private IsNotDuplicateSigner(vSignerA) {
    pSignersAddrMR[vSignerA] = R_Signer(
      uint32(now),  // uint32  addedT;
      0,            // uint32  confirmedT;
      0,            // uint32  numSigs;
      0);           // uint32  lastSigT;
    pSignersYA.push(vSignerA);
    emit AddSignerV(vSignerA);
  }

  // OpMan.pAddManOp()
  // -----------------
  // Called from constructor and AddManOpMO() as part of processes:
  // 1.3 Add initial (OpMan) manOps
  // 2.3 Admin to add additional manOp as a managed op
  function pAddManOp(uint256 vContractX, uint256 vManOpX, uint32 vSigsRequired, uint32 vSecsToSign) private {
    require(vContractX < pContractsYR.length,           'Unknown contract');
    require(pContractsYR[vContractX].manOpsOpxMB[vManOpX] == false, 'ManOp already defined for contract');
    require(vSigsRequired >= MIN_NUM_SIGNERS, 'Insufficient required sigs');
    uint256 manOpK = vContractX * 100 + vManOpX;
    pManOpsOpkMR[manOpK] = R_ManOp(
      uint32(vContractX), // uint32 contractX;   // index of the contract with the operation to be approved
      vSigsRequired, // uint32 sigsRequired;
      vSecsToSign,   // uint32 secsToSign;
      0,             // uint32 startT;
      0,             // uint32 sigs;
      0,             // uint32 approvals;   // number of times the manOp has been approved or used
      false);        // bool   pausedB;     // true if manOP is paused
                     // mapping(address => uint32) signedAtAddrMT; // sign time of the sigs by signer to prevent double signing
    pManOpKsYU.push(manOpK);
    pContractsYR[vContractX].numManOps++;
    pContractsYR[vContractX].manOpsOpxMB[vManOpX] = true;
    emit AddManOpV(vContractX, vManOpX, vSigsRequired, vSecsToSign);
  }

  // OpMan.pIsManOpApproved()
  // ------------------------
  // Called from IsManOpApproved() and OpMan *MO() functions to check if approval for the manOp has been given by the required number of signers
  function pIsManOpApproved(uint256 vManOpK) private returns (bool) {
    R_ManOp storage srManOpR = pManOpsOpkMR[vManOpK];
    require(srManOpR.sigs >= srManOpR.sigsRequired                 // signed the requisite number of times
         && (uint32(now) - srManOpR.startT <= srManOpR.secsToSign) // within time
         && !pContractsYR[srManOpR.contractX].pausedB              // contract is active
         && !srManOpR.pausedB,                                     // manOp is active
            'ManOp not approved'); // also serves to confirm that the op is defined
    srManOpR.sigs = 0;
    emit ManOpApprovedV(vManOpK);
    return true;
  }

  // State changing external methods
  // ===============================

  // OpMan.AddContractMO()
  // ---------------------
  // 2.1 Admin to add additional contract as a managed op
  // Called manually by Admin to add an additional contract not included in the initial deployment. Must be approved.
  function AddContractMO(uint32 vContractX, address vContractA, bool vPausableB) external IsAdminOwner {
    require(pIsManOpApproved(OP_MAN_ADD_CONTRACT_X)); // Same as OP_MAN_X * 100 + OP_MAN_ADD_CONTRACT_X since OP_MAN_X is 0
    pAddContract(vContractX, vContractA, vPausableB);
  }

  // OpMan.AddSignerMO()
  // -------------------
  // 2.2 Admin to add additional signer as a managed op
  // Called manually by Admin to add an additional signer not included in the initial deployment. Must be approved.
  function AddSignerMO(address vSignerA) external IsAdminOwner returns (bool) {
    require(pIsManOpApproved(OP_MAN_ADD_SIGNER_X)); // Same as OP_MAN_X * 100 + OP_MAN_ADD_SIGNER_X
    pAddSigner(vSignerA); // included IsNotDuplicateSigner() call
    return true;
  }

  // OpMan.AddManOpMO()
  // ------------------
  // 2.3 Admin to add additional manOp as a managed op
  // Called manually by Admin to add an additional manOp not included in the initial deployment. Must be approved.
  function AddManOpMO(uint256 vContractX, uint256 vManOpX, uint32 vSigsRequired, uint32 vSecsToSign) external IsAdminOwner returns (bool) {
    require(pIsManOpApproved(OP_MAN_ADD_MAN_OP_X)); // Same as OP_MAN_X * 100 + OP_MAN_ADD_MAN_OP_X
    pAddManOp(vContractX, vManOpX, vSigsRequired, vSecsToSign);
    return true;
  }

  // OpMan.InitAddManOp()
  // ------------------
  // 2.4 Called from contract Initialise() function to add a manOp for the contract
  function InitAddManOp(uint256 vContractX, uint256 vManOpX, uint32 vSigsRequired, uint32 vSecsToSign) external returns (bool) {
    require(iInitialisingB); // To enforce being called only during initialisation
    uint256 cX = pContractsAddrMX[msg.sender];
    require(cX > 0, 'Not called from known contract'); // Not concerned about the cX == 0 (OP_MAN_X) case for OpMan itself as no OpMan functions call this function.
    require(cX == vContractX, 'cX missmatch');
    pAddManOp(vContractX, vManOpX, vSigsRequired, vSecsToSign);
    return true;
  }

  // OpMan.ChangeSignerMO()
  // ----------------------
  // 3. Admin to change one signer to another as a managed op
  function ChangeSignerMO(address vOldSignerA, address vNewSignerA) external IsAdminOwner returns (bool) {
    require(pIsManOpApproved(OP_MAN_CHANGE_SIGNER_X)); // Same as OP_MAN_X * 100 + OP_MAN_CHANGE_SIGNER_X
    uint256 iX = pSignersYA.length;
    for (uint256 j=0; j<pSignersYA.length; j++) {
      if (pSignersYA[j] == vOldSignerA)
        iX = j;
    }
    require(iX < pSignersYA.length, 'Old signer not known');
    delete pSignersAddrMR[vOldSignerA];
    pSignersAddrMR[vNewSignerA] = R_Signer(
      uint32(now),  // uint32  addedT;
      0,            // uint32  confirmedT;
      0,            // uint32  numSigs;
      0);           // uint32  lastSigT;
    pSignersYA[iX] = vNewSignerA;
    emit ChangeSignerV(vOldSignerA, vNewSignerA);
    return true;
  }

  // OpMan.ConfirmSelfAsSigner()
  // ---------------------------
  // 4.1 Signer to confirm self as a signer
  function ConfirmSelfAsSigner() external returns (bool) {
    R_Signer storage srSigR = pSignersAddrMR[msg.sender];
    require(srSigR.addedT > 0, 'Not called by a signer');
    require(srSigR.confirmedT == 0, 'Already confirmed');
    srSigR.confirmedT = uint32(now);
    emit ConfirmSignerV(msg.sender);
    return true;
  }

  // OpMan.UnConfirmSigner()
  // -----------------------
  // 4.2 Admin to unconfirm (pause) a signer
  function UnConfirmSigner(address vSignerA) external IsAdminOwner returns (bool) {
    R_Signer storage srSigR = pSignersAddrMR[vSignerA];
    require(srSigR.confirmedT > 0, 'Signer not confirmed');
    srSigR.confirmedT = 0;
    emit UnConfirmSignerV(vSignerA);
    return true;
  }
  // OpMan.UpdateContractMO()
  // ------------------------
  // 5.1 Admin to update a contract as a managed op
  // New contract address must be unique
  function UpdateContractMO(uint256 vContractX, address vNewContractA, bool vPausableB) external IsAdminOwner IsNotDuplicateContract(vNewContractA) returns (bool) {
    require(pIsManOpApproved(OP_MAN_UPDATE_CONTRACT_X)); // Same as OP_MAN_X * 100 + OP_MAN_UPDATE_CONTRACT_X
    require(vContractX < pContractsYR.length, 'Contract not known');
    R_Contract storage srContractR = pContractsYR[vContractX];
    require(srContractR.addedT > 0, 'Contract not known'); // contract must exist
    delete pContractsAddrMX[srContractR.contractA]; // Mapping of contracts by address -> cX (contract index in pContractsYR)
    srContractR.contractA = vNewContractA; // contractA of R_Contract
    srContractR.pausableB = vPausableB; // pausableB
                                        // pausedB
                                        // addedT
    srContractR.updatedT = uint32(now); // updatedT
                                        // numManOps
                                        // mapping (uint32 => bool) manOpsOpxMB To confirm ownership of ops by contract
    pContractsAddrMX[vNewContractA] = vContractX; // Mapping of contracts by address -> cX (contract index in pContractsYR)
    emit UpdateContractV(vContractX, vNewContractA, vPausableB);
    return true;
  }

  // OpMan.UpdateManOpMO()
  // ---------------------
  // 5.2 Admin to update a manOp as a managed op
  // Can update sigsRequired and secsToSign not contractX
  // Accessed by its Key
  function UpdateManOpMO(uint256 vManOpK, uint32 vSigsRequired, uint32 vSecsToSign) external IsAdminOwner returns (bool) {
    require(pIsManOpApproved(OP_MAN_UPDATE_MAN_OP_X)); // Same as OP_MAN_X * 100 + OP_MAN_UPDATE_MAN_OP_X
    R_ManOp storage srManOpR = pManOpsOpkMR[vManOpK];
    require(srManOpR.sigsRequired > 0, 'ManOp not known');
                                           // uint32(vContractX), // uint32 contractX;   // index of the contract with the operation to be approved
    srManOpR.sigsRequired = vSigsRequired; // uint32 sigsRequired;
    srManOpR.secsToSign   = vSecsToSign;   // uint32 secsToSign;
                                           // uint32 startT;
                                           // uint32 sigs;
                                           // bool    pausedB;     // true if manOP is paused
                                           // mapping(address => uint32) signedAtAddrMT; // sign time of the sigs by signer to prevent double signing
    emit UpdateManOpV(vManOpK, vSigsRequired, vSecsToSign);
    return true;
  }

  // OpMan.StartManOpApproval()
  // --------------------------
  // 6. Signer to start the approval process for a manOp
  // Accessed by its Key
  function StartManOpApproval(uint256 vManOpK) external IsConfirmedSigner returns (bool) {
    R_ManOp storage srManOpR = pManOpsOpkMR[vManOpK];
    require(srManOpR.sigsRequired > 0, 'ManOp not known'); // op is defined
    require(!srManOpR.pausedB,         'ManOp is paused');
    require(srManOpR.sigsRequired <= pSignersYA.length, 'Not enough signers available');
    srManOpR.startT = uint32(now);
    srManOpR.sigs = 0;
    for (uint256 j=0; j<pSignersYA.length; j++)
      delete srManOpR.signedAtAddrMT[pSignersYA[j]];
    emit StartManOpApprovalV(vManOpK);
    return true;
  }

  // OpMan.SignManOp()
  // -----------------
  // 7. Signer to sign a manOp for approval
  // Accessed by its Key
  function SignManOp(uint256 vManOpK) external IsConfirmedSigner returns (bool) {
    R_ManOp storage srManOpR = pManOpsOpkMR[vManOpK];
    require(srManOpR.sigsRequired > 0, 'ManOp not known'); // op is defined
    require(!srManOpR.pausedB,         'ManOp is paused');
    uint32 nowUint32 = uint32(now);
    require(nowUint32 - srManOpR.startT < srManOpR.secsToSign, 'Out of time');
    require(srManOpR.sigs < srManOpR.sigsRequired, 'Already approved');
    require(srManOpR.signedAtAddrMT[msg.sender] == 0, 'Duplicate signing attempt');
    require(pContractsYR[srManOpR.contractX].manOpsOpxMB[vManOpK%100], 'Contract ManOp Unknown');
    srManOpR.sigs++;
    srManOpR.signedAtAddrMT[msg.sender] = nowUint32;
    pSignersAddrMR[msg.sender].numSigs++;
    pSignersAddrMR[msg.sender].lastSigT = nowUint32;
    emit SignManOpV(msg.sender, vManOpK);
    return true;
  }

  // OpMan.IsManOpApproved()
  // -----------------------
  // Called from a contract function using operation management to check if approval for the manOp has been given by the required number of signers
  // Process: 8. Approve or reject a request by a contract function to perform a managed op
  function IsManOpApproved(uint256 vManOpX) external returns (bool) {
    uint256 cX = pContractsAddrMX[msg.sender];
    require(cX > 0 || msg.sender == address(this), 'Not called from known contract'); // The '|| msg.sender == address(this)' test is because cX == 0 (OP_MAN_X) for OpMan itself.
    return pIsManOpApproved(cX * 100 + vManOpX);  // key = cX * 100 + manOpX
  }

  // OpMan.PauseContract()
  // ---------------------
  // 9.1 Signer to pause a contract, with a call to the contract's Pause() fn if the contract has one. Not a managed op.
  function PauseContract(uint256 vContractX) external IsConfirmedSigner returns (bool) {
    require(vContractX < pContractsYR.length, 'Contract not known');
    R_Contract storage srContractR = pContractsYR[vContractX];
    srContractR.pausedB = true;
    if (srContractR.pausableB)
      I_Owned(srContractR.contractA).Pause();
    emit PauseContractV(vContractX);
    return true;
  }

  // OpMan.PauseManOp()
  // ------------------
  // 9.2 Signer to pause a manOp. Not a managed op.
  // Accessed by its Key
  function PauseManOp(uint256 vManOpK) external IsConfirmedSigner returns (bool) {
    R_ManOp storage srManOpR = pManOpsOpkMR[vManOpK];
    require(srManOpR.sigsRequired > 0, 'ManOp not known'); // op is defined
    require(!srManOpR.pausedB,         'ManOp is paused');
    srManOpR.pausedB = true;
    emit PauseManOpV(vManOpK);
    return true;
  }

  // OpMan.ResumeContractMO()
  // ---------------------
  // A.1 Signer to resume a contract as a managed op with a call to the contract's ResumeMO() fn if the contract has one
  function ResumeContractMO(uint256 vContractX) external IsConfirmedSigner returns (bool) {
    require(vContractX < pContractsYR.length, 'Contract not known');
    R_Contract storage srContractR = pContractsYR[vContractX];
    srContractR.pausedB = false;
    if (srContractR.pausableB)
      I_Owned(srContractR.contractA).ResumeMO();   // Owned.ResumeMO() does an IsManOpApproved(RESUME_X) callback
    else
      require(pIsManOpApproved(vContractX * 100)); // No need for + RESUME_X as RESUME_X is 0
    emit ResumeContractV(vContractX);
    return true;
  }

  // OpMan.ResumeManOpMO()
  // ---------------------
  // A.2 Signer to resume a manOp as a managed op
  function ResumeManOpMO(uint256 vManOpK) external IsConfirmedSigner returns (bool) {
    R_ManOp storage srManOpR = pManOpsOpkMR[vManOpK];
    require(srManOpR.sigsRequired > 0, 'ManOp not known'); // op is defined
    require(srManOpR.pausedB,         'ManOp not paused');
    require(pIsManOpApproved(vManOpK));
    srManOpR.pausedB = false;
    emit ResumeManOpV(vManOpK);
    return true;
  }


  // OpMan.ChangeContractOwnerMO()
  // -----------------------------
  // B. Admin signer to change a contract owner as a managed op
  function ChangeContractOwnerMO(uint256 vContractX, uint256 vOwnerX, address vNewOwnerA) external IsAdminOwner IsConfirmedSigner returns (bool) {
    require(vOwnerX < NUM_OWNERS  // NUM_OWNERS is defined in Owned*.sol
         && vNewOwnerA != address(0));
    require(vContractX < pContractsYR.length, 'Contract not known');
  //require(pIsManOpApproved(vContractX * 100 + CHANGE_OWNER_BASE_X + vOwnerX)); No. Is done by Owned.ChangeOwnerMO()
    I_Owned(pContractsYR[vContractX].contractA).ChangeOwnerMO(vOwnerX, vNewOwnerA);
    emit ChangeContractOwnerV(vContractX, vNewOwnerA, vOwnerX);
    return true;
  }

} // End OpMan contract

