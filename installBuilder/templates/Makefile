# -*- Makefile -*-
#
#  Copyright (C) 2000,2002  Wizzer Works
#
#  This Makefile is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  This Makefile is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this Makefile; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#  For information concerning this Makefile, contact Mark S. Millard,
#  of Wizzer Works at msm@wizzer.com.
#
###########################################################################
#
# Makefile for installing InstallBuilder templates.
#
# $Id: Makefile,v 1.1.1.1 2003/03/28 08:30:10 msm Exp $
#
###########################################################################

DEPTH = ../..
ifndef WORKAREA
WORKAREA = $HOME
endif
ifndef WZDEV_DIR
WZDEV_DIR = $(WORKAREA)/tools
endif
include $(DEPTH)/include/make/commondefs

INSTALL = /usr/bin/install

IBDIR = $(WZDEV_DIR)/installBuilder
IBBASEDIR = $(DEPTH)
IBCOLLECT = perl -w $(IBDIR)/bin/ibCollect.pl -baseDir $(IBBASEDIR)

SUBDIRS = installshielddist

SOURCES = \
	ibBody.rul \
	ibDecls.rul \
	rpmBuildScript.txt \
	rpmInstallScript.txt \
	rpmPreamble.txt \
	rpmPrepScript.txt \
	$(NULL)

install:
	$(INSTALL) -d $(ROOT)/usr/local/wizzer/installBuilder/templates
	$(INSTALL) $(SOURCES) $(ROOT)/usr/local/wizzer/installBuilder/templates
	$(SUBDIRS_RULE)

include $(COMMONRULES)

collect:
	$(IBCOLLECT) -log $(DEPTH)/build/collect.raw \
                     -srcDir . \
                     -destDir "wizzer/installBuilder/templates" \
                     -tags "TOOL" \
                     $(SOURCES)
	$(SUBDIRS_RULE)
