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
    Let $(i, j, v)$ be the public part of transaction denoting transfer of amount 
    $v$ from account $i$ to account $j$. Let $rt$ and $rt'$ denote merkle root 
    of accounts tree before and after applying the transaction. The prover shows 
    knowledge of following witness to prove correctness of update:
    
      - Initial Sender leaf: $(addr_i, pub_i, bal_i, nonce_i)$ and $path_i$ consisting 
      of partner nodes for the sender leaf.
      - Inital Receiver leaf: $(addr_j, pub_j, bal_j, nonce_j)$ and path $path_j$ consisting 
      of partner nodes for the receiver leaf.
      - Updated Sender leaf: $(addr_i, pub_i, bal_i', nonce_i')$ and intermediate root 
      $irt$ computed from updated sender leaf and $path_i$. We also check $v\leq bal_i$, 
      $bal_i'=bal_i-v$ and $nonce_i'=nonce_i+1$.
      - Updated Receiver leaf: $(addr_j, pub_j, bal_j', nonce_j)$ and root $irt'$ computed 
      from updated receiver leaf and $path_j$. We check that $irt'==root'$. 
      - Signature check: Signature $\sigma_i$ which is valid with respect to public key 
      $pub_i$ on message $(i, j, v, nonce_i)$. 
    
  - ### Verifying multiple transactions
    We sequentially repeat the circuit for verifying single transaction, providing 
    intermediate merkle roots after applying each transaction as part of the witness.

  - ### Circuit Complexity
    For a batch size of $B$ transactions, the circuit complexity is roughly $B.C_{one}$ 
    where $C_{one}$ denotes the circuit complexity of verifying one transaction. We decompose 
    $C_{one}$ as:
      - 4 subcircuits $C_{merkle}$ for checking computation of merkle root given leaf 
      and partner nodes. Assuming $d$ to be the depth of the trees, this results in $4d$
      copies of the circuit computing the hash, i.e. $C_{merkle}\approx 4d.C_{hash}$.
      - 1 subcircuit for checking EDDSA signature $\sigma_i$ on message $(i,j,nonce_i)$.
      - 1 comparison. 
    The overall circuit complexity is roughy $B(4d\cdot C_{hash} + C_{sig} + C_{comp})$. For 
    $B=50$,$d=5$, $C_{hash}=1000$, $C_{sig}=1000$ and $C_{comp}=100$, the expression works out 
    to approximately $1$ million.
  


      
## Linking transactions to L1
