
# Defaults for installation directories. No trailing slash.
prefix              ?= /usr/local
sbindir             ?= $(prefix)/sbin
plugindir           ?= $(prefix)/lib/nagios/plugins

# Use build directory in current directory, if invoked manually, and in
# central build directory otherwise.
ifeq ($(MAKELEVEL), 0)
    builddir        := build
else
    builddir        ?= build
    builddir        := $(builddir)/$(notdir $(CURDIR))
endif
srcdir              := src

project_top         := $(plugindir)/send_cache $(sbindir)/write-plugin-cache

programs            := top

include ./src/common-build/Makefile.common

