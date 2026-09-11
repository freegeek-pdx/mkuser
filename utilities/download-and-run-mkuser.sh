#!/bin/sh
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell (of Free Geek) on 2/14/23
#
# https://mkuser.sh
#
# MIT License
#
# Copyright (c) 2023 Free Geek
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# NOTICE: This script IS NOT for user creation packages. The mkuser script itself is used for that.
# FOR INFORMATION ABOUT HOW TO USE THIS SCRIPT, SEE: https://github.com/freegeek-pdx/mkuser#running-without-installation

PATH='/usr/bin:/bin:/usr/sbin:/sbin'

if true; then # Wrap entire script in "if true" block so that if there is a incomplete "curl" download of the script that the shell throws an error instead of executing an incomplete download.
	if [ -d '/System/Installation' ] && [ ! -f '/usr/bin/pico' ]; then # The specified folder should exist in recoveryOS and the file should not.
		>&2 printf '\n%s\n' 'mkuser DOWNLOAD AND RUN ERROR: This tool cannot be run within recoveryOS.'
		exit 255
	elif [ "$(uname)" != 'Darwin' ]; then # Check this AFTER checking if running in recoveryOS since "uname" doesn't exist in recoveryOS.
		>&2 printf '\n%s\n' 'mkuser DOWNLOAD AND RUN ERROR: This tool can only run on macOS.'
		exit 254
	elif ! dseditgroup -o checkmember -m "$(id -un)" 'admin' > /dev/null 2>&1; then
		>&2 printf '\n%s\n' 'mkuser DOWNLOAD AND RUN ERROR: This tool must be run as root or as an administrator.'
		exit 253
	fi

	run_as_sudo_if_needed() {
		if [ "$(id -u)" -ne 0 ]; then # Only need to run with "sudo" if this script itself IS NOT already running as root.
			sudo -vn 2> /dev/null || echo '' # IF SUDO REQUIRES A PASSWORD (which won't be the case if it was already authorized less than 5 mins ago), add a line break before the prompt just for display to separate from likely "curl" output when downloading this script.
			sudo -p 'Enter Password for "%p" to DOWNLOAD AND RUN mkuser: ' "$@"
		else
			"$@"
		fi
	}

	# NOTE: The actual download and run script is a bash script which is run via the "bash" command below which is done like this for a couple of reasons:
	# - The parent script can be run as "sh" (or "bash" or "zsh") and the actual install script will always be properly run as "bash" without the user having to worry about that in the invocation.
	# - The install script needs to be run as root, and running is as a sub-command like this means that we can launch "bash" with "sudo" as needed without the user having to worry about that in the invocation since running
	#   "sudo sh <(curl mkuser.sh)" would fail because the process substitution FD would get consumed by "sudo" instead of "sh". This way just "sh <(curl mkuser.sh)" can be run and "sudo" will be added as needed by this script.
	# ALSO NOTE: A here-doc IS NOT used since a here-doc would be passed to the "bash" command using standard input (stdin) and we need any stdin from the parent script to be passed though to the actual "mkuser" script that it run in case
	# a password is being passed using "--stdin-password" and a using here-doc would prevent/mask that since only a single stdin can exist. This makes quoting more complicated since the whole script must exist within a single quoted string.

	# Suppress ShellCheck warning about expressions not expanding in single quotes since it is intentional (as described above).
	# shellcheck disable=SC2016
	run_as_sudo_if_needed bash -c '
PATH="/usr/bin:/bin:/usr/sbin:/sbin"

echo "" # Add a line break before the following output just for display to separate from likely "sudo" prompt or "curl" output when downloading this script.

script_pid="$$" # This script_pid will be used for both "caffeinate" and "shlock".
caffeinate -dimsuw "${script_pid}" & # Use "caffeinate" to keep computer awake while "mkuser" is being downloaded and run which should always be pretty quick, but this does not hurt.

# Block simultaneous mkuser temporary run processes from running simultaneously since only one "mkuser" process can run at a time anyways,
# and simultaneous temporary runs could conflict if one deletes the temporary script while another process is still running from it.
# Simply not allowing simultaneous runs solves all these possible issues and simplifies the logic in this script.

# Use "trap" to catch all EXITs to always delete the "/private/var/run/mkuser-run.pid" file upon completion. This appears to always run for any "exit" statement, and also runs after SIGINT in bash, but that may not be true for other shells: https://unix.stackexchange.com/questions/57940/trap-int-term-exit-really-necessary
trap "rm -rf /private/var/run/mkuser-run.pid" EXIT # Even though this command runs last, it does NOT seem to override the final exit code.

until shlock -p "${script_pid}" -f "/private/var/run/mkuser-run.pid" &> /dev/null; do # Loop and sleep until no other mkuser run processes are running.
	echo "mkuser DOWNLOAD AND RUN NOTICE: Waiting for another mkuser DOWNLOAD AND RUN process (PID $(head -1 "/private/var/run/mkuser-run.pid" 2> /dev/null || echo "?")) to finish before starting this one (PID ${script_pid})."
	sleep 3
done

echo "mkuser DOWNLOAD AND RUN: Retrieving Latest mkuser Version and Download URL..."

if ! latest_version_json="$(curl -m 5 -sfL "https://update.mkuser.sh" 2> /dev/null)" || [[ "${latest_version_json}" != *"\"tag_name\""* || "${latest_version_json}" != *"\"browser_download_url\""* ]]; then
	>&2 echo "mkuser DOWNLOAD AND RUN ERROR: FAILED TO RETRIEVE LATEST VERSION OR DOWNLOAD URL (INTERNET REQUIRED)"
	exit 1
fi

latest_version="$(osascript -l "JavaScript" -e "run = argv => JSON.parse(argv[0]).tag_name" -- "${latest_version_json}" 2> /dev/null)"
# Parsing JSON with JXA: https://paulgalow.com/how-to-work-with-json-api-data-in-macos-shell-scripts & https://twitter.com/n8henrie/status/1529513429203300352

fallback_version_note=""
if [[ ! "${latest_version}" =~ ^[0123456789][0123456789.-]*$ ]]; then
	# Make sure the latest version string is valid. If JSON.parse() failed somehow, just try to get the latest version string using "awk" instead.
	latest_version="$(echo "${latest_version_json}" | awk -F "\"" '\''($2 == "tag_name") { print $4; exit }'\'')"
	fallback_version_note=" (USED FALLBACK TECHNIQUE TO RETRIEVE VERSION, PLEASE REPORT THIS ISSUE)"

	if [[ ! "${latest_version}" =~ ^[0123456789][0123456789.-]*$ ]]; then
		>&2 echo "mkuser DOWNLOAD AND RUN ERROR: FAILED TO RETRIEVE LATEST VERSION (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)"
		exit 2
	fi
fi

echo "Latest mkuser Version: ${latest_version}${fallback_version_note}"

echo -e "\nmkuser DOWNLOAD AND RUN: Downloading mkuser Version ${latest_version} Archive..."

latest_zip_download_url="$(osascript -l "JavaScript" -e "run = argv => JSON.parse(argv[0]).assets[1].browser_download_url" -- "${latest_version_json}" 2> /dev/null)"

fallback_zip_download_url_note=""
if [[ "${latest_zip_download_url}" != "https://"*".zip" ]]; then
	# Make sure the archive URL is valid. If JSON.parse() failed somehow, just try to get the archive URL using "awk" instead.
	latest_zip_download_url="$(echo "${latest_version_json}" | awk -F "\"" '\''(($2 == "browser_download_url") && ($4 ~ /\.zip$/)) { print $4; exit }'\'')"
	fallback_zip_download_url_note=" (USED FALLBACK TECHNIQUE TO RETRIEVE ARCHIVE DOWNLOAD URL, PLEASE REPORT THIS ISSUE)"

	if [[ "${latest_zip_download_url}" != "https://"*".zip" ]]; then
		>&2 echo "mkuser DOWNLOAD AND RUN ERROR: FAILED TO RETRIEVE RETRIEVE ARCHIVE DOWNLOAD URL (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)"
		exit 3
	fi
fi

echo "Latest mkuser Archive Download URL: ${latest_zip_download_url}${fallback_zip_download_url_note}"

install_location_folder="/private/tmp/mkuser-run"
rm -rf "${install_location_folder}" # Only one instance can be running at a time, so it is always safe to delete this folder if it happens to exist.
mkdir -p "${install_location_folder}"

zip_download_path="${install_location_folder}/mkuser-${latest_version}.zip"
curl --connect-timeout 5 --progress-bar -fL "${latest_zip_download_url}" -o "${zip_download_path}"
curl_exit_code="$?"

if (( curl_exit_code != 0 )) || [[ ! -f "${zip_download_path}" ]]; then
	rm -rf "${install_location_folder}"
	>&2 echo "mkuser DOWNLOAD AND RUN ERROR: DOWLOAD ARCHIVE FAILED WITH EXIT CODE ${curl_exit_code} (INTERNET REQUIRED, SEE OUTPUT ABOVE FOR MORE INFO)"
	exit 4
fi

echo -e "\nmkuser DOWNLOAD AND RUN: Verifying mkuser Version ${latest_version} Archive Checksum..."

latest_checksums_download_url="$(osascript -l "JavaScript" -e "run = argv => JSON.parse(argv[0]).assets[2].browser_download_url" -- "${latest_version_json}" 2> /dev/null)"

fallback_checksums_download_url_note=""
if [[ "${latest_checksums_download_url}" != "https://"*".txt" ]]; then
	# Make sure the checksums URL is valid. If JSON.parse() failed somehow, just try to get the checksums URL using "awk" instead.
	latest_checksums_download_url="$(echo "${latest_version_json}" | awk -F "\"" '\''(($2 == "browser_download_url") && ($4 ~ /\.txt$/)) { print $4; exit }'\'')"
	fallback_checksums_download_url_note=" (USED FALLBACK TECHNIQUE TO RETRIEVE CHECKSUMS DOWNLOAD URL, PLEASE REPORT THIS ISSUE)"

	if [[ "${latest_checksums_download_url}" != "https://"*".txt" ]]; then
		rm -rf "${install_location_folder}"
		>&2 echo "mkuser DOWNLOAD AND RUN ERROR: FAILED TO RETRIEVE RETRIEVE CHECKSUMS DOWNLOAD URL (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)"
		exit 5
	fi
fi

echo "Latest mkuser Checksums URL: ${latest_checksums_download_url}${fallback_checksums_download_url_note}"

if ! latest_checksums="$(curl -m 5 -sfL "${latest_checksums_download_url}" 2> /dev/null)" || [[ "${latest_checksums}" != *"mkuser"* ]]; then
	rm -rf "${install_location_folder}"
	>&2 echo "mkuser DOWNLOAD AND RUN ERROR: FAILED TO RETRIEVE CHECKSUMS (INTERNET REQUIRED)"
	exit 6
fi

intended_zip_checksum="$(echo "${latest_checksums}" | awk '\''($NF ~ /\.zip$/) { print $1; exit }'\'')"
echo "Intended Archive Checksum = ${intended_zip_checksum}"

actual_zip_checksum="$(openssl dgst -sha512 "${zip_download_path}" | awk '\''{ print $NF; exit }'\'')"
echo "Downloaded Archive Checksum = ${actual_zip_checksum}"

if [[ "${actual_zip_checksum}" != "${intended_zip_checksum}" ]]; then
	rm -rf "${install_location_folder}"
	>&2 echo "mkuser DOWNLOAD AND RUN ERROR: INVALID ARCHIVE CHECKSUM (SEE OUTPUT ABOVE FOR MORE INFO)"
	exit 7
fi

echo -e "\nmkuser DOWNLOAD AND RUN: Unarchiving mkuser Version ${latest_version}..."

ditto -xkvV "${zip_download_path}" "${install_location_folder}" # NOTE: Unzipping MUST be done with "ditto" since it properly preserve/restores code signature extended attributes, unlike "unzip".
ditto_exit_code="$?"

rm -f "${zip_download_path}"

if (( ditto_exit_code != 0 )) || [[ ! -f "${install_location_folder}/mkuser" || ! -x "${install_location_folder}/mkuser" ]]; then
	rm -rf "${install_location_folder}"
	>&2 echo "mkuser DOWNLOAD AND RUN ERROR: FAILED TO UNARCHIVE WITH EXIT CODE ${ditto_exit_code}"
	exit 8
fi

echo -e "\nmkuser DOWNLOAD AND RUN: Verifying mkuser Version ${latest_version} Code Signature and Checksum at Temporary Location..."

readonly INTENDED_CODE_SIGNATURE_TEAM_ID="YRW6NUGA63"

codesign -vv --strict -R "=identifier \"org.freegeek.mkuser\" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"${INTENDED_CODE_SIGNATURE_TEAM_ID}\"" "${install_location_folder}/mkuser"
codesign_verify_exit_code="$?"

spctl_assess_last_line="$(spctl -avvt open --context context:primary-signature "${install_location_folder}/mkuser" 2>&1 | tail -1)" # Only capture the last line to output and check (which will be the "origin" line when successful or an error if the siganture was invalid) since thats all thats relevant
# because "spctl -avvt open ..." will "fail" with "rejected" since it rejects any flat files that are not notarized, but scripts cannot be notarized so signing is the most that can be done (packages, disk images, and Mach-O binaries are the only flat files that can be notarized).
echo "${spctl_assess_last_line}"

intended_script_checksum="$(echo "${latest_checksums}" | awk '\''($NF ~ /\/mkuser$/) { print $1; exit }'\'')"
echo "Intended Script Checksum = ${intended_script_checksum}"

actual_script_checksum="$(openssl dgst -sha512 "${install_location_folder}/mkuser" | awk '\''{ print $NF; exit }'\'')"
echo "Unarchived Script Checksum = ${actual_script_checksum}"

if (( codesign_verify_exit_code != 0 )) || [[ "${spctl_assess_last_line}" != *"(${INTENDED_CODE_SIGNATURE_TEAM_ID})" || "${actual_script_checksum}" != "${intended_script_checksum}" ]]; then # Checksum verification is part of "codesign" verification and "spctl" assessment, but manually verify it anyways.
	rm -rf "${install_location_folder}"
	>&2 echo "mkuser DOWNLOAD AND RUN ERROR: INVALID CODE SIGNATURE OR CHECKSUM AT TEMPORARY LOCATION (SEE OUTPUT ABOVE FOR MORE INFO)"
	exit 9
fi

echo -e "\nmkuser DOWNLOAD AND RUN: Successfully unarchived and verified mkuser version ${latest_version}!"

echo -e "\nmkuser DOWNLOAD AND RUN: Running mkuser Version ${latest_version} with Specified Options..."

"${install_location_folder}/mkuser" "$@"
mkuser_exit_code="$?"

rm -rf "${install_location_folder}" # Can delete this file without worrying about another temporary instances running simultaniously since this script uses "shlock" to only allow one instance to run at a time.

if [[ -d "${install_location_folder}" ]]; then
	>&2 echo "mkuser DOWNLOAD AND RUN ERROR: MKUSER FINISHED WITH EXIT CODE ${mkuser_exit_code}, BUT FAILED TO DELETE TEMPORARY MKUSER AFTER RUNNING (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)"
	exit 10
fi

exit "${mkuser_exit_code}" # Always exit with mkusers exit code instead of always being successful after deleting the temporary installation.
' -- "$@"
fi
