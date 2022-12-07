pragma circom 2.0.0;
include "./circomlib/circuits/eddsamimc.circom";
include "./circomlib/circuits/mimc.circom";

// Credits: RollupNC tutorial
template VerifyEdDSAMiMC(k) {
    signal input from_x;
    signal input from_y;
    signal input R8x;
    signal input R8y;
    signal input S;
    signal input preimage[k];
    
    component M = MultiMiMC7(k,91);
    for (var i = 0; i < k; i++){
        M.in[i] <== preimage[i];
    }
    M.k <== 0;
    
    component verifier = EdDSAMiMCVerifier();   
    verifier.enabled <== 1;
    verifier.Ax <== from_x;
    verifier.Ay <== from_y;
    verifier.R8x <== R8x;
    verifier.R8y <== R8y;
    verifier.S <== S;
    verifier.M <== M.out;
}

//component main = VerifyEdDSAMiMC(k);