TEMPLATE = app
TARGET = imageview
QT = core gui widgets multimedia

CONFIG += release console
QMAKE_CFLAGS +=
QMAKE_CXXFLAGS +=

HEADERS += mainwin.h
SOURCES += imageview.cc mainwin.cc
