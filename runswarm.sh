#!/bin/bash

LOGFILE="logfile.log"

{
  echo "Starting script execution at $(date)"
  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 0 --only-swarm
  sleep 5m
  python3 app.py --download --repeat 1 --dl-retrieval 30000ms --dl-redundancy 0 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 5m
  python3 app.py --download --repeat 1 --dl-retrieval 1000ms --dl-redundancy 3 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 5m
  python3 app.py --download --repeat 1 --dl-retrieval 5000ms --dl-redundancy 3 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 5m
  python3 app.py --download --repeat 1 --dl-retrieval 30000ms --dl-redundancy 3 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 5m
  python3 app.py --download --repeat 1 --dl-retrieval 1000ms --dl-redundancy 1 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 5m
  python3 app.py --download --repeat 1 --dl-retrieval 5000ms --dl-redundancy 1 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 5m
  python3 app.py --download --repeat 1 --dl-retrieval 30000ms --dl-redundancy 1 --only-swarm
  rm references_onlyswarm.json

  mv results_onlyswarm.json data/results_onlyswarm_$(date +%F_%H-%M).json
  echo "all runs completed $(date)"
} 2>&1 | tee -a "$LOGFILE"
