#!/bin/bash

red="\e[0;91m";
green="\e[0;92m";
reset="\e[0m";
blue="\e[0;94m";

function errorMsg {
        echo -e "[ ${red}ERROR${reset} ] ${1}";
}

function successMsg {
        echo -e "[ ${green}SUCCESS${reset} ] ${1}";
}

function logMsg {
        echo -e "[ ${blue}INFO${reset} ] ${1}";
}

function checkPreviousCmd {
        if [ $? -ne 0 ]; then
                errorMsg "Error encountered in previous command. Terminating any further processing.";
                exit -1;
        fi
}

# Check if file was passed:
if [ "$1" == "" ]; then
        errorMsg "You must specify a file or directory to symmetrically encrypt";
        exit -1;
elif [ ! -f "$1" ]; then
	errorMsg "File not found.";
	exit -1;
fi


# Read lockdown db and see if hashed file exists:
logMsg "Checking for hashed checksum in lockdowndb to verify file integrity.";
shasum=$(sha256sum "${1}");
hashsum=${shasum/ *};
line_index_to_be_removed=-1;
line_count=0;
LOCKDOWN_DB_FILE="$(dirname $(realpath $0))/lockdowndb.txt";

while IFS= read -r line <&5; do
	line_count=$((line_count + 1));
	if [ "${line/ *}" = "$hashsum" ]; then
		successMsg "Successfully verified hash checksum.";
		logMsg "Gathering original filename from lockdowndb...";
		filename=$(echo ${line#* } | xargs);
		logMsg "Renaming encrypted file to corresponding file (${filename}.gpg) from lockdowndb.";
		mv -- "$1" "${filename}.gpg";
		checkPreviousCmd;
		logMsg "Decrypting ${filename}.gpg to ${filename}...";
		gpg --no-symkey-cache -o "${filename}" --decrypt "${filename}.gpg";
		checkPreviousCmd;
		logMsg "Removing ${filename}.gpg...";
		rm "${filename}.gpg";
		checkPreviousCmd;

		# Check if file was a tar.gz:
		if [ "${filename#*.}" = "tar.gz" ]; then
			logMsg "Is a tar.gz archive.";
			read -p 'Unzip tar.gz archive? (y/N)' shouldUnzipArchive;

			if [ "$shouldUnzipArchive" = "y" ] || [ "$shouldUnzipArchive" = "Y" ]; then
				logMsg "Unzipping archive...";
				tar -xf "${filename}";
				checkPreviousCmd;
				successMsg "Succesfully unzipped tar gunzip file (archive).";
				logMsg "Removing tar gunzip file.";
				rm "${filename}";
				checkPreviousCmd;
			else
				logMsg "Skipping unzipping archive.";
			fi
		fi

		line_index_to_be_removed=$line_count;
	fi
done 5< "$LOCKDOWN_DB_FILE";

if [ $line_index_to_be_removed -ne -1 ]; then
	logMsg "Removing entry from lockdowndb...";
	sed -i "${line_index_to_be_removed}d" "$LOCKDOWN_DB_FILE";
	successMsg "Done.";
	exit 0;
else
	errorMsg "Didn't find in lockdowndb, cannot decrypt because its integrity could not be verified";
	exit -1;
fi