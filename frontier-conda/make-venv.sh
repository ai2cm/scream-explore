#!/bin/bash
COMMIT=$1
ENV_PREFIX=$2
ENVIRONMENT_PATH=$ENV_PREFIX/$COMMIT
SCRATCH=/lustre/orion/cli115/scratch/$USER

if [ -e "$ENVIRONMENT_PATH/bin/python" ]; then
    echo "$ENVIRONMENT_PATH exists, reusing the env."
else
    rm -rf $SCRATCH/ace-slurm-env/temp/
    mkdir -p $SCRATCH/ace-slurm-env/temp/
    cd $SCRATCH/ace-slurm-env/temp/
    git clone https://github.com/ai2cm/full-model.git
    if [ $? -ne 0 ]; then
        echo "Failed to clone repository https://github.com/ai2cm/full-model.git"
        exit 1
    fi

    cd $SCRATCH/ace-slurm-env/temp/full-model
    git checkout "$COMMIT"
    if [ $? -ne 0 ]; then
        echo "Failed to checkout commit: $COMMIT"
        exit 1
    fi

    # Assume the user has conda in their path (there is no common conda module on Ursa).
    echo "Creating environment at $ENVIRONMENT_PATH"
    conda create -p $ENVIRONMENT_PATH python=3.11 pip -y
    conda run --no-capture-output -p $ENVIRONMENT_PATH python -m pip --no-cache-dir install uv==0.2.5
    conda run --no-capture-output -p $ENVIRONMENT_PATH uv --no-cache pip install -c constraints.txt .
    conda run --no-capture-output -p $ENVIRONMENT_PATH uv --no-cache pip -y uninstall torch
    conda run --no-capture-output -p $ENVIRONMENT_PATH uv --no-cache pip install torch==2.7.1 --index-url https://download.pytorch.org/whl/rocm6.2.4
    rm -rf $SCRATCH/ace-slurm-env/temp/full-model
fi

echo $ENVIRONMENT_PATH
