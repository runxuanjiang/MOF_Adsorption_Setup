#!/bin/bash

BASE_DIR=$( pwd )
CONFIG_FILE='Variables.dat'

###############
#Set Variables#
###############

MOF_ID=$( awk '/^MOF_ID/{print $2}' ${CONFIG_FILE} )
MOF_NAME=$( awk '/^MOF_NAME/{print $2}' ${CONFIG_FILE} )
ADSORBATE_NAME=$( awk '/^ADSORBATE_NAME/{print $2}' ${CONFIG_FILE} )
ADSORBATE_RESNAME=$( awk '/^ADSORBATE_RESNAME/{print $2}' ${CONFIG_FILE} )
ELECTROSTATIC=$( awk '/^ELECTROSTATIC/{print $2}' ${CONFIG_FILE} )
RESERVOIR_DIM=$( awk '/^RESERVOIR_DIM/{print $2}' ${CONFIG_FILE} )
RESERVOIR_NUMBER=$( awk '/^RESERVOIR_NUMBER/{print $2}' ${CONFIG_FILE} )
RCUT=$( awk '/^RCUT/{print $2}' ${CONFIG_FILE} )
RUNSTEPS=$( awk '/^RUNSTEPS/{print $2}' ${CONFIG_FILE} )
SUPERCELL_DIM=$( awk '/^SUPERCELL_DIM/{print $2}' ${CONFIG_FILE} )

if [ $ELECTROSTATIC = "TRUE" ]; then
	MOF_FILE="${MOF_ID}_clean_min_charges.cif"
elif [ $ELECTROSTATIC = "FALSE" ]; then 
	MOF_FILE="${MOF_ID}_clean_min.cif"
else
	echo "ELECTROSTATIC INPUT INVALID"
	echo "EXITING..."
	exit 1
fi

if [ $ELECTROSTATIC = "TRUE" ]; then
	MOF_PWD="~/Desktop/CoRE-MOF-1.0-DFT-Minimized/minimized_structures_with_DDEC_charges/${MOF_FILE}"
elif [ $ELECTROSTATIC = "FALSE" ]; then 
	MOF_PWD="~/Desktop/CoRE-MOF-1.0-DFT-Minimized/minimized_structures/${MOF_FILE}"
fi


ADSORBATE_FILE="${ADSORBATE_NAME}.pdb"

############################
#Create Build Directories
############################
echo "setting up build directories"
mkdir build
cd build
mkdir MOF_base
mkdir reservoir_base
cd MOF_base
##############################
#copy MOF cif file into MOF_base directory
##############################
if [ $ELECTROSTATIC = "TRUE" ]; then
	cp ~/Desktop/CoRE-MOF-*/minimized_structures_*/${MOF_FILE} .
elif [ $ELECTROSTATIC = "FALSE" ]; then 
	cp ~/Desktop/CoRE-MOF-*/minimized_structures/${MOF_FILE} .
fi

if [ -f $MOF_FILE ]; then
	echo "MOF_FILE succesfully copied into MOF_base directory"
else
	echo "ERROR: MOF_FILE NOT FOUND"
	exit 2
fi
################################
#Generate Cell Basis Vectors
################################
CELL_LENGTH_A=$( awk '/^_cell_length_a/{print $2}' ${MOF_FILE} )
CELL_LENGTH_B=$( awk '/^_cell_length_b/{print $2}' ${MOF_FILE} )
CELL_LENGTH_C=$( awk '/^_cell_length_c/{print $2}' ${MOF_FILE} )
CELL_ANGLE_ALPHA=$( awk '/^_cell_angle_alpha/{print $2}' ${MOF_FILE} )
CELL_ANGLE_BETA=$( awk '/^_cell_angle_beta/{print $2}' ${MOF_FILE} )
CELL_ANGLE_GAMMA=$( awk '/^_cell_angle_gamma/{print $2}' ${MOF_FILE} )
PI=$( echo "4*a(1)" | bc -l )
ALPHA=$( echo "$CELL_ANGLE_ALPHA*($PI/180)" | bc -l )
BETA=$( echo "$CELL_ANGLE_BETA*($PI/180)" | bc -l )
GAMMA=$( echo "$CELL_ANGLE_GAMMA*($PI/180)" | bc -l )
AX=$CELL_LENGTH_A
AY='0'
AZ='0'
BX=$( echo "$CELL_LENGTH_B*c($GAMMA)" | bc -l )
BY=$( echo "$CELL_LENGTH_B*s($GAMMA)" | bc -l )
BZ='0'
CX=$( echo "$CELL_LENGTH_C*c($BETA)" | bc -l )
CY=$( echo "$CELL_LENGTH_C*c($ALPHA)*s($GAMMA)" | bc -l )
CZ=$( echo "$CELL_LENGTH_C*s($BETA)" | bc -l )

BOX_0_VECTOR1="$AX $AY $AZ"
BOX_0_VECTOR2="$BX $BY $BZ"
BOX_0_VECTOR3="$CX $CY $CZ"

echo " "
echo " - READING SETUP PARAMETERS - "
echo "=========================================="
echo ""
echo "MOF_NAME: " ${MOF_NAME}
echo "ADSORBATE_NAME: " ${ADSORBATE_NAME}
echo "ELECTROSTATIC: " ${ELECTROSTATIC}
echo "RESERVOIR_DIM: " ${RESERVOIR_DIM}
echo "RESERVOIR_NUMBER: " ${RESERVOIR_NUMBER}
echo "RCUT: " ${RCUT}
echo "RUNSTEPS: " ${RUNSTEPS}
echo "SUPERCELL_EXPANSION_FACTOR: " ${SUPERCELL_DIM}
echo " "
echo "Cell Basis Vectors:"
echo $BOX_0_VECTOR1
echo $BOX_0_VECTOR2
echo $BOX_0_VECTOR3




####################
#Create MOF Base
####################
echo "creating MOF base"

cp ../../Setup_scripts/extend_unit_cell.py .
cp ../../Setup_scripts/convert_Pymatgen_PDB.tcl .
cp ../../Setup_scripts/build_psf_box_0.tcl .
cp ../../Setup_scripts/setBeta.tcl .
sed -i "s/FILEFILE/${MOF_FILE}/g" extend_unit_cell.py
sed -i "s/MMMMMM/${MOF_ID}/g" extend_unit_cell.py
sed -i "s/CCC/${SUPERCELL_DIM}/g" extend_unit_cell.py
sed -i "s/MMMMMM/${MOF_ID}/g" *.tcl
sed -i "s/NNNNNN/${MOF_NAME}/g" *.tcl

echo "building PDB and PSF files for MOF: Start"
python extend_unit_cell.py
if [ -f *_clean_min.pdb ]; then
	echo "unit cell extended, proceeding to next step"
else
	echo "ERROR: error generating supercell, check extend_unit_cell.py file and check if Pymatgen and Openbabel are installed correctly"
	exit 3
fi
echo +++++++++++++++++++++++++++++++++++++++
echo +++++++++++++++++++++++++++++++++++++++
echo "topology file needed, please paste topology file into MOF_base directory"
read -p "Press enter to continue"

vmd < convert_Pymatgen_PDB.tcl
if [ -f *_modified.pdb ]; then
	echo "pdb file modification complete, proceeding to next step"
else
	echo "ERROR: error in generating pdb file after running Pymatgen"
	exit 4
fi
vmd < build_psf_box_0.tcl
vmd < setBeta.tcl
if [ -f *.psf ]; then
	echo "psf and pdb files generated; proceeding to next step"
else
	echo "ERROR: error in generating psf file, exiting..."
	exit 5
fi
echo ================================================
echo "MOF pdb and psf input files succesfully built"
echo "now proceeding to generate reservoir files"
echo ================================================

#########################
#Create Reservoir Base
#########################
cd ../reservoir_base
cp "../../Adsorbate_PDBs/${ADSORBATE_FILE}" .
if [ -f $ADSORBATE_FILE ]; then
	echo "Adsorbate file succesfully copied into reservoir_base, psf and pdb build beginning"
else
	echo "Adsorbate file not found, exiting..."
	exit 6
fi
cp ../../Setup_scripts/packmol .
cp ../../Setup_scripts/pack_box_1.inp .
cp ../../Setup_scripts/build_psf_box_1.tcl .

sed -i "s/AAAAAA/${ADSORBATE_NAME}/g" pack_box_1.inp
sed -i "s/DDD0/${RESERVOIR_DIM}/g" pack_box_1.inp
sed -i "s/NUM#/${RESERVOIR_NUMBER}/g" pack_box_1.inp
sed -i "s/RRRR/${ADSORBATE_RESNAME}/g" build_psf_box_1.tcl
sed -i "s/AAAAAA/${ADSORBATE_NAME}/g" build_psf_box_1.tcl

echo "topology file needed, please paste topology file into reservoir_base directory"
read -p "Press enter to continue"

echo "packing reservoir box..."
./packmol < pack_box_1.inp
if [ -f packed_* ]; then
	echo "Reservoir packed succesfully, proceeding..."
else
	echo "Packmol unsuccesful, exiting..."
	exit 7
fi
vmd < build_psf_box_1.tcl
if [ -f *.psf ]; then
	echo "Reservoir psf and pdb files generated succesfully"
	echo ===================================================
else 
	echo "psf generation unsuccesful, exiting..."
	exit 8
fi

###########################
#Set Up In.conf File (Control File) - original
###########################
echo ==================================
echo "configuring control file..."
echo ==================================
cd ../
cp ../Setup_scripts/in.conf .
sed -i "s/AAAAAA/${ADSORBATE_NAME}/g" in.conf
sed -i "s/NNNNNN/${MOF_NAME}/g" in.conf
sed -i "s/RCRC/${RCUT}/g" in.conf
sed -i "s/EEEE/${ELECTROSTATIC}/g" in.conf
sed -i "s/SSSSSSSS/${RUNSTEPS}/g" in.conf
sed -i "s/DDD0/${RESERVOIR_DIM}/g" in.conf
sed -i "s/DDD1/${BOX_0_VECTOR1}/g" in.conf
sed -i "s/DDD2/${BOX_0_VECTOR2}/g" in.conf
sed -i "s/DDD3/${BOX_0_VECTOR3}/g" in.conf
sed -i "s/RRRR/${ADSORBATE_RESNAME}/g" in.conf
echo "control file has been properly configured, now beginning runs setup"
read -p "Press enter to continue"

#################################
#Read Data from Runs data file
#################################
cd ../
mkdir Run_files
cd Run_files
RUN_TOTAL=$( awk '/^RUN_TOTAL/{print $2}' ../${CONFIG_FILE} )
echo "total number of runs: $RUN_NUMBER"
RUN_NUMBER=( $( awk '/^R /{print $2}' ../${CONFIG_FILE} ) )
RUN_TEMP=( $( awk '/^R /{print $3}' ../${CONFIG_FILE} ) )
RUN_FUGACITY=( $( awk '/^R /{print $4}' ../${CONFIG_FILE} ) )
RUN_ID=1
until [ ${RUN_ID} -gt ${RUN_TOTAL} ]; do
	echo "setting up run files for run number $RUN_ID"
	TEMPERATURE=${RUN_TEMP[$RUN_ID - 1]}
	FUGACITY=${RUN_FUGACITY[$RUN_ID - 1]}
	echo "The temperature for run number $RUN_ID is $TEMPERATURE"
	echo "The fugacity for run number $RUN_ID is $FUGACITY"
	mkdir "Run_${RUN_ID}"
	cd "Run_${RUN_ID}"
	cp ../../build/in.conf .
	sed -i "s/TTT/${TEMPERATURE}/g" in.conf
	sed -i "s/FFF/${FUGACITY}/g" in.conf
	cp ~/Desktop/GOMC-master/bin/GOMC_GPU_GCMC .
	echo "run $RUN_ID has been set up, proceeding to next run"
	cd ../
	RUN_ID=$((RUN_ID+1))
done

echo "run directories have been built"

exit









