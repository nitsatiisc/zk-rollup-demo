#!/bin/sh
CIRCUIT_NAME="verifyMultiTx"
PTAU_FILE="pot21_final.ptau"
KEYS_DIR="zk-keys"

# compile the circom file to r1cs
circom ${CIRCUIT_NAME}.circom --r1cs --wasm

# produce the initial step of circuit specific trusted ceremony
snarkjs groth16 setup ${CIRCUIT_NAME}.r1cs ${PTAU_FILE} ${KEYS_DIR}/${CIRCUIT_NAME}_0000.zkey

# add another contribution to circuit specific key file
snarkjs zkey contribute ${KEYS_DIR}/${CIRCUIT_NAME}_0000.zkey ${KEYS_DIR}/${CIRCUIT_NAME}_0001.zkey --name="Contributor 1" -v

# add another contribution to circuit specific file
snarkjs zkey contribute ${KEYS_DIR}/${CIRCUIT_NAME}_0001.zkey ${KEYS_DIR}/${CIRCUIT_NAME}_0002.zkey --name="Contributor 2" -v

# add a contribution from random beacon
snarkjs zkey beacon ${KEYS_DIR}/${CIRCUIT_NAME}_0002.zkey ${KEYS_DIR}/${CIRCUIT_NAME}_final.zkey 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"

# verify the key
snarkjs zkey verify ${CIRCUIT_NAME}.r1cs ${PTAU_FILE} ${KEYS_DIR}/${CIRCUIT_NAME}_final.zkey

# export the verification key
snarkjs zkey export verificationkey ${KEYS_DIR}/${CIRCUIT_NAME}_final.zkey ${KEYS_DIR}/verification_key.json

# export the solidity smart contract for verification
snarkjs zkey export solidityverifier ${KEYS_DIR}/${CIRCUIT_NAME}_final.zkey ${KEYS_DIR}/verifier.sol