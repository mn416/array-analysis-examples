# Script to explore existing PSyclone loop analysis

from psyclone.psyir.transformations import OMPLoopTrans
from psyclone.psyir.nodes import Loop, Routine

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
  for routine in psyir.walk(Routine):
    print("Routine: ", Colour.OKBLUE, routine.name, Colour.ENDC, sep="")
    num_loops = len(routine.walk(Loop))
    for i in range(0, num_loops):
        loop = routine.copy().walk(Loop)[i]
        print("  Loop ",
              Colour.OKBLUE, loop.variable.name, Colour.ENDC,
              ": ", sep="", end="", flush=True)
        try:
            OMPLoopTrans(omp_directive="paralleldo").apply(loop)
            print(Colour.OKGREEN + "conflict free" + Colour.ENDC)
        except:
            print(Colour.FAIL + "conflicts" + Colour.ENDC)
