module chunking_example
contains

  subroutine chunking(arr, chunk_size)
    integer, dimension(:), intent(inout) :: arr
    integer, intent(in) :: chunk_size
    integer :: n, chunk_begin, chunk_end

    n = size(arr)
    do chunk_begin = 1, n, chunk_size
      chunk_end = min(chunk_begin+chunk_size-1, n)
      call modify(arr(chunk_begin:chunk_end))
    end do
  end subroutine

  pure subroutine modify(a)
    integer, intent(inout) :: a(:)
  end subroutine

end module
