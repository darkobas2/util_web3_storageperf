#!/bin/bash

LOGFILE="logfile.log"

{
  echo "Starting script execution at $(date)"
  python3 app.py --upload --repeat 1 --size 100
  python3 app.py --upload --repeat 1 --size 1000
  python3 app.py --upload --repeat 1 --size 10000
  python3 app.py --upload --repeat 1 --size 50000
  python3 app.py --upload --repeat 1 --size 100000
} 2>&1 | tee -a "$LOGFILE"
