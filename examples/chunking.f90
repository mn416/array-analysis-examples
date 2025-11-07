subroutine chunking(arr, chunk_size)
  integer, dimension(:), intent(inout) :: arr
  integer, intent(in) :: chunk_size
  integer :: i, n

  n = size(arr)
  do i = 1, n, chunk_size
    arr(i:i+chunk_size-1) = 0
  end do
end subroutine
