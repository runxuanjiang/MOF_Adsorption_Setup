#!/bin/bash

ATOM_NAME=( $( awk '/^MASS/{print $3}' Topology_masses.dat) )
echo "$ATOM_NAME"
ATOM_TOTAL=$( echo ${#ATOM_NAME[@]} )
echo "total runs=$ATOM_TOTAL"
RUN_ID=1
until [ ${RUN_ID} -gt ${ATOM_TOTAL} ]; do
	echo " "
	echo "RESI ${ATOM_NAME[$RUN_ID - 1]} 		0.00 !"
	echo "GROUP"
	echo "ATOM ${ATOM_NAME[$RUN_ID - 1]} ${ATOM_NAME[$RUN_ID - 1]}		0.00 !"
	echo "PATCHING FIRS NONE LAST NONE"
	echo " "
	RUN_ID=$((RUN_ID+1))

done
exit

