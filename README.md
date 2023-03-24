<script
  src="https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML"
  type="text/javascript">
</script>

# zk-rollup-demo
This repository contains code for workshop on ZK rollups for the SPACE 2022 conference. We illustrate a toy, but an end to end
zk rollup system, using a local [ganache blockchain](https://trufflesuite.com/ganache/). The workshop illustrates:
- Writing circuits for zero knowledge proofs using [circom](https://github.com/iden3/circom).
- Generating and verifying proofs for above circuits.
- Expressing the state update of rollup chain as a circuit.
- Verifying the proof of state update in a smart contract.



Relevant Links:
- [Node Installation](https://npm.github.io/installation-setup-docs/installing/using-a-node-version-manager.html)
- [Circuit Compiler (circom)](https://github.com/iden3/circom)
- [Zero Knowledge Proofs (snarkjs)](https://github.com/iden3/snarkjs)
- [Local Blockchain for Testing (Ganache)](https://trufflesuite.com/ganache/)
- [Managing Smart Contracts (truffle)](https://trufflesuite.com/truffle/)


Also see for more information:
- [RollupNC tutorial](https://github.com/rollupnc/RollupNC_tutorial)
- [Zkswap Contracts](https://github.com/l2labs/zkswap-contracts)


## Steps to Run

### Setup the Blockchain
1. We first create a blockchain instance in Ganache. Provide for 32 accounts with initial balance as 100.
2. Set network id to 5777 and port to 8545. Set the gas limit per transaction to be high.
3. Add truffle-config.js to the Ganache blockchain.

### Create the initial L2 state
1. For this, we will use the client script merkletree.js to fetch the account data for 32 accounts from the blockchain 
and create initial merkle tree: `node merkletree.js initialize`
2. Note the value of initial root returned by the above script and configure the value in the contract Democoin.sol 
under the `contracts` directory. 
3. Deploy the contracts using `truffle migrate`
4. Copy the address of the deployed contract Democoin from Ganache, and configure the same in the client script
blockchainclient.js

### Commit L2 Blocks to Chain
1. The initial state of the L2 chain is committed as part of deploying the Democoin smart contract.
2. Now, we execute `node merkletree.js commit50` which creates transaction data for block update under 
transactions/txCommitBlock.json
3. Now, we execute `node blockchainclient.js commit` to update the L2 block. This will create a transaction on 
ganache blockchain. This transactions updates the state of L2 chain maintained by the contract Democoin.
4. Now we execute `node blockchainclient.js verify 1` which submits a transaction, attesting correctness of the 
L2 block number 1. The transaction payload contains zero-knowledge proof of update created using data under 
transactions/txInput.json

## Brief Introduction to Zk-Rollups

## Key Components of Layer 2

## Overall Approach

## Implementation Components
  - ### Client Side Library (Javascript)
  - ### Smart Contracts (Solidity)
  - ### Ethereum Blockchain (Ganache)

## Circuit Description of L2 Update
  - ### Public Inputs: old-merkle-root, new-merkle-root, $(sender_i, recv_i, v_i)_{i\in [B]}$.
  - ### Private Inputs: 
    - Intermediate roots for each transaction.
    - Authentication Paths for leaf for sender_i for each i.
    - Authentication Paths for updated leaf for sender_i
    - Authentication paths for receiver leaf before and after update.
    - Valid signature on each transaction data.
  
  - ### Verifying a single transaction 
    - Let $(sender_i, recv_i, v_i)$ be the public part of transaction. Let $root_i$ 
    and $root_{i+1}$ denote the merkle root before and after applying the transaction. 
    - The prover shows knowledge of auxiliary inputs $(eth_i,pk_i, nonce_i, nonce_{i+1}, senderbal_i, introot_i,
    senderpath_i, recvbal_i, recvbal_{i+1}, sig_i)$ such that:
      - $(eth_i||pk_i||senderbal_i||nonce_i)$ is a leaf at position $sender_i$ under $root_i$.
      - $(eth_i||pk_i||senderbal_{i+1}||nonce_i+1)$ is a leaf at position $sender_i$ under $introot_i$ 
      at position $sender_i$.
      
## Linking transactions to L1
