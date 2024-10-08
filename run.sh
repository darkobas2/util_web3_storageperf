#!/bin/bash

LOGFILE="logfile.log"

{
  echo "Starting script execution at $(date)"
  python3 app.py --upload --repeat 1 --size 1
  python3 app.py --upload --repeat 1 --size 10
  python3 app.py --upload --repeat 1 --size 100
  python3 app.py --upload --repeat 1 --size 1000
  python3 app.py --upload --repeat 1 --size 10000
  #python3 app.py --upload --repeat 1 --size 50000
  sleep 900
  python3 app.py --download --repeat 30
  echo "all runs completed $(date)"
} 2>&1 | tee -a "$LOGFILE"
