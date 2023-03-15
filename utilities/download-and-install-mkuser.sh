#!/bin/sh
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# Created by Pico Mitchell (of Free Geek) on 12/1/22
#
# https://mkuser.sh
#
# MIT License
#
# Copyright (c) 2022 Free Geek
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
# FOR INFORMATION ABOUT HOW TO USE THIS SCRIPT, SEE: https://github.com/freegeek-pdx/mkuser#local-installation

PATH='/usr/bin:/bin:/usr/sbin:/sbin'

if [ -d '/System/Installation' ] && [ ! -f '/usr/bin/pico' ]; then # The specified folder should exist in recoveryOS and the file should not.
	>&2 printf '\n%s\n' 'mkuser DOWNLOAD AND INSTALL ERROR: This tool cannot be run within recoveryOS.'
	exit 255
elif [ "$(uname)" != 'Darwin' ]; then # Check this AFTER checking if running in recoveryOS since "uname" doesn't exist in recoveryOS.
	>&2 printf '\n%s\n' 'mkuser DOWNLOAD AND INSTALL ERROR: This tool can only run on macOS.'
	exit 254
elif ! dseditgroup -o checkmember -m "$(id -un)" 'admin' > /dev/null 2>&1; then
	>&2 printf '\n%s\n' 'mkuser DOWNLOAD AND INSTALL ERROR: This tool must be run as root or as an administrator.'
	exit 253
fi

run_as_sudo_if_needed() {
	if [ "$(id -u)" -ne 0 ]; then # Only need to run with "sudo" if this script itself IS NOT already running as root.
		sudo -vn 2> /dev/null || echo '' # IF SUDO REQUIRES A PASSWORD (which won't be the case if it was already authorized less than 5 mins ago), add a line break before the prompt just for display to separate from likely "curl" output when downloading this script.
		sudo -p 'Enter Password for "%p" to DOWNLOAD AND INSTALL mkuser: ' "$@"
	else
		"$@"
	fi
}

# NOTE: The actual download and install script is a bash script which is run via the "bash" command below which is done like this for a couple of reasons:
# - The parent script can be run as "sh" (or "bash" or "zsh") and the actual install script will always be properly run as "bash" without the user having to worry about that in the invocation.
# - The install script needs to be run as root, and running is as a sub-command like this means that we can launch "bash" with "sudo" as needed without the user having to worry about that in the invocation.
# ALSO NOTE: A here-doc is used with expansion disabled so that normal quoting and variables can be used within the sub-script without any added nested quoting issues.

run_as_sudo_if_needed bash << 'ACTUAL_INSTALL_SCRIPT_EOF'
PATH='/usr/bin:/bin:/usr/sbin:/sbin'

echo '' # Add a line break before the following output just for display to separate from likely "sudo" prompt or "curl" output when downloading this script.

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}/" || echo '/private/tmp/')" # Make sure "TMPDIR" is always set and that it always has a trailing slash for consistency regardless of the current environment.

script_pid="$$" # This script_pid will be used for both "caffeinate" and "shlock".
caffeinate -dimsuw "${script_pid}" & # Use "caffeinate" to keep computer awake while "mkuser" is being installed (or running) which should always be pretty quick, but this does not hurt.

# Block simultaneous mkuser installation processes from running simultaneously since only one "installer" process can run at a time anyways.
# Simply not allowing simultaneous runs solves all these possible issues and simplifies the logic in this script.

# Use "trap" to catch all EXITs to always delete the "/private/var/run/mkuser-install.pid" file upon completion. This appears to always run for any "exit" statement, and also runs after SIGINT in bash, but that may not be true for other shells: https://unix.stackexchange.com/questions/57940/trap-int-term-exit-really-necessary
trap 'rm -rf /private/var/run/mkuser-install.pid' EXIT # Even though this command runs last, it does NOT seem to override the final exit code.

until shlock -p "${script_pid}" -f '/private/var/run/mkuser-install.pid' &> /dev/null; do # Loop and sleep until no other mkuser install/run processes are running.
	echo "mkuser DOWNLOAD AND INSTALL NOTICE: Waiting for another mkuser DOWNLOAD AND INSTALL process (PID $(head -1 '/private/var/run/mkuser-install.pid' 2> /dev/null || echo '?')) to finish before starting this one (PID ${script_pid})."
	sleep 3
done

readonly INTENDED_CODE_SIGNATURE_TEAM_ID='YRW6NUGA63'

echo 'mkuser DOWNLOAD AND INSTALL: Retrieving Latest mkuser Version and Download URL...'

if ! latest_version_json="$(curl -m 5 -sfL 'https://update.mkuser.sh' 2> /dev/null)" || [[ "${latest_version_json}" != *'"tag_name"'* || "${latest_version_json}" != *'"browser_download_url"'* ]]; then
	>&2 echo 'mkuser DOWNLOAD AND INSTALL ERROR: FAILED TO RETRIEVE LATEST VERSION OR DOWNLOAD URL (INTERNET REQUIRED)'
	exit 1
fi

install_location='/usr/local/bin/mkuser'

installed_version='NOT INSTALLED'

if [[ -f "${install_location}" ]]; then
	installed_version="$(awk -F " |=|'" '($2 == "MKUSER_VERSION") { print $(NF-1); exit }' "${install_location}")"

	if [[ ! "${installed_version}" =~ ^[0123456789][0123456789.-]*$ ]]; then
		installed_version='INVALID VERSION (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)'
	fi
fi

echo "Installed mkuser Version: ${installed_version}"

latest_version="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).tag_name' -- "${latest_version_json}" 2> /dev/null)"
# Parsing JSON with JXA: https://paulgalow.com/how-to-work-with-json-api-data-in-macos-shell-scripts & https://twitter.com/n8henrie/status/1529513429203300352

fallback_version_note=''
if [[ ! "${latest_version}" =~ ^[0123456789][0123456789.-]*$ ]]; then
	# Make sure the latest version string is valid. If JSON.parse() failed somehow, just try to get the latest version string using "awk" instead.
	latest_version="$(echo "${latest_version_json}" | awk -F '"' '($2 == "tag_name") { print $4; exit }')"
	fallback_version_note=' (USED FALLBACK TECHNIQUE TO RETRIEVE VERSION, PLEASE REPORT THIS ISSUE)'

	if [[ ! "${latest_version}" =~ ^[0123456789][0123456789.-]*$ ]]; then
		>&2 echo 'mkuser DOWNLOAD AND INSTALL ERROR: FAILED TO RETRIEVE LATEST VERSION (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)'
		exit 2
	fi
fi

echo "Latest mkuser Version: ${latest_version}${fallback_version_note}"

latest_checksums_download_url="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).assets[2].browser_download_url' -- "${latest_version_json}" 2> /dev/null)"

fallback_checksums_download_url_note=''
if [[ "${latest_checksums_download_url}" != 'https://'*'.txt' ]]; then
	# Make sure the checksums URL is valid. If JSON.parse() failed somehow, just try to get the checksums URL using "awk" instead.
	latest_checksums_download_url="$(echo "${latest_version_json}" | awk -F '"' '(($2 == "browser_download_url") && ($4 ~ /\.txt$/)) { print $4; exit }')"
	fallback_checksums_download_url_note=' (USED FALLBACK TECHNIQUE TO RETRIEVE CHECKSUMS DOWNLOAD URL, PLEASE REPORT THIS ISSUE)'

	if [[ "${latest_checksums_download_url}" != 'https://'*'.txt' ]]; then
		>&2 echo 'mkuser DOWNLOAD AND INSTALL ERROR: FAILED TO RETRIEVE RETRIEVE CHECKSUMS DOWNLOAD URL (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)'
		exit 3
	fi
fi

echo "Latest mkuser Checksums URL: ${latest_checksums_download_url}${fallback_checksums_download_url_note}"

if ! latest_checksums="$(curl -m 5 -sfL "${latest_checksums_download_url}" 2> /dev/null)" || [[ "${latest_checksums}" != *'mkuser'* ]]; then
	>&2 echo 'mkuser DOWNLOAD AND INSTALL ERROR: FAILED TO RETRIEVE CHECKSUMS (INTERNET REQUIRED)'
	exit 4
fi

intended_script_checksum="$(echo "${latest_checksums}" | awk '($NF ~ /\/mkuser$/) { print $1; exit }')"

verify_code_signature_at_path() {
	codesign -vv --strict -R '=identifier "org.freegeek.mkuser" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = '"\"${INTENDED_CODE_SIGNATURE_TEAM_ID}\"" "$1"
	local codesign_verify_exit_code="$?"

	local spctl_assess_last_line
	spctl_assess_last_line="$(spctl -avvt open --context context:primary-signature "$1" 2>&1 | tail -1)" # Only capture the last line to output and check (which will be the "origin" line when successful or an error if the siganture was invalid) since that's all thats relevant
	# because "spctl -avvt open ..." will "fail" with "rejected" since it rejects any flat files that are not notarized, but scripts cannot be notarized so signing is the most that can be done (packages, disk images, and Mach-O binaries are the only flat files that can be notarized).
	echo "${spctl_assess_last_line}"

	if (( codesign_verify_exit_code != 0 )) || [[ "${spctl_assess_last_line}" != *"(${INTENDED_CODE_SIGNATURE_TEAM_ID})" ]]; then
		return 1
	fi

	return 0
}

if [[ "${installed_version}" == "${latest_version}" ]]; then
	echo -e "\nmkuser DOWNLOAD AND INSTALL: Verifying Existing mkuser Version ${latest_version} Code Signature and Checksum at Install Location..."

	verify_code_signature_at_path "${install_location}"
	verify_code_signature_at_path_exit_code="$?"

	echo "Intended Script Checksum = ${intended_script_checksum}"

	actual_script_checksum="$(openssl dgst -sha512 "${install_location}" | awk '{ print $NF; exit }')"
	echo "Installed Script Checksum = ${actual_script_checksum}"

	if (( verify_code_signature_at_path_exit_code == 0 )) && [[ -x "${install_location}" && "${actual_script_checksum}" == "${intended_script_checksum}" ]]; then # Checksum verification is part of "codesign" verification and "spctl" assessment, but manually verify it anyways.
		echo -e "\nmkuser DOWNLOAD AND INSTALL: Verified existing installation of latest mkuser version ${latest_version}!"
		exit 0
	else
		rm -f "${install_location}"
		echo -e "Latest mkuser version ${latest_version} already installed BUT RE-INSTALLING BECAUSE FAILED VERIFICATION!"
	fi
fi # NOTE: Not checking if NEWER version is installed since this scripts intention is just to always install the latest release version.

echo -e "\nmkuser DOWNLOAD AND INSTALL: Downloading mkuser Version ${latest_version} Installation Package..."

latest_pkg_download_url="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).assets[0].browser_download_url' -- "${latest_version_json}" 2> /dev/null)"

fallback_pkg_download_url_note=''
if [[ "${latest_pkg_download_url}" != 'https://'*'.pkg' ]]; then
	# Make sure the package URL is valid. If JSON.parse() failed somehow, just try to get the package URL using "awk" instead.
	latest_pkg_download_url="$(echo "${latest_version_json}" | awk -F '"' '(($2 == "browser_download_url") && ($4 ~ /\.pkg$/)) { print $4; exit }')"
	fallback_pkg_download_url_note=' (USED FALLBACK TECHNIQUE TO RETRIEVE PKG DOWNLOAD URL, PLEASE REPORT THIS ISSUE)'

	if [[ "${latest_pkg_download_url}" != 'https://'*'.pkg' ]]; then
		>&2 echo 'mkuser DOWNLOAD AND INSTALL ERROR: FAILED TO RETRIEVE RETRIEVE PKG DOWNLOAD URL (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)'
		exit 5
	fi
fi

echo "Latest mkuser Package Download URL: ${latest_pkg_download_url}${fallback_pkg_download_url_note}"

package_download_path="${TMPDIR}mkuser-${latest_version}.pkg"
rm -rf "${package_download_path}" # Only one instance can be running at a time, so it is always safe to delete this package if it happens to exist.
curl --connect-timeout 5 --progress-bar -fL "${latest_pkg_download_url}" -o "${package_download_path}"
curl_exit_code="$?"

if (( curl_exit_code != 0 )) || [[ ! -f "${package_download_path}" ]]; then
	rm -f "${package_download_path}"
	>&2 echo "mkuser DOWNLOAD AND INSTALL ERROR: DOWLOAD INSTALLATION PACKAGE FAILED WITH EXIT CODE ${curl_exit_code} (INTERNET REQUIRED, SEE OUTPUT ABOVE FOR MORE INFO)"
	exit 6
fi

echo -e "\nmkuser DOWNLOAD AND INSTALL: Verifying mkuser Version ${latest_version} Installation Package Code Signature and Checksum..."

spctl_assess_output="$(spctl -avvt install "${package_download_path}" 2>&1)"
spctl_assess_exit_code="$?"

echo "${spctl_assess_output}"

pkgutil_check_signature_output="$(pkgutil --check-signature "${package_download_path}" 2>&1)"
pkgutil_check_signature_exit_code="$?"

echo "${pkgutil_check_signature_output}"

darwin_major_version="$(uname -r | cut -d '.' -f 1)" # 17 = 10.13, 18 = 10.14, 19 = 10.15, 20 = 11.0, etc.
if (( spctl_assess_exit_code != 0 || pkgutil_check_signature_exit_code != 0 )) || [[ "${spctl_assess_output}" != *$'\nsource='"$( (( darwin_major_version >= 18 )) && echo 'Notarized ' )"$'Developer ID\n'*"(${INTENDED_CODE_SIGNATURE_TEAM_ID})" || "${pkgutil_check_signature_output}" != *$'\n    1. Developer ID Installer: '*" (${INTENDED_CODE_SIGNATURE_TEAM_ID})"$'\n'* || ( darwin_major_version -ge 21 && "${pkgutil_check_signature_output}" != *$'\n   Notarization: trusted by the Apple notary service\n'* ) ]]; then
	# The "spctl -avv" output on macOS 10.13 High Sierra will only ever include "source=Developer ID" even if it is actually notarized while macOS 10.14 Mojave and newer will include "source=Notarized Developer ID" and the "pkgutil --check-signature" output will only contain the "Notarization" line on macOS 12 Monterey and newer.
	rm -f "${package_download_path}"
	>&2 echo "mkuser DOWNLOAD AND INSTALL ERROR: INSTALLATION PACKAGE VERIFICATION FAILED WITH SPCTL EXIT CODE ${spctl_assess_exit_code} & PKGUTIL EXIT CODE ${pkgutil_check_signature_exit_code} (SEE OUTPUT ABOVE FOR MORE INFO)"
	exit 7
fi

intended_pkg_checksum="$(echo "${latest_checksums}" | awk '($NF ~ /\.pkg$/) { print $1; exit }')"
echo "Intended Package Checksum = ${intended_pkg_checksum}"

actual_pkg_checksum="$(openssl dgst -sha512 "${package_download_path}" | awk '{ print $NF; exit }')"
echo "Downloaded Package Checksum = ${actual_pkg_checksum}"

if [[ "${actual_pkg_checksum}" != "${intended_pkg_checksum}" ]]; then # Checksum verification is part of "spctl" assessment, but manually verify it anyways.
	rm -f "${package_download_path}"
	>&2 echo 'mkuser DOWNLOAD AND INSTALL ERROR: INVALID PACKAGE CHECKSUM (SEE OUTPUT ABOVE FOR MORE INFO)'
	exit 8
fi

echo -e "\nmkuser DOWNLOAD AND INSTALL: Installing mkuser Version ${latest_version} Package..."

installer -pkg "${package_download_path}" -target '/'
installer_exit_code="$?"

rm -f "${package_download_path}"

if (( installer_exit_code != 0 )); then
	>&2 echo "mkuser DOWNLOAD AND INSTALL ERROR: FAILED TO INSTALL PACKAGE WITH EXIT CODE ${installer_exit_code} (SEE OUTPUT ABOVE AND \"/var/log/install.log\" FOR MORE INFO)"
	exit 9
fi

echo -e "\nmkuser DOWNLOAD AND INSTALL: Verifying mkuser Version ${latest_version} Code Signature and Checksum at Install Location..."
# NOTE: The package installer "postinstall" verifies the code signature and checksum and will delete everything and error if somehow anything was invalid, but verify it all again anyways.

if ! verify_code_signature_at_path "${install_location}"; then
	rm -f "${install_location}"
	>&2 echo 'mkuser DOWNLOAD AND INSTALL ERROR: INVALID CODE SIGNATURE AT INSTALL LOCATION (SEE OUTPUT ABOVE FOR MORE INFO)'
	exit 10
fi

echo "Intended Script Checksum = ${intended_script_checksum}"

actual_script_checksum="$(openssl dgst -sha512 "${install_location}" | awk '{ print $NF; exit }')"
echo "Installed Script Checksum = ${actual_script_checksum}"

if [[ "${actual_script_checksum}" != "${intended_script_checksum}" ]]; then # Checksum verification is part of "codesign" verification and "spctl" assessment, but manually verify it anyways.
	rm -f "${install_location}"
	>&2 echo 'mkuser DOWNLOAD AND INSTALL ERROR: INVALID CHECKSUM AT INSTALL LOCATION (SEE OUTPUT ABOVE FOR MORE INFO)'
	exit 11
fi

echo -e "\nmkuser DOWNLOAD AND INSTALL: Successfully installed and verified mkuser version ${latest_version}!"
ACTUAL_INSTALL_SCRIPT_EOF
