SET(fopbc_src
  fopbc.f90
  modPbc.f90
  fkfun.f90
  fkprec.f90
)

ADD_EXECUTABLE(fopbc ${fopbc_src})

TARGET_LINK_LIBRARIES(fopbc
  fosolvers
  ${CGNS_LIBRARIES}
  ${HDF5_LIBRARIES}
  ${BLAS_LIBRARIES}
  ${LAPACK_LIBRARIES}
  ${SUNDIALS_LIBRARIES}
  ${MATHEVAL_LIBRARIES}
)

INSTALL(TARGETS fopbc DESTINATION bin)
