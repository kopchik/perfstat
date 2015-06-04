#!/usr/bin/env python3

import argparse
from perfstat import Perf
from time import time

def to_bool(s):
  if s == '1': return True
  if s == '0': return False
  raise Exception("cannot convert %s to bool."% s)


if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='Run experiments')
  parser.add_argument('-t', '--time', type=int, default=1000, help="measurement time (in _seconds_!)")
  parser.add_argument('-i', '--interval', type=int, default=100, help="interval between measurements in seconds")
  parser.add_argument('--exclude_host', type=to_bool, default=False, help="measure host events")
  parser.add_argument('--exclude_guest', type=to_bool, default=False, help="measure guest events")
  parser.add_argument('-p', '--pid', type=int, default=-1, help="PID of the process")
  parser.add_argument('-c', '--cpu', type=int, default=-1, help="CPU to monitor")
  parser.add_argument('-d', '--debug', default=False, const=True, action='store_const', help='enable debug mode')
  args = parser.parse_args()
  print("config:", args)



  perf = Perf(pid=args.pid,
              cpu=args.cpu,
              exclude_host=args.exclude_host,
              exclude_guest=args.exclude_guest)
  start = time()
  while (time() - start) < args.time:
    r = perf.measure(args.interval)
    if not r[0] or not r[1]:
      print("missing datapoint")
      continue
    # print(r)
    ipc = r[0]/r[1]
    print("Instructions: {ins}\nCycles: {c}\nIPC: {ipc:.3f}".format(ins=r[0], c=r[1], ipc=ipc))
