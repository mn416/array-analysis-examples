subroutine my_transpose(m_in, m_out)
  real, dimension(:,:), intent(in) :: m_in
  real, dimension(:,:), intent(out) :: m_out
  integer :: x, y, x_out_var, y_out_var, m2_n, m1_n

  m2_n = SIZE(m_in, 2)
  m1_n = SIZE(m_in, 1)

  do y_out_var = 1, m2_n, 32
    do x_out_var = 1, m1_n, 32
      do y = y_out_var, MIN(y_out_var + (32 - 1), m2_n), 1
        do x = x_out_var, MIN(x_out_var + (32 - 1), m1_n), 1
          m_out(y,x) = m_in(x,y)
        enddo
      enddo
    enddo
  enddo

end subroutine my_transpose

subroutine my_transpose2(m_in, m_out)
  real, dimension(:,:), intent(in) :: m_in
  real, dimension(:,:), intent(out) :: m_out
  integer :: y

  do y = 1, size(m_in, 2)
    m_out(y,:) = m_in(:,y)
  end do
end subroutine my_transpose2
