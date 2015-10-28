configure_file(appcenter.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter.desktop)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcenter.desktop DESTINATION share/applications)
