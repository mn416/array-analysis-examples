# Script to explore existing PSyclone loop analysis

import os
from psyclone.psyir.transformations import OMPLoopTrans, TransformationError
from psyclone.psyir.nodes import Loop, Routine
from psyclone.psyir.tools.array_index_analysis import ArrayIndexAnalysis

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
  use_smt = os.getenv("USE_SMT", "no")
  timeout = int(os.getenv("TIMEOUT", "10000"))
  int_width = int(os.getenv("INTEGER_WIDTH", "32"))
  use_int = os.getenv("USE_INTEGERS", "no")
  no_overflow = os.getenv("PROHIBIT_OVERFLOW", "no")
  for routine in psyir.walk(Routine):
    print("Routine: ", Colour.OKBLUE, routine.name, Colour.ENDC, sep="")
    num_loops = len(routine.walk(Loop))
    for i in range(0, num_loops):
        loop = routine.copy().walk(Loop)[i]
        print("  Loop ",
              Colour.OKBLUE, loop.variable.name, Colour.ENDC,
              ": ", sep="", end="", flush=True)
        try:
            if use_smt == "yes":
              anal_opts = ArrayIndexAnalysis.Options(
                int_width, use_int == "no", timeout, no_overflow == "yes")
              OMPLoopTrans(omp_directive="paralleldo").apply(
                loop, use_smt_array_anal=True,
                smt_array_anal_options=anal_opts)
            else:
              OMPLoopTrans(omp_directive="paralleldo").apply(loop)
            print(Colour.OKGREEN + "conflict free" + Colour.ENDC)
        except TransformationError as err:
            print(Colour.FAIL + "conflicts" + Colour.ENDC)
            #print(err)
