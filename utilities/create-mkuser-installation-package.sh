#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

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

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}/.." &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}/" || echo '/private/tmp/')" # Make sure "TMPDIR" is always set and that it always has a trailing slash for consistency regardless of the current environment.

id_prefix='org.freegeek.'
script_name='mkuser'

script_path="${SCRIPT_DIR}/${script_name}.sh"

if [[ ! -f "${script_path}" || ! -x "${script_path}" ]]; then
	>&2 echo -e "\nSOURCE SCRIPT NOT FOUND AT PATH: ${script_path}"
	exit 1
fi

package_id="${id_prefix}pkg.${script_name}"

payload_tmp_dir="${TMPDIR}${script_name}_installation_payload"

rm -rf "${payload_tmp_dir}"
mkdir -p "${payload_tmp_dir}"

cat "${script_path}" > "${payload_tmp_dir}/${script_name}" # Instead of copying the file, write the *contents* to a new file to be sure that no xattrs are ever included in the distributed script (such as "com.apple.macl" which is TCC protected).

if [[ ! -f "${payload_tmp_dir}/${script_name}" ]] || (( $(stat -f '%z' "${payload_tmp_dir}/${script_name}") == 0 )); then
	rm -rf "${payload_tmp_dir}"
	>&2 echo -e "\nFAILED TO WRITE SCRIPT SOURCE FROM \"${script_path}\" TO \"${payload_tmp_dir}/${script_name}\""
	exit 2
fi

chmod +x "${payload_tmp_dir}/${script_name}"

script_version="$(awk -F "'" '/VERSION=/ { print $(NF-1); exit }' "${payload_tmp_dir}/${script_name}")"
if [[ -z "${script_version}" ]]; then script_version="$(date '+%Y.%-m.%-d')"; fi # https://strftime.org

echo -e "\nCode Signing ${script_name} Version ${script_version} Script for Package..."
codesign -s 'Developer ID Application' --prefix "${id_prefix}" --strict "${payload_tmp_dir}/${script_name}" # Set a proper identifier prefix since just the filename would be used if none is specified.

codesign_exit_code="$?"

spctl_assess_last_line="$(spctl -avvt open --context context:primary-signature "${payload_tmp_dir}/${script_name}" 2>&1 | tail -1)" # Only capture the last line to output and check (which will be the "origin" line when successful or an error if the siganture was invalid) since that's all thats relevant
# because "spctl -avvt open ..." will "fail" with "rejected" since it rejects any flat files that are not notarized, but scripts cannot be notarized so signing is the most that can be done (packages, disk images, and Mach-O binaries are the only flat files that can be notarized).
echo "${spctl_assess_last_line}"

readonly INTENDED_CODE_SIGNATURE_TEAM_ID='YRW6NUGA63'

if ! codesign -vv --strict -R "=identifier \"${id_prefix}${script_name}\" and certificate leaf[subject.OU] = \"${INTENDED_CODE_SIGNATURE_TEAM_ID}\"" "${payload_tmp_dir}/${script_name}" || (( codesign_exit_code != 0 )) || [[ "${spctl_assess_last_line}" != *"(${INTENDED_CODE_SIGNATURE_TEAM_ID})" ]]; then
	rm -rf "${payload_tmp_dir}"
	>&2 echo -e "\nCODESIGN ERROR OCCURRED: EXIT CODE ${codesign_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
	exit 3
fi

script_checksum="$(openssl dgst -sha512 "${payload_tmp_dir}/${script_name}" | awk '{ print $NF; exit }')"

zip_output_filename="${script_name}-${script_version}.zip"
# Assets on a GitHub Release cannot contain spaces. If spaces exist, they will be replaced with periods.
# Instead of separating the name and version with a period, use a hyphen which matches the filename style of the source code downloads on GitHub Releases.

ditto -ck --sequesterRsrc --zlibCompressionLevel 9 "${payload_tmp_dir}/${script_name}" "${payload_tmp_dir}/${zip_output_filename}"
# IMPORTANT: On macOS 10.15 Catalina and older, it appears that extended attributes (xattr) ARE NOT preserved and are removed during the package installation process.
# This means that the script's code signature (store in the extended attributes) ARE LOST if the script is installed directly by a package on macOS 10.15 Catalina and older.
# To workaround this issue, ZIPPING the script first preserves the code signature extended attributes since the package installation process would only be removing
# any (non-existant) extended attributes from the zip file itself and not the script within the zip, and zipping/unzipping using "ditto" properly preserves the extended attributes.
# So, the zipped script will be installed into a temporary location "/private/tmp/[SCRIPT NAME]-[SCRIPT VERSION].zip" and then unzipped and
# installed into "/usr/local/bin" final destination by the "postinstall" script which also verifies the scripts code signature and checksum.
# NOTE: Zipping and unzipping MUST be done with "ditto" since it properly preserves and restores extended attributes, unlike "zip" and "unzip".

zip_checksum="$(openssl dgst -sha512 "${payload_tmp_dir}/${zip_output_filename}" | awk '{ print $NF; exit }')"

release_dir="${SCRIPT_DIR}/Release ${script_version}"
rm -rf "${release_dir}"

# Save a copy of the signed "zip" to include in the GitHub release.
ditto "${payload_tmp_dir}/${zip_output_filename}" "${release_dir}/${zip_output_filename}" # "ditto" will create missing parent folders.

rm -f "${payload_tmp_dir}/.DS_Store"

echo -e "\nCreating \"postinstall\" Script for ${script_name} Version ${script_version} Package..."

scripts_tmp_dir="${TMPDIR}${script_name}_installation_scripts"

rm -rf "${scripts_tmp_dir}"
mkdir -p "${scripts_tmp_dir}"

cat << POSTINSTALL_EOF > "${scripts_tmp_dir}/postinstall"
#!/bin/bash

PATH='/usr/bin:/bin:/usr/sbin:/sbin'

TMPDIR="\$([[ -d "\${TMPDIR}" && -w "\${TMPDIR}" ]] && echo "\${TMPDIR%/}/" || echo '/private/tmp/')" # Make sure "TMPDIR" is always set and that it always has a trailing slash for consistency regardless of the current environment.

echo '${script_name} INSTALL: Verifying ${script_name} Version ${script_version} Code Signature and Checksum in Temporary Location...'

tmp_script_path="\${TMPDIR}${script_name}"
rm -rf "\${tmp_script_path}"

intended_zip_checksum='${zip_checksum}'
echo "${script_name} INSTALL: Intended Archive Checksum = \${intended_zip_checksum}"

tmp_zip_path='/private/tmp/${zip_output_filename}'

actual_zip_checksum="\$(openssl dgst -sha512 "\${tmp_zip_path}" | awk '{ print \$NF; exit }')"
echo "${script_name} INSTALL: Actual Archive Checksum = \${actual_zip_checksum}"

if [[ "\${actual_zip_checksum}" != "\${intended_zip_checksum}" ]]; then
	rm -f "\${tmp_zip_path}"
	>&2 echo '${script_name} INSTALL ERROR: INVALID ARCHIVE CHECKSUM (SEE OUTPUT ABOVE FOR MORE INFO)'
	exit 1
fi

# NOTE: The script is within a zip (created using with "ditto") to preserve the code signature extended attributes which would be
# removed by the package installation process on macOS 10.15 Catalina and older if the script was installed directly by the package.
ditto -xkvV "\${tmp_zip_path}" "\${TMPDIR}" # Also, unzipping MUST be done with "ditto" since it properly restores extended attributes, unlike "unzip".
ditto_exit_code="\$?"

rm -f "\${tmp_zip_path}"

if (( ditto_exit_code != 0 )) || [[ ! -f "\${tmp_script_path}" || ! -x "\${tmp_script_path}" ]]; then
	rm -f "\${tmp_script_path}"
	>&2 echo '${script_name} INSTALL ERROR: FAILED TO UNZIP SCRIPT TO TEMPORARY LOCATION FOR VERIFICATION'
	exit 2
fi

verify_code_signature_and_checksum_at_path() {
	codesign -vv --strict -R '=$(codesign -dr - "${payload_tmp_dir}/${script_name}" 2> /dev/null | awk -F ' => ' '($1 == "designated") { print $2; exit }')' "\$1"
	local codesign_verify_exit_code="\$?"

	local spctl_assess_last_line
	spctl_assess_last_line="\$(spctl -avvt open --context context:primary-signature "\$1" 2>&1 | tail -1)" # Only capture the last line to output and check (which will be the "origin" line when successful or an error if the siganture was invalid) since that's all thats relevant
	# because "spctl -avvt open ..." will "fail" with "rejected" since it rejects any flat files that are not notarized, but scripts cannot be notarized so signing is the most that can be done (packages, disk images, and Mach-O binaries are the only flat files that can be notarized).
	echo "\${spctl_assess_last_line}"

	local intended_script_checksum='${script_checksum}'
	echo "${script_name} INSTALL: Intended Script Checksum = \${intended_script_checksum}"

	local actual_script_checksum
	actual_script_checksum="\$(openssl dgst -sha512 "\$1" | awk '{ print \$NF; exit }')"
	echo "${script_name} INSTALL: Actual Script Checksum = \${actual_script_checksum}"

	if (( codesign_verify_exit_code != 0 )) || [[ "\${spctl_assess_last_line}" != *'(${INTENDED_CODE_SIGNATURE_TEAM_ID})' || "\${actual_script_checksum}" != "\${intended_script_checksum}" ]]; then # Checksum verification is part of "codesign" verification and "spctl" assessment, but manually verify it anyways.
		return 1
	fi

	return 0
}

if ! verify_code_signature_and_checksum_at_path "\${tmp_script_path}"; then
	rm -f "\${tmp_script_path}"
	>&2 echo '${script_name} INSTALL ERROR: INVALID CODE SIGNATURE OR CHECKSUM AT TEMPORARY LOCATION (SEE OUTPUT ABOVE FOR MORE INFO)'
	exit 3
fi

install_folder='/usr/local/bin'
install_script_path="\${install_folder}/${script_name}"

echo "${script_name} INSTALL: Moving Verified ${script_name} Version ${script_version} to \"\${install_script_path}\" and Re-Verifying Code Signature and Checksum..."

mkdir -p "\${install_folder}"
rm -rf "\${install_script_path}"
mv -f "\${tmp_script_path}" "\${install_script_path}"

if ! verify_code_signature_and_checksum_at_path "\${install_script_path}"; then
	rm -f "\${install_script_path}"
	>&2 echo "${script_name} INSTALL ERROR: INVALID CODE SIGNATURE OR CHECKSUM AT \"\${install_script_path}\" (SEE OUTPUT ABOVE FOR MORE INFO)"
	exit 4
fi

echo "${script_name} INSTALL: Successfully installed and verified ${script_name} version ${script_version} to \"\${install_script_path}\"!"
POSTINSTALL_EOF

chmod +x "${scripts_tmp_dir}/postinstall"
rm -f "${scripts_tmp_dir}/.DS_Store"

rm -f "${payload_tmp_dir}/${script_name}"

package_tmp_dir="${TMPDIR}${script_name}_installation_package"

rm -rf "${package_tmp_dir}"
mkdir -p "${package_tmp_dir}"

package_tmp_output_path="${package_tmp_dir}/${script_name}.pkg"

echo -e "\nCreating ${script_name} Version ${script_version} Installation Package..."
pkgbuild \
	--install-location '/private/tmp' \
	--root "${payload_tmp_dir}" \
	--scripts "${scripts_tmp_dir}" \
	--identifier "${package_id}" \
	--version "${script_version}" \
	"${package_tmp_output_path}"

pkgbuild_exit_code="$?"

rm -rf "${payload_tmp_dir}"
rm -rf "${scripts_tmp_dir}"

if (( pkgbuild_exit_code != 0 )) || [[ ! -f "${package_tmp_output_path}" ]]; then
	rm -rf "${package_tmp_dir}"
	>&2 echo -e "\nPKGBUILD ERROR OCCURRED CREATING INITIAL PACKAGE: EXIT CODE ${pkgbuild_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
	exit 4
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
	exit 5
fi

package_distribution_xml_header="$(head -2 "${package_distribution_xml_output_path}")"
package_distribution_xml_footer="$(tail +3 "${package_distribution_xml_output_path}")"

# Make sure this package is marked as Universal (to run without needing Rosetta on Apple Silicon) no matter what version of macOS it's being created on.
package_distribution_host_architectures_attribute_before="$(xmllint --xpath '//options/@hostArchitectures' "${package_distribution_xml_output_path}" 2> /dev/null)"
if [[ ! "${package_distribution_host_architectures_attribute_before}" =~ arm64[,\"] ]]; then
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
\b Install {\field{\*\fldinst HYPERLINK "https://${script_name}.sh"}{\fldrslt ${script_name}}} ${script_version}\b0 \line
\line
\fs29 \b ${script_name}\b0  \ul m\ul0 a\ul k\ul0 es \ul user\ul0  accounts for macOS with more options, more validation of inputs, and more verification of the created user account than any other user creation tool, including \b sysadminctl -addUser\b0 \line
and System Preferences/Settings!\line
\line
\fs28 \i \b ${script_name}\b0  will be installed into the "/usr/local/bin" folder so that you can run it in Terminal by just entering "${script_name}".\i0 \line
\line
\fs26 Copyright \'a9 $(date '+%Y') {\field{\*\fldinst HYPERLINK "https://www.freegeek.org"}{\fldrslt Free Geek}}
}]]></welcome>
    <conclusion language="en" mime-type="text/rtf"><![CDATA[{\rtf1\ansi
\fs36 \pard\qc \line
\fs128 \uc0\u9989 \fs36 \line
\line
\b Successfully installed {\field{\*\fldinst HYPERLINK "https://${script_name}.sh"}{\fldrslt ${script_name}}} ${script_version}!\b0 \line
\line
\fs28 \i \b ${script_name}\b0  is now installed into the "/usr/local/bin" folder so that you can run it in Terminal by just entering "${script_name}".\i0 \line
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

if [[ ! "$(xmllint --xpath '//options/@hostArchitectures' "${package_distribution_xml_output_path}" 2> /dev/null)" =~ arm64[,\"] ]]; then # Make sure the updated "distribution.xml" file is marked as Universal (in case the manual edits above failed somehow).
	rm -rf "${package_tmp_dir}"
	>&2 echo -e "\nDISTRIBUTION.XML ERROR OCCURRED: Failed to mark package as Universal to be able to run on Apple Silicon Macs without requiring Rosetta."
	exit 6
fi

package_output_filename="${script_name}-${script_version}.pkg"
# Assets on a GitHub Release cannot contain spaces. If spaces exist, they will be replaced with periods.
# Instead of separating the name and version with a period, use a hyphen which matches the filename style of the source code downloads on GitHub Releases.

package_output_path="${release_dir}/${package_output_filename}"

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
	exit 7
fi

echo -en "\nEnter \"Y\" to Notarize ${script_name} Version ${script_version} Installation Package: "
read -r confirm_notarization

pkg_checksum='UNNOTARIZED'

if [[ "${confirm_notarization}" =~ ^[Yy] ]]; then
	# Setting up "notarytool": https://scriptingosx.com/2021/07/notarize-a-command-line-tool-with-notarytool/ & https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow

	notarization_submission_log_path="${TMPDIR}${script_name}_package_notarization_submission.log"
	rm -rf "${notarization_submission_log_path}"

	echo -e "\nNotarizing ${script_name} Version ${script_version} Installation Package..."
	xcrun notarytool submit "${package_output_path}" --keychain-profile 'notarytool App Specific Password' --wait | tee "${notarization_submission_log_path}" # Show live log since it may take a moment AND save to file to extract submission ID from to be able to load full notarization log.
	notarytool_exit_code="$?"

	notarization_submission_id="$(awk '($1 == "id:") { print $NF; exit }' "${notarization_submission_log_path}")"
	rm -f "${notarization_submission_log_path}"

	echo 'Notarization Log:'
	xcrun notarytool log "${notarization_submission_id}" --keychain-profile 'notarytool App Specific Password' # Always load and show full notarization log regardless of success or failure (since documentation states there could be warnings).

	if (( notarytool_exit_code != 0 )); then
		>&2 echo -e "\nNOTARIZATION ERROR OCCURRED: EXIT CODE ${notarytool_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
		exit 8
	fi

	echo -e "\nStapling Notarization Ticket to ${script_name} Version ${script_version} Installation Package..."
	xcrun stapler staple "${package_output_path}"
	stapler_exit_code="$?"

	if (( stapler_exit_code != 0 )); then
		>&2 echo -e "\nSTAPLING ERROR OCCURRED: EXIT CODE ${stapler_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
		exit 9
	fi

	echo -e "\nAssessing Notarized ${script_name} Version ${script_version} Installation Package..."
	spctl_assess_output="$(spctl -avvt install "${package_output_path}" 2>&1)"
	spctl_assess_exit_code="$?"

	echo "${spctl_assess_output}"

	pkgutil_check_signature_output="$(pkgutil --check-signature "${package_output_path}" 2>&1)"
	pkgutil_check_signature_exit_code="$?"

	echo "${pkgutil_check_signature_output}"

	if (( spctl_assess_exit_code != 0 || pkgutil_check_signature_exit_code != 0 )) || [[ "${spctl_assess_output}" != *$'\nsource=Notarized Developer ID\n'*"(${INTENDED_CODE_SIGNATURE_TEAM_ID})" || "${pkgutil_check_signature_output}" != *$'\n   Notarization: trusted by the Apple notary service\n'* || "${pkgutil_check_signature_output}" != *$'\n    1. Developer ID Installer: '*" (${INTENDED_CODE_SIGNATURE_TEAM_ID})"$'\n'* ]]; then # Double-check that the package got assessed to be signed with "Notarized Developer ID" and the correct Team ID.
		# The "spctl -avv" output will only ever include "source=Notarized Developer ID" when running on macOS 10.14 Mojave and newer and the "pkgutil --check-signature" output will only contain the "Notarization" line on macOS 12 Monterey and newer, but we should only be building on the latest version of macOS so don't need to worry about checking the current OS version for these verifications.
		>&2 echo -e "\nASSESSMENT ERROR OCCURRED: SPCTL EXIT CODE ${spctl_assess_exit_code} & PKGUTIL EXIT CODE ${pkgutil_check_signature_exit_code} (ALSO SEE ERROR MESSAGES ABOVE)"
		exit 10
	fi

	echo -e "\nSuccessfully notarized ${script_name} version ${script_version} installation package!"

	pkg_checksum="$(openssl dgst -sha512 "${package_output_path}" | awk '{ print $NF; exit }')"
else
	echo -e "\nChose NOT to notarize the ${script_name} version ${script_version} installation package."
	mv "${package_output_path}" "${package_output_path/.pkg/-UNNOTARIZED.pkg}" # Rename unnotarized package so that I never accidentally publish it.
fi

echo -e '\nVerifying Checksums of Package and Archive (and currently installed script which may fail if it is not the latest version)...'

printf '%s  %s\n' \
	"${pkg_checksum}" "${package_output_filename}" \
	"${zip_checksum}" "${zip_output_filename}" \
	"${script_checksum}" "/usr/local/bin/${script_name}" > "${release_dir}/${script_name}-sha512-checksums-${script_version}.txt" # Save all checksums in a format that can be used with "shasum -c".

cd "${release_dir}" || exit 11 # Must "cd" into "release_dir" to be able to verify the checksums file using "shasum -c".
shasum -c "${script_name}-sha512-checksums-${script_version}.txt" # The "/usr/local/bin/mkuser" verification may fail if I don't currently have the latest version being built installed (since it's not uncommon to keep the previous release version installed until after I run this script to finalize a new release).

open "${release_dir}"
