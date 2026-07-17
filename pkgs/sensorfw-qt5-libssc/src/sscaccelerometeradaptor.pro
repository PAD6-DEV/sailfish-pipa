TEMPLATE = lib
TARGET = sscaccelerometeradaptor-qt5
CONFIG += plugin link_pkgconfig hide_symbols
QT -= gui
QT += core dbus

PKGCONFIG += glib-2.0 gio-2.0 libssc

HEADERS += \
    sscaccelerometeradaptor.h \
    sscaccelerometeradaptorplugin.h

SOURCES += \
    sscaccelerometeradaptor.cpp \
    sscaccelerometeradaptorplugin.cpp

INCLUDEPATH += $$system(pkg-config --variable=includedir sensord-qt5 2>/dev/null)
INCLUDEPATH += /usr/include/sensord-qt5 /usr/include/sensord-qt5/datatypes

LIBS += -lsensorfw -lsensordatatypes-qt5

isEmpty(PLUGINPATH) {
    PLUGINPATH = $$[QT_INSTALL_LIBS]/sensord-qt5
}
target.path = $$PLUGINPATH
INSTALLS += target
