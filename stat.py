#!/usr/bin/env python3

import argparse
from perflib import Task
from time import time

def to_bool(s):
  if s == '1': return True
  if s == '0': return False
  raise Exception("cannot convert %s to bool."% s)


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='Run experiments')
  parser.add_argument('-t', '--time', type=int, default=1000, help="measurement time (in _seconds_!)")
  parser.add_argument('-i', '--interval', type=int, default=100, help="interval between measurements in seconds")
  parser.add_argument('--host', type=to_bool, default=True, help="measure host events")
  parser.add_argument('--guest', type=to_bool, default=True, help="measure guest events")
  parser.add_argument('-p', '--pid', type=int, required=True, help="PID of the process")
  parser.add_argument('-d', '--debug', default=False, const=True, action='store_const', help='enable debug mode')
  args = parser.parse_args()
  print("config:", args)



  task = Task(args.pid, args.host, args.guest)
  start = time()
  while (time() - start) < args.time:
    r = task.measure(args.interval)
    print(r)
    ipc = r[0]/r[1]
    print("IPC: {:.3f}".format(ipc))
