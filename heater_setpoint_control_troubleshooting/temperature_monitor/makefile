getFullyQualifiedWindowsStylePath=$(shell cygpath --windows --absolute "$(1)")
unslashedDir=$(patsubst %/,%,$(dir $(1)))
pathOfThisMakefile=$(call unslashedDir,$(lastword $(MAKEFILE_LIST)))
sources:=$(wildcard ${pathOfThisMakefile}/*.sh)
destinationDirectoryOnTheMakerbot:=/home/usb_storage/
makerbotHost:=makerbot.ad.autoscaninc.com
makerbotUsername:=root
kittySessionDefinitionFile:=makerbot_ssh.ktx
foo:=$(call getFullyQualifiedWindowsStylePath,$(kittySessionDefinitionFile))
commandToPassToCmdToStartKitty:=start "" kitty -kload $(value foo) -cmd "sh $(call unslashedDir,$(destinationDirectoryOnTheMakerbot))/$(notdir $(sources))"
escapedCommandToPassToCmdToStartKitty:=$(subst ",\",$(commandToPassToCmdToStartKitty))
SHELL=sh



.PHONY: default
default: $(sources)
	@echo "====== BUILDING $@ from $< ======= "
	# @ls -al $<
	pscp "$(call getFullyQualifiedWindowsStylePath,$<)" "${makerbotUsername}@${makerbotHost}:${destinationDirectoryOnTheMakerbot}$(notdir $<)"
	# # ssh ${makerbotUsername}@${makerbotHost} "chmod ugo+x ${destinationDirectoryOnTheMakerbot}$(notdir $<)"
	# kitty -ssh ${makerbotUsername}@${makerbotHost} -cmd "chmod ugo+x ${destinationDirectoryOnTheMakerbot}$(notdir $<); exit"
	# the file seems to be ending up executable without having to run the above commands, so I have commented them out for now.
	cmd /c start "" kitty -kload "$(call getFullyQualifiedWindowsStylePath,${kittySessionDefinitionFile}) " -cmd "sh $(call unslashedDir,${destinationDirectoryOnTheMakerbot})/$(notdir $<)" -title "sh $(call unslashedDir,${destinationDirectoryOnTheMakerbot})/$(notdir $<)"
	
# @echo $(shell set)
# cmd /c $${commandToPassToCmdToStartKitty} 

.SILENT:		

# set command="python /usr/scripts/repl.py"
# start "" kitty -kload "U:\2020-05-02_makerbot_uart_connection\makerbot_ssh.ktx" -cmd %command% -title %command%
	
# cmd /c "start \"\" kitty -kload \"$(call getFullyQualifiedWindowsStylePath,${kittySessionDefinitionFile})\" -cmd \"sh $(call unslashedDir ${destinationDirectoryOnTheMakerbot})/$(notdir $<)\""	

#cmd /c "start \"\" kitty -kload \"$(call getFullyQualifiedWindowsStylePath,${kittySessionDefinitionFile})\" -cmd \"sh $(call unslashedDir ${destinationDirectoryOnTheMakerbot})/$(notdir $<)\"  "

# kitty -kload "$(call getFullyQualifiedWindowsStylePath,${kittySessionDefinitionFile})" -cmd "sh $(call unslashedDir,${destinationDirectoryOnTheMakerbot})/$(notdir $<)"

#cmd /c start "" kitty -kload "$(call getFullyQualifiedWindowsStylePath,${kittySessionDefinitionFile}) " -cmd "sh $(call unslashedDir,${destinationDirectoryOnTheMakerbot})/$(notdir $<)" 
# cmd /c "${escapedCommandToPassToCmdToStartKitty}"
#cmd /c start "" kitty -kload ""$(call getFullyQualifiedWindowsStylePath,${kittySessionDefinitionFile})"" -cmd "sh $(call unslashedDir,${destinationDirectoryOnTheMakerbot})/$(notdir $<)" 