pragma circom 2.0.0;

include "./verifyMerklePath.circom";
include "./verifyEDDSA.circom";
include "./getMerkleRoot.circom";
include "./circomlib/circuits/mimc.circom";
include "./circomlib/circuits/comparators.circom";
// Credits: RollupNC tutorial

template ProcessTx(k){
    // k is depth of accounts tree
    // accounts tree info
    signal input accounts_root;
    signal input sender_index;
    signal input receiver_index;
    signal input amount;
    signal input sender_nonce;

    signal input intermediate_root;
    //signal private input accounts_pubkeys[2**k][2];
    //signal private input accounts_balances[2**k];
    //ignal private input eth_addresses[2**k];
    //signal private input nonces[2**k];


    // transactions info
    signal input sender_pubkey[2];
    signal input sender_balance;
    signal input sender_eth_address;

    signal input receiver_pubkey[2];
    signal input receiver_balance;
    signal input receiver_eth_address;
    signal input receiver_nonce;


    signal input signature_R8x;
    signal input signature_R8y;
    signal input signature_S;

    signal input sender_proof[k];
    signal input sender_proof_pos[k]; // sender index is implicity determined
    signal input receiver_proof[k];
    signal input receiver_proof_pos[k]; // receiver index is implicity

    // output
    signal output new_accounts_root;

    // verify sender account exists in accounts_root
    component senderExistence = LeafExistence(k, 5);
    // modification: component senderExistence = LeafExistence(k, 5)
    senderExistence.preimage[0] <== sender_pubkey[0];
    senderExistence.preimage[1] <== sender_pubkey[1];
    senderExistence.preimage[2] <== sender_balance;
    senderExistence.preimage[3] <== sender_eth_address;
    senderExistence.preimage[4] <== sender_nonce;

    // ensure sender_index corresponds to sender_proof_pos
    var lc_sender_index = 0;
    for (var i=0; i < k; i++) {
        lc_sender_index += (2**i)*(1-sender_proof_pos[i]);
    }

    lc_sender_index === sender_index;


    senderExistence.root <== accounts_root;
    for (var i = 0; i < k; i++){
        senderExistence.paths2_root_pos[i] <== sender_proof_pos[i];
        senderExistence.paths2_root[i] <== sender_proof[i];
    }

    // check that transaction was signed by sender
    
    component signatureCheck = VerifyEdDSAMiMC(4);
    signatureCheck.from_x <== sender_pubkey[0];
    signatureCheck.from_y <== sender_pubkey[1];
    signatureCheck.R8x <== signature_R8x;
    signatureCheck.R8y <== signature_R8y;
    signatureCheck.S <== signature_S;
    signatureCheck.preimage[0] <== sender_index; // mod: sender index, 
    signatureCheck.preimage[1] <== receiver_index; // mod: receiver index,
    signatureCheck.preimage[2] <== amount; // mod: amount
    signatureCheck.preimage[3] <== sender_nonce; // mod: nonce
    
    // debit sender account and hash new sender leaf
    // mod: our leaf has 5 elements
    component newSenderLeaf = MultiMiMC7(5,91);
    newSenderLeaf.in[0] <== sender_pubkey[0];
    newSenderLeaf.in[1] <== sender_pubkey[1];
    newSenderLeaf.in[2] <== sender_balance - amount;
    newSenderLeaf.in[3] <== sender_eth_address;
    newSenderLeaf.in[4] <== sender_nonce + 1;
    newSenderLeaf.k <== 0;
    

    // update accounts_root
    component computed_intermediate_root = GetMerkleRoot(k);
    computed_intermediate_root.leaf <== newSenderLeaf.out;
    for (var i = 0; i < k; i++){
        computed_intermediate_root.paths2_root_pos[i] <== sender_proof_pos[i];
        computed_intermediate_root.paths2_root[i] <== sender_proof[i];
    }

    // check that computed_intermediate_root.out === intermediate_root
    computed_intermediate_root.out === intermediate_root;

    // verify receiver account exists in intermediate_root
    // modification: our leaf has 5 elements
    component receiverExistence = LeafExistence(k, 5);
    receiverExistence.preimage[0] <== receiver_pubkey[0];
    receiverExistence.preimage[1] <== receiver_pubkey[1];
    receiverExistence.preimage[2] <== receiver_balance;
    receiverExistence.preimage[3] <== receiver_eth_address;
    receiverExistence.preimage[4] <== receiver_nonce;

    // ensure receiver_index corresponds to receiver_proof_pos
    var lc_receiver_index = 0;
    for (var i=0; i < k; i++) {
        lc_receiver_index += (2**i)*(1-receiver_proof_pos[i]);
    }

    lc_receiver_index === receiver_index;
    receiverExistence.root <== intermediate_root;
    for (var i = 0; i < k; i++){
        receiverExistence.paths2_root_pos[i] <== receiver_proof_pos[i];
        receiverExistence.paths2_root[i] <== receiver_proof[i];
    }

    // credit receiver account and hash new receiver leaf
    // modification: our leaf has 5 elements
    component newReceiverLeaf = MultiMiMC7(5,91);
    newReceiverLeaf.in[0] <== receiver_pubkey[0];
    newReceiverLeaf.in[1] <== receiver_pubkey[1];
    newReceiverLeaf.in[2] <== receiver_balance + amount;
    newReceiverLeaf.in[3] <== receiver_eth_address;
    newReceiverLeaf.in[4] <== receiver_nonce;
    newReceiverLeaf.k <== 0;
    

    // update accounts_root
    component computed_final_root = GetMerkleRoot(k);
    computed_final_root.leaf <== newReceiverLeaf.out;
    for (var i = 0; i < k; i++){
        computed_final_root.paths2_root_pos[i] <== receiver_proof_pos[i];
        computed_final_root.paths2_root[i] <== receiver_proof[i];
    }

    // match the final accounts_root
    new_accounts_root <== computed_final_root.out;
}

template ProcessMultiTx(nTransactions, k) {
    // public inputs
    signal input old_root;
    signal input final_root;
    signal input accounts_root[nTransactions + 1];
    signal input sender_index[nTransactions];
    signal input receiver_index[nTransactions];
    signal input amount[nTransactions];
    signal input sender_nonce[nTransactions];

    signal input intermediate_root[nTransactions];

    signal input sender_pubkey[nTransactions][2];
    signal input sender_balance[nTransactions];
    signal input sender_eth_address[nTransactions];

    signal input receiver_pubkey[nTransactions][2];
    signal input receiver_balance[nTransactions];
    signal input receiver_eth_address[nTransactions];
    signal input receiver_nonce[nTransactions];


    signal input signature_R8x[nTransactions];
    signal input signature_R8y[nTransactions];
    signal input signature_S[nTransactions];

    signal input sender_proof[nTransactions][k];
    signal input sender_proof_pos[nTransactions][k]; // sender index is implicity determined
    signal input receiver_proof[nTransactions][k];
    signal input receiver_proof_pos[nTransactions][k]; // receiver index is implicity

    signal input folded_tx[nTransactions];

    // check all tx parameters are in specified ranges.
    component compSenderIndex[nTransactions];
    component compReceiverIndex[nTransactions];
    component compAmount[nTransactions];
    component compNonce[nTransactions];

    for(var i=0; i < nTransactions; i++) {
        compSenderIndex[i] = LessThan(20);
        compReceiverIndex[i] = LessThan(20);
        compAmount[i] = LessThan(10);
        compNonce[i] = LessThan(30);

        compSenderIndex[i].in[0] <== sender_index[i];
        compSenderIndex[i].in[1] <== 1000000;

        compReceiverIndex[i].in[0] <== receiver_index[i];
        compReceiverIndex[i].in[1] <== 1000000;

        compAmount[i].in[0] <== amount[i];
        compAmount[i].in[1] <== 1000;

        compNonce[i].in[0] <== sender_nonce[i];
        compNonce[i].in[1] <== 1000000000;


        folded_tx[i] === sender_index[i] + (2**20)*receiver_index[i] + (2**40)*amount[i] + (2**50)*sender_nonce[i];

        compSenderIndex[i].out === 1;
        compReceiverIndex[i].out === 1;
        compAmount[i].out === 1;
        compNonce[i].out === 1;
    }

    component checkOneTx[nTransactions];

    for(var i=0; i < nTransactions; i++) {
        checkOneTx[i] = ProcessTx(k);
        checkOneTx[i].accounts_root <== accounts_root[i];
        checkOneTx[i].sender_index <== sender_index[i];
        checkOneTx[i].receiver_index <== receiver_index[i];
        checkOneTx[i].amount <== amount[i];
        checkOneTx[i].sender_nonce <== sender_nonce[i];
        checkOneTx[i].intermediate_root <== intermediate_root[i];
        checkOneTx[i].sender_pubkey[0] <== sender_pubkey[i][0];
        checkOneTx[i].sender_pubkey[1] <== sender_pubkey[i][1];
        checkOneTx[i].sender_balance <== sender_balance[i];
        checkOneTx[i].sender_eth_address <== sender_eth_address[i];
        checkOneTx[i].receiver_pubkey[0] <== receiver_pubkey[i][0];
        checkOneTx[i].receiver_pubkey[1] <== receiver_pubkey[i][1];
        checkOneTx[i].receiver_balance <== receiver_balance[i];
        checkOneTx[i].receiver_eth_address <== receiver_eth_address[i];
        checkOneTx[i].receiver_nonce <== receiver_nonce[i];

        checkOneTx[i].signature_R8x <== signature_R8x[i];
        checkOneTx[i].signature_R8y <== signature_R8y[i];
        checkOneTx[i].signature_S <== signature_S[i];

        for(var j=0; j < k; j++) {
            checkOneTx[i].sender_proof[j] <== sender_proof[i][j];
            checkOneTx[i].receiver_proof[j] <== receiver_proof[i][j];
            checkOneTx[i].sender_proof_pos[j] <== sender_proof_pos[i][j];
            checkOneTx[i].receiver_proof_pos[j] <== receiver_proof_pos[i][j];
        }

        checkOneTx[i].new_accounts_root === accounts_root[i+1];
    }

    final_root === accounts_root[nTransactions];
    old_root === accounts_root[0];

}

component main {public [old_root, final_root, folded_tx]} = ProcessMultiTx(15,5);
//component main = ProcessMultiTx(20,5);