const snarkjs = require("snarkjs");
const fs = require("fs");
const { stringifyBigInts } = require("wasmsnark/tools/stringifybigint.js");

var Contract = require("web3-eth-contract");
Contract.setProvider('ws://localhost:8545');
const CONTRACT_ABI = JSON.parse(fs.readFileSync('./build/contracts/DemoCoin.json'));
const CONTRACT_ADDR = "0x1b07bA68D3B45520D765601D4409a0268FC39EC3";
var contract = new Contract(CONTRACT_ABI["abi"], CONTRACT_ADDR);

var Web3 = require("web3");
var web3 = new Web3("ws://localhost:8545");

checkConnection = async function() {
    var accounts  = await web3.eth.getAccounts(console.log);
    console.log(accounts[0]);
}

async function commitBlock() {
    var accounts  = await web3.eth.getAccounts();
    const txInputs = JSON.parse(fs.readFileSync("./transactions/txCommitBlock.json"));
    await contract.methods.commitNewBlock(txInputs.operations, txInputs.newRoot).send(
        {from: accounts[0], gasLimit: 10000000}).then(
            function (res) {
                console.log(res);
            }
        );

}


async function verifyBlock(blockNumber) {
    var accounts  = await web3.eth.getAccounts(console.log);
    console.log(accounts[0]);
    const inputs = JSON.parse(fs.readFileSync("./transactions/txInput.json"));
    const { proof, publicSignals } = await snarkjs.groth16.fullProve(inputs, 
        "./verifyMultiTx_js/verifyMultiTx.wasm", "./zk-keys/verifyMultiTx_final.zkey");

    console.log("Proof: ");
    console.log(JSON.stringify(proof, null, 1));

    const vKey = JSON.parse(fs.readFileSync("./zk-keys/verification_key.json"));

    const res = await snarkjs.groth16.verify(vKey, publicSignals, proof);

    if (res === true) {
        console.log("Verification OK");
    } else {
        console.log("Invalid proof");
    }

    const solidityProof = {
        a: stringifyBigInts(proof.pi_a).slice(0, 2),
        b: stringifyBigInts(proof.pi_b)
          .map(x => x.reverse())
          .slice(0, 2),
        c: stringifyBigInts(proof.pi_c).slice(0, 2),
        inputs: publicSignals.map(x => x.toString())
      };


    // now do smart contract verification
    const solidityIsValid = await contract.methods.verifyBlock(
        blockNumber,
        solidityProof.a, 
        solidityProof.b,
        solidityProof.c,
        solidityProof.inputs).send({from:accounts[0], gasLimit: 1000000}).
        then(function(res) {
            console.log(res.status);
        });
    //console.log(solidityIsValid);
}


process_option = async function(argv) {
    console.log(argv[2]);
    if (argv[2].localeCompare("commit") == 0) {
        await commitBlock();
        process.exit(0);
    } else if (argv[2].localeCompare("verify") == 0) {
        await verifyBlock(argv[3]);
        process.exit(0);
    } else if (argv[2].localeCompare("transfer") == 0) {
        var accounts  = await web3.eth.getAccounts();
        // do a normal transfer
        await web3.eth.sendTransaction({from:accounts[argv[3]], to:accounts[argv[4]], value:'1', gasLimit: 1000000});
        process.exit(0);
    }
}

process_option(process.argv);
//checkConnection();
