# For now, load the python libraries through vtkWrapPython.cmake (eventually,
# FindPythonLibs.cmake should be fixed so it can be used here directly)
set(VTK_WRAP_PYTHON_FIND_LIBS ON)
include(vtkWrapPython)

# Check minimum versions of Python
set(_message "Python ${PYTHON_MAJOR_VERSION}.${PYTHON_MINOR_VERSION} is too old, use Python 2.7 or 3.3+")
set(_warning "Python ${PYTHON_MAJOR_VERSION}.${PYTHON_MINOR_VERSION} support is deprecated, use Python 2.7 or 3.3+")
if(PYTHON_MAJOR_VERSION EQUAL 3)
  if(PYTHON_MINOR_VERSION LESS 2)
    message(FATAL_ERROR ${_message})
  elseif(NOT VTK_LEGACY_SILENT AND PYTHON_MINOR_VERSION LESS 3)
    message(WARNING ${_warning})
  endif()
else()
  if(PYTHON_MINOR_VERSION LESS 6)
    message(FATAL_ERROR ${_message})
  elseif(NOT VTK_LEGACY_SILENT AND PYTHON_MINOR_VERSION LESS 7)
    message(WARNING ${_warning})
  endif()
endif()

if(CMAKE_CONFIGURATION_TYPES)
  # For build systems with configuration types e.g. Xcode/Visual Studio,
  # we rely on generator expressions.
  if(CMAKE_VERSION VERSION_LESS 3.4)
    message(FATAL_ERROR "CMake 3.4 or newer if needed for your generator.")
  endif()
  set(VTK_BUILD_PYTHON_MODULES_DIR
    "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/$<CONFIG>/${VTK_PYTHON_SITE_PACKAGES_SUFFIX}"
    CACHE INTERNAL "Directory where python modules will be built")
else()
  set(VTK_BUILD_PYTHON_MODULES_DIR
    "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${VTK_PYTHON_SITE_PACKAGES_SUFFIX}"
    CACHE INTERNAL "Directory where python modules will be built")
endif()

if(WIN32 AND NOT CYGWIN)
  set(VTK_INSTALL_PYTHON_MODULES_DIR
    "${VTK_INSTALL_RUNTIME_DIR}/${VTK_PYTHON_SITE_PACKAGES_SUFFIX}"
    CACHE INTERNAL "Directory where python modules will be installed")
else()
  set(VTK_INSTALL_PYTHON_MODULES_DIR
    "${VTK_INSTALL_LIBRARY_DIR}/${VTK_PYTHON_SITE_PACKAGES_SUFFIX}"
    CACHE INTERNAL "Directory where python modules will be installed")
endif()
