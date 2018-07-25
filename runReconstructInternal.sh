#!/bin/bash

#-----------------------------------------
# General
#FOAMVersion=AEG. Defined in the main calling program
#thisScript=AEG. Defined in the main calling program

#-----------------------------------------
#Names for the case
#folderType=AEG. Defined in the main calling program
#dimensionType=AEG. Defined in the main calling program
#domainType=AEG. Defined in the main calling program
#arrayType=AEG. Defined in the main calling program
#arrayDensity=AEG. Defined in the main calling program
#Reynolds=AEG. Defined in the main calling program

#-----------------------------------------
#Working Directories
#baseDir=/scratch/pawsey0106/espinosa/OpenFOAM/espinosa-$FOAMVersion/run
baseDir=$MYGROUP/OpenFOAM/espinosa-$FOAMVersion/run
#workingDir=AEG. Defined in the main calling program
#GeneralDir=AEG. Defined in the main calling program
#functionsD=/home/espinosa/bash_functions
functionsD=$HOME/bash_functions

#-----------------------------------------
# Number of last times saved in the purgeWrite (as defined in controlDict)
#Nlast=AEG. Defined in the main calling program
# Number of times to be reconstructed from these available times
#NtimesToReconstruct=AEG. Defined in the main calling program

#-----------------------------------------
#Log files names
cd $baseDir
cd $workingDir
dateString=$(date +%Y-%m-%d.%H.%M.%S)
logRun="${baseDir}/${workingDir}/log_3Reconstruct_${SLURM_JOB_ID}_${dateString}"
logJob="${baseDir}/${workingDir}/log_jobRec_${SLURM_JOB_ID}_${dateString}"
touch $logJob

#-----------------------------------------
#Spitting the slurm setup
echo "SLURM_JOB_ID = $SLURM_JOB_ID" | tee -a ${logJob}
echo "SLURM_JOB_NAME = $SLURM_JOB_NAME" | tee -a ${logJob}
echo "SLURM_NTASKS = $SLURM_NTASKS" | tee -a ${logJob}
echo "SLURM_NTASKS_PER_NODE = $SLURM_NTASKS_PER_NODE" | tee -a ${logJob}

#-----------------------------------------
#Knowing the computer we are using for this script
THISHOST=$(hostname --short)

#-----------------------------------------
# Unloading modules to avoid unexpected crashes
if [ "${THISHOST:0:1}" = "n" ]; then
   module unload PrgEnv-cray
   module unload PrgEnv-gnu
fi

#-----------------------------------------
# Loading desired module
if [ "${THISHOST:0:1}" = "n" ]; then
#   module load PrgEnv-intel
   module load PrgEnv-gnu
fi

#-----------------------------------------
#Look. Already included in $MYGROUP/OpenFOAM/OpenFOAM-$FOAMVersion/etc/bashrc
# Env. Variables needed for compilation
# Activate dynamic linking
if [ "${THISHOST:0:1}" = "n" ]; then
   export CRAYPE_LINK_TYPE=dynamic
# 64-bit build
   export WM_64=ON
fi

#-----------------------------------------
# Source OpenFOAM bashrc
if [ "${THISHOST:0:1}" = "z" ]; then
   module load openfoam
elif [ "${THISHOST:0:1}" = "n" ]; then
   source $MYGROUP/OpenFOAM/OpenFOAM-$FOAMVersion/etc/bashrc
fi

#-----------------------------------------
#Sourcing the floating point function defininitons
#Global variable to be used as scale=$float_scale in bc floatingPoint functions
float_scale=4
archi=$functionsD/floatingPoint
if [ -e $archi ]; then
   echo "Found floatingPoint functions" | tee -a ${logJob}
   source $archi
else
   echo "NOT FOUND floatingPoint functions" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Sourcing the auxiliary function defininitons
archi=$functionsD/auxiliaryFunctions.sh
if [ -e $archi ]; then
   echo "Found auxiliary functions" | tee -a ${logJob}
   source $archi
else
   echo "NOT FOUND auxiliary functions" | tee -a ${logJob}
   exit 4
fi

#-----------------------------------------
#Checking if there is any decomposition
cd $baseDir/$workingDir
if [ -d processor0 ]; then
   echo "Directory processor0 is here. Good! will attempt reconstruction."| tee -a ${logJob}
else
   echo "Processor0 does not exists. Exiting" | tee -a ${logJob}
   exit 1
fi


#-----------------------------------------
#Generating a list of existing time directories
echo "Reading a list of existing time directories" | tee -a ${logJob}
cd $baseDir/$workingDir/processor0
ls -dt [0-9]*/ | sed 's/\///g' > listaDirs.Borra
sort -rn listaDirs.Borra > listaDirsOrdenada.Borra
i=0
while read textTimeDir
do
    timeDirArr[$i]=$textTimeDir
    #echo "The $i timeDir is: ${timeDirArr[$i]}" | tee -a ${logJob}
    ((i++))
done < listaDirsOrdenada.Borra
nTimeDirectories=$i
if [ $nTimeDirectories -eq 0 ]
then
   echo "Exiting because NO time directories available for reconstruct" | tee -a ${logJob}
   exit 3
else
    maxTimeSeen=${timeDirArr[0]}
    echo "The maxTimeSeen is $maxTimeSeen" | tee -a ${logJob}
fi


#-----------------------------------------
#Defining the time indexes from which reconstruct
jEnd=0
#endTime=${timeDirArr[0]}
if [ $nTimeDirectories -ge $Nlast ]; then
    jIni=$(( $Nlast - 1 ))
    #iniTime=${timeDirArr[$jIni]}
    echo "Checking for Reconstructing the last ${Nlast} times" | tee -a ${logJob}
else
    jIni=$(( $nTimeDirectories - 1 ))
    #iniTime=${timeDirArr[$jIni]}
    echo "Checking for Reconstructing just ${nTimeDirectories} times" | tee -a ${logJob}
fi
cd $baseDir/$workingDir

#-----------------------------------------
#Defining the increment jump for the index used to choose the time to reconstruct
nReconstructable=$(( $jIni + 1 ))
if [ $NtimesToReconstruct -gt 0 ]; then
   echo "Reconstructing ${NtimesToReconstruct} of ${nReconstructable} times" | tee -a ${logJob}  
   deltaJ=$(float_eval "${nReconstructable} / ${NtimesToReconstruct}")
   deltaJ=$(float_round2int "${deltaJ}")
   echo "So it will be done every deltaJ=${deltaJ} saved times" | tee -a ${logJob}
else
   deltaJ=1
   echo "nReconstructable was not set"
   echo "So it will be done every deltaJ=${deltaJ} saved times" | tee -a ${logJob}
fi
cd $baseDir/$workingDir


#-----------------------------------------
#Reconstructing the desired directories
echo "Reconstructing all times without the .done file" | tee -a ${logJob}
cd $baseDir/$workingDir
for ((j=$jEnd; j<=$jIni; j+=$deltaJ))
do
    jTime=${timeDirArr[$j]}
    if [ -f "./${jTime}/.done" ]; then
      echo "NOT Reconstructing ${jTime} as it was done already" | tee -a ${logJob}
    else
      echo "YES Reconstructing ${jTime}" | tee -a ${logJob}
      date | tee -a ${logJob}
      if [ "${THISHOST:0:1}" = "z" ]; then
         reconstructPar -time "${jTime}" > "logR${jTime}" 2>&1
      elif [ "${THISHOST:0:1}" = "n" ]; then
         srun -n 1 reconstructPar -time "${jTime}" > "logR${jTime}" 2>&1
      fi
      touch "./${jTime}/.done"
      date | tee -a ${logJob}
    fi
done
#Trying the jIni again, just in case it was skipped because of deltaJ in the for cycle above
jTime=$jIni
if [ -f "./${jTime}/.done" ]; then
   echo "NOT Reconstructing ${jTime} as it was done already" | tee -a ${logJob}
else
   echo "YES Reconstructing ${jTime}" | tee -a ${logJob}
   date | tee -a ${logJob}
   if [ "${THISHOST:0:1}" = "z" ]; then
      reconstructPar -time "${jTime}" > "logR${jTime}" 2>&1
   elif [ "${THISHOST:0:1}" = "n" ]; then
      srun -n 1 reconstructPar -time "${jTime}" > "logR${jTime}" 2>&1
   fi
   touch "./${jTime}/.done"
   date | tee -a ${logJob}
fi

#-----------------------------------------
#End
echo "Reconstruction finished" | tee -a ${logJob}
echo "Last reconstruction was ${jTime}" | tee -a ${logJob}

#-----------------------------------------
#Add a mark for last changes: (for rsync to pick it up with --only-size)
#2018.07.26


