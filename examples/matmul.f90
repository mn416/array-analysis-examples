subroutine my_matmul(a, b, c)
  integer, dimension(:,:), intent(in) :: a
  integer, dimension(:,:), intent(in) :: b
  integer, dimension(:,:), intent(out) :: c
  integer :: x, y, k, k_tile, x_tile, y_tile

  c(:,:) = 0
  do y_tile = 1, size(a, 2), 8
    do x_tile = 1, size(b, 1), 8
      do k_tile = 1, size(a, 1), 8
        do y = y_tile, min(y_tile + (8 - 1), size(a, 2)), 1
          do x = x_tile, min(x_tile + (8 - 1), size(b, 1)), 1
            do k = k_tile, min(k_tile + (8 - 1), size(a, 1)), 1
              c(x,y) = c(x,y) + a(k,y) * b(x,k)
            enddo
          enddo
        enddo
      enddo
    enddo
  enddo
end subroutine my_matmul

