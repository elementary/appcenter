configure_file(appcenter.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter.desktop)
configure_file(appcenter.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter.appdata.xml)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcenter.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcenter.appdata.xml DESTINATION share/appdata)
