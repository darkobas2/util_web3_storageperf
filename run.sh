#!/bin/bash

LOGFILE="logfile.log"
source ~/bin/activate
{
  echo "Starting script execution at $(date)"
  python3 app.py --upload --repeat 30 --size 1
  python3 app.py --upload --repeat 30 --size 10
  python3 app.py --upload --repeat 30 --size 100
  python3 app.py --upload --repeat 30 --size 1000
  python3 app.py --upload --repeat 30 --size 10000
  python3 app.py --upload --repeat 30 --size 100000
  echo "started sleep $(date)"
  sleep 10m
  echo "ended sleep $(date)"
  python3 app.py --download --repeat 1
  echo "all runs completed $(date)"
} 2>&1 | tee -a "$LOGFILE"
