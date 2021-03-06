
include(ListToString)

set(proj python)

# Set dependency list
set(${proj}_DEPENDENCIES "")
if(NOT ${CMAKE_PROJECT_NAME}_USE_SYSTEM_python)
  list(APPEND ${proj}_DEPENDENCIES
    bzip2
    CTKAPPLAUNCHER
    zlib
    )
endif()
if(Slicer_USE_PYTHONQT_WITH_TCL)
  if(WIN32)
    list(APPEND ${proj}_DEPENDENCIES tcl)
  else()
    list(APPEND ${proj}_DEPENDENCIES tcl tk)
  endif()
endif()
if(PYTHON_ENABLE_SSL)
  list(APPEND ${proj}_DEPENDENCIES OpenSSL)
endif()

# Python stdlib and site-packages directories
# Note: These variables are set before the call to "ExternalProject_Include_Dependencies"
#       to ensure they are defined during the first time this file is included
#       by ExternalProjectDependency module.
#       That way, the variable are available in External_tcl.cmake despite the fact
#       the "tcl" project does NOT directly depend on "python".
set(PYTHON_STDLIB_SUBDIR lib/python2.7)
if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(PYTHON_STDLIB_SUBDIR Lib)
endif()
set(PYTHON_SITE_PACKAGES_SUBDIR ${PYTHON_STDLIB_SUBDIR}/site-packages)

# Include dependent projects if any
ExternalProject_Include_Dependencies(${proj} PROJECT_VAR proj DEPENDS_VAR ${proj}_DEPENDENCIES)

if(${CMAKE_PROJECT_NAME}_USE_SYSTEM_${proj})
  unset(PYTHON_INCLUDE_DIR CACHE)
  unset(PYTHON_LIBRARY CACHE)
  unset(PYTHON_EXECUTABLE CACHE)
  find_package(PythonLibs 2.7 REQUIRED)
  find_package(PythonInterp 2.7 REQUIRED)
  set(PYTHON_INCLUDE_DIR ${PYTHON_INCLUDE_DIRS})
  set(PYTHON_LIBRARY ${PYTHON_LIBRARIES})
  set(PYTHON_EXECUTABLE ${PYTHON_EXECUTABLE})
endif()

if((NOT DEFINED PYTHON_INCLUDE_DIR
   OR NOT DEFINED PYTHON_LIBRARY
   OR NOT DEFINED PYTHON_EXECUTABLE) AND NOT ${CMAKE_PROJECT_NAME}_USE_SYSTEM_${proj})

  set(python_SOURCE_DIR "${CMAKE_BINARY_DIR}/Python-2.7.13")

  ExternalProject_Add(python-source
    URL "https://www.python.org/ftp/python/2.7.13/Python-2.7.13.tgz"
    URL_MD5 "17add4bf0ad0ec2f08e0cae6d205c700"
    DOWNLOAD_DIR ${CMAKE_BINARY_DIR}
    SOURCE_DIR ${python_SOURCE_DIR}
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ""
    )

  set(EXTERNAL_PROJECT_OPTIONAL_CMAKE_CACHE_ARGS)
  set(EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS)

  if(Slicer_USE_PYTHONQT_WITH_TCL)
    list(APPEND EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS
      -DTCL_LIBRARY:FILEPATH=${TCL_LIBRARY}
      -DTCL_INCLUDE_PATH:PATH=${Slicer_TCL_DIR}/include
      -DTK_LIBRARY:FILEPATH=${TK_LIBRARY}
      -DTK_INCLUDE_PATH:PATH=${Slicer_TCL_DIR}/include
      )
  endif()

  if(PYTHON_ENABLE_SSL)
    list_to_string(${EP_LIST_SEPARATOR} "${OPENSSL_LIBRARIES}" EP_OPENSSL_LIBRARIES)
    list(APPEND EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS
      -DOPENSSL_INCLUDE_DIR:PATH=${OPENSSL_INCLUDE_DIR}
      -DOPENSSL_LIBRARIES:STRING=${EP_OPENSSL_LIBRARIES}
      )
  endif()

  if(APPLE)
    list(APPEND EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS
      -DCMAKE_BUILD_WITH_INSTALL_RPATH:BOOL=ON
      )
  endif()

  # Force modules that statically link to zlib or libbz2 to not be built-in.
  # Otherwise, when building in Debug configuration, the Python library--which
  # we force to build in Release configuration--would mix Debug and Release C
  # runtime libraries.
  if(WIN32)
    list(APPEND EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS
        # Depends on libbz2
        -DBUILTIN_BZ2:BOOL=OFF
        # Depends on zlib
        -DBUILTIN_BINASCII:BOOL=OFF
        -DBUILTIN_ZLIB:BOOL=OFF
      )
  endif()

  # Force python build to "Release"
  if(CMAKE_CONFIGURATION_TYPES)
    list(APPEND EXTERNAL_PROJECT_OPTIONAL_CMAKE_CACHE_ARGS
      -DCMAKE_CONFIGURATION_TYPES:STRING=Release
      )
    set(_build_command BUILD_COMMAND ${CMAKE_COMMAND} --build . --config Release)
    set(_install_command INSTALL_COMMAND ${CMAKE_COMMAND} --build . --config Release --target install)
  else()
    set(_build_command)
    set(_install_command)
    list(APPEND EXTERNAL_PROJECT_OPTIONAL_CMAKE_CACHE_ARGS
      -DCMAKE_BUILD_TYPE:STRING=Release
      )
  endif()

  ExternalProject_SetIfNotDefined(
    ${CMAKE_PROJECT_NAME}_${proj}_GIT_REPOSITORY
    "${EP_GIT_PROTOCOL}://github.com/python-cmake-buildsystem/python-cmake-buildsystem.git"
    QUIET
    )

  ExternalProject_SetIfNotDefined(
    ${CMAKE_PROJECT_NAME}_${proj}_GIT_TAG
    "16d41fe7aeb24c3e3fada6f888837276e03a7f3a"
    QUIET
    )

  set(EP_SOURCE_DIR ${CMAKE_BINARY_DIR}/${proj})
  set(EP_BINARY_DIR ${CMAKE_BINARY_DIR}/${proj}-build)
  set(EP_INSTALL_DIR ${CMAKE_BINARY_DIR}/${proj}-install)

  # If it applies, prepend "CMAKE_ARGS"
  if(NOT EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS STREQUAL "")
    set(EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS
      CMAKE_ARGS
      ${EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS})
  endif()

  ExternalProject_Add(${proj}
    ${${proj}_EP_ARGS}
    GIT_REPOSITORY "${${CMAKE_PROJECT_NAME}_${proj}_GIT_REPOSITORY}"
    GIT_TAG "${${CMAKE_PROJECT_NAME}_${proj}_GIT_TAG}"
    SOURCE_DIR ${EP_SOURCE_DIR}
    BINARY_DIR ${EP_BINARY_DIR}
    CMAKE_CACHE_ARGS
      -DCMAKE_CXX_COMPILER:FILEPATH=${CMAKE_CXX_COMPILER}
      #-DCMAKE_CXX_FLAGS:STRING=${ep_common_cxx_flags} # Not used
      -DCMAKE_C_COMPILER:FILEPATH=${CMAKE_C_COMPILER}
      -DCMAKE_C_FLAGS:STRING=${ep_common_c_flags}
      -DCMAKE_INSTALL_PREFIX:PATH=${EP_INSTALL_DIR}
      #-DBUILD_TESTING:BOOL=OFF
      -DBUILD_LIBPYTHON_SHARED:BOOL=ON
      -DUSE_SYSTEM_LIBRARIES:BOOL=OFF
      -DSRC_DIR:PATH=${python_SOURCE_DIR}
      -DDOWNLOAD_SOURCES:BOOL=OFF
      -DINSTALL_WINDOWS_TRADITIONAL:BOOL=OFF
      -DBZIP2_INCLUDE_DIR:PATH=${BZIP2_INCLUDE_DIR}
      -DBZIP2_LIBRARIES:FILEPATH=${BZIP2_LIBRARIES}
      -DZLIB_INCLUDE_DIR:PATH=${ZLIB_INCLUDE_DIR}
      -DZLIB_LIBRARY:FILEPATH=${ZLIB_LIBRARY}
      -DENABLE_TKINTER:BOOL=${Slicer_USE_PYTHONQT_WITH_TCL}
      -DENABLE_SSL:BOOL=${PYTHON_ENABLE_SSL}
      -DPatch_EXECUTABLE:FILEPATH=${Patch_EXECUTABLE}
      ${EXTERNAL_PROJECT_OPTIONAL_CMAKE_CACHE_ARGS}
    ${EXTERNAL_PROJECT_OPTIONAL_CMAKE_ARGS}
    ${_build_command}
    ${_install_command}
    DEPENDS
      python-source ${${proj}_DEPENDENCIES}
    )
  set(python_DIR ${CMAKE_BINARY_DIR}/${proj}-install)

  if(UNIX)
    set(python_IMPORT_SUFFIX so)
    if(APPLE)
      set(python_IMPORT_SUFFIX dylib)
    endif()
    set(slicer_PYTHON_SHARED_LIBRARY_DIR ${python_DIR}/lib)
    set(PYTHON_INCLUDE_DIR ${python_DIR}/include/python2.7)
    set(PYTHON_LIBRARY ${python_DIR}/lib/libpython2.7.${python_IMPORT_SUFFIX})
    set(PYTHON_EXECUTABLE ${python_DIR}/bin/SlicerPython)
    set(slicer_PYTHON_REAL_EXECUTABLE ${python_DIR}/bin/python)
  elseif(WIN32)
    set(slicer_PYTHON_SHARED_LIBRARY_DIR ${python_DIR}/bin)
    set(PYTHON_INCLUDE_DIR ${python_DIR}/include)
    set(PYTHON_LIBRARY ${python_DIR}/libs/python27.lib)
    set(PYTHON_EXECUTABLE ${python_DIR}/bin/SlicerPython.exe)
    set(slicer_PYTHON_REAL_EXECUTABLE ${python_DIR}/bin/python.exe)
  else()
    message(FATAL_ERROR "Unknown system !")
  endif()

  if(NOT ${CMAKE_PROJECT_NAME}_USE_SYSTEM_python)

    ExternalProject_Add_Step(${proj} configure_python_launcher
      COMMAND ${CMAKE_COMMAND}
        -DCMAKE_EXECUTABLE_SUFFIX:STRING=${CMAKE_EXECUTABLE_SUFFIX}
        -DCTKAppLauncher_DIR:PATH=${CTKAppLauncher_DIR}
        -DOPENSSL_EXPORT_LIBRARY_DIR:PATH=${OPENSSL_EXPORT_LIBRARY_DIR}
        -Dpython_DIR:PATH=${python_DIR}
        -DPYTHON_ENABLE_SSL:BOOL=${PYTHON_ENABLE_SSL}
        -DPYTHON_REAL_EXECUTABLE:FILEPATH=${slicer_PYTHON_REAL_EXECUTABLE}
        -DPYTHON_SHARED_LIBRARY_DIR:PATH=${slicer_PYTHON_SHARED_LIBRARY_DIR}
        -DPYTHON_SITE_PACKAGES_SUBDIR:STRING=${PYTHON_SITE_PACKAGES_SUBDIR}
        -DPYTHON_STDLIB_SUBDIR:STRING=${PYTHON_STDLIB_SUBDIR}
        -DSlicer_BIN_DIR:PATH=${Slicer_BIN_DIR}
        -DSlicer_BINARY_DIR:PATH=${Slicer_BINARY_DIR}
        -DSlicer_LIB_DIR:PATH=${Slicer_LIB_DIR}
        -DSlicer_SHARE_DIR:PATH=${Slicer_SHARE_DIR}
        -DSlicer_SOURCE_DIR:PATH=${Slicer_SOURCE_DIR}

        -P ${Slicer_SOURCE_DIR}/SuperBuild/python_configure_python_launcher.cmake
      DEPENDEES install
      )

    # Note: Install rules for SlicerPythonLauncherSettingsToInstall.ini and SlicerPython executable
    #       are specified in SlicerBlockInstallPython.cmake

    if(UNIX AND NOT APPLE)
      find_program(LSB_RELEASE_EXECUTABLE NAMES lsb_release)
      if(LSB_RELEASE_EXECUTABLE)
        ExternalProject_Add_Step(${proj} configure_lsb_release_wrapper
          COMMAND ${CMAKE_COMMAND}
            -DCTKAppLauncher_DIR:PATH=${CTKAppLauncher_DIR}
            -DLSB_RELEASE_EXECUTABLE:PATH=${LSB_RELEASE_EXECUTABLE}
            -DPYTHON_REAL_EXECUTABLE:FILEPATH=${slicer_PYTHON_REAL_EXECUTABLE}
            -P ${Slicer_SOURCE_DIR}/SuperBuild/python_configure_lsb_release_wrapper.cmake
          DEPENDEES install
          )
      endif()
    endif()
  endif()

  if(NOT DEFINED PYTHON_VALGRIND_SUPPRESSIONS_FILE)
    set(PYTHON_VALGRIND_SUPPRESSIONS_FILE ${python_SOURCE_DIR}/Misc/valgrind-python.supp)
  endif()
  mark_as_superbuild(PYTHON_VALGRIND_SUPPRESSIONS_FILE:FILEPATH)

  #-----------------------------------------------------------------------------
  # Slicer Launcher setting specific to build tree

  set(_lib_subdir lib)
  if(WIN32)
    set(_lib_subdir bin)
  endif()

  # library paths
  set(${proj}_LIBRARY_PATHS_LAUNCHER_BUILD ${python_DIR}/${_lib_subdir})
  mark_as_superbuild(
    VARS ${proj}_LIBRARY_PATHS_LAUNCHER_BUILD
    LABELS "LIBRARY_PATHS_LAUNCHER_BUILD"
    )

  # paths
  set(${proj}_PATHS_LAUNCHER_BUILD ${python_DIR}/bin)
  mark_as_superbuild(
    VARS ${proj}_PATHS_LAUNCHER_BUILD
    LABELS "PATHS_LAUNCHER_BUILD"
    )

  set(${proj}_PYTHONPATH_LAUNCHER_BUILD
    ${python_DIR}/${PYTHON_STDLIB_SUBDIR}
    ${python_DIR}/${PYTHON_STDLIB_SUBDIR}/lib-dynload
    ${python_DIR}/${PYTHON_SITE_PACKAGES_SUBDIR}
    )
  mark_as_superbuild(
    VARS ${proj}_PYTHONPATH_LAUNCHER_BUILD
    LABELS "PYTHONPATH_LAUNCHER_BUILD"
    )

  # environment variables
  set(${proj}_ENVVARS_LAUNCHER_BUILD
    "PYTHONHOME=${python_DIR}"
    "PYTHONNOUSERSITE=1"
    )
  mark_as_superbuild(
    VARS ${proj}_ENVVARS_LAUNCHER_BUILD
    LABELS "ENVVARS_LAUNCHER_BUILD"
    )

  #-----------------------------------------------------------------------------
  # Slicer Launcher setting specific to install tree

  # library paths
  if(UNIX)
    # On windows, python libraries are installed along with the executable
    set(${proj}_LIBRARY_PATHS_LAUNCHER_INSTALLED <APPLAUNCHER_DIR>/lib/Python/lib)
    mark_as_superbuild(
      VARS ${proj}_LIBRARY_PATHS_LAUNCHER_INSTALLED
      LABELS "LIBRARY_PATHS_LAUNCHER_INSTALLED"
      )
  endif()

  # pythonpath
  set(${proj}_PYTHONPATH_LAUNCHER_INSTALLED
    <APPLAUNCHER_DIR>/lib/Python/${PYTHON_STDLIB_SUBDIR}
    <APPLAUNCHER_DIR>/lib/Python/${PYTHON_STDLIB_SUBDIR}/lib-dynload
    <APPLAUNCHER_DIR>/lib/Python/${PYTHON_SITE_PACKAGES_SUBDIR}
    )
  mark_as_superbuild(
    VARS ${proj}_PYTHONPATH_LAUNCHER_INSTALLED
    LABELS "PYTHONPATH_LAUNCHER_INSTALLED"
    )

  # environment variables
  set(${proj}_ENVVARS_LAUNCHER_INSTALLED
    "PYTHONHOME=<APPLAUNCHER_DIR>/lib/Python"
    "PYTHONNOUSERSITE=1"
    )
  mark_as_superbuild(
    VARS ${proj}_ENVVARS_LAUNCHER_INSTALLED
    LABELS "ENVVARS_LAUNCHER_INSTALLED"
    )

else()
  ExternalProject_Add_Empty(${proj} DEPENDS ${${proj}_DEPENDENCIES})
endif()

mark_as_superbuild(
  VARS
    PYTHON_STDLIB_SUBDIR:STRING
    PYTHON_SITE_PACKAGES_SUBDIR:STRING
  )

mark_as_superbuild(
  VARS ${CMAKE_PROJECT_NAME}_USE_SYSTEM_${proj}
  LABELS "USE_SYSTEM"
  )

mark_as_superbuild(
  VARS
    PYTHON_EXECUTABLE:FILEPATH
    PYTHON_INCLUDE_DIR:PATH
    PYTHON_LIBRARY:FILEPATH
  LABELS "FIND_PACKAGE"
  )

ExternalProject_Message(${proj} "PYTHON_EXECUTABLE:${PYTHON_EXECUTABLE}")
ExternalProject_Message(${proj} "PYTHON_INCLUDE_DIR:${PYTHON_INCLUDE_DIR}")
ExternalProject_Message(${proj} "PYTHON_LIBRARY:${PYTHON_LIBRARY}")

if(WIN32)
  set(PYTHON_DEBUG_LIBRARY ${PYTHON_LIBRARY})
  mark_as_superbuild(VARS PYTHON_DEBUG_LIBRARY LABELS "FIND_PACKAGE")
  ExternalProject_Message(${proj} "PYTHON_DEBUG_LIBRARY:${PYTHON_DEBUG_LIBRARY}")
endif()

#!
#! ExternalProject_PythonModule_InstallTreeCleanup(<proj> <modname> "[<dirname1>;[<dirname2>;[...]]]"))
#!
#! Add post-install cleanup step to project <proj>. For each <dirname>, this step will
#! import the module <modname> and delete the <dirname> folder located in the module
#! directory.
#!
#! This function is particularly useful to remove option and too long directories
#! from python module install tree. This function was first developer to address
#! issue #3749.
#!
function(ExternalProject_PythonModule_InstallTreeCleanup proj modname dirnames)
  ExternalProject_Get_Property(${proj} tmp_dir)
  set(_file "${tmp_dir}/${proj}_install_tree_cleanup.py")
  set(_content
"
${${proj}_EP_PYTHONMODULE_INSTALL_TREE_CLEANUP_CODE_BEFORE_IMPORT}
import ${modname}
import os.path
import shutil
")
  foreach(dirname ${dirnames})
    set(_content "${_content}
dir=os.path.join(os.path.dirname(${modname}.__file__), '${dirname}')
print('Removing %s' % dir)
shutil.rmtree(dir, True)
print('Removing %s [done]' % dir)
")
  endforeach()
  file(WRITE ${_file} ${_content})

  ExternalProject_Add_Step(${proj} install_tree_cleanup
    COMMAND ${PYTHON_EXECUTABLE} ${_file}
    COMMENT "Performing install tree cleanup for '${proj}'"
    DEPENDEES install
    )
endfunction()
