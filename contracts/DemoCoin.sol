// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;

import "./verifier50.sol";

// Operations:
// createAccount(pubkey)
// deposit(idx, amount)
// transfer(idx1, idx2, amount, nonce)
// withdraw(idx, to_, amount, nonce)

contract DemoCoin is Verifier {

    // contract deployer
    address public owner;
    uint32 public constant MAX_DEPOSITS_PER_BLOCK = 5;
    uint32 public constant MAX_TRANSFERS_PER_BLOCK = 50;
    uint32 public constant MAX_WITHDRAWALS_PER_BLOCK = 5;
    uint32 public constant MAX_OPERATIONS = 50;
    uint public constant INITIAL_ROOT = 18636777963891255578166029100698083723372389828036979507413507400426748427412;

    // Structure for storing L2 accounts
    struct AccountInfo {
        address ethAddr;
        bytes32 pubkey;
        uint balance;
        uint nonce;
    }

    // Enum for operation types
    enum OperationType {
        DEPOSIT,
        TRANSFER,
        WITHDRAW
    }


    struct Operation {
        OperationType opType;
        uint32 from;
        uint32 to;
        uint32 amount;
        uint32 nonce;
    }

    // Information about each rollup block on 
    // main chain
    struct Block {
        uint prevrootHash;
        uint rootHash;                  // initial block should be set with root of genesis account tree
        uint processedDeposits;
        uint totalWithdrawals;
        uint commitBlockNumber;
        uint32 nDeposits;
        uint32 nTransfers;
        uint32 nWithdrawals;
        bytes32 pubDataHash;
    } 

    event BlockCommitEvent(uint blockNumber, uint prevRootHash, uint newRootHash);
    event VerifiedBlockEvent(uint blockNumber, uint prevRootHash, uint newRootHash);



    mapping (uint => Operation) depositOperationQueue;
    mapping (uint => Operation) withdrawalsQueue;
    mapping (uint => Block) blocks;
    //mapping (uint => uint[MAX_OPERATIONS]) pubTxData;
    mapping (address => uint) fundsOnLayer;

    uint totalDepositOperations;
    uint totalWithdrawals;
    uint processedDepositOperations;
    uint processedWithdrawals;
    uint totalBlocksCommitted;
    uint totalBlocksVerified;
    uint numAccounts;

    constructor() {
        totalDepositOperations = 0;
        totalWithdrawals = 0;
        processedDepositOperations = 0;
        processedWithdrawals = 0;
        totalBlocksCommitted = 1;
        totalBlocksVerified = 1;
        numAccounts = 32;
        // set initial root in the genesis block.        
        blocks[0] = Block(
            0,
            INITIAL_ROOT,
            0,
            0,
            block.number,
            0,
            0,
            0, 0);

        owner = msg.sender;
    }

    /*
    function createAccount(string memory pubkey) external returns (bool) {
        bytes32 pubkeybytes = bytes32(bytes(pubkey));
        priorityOperationQueue[totalPriorityOperations] = 
            Operation(OperationType.CREATEACCOUNT, abi.encode(numAccounts, msg.sender, pubkeybytes));
        addressMap[msg.sender] = numAccounts;
        totalPriorityOperations += 1;
        numAccounts += 1;
        return true;
    }
    */

    function getLayerBalance() external view returns (uint) {
        return fundsOnLayer[msg.sender];
    }

    // register a deposit to the contract. 
    // this adds funds to the layer 2.
    receive() external payable {
        fundsOnLayer[msg.sender] += msg.value;
	}

    // Transfer funds to L2 account
    // This registers an operation on L1 queue to transfer from staging funds
    // to the requested L2 account.
    function depositToLayer(uint32 idx, uint32 amount) external returns (bool) {
        require(fundsOnLayer[msg.sender] >= amount, "Insufficient Funds on Layer2");
        fundsOnLayer[msg.sender] -= amount;
        depositOperationQueue[totalDepositOperations] = 
            Operation(OperationType.DEPOSIT, 0, idx, amount, uint32(totalDepositOperations));
        totalDepositOperations++;
        return true;
    }   

    // create a block
    // this will be called by the chain operator to 
    // create a new block containing the latest state of 
    // of the rollup chain. A seperate verifyBlock() transaction
    // will verify this block. 
    function commitNewBlock(
        Operation[MAX_OPERATIONS] calldata _operations,        // encoded on chain operations
        uint _newRoot                           // root of rollup chain 
    )   external returns (bool)
    {

        require(msg.sender == owner, "Only contract owner can call");
        require(totalBlocksCommitted == totalBlocksVerified, "Previous block not verified");

        Operation[MAX_DEPOSITS_PER_BLOCK] memory depositOperations;
        Operation[MAX_TRANSFERS_PER_BLOCK] memory transferOperations;
        Operation[MAX_WITHDRAWALS_PER_BLOCK] memory withdrawalOperations;
        uint[2+MAX_OPERATIONS] memory foldedOperations;

        uint32 nDeposits;
        uint32 nTransfers;
        uint32 nWithdrawals;
        uint32 nOperations = uint32(_operations.length);
        Block memory newBlock;
        
        for(uint32 i=0; i < _operations.length; i++)
        {
            uint8 opType = uint8(_operations[i].opType);
            if (opType == uint8(OperationType.DEPOSIT)) {
                require(nDeposits <= MAX_DEPOSITS_PER_BLOCK, "Exceeded Deposits");
                require(_operations[i].from == 0, "Malformed deposit operation");
                depositOperations[nDeposits] = _operations[i];
                nDeposits++;
            } else if (opType == uint8(OperationType.TRANSFER))
            {
                // TRANSFER = [idx1, idx2, amount, nonce]
                require(nTransfers <= MAX_TRANSFERS_PER_BLOCK, "Exceeded Transfers");
                require(_operations[i].from != 0, "Malformed transfer operation");
                require(_operations[i].to != 0, "Malformed transfer operation");

                transferOperations[nTransfers] = _operations[i];
                nTransfers++;

            } else if (opType == uint8(OperationType.WITHDRAW))
            {
                require(nWithdrawals <= MAX_WITHDRAWALS_PER_BLOCK, "Exceeded Deposits");
                require(_operations[i].to == 0, "Malformed withdrawal operation");
                withdrawalOperations[nWithdrawals] = _operations[i];
                nWithdrawals++;
            } else {
                // error 
                require(false, "Undefined on chain operation");
            }
        }
                
        for(uint32 i=0; i < nDeposits; i++)
        {
            Operation memory onChainOp = depositOperationQueue[processedDepositOperations + i];
            require(onChainOp.opType == depositOperations[i].opType, "Operations don't match");
            require(onChainOp.from == depositOperations[i].from, "Operations don't match");
            require(onChainOp.to == depositOperations[i].to, "Operations don't match");
            require(onChainOp.amount == depositOperations[i].amount, "Operations don't match");
            require(onChainOp.nonce == depositOperations[i].nonce, "Operations don't match");
        }

        // add the withdrawals to withdrawal queue
        for(uint32 i=0; i < nWithdrawals; i++)
        {
            withdrawalsQueue[totalWithdrawals + i] = withdrawalOperations[i];
        }

        newBlock.totalWithdrawals = totalWithdrawals + nWithdrawals;      
        newBlock.processedDeposits = processedDepositOperations + nDeposits;
        newBlock.nDeposits = nDeposits;
        newBlock.nTransfers = nTransfers;
        newBlock.nWithdrawals = nWithdrawals;
        newBlock.commitBlockNumber = block.number;
        newBlock.prevrootHash = blocks[totalBlocksCommitted-1].rootHash;
        newBlock.rootHash = _newRoot;  

        foldedOperations[0] = newBlock.prevrootHash;
        foldedOperations[1] = newBlock.rootHash;

        for(uint32 i=0; i < MAX_OPERATIONS; i++)
        {
            // fold operation into a uint
            uint foldedOperation = 0;
            foldedOperation += _operations[i].from;
            foldedOperation += (1048576*_operations[i].to);
            foldedOperation += (1099511627776*_operations[i].amount);
            foldedOperation += (1125899906842624*_operations[i].nonce);

            foldedOperations[i+2] = foldedOperation;
        }

        newBlock.pubDataHash = sha256(abi.encode(foldedOperations));
        blocks[totalBlocksCommitted] = newBlock;
        emit BlockCommitEvent(totalBlocksCommitted, nOperations, 0);
        totalBlocksCommitted++;
        return true;
    }

    function verifyBlock(
        uint _blockNum,
        uint[2] memory a,       // ZK proof
        uint[2][2] memory b,    // ZK proof
        uint[2] memory c,       // ZK proof
        uint[2 + MAX_OPERATIONS] memory input   // ZK inputs
    ) external returns (bool) {
        require(_blockNum == totalBlocksVerified, "Wrong block totalBlocksVerified");

        Block memory blk = blocks[_blockNum];
        require(blk.prevrootHash == input[0], "Original state mismatch");
        require(blk.rootHash == input[1], "Final state mismatch");

        // compute hash of public data and compare against that in committed block.
        //bytes32 pubDataHash = sha256(abi.encode(input));
        //require(blk.pubDataHash == pubDataHash, "Transaction PubData Mismatch");

        require(verifyProof(a, b, c, input), "Incorrect ZK proof");
        processedDepositOperations = blk.processedDeposits;
        totalWithdrawals = blk.totalWithdrawals;

        emit VerifiedBlockEvent(totalBlocksVerified, 0, 0);
        totalBlocksVerified++;
        return true; 
    }



}
