
include(vtkPythonWrapping)

get_property(VTK_PYTHON_MODULES GLOBAL PROPERTY VTK_PYTHON_WRAPPED)

# Get the include directories for the module and all its dependencies.
macro(vtk_include_recurse module)
  _vtk_module_config_recurse("${module}_PYTHON" ${module})
  include_directories(${${module}_PYTHON_INCLUDE_DIRS})
endmacro()


set(VTK_PYTHON_MODULES_AND_KITS ${VTK_PYTHON_MODULES})
set(_vtk_python_modules_only ${VTK_PYTHON_MODULES})

if(VTK_ENABLE_KITS)
  set(_vtk_kits_with_suffix)
  set(VTK_KIT_SUFFIX "Kit") # Required to avoid conflict with targets like vtkFiltersPython
  # Create list of module that do not belong to any kits
  foreach(kit IN LISTS vtk_kits)
    # XXX Variable '_${kit}_modules' is set in vtkModuleTop.cmake
    list(REMOVE_ITEM _vtk_python_modules_only ${_${kit}_modules})
    list(APPEND _vtk_kits_with_suffix ${kit}${VTK_KIT_SUFFIX})
  endforeach()
  set(VTK_PYTHON_MODULES_AND_KITS ${_vtk_kits_with_suffix} ${_vtk_python_modules_only})

  # Create dependency lists for kits (suffix: _DEPENDS). The function
  # vtk_add_python_wrapping_libary uses these lists.
  #
  # Additionally, create subsets of the full dependency lists that contain only
  # Python-wrapped kits and modules (suffix: _PYTHON_DEPENDS). These lists are
  # used to topologically sort the dependency graph.
  foreach(kit IN LISTS vtk_kits)
    set(_module_depends)
    foreach(module IN LISTS _${kit}_modules)
      vtk_module_load(${module})
      list(APPEND _module_depends ${${module}_DEPENDS})
    endforeach()

    set(_kit_depends)
    foreach(dep IN LISTS _module_depends)
      if(${dep}_KIT)
        list(APPEND _kit_depends ${${dep}_KIT}${VTK_KIT_SUFFIX})
      else()
        list(APPEND _kit_depends ${dep})
      endif()
    endforeach()
    list(REMOVE_DUPLICATES _kit_depends)
    set(${kit}${VTK_KIT_SUFFIX}_DEPENDS ${_kit_depends})

    set(_kit_python_depends)
    foreach(module IN LISTS ${kit}${VTK_KIT_SUFFIX}_DEPENDS)
      list(FIND VTK_PYTHON_MODULES_AND_KITS ${module} _module_index)
      if (_module_index GREATER -1)
        list(APPEND _kit_python_depends ${module})
      endif()
    endforeach()
    list(REMOVE_DUPLICATES _kit_python_depends)
    set(${kit}${VTK_KIT_SUFFIX}_PYTHON_DEPENDS ${_kit_python_depends})
  endforeach()

  # Create dependency lists for modules that also consider any dependent kits
  # (suffix: _DEPENDS_WITH_KITS). These lists are used to override
  # <module>_DEPENDS when calling vtk_add_python_wrapping_library.
  #
  # Additionally, create subsets of the full dependency lists that contain only
  # Python-wrapped kits and modules (suffix: _PYTHON_DEPENDS). These lists are
  # used to topologically sort the dependency graph.
  foreach(module IN LISTS _vtk_python_modules_only)
    vtk_module_load(${module})
    set(_saved_${module}_DEPENDS ${${module}_DEPENDS})

    set(_module_depends_with_kits)
    foreach(dep IN LISTS ${module}_DEPENDS)
      if(${dep}_KIT)
        list(APPEND _module_depends_with_kits ${${dep}_KIT}${VTK_KIT_SUFFIX})
      else()
        list(APPEND _module_depends_with_kits ${dep})
      endif()
    endforeach()
    list(REMOVE_DUPLICATES _module_depends_with_kits)
    set(${module}_DEPENDS_WITH_KITS ${_module_depends_with_kits})

    set(_module_python_depends)
    foreach(module IN LISTS ${module}_DEPENDS_WITH_KITS)
      list(FIND VTK_PYTHON_MODULES_AND_KITS ${module} _module_index)
      if (_module_index GREATER -1)
        list(APPEND _module_python_depends ${module})
      endif()
    endforeach()
    if(_module_python_depends)
      list(REMOVE_DUPLICATES _module_python_depends)
    endif()
    set(${module}_PYTHON_DEPENDS ${_module_python_depends})
  endforeach()

  # Create list of kits and modules to wrap, ordered to satisfy dependencies.
  include(${VTK_CMAKE_DIR}/TopologicalSort.cmake)
  set(_vtk_python_wrapping_work_list ${VTK_PYTHON_MODULES_AND_KITS})
  topological_sort(_vtk_python_wrapping_work_list "" _PYTHON_DEPENDS)

  # Wrap kits and modules.
  foreach(target IN LISTS _vtk_python_wrapping_work_list)
    # Determine whether target is a kit or module
    string(REGEX REPLACE "(.+)${VTK_KIT_SUFFIX}\$" "\\1" _stripped_target ${target})
    if(_${_stripped_target}_is_kit)
      # Wrap kit
      set(kit ${_stripped_target})
      set(kit_srcs)
      foreach(module IN LISTS _${kit}_modules)
        vtk_module_headers_load(${module})
        vtk_include_recurse(${module})
      endforeach()
      vtk_add_python_wrapping("${_${kit}_modules}" kit_srcs ${kit}${VTK_KIT_SUFFIX})
      vtk_add_python_wrapping_library(${kit}${VTK_KIT_SUFFIX} kit_srcs ${_${kit}_modules})
    else()
      # Wrap module
      set(module ${_stripped_target})
      vtk_module_headers_load(${module})
      vtk_include_recurse(${module})
      vtk_add_python_wrapping(${module} module_srcs)
      # Override module dependency list for vtk_add_python_wrapping_library
      set(${module}_DEPENDS ${${module}_DEPENDS_WITH_KITS})
      vtk_add_python_wrapping_library(${module} module_srcs ${module})
      set(${module}_DEPENDS ${_saved_${module}_DEPENDS})
    endif()
  endforeach()

  # Ensure that original module dependency lists are restored
  foreach(module IN LISTS _vtk_python_modules_only)
    set(${module}_DEPENDS ${_saved_${module}_DEPENDS})
    unset(_saved_${module}_DEPENDS)
  endforeach()

else(VTK_ENABLE_KITS)
  # Loop through all modules that should be wrapped, and wrap them.
  foreach(module IN LISTS _vtk_python_modules_only)
    vtk_module_load(${module})
    vtk_module_headers_load(${module})
    vtk_include_recurse(${module})
    vtk_add_python_wrapping(${module} module_srcs)
    vtk_add_python_wrapping_library(${module} module_srcs ${module})
  endforeach()
endif(VTK_ENABLE_KITS)

vtk_module_load(vtkWrappingPythonCore)
vtk_module_load(vtkPython)
include_directories(${vtkWrappingPythonCore_INCLUDE_DIRS}
  ${vtkPython_INCLUDE_DIRS})
