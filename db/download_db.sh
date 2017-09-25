#!/bin/bash

db_url_prefix=https://onvotar.garantiespelreferendum.com/db
hex_values=`printf "%02x " {0..255}`
parallel_downloads=10

function check_md5() {
  local file=$1
  local file_url=${db_url_prefix}/${file}
  echo -n "Checking if file ${file} needs to be updated ... "
  origin_md5=`curl -s ${file_url} -o- | md5sum | awk '{print $1}'`
  dest_md5=`md5sum ${file} | awk '{print $1}'`
  if [ ${origin_md5} == ${dest_md5} ]; then
    return 0
  fi
  return 1
}

function download_db() {
  local file=$1
  local file_url=${db_url_prefix}/${file}
  echo "Downloading file ${file_url} into ${file} ..."
  curl -s ${file_url} -o ${file} &
}

for folder in ${hex_values}; do
  if [ ! -d ${folder} ]; then
    mkdir ${folder}
  fi
  N=${parallel_downloads}
  (
  for file in ${hex_values}; do
    ((i=i%N)); ((i++==0)) && wait
    if [ ! -e ${folder}/${file}.db ]; then
      download_db ${folder}/${file}.db &
    elif [ `wc -l ${folder}/${file}.db | awk '{print $1}'` -eq 0 ]; then
      rm -f ${folder}/${file}.db
      download_db ${folder}/${file}.db &
    elif grep "Connection timed out" ${folder}/${file}.db >/dev/null; then
      rm -f ${folder}/${file}.db
      download_db ${folder}/${file}.db &
    elif ! check_md5 ${folder}/${file}.db; then
      echo "Updating file ${folder}/${file}.db ..."
      rm -f ${folder}/${file}.db
      download_db ${folder}/${file}.db &
    fi
    echo
  done
  )
done

