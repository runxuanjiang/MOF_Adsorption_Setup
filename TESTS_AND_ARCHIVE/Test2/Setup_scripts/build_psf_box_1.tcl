psfgen<<ENDMOL

topology topology.inp

segment RRRR {
    pdb packed_AAAAAA.pdb
    first none
    last none
}

coordpdb ./packed_AAAAAA.pdb RRRR

writepsf ./START_BOX_1.psf
writepdb ./START_BOX_1.pdb
