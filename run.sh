#!/bin/bash

LOGFILE="logfile.log"

{
  echo "Starting script execution at $(date)"
  python3 app.py --upload --repeat 2 --size 100000
  python3 app.py --upload --repeat 3 --size 50000
  python3 app.py --upload --repeat 4 --size 10000
  python3 app.py --upload --repeat 5 --size 1000
  python3 app.py --upload --repeat 5 --size 100
} 2>&1 | tee -a "$LOGFILE"
