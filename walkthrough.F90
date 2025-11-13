! Array Index Analysis
! ====================

!   * Problem: determine if a given loop contains array access
!     conflicts between iterations

!   * Formulates problem as a constraint satisfaction problem
!     and passes it an external solver / theorem prover (Z3)

! Matrix Transposition
! ====================

subroutine my_transpose(m_in, m_out)
  real, dimension(:,:), intent(in) :: m_in
  real, dimension(:,:), intent(out) :: m_out
  integer :: width, height, x, y

  width = size(m_in, 1)
  height = size(m_in, 2)

  do y = 1, height
    do x = 1, width
      m_out(x,y) = m_in(y,x)
    enddo
  enddo
end subroutine my_transpose

! Tiled Matrix Transposition
! ==========================

subroutine my_transpose(m_in, m_out)
  real, dimension(:,:), intent(in) :: m_in
  real, dimension(:,:), intent(out) :: m_out
  integer :: width, height, x, y, x_tile, y_tile

  width = size(m_in, 1)
  height = size(m_in, 2)

  do y_tile = 1, height, 32
    do x_tile = 1, width, 32
      do y = y_tile, min(y_tile + (32 - 1), height), 1
        do x = x_tile, min(x_tile + (32 - 1), width), 1
          m_out(x,y) = m_in(y,x)
        enddo
      enddo
    enddo
  enddo
end subroutine my_transpose

! Parallel performance on 10Kx10K matrix:
!   * Untiled: 0.2996s
!   * Tiled:   0.0445s

! Tiled Matrix Multiplication
! ===========================

subroutine my_matmul(a, b, c)
  integer, dimension(:,:), intent(in) :: a
  integer, dimension(:,:), intent(in) :: b
  integer, dimension(:,:), intent(out) :: c
  integer :: x, y, k, k_tile, x_tile, y_tile, a1_n, a2_n, b1_n

  a2_n = size(a, 2)
  b1_n = size(b, 1)
  a1_n = size(a, 1)

  c(:,:) = 0
  do y_tile = 1, a2_n, 8
    do x_tile = 1, b1_n, 8
      do k_tile = 1, a1_n, 8
        do y = y_tile, min(y_tile + (8 - 1), a2_n), 1
          do x = x_tile, min(x_tile + (8 - 1), b1_n), 1
            do k = k_tile, min(k_tile + (8 - 1), a1_n), 1
              c(x,y) = c(x,y) + a(k,y) * b(x,k)
            enddo
          enddo
        enddo
      enddo
    enddo
  enddo
end subroutine my_matmul

! Parallel performance on 1500^2 matrix:
!   * Untiled: 3.291s
!   * Tiled:   0.306s

! UKCA-Style Chunking
! ===================

! Assume that subroutine "sub" is pure and may write to its args

subroutine chunking(arr, chunk_size)
  integer, dimension(:), intent(inout) :: arr
  integer, intent(in) :: chunk_size
  integer :: i, n

  n = size(arr)
  do i = 1, n, chunk_size
    call sub(arr(i:min(n, i+chunk_size-1)))
  end do
end subroutine

! Array Reversal
! ==============

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

! Odd/Even Transposition
! ======================

subroutine odd_even_transposition(arr, start)
  integer , intent(inout) :: arr(:)
  integer, intent(in) :: start
  integer :: i, tmp
  do i = start, size(arr)-1, 2
    if (arr(i) > arr(i+1)) then
      tmp = arr(i+1)
      arr(i+1) = arr(i)
      arr(i) = tmp
    end if
  end do
end subroutine

! Array Flattening
! ================

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

! Gauss/Jordan Method
! ===================

! Code from: https://www.numericalmethods.in/pages/sle/02gaussJordan.html
subroutine gauss_jordan(a, n)
  real, intent(inout) :: a(:,:)
  integer, intent(in) :: n
  integer :: i, j, k
  real :: ratio
  do k = 1, n
    do i = 1, n  ! Is this loop parallelisable?
      if (i /= k) then
        ratio = a(i,k) / a(k,k)
        do j=1,n+1
          a(i,j) = a(i,j) - a(k,j)*ratio
        end do
      end if
    end do
  end do
end subroutine

! Bitonic Sorter
! ==============

! Code ported to Fortran from: https://sortvisualizer.com/bitonicsort/
subroutine bitonic_sort(arr, log_n)
  integer, intent(inout) :: arr(0:)
  integer, intent(in) :: log_n
  integer :: i, j, k, l, log_j, log_k, tmp
  do log_k = 1, log_n
    k = shiftl(1, log_k)
    do log_j = log_k-1, 0, -1
      j = shiftl(1, log_j)
      do i = 0, shiftl(1, log_n) - 1 ! This loop should be parallelisable
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

! Further Reading
! ===============

! How it works:
!   * https://github.com/stfc/PSyclone/pull/3213
!
! Full discussion of examples:
!   * https://github.com/mn416/array-analysis-examples
