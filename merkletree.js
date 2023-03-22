const {getCurveFromName, Scalar} = require("ffjavascript");
const fs = require("fs");
const chai = require("chai");
const assert = chai.assert;
const ethers = require("ethers");
const { buildEddsa, buildMimc7 } = require("circomlibjs");

var Web3 = require("web3");
var web3 = new Web3("ws://localhost:8545");
const numAccounts = 32;
const depth = 5;

let mimcjs;
let eddsa;

// stringify a field element for JS processing
function put(x) {
    return mimcjs.F.toString(x);
}

// stringify leaf data
function stringify_data(x) {
    return {
        addr: x.addr.toString(),
        pubkey: [mimcjs.F.toString(x.pubkey[0]), mimcjs.F.toString(x.pubkey[1])],
        balance: x.balance,
        nonce: x.nonce
    };
}

// create initial L2 Account State consisting of:
// 1. JSONIFIED keys[] in account-keys.json consisting of private eddsa keys for each account.
// 2. JSONIFIED data[] in account-data.json consisting of leaf data for each account.
//   2.1 Leaf data for each account consists of [ethereum address, eddsa public key, balance, nonce]
// 3. JSONIFIED nodes[] in merkle-tree.json consisting of nodes in the merkle tree on data[]
initializeAccountTree = async function() {
    eddsa = await buildEddsa();
    mimcjs = await buildMimc7();
    const bn128 = await getCurveFromName("bn128", true);

    // create initial leaves of the merkle tree
    // Each leaf contains [eth-addr, L2 pub key (EDDSA), balance, nonce]
    var accounts = await web3.eth.getAccounts();
    var nodes=[];
    var data=[];
    var keys=[];

    // set internal nodes to 0 for now
    for(let i=0; i < numAccounts-1; i++) nodes[i] = 0;

    var seed = [
        '0', '1', '2', '3', '4', '5', '6', '7',
        '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
        '10', '11', '12', '13', '14', '15', '16', '17',
        '18', '19', '1A', '1B', '1C', '1D', '1E', '1F'
    ];
    // compute leaf nodes from account information
    for(let i=0; i < numAccounts; i++) {
        // choose a 32 byte private key sk from a buffer.
        keys[i] = Buffer.from(seed[i].padStart(64,'0'), "hex");
        // create a public key for a the above private key. pk = sk.G
        let pubKey =  eddsa.prv2pub(keys[i]);
        // data for leaf = [ ethereum-addr, eddsa-pub-key, balance, nonce ]
        data[i] = {addr: ethers.BigNumber.from(accounts[i]), pubkey: pubKey, balance: 100, nonce: 0};
        // actual content of leaf i = mimc(data)
        nodes[numAccounts -1 + i] = mimcjs.multiHash([data[i].pubkey[0], data[i].pubkey[1], data[i].balance, data[i].addr, data[i].nonce]);
    }

    // build merkle tree
    for(let i=0; i < numAccounts-1; i++) {
        console.log(i);
        let j = numAccounts - 2 - i;
        nodes[j] = mimcjs.multiHash([nodes[2*j+1], nodes[2*j+2]]);
    }

    fs.writeFileSync(
        "./accounts-keys.json",
        JSON.stringify(keys.map(x => x.toString("hex"))),
        "utf-8"
    );
    
    fs.writeFileSync(
        "./accounts-data.json",
        JSON.stringify(data.map(x => stringify_data(x))),
        "utf-8"
    );

    fs.writeFileSync(
        "./merkle-tree.json",
        JSON.stringify(nodes.map(x => put(x))),
        "utf-8"
    );

    return put(nodes[0]);
}

// get bits denoting the path in merkle tree for nth leaf
// bit[i] = 1 denotes that the partner node forms the
// right half of the hash to compute parent.
get_bits = function(n, bits) {
    n1 = n;
    for(let i=0; i < depth; ++i)
    {
        bits[i] = 1 - (n1 % 2);
        n1 = Math.floor(n1/2);
    }
}

// get partner nodes of the leaf index idx
// in merkle tree array given by nodes.
get_path = function(nodes, idx, mpath)
{
    pos = numAccounts - 1 + idx;
    for(let i=0; i < depth; ++i)
    {
        console.log(pos);
        if (pos % 2 == 0) {
            mpath[i] = nodes[pos-1];
        } else {
            mpath[i] = nodes[pos+1];
        }
        pos = Math.floor((pos-1)/2);

    }
}

// update the merkle tree (nodes) by updating the
// leaf with index idx, to correspond to data given 
// by premimg.
update_tree = async function(nodes, preimg, idx) {
    mimcjs = await buildMimc7();
    const bn128 = await getCurveFromName("bn128", true);

    nodes[numAccounts - 1 + idx] = mimcjs.multiHash([preimg.pubkey[0], preimg.pubkey[1], preimg.balance, preimg.addr, preimg.nonce]);

    // rebuild merkle tree
    for(let i=0; i < numAccounts-1; i++) {
        let j = numAccounts - 2 - i;
        nodes[j] = mimcjs.multiHash([nodes[2*j+1], nodes[2*j+2]]);
    }
}


check_root = function(root, leaf, path_nodes, path_pos, mimcjs) {
    let computed = leaf;


    // path pos 0, computed goes right
    for(let i=0; i < depth; i++)
    {
        if (path_pos[i] == 0) {
            //console.log("Left");
            computed = mimcjs.multiHash([path_nodes[i], computed]);
        } else {
            //console.log("Right");
            computed = mimcjs.multiHash([computed, path_nodes[i]]);
        }
    }
   
    console.log(put(root));
    console.log(put(computed));
    return (put(computed).localeCompare(put(root)) === 0);
}

// function to process a batch of transactions.
// outputs witness for ZK circuits
// updates the state of accounts-data and merkle-tree
processTxBatch = async function(txBatch)
{
   
    
    eddsa = await buildEddsa();
    mimcjs = await buildMimc7();
    const bn128 = await getCurveFromName("bn128", true);
    // load keys, data and merkle tree
    var keys = JSON.parse(fs.readFileSync("./accounts-keys.json"));
    var data = JSON.parse(fs.readFileSync("./accounts-data.json"));
    var nodes = JSON.parse(fs.readFileSync("./merkle-tree.json")).map(x => mimcjs.F.e(x));
   
    for(let i=0; i < numAccounts; i++)
    {
        data[i].pubkey = data[i].pubkey.map(x => mimcjs.F.e(x));
        data[i].addr = ethers.BigNumber.from(data[i].addr);
    }

    var old_root;
    var final_root;
    var accounts_root = [];
    var sender_index = [];
    var receiver_index = [];
    var amount = [];
    var sender_nonce = [];

    var intermediate_root = [];
    
    var sender_pubkey = []; // a 2D array
    var sender_balance = [];
    var sender_eth_address = [];

    var receiver_pubkey = []; // [nTransactions][2];
    var receiver_balance = []; 
    var receiver_eth_address = [];
    var receiver_nonce = [];


    var signature_R8x = [];
    var signature_R8y = [];
    var signature_S = [];

    var sender_proof = []; // [][k];
    var sender_proof_pos = []; // [][k]
    var receiver_proof = []; // [][k]
    var receiver_proof_pos = []; // [][k];

    var folded_tx = [];

    accounts_root[0] = nodes[0];
    old_root = nodes[0];

    const twoPow20 = Scalar.fromString("1048576");
    const twoPow40 = Scalar.fromString("1099511627776");
    const twoPow50 = Scalar.fromString("1125899906842624");

    for(let i=0; i < txBatch.length; i++)
    {
        sender_index[i] = txBatch[i][1];
        receiver_index[i] = txBatch[i][2];
        amount[i] = txBatch[i][3];
        sender_nonce[i] = txBatch[i][4];

        var si = Scalar.fromString(sender_index[i].toString());
        var ri = Scalar.fromString(receiver_index[i].toString());
        var am = Scalar.fromString(amount[i].toString());
        var nn = Scalar.fromString(sender_nonce[i].toString());
        folded_tx[i] = si + (twoPow20*ri) + (twoPow40*am) + (twoPow50*nn);
        
        
        // generate signature on transaction
        // For demo, we are generating it here. In real situation the sender will generate
        // this signature, and send the signed transfer request to the operator
        var txHash = mimcjs.multiHash([sender_index[i], receiver_index[i], amount[i], sender_nonce[i]]);
        var signature = eddsa.signMiMC(Buffer.from(keys[ sender_index[i] ], "hex"), txHash);
        
        signature_R8x[i] = put(signature['R8'][0]);
        signature_R8y[i] = put(signature['R8'][1]);
        signature_S[i] = signature['S'].toString();

        sender_proof_pos[i] = [];
        get_bits(sender_index[i], sender_proof_pos[i]);
        sender_proof[i] = [];
        get_path(nodes, sender_index[i], sender_proof[i]);

        if (check_root(nodes[0], nodes[numAccounts -1 + sender_index[i]], sender_proof[i], sender_proof_pos[i], mimcjs) === false)
        {
            console.log("Incorrect sender path computed");
        }
        
        sender_proof[i] = sender_proof[i].map(x => put(x));

        // change sender data
        var j = sender_index[i];
        sender_pubkey[i] = [];
        sender_pubkey[i][0] = put(data[j].pubkey[0]);
        sender_pubkey[i][1] = put(data[j].pubkey[1]);
        sender_balance[i] = data[j].balance;
        sender_eth_address[i] = data[j].addr;
        data[j].balance = data[j].balance - amount[i];
        data[j].nonce = data[j].nonce + 1;

        // update merkle tree
        await update_tree(nodes, data[j], j);
        intermediate_root[i] = nodes[0];

        receiver_proof_pos[i] = [];
        get_bits(receiver_index[i], receiver_proof_pos[i]);
        receiver_proof[i] = [];
        get_path(nodes, receiver_index[i], receiver_proof[i]);
        
        if (check_root(nodes[0], nodes[numAccounts -1 + receiver_index[i]], receiver_proof[i], receiver_proof_pos[i], mimcjs) === false)
        {
            console.log("Incorrect receiver path computed");
        }

        receiver_proof[i] = receiver_proof[i].map(x => put(x));
        // change receiver data
        j = receiver_index[i];
        receiver_pubkey[i] = [];
        receiver_pubkey[i][0] = put(data[j].pubkey[0]); 
        receiver_pubkey[i][1] = put(data[j].pubkey[1]); 
        receiver_balance[i] = data[j].balance;
        receiver_eth_address[i] = data[j].addr;
        receiver_nonce[i] = data[j].nonce;
        data[j].balance = data[j].balance + amount[i];

        // update merkle tree
        await update_tree(nodes, data[j], j);
        //nodes = nodes.map(x => put(x));
        accounts_root[i+1] = nodes[0];
    }

    final_root = accounts_root[txBatch.length];

    var txInfo = {
        "old_root": put(old_root),
        "final_root": put(final_root),
        "folded_tx": folded_tx.map(x => x.toString()),
        "accounts_root": accounts_root.map(x => put(x)),
        "sender_index": sender_index,
        "receiver_index": receiver_index,
        "amount": amount,
        "sender_nonce": sender_nonce,
        "intermediate_root": intermediate_root.map(x => put(x)),
        "sender_pubkey": sender_pubkey,
        "sender_balance": sender_balance,
        "sender_eth_address": sender_eth_address.map(x => x.toString()),
        "receiver_pubkey": receiver_pubkey,
        "receiver_balance": receiver_balance,
        "receiver_eth_address": receiver_eth_address.map(x => x.toString()),
        "receiver_nonce": receiver_nonce,
        "signature_R8x": signature_R8x,
        "signature_R8y": signature_R8y,
        "signature_S": signature_S,
        "sender_proof": sender_proof,
        "sender_proof_pos": sender_proof_pos,
        "receiver_proof": receiver_proof,
        "receiver_proof_pos": receiver_proof_pos
    };

    var txCommitInfo = {
        "operations": txBatch,
        "newRoot": put(final_root)
    };

    fs.writeFileSync(
        "./transactions/txInput.json",
        JSON.stringify(txInfo),
        "utf-8"
    );

    
    fs.writeFileSync(
        "./transactions/txCommitBlock.json",
        JSON.stringify(txCommitInfo),
        "utf-8"
    );

    // write updated DB
    fs.writeFileSync(
        "./accounts-data.json",
        JSON.stringify(data.map(x => stringify_data(x))),
        "utf-8"
    );

    fs.writeFileSync(
        "./merkle-tree.json",
        JSON.stringify(nodes.map(x => put(x))),
        "utf-8"
    );

    return put(nodes[0]);


}

// first transaction batch
var txBatch1 = [
    [1, 1, 2, 11, 0], [1, 3, 4, 0, 0], [1, 1, 3, 0, 1], [1, 5, 6, 0, 0], [1, 4, 8, 0, 0],
    [1, 1, 2, 0, 2], [1, 1, 2, 0, 3], [1, 1, 2, 0, 4], [1, 1, 2, 0, 5], [1, 1, 2, 0, 6], 
    [1, 1, 2, 0, 7], [1, 1, 2, 0, 8], [1, 1, 2, 0, 9], [1, 1, 2, 0, 10], [1, 1, 2, 0, 11]
];

// second transaction batch
var txBatch2 = [[1, 1, 2, 11, 12], [1, 3, 4, 0, 1], [1, 1, 3, 0, 13], [1, 5, 6, 0, 1], [1, 4, 8, 0, 1],
    [1, 1, 2, 0, 14], [1, 1, 2, 0, 15], [1, 1, 2, 0, 16], [1, 1, 2, 0, 17], [1, 1, 2, 0, 18], 
    [1, 1, 2, 0, 19], [1, 1, 2, 0, 20], [1, 1, 2, 0, 21], [1, 1, 2, 0, 22], [1, 1, 2, 0, 23]
];

var txBatch50 = [
    [1, 1, 2, 11, 0], [1, 3, 4, 0, 0], [1, 1, 3, 0, 1], [1, 5, 6, 0, 0], [1, 4, 8, 0, 0],
    [1, 1, 2, 0, 2], [1, 1, 2, 0, 3], [1, 1, 2, 0, 4], [1, 1, 2, 0, 5], [1, 1, 2, 0, 6], 
    [1, 1, 2, 0, 7], [1, 1, 2, 0, 8], [1, 1, 2, 0, 9], [1, 1, 2, 0, 10], [1, 1, 2, 0, 11],
    [1, 1, 2, 11, 12], [1, 3, 4, 0, 1], [1, 1, 3, 0, 13], [1, 5, 6, 0, 1], [1, 4, 8, 0, 1],
    [1, 1, 2, 0, 14], [1, 1, 2, 0, 15], [1, 1, 2, 0, 16], [1, 1, 2, 0, 17], [1, 1, 2, 0, 18], 
    [1, 1, 2, 0, 19], [1, 1, 2, 0, 20], [1, 1, 2, 0, 21], [1, 1, 2, 0, 22], [1, 1, 2, 0, 23]
]

for(let i=0; i < 20; i++) {
    txBatch50.push([1, 1, 2, 0, 24+i]);
}


process_option = async function(arg) {
    console.log(arg);
    if (arg.localeCompare("initialize") === 0) {
        root = await initializeAccountTree();
        console.log("Initial Root:", root);
        process.exit(0);
    } else if (arg.localeCompare("commitfirst") === 0) {
        newRoot = await processTxBatch(txBatch1);
        console.log("Created transaction artificats");
        console.log("newRoot:", newRoot);
        process.exit(0);
    } else if (arg.localeCompare("commitsecond") === 0) {
        newRoot = await processTxBatch(txBatch2);
        console.log("Created transaction artificats");
        console.log("newRoot:", newRoot);
        process.exit(0);
    } else if (arg.localeCompare("commit50") === 0) {
        newRoot = await processTxBatch(txBatch50);
        console.log("Created transaction artificats");
        console.log("newRoot:", newRoot);
        process.exit(0);
    }
}

process_option(process.argv[2]);
