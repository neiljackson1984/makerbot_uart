getFullyQualifiedWindowsStylePath=$(shell cygpath --windows --absolute "$(1)")
unslashedDir=$(patsubst %/,%,$(dir $(1)))
pathOfThisMakefile=$(call unslashedDir,$(lastword $(MAKEFILE_LIST)))
sources:=$(wildcard ${pathOfThisMakefile}/*.sh)
destinationDirectoryOnTheMakerbot:=/home/usb_storage/
makerbotHost:=makerbot.ad.autoscaninc.com
makerbotUsername:=root

SHELL=sh

.PHONY: default
default: $(sources)
	@echo "====== BUILDING $@ from $< ======= "
	# @ls -al $<
	pscp "$(call getFullyQualifiedWindowsStylePath,$<)" "${makerbotUsername}@${makerbotHost}:${destinationDirectoryOnTheMakerbot}$(notdir $<)"
	# # ssh ${makerbotUsername}@${makerbotHost} "chmod ugo+x ${destinationDirectoryOnTheMakerbot}$(notdir $<)"
	# kitty -ssh ${makerbotUsername}@${makerbotHost} -cmd "chmod ugo+x ${destinationDirectoryOnTheMakerbot}$(notdir $<); exit"
	# the file seems to be ending up executable without having to run the above commands, so I have commented them out for now.

.SILENT:		


	
	