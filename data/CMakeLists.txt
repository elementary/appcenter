include (Translations)
configure_file(appcenter.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter.desktop.in)
configure_file(appcenter-daemon.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter-daemon.desktop)
configure_file(org.pantheon.AppCenter.service.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.AppCenter.service)
configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/appcenter.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter.desktop ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation(${CMAKE_CURRENT_SOURCE_DIR}/appcenter.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter.appdata.xml ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcenter.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcenter-daemon.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.AppCenter.service DESTINATION share/dbus-1/services)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcenter.appdata.xml DESTINATION share/appdata)

