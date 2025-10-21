#!/bin/bash

## remswap.sh
## version 1.00.01
## Quickly deactivate and remove a SWAP file.

## Usage:
##
## (as root)
##   ./remswap.sh {/swapfile.0xx}
##
## (with sudo)
##   sudo ./remswap.sh {/swapfile.0xx}
##
## {/swapfile.0xx} is optional. The 0xx extension is a range of numbers from 001 to
## 024. If you leave it out then the last file in the sequence will be removed.
##
## The script will quickly deactivate a SWAP file, removed it and remove it from
## /etc/fstab
##
## It is important that you have addswap.sh and remswap.sh in the same folder and
## set the permissions to 700 and the owner and group to root. Do not try and run
## either script with out root or sudo privelages.
##
## A log file can be found at /var/log/swapmanagement.log

function echolog {
  echo "$1"
  echo "$(date) > remswap > $1" >> /var/log/swapmanagement.log

  if [[ $(wc -l < /var/log/swapmanagement.log) -gt 300 ]]; then

    cat /var/log/swapmanagement.log | tail -n 250 > /var/log/swapmanagement.temp && mv /var/log/swapmanagement.temp /var/log/swapmanagement.log

  fi
}

if [[ -z $1 ]] || [[ $1 == "" ]]; then

  swapfile=$(ls -1 /swapfile.* 2>/dev/null | tail -1)

  if [[ -z "$swapfile" ]]; then

    echolog "No swap files found to remove."
    exit 1

  fi

elif [[ $1 =~ ^/swapfile\.0(0[0-9]|1[0-9]|2[0-4])$ ]] && [[ -f $1 ]]; then

  swapfile="$1"

else

  echolog "Invalid swap file name given or swap file does not exist."
  exit 2

fi

if swapon --show=NAME | grep -qF "$swapfile"; then

  echolog "Turning off $swapfile..."
  swapoff "$swapfile"

else

  echolog "$swapfile is not active."

fi

if grep -Fq "$swapfile" /etc/fstab; then

  echolog "Removing $swapfile entry from /etc/fstab..."
  sed -i "\|$swapfile|d" /etc/fstab

else

  echolog "$swapfile entry not found in /etc/fstab."

fi

echolog "Deleting $swapfile..."
rm -f "$swapfile"

if [[ $? == 0 ]]; then

  echolog "$swapfile successfully removed."
  partitioncount=$(swapon --show | grep "partition" | wc -l)
  filecount=$(swapon --show | grep "file" | wc -l)
  echolog "You now have $partitioncount active swap partitions and $filecount active swap files."
  exit 0

else

  echolog "$swapfile failed to be removed."
  exit 3

fi
