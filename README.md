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

Note that, as there are multiple references to the size of the array, it is
important to capture the size once via the statement `n = size(arr)` rather
than write `size(arr)` multiple times. This is because the analysis currently
doesn't have any special knowledge of the `size` intrinsic (it assumes it could
return anything, and not necessarily the same thing each time). To prove that
there are no conflicts in this example, the analysis only requires that each
reference to the array size is the same, which can be achieved using the
assignment statement.

(In future, we could use SMT _uninterpreted functions_ to model intrinsics such
as `size`. An uninterpreted function can return any value but must return the
same value each time. We might also constrain the return value to be greater
than or equal to zero, if the Fortran standard does indeed guarantee that.)

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
  integer :: x, y, k, k_out_var, x_out_var, y_out_var, a1_n, a2_n, b1_n

  a2_n = size(a, 2)
  b1_n = size(b, 1)
  a1_n = size(a, 1)

  c(:,:) = 0
  do y_out_var = 1, a2_n, 8
    do x_out_var = 1, b1_n, 8
      do k_out_var = 1, a1_n, 8
        do y = y_out_var, min(y_out_var + (8 - 1), a2_n), 1
          do x = x_out_var, min(x_out_var + (8 - 1), b1_n), 1
            do k = k_out_var, min(k_out_var + (8 - 1), a1_n), 1
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

When developing this example, my expectation was that both loops would be
parallelisable, but the analysis reports:

```
Routine: flatten
  Loop y: conflicts
  Loop x: conflict free
```

After some thought, it is apparant that the outer loop does indeed contain a
conflict if integers wrap around due to integer overflow. However, as integer
overflow is undefined behaviour in Fortran, it is reasonable for the analysis
to ignore it. This can be done using one of two approaches. In the first
approach, we tell the analysis to model Fortran integers as
arbitrary-precision integers rather than 32-bit vectors:

```
$ USE_INTEGERS=yes psyclone -s analyse.py -o /dev/null examples/flatten.f90
Routine: flatten
  Loop y: conflict free
  Loop x: conflict free
```

Success!

In the second approach, we stick with the use of bit vectors but prohibit
overflow:

```
$ PROHIBIT_OVERFLOW=yes psyclone -s analyse.py -o /dev/null examples/flatten.f90
Routine: flatten
  Loop y: timeout
  Loop x: conflict free
```

Unfortunately, this approach leads to a solver timeout for the outer loop.
Although somewhat unsatisfactory, the solver does succeed if we tell the
analysis to model Fortran integers as 8 bits instead of 32:

```
INTEGER_WIDTH=8 PROHIBIT_OVERFLOW=yes psyclone -s analyse.py -o /dev/null examples/flatten.f90
Routine: flatten
  Loop y: conflict free
  Loop x: conflict free
```

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
non-conflicting.  The arthmetic to compute a partner pairs is quite complex,
involving `+`, `-`, `*`, `/`, `mod` and `min`, but the analysis can handle it:

```f90
psyclone -s analyse.py -o /dev/null examples/oem_sort.f90 
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
psyclone -s analyse.py -o /dev/null examples/bitonic_sort.f90        
Routine: bitonic_sort
  Loop log_k: conflicts
  Loop log_j: conflicts
  Loop i: conflict free
```

## Example 8: Array Chunking

Handling tiled/chunked loops was one of the motivations for this work, so it is
worth exploring this area in more detail. Unlike in the `matmul.f90` example,
the chunk size in [chunking.f90](examples/chunking.f90) is not statically
known:

```f90
subroutine chunking(arr, chunk_size)
  integer, dimension(:), intent(inout) :: arr
  integer, intent(in) :: chunk_size
  integer :: i, n

  n = size(arr)
  do i = 1, n, chunk_size
    arr(i:i+chunk_size-1) = 0
  end do
end subroutine
```

Unfortunately, the default analysis times out on this example:

```
psyclone -s analyse.py -o /dev/null examples/chunking.f90 
Routine: chunking
  Loop i: timeout
```

However, the arbitrary-precision-integer solver succeeds:

```
USE_INTEGERS=yes psyclone -s analyse.py -o /dev/null examples/chunking.f90 
Routine: chunking
  Loop i: conflict free
```

The situation is similar when using run-time chunk size in
[matmul.f90](examples/matmul.f90): the bit-vector solver fails but the integer
solver succeeds.

## Result Summary

The following table summaraises the different analysis options for each
example.  We use "yes" to mean that the solver succeeds in finding all the
non-conflicting loops, and a blank box to mean that it doesn't. The `-oflow`
tag means "integer overflow is probibited".

|                  | 32 bit | Integer | 32 bit, -oflow | 8 bit, -oflow |
| ---              | ---    | ---     | ---            | ---           |
| `reverse`        | yes    | yes     | yes            | yes           |
| `odd_even_trans` | yes    | yes     | yes            | yes           |
| `matmul`         | yes    | yes     | yes            | yes           |
| `flatten`        |        | yes     |                | yes           |
| `gauss_jordan`   | yes    | yes     | yes            | yes           |
| `oem_sort`       | yes    |         | yes            | yes           |
| `bitonic_sort`   | yes    |         | yes            | yes           |
| `chunking`       |        | yes     |                | yes           |

It is pleasing that each example can be handled either by the integer solver or
by the 32-bit bit-vector solver.

The following table shows how the existing PSyclone loop analysis fares on the
same examples.

| Routine          | Finds all parallelisable loops? |
| ---              | ---                             |
| `reverse`        | no                              |
| `odd_even_trans` | no                              |
| `matmul`         | no                              |
| `flatten`        | no                              |
| `gauss_jordan`   | no                              |
| `oem_sort`       | no                              |
| `bitonic_sort`   | no                              |
| `chunking`       | no                              |
