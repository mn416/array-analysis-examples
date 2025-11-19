module scalar_array_conflict
  implicit none

  type :: Box
    integer :: arr(10)
  end type
contains
  subroutine main()
    type(Box) :: b
    integer :: i

    do i = 1, size(b%arr)
      b%arr(i) = i
      call modify(b)
    end do
  end subroutine

  pure subroutine modify(b)
    type(Box), intent(inout) :: b
    b%arr(1) = 0
  end subroutine
end module

subroutine non_injective_index(arr)
  integer, intent(inout) :: arr(:)
  integer :: i

  do i = 1, size(arr)
    arr(i/2) = 0
  end do
end subroutine
