import os
from psyclone.psyir.nodes import Loop, Routine
from psyclone.psyir.tools.array_index_analysis import ArrayIndexAnalysis

class Colour:
  HEADER = '\033[95m'
  OKBLUE = '\033[94m'
  OKCYAN = '\033[96m'
  OKGREEN = '\033[92m'
  WARNING = '\033[93m'
  FAIL = '\033[91m'
  ENDC = '\033[0m'
  BOLD = '\033[1m'
  UNDERLINE = '\033[4m'

def trans(psyir):
  timeout = int(os.getenv("TIMEOUT", "10000"))
  int_width = int(os.getenv("INTEGER_WIDTH", "32"))
  use_int = os.getenv("USE_INTEGERS", "no")
  no_overflow = os.getenv("PROHIBIT_OVERFLOW", "no")
  for routine in psyir.walk(Routine):
    print("Routine: ", Colour.OKBLUE, routine.name, Colour.ENDC, sep="")
    for loop in routine.walk(Loop):
      print("  Loop ",
            Colour.OKBLUE, loop.variable.name, Colour.ENDC,
            ": ", sep="", end="", flush=True)
      options = ArrayIndexAnalysis.Options(
                  int_width = int_width,
                  use_bv = not (use_int == "yes"),
                  smt_timeout_ms = timeout,
                  prohibit_overflow = no_overflow == "yes")
      conflict_free = ArrayIndexAnalysis(options).is_loop_conflict_free(loop)
      if conflict_free is None:
        print(Colour.FAIL + "timeout" + Colour.ENDC)
      elif conflict_free:
        print(Colour.OKGREEN + "conflict free" + Colour.ENDC)
      else:
        print(Colour.FAIL + "conflicts" + Colour.ENDC)
