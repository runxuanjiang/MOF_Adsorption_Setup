psfgen<<ENDMOL

topology ../model/Top_MODEL_NAME.inp

segment XX {
    pdb ./STEP2_XX_liq_BOX_0.pdb
    first none
    last none
}

coordpdb ./STEP2_XX_liq_BOX_0.pdb XX

writepsf ./STEP3_START_XX_liq_BOX_0.psf
writepdb ./STEP3_START_XX_liq_BOX_0.pdb
