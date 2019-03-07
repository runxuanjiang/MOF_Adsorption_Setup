#!/bin/bash

e="xxEEE_EE"
s="xxS_SSS"
n="xxNN"

BASE_DIR=$( pwd )

if [[ $# -eq 1 ]]; then
    CONFIG_FILE
else
    CONFIG_FILE='build_config.dat'
fi

##############################################
# 1. Read in general vars from config file.
##############################################

#read w/ awk

MODEL_NAME=$( awk '/^MODEL_NAME/{print $2}' ${CONFIG_FILE} )
RUNS=$( awk '/^RUNS/{print $2}' ${CONFIG_FILE} )
RUN_LETTER=$( awk '/^RUN_LETTER/{print $2}' ${CONFIG_FILE} )
BRIDGE=$( awk '/^BRIDGE/{print $2}' ${CONFIG_FILE} )
PACK_BOX_SIZE=$( awk '/^PACK_BOX_SIZE/{print $2}' ${CONFIG_FILE} )
SIM_BOX_SIZE=$( awk '/^SIM_BOX_SIZE/{print $2}' ${CONFIG_FILE} )
N_IN_LIQUID=$( awk '/^N_IN_L/{print $2}' ${CONFIG_FILE} )
N_IN_RESERVOIR=$( awk '/^N_IN_R/{print $2}' ${CONFIG_FILE} )
COMP_NAME_SHORT=$( awk '/^COMP_NAME_S/{print $2}' ${CONFIG_FILE} )
COMP_NAME_FULL=$( awk '/^COMP_NAME_F/{print $2}' ${CONFIG_FILE} )
R_CUT=$( awk '/^R_CUT/{print $2}' ${CONFIG_FILE} )

#print out results
echo ""
echo "  ----------------------"
echo " - READ SETUP PARAMS -"
echo "==================="
echo ""
echo "Model name: "${MODEL_NAME}
echo "Runs: "${RUNS}
echo "Run letter: "${RUN_LETTER}
echo "Bridge: "${BRIDGE}
PSZ=$PACK_BOX_SIZE
SSZ=$SIM_BOX_SIZE
echo "Pack sz.: "$PSZ" x "$PSZ" x "$PSZ" A  ; Sim. box sz.: "\
$SSZ" x "$SSZ" x "$SSZ" A"
echo "N in liq.: "$N_IN_LIQUID" molec. ; N in reservoir: "\
$N_IN_RESERVOIR" molec."
echo "Target residue: "$COMP_NAME_SHORT" ; shorthand: "${COMP_NAME_SHORT}
echo ""

#################################################
# 2. Set up arrays
#################################################

#Set up run specific parameters

declare -a RUN
declare -a STATE
declare -a FOUND

#Set up default values of arrays.

for (( r=0; r < $RUNS; r++)); do
    rn=${r}
    ((rn++))
    RUN[$r]=$rn
    FOUND[$r]='0'
done

#Set the expected state of each sim.

for (( r=0; r < ${BRIDGE}; r++)); do
    STATE[$r]='v'
done
rTmp=${BRIDGE}
((rTmp--))
STATE[$rTmp]='b'
for (( r=${BRIDGE}; r < $RUNS; r++)); do
    STATE[$r]='l'
done

#################################################
# 3. Read in specific vars.
#################################################

#Grab values

RUN_NUM=( $( awk '/^R /{print $2}' ${CONFIG_FILE} ) )
RUN_T=( $( awk '/^R /{print $3}' ${CONFIG_FILE} ) )
RUN_CP=( $( awk '/^R /{print $4*-1}' ${CONFIG_FILE} ) )
RUN_CBMC_1ST=( $( awk '/^R /{print $5}' ${CONFIG_FILE} ) )
RUN_CBMC_NTH=( $( awk '/^R /{print $6}' ${CONFIG_FILE} ) )

#Assign to corresponding indices (in case out of order) 

for (( r=0; r < ${#RUN_NUM[@]}; r++)); do
    rn=${RUN_NUM[$r]}
    ((rn--))
    CP[$rn]=${RUN_CP[$r]}
    CBMC_1ST[$rn]=${RUN_CBMC_1ST[$r]}
    CBMC_NTH[$rn]=${RUN_CBMC_NTH[$r]}
    T_K[$rn]=${RUN_T[$r]}
    FOUND[$rn]='1'
done

#Print our setup for filekeeping/errorchecking

echo ""
echo "  --------------------"
echo " - READ RUN POINTS -"
echo "=================="
echo "                 Chem.      CBMC LJ     Kind"
echo "Run #   T(K)      Pot.    1st   nth  (v,l, or b)"
echo "------------------------------------------------"
for (( r=0; r < $RUNS; r++ )); do
    if [[ ${STATE[$r]} == 'v' ]]; then
       STATE_FULL="vapor"
    elif [[ ${STATE[$r]} == 'l' ]]; then
       STATE_FULL="liquid"
    else

       STATE_FULL="bridge"
    fi
    printf "%2s      %3d     %4d     %2d   %2d    %s\n" \
        ${RUN[$r]} ${T_K[$r]} "-${CP[$r]}" \
	${CBMC_1ST[$r]} ${CBMC_NTH[$r]} $STATE_FULL 
done

echo ""
echo ""

#Check and make sure all were set, if not exit 

ERR_RUN_NOT_FOUND='0'
for (( r=0; r < ${#RUN[@]}; r++)); do
    if [[ ${FOUND[$r]} -eq '0' ]]; then
        ERR_RUN_NOT_FOUND='1'
        echo "Run "${RUN[r]}" was not found in file."
    fi
done
if [[ ERR_RUN_NOT_FOUND -eq '1' ]]; then
    echo "You asked for "$RUNS" runs!"
    echo ""
    exit
fi

#################################################
# 4. Build system
#################################################

cd resources/pack

# Print header msg.

echo "Packing boxes w/ Packmol....."
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo ""
# Modify pack and run it

sed -i "s#FULL_NAME#${COMP_NAME_FULL}#g" pack_*inp
sed -i "s#XX#${COMP_NAME_SHORT}#g" pack_*inp
sed -i "s#LLL#${N_IN_LIQUID}#g" pack_*inp
sed -i "s#RRR#${N_IN_RESERVOIR}#g" pack_*inp
sed -i "s#BBS#${PACK_BOX_SIZE}#g" pack_*inp

# Pack boxes

./packmol < pack_liq*0.inp >& pack_l_B0_results.log
./packmol < pack_vap*0.inp >& pack_v_B0_results.log
./packmol < pack_res*1.inp >& pack_r_B1_results.log

# Print files we built for bookkeeping, exit on error

if [[ $( ls STEP2* 2> /dev/null | wc -l ) -eq '3' ]]; then
    echo "Pack was a success... see files:"
    echo ""
    OUT_NAMES=( $( ls | grep STEP2 ) )
    for OUT_NAME in ${OUT_NAMES[@]}; do
        echo $OUT_NAME
    done
    echo ""
else
    echo "Pack was failure, exiting..."
    echo ""
    exit
fi

# Print header msg.

echo ""
echo "Generating topology w/ PSFGEN....."
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo ""

# Modify build.tcl files

sed -i "s#MODEL_NAME#${MODEL_NAME}#g" build*tcl
sed -i "s#XX#${COMP_NAME_SHORT}#g" build*tcl

# Run system building scripts.

./build_liq*0.tcl >& build_top_l_B0_results.log
./build_vap*0.tcl >& build_top_v_B0_results.log
./build_res*1.tcl >& build_top_r_B1_results.log

# Print files we built for bookkeeping, exit on error

if [[ $( ls STEP3* 2> /dev/null | wc -l ) -eq '6' ]]; then
    echo "Topology generation was a success... see files:"
    echo ""
    OUT_NAMES=( $( ls | grep STEP3 | grep pdb ) )
    for OUT_NAME in ${OUT_NAMES[@]}; do
        echo $OUT_NAME" "${OUT_NAME/pdb/psf}
    done
    echo ""
else
    echo "Topology generation was failure, exiting..."
    echo ""
    exit
fi

#################################################
# 5. Preequilibrating pdb
#################################################

PREQUIL_DIR=${BASE_DIR}/prequil_NVT_run
IN_PREQUIL_FILE=${PREQUIL_DIR}/in.dat

SIM_FILES_DIR=${BASE_DIR}/resources/sim
PACK_DIR=${BASE_DIR}/resources/pack
MODEL_FILES_DIR=${BASE_DIR}/resources/model

DIS_STR=$( awk '/^OutHistSettings/{print $2}' ${IN_PREQUIL_FILE} )
HIS_STR=$( awk '/^OutHistSettings/{print $3}' ${IN_PREQUIL_FILE} )

echo ${BASE_DIR}/prequil_NVT_run
cd ${PREQUIL_DIR}
echo "A"
#Copy liquid PDB & PSF
cp -f ${PACK_DIR}/STEP3_*res* ${PREQUIL_DIR}/
cp -f ${PACK_DIR}/STEP3_*liq* ${PREQUIL_DIR}/
cp -f ${PACK_DIR}/MC_prog* ${PREQUIL_DIR}/
echo "B"
#Copy parameter file
cp -f ${MODEL_FILES_DIR}/Par_${MODEL_NAME}.inp ${PREQUIL_DIR}/

#Edit input file (run specific)
IN_FILE=${PREQUIL_DIR}/in.dat
sed -i "s#MODEL_NAME#${MODEL_NAME}#g" ${IN_FILE}
sed -i "s#PHA#liq#g" ${IN_FILE}
sed -i "s#PPP#l#g" ${IN_FILE}
sed -i "s#TTT#${T_K[$BRIDGE]}#g" ${IN_FILE}
sed -i "s#R_C#${R_CUT}#g" ${IN_FILE}
sed -i "s#CPCP#${CP[$BRIDGE]}#g" ${IN_FILE}
sed -i "s#CB1ST#${CBMC_1ST[$BRIDGE]}#g" ${IN_FILE}
sed -i "s#CBNTH#${CBMC_NTH[$BRIDGE]}#g" ${IN_FILE}
sed -i "s#BBB#${SIM_BOX_SIZE}#g" ${IN_FILE}
sed -i "s#rAA#r0#g" ${IN_FILE}
sed -i "s#RNN#p#g" ${IN_FILE}

#Edit input files (general)
sed -i "s#RLL#${RUN_LETTER}#g" ${IN_FILE}
sed -i "s#XX#${COMP_NAME_SHORT}#g" ${IN_FILE}

#Edit parameter file
PARAM_FILE=${PREQUIL_DIR}/Par_${MODEL_NAME}.inp
sed -i "s#EEE_EE#${e}#g" ${PARAM_FILE}
sed -i "s#S_SSS#${s}#g" ${PARAM_FILE}
sed -i "s#NN#${n}#g" ${PARAM_FILE}

echo ""
echo "  -----------------------------------"
echo " - MINIMIZING LIQ. EN. W/ NVT RUN -"
echo "================================="
echo ""

./MC_prog* in.dat

rm -f Blk*
rm -f Fluct*
rm -f $( ls | grep ${HIS_STR} )
rm -f $( ls | grep ${DIS_STR} )

EQUIL_LIQ_PDB_NAME=${PREQUIL_DIR}/$( ls | grep 'l_BOX_0_restart.pdb' )
ORIG_LIQ_PDB_NAME=$( ls | grep STEP3 | grep liq | grep pdb )
cp ${PACK_DIR}/${ORIG_LIQ_PDB_NAME} \
    ${PACK_DIR}/${ORIG_LIQ_PDB_NAME/STEP3/prequil}
cp -f ${EQUIL_LIQ_PDB_NAME} ${PACK_DIR}/${ORIG_LIQ_PDB_NAME}

cd ${BASE_DIR}

#################################################
# 5. Make test directories
#################################################

echo ""
echo "  ----------------------"
echo " - BUILDING RUN DIRS -"
echo "===================="
echo ""

for (( r=0; r < $RUNS; r++ )); do

    #Get id string
    rn=$r
    ((rn++))
    RUN_ID=${rn}${RUN_LETTER}
    
    #create the folder
    RUN_DIR_NAME=run${RUN_ID}
    echo "Building ${RUN_DIR_NAME}..."
    mkdir ${BASE_DIR}/${RUN_DIR_NAME}

    CP_DIR=${BASE_DIR}/${RUN_DIR_NAME}

    #Copy simulation files (common)
    cp -f ${SIM_FILES_DIR}/gcmc*cmd ${CP_DIR}/
    cp -f ${SIM_FILES_DIR}/MC_prog* ${CP_DIR}/
    cp -f ${SIM_FILES_DIR}/in.dat ${CP_DIR}/

    #Copy PDB files
    cp -f ${PACK_DIR}/STEP3_*res* ${CP_DIR}/
    if [[ ${STATE[$r]} == 'l' ]]; then
	cp -f ${PACK_DIR}/STEP3_*liq* ${CP_DIR}/
    else
	cp -f ${PACK_DIR}/STEP3_*vap* ${CP_DIR}/
    fi

    #Copy parameter file
    cp -f ${MODEL_FILES_DIR}/Par_${MODEL_NAME}.inp ${CP_DIR}/

    #Edit input file (run specific)
    sed -i "s#MODEL_NAME#${MODEL_NAME}#g" ${CP_DIR}/in.dat
    if [[ ${STATE[$r]} == 'l' ]]; then
	sed -i "s#PHA#liq#g" ${CP_DIR}/in.dat
    else
	sed -i "s#PHA#vap#g" ${CP_DIR}/in.dat
    fi
    sed -i "s#PPP#${STATE[$r]}#g" ${CP_DIR}/in.dat
    sed -i "s#TTT#${T_K[$r]}#g" ${CP_DIR}/in.dat
    sed -i "s#R_C#${R_CUT}#g" ${CP_DIR}/in.dat
    sed -i "s#CPCP#${CP[$r]}#g" ${CP_DIR}/in.dat
    sed -i "s#CB1ST#${CBMC_1ST[$r]}#g" ${CP_DIR}/in.dat
    sed -i "s#CBNTH#${CBMC_NTH[$r]}#g" ${CP_DIR}/in.dat
    sed -i "s#BBB#${SIM_BOX_SIZE}#g" ${CP_DIR}/in.dat
    sed -i "s#rAA#r${RUN_ID}#g" ${CP_DIR}/in.dat
    sed -i "s#RNN#${rn}#g" ${CP_DIR}/in.dat

    #Edit input files (general)
    sed -i "s#RLL#${RUN_LETTER}#g" ${CP_DIR}/in.dat
    sed -i "s#XX#${COMP_NAME_SHORT}#g" ${CP_DIR}/in.dat
done

echo ""

#NOTE: removed setting up the patch directory and run sims!