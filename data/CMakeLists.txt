include (Translations)
configure_file(org.pantheon.appcenter.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.appcenter.desktop.in)
configure_file(org.pantheon.appcenter-daemon.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.appcenter-daemon.desktop)
configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.appcenter.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.appcenter.desktop ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation(${CMAKE_CURRENT_SOURCE_DIR}/appcenter.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter.appdata.xml ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.appcenter.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/org.pantheon.appcenter-daemon.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcenter.appdata.xml DESTINATION share/appdata)

