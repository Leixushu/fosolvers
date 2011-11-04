program libtest
  use moduleGrid
  use moduleCond
  use moduleWrite
  use moduleMPIvar
  
  double precision,target,allocatable::v(:),vv(:,:)
  double precision g(3)
  
  call initMPI()
  call genPrtDataTab(0,0,0,1,1,0)
  
  if(pidMPI==0)then
    call readmsh('./grid.msh',10)
    call updateFacetPara()
    call updateElePara()
    
    ! prepare data space
    allocate(v(nEle))
    v(:)=0d0
    transEleScal(1)%ptr=>v
    allocate(vv(nEle,3))
    vv(:,:)=0d0
    transEleVect(1)%ptr=>vv
    
    ! define conditions
    allocate(Conditions(1))
    Conditions(1)%GeoEnti=20
    Conditions(1)%what(1:2)='Dr'
    Conditions(1)%val=32.3
    Conditions(1)%tab2=1900
    allocate(dataTab(1))
    dataTab(1)%length=5
    allocate(dataTab(1)%x(5))
    allocate(dataTab(1)%y(5))
    dataTab(1)%x(:)=[1,2,3,4,5]
    dataTab(1)%y(:)=[7,8,10,11,12]
    
    ! broadcast static information
    call bcastStatic()
    
    ! assign task
    call distriPrt(1,1)
    
    ! gather data
    call gathData(i)
    
    ! write result
    call initWriteEnv(0,0,0,1,1,0)
    rstEleScal(1)%ptr=>v
    rstEleVect(1)%ptr=>vv
    call writerst('rst.msh',11,.false.)
  else
    ! receive static informaion
    call recvStatic()
    write(*,*),Conditions(1)%GeoEnti,Conditions(1)%what,Conditions(1)%val,Conditions(1)%tab2
    write(*,*),dataTab(1)%lookup(2.85d0)
    
    ! receive task
    call recvPrt()
    allocate(v(nEle))
    v=transEleScal(1)%ptr
    deallocate(transEleScal(1)%ptr)
    allocate(vv(nEle,3))
    vv=transEleVect(1)%ptr
    deallocate(transEleVect(1)%ptr)
    
    ! do work
    do i=1,nEle
      v(i)=sin(t+10d0*Ele(i)%PC(1))+cos(5d0*Ele(i)%PC(2))-sin(5d0*Ele(i)%PC(3))
    end do
    do i=1,nEle
      call findEleGradScal(i,v,g)
      vv(i,:)=g(:)
    end do
    
    ! return data
    transEleScal(1)%ptr=>v
    transEleVect(1)%ptr=>vv
    call retnData()
  end if
  
  call finalMPI()
end program
