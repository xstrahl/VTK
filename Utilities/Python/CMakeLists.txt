include(vtkInitializeWrapPython)

set(${vtk-module}_LIBRARIES ${VTK_PYTHON_LIBRARIES})
set(${vtk-module}_SYSTEM_INCLUDE_DIRS "${PYTHON_INCLUDE_DIRS}")
set(${vtk-module}_NO_Header_Test 1)
vtk_module_impl()

# Export location of python module dirs in install and build tree for for
# projects that link against VTK
set(${vtk-module}_EXPORT_CODE_BUILD "set(VTK_PYTHONPATH \"${VTK_BUILD_PYTHON_MODULES_DIR}\")")
if(IS_ABSOLUTE ${VTK_INSTALL_PYTHON_MODULES_DIR})
  set(${vtk-module}_EXPORT_CODE_INSTALL "set(VTK_PYTHONPATH \"${VTK_INSTALL_PYTHON_MODULES_DIR}\")")
else()
  set(${vtk-module}_EXPORT_CODE_INSTALL "set(VTK_PYTHONPATH \"${CMAKE_INSTALL_PREFIX}/${VTK_INSTALL_PYTHON_MODULES_DIR}\")")
endif()

vtk_module_export_info()

# for static builds, since vtkPythonInterpreter cannot work off the library
# location, but instead has to use the executable location, it needs to know the
# library dir explicitly.
if(NOT VTK_BUILD_SHARED_LIBS)
  set(VTK_PYTHON_SITE_PACKAGES_SUFFIX_FIXED ${VTK_INSTALL_PYTHON_MODULES_DIR})
else()
  set(VTK_PYTHON_SITE_PACKAGES_SUFFIX_FIXED ${VTK_PYTHON_SITE_PACKAGES_SUFFIX})
endif()

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/vtkPythonConfigure.h.in
  ${CMAKE_CURRENT_BINARY_DIR}/vtkPythonConfigure.h)

set(${vtk-module}_HDRS
  vtkPython.h
  ${CMAKE_CURRENT_BINARY_DIR}/vtkPythonConfigure.h
  )

if(NOT VTK_INSTALL_NO_DEVELOPMENT)
  install(FILES ${${vtk-module}_HDRS}
    DESTINATION ${VTK_INSTALL_INCLUDE_DIR}
    COMPONENT Development
    )
endif()
