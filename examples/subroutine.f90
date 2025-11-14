module subroutine_example
contains
  subroutine main()
    integer :: i
    real :: re_m(10)
    real :: im_m(10)
    do i = 1, 10
      call sub(re_m(i), im_m(i))
    end do
  end subroutine

  pure subroutine sub(a, b)
    real, intent(inout) :: a
    real, intent(inout) :: b
  end subroutine
end module
