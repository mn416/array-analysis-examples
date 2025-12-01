subroutine my_transpose(m_in, m_out, chunk_size)
  real, dimension(:,:), intent(in) :: m_in
  real, dimension(:,:), intent(out) :: m_out
  integer, intent(in) :: chunk_size
  integer :: x, y, x_tile, y_tile

  do y_tile = 1, size(m_in, 2), chunk_size
    do x_tile = 1, size(m_in, 1), chunk_size
      do y = y_tile, min(y_tile + (chunk_size - 1), size(m_in, 2)), 1
        do x = x_tile, min(x_tile + (chunk_size - 1), size(m_in, 1)), 1
          m_out(x,y) = m_in(y,x)
        enddo
      enddo
    enddo
  enddo
end subroutine my_transpose
