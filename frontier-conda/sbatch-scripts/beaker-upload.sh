#!/bin/bash

# This script requires that both beaker and yq are site installed:
# beaker: https://beaker-docs.apps.allenai.org/start/install.html
# yq: https://github.com/mikefarah/yq?tab=readme-ov-file#install

BEAKER_NAME=$1
FME_OUTPUT_DIR=$2

# Ensure that we upload all but the wandb/ directory as a beaker dataset.
# The wandb/ directory contains many files, which is not efficient for
# beaker, and is already synced with WandB proper.
temp_dir=$(mktemp -d)
paths=$(ls -d $FME_OUTPUT_DIR/*)
for path in $paths
do
    if [[ $(basename $path) != "wandb" ]]; then
	cp -r $path $temp_dir/
    fi
done

CONFIG=$FME_OUTPUT_DIR/job_config/archived_config.yaml
WANDB_ENTITY=$(yq .logging.entity $CONFIG)
WANDB_PROJECT=$(yq .logging.project $CONFIG)
WANDB_ID=$(cat $FME_OUTPUT_DIR/wandb_run_id)
DESCRIPTION="https://wandb.ai/${WANDB_ENTITY}/${WANDB_PROJECT}/runs/${WANDB_ID}"
beaker dataset create \
       --name $BEAKER_NAME \
       --desc $DESCRIPTION \
       --workspace ai2/ace \
       $temp_dir

rm -rf $temp_dir
