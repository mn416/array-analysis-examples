! Code ported to Fortran from: https://sortvisualizer.com/bitonicsort/
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
