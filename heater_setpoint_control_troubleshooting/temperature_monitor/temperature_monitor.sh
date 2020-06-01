#!/bin/sh
#by neil

#here is a daemon-like shell script that polls the kaiten repl interface every few seconds, and also timestamps and dumps to a log file each of the lines outputted by the kaiten repl.



moduleName=neil_module
logFile="/home/usb_storage/neil_repl_log";
stimulus="$moduleName.getReport(self)";

timestampFormat="%F_%T";
replCommandPrompt="dbg>";

tempModuleDirectory=/tmp/neiltemp
pipeIntoRepl=/tmp/neiltemp1
pipeOutOfRepl=/tmp/neiltemp2
replPidFile=/tmp/neiltemp3
loggerPidFile=/tmp/neiltemp4
stimulatorPidFile=/tmp/neiltemp5
stimulusFile=/tmp/neiltemp6





moduleContent=$(cat <<'EOF'
import ctypes;
import mbcoreutils.machine_definitions;
import libmachine.pymachine;
import time;

# intended as an additional method on the Machine class.
def neil_get_axes_position(pymach, timeout=3):
    c_axes_position = (ctypes.c_float*mbcoreutils.machine_definitions.constants['axis_count'])()
    # c_axes_position = (ctypes.c_float*6)()
    i=0
    maxI=1
    #regardless of whether maxI is 2 or 10, it seems that we hit maxI on about every other call to neil_get_axes_position()
    for x in pymach._loop(pymach._libmachine.GetAxesPosition, c_axes_position, pymach._machine_driver, timeout): 
        if i>maxI:
            break
        i+=1
        # time.sleep(1)
        pass
    # return Machine.unwrap_returns((list(c_axes_position),))
    if i>maxI:
        return "hit max i " + str(i) + "."
    else:
        return libmachine.pymachine.Machine.unwrap_returns((list(c_axes_position),))
    # return [c_axes_position, i]

def roundIfList(x):
    if type(x)==list:
        return map(lambda x: round(x,4), x)
    else:
        return x

def realVectorToString(x):
    return " ".join(("{: > 011.4f}" for _ in range(len(x)))).format(*x)
    # the repl seems to be condensing runs of multiple spaces in the output into a single space, so the above field width of 11
    # does not have the desired effect in the log file -- oh well.

def getReport(server):
    axes_position = neil_get_axes_position(server._machine_manager._pymach)
    try:    
        currentPrintFilename = server._machine_manager.get_current_process().filename
    except:
        currentPrintFilename=""
    return [
        currentPrintFilename.split("/")[-1],
        server._machine_manager._pymach.get_current_command_index(), 
        server._machine_manager._pymach.get_temperature(0), 
        server._machine_manager._pymach.get_temperature_settings()[0], 
        ("move_buffer_empty" if server._machine_manager._pymach.move_buffer_empty() else "                 "), 
        ("accel_buffer_empty" if server._machine_manager._pymach.acceleration_buffer_empty() else "                  "), 
        realVectorToString(server._machine_manager._pymach.get_move_buffer_position()), 
        ( realVectorToString(axes_position) if type(axes_position)==list else axes_position ),
        server._machine_manager.get_info_dict()
    ]
EOF
)


# a Python expression that we will send (in the same way that we send the stimulus) once immediately after starting the repl and putting it into debug mode,
# to set things up, if needed, (mainly importing modules and defining functions)
initialCommand=$(cat <<EOF
import sys
import importlib
if "$tempModuleDirectory" not in sys.path: 
    sys.path.append("$tempModuleDirectory")
    
import $moduleName
importlib.reload($moduleName)
EOF
)



# the replProcess, here, refers to a running instance of sh in which the python repl
# script is running and redirecting stdin and stdout to $pipeIntoRepl and
# $pipeOutOfRepl respectively.
replCommand=$(cat <<EOF
    # echo \$$ > $replPidFile
    if [ ! -p $pipeIntoRepl  ]; then mkfifo $pipeIntoRepl  ; fi;
    if [ ! -p $pipeOutOfRepl ]; then mkfifo $pipeOutOfRepl ; fi;
    exec 8<> $pipeIntoRepl; 
    exec 9<> $pipeOutOfRepl;
    python /usr/scripts/repl.py >$pipeOutOfRepl <$pipeIntoRepl &
    echo \$(jobs -p) > $replPidFile
    # wait \$(jobs -p)
EOF
)


# the loggerProcess, here, refers to a running instance of sh in which a
# loop is being executed reading from $pipeOutOfRepl, and, for each line 
# read, prepend a timestamp and dump into $logFile
loggerCommand=$(cat <<EOF
    echo \$$ > $loggerPidFile
    if [ ! -p $pipeOutOfRepl ]; then mkfifo $pipeOutOfRepl ; fi;
    exec 9<> $pipeOutOfRepl;
    # listen for lines being sent to $pipeOutOfRepl, and write them to the log file with a timestamp as they come in:
    echo "\$(date  +$timestampFormat) logger started" >> $logFile; 
    while read p; 
        #remove $replCommandPrompt (e.g. "dbg>") occuring at the beginning of the line (this is the command prompt).
        r=\$(echo -e \$p | awk "{sub(/^${replCommandPrompt}/, \"\")}1");
        do echo "\$(date  +$timestampFormat) \$r" >> $logFile; 
    done < $pipeOutOfRepl ;
    echo "\$(date  +$timestampFormat) logger fell through" >> $logFile; 
EOF
)


# stimulatorCommand=$(cat <<EOF
    # echo \$$ > $stimulatorPidFile
    # watch -n 2 "cat $stimulusFile > $pipeIntoRepl"
# EOF
# )

cleanupCommand=$(cat <<EOF
    echo ; 
    echo cleaning up...; 
    echo "logging the fact that we are ceasing logging ..."; echo "ceasing logging at \$(date +$timestampFormat)" > $pipeOutOfRepl; 
    echo "waiting 1 second to allow the logging apparatus to log the cessation of logging before we kill the logging apparatus ..."; sleep 1; 
    echo killing processes \$(jobs -p) ...; kill \$(jobs -p); 
    echo killing logger and stimulator with pids \$(cat $loggerPidFile) and \$(cat $stimulatorPidFile) ...; kill \$(cat $loggerPidFile) \$(cat $stimulatorPidFile); 
    echo "invoking \"jobs\" one last time so that subsequent calls to jobs will not return anything...";  jobs ;
EOF
)

# cleanup()
# {
    
# }


#========= ACTION STARTS HERE: ==================================================
#set the clock based on a public ntp server:
ntpd -d -n -q -g -p pool.ntp.org 1>/dev/null 2>&1 &:;

mkdir --parents $tempModuleDirectory 1>/dev/null 2>&1 ;
echo "$moduleContent" > $tempModuleDirectory/$moduleName.py
echo "$stimulus" > $stimulusFile




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

trap "${cleanupCommand}" SIGINT SIGTERM;

# rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1; 

if [ ! -p $pipeIntoRepl  ]; then mkfifo $pipeIntoRepl;  fi;
if [ ! -p $pipeOutOfRepl ]; then mkfifo $pipeOutOfRepl; fi;


# the exec 9<> ${pipeOutOfRepl};, above, is necessary to keep the while loop cranking away even if everyone else has closed the output pipe.

#we start the logger first so that we can log information to it as we start the other processes.
echo "ensuring that the logger is running..." 
# start-stop-daemon --background --pidfile $loggerPidFile --make-pidfile --startas sh --start -- -c $loggerCommand
if [ -f $loggerPidFile ] && [ -d /proc/$(cat $loggerPidFile) ]; then 
    echo logger process is already running with pid $(cat $loggerPidFile); 
else 
    echo logger process is not already running, so we will now start it.
    sh -c "$loggerCommand"  1>/dev/null  2>/dev/null & :;
    echo started logger process with pid $(cat $loggerPidFile)
fi

# echo "commenced logging to $logFile at $(date +$timestampFormat)"  | tee $pipeOutOfRepl


echo "ensuring that the makerbot repl is running..."
# start-stop-daemon --background --pidfile $replPidFile --make-pidfile --startas sh --start -- -c $replCommand
if [ -f $replPidFile ] && [ -d /proc/$(cat $replPidFile) ]; then 
    echo repl process is already running with pid $(cat $replPidFile); 
else 
    echo repl process is not already running, so we will now start it
    # sh -c "$replCommand"  1>/dev/null  2>/dev/null & :;
    sh -c "$replCommand"  1>/dev/null  2>/dev/null
    echo started repl process with pid $(cat $replPidFile)
fi

echo "ensuring that the stimulator is stopped (temporarily)..."
if [ -f $stimulatorPidFile ] && [ -d /proc/$(cat $stimulatorPidFile) ]; then 
    echo temporarily stopping the stimulator process
    kill $(cat $stimulatorPidFile)
else 
    echo the stimulator process is stopped
fi


echo "configuring makerbot repl..."
echo debug > $pipeIntoRepl;
echo "$initialCommand" > $pipeIntoRepl;


echo "ensuring that the stimulator is running..."
# start-stop-daemon --background --pidfile $replPidFile --make-pidfile --startas sh --start -- -c $replCommand
if [ -f $stimulatorPidFile ] && [ -d /proc/$(cat $stimulatorPidFile) ]; then 
    echo stimulator process is already running with pid $(cat $stimulatorPidFile); 
else 
    echo stimulator is not already running, so we will now start it
    # sh -c "$stimulatorCommand"  1>/dev/null  2>/dev/null & :;
    watch -n 2 "cat $stimulusFile > $pipeIntoRepl" > /dev/null & :;
    echo $! > $stimulatorPidFile
    echo started stimulator process with pid $(cat $stimulatorPidFile)
fi






# # this is a bit of a bogus command just to prevent this shell from ever exiting (unless 
# # of course we manually kill it, which is the intended way to stop this shell).
# # we need this because all of our business logic is running asynchronous subshells.
# # if we did not do something explicit here to wait, we would fall out the bottom of the subshell and the 
# # cleanup up command that we registered with trap, above, would fire, stopping the logging process.
# # wait for 

# wait $(jobs -p);
wait
# #a hack for keeping the shell alive (for a while) so I can run it interactively for debugging:
sleep 999999
