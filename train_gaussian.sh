#!/bin/bash

cd 4DGaussians
python train.py \
    -s ../sample_data/bouncingballs \
    --port 6017 \
    --expname "dnerf/bouncingballs" \
    --configs arguments/dnerf/bouncingballs.py \