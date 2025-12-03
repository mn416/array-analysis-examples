import os
import time
from psyclone.psyir.nodes import Loop, Routine
from psyclone.psyir.tools.array_index_analysis import (
  ArrayIndexAnalysis, ArrayIndexAnalysisOptions)
from psyclone.psyir.tools.dependency_tools import (DependencyTools)

RESOLVE_IMPORTS = True

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
  use_dep_tools = os.getenv("USE_DEP_TOOLS", "no")
  timeout = int(os.getenv("TIMEOUT", "5000"))
  bv_width = int(os.getenv("BITVEC_WIDTH", "32"))
  use_int = os.getenv("USE_INTEGERS", "no")
  use_bitvec = os.getenv("USE_BITVEC", "no")
  no_overflow = os.getenv("PROHIBIT_OVERFLOW", "yes")

  use_bv = None
  if use_int == "yes":
    use_bv = False
  elif use_bitvec == "yes":
    use_bv = True

  for routine in psyir.walk(Routine):
    print("Routine: ", Colour.OKBLUE, routine.name, Colour.ENDC, sep="")
    for loop in routine.walk(Loop):
      print("  Loop ",
            Colour.OKBLUE, loop.variable.name, Colour.ENDC,
            ": ", sep="", end="", flush=True)
      options = ArrayIndexAnalysisOptions(
                  int_width = bv_width,
                  use_bv = use_bv,
                  smt_timeout_ms = timeout,
                  prohibit_overflow = no_overflow == "yes")
      analysis = ArrayIndexAnalysis(options)
      dep_tools = DependencyTools()
      try:
        start = time.time()
        if use_dep_tools == "yes":
            conflict_free = dep_tools.can_loop_be_parallelised(
                               loop, test_all_variables=True)
        else:
            conflict_free = analysis.is_loop_conflict_free(loop)
        end = time.time()
        if conflict_free is None:
          print(Colour.FAIL + "timeout" + Colour.ENDC, end="")
        elif conflict_free:
          print(Colour.OKGREEN + "conflict free" + Colour.ENDC, end="")
        else:
          print(Colour.FAIL + "conflicts" + Colour.ENDC, end="")
        print(" (%.3f" % (end-start), "s)", sep="")
      except Exception:
        print(Colour.FAIL + " exception" + Colour.ENDC)
