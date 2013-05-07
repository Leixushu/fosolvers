!----------------------------------------------------------------------------- best with 100 columns

!> foburn1d main program
program foburn1d
  use miscBurn1D
  use moduleGrid1D
  use moduleFVMConvect
  use moduleFVMDiffus
  use moduleFVMGrad
  use moduleInterpolation
  use moduleCLIO
  
  width=5d-3
  call grid%genUniform(0d0,width,500)
  call setEnv()
  t=0d0
  dt=1d-7
  tFinal=1d-1
  tWrite=0d0
  dtWrite=5d-4
  ! initial state
  gamm=1.4d0
  mw=30d-3 ![kg/mol]
  R=RU/mw ![J/kg/K]
  Cv=R/(gamm-1d0) ![J/kg/K]
  Cp=Cv*gamm ![J/kg/K]
  Q=70d3 ![J/mol reactant]
  Dm=2d-5 ![m^2/s]
  alpha=2d-5 ![m^2/s]
  Y(:)=1d0
  u(:)=0d0
  p=1d5 !< inital pressure
  Temp(:)=300d0 !< initial temperature
  rho(:)=p/R/Temp(:)
  Mass(:)=rho(:)*grid%CellWidth(:)
  Temp(size(Temp)-1:size(Temp))=5d3
  ! advance in time
  do while(t<tFinal)
    ! diffusion and burn
    burnR(:)=1d11*(Y(:)*rho(:)/mw)**2d0*exp(-1.8d4/Temp(:))
    burnR(:)=min(burnR(:),Y(:)*rho(:)/mw/dt)
    Temp(:)=(Temp(:)*Cp*rho(:)*grid%CellWidth(:)&
    &        +dt*findDiffus(alpha*Cp*1.2d0*[(1d0,i=1,grid%nCell)],BIND_CELL,Temp,grid))&
    &       /rho(:)/Cp/grid%CellWidth(:)
    Temp(:)=Temp(:)+dt*Q/Cp*burnR(:)/rho(:)
    Y(:)=(Y(:)*rho(:)*grid%CellWidth(:)+dt*findDiffus(Dm*rho(:),BIND_CELL,Y,grid))&
    &    /rho(:)/grid%CellWidth(:)
    Y(:)=Y(:)-dt*mw*burnR(:)/rho(:)
    Y(:)=max(0d0,Y(:))
    ! move gas
    grid%CellWidth(:)=grid%CellWidth(:)*(rho(:)*R*Temp(:)/p)**(1d0/gamm)
    Temp(:)=Temp(:)*(rho(:)*R*Temp(:)/p)**(-(gamm-1d0)/gamm)
    do i=2,grid%nNode
      grid%NodePos(i)=grid%NodePos(NlN(i))+grid%CellWidth(NlC(i))
    end do
    p=p*(grid%NodePos(grid%nNode)/width)**gamm
    Temp(:)=Temp(:)*(grid%NodePos(grid%nNode)/width)**(gamm-1d0)
    grid%NodePos(:)=grid%NodePos(:)*width/grid%NodePos(grid%nNode)
    call grid%update()
    rho(:)=Mass(:)/grid%CellWidth(:)
    t=t+dt
    if(Y(1)<0.001d0)then
      !call writeRst()
      !write(*,*),t
      stop
    end if
    if(t>=tWrite)then
      call writeRst()
      tWrite=tWrite+dtWrite
    end if
  end do
  ! clean up
  call clearEnv()
  
end program
