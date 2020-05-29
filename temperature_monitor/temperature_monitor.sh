#!/bin/sh
#by neil

#here is a daemon-like shell script that polls the kaiten repl interface every few seconds, and also timestamps and dumps to a log file each of the lines outputted by the kaiten repl.

# echo $$
pipeIntoRepl="/tmp/neiltemp1";
pipeOutOfRepl="/tmp/neiltemp2";
logFile="/tmp/neil_log_1";
timestampFormat="%F_%T";
#(
#clean up procedure:
# trap "echo ; echo cleaning up...; echo \"logging the fact that we are ceasing logging ...\"; echo \"ceasing logging at \$(date +${timestampFormat})\" >> ${pipeOutOfRepl}; echo \"waiting 1 second to allow the logging apparatus to log the cessation of logging before we kill the logging apparatus ...\"; sleep 1; echo killing processes \$(jobs -p) ...; kill \$(jobs -p); echo deleting pipes ${pipeIntoRepl}  ${pipeOutOfRepl} ...; rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1;  echo \"invoking \\\"jobs\\\" one last time...\";  jobs 1> /dev/null 2>&1; " SIGINT;
# trap "echo ; echo cleaning up...; echo \"making sure the output pipe is open so that our logging of the cessation of logging will wait until the loggin apparatus will receive the message before proceeding to kill the logging apparatus. ...\"; exec 9<> ${pipeOutOfRepl}; echo \"logging the fact that we are ceasing logging ...\"; echo \"ceasing logging at \$(date +${timestampFormat})\" > ${pipeOutOfRepl}; echo killing processes \$(jobs -p) ...; kill \$(jobs -p); echo deleting pipes ${pipeIntoRepl}  ${pipeOutOfRepl} ...; rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1;  echo \"invoking \\\"jobs\\\" one last time...\";  jobs 1> /dev/null 2>&1; " SIGINT;
# trap "echo ; echo cleaning up...; echo \"logging the fact that we are ceasing logging ...\"; echo \"ceasing logging at \$(date +${timestampFormat})\" > ${pipeOutOfRepl}; echo killing processes \$(jobs -p) ...; kill \$(jobs -p); echo deleting pipes ${pipeIntoRepl}  ${pipeOutOfRepl} ...; rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1;  echo \"invoking \\\"jobs\\\" one last time...\";  jobs 1> /dev/null 2>&1; " SIGINT;
#getting the listening loop (below) to stay active long enough to log the cessation of logging is a bit tricky.  I have resorted to a rather crude method of just waiting a second after logging the cessation of logging before doing the killing (it ought to be possible for the echo that sends the cessation log message to block until the 
#listening loop has ingested the data, but I can't quite seem to make this happen - hence the wait-one-second kludge.
trap "echo ; echo cleaning up...; echo \"logging the fact that we are ceasing logging ...\"; echo \"ceasing logging at \$(date +${timestampFormat})\" >> ${pipeOutOfRepl}; echo \"waiting 1 second to allow the logging apparatus to log the cessation of logging before we kill the logging apparatus ...\"; sleep 1; echo killing processes \$(jobs -p) ...; kill \$(jobs -p); echo deleting pipes ${pipeIntoRepl}  ${pipeOutOfRepl} ...; rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1;  echo \"invoking \\\"jobs\\\" one last time...\";  jobs 1> /dev/null 2>&1" SIGINT;

rm ${pipeIntoRepl}  ${pipeOutOfRepl} 1> /dev/null 2>&1; 
mkfifo ${pipeIntoRepl} ${pipeOutOfRepl}; 
exec 8<> ${pipeIntoRepl}; 
exec 9<> ${pipeOutOfRepl};

#start listening for log entries, and write them to the log file with a timestamp as they come in:
# (exec 9<> ${pipeOutOfRepl}; while read p; do echo "$(date  +${timestampFormat}) $p" >> ${logFile}; done <${pipeOutOfRepl} ;) &:;
(sleep 5; while read p; do echo "$(date  +${timestampFormat}) $p" >> ${logFile}; done <${pipeOutOfRepl} ;) &:;

# the exec 9<> ${pipeOutOfRepl};, above, is necessary to keep the while loop cranking away even if everyone else has closed the output pipe.

echo "commencing logging at $(date +${timestampFormat})" > ${pipeOutOfRepl};

python /usr/scripts/repl.py >>${pipeOutOfRepl} <${pipeIntoRepl} & :;


echo debug > ${pipeIntoRepl};
watch -n 2 "echo -e \"[self._machine_manager._pymach.get_current_command_index(),self._machine_manager._pymach.get_temperature(0),self._machine_manager._pymach.get_temperature_settings()[0]]\" > ${pipeIntoRepl}" > /dev/null & :; 

#at this point, all of our asynchronous tasks are cranking away and we can sit back and relax

# echo waiting for ${logFile} to exist...;
# wait for the log file to exist, so as  not to cause the tail command, below, to throw an error when it tries to read a non-existent file.
while [ ! -f ${logFile} ]; do echo log file does not yet exist.  waiting...; sleep 1; done;


#when running this whole script as a one-liner, the following command is useful because it causes us to previewthe log entries in real time.
tail -f ${logFile} ;

#this is a bit of a bogus command just to prevent this shell from ever exiting (unless of course we manually kill it, which is the intended way to stop this shell).
# we need this because all of our business logic is running asynchronous subshells.
#if we did not do something explicit here to wait, we would fall out the bottom of the subshell and the 
# cleanup up command that we registered with trap, above, would fire, stopping the logging process.
#wait for 
wait $(jobs -p);
#)

