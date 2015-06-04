from libc.stdint cimport int64_t, uint32_t, uint64_t
from posix.unistd cimport pid_t, useconds_t, read, usleep
from posix.ioctl cimport ioctl
from libc.signal cimport SIGCONT, SIGSTOP
from cython cimport sizeof, bool

DEF DEBUG = True

cdef extern from "errno.h":
  int errno

cdef extern from "signal.h" nogil:
  int kill(pid_t pid, int sig) except -1


cdef extern from "linux/perf_event.h":
  cdef struct perf_event_attr:
    uint32_t type
    uint32_t size
    uint64_t config
    int      inherit
    int      disabled
    int      exclude_host
    int      exclude_guest
    uint64_t read_format

  cdef enum perf_type_id:
    PERF_TYPE_HARDWARE
    PERF_COUNT_HW_INSTRUCTIONS
    PERF_COUNT_HW_CPU_CYCLES
  cdef int PERF_EVENT_IOC_RESET
  cdef int PERF_FORMAT_GROUP
  cdef int PERF_IOC_FLAG_GROUP
  cdef int PERF_FORMAT_TOTAL_TIME_ENABLED
  cdef int PERF_FORMAT_TOTAL_TIME_RUNNING
  cdef int PERF_EVENT_IOC_ENABLE
  cdef int PERF_FLAG_FD_CLOEXEC


cdef extern from "_perf.h":
  void* mymalloc(size_t size)
  int perf_event_open(perf_event_attr *event, pid_t pid,
                  int cpu, int group_fd, unsigned long flags) #except -1


cdef struct Result:
  uint64_t nr
  uint64_t time_enabled
  uint64_t time_running
  uint64_t instr
  uint64_t cycles


cdef class Task:
  cdef int cpu, exclude_host, exclude_guest
  cdef int ifd, cfd
  cdef pid_t pid

  def __repr__(self):
    return "Task(pid=%s, cpu={cpu}, exclude_host={excl_host}, exclude_guest={excl_guest})" \
           .format(pid=self.pid, cpu=self.cpu, excl_host=self.exclude_host, excl_guest=self.exclude_guest)

  def __cinit__(self, pid_t pid=-1, int cpu=-1, int exclude_host=0, int exclude_guest=0):
    cdef int pe_size
    cdef perf_event_attr *pe

    kill(pid, 0)
    self.pid = pid
    self.cpu = cpu
    self.exclude_host = exclude_host
    self.exclude_guest = exclude_guest

    pe_size = sizeof(perf_event_attr)
    pe = <perf_event_attr*>mymalloc(pe_size)

    pe.size = pe_size
    pe.type = PERF_TYPE_HARDWARE
    pe.disabled = 1
    #pe.inherit = 1
    pe.read_format = PERF_FORMAT_GROUP | PERF_FORMAT_TOTAL_TIME_ENABLED | PERF_FORMAT_TOTAL_TIME_RUNNING
    pe.config = PERF_COUNT_HW_INSTRUCTIONS
    pe.exclude_host = exclude_host
    pe.exclude_guest = exclude_guest

    flags = PERF_FLAG_FD_CLOEXEC

    IF DEBUG:
      print("CFG: cpu: {cpu}, exclude_guest: {}, exclude_host: {}".format(exclude_guest, exclude_host, cpu=cpu))

    self.ifd = perf_event_open(pe, pid, cpu, -1, flags)
    if self.ifd == -1:
      raise Exception("cannot open instructions counter: err {}".format(errno))

    # cycles counter
    pe.config = PERF_COUNT_HW_CPU_CYCLES
    self.cfd = perf_event_open(pe, pid, cpu, self.ifd, flags)
    if self.cfd == -1:
      raise Exception("cannot open cycles counter: err {}".format(errno))

    # enable events
    r = ioctl(self.ifd, PERF_EVENT_IOC_ENABLE, PERF_IOC_FLAG_GROUP)
    assert r != -1, "ioctl PERF_EVENT_IOC_ENABLE failed"

  cpdef measure(self, int interval):
    cdef Result cnts
    cdef int r

    # reset counters before reading
    r = ioctl(self.ifd, PERF_EVENT_IOC_RESET, PERF_IOC_FLAG_GROUP)
    assert r != -1, "ioctl PERF_EVENT_IOC_RESET failed"
    # let it work fork a while
    usleep(<useconds_t>(interval*(10**3)))  # convert milliseconds to microseconds
    # read and parse
    r = read(self.ifd, &cnts, sizeof(cnts))
    assert r == sizeof(cnts)
    if not cnts.time_running == cnts.time_enabled:
      raise Exception("time_running {} != time_enabled {}".format(cnts.time_running, cnts.time_enabled))
    if not cnts.time_enabled:
      print("<not counted>")
      return (0,0)
    #print("enabled time:", cnts.time_running/cnts.time_enabled)
    return (cnts.instr, cnts.cycles)

  cpdef measurex(self, int interval, int num):
    return [self.measure(interval) for _ in range(num)]

  def freeze(self, tasks):
    for t in tasks:
      if t == self: continue
      t.stop()

  def defrost(self, tasks):
    for t in tasks:
      t.cont()

  cpdef stop(self):
    kill(self.pid, SIGSTOP)

  cpdef cont(self):
    kill(self.pid, SIGCONT)
