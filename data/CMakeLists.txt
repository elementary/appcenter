configure_file(appcenter.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter.desktop)
configure_file(appcenter-daemon.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter-daemon.desktop)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcenter.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcenter-daemon.desktop DESTINATION share/applications)
install (FILES appcenter.appdata.xml DESTINATION share/appdata)
