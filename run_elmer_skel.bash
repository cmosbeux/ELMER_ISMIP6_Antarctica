#!/bin/bash
ulimit -s unlimited

HELMER=<HELMER>

# INPUTS
# segment number
i=<ID>
# restart name
RSTFILEnc=<RSTFILEnc>
# conf case
CONFIG=<ECONFIG>
CASE=<ECASE>

# LOG links
ln -sf LOG/${CONFIG}-${CASE}_${i}.e$SLURM_JOBID elmer.err
ln -sf LOG/${CONFIG}-${CASE}_${i}.o$SLURM_JOBID elmer.out

# load arch parameter
. ./param_arch.bash

# load modules
load_elmer_modules

# print status file
mv ${HELMER}/zELMER_${i}_READY ${HELMER}/zELMER_${i}_IN_PROGRESS

# 
echo ''
echo "run Elmer/Ice in $WELMER"
echo ''
cd $WELMER

# manage sif info
echo "sif use is : elmer_t${i}.sif"
if [ ! -f elmer_t${i}.sif ] ; then echo "E R R O R: sif file missing"; exit 42; fi
echo elmer_t${i}.sif > ELMERSOLVER_STARTINFO

# manage restart
if [[ $i -gt 1 ]] ; then
   echo '$WELMER/${RSTFILEnc} is missing, we pick it up from $RELMER'
   ln -sf $RELMER/${RSTFILEnc} $WELMER/MSH/restart_$((i-1)).nc || nerr=$((nerr+1))

   if [[ $nerr -ne 0 ]] ; then
   echo 'ERROR during copying restart file; please check'
   mv ${HELMER}/zELMER_${i}_IN_PROGRESS ${HELMER}/zELMER_${i}_ERROR_rst
   exit 42
   fi
fi

# run elmer (see function in param_hpc.bash)
run_elmer ; RUNSTATUS=$?

# post processing
if [[ $RUNSTATUS == 0 ]]; then
   
   # error count
   nerr=0
   ls
   # cp restart to RST dir
   echo "cp restart to $RELMER"
   RSTTIMEFILES=`echo "restart_time_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   RSTFILES=`echo "restart_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   ncks -A -v elmer_time $RSTTIMEFILES $RSTFILES             || nerr=$((nerr+1))
   mv -f $RSTFILES $RELMER/$CONFIG-${CASE}_${i}.restart.nc   || nerr=$((nerr+1))

   # mv data to S dir
   echo ''
   echo "mv dat to $SELMER"
   DATFILES=`echo "scalars_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   mv scalars_$CONFIG-${CASE}_${i}.dat*                $SELMER/. || nerr=$((nerr+1))
   NCFILES=`echo "*_$CONFIG-${CASE}_${i}.nc" | tr [:upper:] [:lower:]`
   mv $NCFILES                                         $SELMER/.   || nerr=$((nerr+1))

   if [[ $nerr -ne 0 ]] ; then
      echo 'ERROR during copying output file/restarts; please check'
      mv ${HELMER}/zELMER_${i}_IN_PROGRESS ${HELMER}/zELMER_${i}_ERROR_pp
      exit 42
   fi

else

   echo 'ELMER failed, exit 42'
   mv ${HELMER}/zELMER_${i}_IN_PROGRESS ${HELMER}/zELMER_${i}_ERROR
   exit 42

fi

# manage indicator file
mv ${HELMER}/zELMER_${i}_IN_PROGRESS ${HELMER}/zELMER_${i}_SUCCESSFUL
touch ${HELMER}/zELMER_$((i+1))_READY
