!----------------------------------------------------------------------------- best with 100 columns

function advection1() result(ierr)
  use modFileIO
  use modPolyFvGrid
  use modReconstruction
  use modGradient
  use modAdvection
  integer ierr
  type(polyFvGrid)::grid
  double precision,allocatable::s(:),u(:,:),grads(:,:),gradu(:,:,:),sr(:),ur(:,:),tmps(:)
  double precision::p(3),dt
  
  ierr=0
  open(10,file='data/bar_tet.vtk',action='read')
  call readVTK(10,grid)
  close(10)
  call grid%up()
  allocate(s(grid%nC))
  allocate(u(3,grid%nC))
  do i=1,grid%nC
    p=grid%p(i)
    if(p(1)<0.6d0.and.p(1)>0.4d0)then
      s(i)=1d0
    else if(p(1)<0.3d0.and.p(1)>0.1d0)then
      s(i)=sin((p(1)-0.1d0)*40d0*atan(1d0))
    else
      s(i)=0d0
    end if
    u(:,i)=[1d0,0d0,0d0]
  end do
  dt=0.0005d0
  call findGrad(grid,u,gradu)
  call reconAvg(grid,u,gradu,ur)
  do l=1,200
    call findGrad(grid,s,grads)
    call reconLtd(grid,s,grads,ur,sr)
    call findAdv(grid,sr,ur,tmps)
    s(:)=s(:)+dt*tmps(:)/grid%v(:)
  end do
  open(10,file='advection1_rst.vtk',action='write')
  call writeVTK(10,grid)
  call writeVTK(10,grid,E_DATA)
  call writeVTK(10,'s',[s,[(0d0,i=1,grid%nE-grid%nC)]])
  close(10)
  call grid%clear()
  deallocate(s,u,grads,gradu,sr,ur,tmps)
end function
