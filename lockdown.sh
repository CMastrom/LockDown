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

function saveChecksum {
	logMsg "Hashing file contents and storing for future checksum (when decrypting it back to cleartext).";
	shasum=$(sha256sum "${1}");
	shasum=${shasum/ *};
	echo "${shasum}  ${2}" >> ${HOME}/Applications/lockdowndb.txt;
}

function copyOGFile {
	logMsg "Copying original file to ${1}.og";
        cp -r "${1}" "${1}.og";
}

function obfuscate {
	logMsg "Obfuscating file extension to text file.";
	mv -- "${1}" "${1/.*}.txt";
}

gpgInfoMsg="GPG symmetrically encrypting file with NO SYMKEY CACHE and CIPHER ALGORITHM AES 256.";

# Check if file was passed:
if [ "$1" == "" ]; then
	errorMsg "You must specify a file or directory to symmetrically encrypt";
	exit -1;
fi

# Check if directory:
if [ -d $1 ]; then
	successMsg "Is a directory, creating a tar.gz file to be gpg symmetrically encrypted.";
	folderName="${1%/}";
	checkPreviousCmd;
	tar -cf "${folderName}.tar.gz" "${folderName}";
	checkPreviousCmd;
	logMsg "$gpgInfoMsg";
	gpg -c --no-symkey-cache --cipher-algo aes256 "${folderName}.tar.gz";
	checkPreviousCmd;
	obfuscate "${folderName}.tar.gz.gpg";
	checkPreviousCmd;
	saveChecksum "${folderName/.*}.txt" "${folderName}.tar.gz";
	checkPreviousCmd;
	logMsg "Removing ${folderName}.tar.gz...";
	rm "${folderName}.tar.gz";
	checkPreviousCmd;
	successMsg "Done";
	exit 0;
fi

# If not directory, check if file:
if [ -f $1 ]; then
	successMsg "Is a file, gpg symmetrically encrypting the file as ${1}.gpg";
	copyOGFile "${1}";
	checkPreviousCmd;
	logMsg "$gpgInfoMsg";
	gpg -c --no-symkey-cache --cipher-algo aes256 "${1}";
	checkPreviousCmd;
	obfuscate "${1}.gpg";
	checkPreviousCmd;
	saveChecksum "${1/.*}.txt" "${1/.*}.txt";
	checkPreviousCmd;
	successMsg "Done";
	exit 0;
fi

# If neither, error out:
errorMsg "Must specify a valid file or directory to symmetrically encrypt";
exit -1;

