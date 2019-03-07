psfgen<<ENDMOL

topology ../model/Top_MODEL_NAME.inp

segment XX {
    pdb ./STEP2_XX_reservoir_BOX_1.pdb
    first none
    last none
}

coordpdb ./STEP2_XX_reservoir_BOX_1.pdb XX

writepsf ./STEP3_START_XX_reservoir_BOX_1.psf
writepdb ./STEP3_START_XX_reservoir_BOX_1.pdb
