# Script to explore existing PSyclone loop analysis

from psyclone.psyir.transformations import OMPLoopTrans
from psyclone.psyir.nodes import Loop

def trans(psyir):
  num_loops = len(psyir.walk(Loop))
  for i in range(0, num_loops):
      loop = psyir.copy().walk(Loop)[i]
      print(loop.variable.name + ": ", end="")
      try:
          OMPLoopTrans(omp_directive="paralleldo").apply(loop)
          print("conflict free")
      except:
          print("conflicts")
