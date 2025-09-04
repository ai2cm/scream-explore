#!/bin/bash

FME_VENV=$1
FME_OUTPUT_DIR=$2

# Note that it is apparently very important to pass the wandb directory
# as a relative path, so we change to the FME_OUTPUT_DIR first. If we
# do not do this WandB does not detect any data to sync.
cd $FME_OUTPUT_DIR
conda run --prefix $FME_VENV wandb sync --sync-all --append wandb
