#!/bin/bash

## addswap.sh
## version 1.00.01
## Quickly add and activate a SWAP file.

## Usage:
##
## (as root)
##   ./addswap.sh {size-in-gigaytes}
##
## (with sudo)
##   sudo ./addswap.sh {size-in-gigaytes}
##
## {size-in-gigabytes} is optional. If you leave it out then the size will default
## to 4GB.
##
## The script will quickly create a SWAP file, activate it and add it to /etc/fstab
##
## It is important that you have addswap.sh and remswap.sh in the same folder and
## set the permissions to 700 and the owner and group to root. Do not try and run
## either script with out root or sudo privelages.
##
## A log file can be found at /var/log/swapmanagement.log

function echolog {
  echo "$1"
  echo "$(date) > addswap > $1" >> /var/log/swapmanagement.log

  if [[ $(wc -l < /var/log/swapmanagement.log) -gt 300 ]]; then

    cat /var/log/swapmanagement.log | tail -n 250 > /var/log/swapmanagement.temp && mv /var/log/swapmanagement.temp /var/log/swapmanagement.log

  fi
}

if [[ -z $1 ]] || [[ $1 = "" ]] || [[ ! $1 =~ ^[0-9]+$ ]] || [[ $1 -le 0 ]]; then

  swapsize=4
  echolog "Swap size not defined. Defaulting to 4GB."

else

  swapsize=$1
  echolog "Swap size manually defined as ${swapsize}GB."

fi

partitioncount=$(swapon --show | grep "partition" | wc -l)
filecount=$(swapon --show | grep "file" | wc -l)
totalcount=$((partitioncount+filecount))

echolog "You currently have $partitioncount active swap partitions and $filecount active swap files."

if [[ $totalcount -gt 23 ]]; then

  echolog "You already have 24 or more active swap partitions and files."
  exit 1

fi

swaplimit=$((24-$partitioncount))
array=($(df | grep "/$"))
freespace=$((${array[3]}/1048576))

if [[ $freespace -gt $swapsize ]]; then

  checking=true
  n=1

  while [[ $checking == true ]]; do

    if [[ $n -gt $swaplimit ]]; then

      echolog "You already have 24 or more active swap partitions and files."
      exit 1

    fi

    if [[ $n -lt 10 ]]; then

      ext="00$n"

    elif [[ $n -lt 25 ]] && [[ $n -gt 9 ]]; then

      ext="0$n"

    else

      echolog "You already have 24 or more active swap partitions and files."
      exit 1

    fi

    if [[ -f /swapfile.$ext ]]; then

      if swapon --show=NAME | grep -qF "/swapfile.$ext"; then

        echolog "/swapfile.$ext exists...[Active]"

      else

        echolog "/swapfile.$ext exists...[Inactive] > Removing"
        bash remswap.sh "/swapfile.$ext"
        filecount=$(swapon --show | grep "file" | wc -l)

      fi

      ((n++))

    else

      echolog "Creating /swapfile.$ext..."
      fallocate -l ${swapsize}G /swapfile.$ext
      chmod 600 /swapfile.$ext
      mkswap /swapfile.$ext
      swapon /swapfile.$ext
      echo "/swapfile.$ext none swap sw 0 0" >> /etc/fstab
      checking=false
      filecount=$(swapon --show | grep "file" | wc -l)
      echolog "You now have $partitioncount active swap partitions and $filecount active swap files."
      exit 0

    fi

  done

else

  echolog "Not enough harddrive space to make a ${swapsize}GB swap file."
  exit 2

fi
