#!/bin/bash
#SBATCH --time=900:00:00
#SBATCH --ntasks=1   # number of processor cores (i.e. tasks)
#SBATCH --nodes=1   # number of nodes
echo Running on host `hostname`
echo Time is `date`


cd RUN_DIR/
echo Directory is `pwd`


# Run job
./GOMC_CPU_GCMC in.dat >& out_T_`grep Temperature in.dat | awk '{print $2}'`_K_GCMC_u_`grep ChemPot in.dat | awk '{print $3*-1}'`.log
