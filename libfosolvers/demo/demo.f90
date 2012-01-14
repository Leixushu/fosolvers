!----------------------------------------------------------------------------- best with 100 columns

program demo
  use moduleGrid
  use moduleTime
  use moduleFileIO
  use moduleMtl
  use moduleCond
  use moduleFVM
  use moduleMP1
  use moduleMP2
  use moduleMiscDataStruct
  
  double precision,allocatable::v(:,:,:)
  
  ! test multi-processing, material and conditions
  call initMPI()
  
  if(pidMPI==ROOT_PID)then
    call readMsh('grid.msh',50,verbose=.true.)
    call readCond('conditions.cod',52)
    call readMtl('materials.mtl',51)
    
    allocate(v(nNode,DIMS,DIMS))
    forall(i=1:nNode)
      v(i,:,1)=Node(i)%Pos(:)
      v(i,:,2)=Node(i)%Pos(:)
      v(i,:,3)=Node(i)%Pos(:)
    end forall
    
    call sendData(Mtl,1,1)
    call sendPrt(2,1)
    call sendPrt(2,1,v,binding=BIND_NODE)
  else
    if(pidMPI==1)then
      call recvData(Mtl,0,1,realloc=.true.)
      call recvPrt()
      call recvPrt(v)
      
      write(*,*),condNode(5)%lookup('vname'),condNode(5)%lookup('tname',5d-1)
      write(*,*),condFacet(32)%lookup('fffc1'),condFacet(32)%lookup('fffc2',0.6d0)
      write(*,*),size(Mtl),size(Mtl(1)%DataItem)
      write(*,*),Mtl(1)%lookup('Denst')
      write(*,*),Mtl(1)%lookup('SpcHt',475d0)
      write(*,*),Mtl(1)%lookup('ThrCd',5d2)
      write(*,*),Mtl(1)%lookup('YounM')
      write(*,*),Mtl(1)%lookup('PoisR')
      write(*,*),Mtl(1)%lookup('Stren')
      
      call addWrite(v,binding=BIND_NODE)
      call writeRst('rst.msh',55)
    end if
  end if
  
  call finalMPI()
  
!  ! test dataset
!  type(typeDataSet)::v
!  type(typeDataItem)::ve
!  
!  write(*,*),v%lookup('name3',stat=ierr)
!  write(*,*),ierr
!  
!  call v%extend(1)
!  call v%ptrLast%specify(TAB1D_TYPE,5)
!  v%ptrLast%DataName='name1'
!  v%ptrLast%Tab1d(:,1)=[1d0,2d0,3d0,4d0,5d0]
!  v%ptrLast%Tab1d(:,2)=[1d1,2d1,3d1,4d1,5d1]
!  
!  call v%extend(1)
!  call v%ptrLast%specify(VAL_TYPE)
!  v%ptrLast%DataName='name2'
!  v%ptrLast%Val=250d0
!  
!  call ve%specify(TAB1D_TYPE,5)
!  ve%DataName='name4'
!  ve%Tab1d(:,1)=[1d0,2d0,3d0,4d0,5d0]
!  ve%Tab1d(:,2)=[1d2,2d2,3d2,4d2,5d2]
!  call v%push(ve)
!  v%ptrLast%DataName='name4'
!  
!  write(*,*),v%lookup('name1',-2d0)
!  write(*,*),v%lookup('name2')
!  write(*,*),v%lookup('name4',3d0)
  
!  ! test gradient and grid and result
!  double precision,target,allocatable::v(:),vv(:,:),vvv(:,:,:)
!  
!  call readMsh('grid.msh',50,verbose=.true.)
!  
!  allocate(v(nNode))
!  allocate(vv(nNode,DIMS))
!  allocate(vvv(nNode,DIMS,DIMS))
!  call addWrite(v,binding=BIND_NODE)
!  call addWrite(vv,binding=BIND_NODE)
!  call addWrite(vvv,binding=BIND_NODE)
!  
!  do i=1,nNode
!    v(i)=sin(3d0*Node(i)%Pos(1))+cos(4d0*Node(i)%Pos(2))+sin(5d0*Node(i)%Pos(3))
!  end do
!  do i=1,nNode
!    vv(i,:)=findGrad(i,v,binding=BIND_Node)
!  end do
!  do i=1,nNode
!    vvv(i,:,:)=findGrad(i,vv,binding=BIND_Node)
!  end do
!  
!  call writeRst('rst.msh',55)
end program
