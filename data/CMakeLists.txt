include (Translations)
configure_file(io.elementary.appcenter.desktop.in.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.appcenter.desktop.in)
configure_file(io.elementary.appcenter-daemon.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.appcenter-daemon.desktop)
configure_file_translation(${CMAKE_CURRENT_BINARY_DIR}/io.elementary.appcenter.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.appcenter.desktop ${CMAKE_SOURCE_DIR}/po/)
configure_file_translation(${CMAKE_CURRENT_SOURCE_DIR}/appcenter.appdata.xml.in ${CMAKE_CURRENT_BINARY_DIR}/appcenter.appdata.xml ${CMAKE_SOURCE_DIR}/po/)

install (FILES ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.appcenter.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/io.elementary.appcenter-daemon.desktop DESTINATION share/applications)
install (FILES ${CMAKE_CURRENT_BINARY_DIR}/appcenter.appdata.xml DESTINATION share/metainfo)

