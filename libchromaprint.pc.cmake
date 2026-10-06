prefix=@CMAKE_INSTALL_PREFIX@
exec_prefix=@CMAKE_INSTALL_FULL_BINDIR@
libdir=@CMAKE_INSTALL_FULL_LIBDIR@
includedir=@CMAKE_INSTALL_FULL_INCLUDEDIR@

Name: @PROJECT_NAME@
Description: Audio fingerprint library
URL: http://acoustid.org/chromaprint
Version: @PROJECT_VERSION@
Requires.private: @CHROMAPRINT_PC_REQUIRES_PRIVATE@
Libs: -L${libdir} -lchromaprint
Libs.private: @CHROMAPRINT_PC_LIBS_PRIVATE@
Cflags: -I${includedir}

