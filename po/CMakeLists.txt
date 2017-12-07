include (Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    ../daemon
    DESKTOP_FILES
        ${CMAKE_BINARY_DIR}/data/${DESKTOP_FILE}.in
    APPDATA_FILES
        ../data/${CMAKE_PROJECT_NAME}.appdata.xml.in
)
