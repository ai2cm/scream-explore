#!/bin/bash

set -x

FME_VENV=$1
TRAIN_CONFIG=$2
FRONTIER_CONDA_DIR=$3
SCRATCH=$4
WANDB_NAME=$5
WANDB_USERNAME=$6
OVERRIDE="${@:7}"

JOB_ID="$(date +%F)-$(uuidgen | sed 's/.*\(.....\)$/\1/')"
# directory for saving output from training/inference job
if [ -z "${RESUME_JOB_ID}" ]; then
  FME_OUTPUT_DIR=${SCRATCH}/fme-output/${JOB_ID}
else
  FME_OUTPUT_DIR=${SCRATCH}/fme-output/${RESUME_JOB_ID}
fi
mkdir -p $FME_OUTPUT_DIR

sbatch $FRONTIER_CONDA_DIR/sbatch-scripts/sbatch-train.sh \
       $FME_VENV \
       $TRAIN_CONFIG \
       $FRONTIER_CONDA_DIR \
       $SCRATCH \
       $WANDB_NAME \
       $WANDB_USERNAME \
       $FME_OUTPUT_DIR \
       $OVERRIDE

echo "$FME_OUTPUT_DIR/job_config/sbatch-scripts/wandb-sync.sh $FME_VENV $FME_OUTPUT_DIR" > "post_run_$JOB_ID.sh"
echo "$FME_OUTPUT_DIR/job_config/sbatch-scripts/beaker-upload.sh $WANDB_NAME $FME_OUTPUT_DIR" >> "post_run_$JOB_ID.sh"
