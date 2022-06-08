# -*- Makefile -*-
#
# MIT License
#
# Copyright (C) 2000-2022  Wizzer Works
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#  For information concerning this Makefile, contact Mark S. Millard,
#  of Wizzer Works at msm@wizzerworks.com.
#
################################################################################
#
# Makefile for tools/build to build RPM distribution package
#
# Three products are built:
#   o wz_toolroot      - cross platform build environment tools
#
################################################################################

ifndef WORKAREA
WORKAREA = $HOME
endif
ifndef WZDEV_DIR
WZDEV_DIR = $(HOME)/tools
endif

IBDIR = $(WZDEV_DIR)/installBuilder
IBBASEDIR = ..
IBVERIFYCOLLECT = perl -w $(IBDIR)/bin/ibVerifyCollection.pl
IBBUILD = perl -w $(IBDIR)/bin/ibBuild.pl -baseDir $(IBBASEDIR)

default rawidb: collect verifyCollect

collect:
	rm -f collect.raw
	cd ..; make collect

collect.raw : collect

verifyCollect: collect.master collect.raw
	rm -f extra missing
	$(IBVERIFYCOLLECT) collect.master collect.raw

build: verifyCollect
	$(IBBUILD) -collect collect.master \
                   -spec spec.linux \
                   -target linux \
                   -relocate /usr/local \
                   -ibDir $(IBDIR)

clean: _FORCE
	rm -rf instcruft
	rm -f collect.raw

clobber: clean
	rm -rf *.rpm

_FORCE:
