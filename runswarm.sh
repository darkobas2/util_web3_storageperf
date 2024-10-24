#!/bin/bash

LOGFILE="logfile.log"

{
  echo "Starting script execution at $(date)"
  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 0 --only-swarm
  sleep 10m
  python3 app.py --download --repeat 1 --dl-retrieval 30000 --dl-redundancy 0 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 10m
  python3 app.py --download --repeat 1 --dl-retrieval 500 --dl-redundancy 3 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 10m
  python3 app.py --download --repeat 1 --dl-retrieval 5000 --dl-redundancy 3 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 10m
  python3 app.py --download --repeat 1 --dl-retrieval 30000 --dl-redundancy 3 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 10m
  python3 app.py --download --repeat 1 --dl-retrieval 5000 --dl-redundancy 1 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 1 --only-swarm
  sleep 10m
  python3 app.py --download --repeat 1 --dl-retrieval 30000 --dl-redundancy 0 --only-swarm
  rm references_onlyswarm.json


  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 2 --only-swarm
  sleep 10m
  python3 app.py --download --repeat 1 --dl-retrieval 500 --dl-redundancy 2 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 2 --only-swarm
  sleep 10m
  python3 app.py --download --repeat 1 --dl-retrieval 5000 --dl-redundancy 2 --only-swarm
  rm references_onlyswarm.json

  python3 app.py --upload --repeat 5 --size 100000 --ul-redundancy 2 --only-swarm
  sleep 10m
  python3 app.py --download --repeat 1 --dl-retrieval 30000 --dl-redundancy 2 --only-swarm
  rm references_onlyswarm.json

  echo "all runs completed $(date)"
} 2>&1 | tee -a "$LOGFILE"
