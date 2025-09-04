#!/bin/bash -l

#SBATCH --job-name=train-ace
#SBATCH -t 00:30:00
#SBATCH -N 2
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-task=1
#SBATCH --gpu-bind=closest
#SBATCH --cpus-per-task=7
#SBATCH -p batch
#SBATCH -A CLI115
#SBATCH --output=stdout/%x.%j.out
#SBATCH --signal=USR1@60
#SBATCH --requeue
#SBATCH --open-mode=append

set -xe

FME_VENV=$1
TRAIN_CONFIG=$2
FRONTIER_CONDA_DIR=$3
SCRATCH=$4
WANDB_AND_BEAKER_NAME=$5
WANDB_USERNAME=$6
FME_OUTPUT_DIR=$7
OVERRIDE="${@:8}"

OVERRIDE="${OVERRIDE} experiment_dir=${FME_OUTPUT_DIR}"

# During the first segment, archive scripts and config needed to run the
# job. This ensures that they stay consistent throughout job requeues,
# and do not get lost, e.g. if we switch branches in the full-model
# repo where we launch experiments from.
JOB_CONFIG_DIR=$FME_OUTPUT_DIR/job_config
ARCHIVED_CONFIG=$JOB_CONFIG_DIR/archived_config.yaml
if [ ! -d $JOB_CONFIG_DIR ]; then
    mkdir $JOB_CONFIG_DIR
    cp $TRAIN_CONFIG $ARCHIVED_CONFIG
    cp $FRONTIER_CONDA_DIR/run-train-frontier.sh $JOB_CONFIG_DIR
    cp $FRONTIER_CONDA_DIR/make-venv.sh $JOB_CONFIG_DIR
    cp $FRONTIER_CONDA_DIR/sbatch-scripts/requeueable-train.sh $JOB_CONFIG_DIR
    cp $FRONTIER_CONDA_DIR/sbatch-scripts/sbatch-train.sh $JOB_CONFIG_DIR
    cp $FRONTIER_CONDA_DIR/sbatch-scripts/wandb-sync.sh $JOB_CONFIG_DIR
    cp $FRONTIER_CONDA_DIR/sbatch-scripts/beaker-upload.sh $JOB_CONFIG_DIR
fi

preempt_handler()
{
    #place here: commands to run when preempt signal (SIGTERM) arrives from slurm
    kill -TERM ${1} #forward SIGTERM signal to the user application
    #if --requeue was used, slurm will automatically do so here
}
timeout_handler()
{
    kill -TERM ${1}
    scontrol requeue ${SLURM_JOB_ID}
}

srun -u $JOB_CONFIG_DIR/requeueable-train.sh \
     $FME_VENV \
     $FME_OUTPUT_DIR \
     $ARCHIVED_CONFIG \
     $WANDB_AND_BEAKER_NAME \
     $WANDB_USERNAME \
     $SCRATCH \
     $OVERRIDE

    
pid=$!
trap "preempt_handler '$pid'" SIGTERM #this catches preempt SIGTERM from slurm
trap "timeout_handler '$pid'" USR1 # this catches timeout USR1 from slurm
wait
sleep 120

