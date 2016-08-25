! $Id$
!
! This method will contain (more or less) a replica of poisson.f90, which is a module linked to the 
! pencil code for computing  potential from density. It will implement the version of poisson
! equation solving that I have been building (the method outlined in Clement Baruteau's thesis).
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lpoisson=.true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************
module Poisson
!
  use Cdata
  use Cparam
  use Fourier
  use Messages
  use General, only: keep_compiler_quiet,linspace,meshgrid
!
  implicit none
!
  include 'poisson.h'
!
  real :: Gnewton=1.0 !Newton's constant of gravity=1 in these units
!
  namelist /poisson_init_pars/ Gnewton
!
  namelist /poisson_run_pars/ Gnewton
!
  logical :: luse_fourier_transform = .false.
!
! Variables to be used
!      
  real :: innerRadius
  real :: outerRadius
  real :: uMax
  real :: phiMin
  real :: phiMax
  real :: du,dphi
  real, dimension(2*nx,ny) :: u2d,phi2d,sigma,sr,sphi,sv,kr,kphi,kv,gr,gphi
  real, dimension(nx,ny) :: r
  real :: B,B2
!
contains
!***********************************************************************
    subroutine initialize_poisson()
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  18-oct-07/anders: adapted
!
      if (nzgrid/=1) then
        if (lroot) print*, 'inverse_laplacian_fft: logspirals only works with nzgrid==1'
        call fatal_error('inverse_laplacian_fft','')
      endif
!
!  Dimensionality
!
      call decide_fourier_routine()
!
! Mask values from elsewhere
!
      innerRadius=xyz0(1)
      outerRadius=xyz1(1)
      uMax=log(outerRadius/innerRadius)
      phiMin=xyz0(2)
      phiMax=xyz1(2)
!
!  Coordinates u,phi (Fourier grid) and r,x,y (physical grid) are generated
!
      call generate_coordinates()
!
!  Kernals for each integral (gr,gphi,V)
!
      call generate_kernals()
!
    endsubroutine initialize_poisson
!***********************************************************************
    subroutine inverse_laplacian(phi,gpotself)
!
!  Dispatch solving the Poisson equation to inverse_laplacian_fft
!  or inverse_laplacian_semispectral, based on the boundary conditions
!
!  17-jul-2007/wolf: coded wrapper
!
      real, dimension(nx,ny,nz), intent(inout) :: phi
      real, dimension(nx,ny,nz), intent(inout), optional :: gpotself
!
      if (lcylindrical_coords) then
!
        if (present(gpotself)) then 
          call inverse_laplacian_logradial_fft(phi,gpotself)
        else
          call fatal_error("inverse_laplacian","poisson_logspirals works with the acceleration only")
        endif
!
      else if (lspherical_coords) then
         if (lroot) then
          print*,'There is no poisson solver for spherical '
          print*,'coordinates yet. Please feel free to implement it. '
          print*,'Many people will thank you for that.'
          call fatal_error("inverse_laplacian","")
        endif
      else if (lcartesian_coords) then
        if (lroot) then
          print*,'Use poisson.f90 or other poisson solver for cartesian coordinates '
          call fatal_error("inverse_laplacian","")
        endif
      endif
!
    endsubroutine inverse_laplacian
!***********************************************************************
    subroutine inverse_laplacian_semispectral(phi)
!
!  dummy subroutine
!      
!  19-dec-2006/anders: coded
!
      real, dimension (nx,ny,nz) :: phi
!
      call keep_compiler_quiet(phi)
!
    endsubroutine inverse_laplacian_semispectral
!***********************************************************************
    subroutine decide_fourier_routine
!
! Decide, based on the dimensionality and on the geometry
! of the grid, which fourier transform routine is to be
! used. "fourier_transform" and "fourier_tranform_shear"
! are functional only without x-parallelization, and for
! cubic, 2D square, and 1D domains only. Everything else
! should use fft_parallel instead.
!
! 05-dec-2011/wlad: coded
!
      logical :: lxpresent,lypresent,lzpresent
      logical :: l3D,l2Dxy,l2Dyz,l2Dxz
      logical :: l1Dx,l1Dy,l1Dz
!
! Check the dimensionality and store it in logicals
!
      lxpresent=(nxgrid/=1)
      lypresent=(nygrid/=1)
      lzpresent=(nzgrid/=1)
!
      l3D  =     lxpresent.and.     lypresent.and.     lzpresent
      l2Dxy=     lxpresent.and.     lypresent.and..not.lzpresent
      l2Dyz=.not.lxpresent.and.     lypresent.and.     lzpresent
      l2Dxz=     lxpresent.and..not.lypresent.and.     lzpresent
      l1Dx =     lxpresent.and..not.lypresent.and..not.lzpresent
      l1Dy =.not.lxpresent.and.     lypresent.and..not.lzpresent
      l1Dz =.not.lxpresent.and..not.lypresent.and.     lzpresent
!
      if (ldebug.and.lroot) then
        if (l3D)   print*,"This is a 3D simulation"
        if (l2Dxy) print*,"This is a 2D xy simulation"
        if (l2Dyz) print*,"This is a 2D yz simulation"
        if (l2Dxz) print*,"This is a 2D xz simulation"
        if (l1Dx)  print*,"This is a 1D x simulation"
        if (l1Dy)  print*,"This is a 1D y simulation"
        if (l1Dz)  print*,"This is a 1D z simulation"
      endif
!
! The subroutine "fourier_transform" should only be used
! for 1D, square 2D or cubic domains without x-parallelization.
! Everything else uses fft_parallel.
!
      luse_fourier_transform=(nprocx==1.and.&
           (l1dx                                       .or.&
            l1dy                                       .or.&
            l1dz                                       .or.&
            (l2dxy.and.nxgrid==nygrid)                 .or.&
            (l2dxz.and.nxgrid==nzgrid)                 .or.&
            (l2dyz.and.nygrid==nzgrid)                 .or.&
            (l3d.and.nxgrid==nygrid.and.nygrid==nzgrid)))
!
    endsubroutine decide_fourier_routine
!***********************************************************************
    subroutine read_poisson_init_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=poisson_init_pars, IOSTAT=iostat)
!
    endsubroutine read_poisson_init_pars
!***********************************************************************
    subroutine write_poisson_init_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=poisson_init_pars)
!
    endsubroutine write_poisson_init_pars
!***********************************************************************
    subroutine read_poisson_run_pars(iostat)
!
      use File_io, only: parallel_unit
!
      integer, intent(out) :: iostat
!
      read(parallel_unit, NML=poisson_run_pars, IOSTAT=iostat)
!
    endsubroutine read_poisson_run_pars
!***********************************************************************
    subroutine write_poisson_run_pars(unit)
!
      integer, intent(in) :: unit
!
      write(unit, NML=poisson_run_pars)
!
    endsubroutine write_poisson_run_pars
!***********************************************************************
!----------------------------------------------------------------------
!                       Routines for logspirals!                              
!----------------------------------------------------------------------
!
!***********************************************************************
    subroutine inverse_laplacian_logradial_fft(potential,gpotself)
!
! Solve the Poisson equation by Fourier transforming on a periodic grid,
! in cylindrical coordinates with a log spaced radial coordinate.
!
! 18-aug-2016/vince: coded
!     
      real, dimension(nx,ny,nz), intent(inout) :: potential      
      real, dimension(nz,ny,nz,3), intent(inout) :: gpotself
!
! The density will be passed in via potential, but needs to be put on the fourier grid
! with 0's in the extra cells
!
      call generate_fourier_density(potential)
!
! Finally, mass fields and kernals for each integral (gr,gphi,V)
!
      call generate_massfields()
!
! Mass fields and kernals are used to compute quatities of interest
!
      call compute_acceleration(gpotself)
      call compute_potential(potential)
!      
    endsubroutine inverse_laplacian_logradial_fft
!***********************************************************************
    subroutine generate_coordinates()
!
! Generates all coordinates that will be used, sets the smoothing factor (function of the 
! radial spacing)
!
      real, dimension(ny) :: phi1d
      real, dimension(2*nx) :: u1d
!
      u1d=linspace(start=0.0,end=2*uMax,n=size(u1d,1),step_size=du,endpoint=.true.)
      phi1d=linspace(start=phiMin,end=phiMax,n=size(phi1d,1),step_size=dphi,endpoint=.false.)
!        
      B=.01*du
      B2=B**2    
!
      call meshgrid(u1d,phi1d,u2d,phi2d)
      r=innerRadius*exp(u2d(:nx,:))
!
    endsubroutine generate_coordinates
!***********************************************************************
    subroutine generate_fourier_density(potential)
! 
! Put the density (passed in on the physical grid) onto the extended
! Fourier grid, with 0's in the extra Fourier cells.
! 
      real, dimension(:,:,:), intent(inout) :: potential
!
      sigma(nx+1:,:)=0.0
      sigma(:nx,:)=potential(:,:,1)
!        
    endsubroutine generate_fourier_density
!***********************************************************************
    subroutine generate_kernals()
!
! Calculates the kernals for the three relevant integrals (functions
! only of the geometry of the disk) for the kernal, periodic boundary
! conditions are enforced beyond the edge of the physical disk.
!
      real, dimension(2*nx,ny) :: u_k,krNumerator,kphiNumerator,kernalDenominator
!
      u_k(:nx,:)=u2d(:nx,:)          
      u_k(nx+1:,:)=-u2d(nx+1:2:-1,:)

      krNumerator=1+B2-exp(-u_k)*cos(phi2d)
      kphiNumerator=sin(phi2d)
      kernalDenominator=(2.*(cosh(u_k)-cos(phi2d))+B2*exp(u_k))**(1.5)
      kr=krNumerator/kernalDenominator
      kphi=kphiNumerator/kernalDenominator
        
      kv=1/sqrt((1+B2)*exp(u_k)+exp(-u_k)-2*cos(phi2d)) !changed from **-.5 to 1/sqrt
!
    endsubroutine generate_kernals
!***********************************************************************
    subroutine generate_massfields()
!
! Calculates the mass fields (density distributions weighted by
! coordinate locations) for the three relevant integrals. These are
! dependent on the mass distribution, and will therefore change at
! each timestep.
!
      sr=sigma*exp(u2d/2)
      sphi=sigma*exp(3*u2d/2)
!
      sv = sigma*exp(3*u2d/2)
!
    endsubroutine generate_massfields
!***********************************************************************
    subroutine compute_acceleration(gpotself)
!
! Uses kernals and mass fields for the two acceleration integrals to
! calculate gravitational accelerations.
!
      real, dimension(nx,ny,nz,3), intent(inout) :: gpotself
      real, dimension(2*nx,ny) :: gr_convolution,gr_factor,gr1,gr2,gphi_convolution,gphi_factor
!
      call fftconvolve(kr,sr,gr_convolution)
      call fftconvolve(kphi,sphi,gphi_convolution)
      gr_factor=-Gnewton*exp(-u2d/2)*du*dphi
      gphi_factor=-Gnewton*exp(-3*u2d/2)*du*dphi
!
      gr1=gr_factor*gr_convolution
      gr2=Gnewton*sigma*du*dphi/B
      gr=gr1+gr2
!
      gphi=gphi_factor*gphi_convolution
!
      do n=1,nz
        gpotself(:,:,n,1)=gr(:nx,:)
        gpotself(:,:,n,2)=gphi(:nx,:)
      enddo
      gpotself(:,:,:,3)=0.
!
    endsubroutine compute_acceleration
!***********************************************************************
    subroutine compute_potential(potential)
!
! Uses kernals and mass fields for the potential integral to calculate
! potential on the grid NOTE: Should actually calculate potential from
! the accelerations, since the log radial convolution product produces
! potentials which are known to violate Newton's first law (due to the
! smoothing factor being a function of radius), but produces accelerations
! that are free of this behavior (See Towards Predictive Scenarios of
! Planetary Migration, by Clement Baruteau)
!
      real, dimension(nx,ny,nz), intent(inout) :: potential
      real, dimension(2*nx,ny) :: v_convolution,v_factor
!
      call fftconvolve(kv,sv,v_convolution)
      v_factor=-Gnewton*innerRadius*exp(-u2d/2)*du*dphi
!
      do n=1,nz
        potential(:,:,n)=v_factor(:nx,:)*v_convolution(:nx,:)
      enddo
!
    endsubroutine compute_potential
!***********************************************************************
    subroutine fftconvolve(array1,array2,convolution)
!
! convolution product using the pendil code fft methods to do the ffts
!
      real, intent(in), dimension(:,:) :: array1
      real, intent(in), dimension(:,:) :: array2
      real, intent(out), dimension(:,:) :: convolution
      complex, dimension(size(convolution,1),size(convolution,2)) :: convolution_fourier
      real, dimension(size(convolution,1),size(convolution,2)) :: array1_fourier_real,array1_fourier_imaginary
      real, dimension(size(convolution,1),size(convolution,2)) :: array2_fourier_real,array2_fourier_imaginary
      real, dimension(size(convolution,1),size(convolution,2)) :: convolution_fourier_real
      real, dimension(size(convolution,1),size(convolution,2)) :: convolution_fourier_imaginary
      integer :: nrow,ncol,i,j
      logical :: array1_convolution_diffshape,array2_convolution_diffshape
!
      array1_convolution_diffshape=(size(array1,1)/=size(convolution,1)).or.(size(array1,2)/=size(convolution,2))
      array2_convolution_diffshape=(size(array2,1)/=size(convolution,1)).or.(size(array2,2)/=size(convolution,2))
      if (array1_convolution_diffshape.or.array2_convolution_diffshape) then
         write(*,*) 'Input and output arrays must be the same shape as each other.'
         stop
      else
!
!  The input arrays are purely real. Here, I copy the arrays into the ones holding the
!  real components for the transform, and fill the arrays holding the imaginary
!  components with 0's
!
         nrow=size(convolution,1)
         ncol=size(convolution,2)
         array1_fourier_real=array1
         array1_fourier_imaginary=0.0
         array2_fourier_real=array2
         array2_fourier_imaginary=0.0
      end if
        !There may be some significant optimization that can be done above

        !Transforming the arrays
        !call fourier_transform_other_2(array1_fourier_real,array1_fourier_imaginary,.false.)
        !call fourier_transform_other_2(array2_fourier_real,array2_fourier_imaginary,.false.)

        !Now, the convolution product must be calculated by multiplying the transformed arrays.
        !To ensure that the multiplication is carried out correctly, the real and imaginary parts
        !of the transformed arrays are first recombined into complex numbers, then multiplied.
        !Afterwards, the convolution is separated back into its real and imaginary components in
        !preparation for its own inverse transform.
      convolution_fourier=cmplx(array1_fourier_real,array1_fourier_imaginary)*cmplx(array2_fourier_real,array2_fourier_imaginary)
      convolution_fourier_real=real(convolution_fourier)
      convolution_fourier_imaginary=aimag(convolution_fourier)

        !Inverse transform
        !call fourier_transform_other_2(convolution_fourier_real,convolution_fourier_imaginary,.true.)

        !If all went according to plan, the end result should be purely real.
      convolution=convolution_fourier_real

    endsubroutine fftconvolve
!***********************************************************************
endmodule Poisson