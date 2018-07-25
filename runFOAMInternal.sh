#!/bin/bash
#AEG: This is the internal part of the runFOAM script for general runs
#Good luck!

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# General
#FOAMVersion=AEG. Defined in the main calling program
#thisScript=AEG. Defined in the main calling program

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Names for the case
#folderType=AEG. Defined in the main calling program
#dimensionType=AEG. Defined in the main calling program
#domainType=AEG. Defined in the main calling program
#arrayType=AEG. Defined in the main calling program
#arrayDensity=AEG. Defined in the main calling program
#Reynolds=AEG. Defined in the main calling program

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Times
#timeInitial=AEG. Defined in the main calling program
#timeFinal=AEG. Defined in the main calling program
#timeTolerance=AEG. Defined in the main calling program
#timeAverageInitial=AEG. Defined in the main calling program

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Output intervals
#OUTPUT_INTERVAL_U=AEG. Defined in the main calling program
#OUTPUT_INTERVAL_P=AEG. Defined in the main calling program
#OUTPUT_INTERVAL_FORCES=AEG. Defined in the main calling program
#OUTPUT_INTERVAL_pU=AEG. Defined in the main calling program
if [ -z "$OUTPUT_INTERVAL_pU" ]; then
   OUTPUT_INTERVAL_pU=${OUTPUT_INTERVAL_U}
fi


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Working Directories
#baseDir=/scratch/pawsey0106/espinosa/OpenFOAM/espinosa-$FOAMVersion/run
baseDir=$MYSCRATCH/OpenFOAM/espinosa-$FOAMVersion/run
#previousDir=
#workingDir=AEG. Defined in the main calling program
#nextDir=
#functionsD=/home/espinosa/bash_functions
functionsD=$HOME/bash_functions
#GeneralDir=AEG. Defined in the main calling program

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Log files names
cd $baseDir
cd $workingDir
dateString=$(date +%Y-%m-%d.%H.%M.%S)
logRun="${baseDir}/${workingDir}/log_run_${SLURM_JOB_ID}_${dateString}"
logJob="${baseDir}/${workingDir}/log_job_${SLURM_JOB_ID}_${dateString}"
touch $logJob

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Spitting the slurm setup
echo "SLURM_JOB_ID = $SLURM_JOB_ID" | tee -a ${logJob}
echo "SLURM_JOB_NAME = $SLURM_JOB_NAME" | tee -a ${logJob}
echo "SLURM_NTASKS = $SLURM_NTASKS" | tee -a ${logJob}
echo "SLURM_NTASKS_PER_NODE = $SLURM_NTASKS_PER_NODE" | tee -a ${logJob}

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# Unloading modules to avoid unexpected crashes
module unload PrgEnv-cray
module unload PrgEnv-gnu

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# Loading desired module
#module load PrgEnv-intel
module load PrgEnv-gnu

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Look. Already included in $MYGROUP/OpenFOAM/OpenFOAM-$FOAMVersion/etc/bashrc
# Env. Variables needed for compilation
# Activate dynamic linking
export CRAYPE_LINK_TYPE=dynamic
# 64-bit build
export WM_64=ON

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# Source OpenFOAM bashrc
source $MYGROUP/OpenFOAM/OpenFOAM-$FOAMVersion/etc/bashrc

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Sourcing the floating point function defininitons
#Global variable to be used as scale=$float_scale in bc floatingPoint functions
float_scale=4
archi=$functionsD/floatingPoint
if [ -e $archi ]; then
   echo "Found floatingPoint functions" | tee -a ${logJob}
   source $archi
else
   echo "NOT FOUND floatingPoint functions" | tee -a ${logJob}
   exit 4
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

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# Identifying if is there another job with the same name already running
nTocallos=$(squeue --name="$SLURM_JOB_NAME" --state=RUNNING | wc -l)
nTocallos=$(float_eval "$nTocallos")
nTocallos=$(float_eval "$nTocallos - 2")

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Checking if there are other pending jobs with the same name
nPendientes=$(squeue --name="$SLURM_JOB_NAME" --state=PENDING | wc -l)
nPendientes=$(float_eval "$nPendientes")
nPendientes=$(float_eval "$nPendientes - 1")

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Logic for cancelling existing running and pending jobs and resubmitting

if [ $nTocallos -ge 2 ] || [ $nPendientes -ge 2 ]; then
    echo "TWO OR MORE jobs with the same name are already running. Tocallos=${nTocallos}" | tee -a ${logJob}
    echo "or TWO OR MORE jobs with the same name are already pending. Pending=${nPendientes}" | tee -a ${logJob}
    echo "All the existing jobs (all running and all pending) with the same name will be cancelled" | tee -a ${logJob}
    scancel --name="$SLURM_JOB_NAME"
    echo "All Tocallo-Jobs (running and pending) have been cancelled" | tee -a ${logJob}
    echo "Now, This job will be proceed to submit a case for running" | tee -a ${logJob}
elif [ $nTocallos -eq 1 ] && [ $nPendientes -le 1 ]; then
    echo "ONE job with the same name is already running. Tocallos=${nTocallos}" | tee -a ${logJob}
    echo "And one or none jobs with the same name are already pending. Pending=${nPendientes}" | tee -a ${logJob}
    echo "Everything looks fine in the queue for that running job and dependants." | tee -a ${logJob}
    echo "So That job will be left running" | tee -a ${logJob}
    echo "And This job request will be cancelled" | tee -a ${logJob}
    echo "Exiting this job request .." | tee -a ${logJob}
    exit 1
elif [ $nTocallos -eq 0 ] && [ $nPendientes -eq 1 ]; then
    echo "There was a single orphan pending job. Tocallos=${nTocallos}, Pending=${nPendientes}" | tee -a ${logJob}
    echo "I will leave it in the queue And This job request will be cancelled" | tee -a ${logJob}
    echo "Exiting this job request .." | tee -a ${logJob}
    exit 1
else
    echo "No Tocallo-Jobs already running exist. Good! Tocallos=${nTocallos}, Pending=${nPendientes}" | tee -a ${logJob}
    echo "Now, This job will be proceed to submit a case for running" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Change directory
cd $baseDir/$workingDir
#### I used to mv log files like this, but now Im naming them from the beginning
##mv log_run log_run_${SLURM_JOB_ID}
##mv log_job log_job_${SLURM_JOB_ID}

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Avoiding falling into an infinite loop of recurrent errors which generate huge amount of files
#maxSlurmies= AEG.Defined in the main calling program
slurmies=$(find . -maxdepth 1 -name "slurm*" | wc -l)
if [ $slurmies -gt $maxSlurmies ]; then
   echo "Exiting because the maximum slurmies have been reached: $slurmies" | tee -a ${logJob}
   exit 2
fi


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Decomposing the case if there is no decomposition
cd $baseDir/$workingDir
if [ -d processor0 ]; then
   echo "Directory processor0 is here. Good! Not attempting for decomposition."| tee -a ${logJob}
else
   echo "Processor0 does not exists. Attempting decomposition" | tee -a ${logJob}
   copyFile $GeneralDir/system.FlowFields/controlDict.Default ./system/controlDict
   copyFile $GeneralDir/system.FlowFields/decomposeParDict.$domainType ./system/decomposeParDict
   if [ "$arrayType" = "SingleGrid15BLD100Alexis" ]; then
      copyFile $GeneralDir/system.FlowFields/decomposeParDict.2DChannel ./system/decomposeParDict
   fi
   sed -i "s/NSUBDOMAINS/${SLURM_NTASKS}/g" ./system/decomposeParDict
   srun -n 1 decomposePar -latestTime > logDecompose 2>&1
fi


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
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
   echo "Exiting because NO time directories available for restart" | tee -a ${logJob}
   exit 3
else
    maxTimeSeen=${timeDirArr[0]}
    echo "The maxTimeSeen is $maxTimeSeen" | tee -a ${logJob}
fi


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Defining the time from which to restart
if [ $nTimeDirectories -eq 1 ]; then
    restartTime=${timeDirArr[0]}
    echo "Using the only existing time: $restartTime for restart: modifying controlDict" | tee -a ${logJob}
else
    echo "The last timeDir is: ${timeDirArr[0]}" | tee -a ${logJob}
    echo "The secondLast timeDir is: ${timeDirArr[1]}" | tee -a ${logJob}
    restartTime=${timeDirArr[1]}
    echo "Using the secondLast time: $restartTime for restart: modifying controlDict" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Reconstructing the restartTime to keep some reconstructed History
echo "Reconstructing the restartTime if it does not have the .done file" | tee -a ${logJob}
cd $baseDir/$workingDir
if float_cond "$restartTime > 0"; then
    jTime=$restartTime
    if [ -f "./${jTime}/.done" ]; then
      echo "NOT Reconstructing ${jTime} as it was done already" | tee -a ${logJob}
    else
      echo "YES Reconstructing ${jTime}" | tee -a ${logJob}
      date | tee -a ${logJob}
      srun -n 1 reconstructPar -time "${jTime}" > "logR${jTime}" 2>&1
      touch "./${jTime}/.done"
      date | tee -a ${logJob}
    fi
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Defining the finishTime together with the controlDict setup
cd $baseDir/$workingDir
#Copying the file that define force calculations:-------------------------
echo "Copying file: " | tee -a ${logJob}
echo "$GeneralDir/system.ForcesSampling/forcesCylinder_${domainType}_${arrayType}.txt" | tee -a ${logJob}
rm ./system/forcesCylinder.txt
copyFile $GeneralDir/system.ForcesSampling/forcesCylinder_${domainType}_${arrayType}.txt ./system/forcesCylinder.txt
sed -i "s/OUTPUT_INTERVAL_FORCES/${OUTPUT_INTERVAL_FORCES}/" ./system/forcesCylinder.txt
#Deciding if sampling is to be done or not:---------------------------------
echo "Restart time is ${restartTime} and timeAverageInitial is ${timeAverageInitial}" | tee -a ${logJob}
if float_cond "$restartTime >= $timeAverageInitial"; then
   finishTime=$timeFinal
   echo "Therefore finish time will be $finishTime" | tee -a ${logJob}
   echo "And sampling and averaging will be performed" | tee -a ${logJob}
   #Copying the different files that define sampling:-------------------------
   #samplingRings:::
   echo "Copying file: " | tee -a ${logJob}
   echo "${GeneralDir}/system.ForcesSampling/samplingRings_${domainType}_${arrayType}_SF${arrayDensity}.txt"  | tee -a ${logJob}
   rm ./system/samplingRings.txt
   copyFile $GeneralDir/system.ForcesSampling/samplingRings_${domainType}_${arrayType}_SF${arrayDensity}.txt ./system/samplingRings.txt
   sed -i "s/OUTPUT_INTERVAL_U/${OUTPUT_INTERVAL_U}/" ./system/samplingRings.txt
   sed -i "s/OUTPUT_INTERVAL_P/${OUTPUT_INTERVAL_P}/" ./system/samplingRings.txt
   #additionalRings:::
   echo "Copying file: " | tee -a ${logJob}
   echo "${GeneralDir}/system.ForcesSampling/additionalRings_${domainType}_${arrayType}_SF${arrayDensity}.txt"  | tee -a ${logJob}
   rm ./system/additionalRings.txt
   copyFile $GeneralDir/system.ForcesSampling/additionalRings_${domainType}_${arrayType}_SF${arrayDensity}.txt ./system/additionalRings.txt
   sed -i "s/OUTPUT_INTERVAL_U/${OUTPUT_INTERVAL_U}/" ./system/additionalRings.txt
   sed -i "s/OUTPUT_INTERVAL_P/${OUTPUT_INTERVAL_P}/" ./system/additionalRings.txt
   #samplingLines:::
   echo "Copying file: " | tee -a ${logJob}
   echo "${GeneralDir}/system.ForcesSampling/samplingLines_${domainType}_${arrayType}_SF${arrayDensity}.txt"  | tee -a ${logJob}
   rm ./system/samplingLines.txt
   copyFile $GeneralDir/system.ForcesSampling/samplingLines_${domainType}_${arrayType}_SF${arrayDensity}.txt ./system/samplingLines.txt
   sed -i "s/OUTPUT_INTERVAL_pU/${OUTPUT_INTERVAL_pU}/" ./system/samplingLines.txt
   #Checking for the postprocessing dir:------------------------------
   if ! [ -d postProcessing ]; then
      echo "Creating the postProcessing dir for the first time" | tee -a ${logJob}
      mkdir postProcessing
   fi
   #Copying the lists of Rps and generalGeometry:------------------------------
   if ! [ -f ./postProcessing/samplingRp.txt ]; then
      echo "Copying file: " | tee -a ${logJob}
      echo "$GeneralDir/system.ForcesSampling/samplingRp_${arrayType}.txt" | tee -a ${logJob}
      copyFile $GeneralDir/system.ForcesSampling/samplingRp_${arrayType}.txt ./postProcessing/samplingRp.txt
   fi
   if ! [ -f ./postProcessing/additionalRp.txt ]; then
      echo "Copying file: " | tee -a ${logJob}
      echo "$GeneralDir/system.ForcesSampling/additionalRp_${arrayType}.txt" | tee -a ${logJob}
      copyFile $GeneralDir/system.ForcesSampling/additionalRp_${arrayType}.txt ./postProcessing/additionalRp.txt
   fi
   if ! [ -f ./postProcessing/generalGeometry.txt ]; then
      echo "Copying file: " | tee -a ${logJob}
      echo "$GeneralDir/system.ForcesSampling/generalGeometry_${arrayType}.txt" | tee -a ${logJob}
      copyFile $GeneralDir/system.ForcesSampling/generalGeometry_${arrayType}.txt ./postProcessing/generalGeometry.txt
      if [ "$domainType" = "2DChannel" ]; then
         lineAdded=DomainType,Channel
         echo "Adding the line ${lineAdded} to ./postProcessing/generalGeometry.txt" | tee -a ${logJob}
         echo $lineAdded | tee -a ./postProcessing/generalGeometry.txt
      fi
   fi
   #Defining the averaging:------------------------------
   averageEnabled=true
else
   #If it is not time for sampling, put null files:------------------------------
   finishTime=$(float_eval "$timeAverageInitial + 1")
   echo "Therefore finish time will be $finishTime" | tee -a ${logJob}
   echo "And No sampling No averaging will be performed" | tee -a ${logJob}
   rm ./system/samplingRings.txt
   touch ./system/samplingRings.txt
   rm ./system/additionalRings.txt
   touch ./system/additionalRings.txt
   rm ./system/samplingLines.txt
   touch ./system/samplingLines.txt
   #Defining the averaging:------------------------------
   averageEnabled=false
fi

#Adapting controlDict:-------------------------------------------------
echo "Copying file: " | tee -a ${logJob}
echo "${GeneralDir}/system.FlowFields/controlDict.Macho$domainType"  | tee -a ${logJob}
copyFile $GeneralDir/system.FlowFields/controlDict.Macho$domainType ./system/controlDict
sed -i "s/ALE_AVERAGE_ENABLED/${averageEnabled}/" ./system/controlDict
echo "Modifying control dict with the desired restart and final times" | tee -a ${logJob}
echo "restartTime=${restartTime}, finalTime=${finishTime}" | tee -a ${logJob}
sed -i "s/ALE_STARTTIME/$restartTime/" ./system/controlDict
sed -i "s/ALE_FINALTIME/$finishTime/" ./system/controlDict


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Deciding if sending a following job with dependency
#useDependantCycle=AEG. Defined in the main calling program
#dependantScript=AEG. Defined in the main calling program
if [ -f "zzz_justOneMore" ]; then
    echo "The zzz_justOneMore file has been identified. Turning useDependatCyle=false now." | tee -a ${logJob}
    useDependantCycle=false
fi

if float_cond "$restartTime < $timeInitial"; then
   echo "The time found for restarting the case is lower than the timeInitial set in this script" | tee -a ${logJob}
   echo "restartTime= ${restartTime}, timeInitial=${timeInitial}" | tee -a ${logJob}
   echo "Letting the script to continue anyway" | tee -a ${logJob}
fi

echo "To be restarted from time $restartTime" | tee -a ${logJob}
if [ "$useDependantCycle" = "true" ]; then
   if float_cond "$maxTimeSeen >= $timeFinal - $timeTolerance"; then
      echo "The last time has been seen: $maxTimeSeen" | tee -a ${logJob}
      echo "Creating the flag file: zzz_justOneMore," | tee -a ${logJob}
      echo "which will stop the dependant cycle the next time" | tee -a ${logJob}
      touch zzz_justOneMore
   fi
   echo "Sending also the dependant job: ${dependantScript}" | tee -a ${logJob}
#OJO, still not working   sbatch --dependency=afterany:${SLURM_JOB_ID} ${thisScript}
   sbatch --dependency=afterany:${SLURM_JOB_ID} $dependantScript
else
   echo "useDependantCycle=false, therefore NOT SENDING the dependant script" | tee -a ${logJob}
fi


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# Running openFOAM
if [ "$SLURM_NTASKS" -gt 1 ]; then
   echo "Running pimpleFoam in parallel" | tee -a ${logJob}
   #srun -n $SLURM_NTASKS ale_pimpleKinematicParcelFoamReboundingSF8.0_14Clouds -parallel > ${logRun} 2>&1
   #srun -n $SLURM_NTASKS ale_pimpleKinematicParcelFoamFreezingSF8.0_14Clouds -parallel > ${logRun} 2>&1
   #srun -n $SLURM_NTASKS dhcae_pimpleKinematicParcelFoam -parallel > ${logRun} 2>&1
   srun -n $SLURM_NTASKS pimpleFoam -parallel > ${logRun} 2>&1
else
   echo "Running pimpleFoam in parallel" | tee -a ${logJob}
   srun -n $SLURM_NTASKS pimpleFoam > ${logRun} 2>&1
fi


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Reconstructing the Final time if it exists
echo "Reconstructing the restartTime if it does not have the .done file" | tee -a ${logJob}
cd $baseDir/$workingDir
#if [ -d processor0 ]; then
    jTime=$finishTime
    if [ -f "./${jTime}/.done" ]; then
      echo "NOT Reconstructing ${jTime} as it was done already" | tee -a ${logJob}
    else
      echo "YES Reconstructing ${jTime}" | tee -a ${logJob}
      date | tee -a ${logJob}
      srun -n 1 reconstructPar -time "${jTime}" > "logR${jTime}" 2>&1
      touch "./${jTime}/.done"
      date | tee -a ${logJob}
    fi
#fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# End
echo "Case run Finished" | tee -a ${logJob}
exit 0

#-----------------------------------------
#Add a mark for last changes: (for rsync to pick it up with --only-size)
#2018.07.26
