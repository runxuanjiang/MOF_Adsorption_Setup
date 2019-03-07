psfgen<<ENDMOL

topology ../../../BUILD/resources/model/Top_Universal.inp

segment AR {
    pdb packed_argon.pdb
    first none
    last none
}

coordpdb ./packed_argon.pdb AR

writepsf ./START_BOX_1.psf
writepdb ./START_BOX_1.pdb
