include (Translations)
add_translations_directory (${GETTEXT_PACKAGE})
add_translations_catalog (${GETTEXT_PACKAGE}
    ../src
    ../daemon
    DESKTOP_FILES
        ${CMAKE_BINARY_DIR}/data/appcenter.desktop.in
    APPDATA_FILES
        ../data/appcenter.appdata.xml.in
    SCHEMA_FILES
        ../schemas/org.pantheon.appcenter.gschema.xml.in
)
