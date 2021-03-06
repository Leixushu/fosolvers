!----------------------------------------------------------------------------- best with 100 columns

!> environment for the pressure-based coupled solver
module modPbc
  use modPolyFvGrid
  use modCondition
  use modUDF
  use iso_c_binding
  
  public
  
  integer,parameter::DIMS=3 !< three dimensions
  
  type(polyFvGrid)::grid !< computational grid
  
  double precision::t !< time
  double precision::tFinal !< final time
  double precision::dt !< time step size [s]
  double precision::tInt !< time interval of output
  double precision::tNext !< time for next output
  integer::iOut !< index of output
  
  double precision,allocatable::rho(:) !< density [kg/m^3]
  double precision,allocatable::rhou(:,:) !< momentum [kg/s/m^2]
  double precision,allocatable::rhoE(:) !< total energy [J/m^3]
  double precision,allocatable::p(:) !< pressure [Pa]
  double precision,allocatable::u(:,:) !< velocity [m/s]
  double precision,allocatable::temp(:) !< temperature [K]
  double precision,allocatable::Y(:,:) !< mass fraction of species
  ! state at the beginning of a time step
  double precision,allocatable::rho0(:),rhou0(:,:),rhoE0(:),p0(:),u0(:,:),temp0(:),Y0(:,:)
  
  double precision,allocatable::visc(:) !< viscosity [Pa*s]
  double precision,allocatable::cond(:) !< thermal conductivity [W/m/K]
  double precision,allocatable::gradP(:,:) !< gradient of p [Pa/m]
  double precision,allocatable::viscF(:,:) !< viscous force applied on cell [N]
  double precision,allocatable::presF(:,:) !< pressure force applied on cell [N]
  double precision,allocatable::condQ(:) !< heat conduction into cell [W]
  double precision,allocatable::carrier(:,:) !< {rho,rhou,rhoH} of each cell [*]
  double precision,allocatable::flux(:,:,:) !< flux of {rho,rhou,rhoH} [*m/s]
  double precision,allocatable::flow(:,:) !< flow rate of {rho,rhou,rhoH} into cell [*m^3/s]
  double precision,allocatable::localPrec(:,:,:) !< local preconditioner and its invertion
  
  double precision,allocatable::x(:) !< solution vector of the nonlinear system of equations
  double precision,allocatable::xscale(:) !< scaling factors for the solution
  double precision,allocatable::rscale(:) !< scaling factors for the residual
  integer(C_LONG)::nEq !< number of equations
  integer(C_LONG)::ioutFKIN(100) !< integer output of FKINSOL
  double precision::routFKIN(100) !< real output of FKINSOL
  
contains
  
  !> initialize the simulation
  subroutine init()
    use modFileIO
    integer,parameter::FID=10
    double precision::pInit,uInit(DIMS),TInit,pE(DIMS)!,tmpD
    double precision,allocatable::YInit(:)
    integer::ier!,udfIc,udfBc,iUdf(5)
    
    ! read inputs
    open(FID,file='grid.msh',action='read')
    call readGMSH(FID,grid)
    call grid%up()
    close(FID)
    !open(FID,file='bc',action='read')
    !call readCondTab(FID,bc)
    !if(any(bc%t(:)==BC_IN_STATIC_UDF).or.&
    !&  any(bc%t(:)==BC_IN_TOTAL_UDF).or.&
    !&  any(bc%t(:)==BC_OUT_UDF).or.&
    !&  any(bc%t(:)==BC_FAR_UDF))then
    !  udfBc=1
    !else
    !  udfBc=0
    !end if
    !close(FID)
    !open(FID,file='ic',action='read')
    !read(FID,*),udfIC
    !if(udfIc==0)then
    !  read(FID,*),pInit
    !  read(FID,*),TInit
    !  read(FID,*),uInit(1)
    !  read(FID,*),uInit(2)
    !  read(FID,*),uInit(3)
    !else
    !  read(FID,*),tmpD
    !  iUdf(1)=int(tmpD)
    !  read(FID,*),tmpD
    !  iUdf(2)=int(tmpD)
    !  read(FID,*),tmpD
    !  iUdf(3)=int(tmpD)
    !  read(FID,*),tmpD
    !  iUdf(4)=int(tmpD)
    !  read(FID,*),tmpD
    !  iUdf(5)=int(tmpD)
    !end if
    !close(FID)
    open(FID,file='sim',action='read')
    read(FID,*)tFinal
    read(FID,*)tInt
    close(FID)
    !open(FID,file='fl',action='read')
    !read(FID,*),r
    !read(FID,*),gamm
    !close(FID)
    !if(udfIc/=0.or.udfBc/=0)then
    !  open(FID,file='udf',action='read')
    !  call readUDFTab(FID,udf)
    !  close(FID)
    !end if
    ! indexes of boundary conditions
    !allocate(iBC(grid%nE))
    !iBC(:)=0
    !do i=1,grid%nE
    !  do j=1,size(bc%gid)
    !    if(grid%gid(i)==bc%gid(j))then
    !      iBC(i)=j
    !      exit
    !    end if
    !  end do
    !end do
    ! initialize nonlinear solver
    nEq=5*grid%nC
    call fnvinits(3,nEq,ier)
    call fkinmalloc(ioutFKIN,routFKIN,ier)
    !call fkinspgmr(0,0,ier)
    !call fkinspilssetprec(1,ier)
    call fkindense(nEq,ier)
    call fkinsetrin('MAX_STEP',huge(1d0),ier)
    !call fkinsetrin('FNORM_TOL',1d-5,ier)
    !call fkinsetrin('SSTEP_TOL',1d-9,ier)
    call fkinsetiin('PRNT_LEVEL',1,ier)
    allocate(x(nEq))
    allocate(xscale(nEq))
    allocate(rscale(nEq))
    ! work space and initial state
    allocate(rho(grid%nE))
    allocate(rho0(grid%nE))
    allocate(rhou(DIMS,grid%nE))
    allocate(rhou0(DIMS,grid%nE))
    allocate(rhoE(grid%nE))
    allocate(rhoE0(grid%nE))
    allocate(p(grid%nE))
    allocate(p0(grid%nE))
    allocate(u(DIMS,grid%nE))
    allocate(u0(DIMS,grid%nE))
    allocate(temp(grid%nE))
    allocate(temp0(grid%nE))
    ! FIXME fix nSp
    allocate(Y(1,grid%nE))
    allocate(Y0(1,grid%nE))
    allocate(YInit(1))
    allocate(visc(grid%nE))
    allocate(cond(grid%nE))
    allocate(gradP(DIMS,grid%nC))
    allocate(viscF(DIMS,grid%nC))
    allocate(presF(DIMS,grid%nC))
    allocate(condQ(grid%nC))
    allocate(carrier(5,grid%nE))
    allocate(flux(DIMS,5,grid%nE))
    allocate(flow(5,grid%nC))
    allocate(localPrec(5,5,grid%nC))
    do i=1,grid%nE
    !  if(udfIc/=0)then
    !    pE(:)=grid%p(:,i)
    !    pInit=udf%eval(iUdf(1),pE,0d0)
    !    TInit=udf%eval(iUdf(2),pE,0d0)
    !    uInit(1)=udf%eval(iUdf(3),pE,0d0)
    !    uInit(2)=udf%eval(iUdf(4),pE,0d0)
    !    uInit(3)=udf%eval(iUdf(5),pE,0d0)
    !  end if
      ! FIXME remove below
      pE(:)=grid%p(:,i)
      pInit=min(max(0.9d5,-0.5d5*(pE(3)-0.5d0)+0.95d5),1d5)
      uInit(:)=[0d0,0d0,0d0]
      TInit=298d0
      YInit=[1d0]
      ! FIXME remove above
      ! FIXME calculation of rho, rhoE based on cantera
      p(i)=pInit
      u(:,i)=uInit(:)
      temp(i)=TInit
      Y(:,i)=YInit(:)
    end do
    call recoverState(p,u,temp,Y,rho,rhou,rhoE)
    t=0d0
    tNext=tInt
    iOut=0
    deallocate(YInit)
  end subroutine
  
  !> clear the simulation environment
  subroutine clear()
    call grid%clear()
    call fkinfree()
  end subroutine
  
  !> record {rho,rhoU,rhoE,p,u,temp,Y} in {rho0,rhoU0,rhoE0,p0,u0,temp0,Y0}
  subroutine recordState0()
    rho0(:)=rho(:)
    rhou0(:,:)=rhou(:,:)
    rhoE0(:)=rhoE(:)
    p0(:)=p(:)
    u0(:,:)=u(:,:)
    temp0(:)=temp(:)
    Y0(:,:)=Y(:,:)
  end subroutine
  
  !> derive primitive state {p,u,T} from conserved state {rho,rhou,rhoE}
  subroutine deriveState(rhoi,rhoui,rhoEi,Yi,po,uo,tempo)
    double precision,intent(in)::rhoi(:) !< density
    double precision,intent(in)::rhoui(:,:) !< momentum
    double precision,intent(in)::rhoEi(:) !< total energy
    double precision,intent(in)::Yi(:,:) !< mass fraction of species
    double precision,intent(inout)::po(:) !< pressure
    double precision,intent(inout)::uo(:,:) !< velocity
    double precision,intent(inout)::tempo(:) !< temperature
    
    !$omp parallel do default(shared)
    do i=1,grid%nE
      uo(:,i)=rhoui(:,i)/rhoi(i)
      ! FIXME calculation of p, T based on cantera
      po(i)=(1.4d0-1d0)*(rhoEi(i)-0.5d0*dot_product(rhoui(:,i),rhoui(:,i))/rhoi(i))
      tempo(i)=po(i)/rhoi(i)/287.058d0
    end do
    !$omp end parallel do
  end subroutine
  
  !> recover conserved state {rho,rhou,rhoE} from primitive state {p,u,T}
  subroutine recoverState(pi,ui,tempi,Yi,rhoo,rhouo,rhoEo)
    double precision,intent(in)::pi(:) !< pressure
    double precision,intent(in)::ui(:,:) !< velocity
    double precision,intent(in)::tempi(:) !< temperature
    double precision,intent(in)::Yi(:,:) !< mass fraction of species
    double precision,intent(inout)::rhoo(:) !< density
    double precision,intent(inout)::rhouo(:,:) !< momentum
    double precision,intent(inout)::rhoEo(:) !< total energy
    
    !$omp parallel do default(shared)
    do i=1,grid%nE
      ! FIXME calculation of rho, rhoE based on cantera
      rhoo(i)=pi(i)/287.058d0/tempi(i)
      rhouo(:,i)=rhoo(i)*ui(:,i)
      rhoEo(i)=rhoo(i)*(1d0/(1.4d0-1d0)*287.058d0*tempi(i)+0.5d0*dot_product(ui(:,i),ui(:,i)))
    end do
    !$omp end parallel do
  end subroutine
  
  !> extract primitive state {p,u,T} from variable vector
  subroutine extractVar(var,po,uo,tempo)
    double precision,intent(in)::var(:) !< variable vector of the nonlinear problem
    double precision,intent(inout)::po(:) !< pressure
    double precision,intent(inout)::uo(:,:) !< velocity
    double precision,intent(inout)::tempo(:) !< temperature
    
    !$omp parallel do default(shared)&
    !$omp& private(j)
    do i=1,grid%nC
      j=(i-1)*5
      po(i)=p0(i)+var(j+1)
      uo(:,i)=u0(:,i)+var(j+2:j+4)
      tempo(i)=temp0(i)+var(j+5)
    end do
    !$omp end parallel do
  end subroutine
  
  !> write the state to post-processing file
  subroutine writeState(fName)
    use modFileIO
    character(*),intent(in)::fName
    integer,parameter::FID=10
    
    open(FID,file=trim(fName),action='write')
    call writeVTK(FID,grid)
    call writeVTK(FID,grid,E_DATA)
    call writeVTK(FID,'density',rho)
    call writeVTK(FID,'velocity',u)
    call writeVTK(FID,'pressure',p)
    call writeVTK(FID,'temperature',temp)
    close(FID)
  end subroutine
  
  !> calculate time step size, scaling vectors and initial solution vector
  subroutine preSolve()
    double precision::ps,us,temps,rhos,rhous,rhoEs
    double precision,parameter::CFL_ACCOUSTIC=10d0
    double precision,parameter::CFL_FLOW=0.5d0
    double precision,parameter::CFL_DIFFUSION=0.5d0
    
    ! TODO calculate dt, cantera sound speed
    dt=min(tNext-t,minval(CFL_ACCOUSTIC*grid%v(:)**(1d0/3d0)&
    &                     /sqrt(1.4d0*p(1:grid%nC)/rho(1:grid%nC))))
    dt=min(dt,minval(CFL_FLOW*grid%v(:)**(1d0/3d0)&
    &                /norm2(u(:,1:grid%nC),1)))
    dt=min(dt,minval(CFL_DIFFUSION*grid%v(:)**(2d0/3d0)&
    &                /(visc(1:grid%nC)/rho(1:grid%nC))))
    dt=1d-4
    
    ! estimate the solution vector
    x(:)=0d0
    
    ! solution and residual scaling
    ps=max(maxval(p)-minval(p),maxval(0.5d0*rho*norm2(u,1)**2),1d0)
    us=max(maxval(norm2(u,1)),sqrt(2d0*ps/minval(rho)))
    temps=max(maxval(temp)-minval(temp),ps/minval(rho)/287.058d0)
    rhos=maxval(rho)
    rhous=rhos*us
    rhoEs=max(rhos*287.058*temps,0.5d0*rhos*us**2)
    do i=1,grid%nC
      j=(i-1)*5
      xscale(j+1)=1d0/ps
      xscale(j+2:j+4)=1d0/us
      xscale(j+5)=1d0/temps
      rscale(j+1)=1d0/rhos
      rscale(j+2:j+4)=1d0/rhous
      rscale(j+5)=1d0/rhoEs
    end do
  end subroutine
  
  !> set the boundary conditions
  subroutine setBC()
    
    do i=1,grid%nP
      m=grid%iEP(1,i)
      n=grid%iEP(2,i)
      if(n>grid%nC)then
        if(.true.)then ! default wall boundary
          p(n)=p(m)
          u(:,n)=-u(:,m)
          temp(n)=temp(m)
          Y(:,n)=Y(:,m)
        end if
      end if
    end do
  end subroutine
  
end module
