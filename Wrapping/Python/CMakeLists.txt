if (WIN32)
  if (building_vtkpythonrc)
    # XXX: With long paths, this command line can get too long because of all
    # the include directories required for vtkpython to work. The thing is that
    # CMake's RC rule in Ninja does not support response files, so the path can
    # end up way too long. Since this doesn't need those include paths, act as
    # if it is in a separate directory to avoid all the include_directories
    # used here.
    add_library(vtkpythonrc STATIC dummy.cxx vtkpython.rc)
    return()
  elseif (CMAKE_GENERATOR MATCHES "Visual Studio")
    set(extra_srcs vtkpython.rc)
  else ()
    set(building_vtkpythonrc TRUE)
    set(extra_links vtkpythonrc)
    # Make a separate directory scope for building vtkpythonrc.
    add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/vtkpythonrc")
  endif ()
endif ()

# This is where we actually wrap the modules that have requested it.
include(vtkModulePythonWrapping)

# for vtk_python_module() and vtk_python_package()
include(vtkModuleMacrosPython)

option(VTK_ENABLE_VTKPYTHON "Enable vtkpython and pvtkpython binaries" ON)
mark_as_advanced(VTK_ENABLE_VTKPYTHON)
if(VTK_ENABLE_VTKPYTHON)

vtk_module_load(vtkWrappingPythonCore)
vtk_module_load(vtkPython)
vtk_module_load(vtkPythonInterpreter)
include_directories(${CMAKE_CURRENT_BINARY_DIR}
  ${VTK_SOURCE_DIR}/Utilities
  ${vtkPython_INCLUDE_DIRS}
  ${vtkWrappingPythonCore_INCLUDE_DIRS})

if(UNIX)
  find_library(PYTHON_UTIL_LIBRARY
    NAMES util
    DOC "Utility library needed for vtkpython")
  mark_as_advanced(PYTHON_UTIL_LIBRARY)
endif()

# Generate the header which initializes Python modules when BUILD_SHARED_LIBS is
# OFF. The py_module_dependencies will be set to the libraries we should link
# against when we use the vtkpythonmodules.h file.
vtk_write_python_modules_header_for_wrapped_modules(
  "${CMAKE_CURRENT_BINARY_DIR}/vtkpythonmodules.h"
  py_module_dependencies)

# Create the VTK/Python executable
add_executable(vtkpython vtkPythonAppInit.cxx ${extra_srcs})

if (WIN32)
  target_link_libraries(vtkpython ${extra_links})
endif ()

unset(VTKPYTHON_LINK_FLAGS)
unset(VTKPYTHON_LINK_LIBS)

if(CMAKE_SYSTEM_NAME MATCHES "AIX")
  get_filename_component(CMAKE_PYTHON_LIB_PREFIX "${PYTHON_LIBRARY}" PATH)
  find_file(CMAKE_PYTHON_LIBRARY_EXPORT python.exp "${CMAKE_PYTHON_LIB_PREFIX}")
  if(CMAKE_PYTHON_LIBRARY_EXPORT)
    set(VTKPYTHON_LINK_FLAGS "-Wl,-bE:${CMAKE_PYTHON_LIBRARY_EXPORT}")
  endif()
endif()

# Link against all the kit wrappers.
list(APPEND VTKPYTHON_LINK_LIBS vtkWrappingPythonCore vtkPythonInterpreter)

if(PYTHON_UTIL_LIBRARY)
  list(APPEND VTKPYTHON_LINK_LIBS ${PYTHON_UTIL_LIBRARY})
endif()

set(VTKPYTHON_LINK_LIBS ${VTKPYTHON_LINK_LIBS} ${py_module_dependencies})

# Link to rt to prevent undefined symbol 'fdatasync'
if(CMAKE_SYSTEM MATCHES "SunOS.*" AND NOT CMAKE_COMPILER_IS_GNUCXX)
  find_library(VTK_SUNCC_RT_LIBRARY rt)
  if(VTK_SUNCC_RT_LIBRARY)
    set(VTKPYTHON_LINK_LIBS ${VTKPYTHON_LINK_LIBS} ${VTK_SUNCC_RT_LIBRARY})
  endif()
endif()

if(HAVE_PTHREAD_H AND CMAKE_USE_PTHREADS)
  list(APPEND VTKPYTHON_LINK_LIBS ${CMAKE_THREAD_LIBS_INIT})
endif()

# FIXME: Is this needed here?
if(VTK_USE_FFMPEG_ENCODER)
  list(APPEND VTKPYTHON_LINK_LIBS ${FFMPEG_BASIC_LIBRARIES})
endif()

# Add the libPython.dylib file and link explicitly against it.
# This is needed because this is a new python executable, which needs it's libraries.
find_package(PythonLibs REQUIRED)
list(APPEND VTKPYTHON_LINK_LIBS ${vtkPython_LIBRARIES})

target_link_libraries(vtkpython ${VTKPYTHON_LINK_LIBS})

unset(PVTKPYTHON_EXECUTABLE)
# Create the pvtkpython Python wrapper executable with MPI support.
if(TARGET vtkParallelMPI)
  find_package(MPI REQUIRED)
  include_directories(${MPI_C_INCLUDE_PATH})
  set(MPI_LIBRARIES ${MPI_C_LIBRARIES})
  if(MPI_CXX_LIBRARIES)
    set(MPI_LIBRARIES ${MPI_LIBRARIES} ${MPI_CXX_LIBRARIES})
  endif()

  # Needed for mpich 2
  add_definitions("-DMPICH_IGNORE_CXX_SEEK")

  set(PVTKPYTHON_EXECUTABLE pvtkpython)
  add_executable(pvtkpython vtkParaPythonAppInit.cxx)
  target_link_libraries(pvtkpython ${VTKPYTHON_LINK_LIBS} vtkParallelMPI
    ${MPI_LIBRARIES})
endif()

endif()

# "Configure" files that need to be configured, including generation of the *.py
# files for each of the enabled VTK modules.
# We don't directly configure to `VTK_BUILD_PYTHON_MODULES_DIR` since of VS generator, the
# `VTK_BUILD_PYTHON_MODULES_DIR` depends on build configuration not known at configure time.
# So we configure into a temporary location and then copy those files over to
# `VTK_BUILD_PYTHON_MODULES_DIR` using a custom_command.

# Wrapping/Python/vtk/*.py
unset(VTK_PYTHON_IMPORT_ALL)
unset(configured_py_files)
foreach(module IN LISTS VTK_PYTHON_MODULES_AND_KITS)
  set(VTK_PYTHON_IMPORT_ALL
    "${VTK_PYTHON_IMPORT_ALL}from .${module} import *\n")
  configure_file(vtkmodules/module.py.in
    "${CMAKE_CURRENT_BINARY_DIR}/vtkmodules/${module}.py" @ONLY)
  list(APPEND configured_py_files "${CMAKE_CURRENT_BINARY_DIR}/vtkmodules/${module}.py")
endforeach()
configure_file(vtkmodules/all.py.in
  "${CMAKE_CURRENT_BINARY_DIR}/vtkmodules/all.py" @ONLY)
list(APPEND configured_py_files "${CMAKE_CURRENT_BINARY_DIR}/vtkmodules/all.py")

# Kit module adapters
foreach(kit IN LISTS vtk_kits)
  set(_module_kit ${kit}${VTK_KIT_SUFFIX})
  foreach(dep IN LISTS _${kit}_modules)
    configure_file(vtkmodules/kit_module.py.in
      "${CMAKE_CURRENT_BINARY_DIR}/vtkmodules/${dep}.py" @ONLY)
    list(APPEND configured_py_files "${CMAKE_CURRENT_BINARY_DIR}/vtkmodules/${dep}.py")
  endforeach()
  unset(_module_kit)
endforeach()

# Now copy configured files to build-cfg specific dir.
add_custom_command(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/copy-complete"
  COMMAND ${CMAKE_COMMAND}
          -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}/vtkmodules" "${VTK_BUILD_PYTHON_MODULES_DIR}/vtkmodules"
  COMMAND ${CMAKE_COMMAND}
          -E touch "${CMAKE_CURRENT_BINARY_DIR}/copy-complete"
  DEPENDS ${configured_py_files})


# Build all py files that form the `vtk` package.
vtk_python_package(vtkpython_pyc vtkmodules DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/copy-complete")
vtk_python_module(vtk_python_module vtk.py)

# Let's add a target that generates the `vtk` python package
# including all the platform dependent and independent modules.
set(module_Python_libs)
foreach(module IN LISTS VTK_PYTHON_MODULES_AND_KITS)
  list(APPEND module_Python_libs ${module}Python)
endforeach()

add_custom_target(vtk_python_package)
add_dependencies(vtk_python_package vtkpython_pyc ${module_Python_libs})
unset(module_Python_libs)

if(TARGET vtkpython)
  add_dependencies(vtkpython vtk_python_package)
endif()
if(TARGET pvtkpython)
  add_dependencies(pvtkpython vtk_python_package)
endif()

# If no runtime is to be installed then do not install python modules.
if(NOT VTK_INSTALL_NO_RUNTIME)
  # Install the conveniently configured python interpretters
  if(NOT VTK_INSTALL_NO_PYTHON_EXES AND VTK_ENABLE_VTKPYTHON)
    # Install the vtkpython executable
    install(TARGETS vtkpython
      DESTINATION ${VTK_INSTALL_RUNTIME_DIR})

    if(PVTKPYTHON_EXECUTABLE)
      # Install the mpi enabled vtkpython executable
      install(TARGETS pvtkpython
        DESTINATION ${VTK_INSTALL_RUNTIME_DIR})
    endif()
  endif()
endif()
