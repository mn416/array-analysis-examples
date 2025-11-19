# Script to see which loops in a file are parallelisable

import os
from psyclone.psyir.transformations import OMPLoopTrans, TransformationError
from psyclone.psyir.nodes import Loop, Routine
from psyclone.psyir.tools.array_index_analysis import (
    ArrayIndexAnalysis, ArrayIndexAnalysisOptions)

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
  bv_width = int(os.getenv("BITVEC_WIDTH", "32"))
  use_int = os.getenv("USE_INTEGERS", "no")
  use_bitvec = os.getenv("USE_BITVEC", "no")
  no_overflow = os.getenv("PROHIBIT_OVERFLOW", "no")
  handle_array_intrins = os.getenv("HANDLE_ARRAY_INTRINS", "no")

  num_routines = 0
  num_loops = []
  routine_names = []
  for routine in psyir.walk(Routine):
    num_routines = num_routines + 1
    num_loops.append(len(routine.walk(Loop)))
    routine_names.append(routine.name)

  for r in range(0, num_routines):
    print("Routine ", Colour.OKBLUE,
                      routine_names[r], Colour.ENDC, ": ", sep="")
    for i in range(0, num_loops[r]):
      ir = psyir.copy()
      routine = ir.walk(Routine)[r]
      loop = routine.walk(Loop)[i]
    
      print("  Loop ",
            Colour.OKBLUE, loop.variable.name, Colour.ENDC,
            ": ", sep="", end="", flush=True)
      try:
        if use_smt == "yes":
          use_bv = None
          if use_int == "yes":
            use_bv = False
          elif use_bitvec == "yes":
            use_bv = True
          anal_opts = ArrayIndexAnalysisOptions(
            bv_width, use_bv, timeout, no_overflow == "yes",
            handle_array_intrins == "yes")
          OMPLoopTrans(omp_directive="paralleldo").apply(
            loop, use_smt_array_index_analysis=anal_opts)
        else:
          OMPLoopTrans(omp_directive="paralleldo").apply(loop)
        print(Colour.OKGREEN + "conflict free" + Colour.ENDC)
      except TransformationError as err:
        print(Colour.FAIL + "conflicts" + Colour.ENDC)
