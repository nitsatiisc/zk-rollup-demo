pragma circom 2.0.0;
include "./getMerkleRoot.circom";
include "./circomlib/circuits/mimc.circom";

// Credits: Rollup NC tutorial.
// checks for existence of leaf in tree of depth k

template LeafExistence(k, l){
// k is depth of tree
// l is length of preimage of leaf

    signal input preimage[l]; 
    signal input root;
    signal input paths2_root_pos[k];
    signal input paths2_root[k];

    component leaf = MultiMiMC7(l,91);
    for (var i = 0; i < l; i++){
        leaf.in[i] <== preimage[i];
    }
    leaf.k <== 0;

    component computed_root = GetMerkleRoot(k);
    computed_root.leaf <== leaf.out;

    for (var w = 0; w < k; w++){
        computed_root.paths2_root[w] <== paths2_root[w];
        computed_root.paths2_root_pos[w] <== paths2_root_pos[w];
    }

    // equality constraint: input tx root === computed tx root 
    root === computed_root.out;

}

//component main = LeafExistence(2, 3);
