configure_file(appcentre.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/appcentre.desktop)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcentre.desktop DESTINATION share/applications)
