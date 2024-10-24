#!/bin/bash

LOGFILE="logfile.log"

{
  echo "Starting script execution at $(date)"
  python3 app.py --upload --repeat 10 --size 1 --ul-redundancy 0 --only-swarm
  python3 app.py --upload --repeat 10 --size 1 --ul-redundancy 1 --only-swarm
  python3 app.py --upload --repeat 10 --size 1 --ul-redundancy 2 --only-swarm
  python3 app.py --upload --repeat 10 --size 1 --ul-redundancy 3 --only-swarm
  python3 app.py --upload --repeat 10 --size 1 --ul-redundancy 4 --only-swarm
  python3 app.py --upload --repeat 10 --size 10 --ul-redundancy 0 --only-swarm
  python3 app.py --upload --repeat 10 --size 10 --ul-redundancy 1 --only-swarm
  python3 app.py --upload --repeat 10 --size 10 --ul-redundancy 2 --only-swarm
  python3 app.py --upload --repeat 10 --size 10 --ul-redundancy 3 --only-swarm
  python3 app.py --upload --repeat 10 --size 10 --ul-redundancy 4 --only-swarm
  python3 app.py --upload --repeat 10 --size 100 --ul-redundancy 0 --only-swarm
  python3 app.py --upload --repeat 10 --size 100 --ul-redundancy 1 --only-swarm
  python3 app.py --upload --repeat 10 --size 100 --ul-redundancy 2 --only-swarm
  python3 app.py --upload --repeat 10 --size 100 --ul-redundancy 3 --only-swarm
  python3 app.py --upload --repeat 10 --size 100 --ul-redundancy 4 --only-swarm
  python3 app.py --upload --repeat 10 --size 1000 --ul-redundancy 0 --only-swarm
  python3 app.py --upload --repeat 10 --size 1000 --ul-redundancy 1 --only-swarm
  python3 app.py --upload --repeat 10 --size 1000 --ul-redundancy 2 --only-swarm
  python3 app.py --upload --repeat 10 --size 1000 --ul-redundancy 3 --only-swarm
  python3 app.py --upload --repeat 10 --size 1000 --ul-redundancy 4 --only-swarm
  python3 app.py --upload --repeat 10 --size 10000 --ul-redundancy 0 --only-swarm
  python3 app.py --upload --repeat 10 --size 10000 --ul-redundancy 1 --only-swarm
  python3 app.py --upload --repeat 10 --size 10000 --ul-redundancy 2 --only-swarm
  python3 app.py --upload --repeat 10 --size 10000 --ul-redundancy 3 --only-swarm
  python3 app.py --upload --repeat 10 --size 10000 --ul-redundancy 4 --only-swarm
  #python3 app.py --upload --repeat 1 --size 50000
  echo "started sleep $(date)"
  sleep 2h
  echo "ended sleep $(date)"
  python3 app.py --download --repeat 1 --dl-retrieval 500 --only-swarm
  echo "all runs completed $(date)"
} 2>&1 | tee -a "$LOGFILE"
