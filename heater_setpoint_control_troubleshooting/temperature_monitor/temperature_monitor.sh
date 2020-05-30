#!/bin/sh
#by neil

#here is a daemon-like shell script that polls the kaiten repl interface every few seconds, and also timestamps and dumps to a log file each of the lines outputted by the kaiten repl.

logFile="/home/usb_storage/neil_repl_log";

pipeIntoRepl="/tmp/neiltemp1";
pipeOutOfRepl="/tmp/neiltemp2";

moduleName=neil_module
tempModuleDirectory=/tmp/neiltemp
timestampFormat="%F_%T";

replCommandPrompt="dbg>";

#The 'stimulus' is the string that we will send to the repl periodically to elicit output from the repl.  (think: stimulus and response)
# stimulus="[self._machine_manager._pymach.get_current_command_index(), self._machine_manager._pymach.get_temperature(0), self._machine_manager._pymach.get_temperature_settings()[0], self._machine_manager._pymach.get_move_buffer_position()]";
# stimulus="[ \
    # self._machine_manager._pymach.get_current_command_index(), \
    # self._machine_manager._pymach.get_temperature(0), \
    # self._machine_manager._pymach.get_temperature_settings()[0], \
    # self._machine_manager._pymach.move_buffer_empty(), \
    # self._machine_manager._pymach.acceleration_buffer_empty() \
    # self._machine_manager._pymach.get_move_buffer_position()), \
    # ${moduleName}.neil_get_axes_position(self._machine_manager._pymach), \
# ]";

# stimulus="[ \
    # self._machine_manager._pymach.get_current_command_index(), \
    # self._machine_manager._pymach.get_temperature(0), \
    # self._machine_manager._pymach.get_temperature_settings()[0], \
    # self._machine_manager._pymach.get_move_buffer_position(), \
    # self._machine_manager._pymach.move_buffer_empty(), \
    # self._machine_manager._pymach.acceleration_buffer_empty() \
# ]";

stimulus="${moduleName}.getReport(self)";


moduleContent="
import ctypes;
import mbcoreutils.machine_definitions;
import libmachine.pymachine;

# intended as an additional method on the Machine class.
def neil_get_axes_position(pymach, timeout=3):
    c_axes_position = (ctypes.c_float*mbcoreutils.machine_definitions.constants['axis_count'])()
    # c_axes_position = (ctypes.c_float*6)()
    i=0
    maxI=2
    #regardless of whether maxI is 2 or 10, it seems that we hit maxI on about every other call to neil_get_axes_position()
    for x in pymach._loop(pymach._libmachine.GetAxesPosition, c_axes_position, pymach._machine_driver, timeout): 
        if i>maxI:
            break
        i+=1
        pass
    # return Machine.unwrap_returns((list(c_axes_position),))
    if i>maxI:
        return \"hit max i \" + str(i) + \".\"
    else:
        return libmachine.pymachine.Machine.unwrap_returns((list(c_axes_position),))
    # return [c_axes_position, i]

def roundIfList(x):
    if type(x)==list:
        return map(lambda x: round(x,4), x)
    else:
        return x

def realVectorToString(x):
    return \", \".join((\"{:0.4f}\" for _ in range(len(x)))).format(*x)

def getReport(server):
    axes_position = neil_get_axes_position(server._machine_manager._pymach)
    try:    
        currentPrintFilename = server._machine_manager.get_current_process().filename
    except:
        currentPrintFilename=\"\"
    
    
    return [
        currentPrintFilename.split(\"/\")[-1],
        server._machine_manager._pymach.get_current_command_index(), 
        server._machine_manager._pymach.get_temperature(0), 
        server._machine_manager._pymach.get_temperature_settings()[0], 
        server._machine_manager._pymach.move_buffer_empty(), 
        server._machine_manager._pymach.acceleration_buffer_empty(), 
        realVectorToString(server._machine_manager._pymach.get_move_buffer_position()), 
        ( realVectorToString(axes_position) if type(axes_position)==list else axes_position )
    ]

"


# a Python expression that we will send (in the same way that we send the stimulus) once immediately after starting the repl and putting it into debug mode,
# to set things up, if needed, (mainly importing modules and defining functions)
initialCommand="
import sys
import importlib
if \"${tempModuleDirectory}\" not in sys.path: 
    sys.path.append(\"${tempModuleDirectory}\")
    
import ${moduleName}
importlib.reload(${moduleName})
"



# def get_axes_position(self, timeout=None):
    # c_axes_position = (ctypes.c_float*mbcoreutils.machine_definitions.constants['axis_count'])()
    # yield from self._loop(self._libmachine.GetAxesPosition, c_axes_position, self._machine_driver, timeout=timeout)
    # return Machine.unwrap_returns((list(c_axes_position),))

#========= ACTION STARTS HERE: ==================================================
#set the clock based on a public ntp server:
ntpd -d -n -q -g -p pool.ntp.org 1>/dev/null 2>&1 &:;

mkdir --parents ${tempModuleDirectory} 1>/dev/null 2>&1 ;
echo "${moduleContent}" > ${tempModuleDirectory}/${moduleName}.py
# echo ${neil_module_content} > /home/usb_storage/neil_module2.py

#we look for ${replCommandPrompt} appearing at the beginning of a line of output produced
#by the repl.


#clean up procedure:
# trap "echo ; echo cleaning up...; echo \"logging the fact that we are ceasing logging ...\"; echo \"ceasing logging at \$(date +${timestampFormat})\" > ${pipeOutOfRepl}; echo \"waiting 1 second to allow the logging apparatus to log the cessation of logging before we kill the logging apparatus ...\"; sleep 1; echo killing processes \$(jobs -p) ...; kill \$(jobs -p); echo deleting pipes ${pipeIntoRepl}  ${pipeOutOfRepl} ...; rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1;  echo \"invoking \\\"jobs\\\" one last time...\";  jobs 1> /dev/null 2>&1; " SIGINT;
# trap "echo ; echo cleaning up...; echo \"making sure the output pipe is open so that our logging of the cessation of logging will wait until the loggin apparatus will receive the message before proceeding to kill the logging apparatus. ...\"; exec 9<> ${pipeOutOfRepl}; echo \"logging the fact that we are ceasing logging ...\"; echo \"ceasing logging at \$(date +${timestampFormat})\" > ${pipeOutOfRepl}; echo killing processes \$(jobs -p) ...; kill \$(jobs -p); echo deleting pipes ${pipeIntoRepl}  ${pipeOutOfRepl} ...; rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1;  echo \"invoking \\\"jobs\\\" one last time...\";  jobs 1> /dev/null 2>&1; " SIGINT;
# trap "echo ; echo cleaning up...; echo \"logging the fact that we are ceasing logging ...\"; echo \"ceasing logging at \$(date +${timestampFormat})\" > ${pipeOutOfRepl}; echo killing processes \$(jobs -p) ...; kill \$(jobs -p); echo deleting pipes ${pipeIntoRepl}  ${pipeOutOfRepl} ...; rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1;  echo \"invoking \\\"jobs\\\" one last time...\";  jobs 1> /dev/null 2>&1; " SIGINT;

# getting the listening loop (below) to stay active long enough to log the cessation of 
# logging is a bit tricky.  I have resorted to a rather crude method of just waiting a 
# second after logging the cessation of logging before doing the killing (it ought to 
# be possible for the echo that sends the cessation log message to block until the 
# #listening loop has ingested the data, but I can't quite seem to make this 
# happen - hence the wait-one-second kludge.

trap "echo ; 
echo cleaning up...; 
echo \"logging the fact that we are ceasing logging ...\"; echo \"ceasing logging at \$(date +${timestampFormat})\" > ${pipeOutOfRepl}; 
echo \"waiting 1 second to allow the logging apparatus to log the cessation of logging before we kill the logging apparatus ...\"; sleep 1; 
echo killing processes \$(jobs -p) ...; kill \$(jobs -p); 
# echo deleting pipes ${pipeIntoRepl}  ${pipeOutOfRepl} ...; rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1;  
echo \"invoking \\\"jobs\\\" one last time so that subsequent calls to jobs will not return anything...\";  jobs 1> /dev/null 2>&1;
" SIGINT;

# rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1; 

# mkfifo ${pipeIntoRepl} ${pipeOutOfRepl}; 
if [ ! -f ${pipeIntoRepl} ]; then mkfifo ${pipeIntoRepl}; fi;
if [ ! -f ${pipeOutOfRepl} ]; then mkfifo ${pipeOutOfRepl}; fi;

exec 8<> ${pipeIntoRepl}; 
exec 9<> ${pipeOutOfRepl};

#start listening for log entries, and write them to the log file with a timestamp as they come in:
(
    echo "replCommandPrompt: ${replCommandPrompt}"
    while read p; 
    #remove ${replCommandPrompt} (e.g. "dbg>") occuring at the beginning of the line (this is the command prompt).
    r=$(echo -e $p | awk "{sub(/^${replCommandPrompt}/, \"\")}1");
    do echo "$(date  +${timestampFormat}) $r" >> ${logFile}; 
    done <${pipeOutOfRepl} ;
) &:;

# the exec 9<> ${pipeOutOfRepl};, above, is necessary to keep the while loop cranking away even if everyone else has closed the output pipe.
echo "commenced logging to ${logFile} at $(date +${timestampFormat})" > ${pipeOutOfRepl};


echo "starting the makerbot repl..." > ${pipeOutOfRepl};
python /usr/scripts/repl.py >${pipeOutOfRepl} <${pipeIntoRepl} & :;
echo debug > ${pipeIntoRepl};
echo "${initialCommand}" > ${pipeIntoRepl};

echo "commencing periodic stimulation of the repl using stimulus: ${stimulus} ..." > ${pipeOutOfRepl};
# watch -n 2 "echo -e \"\\n\" > ${pipeOutOfRepl}; echo -e \"[self._machine_manager._pymach.get_current_command_index(), self._machine_manager._pymach.get_temperature(0), self._machine_manager._pymach.get_temperature_settings()[0], self._machine_manager._pymach.get_move_buffer_position()]\" > ${pipeIntoRepl}" > /dev/null & :; 
watch -n 2 "echo -e \"${stimulus}\" > ${pipeIntoRepl}" > /dev/null & :; 
# at this point, all of our asynchronous tasks are cranking away and we can sit back and relax

# wait for the log file to exist, so as  not to cause the tail command, below, to throw an error when it tries to read a non-existent file.
# echo waiting for ${logFile} to exist...;
while [ ! -f ${logFile} ]; do echo log file does not yet exist.  waiting...; sleep 1; done;

# emit a real-time view of the log file to stdout (this doesn't have any bearing on the creation of the log file,
# but is useful for monitoring the log entries in real time.
echo tailing the log file...;
( tail -f ${logFile} ; ) &:;

# this is a bit of a bogus command just to prevent this shell from ever exiting (unless 
# of course we manually kill it, which is the intended way to stop this shell).
# we need this because all of our business logic is running asynchronous subshells.
# if we did not do something explicit here to wait, we would fall out the bottom of the subshell and the 
# cleanup up command that we registered with trap, above, would fire, stopping the logging process.
# wait for 

wait $(jobs -p);


