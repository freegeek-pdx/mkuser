#!/bin/bash

#
# Created by Pico Mitchell (of Free Geek) on 1/4/22
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
# This script IS AN INTERNAL DEVELOPMENT TOOL which is used when new mkuser versions are released
# to create the package to install the mkuser script into "/usr/local/bin".

PATH='/usr/bin:/bin:/usr/sbin:/sbin'

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}/" || echo '/private/tmp/')" # Make sure "TMPDIR" is always set and that it always has a trailing slash for consistency regardless of the current environment.

id_prefix='org.freegeek'
script_name='mkuser'

script_id="${id_prefix}.${script_name}"
package_id="${id_prefix}.pkg.${script_name}"

payload_tmp_dir="${TMPDIR}${script_name}_installation_payload"

rm -rf "${payload_tmp_dir}"
mkdir -p "${payload_tmp_dir}"

cat "${SCRIPT_DIR}/${script_name}.sh" > "${payload_tmp_dir}/${script_name}" # Instead of copying the file, write the *contents* to a new file to be sure that no xattrs are ever included in the distributed script (such as "com.apple.macl" which is SIP protected).
chmod +x "${payload_tmp_dir}/${script_name}"

script_version="$(awk -F "'" '/VERSION=/ { print $(NF-1); exit }' "${payload_tmp_dir}/${script_name}")"
if [[ -z "${script_version}" ]]; then script_version="$(date '+%Y.%-m.%-d')"; fi # https://strftime.org

echo -e "\nCode signing ${script_name} version ${script_version} script for package..."
codesign -s 'Developer ID Application' --identifier "${script_id}" --strict "${payload_tmp_dir}/${script_name}" # Set a proper identifier since just the filename would be used if none is specified.

codesign_exit_code="$?"

spctl --assess -vvv --type execute "${payload_tmp_dir}/${script_name}" # This should "fail" with "rejected (the code is valid but does not seem to be an app)"

if (( codesign_exit_code != 0 )); then
	rm -rf "${payload_tmp_dir}"
	>&2 echo -e "\nCODESIGN ERROR OCCURRED: EXIT CODE ${codesign_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
	exit 1
fi

package_tmp_dir="${TMPDIR}${script_name}_installation_package"

rm -rf "${package_tmp_dir}"
mkdir -p "${package_tmp_dir}"

rm -f "${payload_tmp_dir}/.DS_Store"

package_tmp_output_path="${package_tmp_dir}/${script_name}.pkg"

echo -e "\nCreating ${script_name} version ${script_version} installation package..."
pkgbuild \
	--install-location '/usr/local/bin' \
	--root "${payload_tmp_dir}" \
	--identifier "${package_id}" \
	--version "${script_version}" \
	"${package_tmp_output_path}"

pkgbuild_exit_code="$?"

rm -rf "${payload_tmp_dir}"

if (( pkgbuild_exit_code != 0 )) || [[ ! -f "${package_tmp_output_path}" ]]; then
	rm -rf "${package_tmp_dir}"
	>&2 echo -e "\nPKGBUILD ERROR OCCURRED CREATING INITIAL PACKAGE: EXIT CODE ${pkgbuild_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
	exit 1
fi

package_distribution_xml_output_path="${package_tmp_dir}/distribution.xml"

productbuild \
	--synthesize \
	--package "${package_tmp_output_path}" \
	"${package_distribution_xml_output_path}"

productbuild_synthesize_exit_code="$?"

if (( productbuild_synthesize_exit_code != 0 )) || [[ ! -f "${package_distribution_xml_output_path}" ]]; then
	rm -rf "${package_tmp_dir}"
	>&2 echo -e "\nPRODUCTBUILD SYNTHESIZE ERROR OCCURRED CREATING DISTRIBUTION XML: EXIT CODE ${productbuild_synthesize_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
	exit 2
fi

package_distribution_xml_header="$(head -2 "${package_distribution_xml_output_path}")"
package_distribution_xml_footer="$(tail +3 "${package_distribution_xml_output_path}")"

# Make sure this package is marked as Universal (to run without needing Rosetta on Apple Silicon) no matter what version of macOS it's being created on.
package_distribution_host_architectures_attribute_before="$(xmllint --xpath '//options/@hostArchitectures' "${package_distribution_xml_output_path}" 2> /dev/null)"
if ! [[ "${package_distribution_host_architectures_attribute_before}" =~ arm64[,\"] ]]; then
	if [[ "${package_distribution_host_architectures_attribute_before}" == *'hostArchitectures='* ]]; then # I'm not sure that it's actually possible for the "hostArchitectures" attribute to be set by any version of macOS when it wouldn't have already added arm64 to it as an option (it just doesn't exist by default on macOS 10.15 Catalina and older), but check for and add to an existing attribute anyways.
		package_distribution_xml_footer="${package_distribution_xml_footer//hostArchitectures=\"/hostArchitectures=\"arm64,}" # There should only be one "hostArchitectures" arribute, but update them all just in case.
	else # On macOS 10.15 Catalina and older, the "hostArchitectures" attribute will not be set at all and that will make Apple Silicon Macs think this package needs Rosetta when it really doesn't.
		# This is adding "hostArchitectures" as the first specified attribute instead of the last (as newer versions of macOS do), but the order of XML attributes within a tag doesn't matter.
		package_distribution_xml_footer="${package_distribution_xml_footer//<options /<options hostArchitectures=\"x86_64,arm64\" }" # There should only be one "options" tag, but update them all just in case.
	fi
fi

cat << CUSTOM_DISTRIBUTION_XML_EOF > "${package_distribution_xml_output_path}"
${package_distribution_xml_header}
    <title>${script_name} ${script_version}</title>
    <welcome language="en" mime-type="text/rtf"><![CDATA[{\rtf1\ansi
\fs36 \pard\qc \line
\b Install {\field{\*\fldinst HYPERLINK "https://mkuser.sh"}{\fldrslt mkuser}} ${script_version}\b0 \line
\line
\fs29 \b mkuser\b0  \ul m\ul0 a\ul k\ul0 es \ul user\ul0  accounts for macOS with more options, more validation of inputs, and more verification of the created user account than any other user creation tool, including \b sysadminctl -addUser\b0  and System Preferences!\line
\line
\fs28 \i \b mkuser\b0  will be installed into the "/usr/local/bin" folder so that you can run it in Terminal by just entering "mkuser".\i0 \line
\line
\fs26 Copyright \'a9 $(date '+%Y') {\field{\*\fldinst HYPERLINK "https://www.freegeek.org"}{\fldrslt Free Geek}}
}]]></welcome>
    <conclusion language="en" mime-type="text/rtf"><![CDATA[{\rtf1\ansi
\fs36 \pard\qc \line
\fs128 \uc0\u9989 \fs36 \line
\line
\b Successfully installed {\field{\*\fldinst HYPERLINK "https://mkuser.sh"}{\fldrslt mkuser}} ${script_version}!\b0 \line
\line
\fs28 \i \b mkuser\b0  is now installed into the "/usr/local/bin" folder so that you can run it in Terminal by just entering "mkuser".\i0 \line
\line
\fs26 Copyright \'a9 $(date '+%Y') {\field{\*\fldinst HYPERLINK "https://www.freegeek.org"}{\fldrslt Free Geek}}
}]]></conclusion>
    <volume-check>
        <allowed-os-versions>
            <os-version min="10.13.0"/>
        </allowed-os-versions>
    </volume-check>
${package_distribution_xml_footer}
CUSTOM_DISTRIBUTION_XML_EOF

if ! [[ "$(xmllint --xpath '//options/@hostArchitectures' "${package_distribution_xml_output_path}" 2> /dev/null)" =~ arm64[,\"] ]]; then # Make sure the updated "distribution.xml" file is marked as Universal (in case the manual edits above failed somehow).
	rm -rf "${package_tmp_dir}"
	>&2 echo -e "\nDISTRIBUTION.XML ERROR OCCURRED: Failed to mark package as Universal to be able to run on Apple Silicon Macs without requiring Rosetta."
	exit 3
fi

package_output_filename="${script_name}-${script_version}.pkg"
# Assets on a GitHub Release cannot contain spaces. If spaces exist, they will be replaced with periods.
# Instead of separating the name and version with a period, use a hyphen which matches the filename style of the source code downloads on GitHub Releases.

package_output_path="${SCRIPT_DIR}/${package_output_filename}"

rm -rf "${package_output_path}"

productbuild \
	--distribution "${package_distribution_xml_output_path}" \
	--package-path "${package_tmp_dir}" \
	--identifier "${package_id}" \
	--version "${script_version}" \
	--sign 'Developer ID Installer' \
	"${package_output_path}"

productbuild_exit_code="$?"

rm -rf "${package_tmp_dir}"

if (( productbuild_exit_code != 0 )) || [[ ! -f "${package_output_path}" ]]; then
	>&2 echo -e "\nPRODUCTBUILD ERROR OCCURRED CREATING/SIGNING INSTALLATION PACKAGE: EXIT CODE ${productbuild_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
	exit 4
fi

if [[ -d '/Applications/SD Notary.app' ]]; then
	echo -en "\nEnter \"Y\" to Confirm Notarizing ${script_name} Version ${script_version} Installation Package: "
	read -r confirm_notarization

	if [[ "${confirm_notarization}" =~ ^[Yy] ]]; then
		# Setting up "notarytool": https://scriptingosx.com/2021/07/notarize-a-command-line-tool-with-notarytool/ & https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow

		notarization_submission_log_path="${TMPDIR}${script_name}_package_notarization_submission.log"
		rm -rf "${notarization_submission_log_path}"

		echo -e "\nNotarizing ${script_name} version ${script_version} installation package..."
		xcrun notarytool submit "${package_output_path}" --keychain-profile 'notarytool App Specific Password' --wait | tee "${notarization_submission_log_path}" # Show live log since it may take a moment AND save to file to extract submission ID from to be able to load full notarization log.
		notarytool_exit_code="$?"

		notraization_submission_id="$(awk '($1 == "id:") { print $NF; exit }' "${notarization_submission_log_path}")"
		rm -f "${notarization_submission_log_path}"

		echo 'Notarization Log:'
		xcrun notarytool log "${notraization_submission_id}" --keychain-profile 'notarytool App Specific Password' # Always load and show full notarization log regardless of success or failure (since documentation states there could be warnings).

		if (( notarytool_exit_code != 0 )); then
			>&2 echo -e "\nNOTARIZATION ERROR OCCURRED: EXIT CODE ${notarytool_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
		 	exit 5
		fi

		echo -e "\nStapling notarization ticket to ${script_name} version ${script_version} installation package..."
		xcrun stapler staple "${package_output_path}"
		stapler_exit_code="$?"

		if (( stapler_exit_code != 0 )); then
			>&2 echo -e "\nSTAPLING ERROR OCCURRED: EXIT CODE ${stapler_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
		 	exit 6
		fi

		echo -e "\nAssessing notarized ${script_name} version ${script_version} installation package..."
		spctl_assess_output="$(spctl --assess -vvv --type install "${package_output_path}" 2>&1)"
		spctl_assess_exit_code="$?"

		echo "${spctl_assess_output}"

		if (( spctl_assess_exit_code != 0 )) || [[ "${spctl_assess_output}" != *$'\nsource=Notarized Developer ID\n'* ]]; then # Double-check that the package got assessed to signed with "Notarized Developer ID".
			>&2 echo -e "\nASSESSMENT ERROR OCCURRED: EXIT CODE ${spctl_assess_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
		 	exit 7
		fi

		echo -e "\nSuccessfully notarized ${script_name} version ${script_version} installation package!"
	else
		echo -e "\nChose NOT to notarize the ${script_name} version ${script_version} installation package."
	fi
else
	echo -e "\nInstall SD Notary to be able to notarize the ${script_name} version ${script_version} installation package: https://latenightsw.com/sd-notary-notarizing-made-easy/"
fi

open -R "${package_output_path}"
