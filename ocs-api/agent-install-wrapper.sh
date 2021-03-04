#!/bin/sh

# The primary purpose of this wrapper is to be able to invoke agent-install.sh in the SDO context and log all of its stdout/stderr

echo "$0 starting...."
echo "Will be running: ./agent-install.sh $*"

# Verify the number of args is what we are handling below
maxArgs=8   # the exec statement below is only passing up to this many args to agent-install.sh
if [ $# -gt $maxArgs ]; then
    # it is easy to miss this error msg in the midst of the verbose sdo output
    echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    echo "Error: the number of args specified ($#) is more than the maximum that agent-install-wrapper.sh currently supports ($maxArgs)"
    echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    exit 2
fi

# This script has a 2nd purpose in the native client case: when run inside the docker sdo container, copy the downloaded files to outside the container
if [ -f /target/boot/inside-sdo-container ]; then
    # Copy all of the downloaded files (including ourselves) to /target/boot, which is mounted from host /var/horizon/sdo-native
    echo "Copying downloaded files to /target/boot: $(ls | tr "\n" " ")"
    # need to exclude a few files and dirs, so copy with find
    find . -maxdepth 1 -type f ! -name inside-sdo-container ! -name linux-client ! -name run_csdk_sdo.sh -exec cp -p -t /target/boot/ {} +
    if [ $? -ne 0 ]; then echo "Error: can not copy downloaded files to /target/boot"; fi
    # The <device-uuid>_exec file is not actually saved to disk, so recreate it (with a fixed name)
    echo "/bin/sh agent-install-wrapper.sh \"$1\" \"$2\" \"$3\" \"$4\" " > /target/boot/device_exec
    chmod +x /target/boot/device_exec
    echo "Created /target/boot/device_exec: $(cat /target/boot/device_exec)"
    exit
    # now the sdo container will exit, then our owner-boot-device script will find the files and run them
fi

mkdir -p /var/sdo
logFile=/var/sdo/agent-install.log
echo "Logging all output to $logFile"

# When SDO transfers agent-install.sh to the device, it does not make it executable
chmod 755 agent-install.sh

# If tee is installed, use it so the output can go to both stdout/stderr and the log file
if command -v tee >/dev/null 2>&1; then
    # Note: the individual arg variables need to be listed like this and quoted to handle spaces in an arg
    exec ./agent-install.sh "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" 2>&1 | tee $logFile
else
    exec ./agent-install.sh "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" 2>&1 > $logFile
fi
#exit 2   # it only gets here if exec failed