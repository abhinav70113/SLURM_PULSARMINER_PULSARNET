#!/bin/bash

sing_image=$1
data_dir=$2
code_dir=$3
input_data=$4
rfifind_mask=$5
dm_low=$6
dm_high=$7
dm_trials=$8
ncpus=$9
segment_label=${10}
chunk_label=${11}
working_dir=${12}
output_dir=${13}


# Create an array of DM values
dm_values=($(seq -f "%.2f" $dm_low 0.1 $dm_high))
# Extract the output file base name from $output_dir
output_file_base=$(echo "$output_dir" | awk -F '/' '{print $(NF-2)"_"$(NF-1)"_"$NF}' | sed 's/\//_/g')

# Append the specific string to the base name
output_file_base="${output_file_base}_DM"
# Iterate through DM values to check if the corresponding files exist
all_files_exist=true
# total files to check
total_files=${#dm_values[@]}
# counter
counter=0
for dm in "${dm_values[@]}"; do
  filename="${output_dir}/${output_file_base}${dm}.dat"
  
  # If the file doesn't exist or is empty, set the flag to false and break the loop
  if [ ! -s "$filename" ]; then
    echo "File $filename does not exist or is empty."
    all_files_exist=false
#    break
  fi
  counter=$((counter+1))
done

# files that exist out of the total
files_exist=$counter
echo "Files that exist: $files_exist out of $total_files"

if $all_files_exist; then
  echo "All files exist, exiting."
  exit 0
else
    echo "Some files do not exist, continuing."
    mkdir -p $working_dir
    mkdir -p $output_dir
    # Copy the data and the rfifind mask to /tmp
    rsync -PavL ${rfifind_mask::-5}* $working_dir
    rsync -PavL $input_data $working_dir 


    basename_mask=$(basename "$rfifind_mask")
    basename_mask=${working_dir}/$basename_mask
    basename_data=$(basename "$input_data")
    basename_data=${working_dir}/$basename_data

    singularity exec -H $HOME:/home1 -B $data_dir:$data_dir $sing_image python ${code_dir}/dedisperse.py -i $basename_data -m $basename_mask -d $dm_low -D $dm_high  -t $dm_trials -n $ncpus -s $segment_label -c $chunk_label -w $working_dir
    status=$?
    if [ $status -ne 0 ]; then
        echo "Error: dedisperse.py failed with status $status"
        echo "Deleting $working_dir"
        rm -rf $working_dir
        exit 1
    fi

    # Copy Results back
    working_dir=${working_dir}/dedisp_${segment_label}_${chunk_label}_DM_${dm_low}_${dm_high}
    rsync -Pav $working_dir/*.dat  $output_dir
    #rsync -Pav $working_dir/*.fft  $output_dir
    rsync -Pav $working_dir/*.inf $output_dir
    rm -rf $working_dir
fi
