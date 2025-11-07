subroutine my_matmul(a, b, c)
  integer, dimension(:,:), intent(in) :: a
  integer, dimension(:,:), intent(in) :: b
  integer, dimension(:,:), intent(out) :: c
  integer :: x, y, k, k_out_var, x_out_var, y_out_var, a1_n, a2_n, b1_n

  a2_n = size(a, 2)
  b1_n = size(b, 1)
  a1_n = size(a, 1)

  c(:,:) = 0
  do y_out_var = 1, a2_n, 8
    do x_out_var = 1, b1_n, 8
      do k_out_var = 1, a1_n, 8
        do y = y_out_var, min(y_out_var + (8 - 1), a2_n), 1
          do x = x_out_var, min(x_out_var + (8 - 1), b1_n), 1
            do k = k_out_var, min(k_out_var + (8 - 1), a1_n), 1
              c(x,y) = c(x,y) + a(k,y) * b(x,k)
            enddo
          enddo
        enddo
      enddo
    enddo
  enddo
end subroutine my_matmul

