# ArrayIndexAnalysis Examples

This repo contains examples demonstrating our SMT-based ArrayIndexAnalysis for PSyclone.  The analysis itself is defined in
[array_index_analysis.py](https://github.com/stfc/PSyclone/blob/mn416-smt-array-index-analysis/src/psyclone/psyir/tools/array_index_analysis.py),
which contains a fairly detailed description in the comments.

## Getting started

Recursively clone the PSyclone branch containing the analysis:

```
$ git clone --recursive \
            -b mn416-smt-array-index-analysis \
            https://github.com/stfc/PSyclone
```

Apply a patch to the fparser submodule to support Fortran 2008 bit-shifting
intrinsics, which are useful in some of the examples:

```
$ (cd PSyclone/external/fparser/ && git apply ../../../fparser.patch)
```

Enter a docker shell providing all the necessary dependencies:

```
$ ./docker-shell.sh
```

## Example 1: Array Reversal

The [reverse.f90](examples/reverse.f90) example contains the following code.

```f90
subroutine reverse(arr)
  integer, intent(inout) :: arr(:)
  integer :: i, n, tmp
  n = size(arr)
  do i = 1, n/2
    tmp = arr(i)
    arr(i) = arr(n+1-i)
    arr(n+1-i) = tmp
  end do
end subroutine
```

Each iteration `i` writes to elements `i` and `n+1-i` at opposite ends of the
array but `i` never passes the midpoint `n/2`, hence the loop is conflict free
(with respect to array accesses).

The program can be analysed with the command

```
$ psyclone -s analyse.py -o /dev/null examples/reverse.f90
```

which yields the following output.

```
Routine: reverse
  Loop i: conflict free
```

If we change the upper bound of `i` from `n/2` to `n` we get:

```
Routine: reverse
  Loop i: conflicts
```

## Example 2: Knuth's Odd/Even Transposition

The routine in [odd_even_trans.f90](examples/odd_even_trans.f90), from Knuth's
Odd/Even Transposition Sorter, is as follows.

```f90
subroutine odd_even_transposition(arr, start)
  integer , intent(inout) :: arr(:)
  integer, intent(in) :: start
  integer :: i, tmp
  do i = start, size(arr), 2
    if (arr(i) > arr(i+1)) then
      tmp = arr(i+1)
      arr(i+1) = arr(i)
      arr(i) = tmp
    end if
  end do
end subroutine
```

It swaps adjacent array elements from a given starting point, but the loop has
a step size of 2 making it conflict free.

The analysis gives:

```
Routine: odd_even_transposition
  Loop i: conflict free
```

## Example 3: Tiled Matrix Multiplication

The routine in [matmul.f90](examples/matmul.f90) is an implementation of matrix multplication that has been tiled using PSyclone's `LoopTilingTrans`.

```f90
subroutine my_matmul(a, b, c)
  integer, dimension(:,:), intent(in) :: a
  integer, dimension(:,:), intent(in) :: b
  integer, dimension(:,:), intent(out) :: c
  integer :: x, y, k, k_tile, x_tile, y_tile

  c(:,:) = 0
  do y_tile = 1, size(a, 2), 8
    do x_tile = 1, size(b, 1), 8
      do k_tile = 1, size(a, 1), 8
        do y = y_tile, min(y_tile + (8 - 1), size(a, 2)), 1
          do x = x_tile, min(x_tile + (8 - 1), size(b, 1)), 1
            do k = k_tile, min(k_tile + (8 - 1), size(a, 1)), 1
              c(x,y) = c(x,y) + a(k,y) * b(x,k)
            enddo
          enddo
        enddo
      enddo
    enddo
  enddo
end subroutine my_matmul
```

Unfortunately, after tiling, PSyclone is unable to detect the loops that can be
parallelised. It gives the error:

> Error: The write access to 'c(x,y)' and the read access to 'c(x,y)' are
> dependent and cannot be parallelised.

Handling this example was one of the main motivations for our analysis, which
gives the following output.

```
Routine: my_matmul
  Loop y_out_var: conflict free
  Loop x_out_var: conflict free
  Loop k_out_var: conflicts
  Loop y: conflict free
  Loop x: conflict free
  Loop k: conflicts
```

## Example 4: Array Flattening

The [flatten.f90](examples/flatten.f90) example contains the following
routine.

```f90
subroutine flatten(mat, arr)
  real, intent(in) :: mat(0:,0:)
  real, intent(out) :: arr(0:)
  integer :: x, y
  integer :: nx, ny
  nx = size(mat, 1)
  ny = size(mat, 2)
  do y = 0, ny-1
    do x = 0, nx-1
      arr(nx * y + x) = mat(x, y)
    end do
  end do
end subroutine
```

The analysis reports:

```
Routine: flatten
  Loop y: conflict free
  Loop x: conflict free
```

Note that loop `y` can actually conflict in practice, if integer overflow
leads to wrap-around. However, integer overflow is undefined behaviour in
Fortran, so the analysis ignore its.

## Example 5: Gauss/Jordan Method

The routine in [gauss_jordan.f90](examples/gauss_jordan.f90) is taken from a
[tutorial on numerical
methods](https://www.numericalmethods.in/pages/sle/02gaussJordan.html).

```f90
subroutine gauss_jordan(a, n)
  real, intent(inout) :: a(:,:)
  integer, intent(in) :: n
  integer :: i, j, k
  real :: ratio
  do k = 1, n
    do i = 1, n
      if (i /= k) then
        ratio = a(i,k) / a(k,k)
        do j=1,n+1
          a(i,j) = a(i,j) - a(k,j)*ratio
        end do
      end if
    end do
  end do
end subroutine
```

The interesting question here is whether the `i` loop is parallelisable. Each
iteration writes `a(i,j)` (for all `j`) and reads `a(k,j)` (for all `j` and a
fixed `k`) but, due to the `if` condition `i /= k`, these accesses are
non-overlapping.  The analysis knows this:

```
$ psyclone -s analyse.py -o /dev/null examples/gauss_jordan.f90
Routine: gauss_jordan
  Loop k: conflicts
  Loop i: conflict free
  Loop j: conflict free
```

## Example 6: Batcher's Odd/Even Merge Sort

As a more complex example,
[oem_sort.f90](examples/oem_sort.f90) contains Batcher's
Odd/Even Merge Sort transcribed to Fortran from [Wikepedia's
Pseudocode](https://en.wikipedia.org/wiki/Batcher_odd%E2%80%93even_mergesort).

```f90
subroutine odd_even_merge_sort(arr, log_n)
  integer, intent(inout) :: arr(0:)
  integer, intent(in) :: log_n
  integer :: p, k, j, i, idx1, idx2, log_p, log_k, tmp, n

  n = shiftl(1, log_n)
  do log_p = 0, log_n-1
    p = shiftl(1, log_p)
    do log_k = log_p, 0, -1
      k = shiftl(1, log_k)
      do j = mod(k, p), n-1-k, 2*k
        do i = 0, min(k-1, n-j-k-1)
          idx1 = i+j
          idx2 = i+j+k
          if (idx1 / (p*2) == idx2 / (p*2)) then
            if (arr(idx1) > arr(idx2)) then
              tmp = arr(idx1)
              arr(idx1) = arr(idx2)
              arr(idx2) = tmp
            end if
          end if
        end do
      end do
    end do
  end do
end subroutine
```

Inside the `j` loop, each array element `idx1` is considered for swapping with
its partner element `idx2`.  The partner pairs are unique and hence
non-conflicting.  The arthmetic to compute a partner pairs is quite complex
but the analysis can handle it:

```f90
$ psyclone -s analyse.py -o /dev/null examples/oem_sort.f90 
Routine: odd_even_merge_sort
  Loop log_p: conflicts
  Loop log_k: conflicts
  Loop j: conflict free
  Loop i: conflict free
```

## Example 7: Batcher's Bitonic Sort

The routine in [bitonic_sort.f90](examples/bitonic_sort.f90) is similar to the above example and has been ported to Fortran from C code in a
[tutorial on sorting](https://sortvisualizer.com/bitonicsort/).

```f90
subroutine bitonic_sort(arr, log_n)
  integer, intent(inout) :: arr(0:)
  integer, intent(in) :: log_n
  integer :: i, j, k, l, log_j, log_k, tmp
  do log_k = 1, log_n
    k = shiftl(1, log_k)
    do log_j = log_k-1, 0, -1
      j = shiftl(1, log_j)
      do i = 0, shiftl(1, log_n) - 1
        l = ieor(i, j)
        if (l > i) then
          if ((iand(i, k) == 0 .and. arr(i) > arr(l)) .or.   &
              (iand(i, k) /= 0 .and. arr(i) < arr(l))) then
            tmp = arr(i)
            arr(i) = arr(l)
            arr(l) = tmp
          end if
        end if
      end do
    end do
  end do
end subroutine
```

The analysis can also handle this example:

```
$ psyclone -s analyse.py -o /dev/null examples/bitonic_sort.f90        
Routine: bitonic_sort
  Loop log_k: conflicts
  Loop log_j: conflicts
  Loop i: conflict free
```

## Example 8: Parallel Prefix

The following routine computes the parallel prefix sum of an array.

```f90
subroutine parallel_prefix_sum(arr, chunk_size)
  integer, intent(inout) :: arr(0:)
  integer, intent(in) :: chunk_size
  integer :: inc_by(0:chunk_size-1)
  integer :: n, chunk_begin, chunk_end, chunk_id, i, acc

  n = size(arr)
  do chunk_begin = 0, n-1, chunk_size
    chunk_end = min(chunk_begin + chunk_size - 1, n-1)
    acc = 0
    do i = chunk_begin, chunk_end
      acc = acc + arr(i)
      arr(i) = acc
    end do
  end do

  acc = 0
  do chunk_begin = 0, n-1, chunk_size
    chunk_end = min(chunk_begin + chunk_size - 1, n-1)
    chunk_id = chunk_begin / chunk_size
    inc_by(chunk_id) = acc
    acc = acc + arr(chunk_end)
  end do

  do chunk_begin = chunk_size, n-1, chunk_size
    chunk_end = min(chunk_begin + chunk_size - 1, n-1)
    chunk_id = chunk_begin / chunk_size
    do i = chunk_begin, chunk_end
      arr(i) = arr(i) + inc_by(chunk_id)
    end do
  end do
end subroutine
```

The idea is to set `chunk_size` to the number of available threads, and to
parallelise the first and final `chunk_begin` loops, which the analysis finds
are conflict free:

```
$ psyclone -s analyse.py -o /dev/null examples/parallel_prefix.f90 
Routine: parallel_prefix_sum
  Loop chunk_begin: conflict free
  Loop i: conflict free
  Loop chunk_begin: conflict free
  Loop chunk_begin: conflict free
  Loop i: conflict free
```

Note that `analyse.py` only considers array accesses.  The first `i` loop and
the first `chunk_begin` loop both contain scalar conflicts, which are handled
by the existing `DependencyTools`. We can use `parallelise.py` instead of
`analyse.py` to explore `DependencyTools` and `ArrayIndexAnalysis` in
combination:

```
$ USE_SMT=yes psyclone -s parallelise.py -o /dev/null examples/parallel_prefix.f90
Routine parallel_prefix_sum: 
  Loop chunk_begin: conflict free
  Loop i: conflicts
  Loop chunk_begin: conflicts
  Loop chunk_begin: conflict free
  Loop i: conflict free
```

## Example 9: Array Chunking

Handling tiled/chunked loops was one of the motivations for this work, so it is
worth exploring this area in more detail. Unlike in the `matmul.f90` example,
the chunk size in [chunking.f90](examples/chunking.f90) is not statically
known:

```f90
module chunking_example
contains
  subroutine chunking(arr, chunk_size)
    integer, dimension(:), intent(inout) :: arr
    integer, intent(in) :: chunk_size
    integer :: i, n

    n = size(arr)
    do i = 1, n, chunk_size
      call modify(arr(i:i+chunk_size-1))
    end do
  end subroutine

  pure subroutine modify(a)
    integer, intent(inout) :: a(:)
  end subroutine
end module
```

In this example, the `i` loop passes a different slice to the pure `modify`
routine on eac iteration, and is conflict free:

```
$ psyclone -s analyse.py -o /dev/null examples/chunking.f90 
Routine: chunking
  Loop i: conflict free
```

If we change the call to `modify` to

```f90
call modify(arr(i:i+chunk_size))
```

then the slices become overlapping between iterations, and the analysis
reports a conflict.

## Result Summary

All of the above examples contain one or more parallelisable loops that
existing analysis does not parallelise.

The `ArrayIndexAnalysis` can run in various modes:

  * `Integer`: Fortran integers are interepreted as arbitrary precision
    integers by the SMT solver.

  * `32 Bit`: Fortran integers are interepreted as 32-bit bit vectors
     by the solver, and bit-vector overflow is explicitly ignored.

  * `8 Bit`: Fortran integers are interepreted as 8-bit bit vectors
     by the solver, and bit-vector overflow is explicitly ignored.

  * `Default`: same as `Integer` mode unless the routine enclosing the loop
    uses bit vector operations (shift/bitwise intrinsics), in which case it
    is the same as `32 Bit` mode.

The following table summarises the results of the `ArrayIndexAnalysis` in the
various modes. We use "yes" to mean that the solver succeeds in finding all
the non-conflicting loops, and a blank box to mean that it doesn't.

|                   | Default | Integer | 32 Bit | 8 Bit |
| ---               | ---     | ---     | ---    | ---   |
| `reverse`         | yes     | yes     | yes    | yes   |
| `odd_even_trans`  | yes     | yes     | yes    | yes   |
| `matmul`          | yes     | yes     | yes    | yes   |
| `flatten`         | yes     | yes     |        | yes   |
| `gauss_jordan`    | yes     | yes     | yes    | yes   |
| `oem_sort`        | yes     |         | yes    | yes   |
| `bitonic_sort`    | yes     |         | yes    | yes   |
| `parallel_prefix` | yes     | yes     |        | yes   |
| `chunking`        | yes     | yes     |        | yes   |

In addition to these examples, there are a number of simple examples in
[simple.f90](examples/simple.f90) in which the existing analysis fails but
`ArrayIndexAnalysis` succeeds:

```
$ USE_SMT=yes psyclone -s parallelise.py -o /dev/null examples/simple.f90
Routine copy_array: 
  Loop i: conflict free
Routine injective_index: 
  Loop i: conflict free
Routine double_inner_loop: 
  Loop i: conflict free
  Loop j: conflict free
  Loop k: conflict free
Routine last_iteration: 
  Loop i: conflict free
Routine invariant_if: 
  Loop i: conflict free
Routine one_elem_slice: 
  Loop i: conflict free
Routine extend_array: 
  Loop i: conflict free
Routine main: 
  Loop i: conflict free
Routine modify: 
Routine main: 
  Loop i: conflict free
Routine modify: 
Routine triangular_loop: 
  Loop i: conflicts
  Loop j: conflict free
```

Finally, [beware.f90](examples/beware.f90) contains some examples that
illustrate bugs in the existing `DepdendencyTools` analysis. These have been
reported on the PSyclone issue tracker.
