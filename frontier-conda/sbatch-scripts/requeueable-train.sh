#!/bin/bash

set -x

FME_VENV=$1
FME_OUTPUT_DIR=$2
TRAIN_CONFIG=$3
WANDB_NAME=$4
WANDB_USERNAME=$5
SCRATCH=$6
OVERRIDE="${@:7}"

# this will manually requeue the job and is called if a timeout signal is received
# see https://docs.nersc.gov/jobs/examples/#preemptible-jobs
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

PERSISTENT_CACHE_DIR=$SCRATCH/my-miopen-cache
LOCAL_CACHE_DIR="$TMPDIR/miopen-cache-$USER-$SLURM_JOB_ID"
if [ "$SLURM_LOCALID" -eq 0 ]; then
  mkdir -p "$PERSISTENT_CACHE_DIR"
  mkdir -p "$LOCAL_CACHE_DIR"
  if [ -d "$PERSISTENT_CACHE_DIR" ]; then
    cp -r "$PERSISTENT_CACHE_DIR/" "$LOCAL_CACHE_DIR/"
  fi
fi
sleep 2
export MIOPEN_USER_DB_PATH=$LOCAL_CACHE_DIR
export MIOPEN_CUSTOM_CACHE_DIR=$LOCAL_CACHE_DIR

export RANK=$SLURM_PROCID
export WORLD_SIZE=$SLURM_NTASKS
export LOCAL_RANK=$SLURM_LOCALID
export NCCL_SOCKET_IFNAME=hsn0
export FME_USE_SRUN=1
mkdir -p ${SCRATCH}/.fme_srun
export SRUN_DIST_FILE_PATH="${SCRATCH}/.fme_srun/${SLURM_JOB_ID}_rendezvous"

export WANDB_NOTES="Results on Frontier: $FME_OUTPUT_DIR"
export WANDB_JOB_TYPE=training
export WANDB_MODE=offline
export WANDB_NAME=$WANDB_NAME
export WANDB_USERNAME=$WANDB_USERNAME

exec $FME_VENV/bin/python -m fme.ace.train ${TRAIN_CONFIG} --override $OVERRIDE &

pid=$!
trap "preempt_handler '$pid'" SIGTERM #this catches preempt SIGTERM from slurm
trap "timeout_handler '$pid'" USR1 # this catches timeout USR1 from slurm
wait

if [ "$SLURM_LOCALID" -eq 0 ]; then
  cp -r "$LOCAL_CACHE_DIR/" "$PERSISTENT_CACHE_DIR/"
fi

sleep 120

