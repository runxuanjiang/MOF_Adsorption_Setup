psfgen<<ENDMOL

topology ../../../BUILD/resources/model/Top_Universal.inp

segment XE {
    pdb packed_xenon.pdb
    first none
    last none
}

coordpdb ./packed_xenon.pdb XE

writepsf ./START_BOX_1.psf
writepdb ./START_BOX_1.pdb
