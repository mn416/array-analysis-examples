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
