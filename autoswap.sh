#!/bin/bash

## autoswap.sh
## version 1.00.01
## Automatically add and remove SWAP files based on system load.

## Usage:
##
## 1. Copy the file autoswap.conf to /etc/autoswap/autoswap.conf
## 2. Set owner and group to root and edit the contents of the file to fit your
##    your use case.
## 3. Copy the file autoswap.service to /etc/systemd/system/autoswap.service
## 4. Set owner and group to root
## 5. Copy autoswap.sh, addswap.sh and remswap.sh to the / folder.
## 6. Set owner and group to root and make executable for root only (744)
##
## (as root)
##   systemctl daemon-reload
##   systemctl start autoswap.service
##   systemctl enable autoswap.service
##
## (with sudo)
##   sudo systemctl daemon-reload
##   sudo systemctl start autoswap.service
##   sudo systemctl enable autoswap.service
##
## The script will monitor your available memory and SWAP resources and use
## addswap.sh and remswap.sh to add and remove SWAP fles depending on your
## requirements and settings in /etc/autoswap/autoswap.conf.
##
## If you make changes to /etc/autoswap/autoswap.conf then you need to restart the
## autoswap.service using:
##
## (as root)
##   systemctl restart autoswap.service
##
## (with sudo)
##   sudo systemctl restart autoswap.service
##
## A log file can be found at /var/log/swapmanagement.log


function echolog {
  echo "$1"
  echo "$(date) > autoswap > $1" >> /var/log/swapmanagement.log

  if [[ $(wc -l < /var/log/swapmanagement.log) -gt 300 ]]; then

    cat /var/log/swapmanagement.log | tail -n 250 > /var/log/swapmanagement.temp && mv /var/log/swapmanagement.temp /var/log/swapmanagement.log

  fi
}

echolog "Initializing..."

threshold_minimum=512
swap_file_size=2048
required_swap_files=1
minimum_free_storage=4096
check_interval=30

if [[ -f /etc/autoswap/autoswap.conf ]]; then

  source /etc/autoswap/autoswap.conf
  echolog "/etc/autoswap/autoswap.conf found... settings applied."

else

  echolog "/etc/autoswap/autoswap.conf not found... default settings applied."

fi

swap_file_size_gb=$(($swap_file_size/1024))

if [[ $(($swap_file_size%1024)) != 0 ]]; then
  echolog "Converting {swap_file_size} from MB to GB, rounding up..."
  ((swap_file_size_gb++))
  swap_file_size=$(($swap_file_size_gb*1024))
fi

echolog "{threshold_minimum} = ${threshold_minimum}MB"
echolog "{swap_file_size} = ${swap_file_size}MB"
echolog "{required_swap_files} = ${required_swap_files}"
echolog "{minimum_free_storage} = ${minimum_free_storage}MB"
echolog "{check_interval} = ${check_interval}s"

swap_file_size_gb=$(($swap_file_size/1024))
interval=$check_interval

while true; do

  #echo "Doing checks..."
  ram_array=($(free | grep "^Mem:"))
  swap_array=($(free | grep "^Swap:"))
  root_drive_array=($(df | grep "/$"))
  free_ram=$((${ram_array[6]}/1024))
  free_swap=$((${swap_array[3]}/1024))
  free_combined=$(($free_ram+$free_swap))
  free_root_drive=$((${root_drive_array[3]}/1024))
  total_ram=${ram_array[1]}
  total_swap=${swap_array[1]}
  required_free_root_drive=$(($swap_file_size+$minimum_free_storage))
  swap_files=$(swapon --show | grep "file" | wc -l)
  #echo "Root Drive Free Space     : ${free_root_drive}MB"
  #echo "Req. Space for more SWAP  : ${required_free_root_drive}MB"
  #echo "RAM Memory Free Space     : ${free_ram}MB"
  #echo "SWAP Memory Free Space    : ${free_swap}MB"
  #echo "Total Combined Free Mem   : ${free_combined}MB"
  #echo "No. of Active SWAP Files  : $swap_files"
  #echo "Threshold Minimum Space   : ${threshold_minimum}MB"
  #echo "SWAP File Allocation Size : ${swap_file_size}MB"

  if [[ $swap_files -lt $required_swap_files ]]; then

    echolog "Number of active SWAP files is less than required minimum..."
    bash addswap.sh $swap_file_size_gb
    interval=1

  elif [[ $free_combined -lt $threshold_minimum ]] && [[ $free_root_drive -gt $required_free_root_drive ]] && [[ $swap_files -ge $required_swap_files ]]; then

    echolog "System Memory and SWAP resources running below ${threshold_minimum}MB..."
    bash addswap.sh $swap_file_size_gb
    interval=$check_interval

  elif [[ $free_combined -lt $threshold_minimum ]] && [[ $free_root_drive -le $required_free_root_drive ]] && [[ $swap_files -ge $required_swap_files ]]; then

    echolog "CRITICAL > System Memory and SWAP resources running below ${threshold_minimum}MB but insufficient free space on root drive. [${free_root_drive}MB - requires $(($swap_file_size+$minimum_free_storage))MB]"
    interval=$(($check_interval*10))

  elif [[ $free_combined -gt $(($threshold_minimum+$swap_file_size)) ]] && [[ $swap_files -gt $required_swap_files ]]; then

    echolog "System Memory and SWAP resource have improved."
    bash remswap.sh
    interval=1

  else

    interval=$check_interval

  fi

  #echo "Check Interval            : ${interval}s"
  sleep ${interval}s

done
