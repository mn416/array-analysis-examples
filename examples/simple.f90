subroutine copy_array(dest, src)
  integer, dimension(:), intent(out) :: dest
  integer, dimension(:), intent(in) :: src
  integer :: i, idx

  do i = 1, size(dest)
    idx = i
    dest(idx) = src(idx)
  end do
end subroutine

subroutine injective_index(arr, n)
  integer, dimension(:), intent(inout) :: arr
  integer, intent(in) :: n
  integer :: i, idx

  do i = 1, n
    idx = i+1
    arr(idx) = 0
  end do
end subroutine

subroutine double_inner_loop(arr)
  integer, dimension(:,:), intent(inout) :: arr
  integer :: i, j, k

  do i = 1, size(arr, 2), 1
    do j = 1, size(arr, 1), 1
        arr(j,i) = 0
    enddo
    do k = 1, size(arr, 1), 1
        arr(k,i) = arr(k,i) + 1
    enddo
  enddo
end subroutine

subroutine last_iteration(arr)
  integer, dimension(:), intent(inout) :: arr
  integer :: i, n

  n = size(arr)
  do i = 1, n-1
    arr(i) = 0
    if (i == n-1) then
      arr(i+1) = 10
    end if
  end do
end subroutine

subroutine invariant_if(arr, mode)
  integer, intent(inout) :: arr(:)
  integer, intent(in) :: mode
  integer :: i

  do i = 1, size(arr)-1
    if (mode >= 0) then
      arr(i) = 1
    else
      arr(i+1) = 2
    end if
  end do
end subroutine

subroutine one_elem_slice(arr)
  integer :: arr(:)
  integer :: i
  do i = 1, size(arr)
    arr(i:i) = i
  end do
end subroutine

subroutine extend_array(arr)
  integer, intent(inout) :: arr(:)
  integer :: i, n

  do i = 1, n
    arr(i+n) = arr(i)
  end do
end subroutine

module sub_modify_array_elem
contains
  subroutine main()
    integer :: i
    real :: re_m(10)
    real :: im_m(10)
    do i = 1, 10
      call modify(re_m(i), im_m(i))
    end do
  end subroutine

  pure subroutine modify(a, b)
    real, intent(inout) :: a
    real, intent(inout) :: b
  end subroutine
end module

module sub_modify_array_slice
contains
  subroutine main(n, low, high)
    integer, intent(in) :: n, low, high
    integer :: i
    real :: arr(n,n)
    do i = 1, n
      call modify(arr(low:high, i))
    end do
  end subroutine

  pure subroutine modify(a)
    real, intent(inout) :: a(:,:)
  end subroutine
end module

subroutine triangular_loop(arr)
  integer, intent(inout) :: arr(:)
  integer :: n, i, j

  n = size(arr)
  do i = 1, n-1
    do j = i+1, n
      arr(j) = arr(j) + arr(i)
    end do
  end do
end subroutine
