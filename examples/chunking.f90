module chunking_example
contains

  subroutine chunking(arr, chunk_size)
    integer, dimension(:), intent(inout) :: arr
    integer, intent(in) :: chunk_size
    integer :: i, n

    n = size(arr)
    do i = 1, n, chunk_size
      call sub(arr(i:i+chunk_size-1))
    end do
  end subroutine

  pure subroutine sub(a)
    integer, intent(inout) :: a(:)
  end subroutine

end module
