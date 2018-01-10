#!/bin/bash -l
#AEG: This is the internal part of script for sampling the mean values for the latest time
#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# General
#originalName=AEG. Defined in the main calling program
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
#Working Directories
baseDir=/scratch/pawsey0106/espinosa/OpenFOAM/espinosa-$FOAMVersion/run
#previousDir=
#workingDir=AEG. Defined in the main calling program
#nextDir=
functionsD=/home/espinosa/bash_functions
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

#-----------------------------------------
#Knowing the computer we are using for this script
THISHOST=$(hostname --short)
echo "THISHOST=${THISHOST}" | tee -a ${logJob}
if [ "${THISHOST:0:1}" = "n" ]; then
   echo "The computer is magnus" | tee -a ${logJob}
elif [ "${THISHOST:0:1}" = "z" ]; then
   echo "The computer is zeus" | tee -a ${logJob}
fi



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
nTocallos=$(( $nTocallos - 2))

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Checking if there are other pending jobs with the same name
nPendientes=$(squeue --name="$SLURM_JOB_NAME" --state=PENDING | wc -l)
nPendientes=$(float_eval "$nPendientes")
nPendientes=$(( $nPendientes - 1))

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
#Moving into processor0 if it exists
cd $baseDir/$workingDir
if [ -d processor0 ]; then
   echo "Directory processor0 is here. Good! Moving inside it."| tee -a ${logJob}
   cd processor0  
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Generating a list of existing time directories (we are inside processor0)
echo "Reading a list of existing time directories" | tee -a ${logJob}
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
   echo "Exiting because NO time directories are available for reconstruct" | tee -a ${logJob}
   exit 3
else
    maxTimeSeen=${timeDirArr[0]}
    echo "The maxTimeSeen is $maxTimeSeen" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Defining the time from which reconstruct
jEnd=0
if [ $nTimeDirectories -eq 1 ]; then
    jIni=$jEnd
    echo "Using the only existing time ${timeDirArr[$jIni]} for reconstruct" | tee -a ${logJob}
elif [ $nTimeDirectories -eq 2 ]; then
    jIni=1
    echo "Using the only two existing times: ${timeDirArr[$jIni]}:${timeDirArr[$jEnd]} for reconstruct" | tee -a ${logJob}
else
    jIni=2
    echo "Using the last three existing times: ${timeDirArr[$jIni]}:${timeDirArr[$jEnd]} for reconstruct" | tee -a ${logJob}
fi
endTime=${timeDirArr[$jEnd]}
iniTime=${timeDirArr[$jIni]}
cd $baseDir/$workingDir

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Checking if the desired time directories have been reconstructed already (with a .done flagFile)
echo "Checking all times without the .done file" | tee -a ${logJob}
cd $baseDir/$workingDir
yesReconstruct=false
for ((j=$jEnd; j<=$jIni; j++))
do
    jTime=${timeDirArr[$j]}
    if [ -f "./${jTime}/.done" ]; then
      echo "NOT Reconstructing ${jTime} as it was done already" | tee -a ${logJob}
    else
      yesReconstruct=true
      echo "YES chosen for reconstructing ${jTime} in the following stage" | tee -a ${logJob}
      echo "Deleting ${jTime} if it exists" | tee -a ${logJob}
      rm -r $jTime
    fi
done

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Reconstruct the chosen range of time
if [ "$yesReconstruct" = "true" ]; then
   echo "Reconstructing now from ${iniTime} to ${endTime} only chosen times from previous stage" | tee -a ${logJob}
   date | tee -a ${logJob}
   if [ "${THISHOST:0:1}" = "z" ]; then
      reconstructPar -newTimes -time "${iniTime}:${endTime}" >> ${logRun} 2>&1
   elif [ "${THISHOST:0:1}" = "n" ]; then
      aprun -n 1 reconstructPar -newTimes -time "${iniTime}:${endTime}" >> ${logRun} 2>&1
   fi
   echo "Finished reconstructing" | tee -a ${logJob}
   date | tee -a ${logJob}
else
   echo "No additional reconstruction is neccessary" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Adding the .done file to all the reconstructed times
cd $baseDir/$workingDir
for ((j=$jEnd; j<=$jIni; j++))
do    
    jTime=${timeDirArr[$j]}
    echo "Adding the .done file to ${jTime}" | tee -a ${logJob}
    touch "./${jTime}/.done"
done

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Defining again the endTime, just in case it has not been reconstructed properly
#(the last time may have corrupted files as the openFOAM solver may have been interrupted while writing)
#     Generating a list of existing reconstructed time directories
cd $baseDir/$workingDir
echo "Reading a list of existing time directories" | tee -a ${logJob}
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
   echo "Exiting because NO time directories have been reconstructed" | tee -a ${logJob}
   exit 3
else
    maxTimeSeen=${timeDirArr[0]}
    echo "The maxTimeSeen is $maxTimeSeen" | tee -a ${logJob}
fi
#  Defining the endTime
jEnd=0
endTime=${timeDirArr[$jEnd]}
cd $baseDir/$workingDir

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Defining a Cycle for revising what is still needed to sample as a Mean
cd $baseDir/$workingDir/postProcessing
echo "Defining the list of directories to check" | tee -a ${logJob}
checkingDirectories=(pressureMeanRings velocityMeanRings arrayMeanLines ADDITIONAL_velocityMeanRings ADDITIONAL_pressureMeanRings)
checkingFiles=(.doneMeanPRing .doneMeanURing .doneMeanUPLines .doneMeanUAdditionalRing .doneMeanPAdditionalRing)
#   Number of elements in the array so far
i=${#checkingDirectories[@]}
#   Adding the folders of the forces for each collector
ls -dt meanForces_cylinder*/ | sed 's/\///g' > listaDirs.Borra
sort -rn listaDirs.Borra > listaDirsOrdenada.Borra
while read textForceDir
do
    checkingDirectories[$i]=$textForceDir
    checkingFiles[$i]=.doneMeanForces
    ((i++))
done < listaDirsOrdenada.Borra
nCheckDirectories=$(($i - 1))

#Starting Cycle for all the checked directories
for j in `seq 0 ${nCheckDirectories}`; do
   echo "Checking status for Directory ${checkingDirectories[$j]}"| tee -a ${logJob}
   #-------------------------------------------------------------------------
   #-------------------------------------------------------------------------
   #Checking if directory (e.g. pressureMeanRings) exists
   cd $baseDir/$workingDir/postProcessing
   if [ -d ./${checkingDirectories[$j]} ] && [ -f ./${checkingFiles[$j]} ]; then   
      echo "Directory ${checkingDirectories[$j]} is yep done. Will check if new mean is neccesary."| tee -a ${logJob}
      checkForNewMean=true
   else
      echo "Directory ${checkingDirectories[$j]} is not done, will keep going as normal."| tee -a ${logJob}
      checkForNewMean=false
   fi

   #-------------------------------------------------------------------------
   #-------------------------------------------------------------------------
   #Checking times in directory (e.g. pressureMeanRings)
   cd $baseDir/$workingDir/postProcessing
   if [ "$checkForNewMean" = "true" ]; then
      cd ./${checkingDirectories[$j]}
      echo "Reading a list of existing times in ${checkingDirectories[$j]}" | tee -a ${logJob}
      ls -dt [0-9]*/ | sed 's/\///g' > listaDirs.Borra
      sort -rn listaDirs.Borra > listaDirsOrdenada.Borra
      i=0
      while read textTimeDir
      do
          meanDirArr[$i]=$textTimeDir
          #echo "The $i timeDir is: ${timeDirArr[$i]}" | tee -a ${logJob}
          ((i++))
      done < listaDirsOrdenada.Borra
      nTimeMean=$i
      if [ $nTimeMean -eq 0 ]
      then
         echo "NO time directories available in ${checkingDirectories[$j]}" | tee -a ${logJob}
         checkForNewMean=false
         echo "Exiting because NO time directories available but .done file exists" | tee -a ${logJob}
         exit 4
      else
          maxMeanSeen=${meanDirArr[0]}
          echo "The maxMeanSeen in ${checkingDirectories[$j]} is $maxMeanSeen" | tee -a ${logJob}
      fi
   fi

   #-------------------------------------------------------------------------
   #-------------------------------------------------------------------------
   #.done files wont be deleted if maxMeanSeen >= endTime (which flags for Means already done)
   cd $baseDir/$workingDir/postProcessing
   if [ "$checkForNewMean" = "true" ] && float_cond "$maxMeanSeen >= $endTime"; then   
      echo "Leaving file: ${checkingFiles[$j]} as it is. Means already processed." | tee -a ${logJob}
      echo "maxMeanSeen:${maxMeanSeen} >= endTime:${endTime}" | tee -a ${logJob}
   else
      if [ "$checkForNewMean" = "true" ]; then
         echo "Removing .done file: ${checkingFiles[$j]} as a new Mean has been detected" | tee -a ${logJob}
         echo "maxMeanSeen:${maxMeanSeen} < endTime:${endTime}" | tee -a ${logJob}
      else
         echo "Removing .done file: ${checkingFiles[$j]} as ${checkingDirectories[$j]} is not done" | tee -a ${logJob}
      fi
      rm -f ./${checkingFiles[$j]}
   fi
done
#Ending Cycle for all the checked directories

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Sending the dependant job
#useDependantCycleAEG. Defined in the main calling program
#dependantScript=AEG. Defined in the main calling program
#repeatingScript=AEG. Defined in the main calling program
cd $baseDir/$workingDir
if [ ! -f ./postProcessing/.doneMeanPRing ] || [ ! -f ./postProcessing/.doneMeanURing ] || [ ! -f ./postProcessing/.doneMeanForces ] || [ ! -f ./postProcessing/.doneMeanPAdditionalRing ] || [ ! -f ./postProcessing/.doneMeanUAdditionalRing ] || [ ! -f ./postProcessing/.doneMeanUPLines ]; then
   echo "Sending repeated this script: ${repeatingScript} as all .done files are not present." | tee -a ${logJob}
   sbatch --dependency=afterany:${SLURM_JOB_ID} $repeatingScript
else
   echo "All .done files are present." | tee -a ${logJob}
   if [ "$useDependantCycle" = "true" ]; then
      echo "Sending the dependant job: ${dependantScript}" | tee -a ${logJob}
      sbatch --dependency=afterany:${SLURM_JOB_ID} $dependantScript
   else
      echo "useDependantCycle=false, therefore NOT SENDING the dependant script" | tee -a ${logJob}
   fi
   echo "Now exiting as All .done files are present." | tee -a ${logJob}
   exit 0
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Renaming result Mean fields in order sample them as U and p
tryFirst=true
sampleTime=${timeDirArr[0]}
trySecond=false
if [ "$tryFirst" = "true" ]; then
   if [ -f ./${timeDirArr[0]}/UMean ]; then
      echo "UMean YES exists in ${timeDirArr[0]}" | tee -a ${logJob}
      echo "Renaming fields in ${timeDirArr[0]}" | tee -a ${logJob}
      if ! [ -f ./${timeDirArr[0]}/U.Truth ]; then
         echo "U.Truth does not exists in ${timeDirArr[0]}. Creating it from U" | tee -a ${logJob}
         copyFile ./${timeDirArr[0]}/U ./${timeDirArr[0]}/U.Truth
      fi
      copyFile ./${timeDirArr[0]}/UMean ./${timeDirArr[0]}/U
   else
      echo "UMean does not exist in ${timeDirArr[0]}" | tee -a ${logJob}
      echo "Will try with ${timeDirArr[1]}" | tee -a ${logJob}
      trySecond=true
   fi
   if [ -f ./${timeDirArr[0]}/pMean ]; then
      echo "pMean YES exists in ${timeDirArr[0]}" | tee -a ${logJob}
      echo "Renaming fields in ${timeDirArr[0]}" | tee -a ${logJob}
      if ! [ -f ./${timeDirArr[0]}/p.Truth ]; then
         echo "p.Truth does not exists in ${timeDirArr[0]}. Creating it from p" | tee -a ${logJob}
         copyFile ./${timeDirArr[0]}/p ./${timeDirArr[0]}/p.Truth
      fi
      copyFile ./${timeDirArr[0]}/pMean ./${timeDirArr[0]}/p
   else
      echo "pMean does not exist in ${timeDirArr[0]}" | tee -a ${logJob}
      echo "Will try with ${timeDirArr[1]}" | tee -a ${logJob}
      trySecond=true
   fi
fi
if [ "$trySecond" = "true" ]; then
   sampleTime=${timeDirArr[1]}
   if [ -f ./${timeDirArr[1]}/UMean ]; then
      echo "UMean YES exists in ${timeDirArr[1]}" | tee -a ${logJob}
      echo "Renaming fields in ${timeDirArr[1]}" | tee -a ${logJob}
      if ! [ -f ./${timeDirArr[1]}/U.Truth ]; then
         echo "U.Truth does not exists in ${timeDirArr[1]}. Creating it from U" | tee -a ${logJob}
         copyFile ./${timeDirArr[1]}/U ./${timeDirArr[1]}/U.Truth
      fi
      copyFile ./${timeDirArr[1]}/UMean ./${timeDirArr[1]}/U
   else
      echo "UMean does not exist in ${timeDirArr[1]}" | tee -a ${logJob}
      echo "Exiting" | tee -a ${logJob}
      exit 5
   fi
   if [ -f ./${timeDirArr[1]}/pMean ]; then
      echo "pMean YES exists in ${timeDirArr[1]}" | tee -a ${logJob}
      echo "Renaming fields in ${timeDirArr[1]}" | tee -a ${logJob}
      if ! [ -f ./${timeDirArr[1]}/p.Truth ]; then
         echo "p.Truth does not exists in ${timeDirArr[1]}. Creating it from p" | tee -a ${logJob}
         copyFile ./${timeDirArr[1]}/p ./${timeDirArr[1]}/p.Truth
      fi
      copyFile ./${timeDirArr[1]}/pMean ./${timeDirArr[1]}/p
   else
      echo "pMean does not exist in ${timeDirArr[1]}" | tee -a ${logJob}
      echo "Exiting" | tee -a ${logJob}
      exit 5
   fi
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Preparing dictionaries for the sampling
restartTime=$sampleTime
timeFinal=$sampleTime
cd $baseDir/$workingDir #Comming back to the working directory
#Copying the file that define force calculations:-------------------------
echo "Copying file: " | tee -a ${logJob}
echo "$GeneralDir/system.ForcesSampling/forcesCylinder_${domainType}_${arrayType}.txt" | tee -a ${logJob}
rm ./system/forcesCylinder.txt
copyFile $GeneralDir/system.ForcesSampling/forcesCylinder_${domainType}_${arrayType}.txt ./system/forcesCylinder.txt
sed -i "s/OUTPUT_INTERVAL_FORCES/1/" ./system/forcesCylinder.txt
#Copying the different files that define sampling:-------------------------
#samplingRings:::
echo "Sampling will be performed" | tee -a ${logJob}
echo "Copying file: " | tee -a ${logJob}
echo "${GeneralDir}/system.ForcesSampling/samplingRings_${domainType}_${arrayType}_SF${arrayDensity}.txt"  | tee -a ${logJob}
rm ./system/samplingRings.txt
touch ./system/samplingRings.txt
copyFile $GeneralDir/system.ForcesSampling/samplingRings_${domainType}_${arrayType}_SF${arrayDensity}.txt ./system/samplingRingsPostProcess.txt
sed -i "s/OUTPUT_INTERVAL_U/1/" ./system/samplingRingsPostProcess.txt
sed -i "s/OUTPUT_INTERVAL_P/1/" ./system/samplingRingsPostProcess.txt
#additionalRings:::
echo "Copying file: " | tee -a ${logJob}
echo "${GeneralDir}/system.ForcesSampling/additionalRings_${domainType}_${arrayType}_SF${arrayDensity}.txt"  | tee -a ${logJob}
rm ./system/additionalRings.txt
touch ./system/additionalRings.txt
copyFile $GeneralDir/system.ForcesSampling/additionalRings_${domainType}_${arrayType}_SF${arrayDensity}.txt ./system/additionalRingsPostProcess.txt
sed -i "s/OUTPUT_INTERVAL_U/${OUTPUT_INTERVAL_U}/" ./system/additionalRingsPostProcess.txt
sed -i "s/OUTPUT_INTERVAL_P/${OUTPUT_INTERVAL_P}/" ./system/additionalRingsPostProcess.txt
#samplingLines:::
echo "Copying file: " | tee -a ${logJob}
echo "${GeneralDir}/system.ForcesSampling/samplingLines_${domainType}_${arrayType}_SF${arrayDensity}.txt"  | tee -a ${logJob}
rm ./system/samplingLines.txt
touch ./system/samplingLines.txt
copyFile $GeneralDir/system.ForcesSampling/samplingLines_${domainType}_${arrayType}_SF${arrayDensity}.txt ./system/samplingLinesPostProcess.txt
sed -i "s/OUTPUT_INTERVAL_pU/${OUTPUT_INTERVAL_pU}/" ./system/samplingLinesPostProcess.txt
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
averageEnabled=false #Leaving it false
#Adapting controlDict:-------------------------
copyFile $GeneralDir/system.FlowFields/controlDict.Macho$domainType ./system/controlDict
echo "Modifying control dict with the desired restart and final times" | tee -a ${logJob}
echo "restartTime=${restartTime}, finalTime=${timeFinal}" | tee -a ${logJob}
sed -i "s/ALE_STARTTIME/$restartTime/" ./system/controlDict
sed -i "s/ALE_FINALTIME/$timeFinal/" ./system/controlDict
sed -i "s/ALE_AVERAGE_ENABLED/${averageEnabled}/" ./system/controlDict

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Modifying the forces definition file
if ! [ -f ./postProcessing/.doneMeanForces ]; then
   echo "Modifying the forces definition file" | tee -a ${logJob}
   sed -i "s/forces_cylinder/meanForces_cylinder/g" ./system/forcesCylinder.txt #changing forces name
else
   echo "NOT Modifying the forces definition file as forces are already done." | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Obtaining the forces using the ControlDict setup
cd $baseDir/$workingDir
if ! [ -f ./postProcessing/.doneMeanForces ]; then
   echo "Running for obtaining the forces:" | tee -a ${logJob}
   echo "execFlowFunctionObjects -time $sampleTime >> ${logRun} 2>&1" | tee -a ${logJob}
   date | tee -a ${logJob}
   if [ "${THISHOST:0:1}" = "z" ]; then
      execFlowFunctionObjects -time $sampleTime >> ${logRun} 2>&1
   elif [ "${THISHOST:0:1}" = "n" ]; then
      aprun -n 1 execFlowFunctionObjects -time $sampleTime >> ${logRun} 2>&1
   fi
   touch ./postProcessing/.doneMeanForces
   date | tee -a ${logJob}
   echo "Finished with the forces" | tee -a ${logJob}
else
   echo "Mean forces are already done. Not doing again." | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Modifying the sampleRings file in order to feed its sampling points into a sampleDict (see two sections below and further)
cd $baseDir/$workingDir
if [ ! -f ./postProcessing/.doneMeanPRing ] || [ ! -f ./postProcessing/.doneMeanURing ]; then
   echo "Modifying the sampleRings file" | tee -a ${logJob}
   sed -i "s/velocityRings/velocityMeanRings/g" ./system/samplingRingsPostProcess.txt #changing sets
   sed -i "s/pressureRings/pressureMeanRings/g" ./system/samplingRingsPostProcess.txt
   #splitting the samplingRings file in the pressure and the velocity parts::
   echo "Splitting the sampleRings file" | tee -a ${logJob}
   #Separating the file in two with awk:::
   awk '{print >out}; /pressureMeanRings/{out="./system/samplingRingsPostProcess_p.txt"}' out=./system/samplingRingsPostProcess_U.txt ./system/samplingRingsPostProcess.txt
   #Deleting these two words first appearance in the first column inside the U part:::
   sed -i 's/^velocityMeanRings//' ./system/samplingRingsPostProcess_U.txt
   sed -i 's/^pressureMeanRings//' ./system/samplingRingsPostProcess_U.txt
   #Removing the initial and final brackets in the first column in the U part:::
   sed -i 's/^{//' ./system/samplingRingsPostProcess_U.txt
   sed -i 's/^}//' ./system/samplingRingsPostProcess_U.txt
   #Removing the initial and final brackets in the first column in the p part:::
   sed -i 's/^{//' ./system/samplingRingsPostProcess_p.txt
   sed -i 's/^}//' ./system/samplingRingsPostProcess_p.txt
else
   echo "NOT Modifying the sampleRings file as UMean and PMean are already done" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Modifying the additionalRing file in order to feed its sampling points into a sampleDict (see two sections below and further)
cd $baseDir/$workingDir
if [ ! -f ./postProcessing/.doneMeanPAdditionalRing ] || [ ! -f ./postProcessing/.doneMeanUAdditionalRing ]; then
   echo "Modifying the additionalRings file" | tee -a ${logJob}
   sed -i "s/velocityRings/velocityMeanRings/g" ./system/additionalRingsPostProcess.txt #changing sets
   sed -i "s/pressureRings/pressureMeanRings/g" ./system/additionalRingsPostProcess.txt
   #splitting the additionalRings file in the pressure and the velocity parts::
   echo "Splitting the additionalRings file" | tee -a ${logJob}
   #Separating the file in two with awk:::
   awk '{print >out}; /ADDITIONAL_pressureMeanRings/{out="./system/additionalRingsPostProcess_p.txt"}' out=./system/additionalRingsPostProcess_U.txt ./system/additionalRingsPostProcess.txt
   #Deleting these two words first appearance in the first column inside the U part:::
   sed -i 's/^ADDITIONAL_velocityMeanRings//' ./system/additionalRingsPostProcess_U.txt
   sed -i 's/^ADDITIONAL_pressureMeanRings//' ./system/additionalRingsPostProcess_U.txt
   #Removing the initial and final brackets in the first column in the U part:::
   sed -i 's/^{//' ./system/additionalRingsPostProcess_U.txt
   sed -i 's/^}//' ./system/additionalRingsPostProcess_U.txt
   #Removing the initial and final brackets in the first column in the p part:::
   sed -i 's/^{//' ./system/additionalRingsPostProcess_p.txt
   sed -i 's/^}//' ./system/additionalRingsPostProcess_p.txt
else
   echo "NOT Modifying the additionalRings file as UMean and PMean are already done" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Modifying the samplingLines file in order to feed its sampling points into a sampleDict (see two sections below and further)
cd $baseDir/$workingDir
if ! [ -f ./postProcessing/.doneMeanUPLines ]; then
   echo "Modifying the samplingLines file" | tee -a ${logJob}
   sed -i "s/HorizontalLine/HorizontalMeanLine/g" ./system/samplingLinesPostProcess.txt #changing sets
   sed -i "s/VerticalLine/VerticalMeanLine/g" ./system/samplingLinesPostProcess.txt
   #Deleting this word first appearance in the first column:::
   sed -i 's/^arrayLines//' ./system/samplingLinesPostProcess.txt
   #Removing the initial and final brackets in the first column:::
   sed -i 's/^{//' ./system/samplingLinesPostProcess.txt
   sed -i 's/^}//' ./system/samplingLinesPostProcess.txt
else
   echo "NOT Modifying the samplingLines file as Mean Lines are already done" | tee -a ${logJob}
fi


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Copying the sampleDict.Macho into the system dir
cd $baseDir/$workingDir
echo "Copying file: " | tee -a ${logJob}
echo "$GeneralDir/system.FlowFields/sampleDict.Macho" | tee -a ${logJob}
copyFile $GeneralDir/system.FlowFields/sampleDict.Macho ./system/sampleDict

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Obtaining the ring samples of Mean U by using sampleDict
cd $baseDir/$workingDir
sed -i 's/samplingFileHere.txt/samplingRingsPostProcess_U.txt/' ./system/sampleDict
if ! [ -f ./postProcessing/.doneMeanURing ]; then
   echo "Running for obtaining the U ring samples:" | tee -a ${logJob}
   echo "sample -time $sampleTime >> ${logRun} 2>&1" | tee -a ${logJob}
   date | tee -a ${logJob}
   if [ "${THISHOST:0:1}" = "z" ]; then
      sample -time $sampleTime >> ${logRun} 2>&1
   elif [ "${THISHOST:0:1}" = "n" ]; then
      aprun -n 1 sample -time $sampleTime >> ${logRun} 2>&1
   fi
   touch ./postProcessing/.doneMeanURing
   date | tee -a ${logJob}
   echo "Finished with UMean sampling" | tee -a ${logJob}
else
   echo "NOT Running for UMean ring samples as it is already done" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Obtaining the ring samples of Mean p by using sampleDict
cd $baseDir/$workingDir
sed -i 's/samplingRingsPostProcess_U.txt/samplingRingsPostProcess_p.txt/' ./system/sampleDict
if ! [ -f ./postProcessing/.doneMeanPRing ]; then
   echo "Running for obtaining the p ring samples:" | tee -a ${logJob}
   echo "sample -time $sampleTime >> ${logRun} 2>&1" | tee -a ${logJob}
   date | tee -a ${logJob}
   if [ "${THISHOST:0:1}" = "z" ]; then
      sample -time $sampleTime >> ${logRun} 2>&1
   elif [ "${THISHOST:0:1}" = "n" ]; then
      aprun -n 1 sample -time $sampleTime >> ${logRun} 2>&1
   fi
   touch ./postProcessing/.doneMeanPRing
   date | tee -a ${logJob}
   echo "Finished with pMean sampling" | tee -a ${logJob}
else
   echo "NOT Running for pMean ring samples as it is already done" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Obtaining the additionalRing samples of Mean U by using sampleDict
cd $baseDir/$workingDir
sed -i 's/samplingRingsPostProcess_p.txt/additionalRingsPostProcess_U.txt/' ./system/sampleDict
if ! [ -f ./postProcessing/.doneMeanUAdditionalRing ]; then
   echo "Running for obtaining the U additionalRing samples:" | tee -a ${logJob}
   echo "sample -time $sampleTime >> ${logRun} 2>&1" | tee -a ${logJob}
   date | tee -a ${logJob}
   if [ "${THISHOST:0:1}" = "z" ]; then
      sample -time $sampleTime >> ${logRun} 2>&1
   elif [ "${THISHOST:0:1}" = "n" ]; then
      aprun -n 1 sample -time $sampleTime >> ${logRun} 2>&1
   fi
   touch ./postProcessing/.doneMeanUAdditionalRing
   date | tee -a ${logJob}
   echo "Finished with UMean additionalRing sampling" | tee -a ${logJob}
else
   echo "NOT Running for UMean additionalRing samples as it is already done" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Obtaining the AdditionalRing samples of Mean p by using sampleDict
cd $baseDir/$workingDir
sed -i 's/additionalRingsPostProcess_U.txt/additionalRingsPostProcess_p.txt/' ./system/sampleDict
if ! [ -f ./postProcessing/.doneMeanPAdditionalRing ]; then
   echo "Running for obtaining the p AdditionalRing samples:" | tee -a ${logJob}
   echo "sample -time $sampleTime >> ${logRun} 2>&1" | tee -a ${logJob}
   date | tee -a ${logJob}
   if [ "${THISHOST:0:1}" = "z" ]; then
      sample -time $sampleTime >> ${logRun} 2>&1
   elif [ "${THISHOST:0:1}" = "n" ]; then
      aprun -n 1 sample -time $sampleTime >> ${logRun} 2>&1
   fi
   touch ./postProcessing/.doneMeanPAdditionalRing
   date | tee -a ${logJob}
   echo "Finished with pMean AdditionalRing sampling" | tee -a ${logJob}
else
   echo "NOT Running for pMean AdditionalRing samples as it is already done" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Obtaining the samplingLines samples of Mean U&p by using sampleDict
cd $baseDir/$workingDir
sed -i 's/additionalRingsPostProcess_p.txt/samplingLinesPostProcess.txt/' ./system/sampleDict
if ! [ -f ./postProcessing/.doneMeanUPLines ]; then
   echo "Running for obtaining the U&p samplingLines samples:" | tee -a ${logJob}
   echo "sample -time $sampleTime >> ${logRun} 2>&1" | tee -a ${logJob}
   date | tee -a ${logJob}
   if [ "${THISHOST:0:1}" = "z" ]; then
      sample -time $sampleTime >> ${logRun} 2>&1
   elif [ "${THISHOST:0:1}" = "n" ]; then
      aprun -n 1 sample -time $sampleTime >> ${logRun} 2>&1
   fi
   touch ./postProcessing/.doneMeanUPLines
   date | tee -a ${logJob}
   echo "Finished with UMean&pMean Lines sampling" | tee -a ${logJob}
else
   echo "NOT Running for UMean&pMean samplingLines samples as it is already done" | tee -a ${logJob}
fi

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Recovering the original U and p fields in the sampleTime
cd $baseDir/$workingDir
echo "Recovering the original U and p fields in the sampleTime" | tee -a ${logJob}
copyFile ./$sampleTime/p.Truth ./$sampleTime/p
copyFile ./$sampleTime/U.Truth ./$sampleTime/U

#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Moving the sampled files into the correct (my own) postprocessing directories
cd $baseDir/$workingDir
echo "Moving the sampled files into the correct postProcessing directories" | tee -a ${logJob}
if ! [ -d ./postProcessing/ADDITIONAL_velocityMeanRings/$sampleTime ]; then
   mkdir -p ./postProcessing/ADDITIONAL_velocityMeanRings/$sampleTime
fi
if ! [ -d ./postProcessing/ADDITIONAL_pressureMeanRings/$sampleTime ]; then
   mkdir -p ./postProcessing/ADDITIONAL_pressureMeanRings/$sampleTime
fi
if ! [ -d ./postProcessing/velocityMeanRings/$sampleTime ]; then
   mkdir -p ./postProcessing/velocityMeanRings/$sampleTime
fi
if ! [ -d ./postProcessing/pressureMeanRings/$sampleTime ]; then
   mkdir -p ./postProcessing/pressureMeanRings/$sampleTime
fi
if ! [ -d ./postProcessing/arrayMeanLines/$sampleTime ]; then
   mkdir -p ./postProcessing/arrayMeanLines/$sampleTime
fi
arrayLines
echo "Moving additionalRings Mean Velocities" | tee -a ${logJob}
mv ./postProcessing/sets/$sampleTime/*ADDITIONAL_velocityMeanRings* ./postProcessing/ADDITIONAL_velocityMeanRings/$sampleTime
echo "Moving additionalRings Mean Pressures" | tee -a ${logJob}
mv ./postProcessing/sets/$sampleTime/*ADDITIONAL_pressureMeanRings* ./postProcessing/ADDITIONAL_pressureMeanRings/$sampleTime
echo "Moving samplingRings Mean Velocities" | tee -a ${logJob}
mv ./postProcessing/sets/$sampleTime/*velocityMeanRings* ./postProcessing/velocityMeanRings/$sampleTime
echo "Moving samplingRings Mean Pressures" | tee -a ${logJob}
mv ./postProcessing/sets/$sampleTime/*pressureMeanRings* ./postProcessing/pressureMeanRings/$sampleTime
echo "Moving Horizontal samplingLines Mean Pressures and Velocities" | tee -a ${logJob}
mv ./postProcessing/sets/$sampleTime/*HorizontalMeanLine* ./postProcessing/arrayMeanLines/$sampleTime
echo "Moving Vertical samplingLines Mean Pressures and Velocities" | tee -a ${logJob}
mv ./postProcessing/sets/$sampleTime/*VerticalMeanLine* ./postProcessing/arrayMeanLines/$sampleTime


#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#Script done
cd $baseDir/$workingDir
echo "Sample means finished" | tee -a ${logJob}
exit 0
