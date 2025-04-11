#!/bin/bash

LOGFILE="logfile.log"
mkdir references

{
  echo "Starting script execution at $(date)"
  python3 app.py --upload --repeat 30 --size 100000 --ul-redundancy 0 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 0 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_0_0_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10000 --ul-redundancy 0 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 0 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_0_0_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1000 --ul-redundancy 0 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 0 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_0_0_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 100 --ul-redundancy 0 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 0 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_0_0_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10 --ul-redundancy 0 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 0 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_0_0_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1 --ul-redundancy 0 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 0 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_0_0_$(date +%F_%H-%M).json

  python3 app.py --upload --repeat 30 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10000 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1000 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 100 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_1_$(date +%F_%H-%M).json

  python3 app.py --upload --repeat 30 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10000 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1000 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 100 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1 --ul-redundancy 1 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_1_3_$(date +%F_%H-%M).json

  python3 app.py --upload --repeat 30 --size 100000 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10000 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1000 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 100 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_1_$(date +%F_%H-%M).json

  python3 app.py --upload --repeat 30 --size 100000 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10000 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1000 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 100 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1 --ul-redundancy 2 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_2_3_$(date +%F_%H-%M).json

  python3 app.py --upload --repeat 30 --size 100000 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10000 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1000 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 100 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_1_$(date +%F_%H-%M).json

  python3 app.py --upload --repeat 30 --size 100000 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10000 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1000 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 100 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1 --ul-redundancy 3 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_3_3_$(date +%F_%H-%M).json

  python3 app.py --upload --repeat 30 --size 100000 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10000 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1000 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 100 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_1_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 1 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_1_$(date +%F_%H-%M).json

  python3 app.py --upload --repeat 30 --size 100000 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10000 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1000 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 100 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 10 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_3_$(date +%F_%H-%M).json
  python3 app.py --upload --repeat 30 --size 1 --ul-redundancy 4 --only-swarm
  sleep 15m
  python3 app.py --download --repeat 1 --dl-redundancy 3 --only-swarm
  mv references_onlyswarm.json references/references_onlyswarm_4_3_$(date +%F_%H-%M).json

  echo "all runs completed $(date)"
} 2>&1 | tee -a "$LOGFILE"
