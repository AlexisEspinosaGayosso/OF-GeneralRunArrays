#!/bin/bash -l
#AEG: This is the internal part of the python posprocessing script

#-----------------------------------------
# General
#FOAMVersion=AEG. Defined in the main calling program
#thisScript=AEG. Defined in the main calling program

#-----------------------------------------
#Names for the case
#domainType=AEG. Defined in the main calling program
#arrayType=AEG. Defined in the main calling program
#arrayDensity=AEG. Defined in the main calling program
#Reynolds=AEG. Defined in the main calling program

#-----------------------------------------
#Working Directories
baseDir=$MYSCRATCH/OpenFOAM/espinosa-$FOAMVersion/run
#previousDir=
#workingDir=AEG. Defined in the main calling program
#nextDir=
functionsD=$MYBASE_AEG/bash_functions
pythonDir=$MYBASE_AEG/PythonPrograms

#-----------------------------------------
#Log files names
cd $baseDir
cd $workingDir
dateString=$(date +%Y-%m-%d.%H.%M.%S)
logRun="${baseDir}/${workingDir}/log_run_VolPY_${SLURM_JOB_ID}_${dateString}"
logJob="${baseDir}/${workingDir}/log_job_VolPY_${SLURM_JOB_ID}_${dateString}"
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
echo "THISHOST=${THISHOST}" | tee -a ${logJob}

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
#   module load PrgEnv-gnu
   echo "For now, not loading modules in magnus" | tee -a ${logJob}
   piton=python
elif [ "${THISHOST:0:1}" = "z" ]; then
   echo "Loading modules for python and numpy" | tee -a ${logJob}
   module load python
   module load numpy
   piton=python
elif [ "${THISHOST:0:1}" = "B" ]; then
   echo "I'm in Behemoth, setting alias python=python3" | tee -a ${logJob}
   piton=python3
fi
echo "Have defined piton=${piton}" | tee -a ${logJob}

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
   exit 4
fi

#-----------------------------------------
#Sourcing the auxiliary function defininitons
archi=$functionsD/auxiliaryFunctions.sh
if [ -e $archi ]; then
   echo "Found auxiliary functions" | tee -a ${logJob}
   source $archi
else
   echo "NOT FOUND auxiliary functions" | tee -a ${logJob}
   exit 4
fi

#------------------------------------------
# Identifying if is there another job with the same name already running
nTocallos=$(squeue --name="$SLURM_JOB_NAME" --state=RUNNING | wc -l)
nTocallos=$(float_eval "$nTocallos")
nTocallos=$(( $nTocallos - 2))

#------------------------------------------
#Checking if there are other pending jobs with the same name
nPendientes=$(squeue --name="$SLURM_JOB_NAME" --state=PENDING | wc -l)
nPendientes=$(float_eval "$nPendientes")
nPendientes=$(( $nPendientes - 1))

#-----------------------------------------
#Logic for cancelling existing running and pending jobs and resubmitting

if [ $nTocallos -ge 2 ] || [ $nPendientes -ge 2 ]; then
    echo "TWO OR MORE jobs with the same name are already running. Tocallos=${nTocallos}" | tee -a ${logJob}
    echo "or TWO OR MORE jobs with the same name are already pending. Pending=${nPendientes}" | tee -a ${logJob}
    echo "All the existing jobs (all running and all pending) with the same name will be cancelled" | tee -a ${logJob}
    scancel --name="$SLURM_JOB_NAME"
    echo "All Tocallo-Jobs (running and pending) have been cancelled" | tee -a ${logJob}
    echo "Now, This job will proceed normally" | tee -a ${logJob}
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

#-----------------------------------------
#Change directory
echo "Changing to ${baseDir}/${workingDir}" | tee -a ${logJob}
cd $baseDir/$workingDir
#### I used to mv log files like this, but now Im naming them from the beginning
##mv log_run log_run_${SLURM_JOB_ID}
##mv log_job log_job_${SLURM_JOB_ID}

#-----------------------------------------
#Avoiding falling into an infinite loop of recurrent errors which generate huge amount of files
#maxSlurmies= AEG.Defined in the main calling program
echo "Checking slurmies" | tee -a ${logJob}
slurmies=$(find . -maxdepth 1 -name "slurm*" | wc -l)
if [ $slurmies -gt $maxSlurmies ]; then
   echo "Exiting because the maximum slurmies have been reached: $slurmies" | tee -a ${logJob}
   exit 2
fi

#-----------------------------------------
#Type of analysis to perform
#For analysing the instantaneous time series:
#readInstantaneous=AEG. defined in the calling script
#For analysing the Mean fields:
#readMeans=AEG. defined in the calling script

#-----------------------------------------
#The rps to analyse
#rpArray=AEG. defined in the calling script
#useAllRps=AEG. defined in the calling script

#Using the whole list of rp's defined in the samplingRp.txt file
if [ "$useAllRps" = "true" ]; then
   echo "useAllRps=true" | tee -a ${logJob}
   echo "Reading rpDataFile:" | tee -a ${logJob}
   rpDataFile=${baseDir}/${workingDir}/postProcessing/samplingRp.txt
   echo $rpDataFile | tee -a ${logJob}
   ii=0
   rpArray[$ii]=9999
   while read -r line
   do
      rpArray[$ii]=$line
      ii=$(( $ii + 1 ))
   done < $rpDataFile
else
   echo "useAllRps=false" | tee -a ${logJob}
fi

#Number of rps to analyse
Nrps=${#rpArray[@]}


#-----------------------------------------
#Deciding if sending a following job with dependency
#useDependantCycle=AEG.defined in the calling script
#dependantScript=AEG.defined in the calling script
#Local flag to know if a dependant cycle was already sent to the queue:
localDependantSent=false

#-----------------------------------------
# Running the angular MEAN
if [ "${readMeans}" = "true" ]; then

   #-----------------------------------------
   #The rps done in Angular
   echo "Reading rpDoneAngularMeanFile:" | tee -a ${logJob}
   rpDoneAngularMeanFile=${baseDir}/${workingDir}/postProcessing/pythonFiles/AngularMean/doneAngularMean.txt
   echo $rpDoneAngularMeanFile | tee -a ${logJob}
   doneAngularMeanArray[0]=9999
   ii=1
   if [ -f "${rpDoneAngularMeanFile}" ]
   then
      ii=0
      while read -r line
      do
         doneAngularMeanArray[$ii]=$line
         ii=$(( $ii + 1 ))
      done < $rpDoneAngularMeanFile
   else
      echo "rpDoneAngularMeanFile does not exist. Starting Mean Angular process from scratch." | tee -a ${logJob}
   fi
   NDoneAngularMean=${#doneAngularMeanArray[@]}

   #The processing cycle
   for ((ii=0; ii<${Nrps}; ii++));
   do
      rpAnalysis=${rpArray[$ii]}
      echo "Analysing AngularMean rp=${rpAnalysis}" | tee -a ${logJob}
      goForIt=true
      for ((jj=0; jj<${NDoneAngularMean}; jj++));
      do
         existingRp=${doneAngularMeanArray[$jj]}
         if float_cond "$existingRp == $rpAnalysis"; then
            goForIt=false
            echo "The AngularMean rp=${rpAnalysis} was already processed fully" | tee -a ${logJob}
         fi
      done
      if [ "${goForIt}" = "true" ]; then
         if [ "$useDependantCycle" = "true" ]; then
            if [ "$localDependantSent" = "false" ]; then
               echo "Sending also the dependant job: ${dependantScript}" | tee -a ${logJob}
               sbatch --dependency=afterany:${SLURM_JOB_ID} $dependantScript
               localDependantSent=true
            fi
         else
            echo "useDependantCycle=false, therefore NOT SENDING the dependant script" | tee -a ${logJob}
         fi
         echo "Obtaining the AngularMean analysis for the available times" | tee -a ${logJob}
         tiempo0=$(($(date +%s%N)/1000000)) 
         $piton $pythonDir/ArrayCapture/AngularFlux/AngularAccumulation.py $rpAnalysis $arrayDensity Mean $PWD > "${logRun}_AngularMean_${rpAnalysis}" 2>&1
         pyResult=$?
         tiempo1=$(($(date +%s%N)/1000000))
         deltaT=$(float_eval "(${tiempo1} - ${tiempo0})/1000.0")
         echo "The python script exited with pyResult=${pyResult}" | tee -a ${logJob}
         echo "Time used was: ${deltaT} seconds" | tee -a ${logJob}
         if [ $pyResult -eq 0 ]; then
            echo $rpAnalysis >> $rpDoneAngularMeanFile
         fi
      fi
   done
else
   echo "readMeans is set to false, so no Mean Angular process will be performed" | tee -a ${logJob}
fi



#-----------------------------------------
# Running the volumetric MEAN analysis
if [ "${readMeans}" = "true" ]; then
   #The rps done in Volumetric MEAN
   echo "Reading rpDoneVolumetricMeanFile:" | tee -a ${logJob}
   rpDoneVolumetricMeanFile=${baseDir}/${workingDir}/postProcessing/pythonFiles/VolumetricMean/doneVolumetricMean.txt
   echo $rpDoneVolumetricMeanFile | tee -a ${logJob}
   doneVolumetricMeanArray[0]=9999
   ii=1
   if [ -f "${rpDoneVolumetricMeanFile}" ]
   then
      ii=0
      while read -r line
      do
         doneVolumetricMeanArray[$ii]=$line
         ii=$(( $ii + 1 ))
      done < $rpDoneVolumetricMeanFile
   else
      echo "rpDoneVolumetricMeanFile does not exist. Starting volumetric mean process from scratch." | tee -a ${logJob}
   fi
   NDoneVolumetricMean=${#doneVolumetricMeanArray[@]}

   #The process cycle
   for ((ii=0; ii<${Nrps}; ii++));
   do
      rpAnalysis=${rpArray[$ii]}
      echo "Analysing VolumetricMean rp=${rpAnalysis}" | tee -a ${logJob}
      goForIt=true
      for ((jj=0; jj<${NDoneVolumetricMean}; jj++));
      do
         existingRp=${doneVolumetricMeanArray[$jj]}
         if float_cond "$existingRp == $rpAnalysis"; then
            goForIt=false
            echo "The VolumetricMean rp=${rpAnalysis} was already processed fully" | tee -a ${logJob}
         fi
      done
      if [ "${goForIt}" = "true" ]; then
         if [ "$useDependantCycle" = "true" ]; then
            if [ "$localDependantSent" = "false" ]; then
               echo "Sending also the dependant job: ${dependantScript}" | tee -a ${logJob}
               sbatch --dependency=afterany:${SLURM_JOB_ID} $dependantScript
               localDependantSent=true
            fi
         else
            echo "useDependantCycle=false, therefore NOT SENDING the dependant script" | tee -a ${logJob}
         fi
         echo "Obtaining the volumetricMean analysis for the available times" | tee -a ${logJob}
         tiempo0=$(($(date +%s%N)/1000000))
         date | tee -a ${logJob}
         $piton $pythonDir/ArrayCapture/VolumetricFlux/TestVolumetric.py $rpAnalysis $arrayDensity Mean $PWD > "${logRun}_VolumetricMean_${rpAnalysis}" 2>&1
         pyResult=$?
         date | tee -a ${logJob}
         tiempo1=$(($(date +%s%N)/1000000))
         deltaT=$(float_eval "(${tiempo1} - ${tiempo0})/1000.0")
         echo "The python script exited with pyResult=${pyResult}"  | tee -a ${logJob}
         echo "Time used was: ${deltaT} seconds" | tee -a ${logJob}
         if [ $pyResult -eq 0 ]; then
            echo $rpAnalysis >> $rpDoneVolumetricMeanFile
         fi
      fi
   done
else
   echo "readMeans is set to false, so no Mean Volumetric process will be performed" | tee -a ${logJob}
fi


#-----------------------------------------
# Running the CylindricalVel MEAN analysis
if [ "${readMeans}" = "true" ]; then
   #The rps done in CylindricalVel MEAN
   echo "Reading rpDoneCylindricalVelMeanFile:" | tee -a ${logJob}
   rpDoneCylindricalVelMeanFile=${baseDir}/${workingDir}/postProcessing/pythonFiles/CylindricalVelMean/doneCylindricalVelMean.txt
   echo $rpDoneCylindricalVelMeanFile | tee -a ${logJob}
   doneCylindricalVelMeanArray[0]=9999
   ii=1
   if [ -f "${rpDoneCylindricalVelMeanFile}" ]
   then
      ii=0
      while read -r line
      do
         doneCylindricalVelMeanArray[$ii]=$line
         ii=$(( $ii + 1 ))
      done < $rpDoneCylindricalVelMeanFile
   else
      echo "rpDoneCylindricalVelMeanFile does not exist. Starting CylindricalVel mean process from scratch." | tee -a ${logJob}
   fi
   NDoneCylindricalVelMean=${#doneCylindricalVelMeanArray[@]}

   #The process cycle
   for ((ii=0; ii<${Nrps}; ii++));
   do
      rpAnalysis=${rpArray[$ii]}
      echo "Analysing CylindricalVelMean rp=${rpAnalysis}" | tee -a ${logJob}
      goForIt=true
      for ((jj=0; jj<${NDoneCylindricalVelMean}; jj++));
      do
         existingRp=${doneCylindricalVelMeanArray[$jj]}
         if float_cond "$existingRp == $rpAnalysis"; then
            goForIt=false
            echo "The CylindricalVelMean rp=${rpAnalysis} was already processed fully" | tee -a ${logJob}
         fi
      done
      if [ "${goForIt}" = "true" ]; then
         if [ "$useDependantCycle" = "true" ]; then
            if [ "$localDependantSent" = "false" ]; then
               echo "Sending also the dependant job: ${dependantScript}" | tee -a ${logJob}
               sbatch --dependency=afterany:${SLURM_JOB_ID} $dependantScript
               localDependantSent=true
            fi
         else
            echo "useDependantCycle=false, therefore NOT SENDING the dependant script" | tee -a ${logJob}
         fi
         echo "Obtaining the CylindricalVelMean analysis for the available times" | tee -a ${logJob}
         tiempo0=$(($(date +%s%N)/1000000))
         date | tee -a ${logJob}
         $piton $pythonDir/ArrayCapture/CylindricalVelocities/CylindricalVel.py $rpAnalysis $arrayDensity Mean $PWD > "${logRun}_CylindricalVelMean_${rpAnalysis}" 2>&1
         pyResult=$?
         date | tee -a ${logJob}
         tiempo1=$(($(date +%s%N)/1000000))
         deltaT=$(float_eval "(${tiempo1} - ${tiempo0})/1000.0")
         echo "The python script exited with pyResult=${pyResult}"  | tee -a ${logJob}
         echo "Time used was: ${deltaT} seconds" | tee -a ${logJob}
         if [ $pyResult -eq 0 ]; then
            echo $rpAnalysis >> $rpDoneCylindricalVelMeanFile
         fi
      fi
   done
else
   echo "readMeans is set to false, so no Mean CylindricalVel process will be performed" | tee -a ${logJob}
fi

#-----------------------------------------
# Running the instantaneous angular analysis script for all the rp's
if [ "${readInstantaneous}" = "true" ]; then
   #The rps done in Angular
   echo "Reading rpDoneAngularFile:" | tee -a ${logJob}
   rpDoneAngularFile=${baseDir}/${workingDir}/postProcessing/pythonFiles/Angular/doneAngular.txt
   echo $rpDoneAngularFile | tee -a ${logJob}
   doneAngularArray[0]=9999
   ii=1
   if [ -f "${rpDoneAngularFile}" ]
   then
      ii=0
      while read -r line
      do
         doneAngularArray[$ii]=$line
         ii=$(( $ii + 1 ))
      done < $rpDoneAngularFile
   else
      echo "rpDoneAngularFile does not exist. Starting Instantaneus Angular process from scratch." | tee -a ${logJob}
   fi
   NDoneAngular=${#doneAngularArray[@]}

   #The processing cycle
   for ((ii=0; ii<${Nrps}; ii++));
   do
      rpAnalysis=${rpArray[$ii]}
      echo "Analysing Angular rp=${rpAnalysis}" | tee -a ${logJob}
      goForIt=true
      for ((jj=0; jj<${NDoneAngular}; jj++));
      do
         existingRp=${doneAngularArray[$jj]}
         if float_cond "$existingRp == $rpAnalysis"; then
            goForIt=false
            echo "The Angular rp=${rpAnalysis} was already processed fully" | tee -a ${logJob}
         fi
      done
      if [ "${goForIt}" = "true" ]; then
         if [ "$useDependantCycle" = "true" ]; then
            if [ "$localDependantSent" = "false" ]; then
               echo "Sending also the dependant job: ${dependantScript}" | tee -a ${logJob}
               sbatch --dependency=afterany:${SLURM_JOB_ID} $dependantScript
               localDependantSent=true
            fi
         else
            echo "useDependantCycle=false, therefore NOT SENDING the dependant script" | tee -a ${logJob}
         fi
         echo "Obtaining the Angular analysis for the available times" | tee -a ${logJob}
         tiempo0=$(($(date +%s%N)/1000000)) 
         $piton $pythonDir/ArrayCapture/AngularFlux/AngularAccumulation.py $rpAnalysis $arrayDensity Normal $PWD > "${logRun}_Angular_${rpAnalysis}" 2>&1
         pyResult=$?
         tiempo1=$(($(date +%s%N)/1000000))
         deltaT=$(float_eval "(${tiempo1} - ${tiempo0})/1000.0")
         echo "The python script exited with pyResult=${pyResult}" | tee -a ${logJob}
         echo "Time used was: ${deltaT} seconds" | tee -a ${logJob}
         if [ $pyResult -eq 0 ]; then
            echo $rpAnalysis >> $rpDoneAngularFile
         fi
      fi
   done
else
   echo "readInstantaneous is set to false, so no instantaneous Angular process will be performed" | tee -a ${logJob}
fi

#-----------------------------------------
# Running the instantaneous volumetric analysis script for all the rp's
if [ "${readInstantaneous}" = "true" ]; then
   #The rps done in Volumetric
   echo "Reading rpDoneVolumetricFile:" | tee -a ${logJob}
   rpDoneVolumetricFile=${baseDir}/${workingDir}/postProcessing/pythonFiles/Volumetric/doneVolumetric.txt
   echo $rpDoneVolumetricFile | tee -a ${logJob}
   doneVolumetricArray[0]=9999
   ii=1
   if [ -f "${rpDoneVolumetricFile}" ]
   then
      ii=0
      while read -r line
      do
         doneVolumetricArray[$ii]=$line
         ii=$(( $ii + 1 ))
      done < $rpDoneVolumetricFile
   else
      echo "rpDoneVolumetricFile does not exist, then starting Volumetric Instantaneous process from scratch." | tee -a ${logJob}
   fi
   NDoneVolumetric=${#doneVolumetricArray[@]}

   #The process cycle
   for ((ii=0; ii<${Nrps}; ii++));
   do
      rpAnalysis=${rpArray[$ii]}
      echo "Analysing Volumetric rp=${rpAnalysis}" | tee -a ${logJob}
      goForIt=true
      for ((jj=0; jj<${NDoneVolumetric}; jj++));
      do
         existingRp=${doneVolumetricArray[$jj]}
         if float_cond "$existingRp == $rpAnalysis"; then
            goForIt=false
            echo "The Volumetric rp=${rpAnalysis} was already processed fully" | tee -a ${logJob}
         fi
      done
      if [ "${goForIt}" = "true" ]; then
         if [ "$useDependantCycle" = "true" ]; then
            if [ "$localDependantSent" = "false" ]; then
               echo "Sending also the dependant job: ${dependantScript}" | tee -a ${logJob}
               sbatch --dependency=afterany:${SLURM_JOB_ID} $dependantScript
               localDependantSent=true
            fi
         else
            echo "useDependantCycle=false, therefore NOT SENDING the dependant script" | tee -a ${logJob}
         fi
         echo "Obtaining the volumetric analysis for the available times" | tee -a ${logJob}
         tiempo0=$(($(date +%s%N)/1000000)) 
         $piton $pythonDir/ArrayCapture/VolumetricFlux/TestVolumetric.py $rpAnalysis $arrayDensity Normal $PWD > "${logRun}_Volumetric_${rpAnalysis}" 2>&1
         pyResult=$?
         tiempo1=$(($(date +%s%N)/1000000))
         deltaT=$(float_eval "(${tiempo1} - ${tiempo0})/1000.0")
         echo "The python script exited with pyResult=${pyResult}" | tee -a ${logJob}
         echo "Time used was: ${deltaT} seconds" | tee -a ${logJob}
         if [ $pyResult -eq 0 ]; then
            echo $rpAnalysis >> $rpDoneVolumetricFile
         fi
      fi
   done
else
   echo "readInstantaneous is set to false, so no instantaneous Volumetric process will be performed" | tee -a ${logJob}
fi

#-----------------------------------------
# Running the instantaneous CylindricalVel analysis
if [ "${readMeans}" = "true" ]; then
   #The rps done in CylindricalVel
   echo "Reading rpDoneCylindricalVelFile:" | tee -a ${logJob}
   rpDoneCylindricalVelFile=${baseDir}/${workingDir}/postProcessing/pythonFiles/CylindricalVel/doneCylindricalVel.txt
   echo $rpDoneCylindricalVelFile | tee -a ${logJob}
   doneCylindricalVelArray[0]=9999
   ii=1
   if [ -f "${rpDoneCylindricalVelFile}" ]
   then
      ii=0
      while read -r line
      do
         doneCylindricalVelArray[$ii]=$line
         ii=$(( $ii + 1 ))
      done < $rpDoneCylindricalVelFile
   else
      echo "rpDoneCylindricalVelFile does not exist. Starting CylindricalVel mean process from scratch." | tee -a ${logJob}
   fi
   NDoneCylindricalVel=${#doneCylindricalVelArray[@]}

   #The process cycle
   for ((ii=0; ii<${Nrps}; ii++));
   do
      rpAnalysis=${rpArray[$ii]}
      echo "Analysing CylindricalVel rp=${rpAnalysis}" | tee -a ${logJob}
      goForIt=true
      for ((jj=0; jj<${NDoneCylindricalVel}; jj++));
      do
         existingRp=${doneCylindricalVelArray[$jj]}
         if float_cond "$existingRp == $rpAnalysis"; then
            goForIt=false
            echo "The CylindricalVel rp=${rpAnalysis} was already processed fully" | tee -a ${logJob}
         fi
      done
      if [ "${goForIt}" = "true" ]; then
         if [ "$useDependantCycle" = "true" ]; then
            if [ "$localDependantSent" = "false" ]; then
               echo "Sending also the dependant job: ${dependantScript}" | tee -a ${logJob}
               sbatch --dependency=afterany:${SLURM_JOB_ID} $dependantScript
               localDependantSent=true
            fi
         else
            echo "useDependantCycle=false, therefore NOT SENDING the dependant script" | tee -a ${logJob}
         fi
         echo "Obtaining the CylindricalVel analysis for the available times" | tee -a ${logJob}
         tiempo0=$(($(date +%s%N)/1000000))
         date | tee -a ${logJob}
         $piton $pythonDir/ArrayCapture/CylindricalVelocities/CylindricalVel.py $rpAnalysis $arrayDensity Normal $PWD > "${logRun}_CylindricalVel_${rpAnalysis}" 2>&1
         pyResult=$?
         date | tee -a ${logJob}
         tiempo1=$(($(date +%s%N)/1000000))
         deltaT=$(float_eval "(${tiempo1} - ${tiempo0})/1000.0")
         echo "The python script exited with pyResult=${pyResult}"  | tee -a ${logJob}
         echo "Time used was: ${deltaT} seconds" | tee -a ${logJob}
         if [ $pyResult -eq 0 ]; then
            echo $rpAnalysis >> $rpDoneCylindricalVelFile
         fi
      fi
   done
else
   echo "readMeans is set to false, so no Mean CylindricalVel process will be performed" | tee -a ${logJob}
fi



#-----------------------------------------
# End
echo "Volumetric Python Analysis Finished" | tee -a ${logJob}
exit 0
