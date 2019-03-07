#!/bin/bash

BASE_DIR=$( pwd )

if [ "$#" -eq "0" ]; then
    BUILD_FILE="search_range.idat"
    if [ ! -f "${BUILD_FILE}" ]; then
	echo "Error, default build file not found.  Expected name:"
	echo "${BUILD_FILE}"
	exit
    else
	echo "Building using default build file name:"
	echo "${BUILD_FILE}"
    fi
else
    BUILD_FILE=$1
fi

#############################################
# 1. Read in ranges to run.
##############################################

model=( $( cat ${BUILD_FILE}|awk 'NR>1 {print $1}' ) )
nVal=( $( cat ${BUILD_FILE}|awk 'NR>1 {print $2}' ) )
eStart=( $( cat ${BUILD_FILE}|awk 'NR>1 {print $3}' ) )
eLast=( $( cat ${BUILD_FILE}|awk 'NR>1 {print $4}' ) )
eInterval=( $( cat ${BUILD_FILE}|awk 'NR>1 {print $5}' ) )
sStart=( $( cat ${BUILD_FILE}|awk 'NR>1 {print $6}' ) )
sLast=( $( cat ${BUILD_FILE}|awk 'NR>1 {print $7}' ) )
sInterval=( $( cat ${BUILD_FILE}|awk 'NR>1 {print $8}' ) )


#############################################
# 2. Build up set of epsilon and sigma values.
##############################################

for ((i=0; i < ${#nVal[@]}; ++i)); do
    eCountStr='scale=0; (('"${eLast[$i]}"' - '"${eStart[$i]}"' ) / '
    eCountStr="${eCountStr}${eInterval[$i]}"') + 1'
    eCount[$i]=$( echo "${eCountStr}" | bc )
    for ((j=0; j < ${eCount[$i]}; ++j)); do
	eArr="e_${i}[$j]"
	eval $eArr=$( echo "scale=2; ${eStart[i]} + ${eInterval[i]} * $j" | \
	    bc )
    done
    eLastEl="e_${i}[$((${eCount[$i]}-1))]"
    if [ $( echo "scale=2; ${eLastEl} == ${eLast[$i]}" | bc ) -ne "1" ]; then
	eArr="e_${i}[${eCount[$i]}]"
	eval $eArr="${eLast[i]}"
	eCount[$i]=$(( ${eCount[$i]} + 1 ))
    fi
    #eArrAll="e_${i}[@]"
    #echo "${!eArrAll}"

    sCountStr='scale=0; (('"${sLast[$i]}"' - '"${sStart[$i]}"' ) / '
    sCountStr="${sCountStr}${sInterval[$i]}"') + 1'
    sCount[$i]=$( echo "${sCountStr}" | bc )
    for ((j=0; j < ${sCount[$i]}; ++j)); do
	sArr="s_${i}[$j]"
	eval $sArr=$( echo "scale=2; ${sStart[i]} + ${sInterval[i]} *$j" | \
	    bc )
    done
    sLastEl="s_${i}[$((${sCount[$i]}-1))]"
    if [ $( echo "scale=2; ${sLastEl} == ${sLast[$i]}" | bc ) -ne "1" ]; then
	sArr="s_${i}[${sCount[$i]}]"
	eval $sArr="${sLast[i]}"
	sCount[$i]=$(( ${sCount[$i]} + 1 ))
    fi
    #sArrAll="s_${i}[@]"
    #echo "${!sArrAll}"
done

echo ""
echo "---------------------------"
echo ""
echo "BUILDING TEMPLATE DIR..."
echo ""
TEMPLATE_WORK_DIRNAME="nWork"
TEMPLATE_ORIG_DIRNAME="template"
TEMPLATE_WORK_DIR=${BASE_DIR}/${TEMPLATE_WORK_DIRNAME}
TEMPLATE_ORIG_DIR=${BASE_DIR}/${TEMPLATE_ORIG_DIRNAME}
PACK_DIR=${TEMPLATE_WORK_DIR}/resources/pack
MODEL_FILES_DIR=${TEMPLATE_WORK_DIR}/resources/model
if [ ! -d "${TEMPLATE_WORK_DIR}" ]; then
    cp -rf ${TEMPLATE_ORIG_DIR} ${TEMPLATE_WORK_DIR}

    echo ""
    echo "Prepping for prequilibration of liq. phase..."
    echo ""

    PREQUIL_DIR=${TEMPLATE_WORK_DIR}/prequil_NVT_run
    mkdir ${PREQUIL_DIR}
    
    IN_PREQUIL_FILE=${PACK_DIR}/in.dat.preequil
    cp -f $IN_PREQUIL_FILE ${PREQUIL_DIR}/in.dat

    #Modify forcefield to first test value (we don't care which one,
    #this is just a crude liquid phase energy minimization to prevent
    #phase swtiching
    CONFIG_FILE=${TEMPLATE_WORK_DIR}/'build_config.dat'
    MODEL_NAME=$( awk '/^MODEL_NAME/{print $2}' ${CONFIG_FILE} )
    cp -f ${MODEL_FILES_DIR}/Par_${MODEL_NAME}.inp ${PREQUIL_DIR}/
    PREQUIL_FF_FILE=$( ls ${PREQUIL_DIR}/Par_*.inp )
 
    #find median value of each of the params
    if [ "${#nVal[@]}" -gt 1 ]; then
	nPrequil=$( echo ${nVal[@]} | tr ' ' '\n' | sort -n | head -n ${#nVal[@]}| tail -n 1 )
	nPrequilIx=$( echo ${nVal[@]} | tr ' ' '\n' | awk '{print $1" "NR}'|sort -n| \
	    tail -n ${#nVal[@]} | head -n 1 | awk '{print $2}' )    
    else
	nPrequil=${nVal[0]}
	nPrequilIx=0
    fi
    eArrPrequilLen=$(( ${eCount[$nPrequilIx]} / 2 ))
    sArrPrequilLen=$(( ${sCount[$nPrequilIx]} / 2 ))
    eValPrequilStr="e_${nPrequilIx}[$((eArrPrequilLen/2))]"
    sValPrequilStr="s_${nPrequilIx}[$((sArrPrequilLen/2))]"
    eValPrequil=$( echo "${!eValPrequilStr}" )
    sValPrequil=$( echo "${!sValPrequilStr}" )

    #Set preequilibration energy to half its default value.
    eValPrequil=$( echo "scale=2; $eValPrequil / 2.00"|bc )

    BUILD_FL=${TEMPLATE_WORK_DIR}/build.sh
    sed -i "s#xxEEE_EE#${eValPrequil}#g" $BUILD_FL
    sed -i "s#xxS_SSS#${sValPrequil}#g" $BUILD_FL
    sed -i "s#xxNN#$nPrequil#g" $BUILD_FL

    echo ""
    echo "Running script to make template dir..."
    echo ""

    cd ${TEMPLATE_WORK_DIR}
    ./build.sh >& template_run_set.log
    cd ${BASE_DIR}
fi
echo "Finished!"
echo ""
echo "---------------------------"
echo ""

for ((n=0; n < ${#nVal[@]}; ++n)); do
    N_DIR="${BASE_DIR}/n${nVal[n]}"
    if [ ! -d "${N_DIR}" ]; then
	mkdir "${N_DIR}"
    fi
    COMMON_DIRNAME_PART="${N_DIR}/${model[n]}"
    echo ""
    echo "STARTING n = ${nVal[n]} BUILD!"
    echo ""
    echo "---------------------------"
    echo ""
    for ((i=0; i < ${eCount[$n]}; ++i)); do
	for ((j=0; j < ${sCount[$n]}; ++j)); do
	    eArr="e_${n}[$i]"
	    sArr="s_${n}[$j]"
	    eVal=$( echo "${!eArr}")
	    eDirStr=$( echo $eVal | sed 's#\.#_#g' | awk '{print $1"_K"}' )
	    sVal=$( echo "${!sArr}" )
	    sDirStr=$( echo $sVal | sed 's#\.#_#g' | awk '{print $1"_A"}' )

	    RUN_SET_DIR="${COMMON_DIRNAME_PART}_e_${eDirStr}_s_${sDirStr}"
	    if [ ! -d "${RUN_SET_DIR}" ]; then
		mkdir ${RUN_SET_DIR}
	    fi

	    cp -f ${CONFIG_FILE} ${RUN_SET_DIR}
	    cp -f ${TEMPLATE_WORK_DIR}/build.sh ${RUN_SET_DIR}
	    cp -rf ${TEMPLATE_WORK_DIR}/run* ${RUN_SET_DIR}

	    TO_RUN=( $( ls ${RUN_SET_DIR}|grep "run" ) )

	    for run in ${TO_RUN[@]}; do

		RUN_DIR="${RUN_SET_DIR}/${run}"

		#echo ${RUN_DIR}
                #Edit queue file
		QUEUE_FILE=$( ls ${RUN_DIR}/gcmc*cmd )
		sed -i "s#RUN_DIR#${RUN_DIR}#g" ${QUEUE_FILE}

                #Edit parameters
		FF_FILE=$( ls ${RUN_DIR}/Par_*.inp )
		sed -i "s#EEE_EE#${eVal}#g" ${FF_FILE}
		sed -i "s#S_SSS#${sVal}#g" ${FF_FILE}
		sed -i "s#NN#${nVal[n]}#g" ${FF_FILE}

		cd ${RUN_DIR}
		QUEUE_FILE=$( ls gcmc*cmd )
		#qsub ${QUEUE_FILE}
		cd ${BASE_DIR}

	    done

	    echo ""
	    echo "Finished run set: ${RUN_SET_DIR}"
	    echo ""
	    echo "---------------------------"
	    echo ""

	done
    done
done

rm -rf ${TEMPLATE_WORK_DIR}