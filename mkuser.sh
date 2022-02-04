#!/bin/bash

mkuser() ( # Notice "(" instead of "{" for this function, see THIS IS A SUBSHELL FUNCTION comments below.

	##
	## Created by Pico Mitchell (of Free Geek) on 5/13/21
	##
	## https://mkuser.sh
	##
	## MIT License
	##
	## Copyright (c) 2021 Free Geek
	##
	## Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
	## to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
	## and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
	##
	## The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
	##
	## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
	## WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
	##

	# THIS IS A SUBSHELL FUNCTION
	# Subshell functions are entirely self contained.
	# All of the variables (and functions) within a subshell function only exist within the scope of the subshell function (like a regular subshell).
	# This means that every variable does NOT need to be declared as "local" and even altering "PATH" only affects the scope of this subshell function.

	readonly MKUSER_VERSION='2022.2.3-1'

	PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy. ("export" is not required since PATH is already exported in the environment, therefore modifying it modifies the already exported variable.)

	# Initialize all default values for variables which can be set from the command line options and parameters.

	user_account_name=''
	user_full_name=''
	user_uid=''
	user_guid=''
	user_gid=''
	user_shell=''

	user_password=''
	did_get_password_from_stdin=false
	prompt_for_user_password=false
	user_password_hint=''
	set_prohibit_user_password_changes=false

	user_home_path=''
	do_not_share_public_folder=false
	do_not_create_home_folder=false

	user_picture_path=''
	set_no_picture=false
	set_prohibit_user_picture_changes=false

	set_admin=false
	set_hidden_user=false
	set_hidden_home=false
	set_sharing_only_account=false
	set_role_account=false
	set_service_account=false
	set_prevent_secure_token_on_big_sur_and_newer=false

	st_admin_account_name=''
	st_admin_password=''
	prompt_for_st_admin_password=false

	set_auto_login=false
	skip_setup_assistant_on_first_boot=false
	skip_setup_assistant_on_first_login=false

	make_package=false
	# <MKUSER-BEGIN-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!
	pkg_path=''
	pkg_version=''
	pkg_identifier=''
	pkg_sign=''
	# <MKUSER-END-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!

	do_not_confirm=false
	suppress_status_messages=false
	check_only=false

	# <MKUSER-BEGIN-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!
	show_version=false
	show_releases_online=false
	show_help="$( (( $# == 0 )) && echo 'true' || echo 'false' )"
	show_brief_help=false
	show_help_online=false
	# <MKUSER-END-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!

	readonly IS_PACKAGE=false # This will be set to "true" when this script is modified during package creation.

	error_code='1' # This error code will be incremented as it passes each potential error.

	if [[ -n "${ZSH_VERSION}" ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: This tool is not compatible with zsh and must be run in bash instead."
		return "${error_code}"
	elif [[ -d '/System/Installation' && ! -f '/usr/bin/pico' ]]; then # The specified folder should exist in recoveryOS and the file should not.
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: This tool cannot be run within recoveryOS."
		return "${error_code}"
	elif [[ "$(uname)" != 'Darwin' ]]; then # Check this AFTER checking if running in recoveryOS since "uname" doesn't exist in recoveryOS.
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: This tool can only run on macOS."
		return "${error_code}"
	fi
	(( error_code ++ ))

	readonly A_Z='ABCDEFGHIJKLMNOPQRSTUVWXYZ' # Set these "A_Z" and "a_z" variables for use in regex and string manipulation to conveniently specify english letters directly instead of using character ranges like "[A-Za-z]" or classes like "[[:alpha:]]"
	readonly a_z='abcdefghijklmnopqrstuvwxyz' # so the intended characters are always matched regardless of locale, and without having to set LC_COLLATE=C for the desired behavior. http://teaching.idallen.com/cst8177/13w/notes/000_character_sets.html
	readonly DIGITS='0123456789' # And do the same with digits since the "[[:digit:]]" character class could also include other characters in some locales (the "[0-9]" character range is probably safe but better to be specific). https://unix.stackexchange.com/questions/414226/difference-between-0-9-digit-and-d/414230#414230


	# PARSE OPTIONS AND PARAMETERS

	has_invalid_options=false # If ANY options or parameters were INVALID, DO NOT create a user or package with possibly unintended settings.

	valid_options_for_package=() # Need to collect valid user creation options to use within package if making a package.

	all_actual_case_options=''
	all_options_as_list=''
	if [[ -f "${BASH_SOURCE[0]}" ]]; then
		all_actual_case_options="$(awk '(($1 ~ /^-.*\)$/) && ($3 == "<MKUSER-VALID-OPTIONS>")) { print $1 }' "${BASH_SOURCE[0]}")" # Also check for the "<MKUSER-VALID-OPTIONS>" to never include other case statement options if this function is included in a larger script that takes arguments, etc.
		all_actual_case_options="${all_actual_case_options//)/}" # This variable will be used in "--help" information to confirm all options have help info.
		all_options_as_list="${all_actual_case_options//|/$'\n'}"
	fi

	short_options_as_list="$(echo "${all_options_as_list}" | grep '^.\{2\}$')"
	short_options_as_list_without_hyphens="${short_options_as_list//-/}"

	long_options_as_array_reverse_sorted=()
	long_options_as_array_reverse_sorted_without_word_hyphens=()
	while IFS='' read -r this_option_line; do
		long_options_as_array_reverse_sorted+=( "${this_option_line}" )
		long_options_as_array_reverse_sorted_without_word_hyphens+=( "--${this_option_line//-/}" ) # This list will be used to allow options to be passed without the word separating hyphens.
	done <<< "$(echo "${all_options_as_list}" | grep '^.\{3\}' | sort -r)" # Must be reverse sorted to always find the longest partial match first in a loop.

	long_options_count="${#long_options_as_array_reverse_sorted[@]}"

	if (( long_options_count <= 1 )) || [[ -z "${short_options_as_list_without_hyphens}" ]]; then
		>&2 echo 'mkuser WARNING: Failed to retrieve valid options from script source. This will cause grouped short options to be invalid since they will not be separated, options and parameters grouped together without whitespace or equals will be invalid, and options with word separating hyphens omitted will be invalid (CONTINUING ANYWAY SINCE PASSING VALID OPTIONS IS STILL POSSIBLE, BUT THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE).'
	fi

	while (( $# > 0 )); do
		this_option_group=()

		if [[ "$1" =~ ^\-{1}[^-]+ ]]; then # Short form (single character) options specified with a single hyphen can be grouped together or have a parameter passed with an equals or with no whitespace or equals, so they need to be parsed and re-formatted for the next loop.
			if [[ -z "${short_options_as_list_without_hyphens}" ]]; then
				this_option_group=( "$1" ) # If failed to retrieve valid short options from source, pass any grouped short options as-is since tring to un-group them would fail. This will cause errors to be displayed in the next loop.
			else
				for (( this_option_group_char_index = 1; this_option_group_char_index < ${#1}; this_option_group_char_index ++ )); do
					next_option_char="${1:${this_option_group_char_index}+1:1}"

					if [[ "${next_option_char}" == '=' ]]; then # If the next char is "=" then assume the parameter is being passed with "=" and pass this whole equal separated option and parameter together and break this loop since it will be handled properly in the next loop.
						this_option_group+=( "-${1:${this_option_group_char_index}}" )
						break
					elif [[ -n "${next_option_char}" && $'\n'"${short_options_as_list_without_hyphens}"$'\n' != *$'\n'"${next_option_char}"$'\n'* ]]; then # If next option is invalid, consider it a combined option and parameter without whitespace or equals.
						this_option_group+=( "-${1:${this_option_group_char_index}:1}=${1:${this_option_group_char_index}+1}" ) # Turn combined option and parameter into equals separated for the next loop to handle properly.
						break
					else
						this_option_group+=( "-${1:${this_option_group_char_index}:1}" ) # If it's a valid short form option, pass it as-is since it's valid.
					fi
				done
			fi
		else
			this_lowercase_long_option="$(echo "$1" | tr '[:upper:]' '[:lower:]')" # Long options are matched lowercase since since case doesn't matter.

			if (( long_options_count <= 1 )) || [[ ( ! "$1" =~ ^\-{2}[^-]+ ) || "$1" == *'='* || " ${long_options_as_array_reverse_sorted[*]} " == *" ${this_lowercase_long_option} "* || " ${long_options_as_array_reverse_sorted_without_word_hyphens[*]} " == *" ${this_lowercase_long_option} "* ]]; then
				# If failed to retrieve long options from source, pass any and all options and parameters as-is since trying to do any parsing will fail.
				# If this is an invalid option passed without hyphens or with too many hyphens, pass it as-is to display an error in the next loop.
				# If this option contains an equals, assume it's a long form option with its parameter included after the equals and pass it as-is since it will be handled properly in the next loop.
				# If this is a valid long form option with or without word separating hyphens, pass it as-is since it's valid (word separating hypens will be added back in the next loop).

				this_option_group=( "$1" ) # DO NOT pass this_lowercase_long_option since $1 may include a parameter after equals that shouldn't have its case changed.
			else # If this is a long form option that is not valid and does not have an equals, check if it is actually a valid long form option with its parameter combined with no whitespace or equals.
				did_find_long_option_match=false

				for (( this_valid_option_index = 0; this_valid_option_index < long_options_count; this_valid_option_index ++ )); do
					this_valid_long_option="${long_options_as_array_reverse_sorted[${this_valid_option_index}]}"
					this_valid_long_option_without_word_hyphens="${long_options_as_array_reverse_sorted_without_word_hyphens[${this_valid_option_index}]}"

					# The following parameter extraction must be done by trimming length of valid option since option matching is case insensitive and we don't want to change the case of parameter.
					if [[ "${this_lowercase_long_option}" == "${this_valid_long_option}"* ]]; then # Found valid option prefix, so assume this is a valid long form option with its parameter combined with no whitespace or equals.
						this_option_group=( "${this_valid_long_option}=${1:${#this_valid_long_option}}" ) # Turn valid combined option and parameter into equals separated for the next loop to handle properly.
						did_find_long_option_match=true
						break
					elif [[ "${this_lowercase_long_option}" == "${this_valid_long_option_without_word_hyphens}"* ]]; then # Found valid option without word separating hyphens prefix, so assume this is a valid long form option without word separating hyphens with its parameter combined with no whitespace or equals.
						this_option_group=( "${this_valid_long_option}=${1:${#this_valid_long_option_without_word_hyphens}}" ) # Turn valid combined option without word separating hyphens and parameter into equals separated for the next loop to handle properly.
						did_find_long_option_match=true
						break
					fi
				done

				if ! $did_find_long_option_match; then
					this_option_group=( "$1" ) # If it's just an invalid option, pass it as-is to display an error in the next loop.
				fi
			fi
		fi

		shift

		this_option_group_count="${#this_option_group[@]}"
		for (( this_option_group_index = 0; this_option_group_index < this_option_group_count; this_option_group_index ++ )); do
			this_unaltered_option="${this_option_group[${this_option_group_index}]}"

			if [[ "${this_unaltered_option}" == '-'* && "${this_unaltered_option}" == *'='* ]]; then # If option was passed with "=", then extract and add the parameter to the front of the arguments array and update the option string to the actual option.
				set -- "${this_unaltered_option#*=}" "$@" # Add actual parameter to front of arguments array so subsequent code retrieving "$1" or using "shift" does not need to change.
				this_unaltered_option="${this_unaltered_option%"=$1"}" # Get actual option string by removing the newly set $1 (plus a leading "=") from the end of the original full option and parameter string.
			fi

			this_option="${this_unaltered_option}"

			# Make all long form options case-insensitive, but still want "-H" to be different from "-h" etc.
			if [[ "${this_option}" =~ ^\-{2}[^-]+ ]]; then
				this_option="$(echo "${this_option}" | tr '[:upper:]' '[:lower:]')"

				# If this has NO word separating hyphens and IS NOT a valid option, see if it has just had the word separating hyphens omitted and translate it if so.
				if (( long_options_count > 1 )) && [[ "${this_option//[^-]/}" == '--' && " ${long_options_as_array_reverse_sorted[*]} " != *" ${this_option} "* ]]; then
					for (( this_valid_option_index = 0; this_valid_option_index < long_options_count; this_valid_option_index ++ )); do
						if [[ "${long_options_as_array_reverse_sorted_without_word_hyphens[${this_valid_option_index}]}" == "${this_option}" ]]; then
							this_option="${long_options_as_array_reverse_sorted[${this_valid_option_index}]}"
							break
						fi
					done
				fi
			fi

			# This will always be true for long form option, but must be checked for short form options with parameters since they must be the last in the group and the only option in the group to take a parameter.
			is_last_option_in_group="$( (( this_option_group_count == ( this_option_group_index + 1 ) )) && echo 'true' || echo 'false' )"

			case "${this_option}" in
				--account-name|--record-name|--short-name|--username|--user|--name|-n) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if $is_last_option_in_group; then
						if [[ -n "$1" ]]; then
							if [[ "$1" != '-'* ]]; then # See comments below about not allowing account names starting with "-".
								if [[ -z "${user_account_name}" ]]; then
									if [[ "$1" =~ ^[${a_z}${DIGITS}_][${a_z}${DIGITS}_.-]*$ ]]; then # More account name validation will be done below, but at least validate that it's all lowercase letters, numbers, hyphen/minus, underscore, or period characters (and doesn't start with a period or hyphen/minus).
										user_account_name="$1" # Will be set to cleaned version of user_full_name if not specified.
										valid_options_for_package+=( "${this_option}" "${user_account_name}" )
									else
										>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must only contain lowercase letters, numbers, hyphen/minus (-), underscore (_), or period (.) characters (and cannot start with a period)."
										has_invalid_options=true

										# System Preferences, "sysadminctl -addUser", and Setup Assistant DO allow account names to start with "." even though they seem to be problematic and DO NOT show up in "dscacheutil -q user" and "dscl . -list /Users".
										# Also, account names that start with "." BREAK System Preferences and sysadminctl's next available UID checks which cause subsequent users to NOT get UIDs since they are getting assigned to the existing UID taken by the
										# account names that start with "." and failing to assign it. But, "mkuser" goes out of its way to check for these users directly from the "dslocal" plists so that the next available UID checking in this script is always accurate.
										# This problematic behavior was tested and confirmed on both macOS 11 Big Sur and macOS 10.13 High Sierra.
									fi
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
									has_invalid_options=true
								fi

								shift
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it cannot start with a hyphen/minus (-) character."
								has_invalid_options=true

								# System Preferences and "sysadminctl -addUser" DO NOT allow account names to start with "-", but Setup Assistant DOES. This script will not allow them for the following reasons...
								# Account names to start with "-" should not really be allowed by macOS at all since they can be interpreted as options in command line tools instead of usernames, and some important tools have no way around that issue (while some do).
								# For example, the "login" command sees an account name starting with a "-" as an (illegal) option, which causes Terminal to exit with an error from the "login" command and never get to the login shell.
								# This is because Terminal runs "login <username>" instead of "login -- <username>" which would work.
								# Also, account names starting with "-" are totally unusable with "sysadminctl" (such as "sysadminctl -secureTokenOn") since it sees them as (invalid) options and there is no way (such as using "--") to make it recognize them as a username parameter that I could figure out.
								# This affects a variety of other commands as well. For example, "id" can work with "id --" (like "login" can) but "dscacheutil -q user -a name" cannot recognize a username starting with a "-" as anything other than an (invalid) option (like "sysadminctl" does).
							fi
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to use the default value."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" requires a parameter. When used in a group, it must be the last option specified and the only option with a parameter."
						has_invalid_options=true
					fi
					;;
				--full-name|--real-name|-f) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if $is_last_option_in_group; then
						if [[ -n "$1" ]]; then # Allow full names to start with "-" as System Preferences does, which is a bit risky if someone does something wrong like "--full-name --uid" which will set the full name to "--uid" and the parameter for "--uid" will become an invalid option and error.
							if [[ -z "${user_full_name}" ]]; then
								# DO NOT use "echo -e" to interpret any included backslash-escaped characters since that would only make it easier to include invalid line breaks.
								if [[ "$1" != *$'\n'* && -n "${1//[[:space:]]/}" ]]; then # Make sure there are no line breaks and that it's not only whitespace.
									user_full_name="$1" # Will be set to the user_account_name if not specified.
									valid_options_for_package+=( "${this_option}" "${user_full_name}" )
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it cannot be only whitespace or contain line breaks."
									has_invalid_options=true
								fi
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
								has_invalid_options=true
							fi

							shift
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to use the default value."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" requires a parameter. When used in a group, it must be the last option specified and the only option with a parameter."
						has_invalid_options=true
					fi
					;;
				--unique-id|--user-id|--uid|-u) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if $is_last_option_in_group; then
						if [[ -n "$1" ]]; then # Allow UIDs to be negative (start with "-").
							if [[ -z "${user_uid}" ]]; then
								if [[ "$1" =~ ^\-?[${DIGITS}]+$ ]]; then # Only allow numbers except for a leading minus (-) for negative numbers.
									user_uid="$1" # Next available UID starting from "501" (or "200" for Role/Service Accounts) will be assigned if not specified.

									if [[ "${user_uid}" == '0'* || "${user_uid}" == '-0'* ]]; then
										user_uid="${user_uid//[^${DIGITS}]/}" # Need to temporarily remove any minus sign to remove leading zeros.
										user_uid="$([[ "$1" == '-'* ]] && echo '-')${user_uid#"${user_uid%%[^0]*}"}" # Remove any leading zeros and add back any minus sign.
										if [[ -z "${user_uid}" || "${user_uid}" == '-' ]]; then user_uid='0'; fi # Catch if the number was all zeros with or without a minus sign.
									fi

									valid_options_for_package+=( "${this_option}" "${user_uid}" )

									shift # Only shift "$1" if it was a valid UID (all numbers), otherwise it might actually be the next valid option is someone made a mistake like "--uid --hint" or will show as an "invalid option" error.
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must be only numbers, except for a leading minus (-) for negative numbers."
									has_invalid_options=true
								fi
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
								has_invalid_options=true
							fi
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to use the default value."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" requires a parameter. When used in a group, it must be the last option specified and the only option with a parameter."
						has_invalid_options=true
					fi
					;;
				--generated-uid|--guid|--uuid|-G) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if $is_last_option_in_group; then
						if [[ -n "$1" ]]; then
							if [[ "$1" != '-'* ]]; then
								if [[ -z "${user_guid}" ]]; then
									if [[ "$1" =~ ^[${A_Z}${DIGITS}]{8}-[${A_Z}${DIGITS}]{4}-[${A_Z}${DIGITS}]{4}-[${A_Z}${DIGITS}]{4}-[${A_Z}${DIGITS}]{12}$ ]]; then # GUIDs can only contain capital letters, numbers, and hyphen/minus characters.
										user_guid="$1" # A random GUID will be assigned by macOS if not specified.
										valid_options_for_package+=( "${this_option}" "${user_guid}" )
									else
										>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must be 36 characters of only capital letters, numbers, and hyphens/minuses (-) in the following format: \"EIGHT888-4444-FOUR-4444-TWELVE121212\"."
										has_invalid_options=true

										# If the GUID does not have the correct number of characters between each hyphen (or is invalid in some other way), the user will be created
										# but the "Password" field will end up as plain text and no "ShadowHashData" etc will be set and the password will not authenticate the user.
										# Therefore, the user will be unable to log in. From random testing, I have found that valid GUIDs with certain characters or sets of characters
										# can also cause that password behavior, but I'm not confident in knowing what the exact things to check for are to avoid that here in this check.
									fi
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
									has_invalid_options=true
								fi

								shift
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it cannot start with a hyphen/minus (-) character."
								has_invalid_options=true
							fi
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to use the default value."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" requires a parameter. When used in a group, it must be the last option specified and the only option with a parameter."
						has_invalid_options=true
					fi
					;;
				--primary-group-id|--group-id|--group|--gid|-g) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if $is_last_option_in_group; then
						if [[ -n "$1" ]]; then # Allow GIDs to be negative (start with "-").
							if [[ -z "${user_gid}" ]]; then
								if [[ "$1" =~ ^\-?[${DIGITS}]+$ ]]; then # Only allow numbers except for a leading minus (-) for negative numbers.
									user_gid="$1" # Will be validated against existing Group IDs and will be set to default of "20" (or "-2" for Service Accounts) if not specified.

									if [[ "${user_gid}" == '0'* || "${user_gid}" == '-0'* ]]; then
										user_gid="${user_gid//[^${DIGITS}]/}" # Need to temporarily remove any minus sign to remove leading zeros.
										user_gid="$([[ "$1" == '-'* ]] && echo '-')${user_gid#"${user_gid%%[^0]*}"}" # Remove any leading zeros and add back any minus sign.
										if [[ -z "${user_gid}" || "${user_gid}" == '-' ]]; then user_gid='0'; fi # Catch if the number was all zeros with or without a minus sign.
									fi

									valid_options_for_package+=( "${this_option}" "${user_gid}" )

									shift # Only shift "$1" if it was a valid GID (all numbers), otherwise it might actually be the next valid option is someone made a mistake like "--gid --hint" or will show as an "invalid option" error.
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must be only numbers, except for a leading minus (-) for negative numbers."
									has_invalid_options=true
								fi
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
								has_invalid_options=true
							fi
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to use the default value."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" requires a parameter. When used in a group, it must be the last option specified and the only option with a parameter."
						has_invalid_options=true
					fi
					;;
				--login-shell|--user-shell|--shell|-s) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if $is_last_option_in_group; then
						if [[ -n "$1" ]]; then
							if [[ "$1" != '-'* ]]; then
								if [[ -z "${user_shell}" ]]; then
									user_shell="$1" # Will validate the specified path is an executable file and will be set to default of "/bin/zsh" or "/bin/bash" if not specified.
									valid_options_for_package+=( "${this_option}" "${user_shell}" )
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
									has_invalid_options=true
								fi

								shift
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it cannot start with a hyphen/minus (-) character."
								has_invalid_options=true
							fi
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to use the default value."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" requires a parameter. When used in a group, it must be the last option specified and the only option with a parameter."
						has_invalid_options=true
					fi
					;;
				--password|--pass|-p) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if $is_last_option_in_group; then
						if [[ -n "$1" ]]; then # Allow passwords to start with "-", which is a bit risky if someone does something wrong like "--password --hint" which will set the password to "--hint" and the parameter for "--hint" will become an invalid option and error.
							if [[ -z "${user_password}" ]]; then # Do not overwrite password if already set with "--no-password" or "--stdin-password" (or multiple "--password" options specified).
								if [[ "$1" != *$'\n'* ]]; then # Make sure there are no line breaks. System Preferences absurdly allows line breaks in password, but they cannot be entered in loginwindow and also cannot be entered on the command line.
									user_password="$1"
									# Do not include "--password" in valid_options_for_package because it will be modified to obfuscate the password within a package and then passed with "--stdin-password" after being deobfuscated.
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Password cannot contain line breaks."
									has_invalid_options=true
								fi
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
								has_invalid_options=true
							fi

							shift
						fi # Allow explicity blank/empty value since passwords can be blank/empty.
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" requires a parameter. When used in a group, it must be the last option specified and the only option with a parameter."
						has_invalid_options=true
					fi
					;;
				--stdin-password|--stdin-pass|--sp) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if [[ ! -t '0' ]]; then # Make sure stdin file descriptor is open so that the script doesn't hang forever if "--stdin-password" is used with no stdin via pipe, here-string, etc.
						if [[ -z "${user_password}" ]]; then # Do not overwrite password if already set with "--no-password" or "--password" (or multiple "--stdin-password" options specified).
							user_password="$(cat -)" # Optionally get password from stdin so that the password is never visible in the process list (will validate the password is either empty string or 4 characters or more).
							# Do not include "--stdin-password" in valid_options_for_package since it will always be added to package installations which include an obfuscated password (after the password has been deobfuscated).

							if [[ "$user_password" == *$'\n'* ]]; then # Make sure there are no line breaks. System Preferences absurdly allows line breaks in password, but they cannot be entered in loginwindow and also cannot be entered on the command line.
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Password cannot contain line breaks."
								has_invalid_options=true
							fi
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
							has_invalid_options=true
						fi

						do_not_confirm=true # Must set do_not_confirm to true if passing password via stdin since it disrupts being able to accept actual input.
						did_get_password_from_stdin=true # Need to also track if got password from stdin since it also disrupts "--secure-token-admin-password-prompt" which will be prevented when passing password via stdin.
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid option \"${this_unaltered_option}\" because no \"stdin\" detected."
						has_invalid_options=true
					fi

					# Allow explicity blank/empty value since passwords can be blank/empty.
					;;
				--password-prompt|--pass-prompt|--pp) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					prompt_for_user_password=true
					;;
				--no-password|--no-pass|--np) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					# This is just a convenience option to set user_password to "*".

					if [[ -z "${user_password}" ]]; then
						user_password='*'
						# Do not include "--no-password" in valid_options_for_package because it will be modified to obfuscate the "*" password within a package and then passed with "--stdin-password" after being deobfuscated.
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option because \"--password\" (or \"--stdin-password\") has already been specified."
						has_invalid_options=true
					fi
					;;
				--password-hint|--hint|--ph) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if [[ -n "$1" ]]; then # Allow hints to start with "-", which is a bit risky if someone does something wrong like "--hint --home" which will set the hint to "--home" and the parameter for "--home" will become an invalid option and error.
						if [[ -z "${user_password_hint}" ]]; then
							user_password_hint="$(echo -e "$1")" # Use "echo -e" to interpret any included backslash-escaped characters in the hint (such as "\n" or "\t") since they are allowed. No password hint will be set if not specified.
							valid_options_for_package+=( "${this_option}" "${user_password_hint}" )
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
							has_invalid_options=true
						fi

						shift
					fi # Allow explicity blank/empty value since hints can be blank/empty.
					;;
				--prohibit-user-password-changes) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					# This prohibits the user from modifying their own password without admin authentication.
					# The password can always be modified with admin authentication.

					if ! $set_prohibit_user_password_changes; then
						set_prohibit_user_password_changes=true
						valid_options_for_package+=( "${this_option}" )
					fi
					;;
				--home-folder|--home-path|--home|-H) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if $is_last_option_in_group; then
						if [[ -n "$1" ]]; then
							if [[ "$1" != '-'* ]]; then
								if [[ -z "${user_home_path}" ]]; then
									user_home_path="$1" # Will validate the home folder does not already exist and that it starts with a "/".
									valid_options_for_package+=( "${this_option}" "${user_home_path}" )
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
									has_invalid_options=true
								fi

								shift
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it cannot start with a hyphen/minus (-) character."
								has_invalid_options=true
							fi
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to use the default value."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" requires a parameter. When used in a group, it must be the last option specified and the only option with a parameter."
						has_invalid_options=true
					fi
					;;
				--do-not-share-public-folder|--dont-share-public) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if ! $do_not_share_public_folder; then
						do_not_share_public_folder=true
						valid_options_for_package+=( "${this_option}" )
					fi
					;;
				--do-not-create-home-folder|--dont-create-home) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if ! $do_not_create_home_folder; then
						do_not_create_home_folder=true
						valid_options_for_package+=( "${this_option}" )
					fi
					;;
				--picture|--photo|--pic|-P) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if $is_last_option_in_group; then
						if [[ -n "$1" ]]; then
							if [[ "$1" != '-'* ]]; then
								if ! $set_no_picture && [[ -z "${user_picture_path}" ]]; then
									user_picture_path="$1" # Will not be set if file does not exist, but will still create user without error (with a random picture).
									# Do not include "--picture" in valid_options_for_package because it will be modified to point to a copy of the picture file within a package.
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
									has_invalid_options=true
								fi

								shift
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it cannot start with a hyphen/minus (-) character."
								has_invalid_options=true
							fi
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option for a random user picture, or specify \"--no-picture\" for no picture."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" requires a parameter. When used in a group, it must be the last option specified and the only option with a parameter."
						has_invalid_options=true
					fi
					;;
				--no-picture|--no-photo|--no-pic) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if ! $set_no_picture; then
						if [[ -z "${user_picture_path}" ]]; then
							set_no_picture=true
							valid_options_for_package+=( "${this_option}" )
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option because \"--picture\" has already been specified."
							has_invalid_options=true
						fi
					fi
					;;
				--prohibit-user-picture-changes) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					# This prohibits the user from modifying their own picture without admin authentication.
					# The picture can always be modified with admin authentication.

					if ! $set_prohibit_user_picture_changes; then
						set_prohibit_user_picture_changes=true
						valid_options_for_package+=( "${this_option}" )
					fi
					;;
				--administrator|--admin|-a) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if ! $set_admin; then
						set_admin=true
						valid_options_for_package+=( "${this_option}" )
					fi
					;;
				--hidden|--hide) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					this_optional_hide_parameter=''

					if [[ -n "$1" && "$1" != '-'* ]]; then # "$1" starting with "-" should not be shifted or cause an "invalid parameter" error since this option can have a parameter or not and "$1" could just be the next valid option.
						this_optional_hide_parameter="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
					fi

					if [[ "${this_optional_hide_parameter}" == 'useronly' ]]; then
						set_hidden_user=true
						valid_options_for_package+=( "${this_option}" "${this_optional_hide_parameter}" )
					elif [[ "${this_optional_hide_parameter}" == 'homeonly' ]]; then
						set_hidden_home=true
						valid_options_for_package+=( "${this_option}" "${this_optional_hide_parameter}" )
					elif [[ -z "${this_optional_hide_parameter}" || "${this_optional_hide_parameter}" == 'both' ]]; then
						set_hidden_user=true
						set_hidden_home=true
						valid_options_for_package+=( "${this_option}" )
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must be one of \"userOnly\", \"homeOnly\", or \"both\" (or nothing)."
						has_invalid_options=true
					fi

					if [[ -n "${this_optional_hide_parameter}" ]]; then
						shift # Only shift off "$1" if is did not start with "-" after all checks in case we want to display the unaltered parameter in an error.
					fi
					;;
				--sharing-only-account|--sharing-account|--sharing-only|--sharing|--soa) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if ! $set_sharing_only_account; then
						if ! $set_role_account && ! $set_service_account; then
							set_sharing_only_account=true
							valid_options_for_package+=( "${this_option}" )
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid option \"${this_unaltered_option}\" while also specifying \"--role-account\" or \"--service-account\", must only specify one of these options."
							has_invalid_options=true
						fi
					fi
					;;
				--role-account|--role|-r) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if ! $set_role_account; then
						if ! $set_sharing_only_account && ! $set_service_account; then
							set_role_account=true
							valid_options_for_package+=( "${this_option}" )
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid option \"${this_unaltered_option}\" while also specifying \"--sharing-account\" or \"--service-account\", must only specify one of these options."
							has_invalid_options=true
						fi
					fi
					;;
				--service-account|--service|--sa) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if ! $set_service_account; then
						if ! $set_sharing_only_account && ! $set_role_account; then
							set_service_account=true
							valid_options_for_package+=( "${this_option}" )
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid option \"${this_unaltered_option}\" while also specifying \"--sharing-account\" or \"--role-account\", must only specify one of these options."
							has_invalid_options=true
						fi
					fi
					;;
				--prevent-secure-token-on-big-sur-and-newer|--prevent-secure-token|--no-st) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					# Must always set this option here even if not currently running on macOS 11 Big Sur and newer
					# since it could be used for a package which will run on macOS 11 Big Sur and newer.
					# The macOS version check will be done during validation before user creation starts.

					if ! $set_prevent_secure_token_on_big_sur_and_newer; then
						set_prevent_secure_token_on_big_sur_and_newer=true
						valid_options_for_package+=( "${this_option}" )
					fi
					;;
				--secure-token-admin-account-name|--st-admin-name|--st-admin-user|--st-name) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if [[ -n "$1" ]]; then
						if [[ "$1" != '-'* ]]; then # See comments below about not allowing account names starting with "-".
							if [[ -z "${st_admin_account_name}" ]]; then
								if [[ "$1" =~ ^[${a_z}${DIGITS}_][${a_z}${DIGITS}_.-]*$ ]]; then # The Secure Token admin will be verified to exist (and be an admin with a Secure Token) below, but at least validate that it's all lowercase letters, numbers, hyphen/minus, underscore, or period characters (and doesn't start with a period or hyphen/minus).
									st_admin_account_name="$1"
									valid_options_for_package+=( "${this_option}" "${st_admin_account_name}" )
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must only contain lowercase letters, numbers, hyphen/minus (-), underscore (_), or period (.) characters (and cannot start with a period)."
									has_invalid_options=true
								fi
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
								has_invalid_options=true
							fi

							shift
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it cannot start with a hyphen/minus (-) character."
							has_invalid_options=true

							# System Preferences and "sysadminctl -addUser" DO NOT allow account names to start with "-", but Setup Assistant DOES.
							# Regardless, they are not usable for our needs here since account names starting with "-" are totally unusable with "sysadminctl" (such as "sysadminctl -secureTokenOn") since it sees them as (invalid) options and there is no way (such as using "--") to make it recognize them as a username parameter that I could figure out.
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to NOT grant the new user a Secure Token."
						has_invalid_options=true
					fi
					;;
				--secure-token-admin-password|--st-admin-pass|--st-pass) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if [[ -n "$1" ]]; then # Allow passwords to start with "-", which is a bit risky if someone does something wrong like "--secure-token-admin-password --hint" which will set the password to "--hint" and the parameter for "--hint" will become an invalid option and error.
						if [[ -z "${st_admin_password}" ]]; then # Do not overwrite password if already set with "--fd3-secure-token-admin-password" (or multiple "--secure-token-admin-password" options specified).
							if [[ "$1" != *$'\n'* ]]; then # Make sure there are no line breaks. System Preferences absurdly allows line breaks in password, but they cannot be entered in loginwindow and also cannot be entered on the command line.
								st_admin_password="$1"
								# Do not include "--secure-token-admin-password" in valid_options_for_package because it will be modified to obfuscate the password within a package and then passed with "--fd3-secure-token-admin-password" after being deobfuscated.
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Secure Token admin password cannot contain line breaks."
								has_invalid_options=true
							fi
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
							has_invalid_options=true
						fi

						shift
					fi # Allow explicity blank/empty value since a Secure Token admins passwords can be blank/empty. The password will be verified before usage though.
					;;
				--fd3-secure-token-admin-password|--fd3-st-admin-pass|--fd3-st-pass) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if [[ -z "${st_admin_password}" ]]; then # Do not overwrite Secure Token admin password if already set with "--secure-token-admin-password" (or multiple "--fd3-secure-token-admin-password" options specified).
						if read -u 3 -r st_admin_password 2> /dev/null; then # Optionally get password from fd3 so that the password is never visible in the process list (will validate the password is 4 characters or more).
							# Do not include "--fd3-secure-token-admin-password" in valid_options_for_package since it will always be added to package installations which include an obfuscated password (after the password has been deobfuscated).

							if [[ "$st_admin_password" == *$'\n'* ]]; then # Make sure there are no line breaks. System Preferences absurdly allows line breaks in password, but they cannot be entered in loginwindow and also cannot be entered on the command line.
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Secure Token admin password cannot contain line breaks."
								has_invalid_options=true
							fi
						else # Show error if file descriptor 3 (fd3) was not specified (via 3<<< here-string).
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid option \"${this_unaltered_option}\" because no file descriptor 3 (fd3) detected, specify with \"3<<<\" here-string. If you are running this command manually in Terminal and using \"sudo\", \"fd3\" may be getting directed to \"sudo\" instead of \"mkuser\"."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
						has_invalid_options=true
					fi

					# Allow explicity blank/empty value since a Secure Token admins passwords can be blank/empty. The password will be verified before usage though.
					;;
				--secure-token-admin-password-prompt|--st-admin-pass-prompt|--st-pass-prompt) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					prompt_for_st_admin_password=true
					;;
				--automatic-login|--auto-login|-A) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if ! $set_auto_login; then
						set_auto_login=true
						valid_options_for_package+=( "${this_option}" )
					fi
					;;
				--prevent-login|--no-login|--nl) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					# This is just a convenience option to set user_shell to "/usr/bin/false".

					if [[ -z "${user_shell}" ]]; then
						user_shell='/usr/bin/false'
						valid_options_for_package+=( "${this_option}" )
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option because \"--login-shell\" has already been specified. \"--prevent-login\" just sets login shell to \"/usr/bin/false\" to prevent login."
						has_invalid_options=true
					fi
					;;
				--skip-setup-assistant|--skip-setup|-S) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					this_optional_skip_setup_assistant_parameter=''

					if $is_last_option_in_group && [[ -n "$1" && "$1" != '-'* ]]; then # "$1" starting with "-" should not be shifted or cause an "invalid parameter" error since this option can have a parameter or not and "$1" could just be the next valid option.
						# Allow "-S" to be included in a group of options, but only check for a parameter if it's at the end of the group.
						# Unlike other grouped options which REQUIRE a parameter, do not error if "-S" is not at the end of a group since its parameter is OPTIONAL.

						this_optional_skip_setup_assistant_parameter="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
					fi

					if [[ "${this_optional_skip_setup_assistant_parameter}" == 'firstbootonly' ]]; then
						skip_setup_assistant_on_first_boot=true
						valid_options_for_package+=( "${this_option}" "${this_optional_skip_setup_assistant_parameter}" )
					elif [[ "${this_optional_skip_setup_assistant_parameter}" == 'firstloginonly' ]]; then
						skip_setup_assistant_on_first_login=true
						valid_options_for_package+=( "${this_option}" "${this_optional_skip_setup_assistant_parameter}" )
					elif [[ -z "${this_optional_skip_setup_assistant_parameter}" || "${this_optional_skip_setup_assistant_parameter}" == 'both' ]]; then
						skip_setup_assistant_on_first_boot=true
						skip_setup_assistant_on_first_login=true
						valid_options_for_package+=( "${this_option}" )
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must be one of \"firstBootOnly\", \"firstLoginOnly\", or \"both\" (or nothing)."
						has_invalid_options=true
					fi

					if [[ -n "${this_optional_skip_setup_assistant_parameter}" ]]; then
						shift # Only shift off "$1" if is did not start with "-" after all checks in case we want to display the unaltered parameter in an error.
					fi
					;;
				# <MKUSER-BEGIN-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!
				--package-path|--pkg-path|--package|--pkg) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					make_package=true

					if [[ -n "$1" && "$1" != '-'* ]]; then # "$1" starting with "-" should not be shifted or cause an invalid error since this option can have a parameter or not and "$1" could just be the next option.
						if [[ -z "${pkg_path}" ]]; then
							pkg_path="$1" # If a package path is not specified, it will be saved to the current working directory.
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
							has_invalid_options=true
						fi

						shift
					fi
					;;
				--package-identifier|--pkg-identifier|--package-id|--pkg-id) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if [[ -n "$1" ]]; then
						if [[ "$1" != '-'* ]]; then
							if [[ -z "${pkg_identifier}" ]]; then
								if [[ "$1" =~ ^[${A_Z}${a_z}${DIGITS}][${A_Z}${a_z}${DIGITS}_.-]*$ ]]; then # Identifier should starts with a letter or number and only contain alphanumeric, hyphen/minus, underscore, and dot.
									# The identifier must be validated since it could also be used in the filename, and don't want to allow or have to deal with invalid filesystem characters.
									pkg_identifier="$1" # Will be set to "mkuser.pkg.<ACCOUNT NAME>" if not specified.
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must start with a letter or number and can only contain alphanumeric, hyphen/minus (-), underscore (_), or dot (.) characters."
									has_invalid_options=true
								fi
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
								has_invalid_options=true
							fi

							shift
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it cannot start with a hyphen/minus (-) character."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to use the default value."
						has_invalid_options=true
					fi
					;;
				--package-version|--pkg-version|--pkg-v) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if [[ -n "$1" ]]; then
						if [[ "$1" != '-'* ]]; then
							if [[ -z "${pkg_version}" ]]; then
								if [[ "$1" =~ ^[${A_Z}${a_z}${DIGITS}][${A_Z}${a_z}${DIGITS}.-]*$ ]]; then # Version should generally only be numbers and dots, but also allow hyphens/minuses and letters as long as it start with a number or letter so folks can do things like "1.0-test1" if they want.
									# The version must also be validated since it could also be used in the filename, and don't want to allow or have to deal with invalid filesystem characters.
									pkg_version="$1" # Date seperated by periods will be used if not specified.
								else
									>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must start with a number or letter and can only contain alphanumeric, hyphen/minus (-), or dot (.) characters."
									has_invalid_options=true
								fi
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
								has_invalid_options=true
							fi

							shift
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it cannot start with a hyphen/minus (-) character."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to use the default value."
						has_invalid_options=true
					fi
					;;
				--package-signing-identity|--package-sign|--pkg-sign) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					if [[ -n "$1" ]]; then
						if [[ "$1" != '-'* ]]; then
							if [[ -z "${pkg_sign}" ]]; then
								pkg_sign="$1"
							else
								>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"${this_unaltered_option}\" option."
								has_invalid_options=true
							fi

							shift
						else
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid parameter \"$1\" for option \"${this_unaltered_option}\", it cannot start with a hyphen/minus (-) character."
							has_invalid_options=true
						fi
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The option \"${this_unaltered_option}\" cannot have a blank/empty parameter. Omit this option to not sign the package."
						has_invalid_options=true
					fi
					;;
				# <MKUSER-END-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!
				--do-not-confirm|--no-confirm|--force|-F) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					do_not_confirm=true
					;;
				--suppress-status-messages|--quiet|-q) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					do_not_confirm=true
					suppress_status_messages=true
					;;
				--check-only|--dry-run|--check|-c) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					check_only=true
					;;
				# <MKUSER-BEGIN-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!
				--version|-v) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					show_version=true

					this_optional_version_parameter=''

					if $is_last_option_in_group && [[ -n "$1" && "$1" != '-'* ]]; then # "$1" starting with "-" should not be shifted or cause an "invalid parameter" error since this option can have a parameter or not and "$1" could just be the next valid option.
						# Allow "-v" to be included in a group of options, but only check for a parameter if it's at the end of the group.
						# Unlike other grouped options which REQUIRE a parameter, do not error if "-v" is not at the end of a group since its parameter is OPTIONAL.

						this_optional_version_parameter="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
					fi

					if [[ "${this_optional_version_parameter}" == 'online' || "${this_optional_version_parameter}" == 'o' ]]; then
						show_releases_online=true
					elif [[ -n "${this_optional_version_parameter}" ]]; then
						>&2 echo "mkuser WARNING: IGNORING invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must be \"online\" (or \"o\") or nothing."
						# Just ignore invalid parameters (not do an invalid option error) since a user would never be created when this option is specified anyway.
					fi

					if [[ -n "${this_optional_version_parameter}" ]]; then
						shift # Only shift off "$1" if is did not start with "-" after all checks in case we want to display the unaltered parameter in an error.
					fi
					;;
				--help|-h) # <MKUSER-VALID-OPTIONS> !!! DO NOT REMOVE THIS COMMENT, IT EXISTING ON THE SAME LINE AFTER EACH OPTIONS CASE STATEMENT IS CRITICAL FOR OPTION PARSING !!!
					show_help=true

					this_optional_help_parameter=''

					if $is_last_option_in_group && [[ -n "$1" && "$1" != '-'* ]]; then # "$1" starting with "-" should not be shifted or cause an "invalid parameter" error since this option can have a parameter or not and "$1" could just be the next valid option.
						# Allow "-h" to be included in a group of options, but only check for a parameter if it's at the end of the group.
						# Unlike other grouped options which REQUIRE a parameter, do not error if "-h" is not at the end of a group since its parameter is OPTIONAL.

						this_optional_help_parameter="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
					fi

					if [[ "${this_optional_help_parameter}" == 'brief' || "${this_optional_help_parameter}" == 'b' ]]; then
						show_brief_help=true
					elif [[ "${this_optional_help_parameter}" == 'online' || "${this_optional_help_parameter}" == 'o' ]]; then
						show_help_online=true
					elif [[ -n "${this_optional_help_parameter}" ]]; then
						>&2 echo "mkuser WARNING: IGNORING invalid parameter \"$1\" for option \"${this_unaltered_option}\", it must be \"brief\" (or \"b\"), \"online\" (or \"o\"), or nothing."
						# Just ignore invalid parameters (not do an invalid option error) since a user would never be created when this option is specified anyway.
					fi

					if [[ -n "${this_optional_help_parameter}" ]]; then
						shift # Only shift off "$1" if is did not start with "-" after all checks in case we want to display the unaltered parameter in an error.
					fi
					;;
				# <MKUSER-END-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!
				*)
					if [[ -n "${this_unaltered_option}" ]]; then
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid option \"${this_unaltered_option}\"."
						has_invalid_options=true
					fi
					;;
			esac
		done
	done

	if $check_only && ! $suppress_status_messages && ! $make_package; then
		echo "mkuser NOTICE: User WILL NOT be created since \"--check-only\" was specified."
	elif $has_invalid_options; then
		>&2 echo "mkuser WARNING: $($make_package && echo 'Package' || echo 'User') WILL NOT be created since INVALID OPTIONS OR PARAMETERS were specified, but still running checks to detect more possible errors."
	fi
	(( error_code ++ ))

	# <MKUSER-BEGIN-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!
	local open_command_asuser_or_not=( 'open' ) # While "open" always opens the app as the currently logged in user, I have found it to not always launch apps reliably if run as root (also: https://scriptingosx.com/2020/08/running-a-command-as-another-user/)
	if (( ${EUID:-$(id -u)} == 0 )); then # Must only run as user with "sudo -u" if running as root since that would fail if already running as a standard user (which cannot run "sudo" commands).
		current_user_id="$(scutil <<< 'show State:/Users/ConsoleUser' | awk '($1 == "UID") { print $NF; exit }')"
		if (( current_user_id != 0 )); then
			current_user_name="$(dscl /Search -search /Users UniqueID "${current_user_id}" 2> /dev/null | awk '{ print $1; exit }')"

			open_command_asuser_or_not=( 'launchctl' 'asuser' "${current_user_id}" 'sudo' '-u' "${current_user_name}" 'open' )
		fi
	fi

	if $show_version; then
		echo -en "mkuser: Version ${MKUSER_VERSION}\nCopyright (c) $(date '+%Y') Free Geek\nhttps://mkuser.sh\n\nUpdate Check: "

		if [[ "${MKUSER_VERSION}" != *'-0' ]]; then
			latest_version_json="$(curl -m 5 -sL 'https://api.github.com/repos/freegeek-pdx/mkuser/releases/latest' 2> /dev/null)"
			if [[ "${latest_version_json}" == *'"tag_name"'* ]]; then
				latest_version="$(OSASCRIPT_ENV_JSON="${latest_version_json}" osascript -l 'JavaScript' -e 'JSON.parse($.NSProcessInfo.processInfo.environment.objectForKey("OSASCRIPT_ENV_JSON").js).tag_name' 2> /dev/null)"
				# Parsing JSON with JXA: https://paulgalow.com/how-to-work-with-json-api-data-in-macos-shell-scripts

				fallback_version_note=''
				if ! [[ "${latest_version}" =~ ^[${DIGITS}][${DIGITS}.-]*$ ]]; then
					# Make sure the new version string is valid. If JSON.parse() failed somehow, just try to get the newest version string using "awk" instead.
					latest_version="$(echo "${latest_version_json}" | awk -F '"' '($2 == "tag_name") { print $4; exit }')"
					fallback_version_note=' (USED FALLBACK TECHNIQUE TO RETRIEVE VERSION, PLEASE REPORT THIS ISSUE)'
				fi

				if [[ "${latest_version}" == "${MKUSER_VERSION}" ]]; then
					echo "Up-to-Date${fallback_version_note}"
				elif [[ "${latest_version}" =~ ^[${DIGITS}][${DIGITS}.-]*$ ]]; then
					echo "Version ${latest_version} is Now Available!${fallback_version_note}"

					if ! $show_releases_online; then echo 'Run "mkuser -v online" to open the mkuser Releases page on GitHub to download the latest version (or visit "https://download.mkuser.sh").'; fi
				else
					echo 'Failed to Retrieve Latest Version (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)'
				fi
			else
				echo 'Failed to Check for Updates (Internet Required)'
			fi
		else
			echo 'Not Checking for Updates for Testing Version'
		fi

		if $show_releases_online; then
			echo -e '\nOpening mkuser Releases page on GitHub...'

			"${open_command_asuser_or_not[@]}" 'https://download.mkuser.sh'
		fi

		return 0
	elif $show_help_online; then
		echo 'Opening README section of the mkuser GitHub page (which contains all help info)...'

		"${open_command_asuser_or_not[@]}" 'https://help.mkuser.sh'

		return 0
	elif $show_help; then
		# Show help before checking if running as root or macOS version so that help can always be displayed.

		clear_ansi='\033[0m' # Clears all ANSI colors and styles.
		ansi_bold='\033[1m'
		ansi_underline='\033[4m'

		# All of the following lines to wrapped specifically to fit in an 80 column Terminal window (the default width).
		help_information="
${ansi_bold}mkuser${clear_ansi} ${ansi_underline}version ${MKUSER_VERSION}${clear_ansi}
Copyright (c) $(date '+%Y') Free Geek
${ansi_underline}https://mkuser.sh${clear_ansi}


\xf0\x9f\x93\x9d ${ansi_bold}DESCRIPTION:${clear_ansi}

  ${ansi_bold}mkuser${clear_ansi} ${ansi_underline}m${clear_ansi}a${ansi_underline}k${clear_ansi}es ${ansi_underline}user${clear_ansi} accounts for macOS with more options, more validation
    of inputs, and more verification of the created user account than any other
    user creation tool, including ${ansi_bold}sysadminctl -addUser${clear_ansi} and System Preferences!


\xe2\x84\xb9\xef\xb8\x8f  ${ansi_bold}USAGE NOTES:${clear_ansi}

  For long form options (multicharacter options starting with two hyphens),
    case doesn't matter.
  For example, ${ansi_bold}--help${clear_ansi}, ${ansi_bold}--HELP${clear_ansi}, and ${ansi_bold}--Help${clear_ansi} are all equal.

  For short form options (single character options starting with one hyphen),
    case DOES matter.
  For example, ${ansi_bold}-h${clear_ansi} and ${ansi_bold}-H${clear_ansi} are NOT equal.

  Short form options can be grouped together or passed individually.
  But, only a single option within a group can take a parameter
    and it must be the last option specified within the group.
  For example, ${ansi_bold}-qaA${ansi_underline}n${clear_ansi}${ansi_bold} <ACCOUNT NAME>${clear_ansi} is valid but ${ansi_bold}-qa${ansi_underline}n${clear_ansi}${ansi_bold}A <ACCOUNT NAME>${clear_ansi} is not.
  Also, ${ansi_bold}-qa${ansi_underline}n${clear_ansi}${ansi_bold} <ACCOUNT NAME> -A${ansi_underline}f${clear_ansi}${ansi_bold} <FULL NAME>${clear_ansi} is valid
    but ${ansi_bold}-qaA${ansi_underline}nf${clear_ansi}${ansi_bold} <ACCOUNT NAME> <FULL NAME>${clear_ansi} is not.
  An error will be displayed if options with parameters are grouped incorrectly.

  Long form options can have their word separating hyphens omitted.
  For example, ${ansi_bold}--user-id${clear_ansi}, ${ansi_bold}--userid${clear_ansi}, and ${ansi_bold}--userID${clear_ansi} are all equal
    (since the case also doesn't matter).
  This does NOT mean word separating hyphen placement doesn't matter,
    all of the word separating hyphens must be correct, or all omitted.

  Options and their parameters can be separated by whitespace, equals (=),
    and can also be combined without using whitespace or equals (=).
  For example, ${ansi_bold}--uid <UID>${clear_ansi}, ${ansi_bold}--uid=<UID>${clear_ansi}, ${ansi_bold}--uid<UID>${clear_ansi},
    ${ansi_bold}-u <UID>${clear_ansi}, ${ansi_bold}-u=<UID>${clear_ansi}, and ${ansi_bold}-u<UID>${clear_ansi} are all valid.
  When combining single character options with their parameter, be careful to
    not set a parameter whose first letter is also a valid single character
    option as this would be interpreted as combined single character options.
  For example, ${ansi_bold}-${ansi_underline}n${clear_ansi}${ansi_bold}user${clear_ansi} would get interpreted as ${ansi_bold}-n -u=ser${clear_ansi} (which would error for
    multiple reasons) instead of ${ansi_bold}-n=user${clear_ansi} since ${ansi_bold}-u${clear_ansi} is also a valid option.
  In these cases, the options and parameters should be seperated instead.
  But, something like ${ansi_bold}-u401${clear_ansi} will always be safe since ${ansi_bold}-4${clear_ansi} is not a valid option.

  If ANY options or parameters are invalid, user or package WILL NOT be created.
  Instead, the invalid option errors and errors from other checks will be shown.

  When creating a user on the current system (not using the ${ansi_bold}--package${clear_ansi} option),
    you will be prompted for confirmation before the user is created.
  To NOT be prompted for confirmation (such as when run within a script),
    you must specify ${ansi_bold}--do-not-confirm${clear_ansi} (${ansi_bold}-F${clear_ansi})
    or ${ansi_bold}--suppress-status-messages${clear_ansi} (${ansi_bold}-q${clear_ansi}) or ${ansi_bold}--stdin-password${clear_ansi}.


\xf0\x9f\x91\xa4 ${ansi_bold}PRIMARY OPTIONS:${clear_ansi}

  ${ansi_bold}--account-name, --record-name, --short-name, --username, --user, --name, -n${clear_ansi}
    < ${ansi_underline}string${clear_ansi} >

    Must only contain lowercase letters, numbers, hyphen/minus (-),
      underscore (_), or period (.) characters.
    The account name cannot start with a period (.) or hyphen/minus (-).
    Must be 244 characters/bytes or less and must contain at least one letter.
    The account name must not already be assigned to another user.
    If omitted, the full name will be converted into a valid account name
      by coverting it to meet the requirements stated above.

    ${ansi_bold}244 CHARACTER/BYTE ACCOUNT NAME LENGTH LIMIT NOTES:${clear_ansi}
    The account name is used as the OpenDirectory RecordName, which has a hard
      244 byte length limit (and the allowed characters are always 1 byte each).
    Attempting to create a user with an account name over 244 characters will
      fail regardless of if you try to use ${ansi_bold}sysadminctl${clear_ansi}, ${ansi_bold}dscl${clear_ansi}, or ${ansi_bold}dsimport${clear_ansi}.

    ${ansi_bold}ACCOUNT NAMES STARTING WITH PERIOD (.) NOTES:${clear_ansi}
    System Preferences actually allows account names to start with a period (.),
      but that causes the account name to not show up in ${ansi_bold}dscacheutil -q user${clear_ansi}
      or ${ansi_bold}dscl . -list /Users${clear_ansi} even though the user does actually exist.
    Also, since users with account names starting with a period (.) are NOT
      properly detected by macOS, their existence can break next available UID
      assignment by ${ansi_bold}sysadminctl -addUser${clear_ansi} and System Preferences and both could
      keep incorrectly assigning the UID of the account name starting with
      a period (.) which fails and results in users created with no UID.
    Since allowing account names starting with a period (.) would cause those
      issues and ${ansi_bold}mkuser${clear_ansi} would not be able to verify that the user was properly
      created, starting with a period (.) is not allowed by ${ansi_bold}mkuser${clear_ansi}.


  ${ansi_bold}--full-name, --real-name, -f${clear_ansi}  < ${ansi_underline}string${clear_ansi} >

    There are no limitations on the characters allowed in the full name,
      except that it cannot be only whitespace or have line breaks.
    See notes below about the non-specific length limit of the full name.
    The full name must not already be assigned to another user.
    If omitted, the account name will be used as the full name.

    ${ansi_bold}FULL NAME LENGTH LIMIT NOTES:${clear_ansi}
    While there is no explicit length limit, there is a combined byte length
      limit of the account name, full name, login shell, and home folder path.
    If the combined byte length of these 4 attributes is over ${ansi_underline}1010 bytes${clear_ansi}, the
      full name will not load in the \"Log Out\" menu item of the \"Apple\" menu.
    While this is not a serious issue, it does indicate a bug or limitation
      within some part of macOS that we do not want to trigger.
    ${ansi_bold}mkuser${clear_ansi} will do this math for you and show an error with all of the
      byte lengths as well as how many bytes need to be removed for these
      4 attributes to fit within the combined 1010 byte length limitation.
    This 1010 byte length limit should not be hit under normal circumstances,
      so you will generally not need to worry about hitting this limit.
    For a bit more technical information about this issue from my testing,
      search for ${ansi_underline}1010 bytes${clear_ansi} within the source of this script.

    Even though ${ansi_bold}mkuser${clear_ansi} will not allow it, if the byte length of these
      4 combined attributes was over 1010 bytes, the account still logs in
      and seems to work properly other than not loading the full name
      in the \"Log Out\" menu item of the \"Apple\" menu.
    But, if this combined byte length is over 2034 bytes, the account cannot
      login via login window as well as when using the ${ansi_bold}login${clear_ansi} or ${ansi_bold}su${clear_ansi} commands.
    For a bit more technical information about this issue from my testing,
      search for ${ansi_underline}2034 bytes${clear_ansi} within the source of this script.


  ${ansi_bold}--unique-id, --user-id, --uid, -u${clear_ansi}  < ${ansi_underline}integer${clear_ansi} >

    Must be an integer between -2147483648 and 2147483647 (signed 32-bit range).
    The User ID (UniqueID) must not already be assigned to another user.
    If omitted, the next User ID available from ${ansi_underline}501${clear_ansi} will be used, unless
      creating a ${ansi_bold}--role-account${clear_ansi} or ${ansi_bold}--service-account${clear_ansi}, then starting from ${ansi_underline}200${clear_ansi}.
    If you're the kind of person that has noticed that UIDs may be represented
      outside of this range, you may be interested in reading the
      ${ansi_underline}UIDs CAN BE REPRESENTED IN DIFFERENT FORMS${clear_ansi} comments in this script.

    ${ansi_bold}NEGATIVE USER ID NOTES:${clear_ansi}
    Negative User IDs should not be created under normal circumstances.
    Negative User IDs are normally reserved for special system users and
      users with negative User IDs may not behave properly or as expected.


  ${ansi_bold}--generated-uid, --guid, --uuid, -G${clear_ansi}  < ${ansi_underline}string${clear_ansi} >

    Must be 36 characters of only capital letters, numbers,
      and hyphens/minuses (-) in the following format:
      ${ansi_underline}EIGHT888-4444-FOUR-4444-TWELVE121212${clear_ansi}
    The Generated UID (GUID) must not already be assigned to another user.
    If omitted, a random Generated UID will be assigned by macOS.
    You should not normally need to manually specify a Generated UID.


  ${ansi_bold}--primary-group-id, --group-id, --group, --gid, -g${clear_ansi}  < ${ansi_underline}integer${clear_ansi} >

    Must be an integer between -2147483648 and 2147483647 (signed 32-bit range).
    The Group ID must already exist, non-existent Group IDs will not be created.
    If omitted, the default Primary Group ID of ${ansi_underline}20${clear_ansi} (staff) will be used,
      unless creating a ${ansi_bold}--service-account${clear_ansi}, then ${ansi_underline}-2${clear_ansi} (nobody) will be used.
    If you're the kind of person that has noticed that GIDs may be represented
      outside of this range, you may be interested in reading the
      ${ansi_underline}UIDs CAN BE REPRESENTED IN DIFFERENT FORMS${clear_ansi} comments in this script.


  ${ansi_bold}--login-shell, --user-shell, --shell, -s${clear_ansi}  < ${ansi_underline}existing path${clear_ansi} || ${ansi_underline}command name${clear_ansi} >

    The login shell must be the path to an existing executable file, or a valid
      command name that can be resolved using ${ansi_bold}which${clear_ansi} (searching within
      \"/usr/bin\", \"/bin\", \"/usr/sbin\", \"/sbin\", and \"/usr/libexec\").
    You must specify the path if the desired login shell is in another location.
    If omitted, \"/bin/zsh\" will be used on macOS 10.15 Catalina and newer
      and \"/bin/bash\" will be used on macOS 10.14 Mojave and older.


\xf0\x9f\x94\x90 ${ansi_bold}PASSWORD OPTIONS:${clear_ansi}

  ${ansi_bold}--password, --pass, -p${clear_ansi}  < ${ansi_underline}string${clear_ansi} >

    The password must be at least 4 characters and 511 bytes or less.
    Except, when enabling auto-login, the maximum limit is 251 bytes.
    Also, blank/empty passwords are allowed when FileVault IS NOT enabled.
    There are no limitations on the characters allowed in the password,
      except that it cannot contain line breaks.
    If omitted, blank/empty password will be specified.

    ${ansi_bold}BLANK/EMPTY PASSWORD NOTES:${clear_ansi}
    Blank/empty passwords are not allowed by macOS when FileVault is enabled.
    When FileVault is not enabled, a user with a blank/empty password
      WILL be able to log in and authenticate GUI prompts, but WILL NOT be able
      to authenticate \"Terminal\" commands like ${ansi_bold}sudo${clear_ansi}, ${ansi_bold}su${clear_ansi}, or ${ansi_bold}login${clear_ansi}, for example.

    ${ansi_bold}AUTO-LOGIN 251 BYTE PASSWORD LENGTH LIMIT NOTES:${clear_ansi}
    Auto-login simply does not work with passwords longer than 251 bytes.
    I am not sure if this is a bug or an intentional limitation, but if you
      set a password of 252 bytes or more and enable auto-login, macOS will
      boot to the login window instead of automatically logged into the user.
    I am not sure what exactly is failing internally, but the behavior is
      as if the encoded auto-login password is incorrect.
    I have confirmed this IS NOT an issue with the auto-login password
      encoding within ${ansi_bold}mkuser${clear_ansi} since the same thing happens when enabling
      auto-login in the \"Users & Groups\" pane of the \"System Preferences\".

    ${ansi_bold}511 BYTE PASSWORD LENGTH LIMIT NOTES:${clear_ansi}
    Most of macOS can technically support passwords longer than 511 bytes,
      but both the ${ansi_bold}login${clear_ansi} and ${ansi_bold}su${clear_ansi} commands fail with passwords over 511 bytes.
    Since 512 byte or longer passwords cannot work in all possible situations,
      they are not allowed since ${ansi_bold}mkuser${clear_ansi} exists to make fully functional users.
    If not being able to use the ${ansi_bold}login${clear_ansi} and ${ansi_bold}su${clear_ansi} commands is not an issue,
      and you want to use a longer password, you can just set a temporary
      password when creating a user with ${ansi_bold}mkuser${clear_ansi} and then change the password
      to something 512 bytes or longer manually using ${ansi_bold}dscl . -passwd${clear_ansi}.
    If you manually set a password 512 bytes or longer, you will be able to
      login via login window as well as authenticate graphical prompts,
      such as unlocking \"System Preferences\" panes if the user in an admin.
    For fun, I tested logging in via login window with passwords up to
      10,000 bytes (typed via an Arduino) and unlocking \"System Preferences\"
      panes with passwords up to 150,000 bytes (copy-and-pasted).
    Longer passwords took overly long for the Arduino to type or macOS to paste.

    ${ansi_bold}PASSWORDS IN PACKAGE NOTES:${clear_ansi}
    When outputting a user creation package (with the ${ansi_bold}--package${clear_ansi} option), the
      specified password (along with the existing Secure Token admin password,
      if specified) will be securely obfuscated within the package in such a way
      that the passwords can only be deobfuscated by the specific and unique
      script generated during package creation and only when run during
      the package installation process.
    For more information about how passwords are securely obfuscated within
      the package, read the comments within the code of this script starting at:
      ${ansi_underline}OBFUSCATE PASSWORDS INTO RUN-ONLY APPLESCRIPT${clear_ansi}
    Also, when the passwords are deobfuscated during package installation,
      they will NOT be visible in the process list because they will be passed
      via \"stdin\" using ${ansi_bold}--stdin-password${clear_ansi} (and ${ansi_bold}--fd3-secure-token-admin-password${clear_ansi})
      regardless of how the passwords were specified when creating the package.


  ${ansi_bold}--stdin-password, --stdin-pass, --sp${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} (stdin) >

    Include this option with no parameter to pass the password via \"stdin\"
      using a pipe (${ansi_bold}|${clear_ansi}) or here-string (${ansi_bold}<<<${clear_ansi}), etc.
    Passing the password via \"stdin\" instead of directly with the ${ansi_bold}--password${clear_ansi}
      option hides the password from the process list.
    The help information for the ${ansi_bold}--password${clear_ansi} option above also applies to
      passwords passed via \"stdin\".
    ${ansi_bold}NOTICE:${clear_ansi} Specifying ${ansi_bold}--stdin-password${clear_ansi} also ENABLES ${ansi_bold}--do-not-confirm${clear_ansi} since
      accepting \"stdin\" disrupts the ability to use other command line inputs.


  ${ansi_bold}--password-prompt, --pass-prompt, --pp${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to be prompted for the new user
      password on the command line before creating the user or package.
    This option allows you to specify a password without it being saved in your
      command line history as well as hides the password from the process list.
    The help information for the ${ansi_bold}--password${clear_ansi} option above also applies to
      passwords entered via command line prompt.


  ${ansi_bold}--no-password, --no-pass, --np${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to set no password at all instead of a
      blank/empty password (like when the ${ansi_bold}--password${clear_ansi} option is omitted).
    This option is equivalent to setting the password to \"*\" with ${ansi_bold}--password '*'${clear_ansi}
      and is here as a seperate option for convenience and information.
    Setting the password to \"*\" is a special character that indicates
      to macOS that this user does not have any meaningful password set.
    When a user has the \"*\" password set, it cannot login by any means and
      it will also not get any AuthenticationAuthority set in the user record.
    When the \"*\" password is set AND no AuthenticationAuthority exists,
      the user will not show in the users list in \"Users & Groups\" pane
      of the \"System Preferences\" and will also not show up in the login window.
    If you choose to start a user out with no password for some reason,
      you can always set their password later with ${ansi_bold}dscl . -passwd${clear_ansi}.

    If you include the ${ansi_bold}--prevent-secure-token-on-big-sur-and-newer${clear_ansi} option
      with this option, that would create an AuthenticationAuthority attribute
      with the special tag to prevent a Secure Token from being granted.
    Since that user would no longer have BOTH no AuthenticationAuthority AND
      the \"*\" password, they would show in the users list in \"Users & Groups\"
      pane of the \"System Preferences\" as well as the login window list
      of users, but could not log in since no meaningful password is set.


  ${ansi_bold}--password-hint, --hint, --ph${clear_ansi}  < ${ansi_underline}string${clear_ansi} >

    Must be 280 characters or less, but there are no limitations
      on the characters allowed in the password hint.
    Line breaks and tabs can also be included.
    If omitted, no password hint will be set.

    ${ansi_bold}280 CHARACTER PASSWORD HINT LENGTH LIMIT NOTES:${clear_ansi}
    The password hint popover in the non-FileVault login window will only
      display up to 7 lines at about 40 characters per line.
    This results in 280 characters being a reasonable maximum length.
    Since each character is a different width, 40 characters per line is just
      an estimation and less or more may fit depending on the characters,
      for example, only 14 smiley face emoji fit on a single line.
    If line breaks are included, they are rendered in the password hint popover
      and that can make less characters show since only up to 7 lines will show.
    If for some reason you need or want a longer password hint, you can just
      set a temporary password hint when creating a user with ${ansi_bold}mkuser${clear_ansi} and then
      change the password hint to something longer manually with:
      ${ansi_bold}dscl . -create /Users/<ACCOUNT NAME> AuthenticationHint '<PASSWORD HINT>'${clear_ansi}


  ${ansi_bold}--prohibit-user-password-changes${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to prohibit the user from being able
      to change their own password without administrator authentication.
    The password can still be changed in the \"Users & Groups\" pane of the
      \"System Preferences\" when unlocked and authenticated by an administrator.


\xf0\x9f\x93\x81 ${ansi_bold}HOME FOLDER OPTIONS:${clear_ansi}

  ${ansi_bold}--home-folder, --home-path, --home, -H${clear_ansi}  < ${ansi_underline}non-existing path${clear_ansi} >

    The home folder path must not currently exist,
      unless specifying the special \"/var/empty\" or \"/dev/null\" paths.
    The total length of the home folder path must be 511 bytes or less,
      or home folder creation will fail during login or ${ansi_bold}createhomedir${clear_ansi}.
    Each folder within the home folder path must be 255 bytes or less each,
      as that is the max folder/file name length set by macOS.
    If the home folder is not within the \"/Users/\" folder,
      the users Public folder will not be shared.
    If omitted, the home folder will be set to \"/Users/<ACCOUNT NAME>\".


  ${ansi_bold}--do-not-share-public-folder, --dont-share-public${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to NOT share the users Public folder.
    The users Public folder will be shared by default unless the users
      home folder is hidden or is not within the \"/Users/\" folder.
    The users Public folder can still be shared manually in the \"File Sharing\"
      section of the \"Sharing\" pane of the \"System Preferences\".


  ${ansi_bold}--do-not-create-home-folder, --dont-create-home${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to NOT create the users home folder.
    The users home folder will be created by macOS when the user is logged in
      graphically via login window, but will not be created when logging in
      via \"Terminal\" using the ${ansi_bold}login${clear_ansi} or ${ansi_bold}su${clear_ansi} commands, for example.
    To create the home folder at anytime via \"Terminal\" or script, you can
      use the ${ansi_bold}createhomedir -cu <ACCOUNT NAME>${clear_ansi} command.
    When using this option, you CANNOT also specify ${ansi_bold}--hide homeOnly${clear_ansi} or
      ${ansi_bold}--skip-setup-assistant firstLoginOnly${clear_ansi} since they require the home folder.


\xf0\x9f\x96\xbc  ${ansi_bold}PICTURE OPTIONS:${clear_ansi}

  ${ansi_bold}--picture, --photo, --pic, -P${clear_ansi}  < ${ansi_underline}existing path${clear_ansi} || ${ansi_underline}default picture filename${clear_ansi} >

    Must be a path to an existing image file that is 1 MB or under,
      or be the filename of one of the default user pictures located within
      the \"/Library/User Pictures/\" folder (with or without the file extension,
      such as \"Earth\" or \"Penguin.tif\").
    When outputting a user creation package (with the ${ansi_bold}--package${clear_ansi} option),
      the specified picture file will be included in the user creation package.
    If omitted, a random default user picture will be assigned.


  ${ansi_bold}--no-picture, --no-photo, --no-pic${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to not set any picture instead of
      a random default user picture (like when the ${ansi_bold}--picture${clear_ansi} option is omitted).
    When no picture is set, a grey head and shoulders silhouette icon is used.


  ${ansi_bold}--prohibit-user-picture-changes${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to prohibit the user from being able
      to change their own picture without administrator authentication.
    The picture can still be changed in the \"Users & Groups\" pane of the
      \"System Preferences\" when unlocked and authenticated by an administrator.


\xf0\x9f\x8e\x9b  ${ansi_bold}ACCOUNT TYPE OPTIONS:${clear_ansi}

  ${ansi_bold}--administrator, --admin, -a${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to make the user an administrator.
    Administrators can manage other users, install apps, and change settings.

    If omitted, a standard user will be created.
    Standard users can install apps and change their own settings,
      but can't add other users or change other users' settings.

    For more information about administrator and standard account types, visit:
      ${ansi_underline}https://support.apple.com/guide/mac-help/mtusr001${clear_ansi}


  ${ansi_bold}--hidden, --hide${clear_ansi}  < ${ansi_underline}userOnly${clear_ansi} || ${ansi_underline}homeOnly${clear_ansi} || ${ansi_underline}both${clear_ansi} (or ${ansi_underline}no parameter${clear_ansi}) >

    Include this option with either no parameter or specify \"${ansi_underline}both${clear_ansi}\"
      to hide both the user and their home folder.

    Specify \"${ansi_underline}userOnly${clear_ansi}\" to hide only the user and keep the home folder visible.
    Hidden users will not show in the users list in \"Users & Groups\" pane
      of the \"System Preferences\" unless they are currently logged in,
    and will also not show up in the login window list of users
      (unless they have a Secure Token and FileVault is enabled).
    A hidden user can still be logged into by using text input fields
      in the non-FileVault login window.

    Specify \"${ansi_underline}homeOnly${clear_ansi}\" to hide only the home folder and keep the user visible.
    If the home folder is hidden, the users Public folder will not be shared.

    Any other parameters are invalid and will cause the user to not be created.


  ${ansi_bold}--sharing-only-account, --sharing-account, --sharing-only, --sharing, --soa${clear_ansi}
    < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to create a \"Sharing Only\" account.

    This is identical to a \"Sharing Only\" account that can be created in
      the \"Users & Groups\" pane of the \"System Preferences\" when adding a
      new user and changing the \"New Account\" pop-up menu to \"Sharing Only\".
    A \"Sharing Only\" account can access shared files remotely,
      but can't log in or change settings on the computer.

    A \"Sharing Only\" account is equivalent to creating a user with the
      login shell set to \"/usr/bin/false\" and home set to \"/dev/null\" .
    This can also be done manually with ${ansi_bold}--shell /usr/bin/false --home /dev/null${clear_ansi},
      or ${ansi_bold}${ansi_underline}--no-login${clear_ansi}${ansi_bold} --home /dev/null${clear_ansi} (see ${ansi_bold}--no-login${clear_ansi} help for more information).
    Make sure to specify a password when creating a \"Sharing Only\" account,
      or it will have ${ansi_underline}a blank/empty password${clear_ansi}.

    Also, when running on macOS 11 Big Sur or newer, \"Sharing Only\" accounts
      get a special tag added to the AuthenticationAuthority attribute
      of the user record to let macOS know not to grant a Secure Token.
    See ${ansi_bold}--prevent-secure-token-on-big-sur-and-newer${clear_ansi} help for more information
      about preventing macOS from granting an account the first Secure Token.

    This is here as a seperate option for convenience and information.
    When using this option, you CANNOT also specify ${ansi_bold}--administrator${clear_ansi},
      since \"Sharing Only\" accounts should not be administrators.
    Also, you cannot specify ${ansi_bold}--role-account${clear_ansi} or ${ansi_bold}--service-account${clear_ansi}
      with this option since they are mutually exclusive account types.
    For more information about \"Sharing Only\" accounts, visit:
      ${ansi_underline}https://support.apple.com/guide/mac-help/mchlp15577${clear_ansi}


  ${ansi_bold}--role-account, --role, -r${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to create a \"Role Account\".

    A ${ansi_bold}-roleAccount${clear_ansi} option was added to ${ansi_bold}sysadminctl -addUser${clear_ansi} in macOS 11 Big Sur,
      but sadly there is not really any documentation from Apple about what
      exactly a \"Role Account\" is or when and why you would want to use one.
    I believe you would want to use a \"Role Account\" when you want a user
      exclusively to be the owner of files and/or processes and ${ansi_bold}${ansi_underline}have a password${clear_ansi}.
    All ${ansi_bold}sysadminctl${clear_ansi} states about them is the following:
      ${ansi_bold}Role accounts require name starting with _ and UID in 200-400 range.${clear_ansi}
    And ${ansi_bold}mkuser${clear_ansi} has these same requirements to create a \"Role Account\".
    Even though the ${ansi_bold}-roleAccount${clear_ansi} option was only added to ${ansi_bold}sysadminctl -addUser${clear_ansi}
      in macOS 11 Big Sur, ${ansi_bold}mkuser${clear_ansi} can make \"Role Accounts\" with
      the same attributes on older versions of macOS as well.

    Using this option is the same as creating a \"Role Account\" using
      ${ansi_bold}sysadminctl -addUser${clear_ansi} with a command like:
      ${ansi_bold}sysadminctl -addUser _role -UID 201 -roleAccount${clear_ansi}
    This example ${ansi_bold}sysadminctl -addUser${clear_ansi} command would create a \"Role Account\"
      with the account name and full name of \"_role\" and the User ID \"201\".
    ${ansi_bold}IMPORTANT:${clear_ansi} The example account would be created with ${ansi_underline}a blank/empty password${clear_ansi}.

    If you want to make an account exclusively to be the owner of files
      and/or processes that ${ansi_underline}has NO password${clear_ansi}, you probably want to use the
      ${ansi_bold}--service-account${clear_ansi} option instead of this ${ansi_bold}--role-account${clear_ansi} option.

    Through investigation of a \"Role Account\" created by ${ansi_bold}sysadminctl -addUser${clear_ansi},
      a \"Role Account\" is equivalent to creating a hidden user with account name
      starting with \"_\" and login shell \"/usr/bin/false\" and home \"/var/empty\".
    The previous example account could be created manually with ${ansi_bold}mkuser${clear_ansi} using:
      ${ansi_bold}-n _role -u 201 -s /usr/bin/false -H /var/empty --hide userOnly${clear_ansi}
      or ${ansi_bold}--name _role --uid 201 ${ansi_underline}--no-login${clear_ansi}${ansi_bold} --home /var/empty --hide userOnly${clear_ansi}.
    See ${ansi_bold}--no-login${clear_ansi} help for more information about login shell \"/usr/bin/false\".
    See ${ansi_bold}--hidden${clear_ansi} help for more information about hiding users (${ansi_bold}--hide userOnly${clear_ansi}).

    This is here as a seperate option for convenience and information.
    So, this same example account could be created with ${ansi_bold}mkuser${clear_ansi} using:
      ${ansi_bold}--account-name _role --uid 201 --role-account${clear_ansi}

    Unlike ${ansi_bold}sysadminctl -addUser${clear_ansi} which requires the User ID to be specified
      manually, ${ansi_bold}mkuser${clear_ansi} can assign the next available User ID starting from ${ansi_underline}200${clear_ansi}.
    So if the User ID is not important, you can just use ${ansi_bold}--name _role --role${clear_ansi} to
      make this same example account with the next User ID in the 200-400 range.

    ${ansi_bold}sysadminctl -addUser${clear_ansi} does not allow creating an admin \"Role Account\".
    If you run ${ansi_bold}sysadminctl -addUser _role -UID 201 -roleAccount -admin${clear_ansi},
      the ${ansi_bold}-admin${clear_ansi} option is silently ignored by ${ansi_bold}sysadminctl -addUser${clear_ansi}.
    ${ansi_bold}mkuser${clear_ansi} also does not allow a \"Role Account\" to be an admin, but errors when
      using the ${ansi_bold}--admin${clear_ansi} option with ${ansi_bold}--role-account${clear_ansi} instead of ignoring it.
    Also, you cannot specify ${ansi_bold}--sharing-only${clear_ansi} or ${ansi_bold}--service-account${clear_ansi}
      with this option since they are mutually exclusive account types.


  ${ansi_bold}--service-account, --service, --sa${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to create a \"Service Account\".

    A \"Service Account\" is similar to a \"Role Account\" in that it exists
      exclusively to be the owner of files and/or processes but ${ansi_bold}${ansi_underline}has NO password${clear_ansi}.
    This is like macOS built-in accounts, such as the \"FTP Daemon\" (_ftp) user.

    Through investigation of the built-in macOS \"Service Accounts\",
      a \"Service Account\" is roughly equivalent to creating a standard user with
      name starting with \"_\", login shell \"/usr/bin/false\", home \"/var/empty\",
      and ${ansi_underline}NO password${clear_ansi} (see ${ansi_bold}--no-password${clear_ansi} for more information about that).
    See ${ansi_bold}--no-login${clear_ansi} help for more information about login shell \"/usr/bin/false\".
    But, this is just a basic template of a \"Service Accounts\".

    These are not all hard requirements for a \"Service Account\".
    The hard requirements are that the account name must start with \"_\",
      must have NO password, must have no picture, CANNOT be an admin,
      and the home folder cannot be within the \"/Users/\" folder.
    But, you can specify any User ID, Primary Group ID, or login shell.
    If ${ansi_bold}--user-id${clear_ansi} is omitted, the next available User ID starting from ${ansi_underline}200${clear_ansi}
      will be assigned by default (the same as a \"Role Account\").
    If ${ansi_bold}--group-id${clear_ansi} is omitted, the ${ansi_underline}-2${clear_ansi} (nobody) group will be used.
    If ${ansi_bold}--login-shell${clear_ansi} is omitted, the \"/usr/bin/false\" will be used.
    If ${ansi_bold}--home-folder${clear_ansi} is omitted, \"/var/empty\" will be used.

    Also, you cannot specify ${ansi_bold}--sharing-only${clear_ansi} or ${ansi_bold}--role-account${clear_ansi}
      with this option since they are mutually exclusive account types.

    While you can pretty much make a \"Service Account\" manually using the other
      ${ansi_bold}mkuser${clear_ansi} options, there is a difference when you specify ${ansi_bold}--service-account${clear_ansi}.
    All other account types get a variety of attributes added to the user record
      that allow the user to manage some aspects of their own account, but none
      of these attributes are included for built-in macOS \"Service Accounts\".
    To match the built-in macOS \"Service Accounts\", these management attributes
      will not be included in the user record when specifying ${ansi_bold}--service-account${clear_ansi}.
    Excluding some (not all) of these specific management attributes is how the
      ${ansi_bold}--prohibit-user-password-changes${clear_ansi} and
      ${ansi_bold}--prohibit-user-picture-changes${clear_ansi} options work.

    ${ansi_bold}GROUPS SPECIFICALLY FOR SERVICE ACCOUNTS NOTES:${clear_ansi}
    Many built-in macOS \"Service Accounts\" have a group specifically for them,
      and often that Group ID is the same as the \"Service Accounts\" User ID
      and the Group ID is set to the Primary Group ID of the \"Service Account\".

    If you specify a Primary Group ID (${ansi_bold}--group-id${clear_ansi}), it must already exist.
    If you want to create a group just to be used with a \"Service Account\",
      you can do that easily before making the \"Service Account\" with:
      ${ansi_bold}dseditgroup -o create -i <GROUP ID> -r <GROUP FULL NAME> <GROUP NAME>${clear_ansi}
    When you do this before creating a \"Service Account\" with ${ansi_bold}mkuser${clear_ansi}, you can
      set the \"Service Account\" Primary Group ID to this Group ID with ${ansi_bold}--gid${clear_ansi}.
    After creating the \"Service Account\", you can also add it to the group with:
      ${ansi_bold}dseditgroup -o edit -a <SERVICE ACCOUNT NAME> -t user <GROUP NAME>${clear_ansi}
    But, that is not really necessary if the \"Service Account\" already has
      its Primary Group ID set to the Group ID.


  ${ansi_bold}--prevent-secure-token-on-big-sur-and-newer, --prevent-secure-token, --no-st${clear_ansi}
    < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to prevent the user from being
      automatically granted the first Secure Token on macOS 11 Big Sur and newer
      when and if they are being created when the first Secure Token has not yet
      been automatically granted by macOS.
    This option is helpful when creating scripted users before going through
      Setup Assistant that you do not want to be granted the first Secure Token,
      which would prevent the Setup Assistant user from getting a Secure Token.
    This option will add a special tag to the AuthenticationAuthority attribute
      of the user record to let macOS know not to grant a Secure Token.
    For more information about this Secure Token prevention tag, visit:
      ${ansi_underline}https://support.apple.com/guide/deployment/dep24dbdcf9e${clear_ansi}
    A Secure Token could still be manually granted to this user after specifying
      this option on macOS 11 Big Sur and newer with ${ansi_bold}sysadminctl -secureTokenOn${clear_ansi}.
    This option has no effect on macOS 10.15 Catalina and older, but there is
      useful information below about first Secure Token behavior all the way
      back to macOS 10.13 High Sierra when Secure Tokens were first introduced.

    ${ansi_bold}VOLUME OWNER ON APPLE SILICON NOTES:${clear_ansi}
    On Apple Silicon Macs, users that do not have a Secure Token cannot
      be Volume Owners, which means they will not be able to approve
      system updates (among other things).

    ${ansi_bold}macOS 11 Big Sur AND NEWER FIRST SECURE TOKEN NOTES:${clear_ansi}
    On macOS 11 Big Sur and newer, the first Secure Token is granted to
      the first administrator or standard user when their password is set,
      regardless of their UID.
    This essentially means the first Secure Token is granted right when the
      first user is created.
    This is different from previous versions of macOS which would grant the
      first Secure Token upon first login or authentication.
    Since this behavior is more aggressive than previous first Secure Token
      behavior, a new way has been added to selectively prevent a user from
      being granted the first Secure Token.
    This is done by adding a special tag to the AuthenticationAuthority
      attribute in the user record before the users password has been set.
    While ${ansi_bold}mkuser${clear_ansi} includes this option and takes care of the necessary timing,
      it's worth noting that when creating users with ${ansi_bold}sysadminctl -addUser${clear_ansi}
      it's actually impossible to prevent a Secure Token in this way since the
      password is always set during that user creation process, even if it's
      just a blank/empty password.
    When users are created with this tag in their AuthenticationAuthority,
      the first user that does not have this special tag will get the first
      Secure Token when their password is set (basically, upon creation).
    In general, you will want to make sure the the first user being granted
      a Secure Token is also an administrator so that they are allowed to do all
      possible operations on macOS (especially on T2 and Apple Silicon Macs).

    ${ansi_bold}macOS 10.15 Catalina FIRST SECURE TOKEN NOTES:${clear_ansi}
    On macOS 10.15 Catalina, the first Secure Token is granted to the first
      administrator (not standard user) to login or authenticate,
      regardless of their UID.
    Even though ${ansi_bold}mkuser${clear_ansi} will always verify the password (using native
      ${ansi_bold}OpenDirectory${clear_ansi} methods) during the user creation process (which is an
      authentication that could trigger granting the first Secure Token), this
      authentication happens before the user is added to the \"admin\" group
      (if they are configured to be an administrator).
    This means that users will never be an administrator during this
      authentication within the ${ansi_bold}mkuser${clear_ansi} process and therefore will not be granted
      the first Secure Token at that moment.
    The first Secure Token will then be granted by macOS to the first
      administrator to login or authenticate after ${ansi_bold}mkuser${clear_ansi} has finished.
    This is the same first Secure Token behavior that can be expected from any
      other user creation method that I'm aware of.
    If for some reason you want to immediately grant an administrator created by
      ${ansi_bold}mkuser${clear_ansi} the first Secure Token, you can manually run
      ${ansi_bold}dscl . -authonly${clear_ansi} after ${ansi_bold}mkuser${clear_ansi} has finished.

    ${ansi_bold}macOS 10.14 Mojave AND macOS 10.13 High Sierra FIRST SECURE TOKEN NOTES:${clear_ansi}
    The following information only applies to macOS on an APFS volume
      (and not HFS+) as Secure Tokens are exclusively an APFS feature.
    The Secure Token behavior is slightly different on macOS 10.14 Mojave
      and macOS 10.13 High Sierra than it is on new versions of macOS.
    Also, ${ansi_bold}mkuser${clear_ansi}'s process has an effect on the default macOS behavior of
      granting the first Secure Token.
    Basically, the first Secure Token is granted to the first administrator or
      standard user to login or authenticate which has a UID of 500 or greater
      if and only if they are the only user with a UID of 500 or greater.
    This means that if multiple users with UIDs of 500 or greater were to be
      created before any of them logged in or authenticated,
      no first Secure Token would be granted automatically by macOS
      (which is not a great situation to get into by accident).
    But, ${ansi_bold}mkuser${clear_ansi} simplifies this complexity since the password will always be
      verified during the user creation process (using native ${ansi_bold}OpenDirectory${clear_ansi}
      methods), which means the users first authentication actually happens
      during the ${ansi_bold}mkuser${clear_ansi} user creation process.
    Therefore, when using ${ansi_bold}mkuser${clear_ansi}, the first Secure Token will always be granted
      to the first user created with a UID of 500 or greater when their password
      is verified during the ${ansi_bold}mkuser${clear_ansi} process.
    If you do not want the first user you are creating with ${ansi_bold}mkuser${clear_ansi} to be granted
      the first Secure Token, such as for a management account, simply set their
      UID below 500 and macOS will not grant them the first Secure Token when
      their password is verified by ${ansi_bold}mkuser${clear_ansi}.
    Then, the first user created by ${ansi_bold}mkuser${clear_ansi} with a UID of 500 or greater or
      the first user created by going through first boot Setup Assistant will
      get the first Secure Token as intended.
    You can also simply adjust the order of users created to be sure the
      user with a UID of 500 or greater that you want to be granted the
      first Secure Token is created first.
    In general, you will want to make sure the first user being granted a
      Secure Token is also an administrator so that they are allowed to do all
      possible operations on macOS, such as grant other users a Secure Token.

    ${ansi_bold}ALL VERSIONS OF macOS SECURE TOKEN NOTES:${clear_ansi}
    Once the first Secure Token has been granted, any subsequent users
      created by ${ansi_bold}mkuser${clear_ansi} or by going through first boot Setup Assistant will
      not automatically be granted a Secure Token by macOS since the first
      Secure Token has already been granted.
    If you're using ${ansi_bold}mkuser${clear_ansi} to create users before going through Setup Assistant,
      and you want the user created by first boot Setup Assistant to be granted
      the first Secure Token, be sure to take the necessary steps for each
      version of macOS (as outline above) to ensure any users created by
      ${ansi_bold}mkuser${clear_ansi} are not granted the first Secure Token.
    Once the first Secure Token has been granted by macOS, you must use
      ${ansi_bold}sysadminctl -secureTokenOn${clear_ansi} to grant other users a Secure Token and
      authenticate the command with an existing Secure Token administrator
      either interactively or by passing their credentials with
      the ${ansi_bold}-adminUser${clear_ansi} and ${ansi_bold}-adminPassword${clear_ansi} options.
    Or, ${ansi_bold}mkuser${clear_ansi} can securely take care of this for you when creating new
      users if you pass an existing Secure Token admins credentials using the
      ${ansi_bold}--secure-token-admin-account-name${clear_ansi} option along with one of the
      three different Secure Token admin password options below.
    See the ${ansi_underline}SECURE TOKEN 1022 BYTE PASSWORD LENGTH LIMIT NOTES${clear_ansi} in the help
      information for the ${ansi_bold}--secure-token-admin-password${clear_ansi} option below and the
      ${ansi_underline}PASSWORDS IN PACKAGE NOTES${clear_ansi} in help information for the ${ansi_bold}--password${clear_ansi} option
      above for more information about how passwords are handled securely
      by ${ansi_bold}mkuser${clear_ansi}, all of which also apply to Secure Token admin passwords.
    Users created in the \"Users & Groups\" pane of the \"System Preferences\"
      will only get a Secure Token when the pane has been unlocked by an
      existing Secure Token administrator.
    Similarly, users created using ${ansi_bold}sysadminctl -addUser${clear_ansi} will only get a
      Secure Token when the command is authenticated with an existing
      Secure Token administrator (the same way as when using
      the ${ansi_bold}sysadminctl -secureTokenOn${clear_ansi} option).
    The only exception to this subsequent Secure Token behavior
      is when utilizing MDM with a Bootstrap Token.


  ${ansi_bold}--secure-token-admin-account-name, --st-admin-name, --st-admin-user, --st-name${clear_ansi}
    < ${ansi_underline}string${clear_ansi} >

    Specify an existing Secure Token administrator account name (not full name)
      along with their password (using one of the three different options below)
      to be used to grant the new user a Secure Token.
    This option is ignored on HFS+ volumes since Secure Tokens are APFS-only.


  ${ansi_bold}--secure-token-admin-password, --st-admin-pass, --st-pass${clear_ansi}  < ${ansi_underline}string${clear_ansi} >

    The password must be at least 4 characters and 1022 bytes or less,
      or a blank/empty password.
    The password will be validated to be correct for the
      specified ${ansi_bold}--secure-token-admin-account-name${clear_ansi}.
    If omitted, blank/empty password will be specified.
    This option is ignored on HFS+ volumes since Secure Tokens are APFS-only.

    See ${ansi_underline}PASSWORDS IN PACKAGE NOTES${clear_ansi} in help information for the ${ansi_bold}--password${clear_ansi} option
      above for more information about how the Secure Token admin password
      is securely obfuscated within a package.

    ${ansi_bold}SECURE TOKEN ADMIN 1022 BYTE PASSWORD LENGTH LIMIT NOTES:${clear_ansi}
    To grant the new user a Secure Token, the user and existing Secure Token
      admin passwords must be passed to ${ansi_bold}sysadminctl -secureTokenOn${clear_ansi}.
    To do this in the most secure way possible (so that they are never visible
      in the process list), the passwords are NOT passed directly as arguments
      but are instead passed via \"stdin\" using the command line prompt options.
    But, this technique fails with Secure Token admin passwords over 1022 bytes.
    For a bit more technical information about this limitation from my testing,
      search for ${ansi_underline}1022 bytes${clear_ansi} within the source of this script.
    The length of the new user password is not an issue for this command since
      it is limited to a maximum of 511 bytes as described in the
      ${ansi_underline}511 BYTE PASSWORD LENGTH LIMIT NOTES${clear_ansi} in help information
      for the ${ansi_bold}--password${clear_ansi} option above.
    Since ${ansi_bold}mkuser${clear_ansi} strives to handle passwords in the most secure ways possible,
      the password length of Secure Token admin is limited to 1022 bytes so that
      the password can be passed to ${ansi_bold}sysadminctl -secureTokenOn${clear_ansi} in a secure way
      that never makes it visible in the process list.
    If your existing Secure Token admin has a longer password for any reason,
      you can use it to manually grant a Secure Token after creating a
      non-Secure Token account with ${ansi_bold}mkuser${clear_ansi} by insecurely passing the password
      directly to ${ansi_bold}sysadminctl -secureTokenOn${clear_ansi} as an argument since longer
      passwords are properly accepted when passed that way.


  ${ansi_bold}--fd3-secure-token-admin-password, --fd3-st-admin-pass, --fd3-st-pass${clear_ansi}
    < ${ansi_underline}no parameter${clear_ansi} (fd3) >

    Include this option with no parameter to pass the Secure Token admin
      password via file descriptor 3 (fd3), using an \"fd3\" here-string (${ansi_bold}3<<<${clear_ansi}).
    If you haven't used \"fd3\" here-strings before, it looks like this:
      ${ansi_bold}mkuser [OPTIONS] --fd3-secure-token-admin-password [OPTIONS] ${ansi_underline}3<<< '<PASS>'${clear_ansi}
    Passing the password via \"fd3\" instead of directly with the
      ${ansi_bold}--secure-token-admin-password${clear_ansi} option hides the password
      from the process list.
    The help information for the ${ansi_bold}--secure-token-admin-password${clear_ansi} option above
      also applies to Secure Token admin passwords passed via \"fd3\".
    This option is ignored on HFS+ volumes since Secure Tokens are APFS-only.


  ${ansi_bold}--secure-token-admin-password-prompt, --st-admin-pass-prompt, --st-pass-prompt${clear_ansi}
    < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to be prompted for the Secure Token
      admin password on the command line before creating the user or package.
    This option allows you to specify a Secure Token admin password without it
      being saved in your command line history as well as hides the password
      from the process list.
    The help information for the ${ansi_bold}--secure-token-admin-password${clear_ansi} option above also
      applies to Secure Token admin passwords entered via command line prompt.
    This option is ignored on HFS+ volumes since Secure Tokens are APFS-only.
    ${ansi_bold}NOTICE:${clear_ansi} This option cannot be used when ${ansi_bold}--stdin-password${clear_ansi} is specified since
      accepting \"stdin\" disrupts the ability to use other command line inputs.


\xf0\x9f\x9a\xaa ${ansi_bold}LOGIN OPTIONS:${clear_ansi}

  ${ansi_bold}--automatic-login, --auto-login, -A${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to set automatic login for the user.
    Enabling automatic login stores the users password in the filesystem
      in an obfuscated but insecure way.
    If automatic login is already setup for another user, it'll be overwritten.
    If FileVault is enabled, automatic login is not possible or allowed
      and this option will be ignored (and a warning will be displayed).


  ${ansi_bold}--prevent-login, --no-login, --nl${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to prevent this user from logging in.
    This option is equivalent to setting the login shell to \"/usr/bin/false\"
      which can also be done directly with ${ansi_bold}--login-shell /usr/bin/false${clear_ansi}.
    This is here as a seperate option for convenience and information.
    When the login shell is set to \"/usr/bin/false\", the user is will not show
      in the \"Users & Groups\" pane of the \"System Preferences\" and will
      also not show up in the non-FileVault login window list of users.

    If FileVault is enabled and one of these users has a password and is
      granted a Secure Token, they WILL show in the FileVault login window
      and can decrypt the volume, but then the non-FileVault login will be
      hit to fully login to macOS with another user account.
    Unlike hidden users, these user CANNOT be logged into using
      text input fields in the non-FileVault login window.

    Even if one of these users has a password set, they CANNOT
      authenticate \"Terminal\" commands like ${ansi_bold}su${clear_ansi}, or ${ansi_bold}login${clear_ansi}.
    They also CANNOT authenticate graphical prompts, such as unlocking
      \"System Preferences\" panes if they are in an administrator.
    But, if these users are an admin, they CAN run AppleScript ${ansi_bold}do shell script${clear_ansi}
      commands ${ansi_bold}with administrator privileges${clear_ansi}.


  ${ansi_bold}--skip-setup-assistant, --skip-setup, -S${clear_ansi}
    < ${ansi_underline}firstBootOnly${clear_ansi} || ${ansi_underline}firstLoginOnly${clear_ansi} || ${ansi_underline}both${clear_ansi} (or ${ansi_underline}no parameter${clear_ansi}) >

    Include this option with either no parameter or specify \"${ansi_underline}both${clear_ansi}\"
      to skip both the first boot and first login Setup Assistant screens.

    Specify \"${ansi_underline}firstBootOnly${clear_ansi}\" to skip only the first boot Setup Assistant screens.
    This affects all users and will only have an effect if the first boot
      Setup Assistant has not already run.

    Specify \"${ansi_underline}firstLoginOnly${clear_ansi}\" to skip only the users first login
      Setup Assistant screens.
    This affects only this user and will also skip any and all future user
      Setup Assistant screens that may appear when and if macOS is updated.

    Any other parameters are invalid and will cause the user to not be created.


\xf0\x9f\x93\xa6 ${ansi_bold}PACKAGING OPTIONS:${clear_ansi}

  ${ansi_bold}--package-path, --pkg-path, --package, --pkg${clear_ansi}
    < ${ansi_underline}folder path${clear_ansi} || ${ansi_underline}pkg file path${clear_ansi} || ${ansi_underline}no parameter${clear_ansi} (working directory) >

    Save distribution package to create a user with the other specified options.
    This will not create a user immediately on the current system, but will
      save a distribution package file that can be used on another system.
    The distribution package (product archive) created will be suitable for use
      with ${ansi_bold}startosinstall --installpackage${clear_ansi} or ${ansi_bold}installer -pkg${clear_ansi} or \"Installer\" app,
      and is also \"no payload\" which only runs scripts and leaves no receipt.
    If no path is specified, the current working directory will be used along
      with the default filename: ${ansi_underline}<PKG ID>-<PKG VERSION>.pkg${clear_ansi}
    If a folder path is specified, the default filename will be used
      within the specified folder.
    If a full file path ending in \".pkg\" is specified, that whole path
      and filename will be used.
    For any of these path options, if the exact filename already exists in the
      specified folder, it will be OVERWRITTEN by a newly created package.


  ${ansi_bold}--package-identifier, --pkg-identifier, --package-id, --pkg-id${clear_ansi}  < ${ansi_underline}string${clear_ansi} >

    Specify the bundle identifier string to use for the package
      (only valid when using the ${ansi_bold}--package${clear_ansi} option).
    Must be 248 characters/bytes or less and start with a letter or number
      and can only contain alphanumeric, hyphen/minus (-),
      underscore (_), or dot (.) characters.
    If the package identifier is over 248 characters, the installation would
      fail to extract the package scripts since they are extracted into a folder
      named with the package identifier and appended with a period plus 6 random
      characters which would make that folder name over the macOS 255 byte max.
    If omitted, the default identifier will be used: ${ansi_underline}mkuser.pkg.<ACCOUNT NAME>${clear_ansi}


  ${ansi_bold}--package-version, --pkg-version, --pkg-v${clear_ansi}  < ${ansi_underline}version string${clear_ansi} >

    Specify the version string to use for the package
      (only valid when using the ${ansi_bold}--package${clear_ansi} option).
    Must start with a number or letter and can only contain alphanumeric,
      hyphen/minus (-), or dot (.) characters.
    If omitted, the current date will be used in the format: ${ansi_underline}YYYY.M.D${clear_ansi}


  ${ansi_bold}--package-signing-identity, --package-sign, --pkg-sign${clear_ansi}  < ${ansi_underline}string${clear_ansi} >

    Specify the installer package signing identity string to use for the package
      (only valid when using the ${ansi_bold}--package${clear_ansi} option).
    The string must be for an existing installer package signing identity in the
      Keychain, and in the proper format: ${ansi_underline}Developer ID Installer: Name (Team ID)${clear_ansi}
    If omitted, the package will not be signed.


\xe2\x9a\x99\xef\xb8\x8f  ${ansi_bold}MKUSER OPTIONS:${clear_ansi}

  ${ansi_bold}--do-not-confirm, --no-confirm, --force, -F${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    By default, ${ansi_bold}mkuser${clear_ansi} prompts for confirmation on the command line before
      creating a user on the current system.
    Include this option with no parameter to NOT prompt for confirmation.
    This option is ignored when outputting a user creation package (with the
      ${ansi_bold}--package${clear_ansi} option) since no user will be created on the current system.
    ${ansi_bold}NOTICE:${clear_ansi} Specifying ${ansi_bold}--suppress-status-messages${clear_ansi} OR ${ansi_bold}--stdin-password${clear_ansi}
      also ENABLES ${ansi_bold}--do-not-confirm${clear_ansi}.


  ${ansi_bold}--suppress-status-messages, --quiet, -q${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to not output any status messages
      that would be sent to \"stdout\".
    Any errors and warning that are sent to \"stderr\" will still be outputted.
    ${ansi_bold}NOTICE:${clear_ansi} Specifying ${ansi_bold}--suppress-status-messages${clear_ansi} also ENABLES ${ansi_bold}--do-not-confirm${clear_ansi}.


  ${ansi_bold}--check-only, --dry-run, --check, -c${clear_ansi}  < ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to check if the other specified
      options are valid and output the settings a user would be created with.
    This option is ignored when outputting a user creation package (with the
      ${ansi_bold}--package${clear_ansi} option) since checking against the
      current system isn't useful when installing packages on other systems.


  ${ansi_bold}--version, -v${clear_ansi}  < ${ansi_underline}online${clear_ansi} (or ${ansi_underline}o${clear_ansi}) || ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to display the ${ansi_bold}mkuser${clear_ansi} version
      (which is ${MKUSER_VERSION}), and also check for updates when connected to
      the internet and display the newest version if an update is available.

    Specify \"${ansi_underline}online${clear_ansi}\" (or \"${ansi_underline}o${clear_ansi}\") to also open the ${ansi_bold}mkuser${clear_ansi} Releases page on GitHub
      in the default web browser to be able to quickly and easily view the
      latest release notes as well as download the latest version.

    This option overrides all other options (including ${ansi_bold}--help${clear_ansi}).


  ${ansi_bold}--help, -h${clear_ansi}  < ${ansi_underline}brief${clear_ansi} (or ${ansi_underline}b${clear_ansi}) ||  ${ansi_underline}online${clear_ansi} (or ${ansi_underline}o${clear_ansi}) || ${ansi_underline}no parameter${clear_ansi} >

    Include this option with no parameter to display this help information.

    Specify \"${ansi_underline}brief${clear_ansi}\" (or \"${ansi_underline}b${clear_ansi}\") to only show options without their descriptions.
    This can be helpful for quick reference to check option or parameter names.

    Specify \"${ansi_underline}online${clear_ansi}\" (or \"${ansi_underline}o${clear_ansi}\") to instead open the README section of the
      ${ansi_bold}mkuser${clear_ansi} GitHub page in the default web browser to be able quickly
      and easily view the help information on there.

    This option overrides all other options (except ${ansi_bold}--version${clear_ansi}).
"

		if $show_brief_help; then
			# DO NOT "echo -e" when grepping so that ansi codes are easier to match and replace and the missing options check continues to work below against un-interpreted ansi codes.
			help_information="$(echo "${help_information}" | grep '^[^ ]\|^[ ]\{2\}\\033\[1m--\|^[ ]\{4\}<')" # Filter to only lines that are section titles, options, and parameter descriptions that my be on their own lines.
			help_information="${help_information//\\xf0\\x9f\\x93\\x9d \\033[1mDESCRIPTION:\\033[0m/}" # Remove DESCRIPTION section title since the description text has been removed (this leaves an empty line in it's place so that there is a line between the URL and first section title).
			help_information="${help_information//\\xe2\\x84\\xb9\\xef\\xb8\\x8f  \\033[1mUSAGE NOTES:\\033[0m$'\n'/}" # Remove USAGE NOTES section title (and the line break at the end) since the description text has been removed (this DOESN'T leave behind a line break so that there aren't two lines between the URL and first section title).
			help_information="${help_information//:\\033[0m/:\\033[0m\n}" # Add back a single line break after each section title for an easier to read display.
			help_information="\n${help_information//>/>\n}" # Add back a single line break after parameter description for an easier to read display (and add line break before first version line to retain original padding).
		fi

		echo -e "${help_information}"

		# Check that all actual options from the "case" statement above have help information for them,
		# and output anything that is missing so all options are always shown even if help doesn't exist.

		some_help_information_is_missing=false

		if [[ -n "${all_actual_case_options}" ]]; then # This is initialized above before parsing passed option and parameters.
			all_actual_case_options="${all_actual_case_options//|/, }"

			IFS=$'\n'
			for this_actual_case_option in ${all_actual_case_options}; do
				if [[ "${help_information}" != *"${ansi_bold}${this_actual_case_option}${clear_ansi}"* ]]; then
					if ! $some_help_information_is_missing; then
						echo -e "
${ansi_bold}UNDOCUMENTED OPTIONS:${clear_ansi}"
					fi

					some_help_information_is_missing=true
					echo -e "
  ${ansi_bold}${this_actual_case_option}${clear_ansi}

    Missing help information for this option.
    THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE.
"
				fi
			done
			unset IFS
		fi

		# Make sure all help information formatting is correct.

		if [[ "${help_information}" == *$'\t'* ]]; then
			>&2 echo -e "\nmkuser HELP ERROR: Help information formatting contains tabs instead of spaces.\n"
		fi

		if echo "${help_information}" | grep -q '^[ ]\{1\}[^ ]\|^[ ]\{3\}[^ ]\|^[ ]\{5\}[^ ]\|^[ ]\{7\}'; then
			>&2 echo -e "\nmkuser HELP ERROR: Help information space indenting is incorrect somewhere.\n"
		fi

		if echo "${help_information}" | grep -q ' $'; then
			>&2 echo -e "\nmkuser HELP ERROR: Some help information line has a trailing space.\n"
		fi

		# Strip ANSI styles to check each displayed line length string length.
		# From: https://superuser.com/questions/380772/removing-ansi-color-codes-from-text-stream#comment2323889_380778
		if echo -e "${help_information}" | sed -e $'s/\x1b\[[0-9;]*m//g' | grep -q '^.\{81\}'; then
			>&2 echo -e "\nmkuser HELP ERROR: Some help information line is over 80 characters.\n"
		fi

		if $some_help_information_is_missing; then
			return "${error_code}"
		fi

		return 0
	fi
	# <MKUSER-END-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!

	darwin_major_version="$(uname -r | cut -d '.' -f 1)" # 17 = 10.13, 18 = 10.14, 19 = 10.15, 20 = 11.0, etc.

	if (( darwin_major_version < 17 )); then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: This tool has only been tested to work on macOS 10.13 High Sierra and newer."
		return "${error_code}"
	fi
	(( error_code ++ ))

	# VALIDATE FORMAT OF ALL PARAMETERS
	# Do all of these checks before preparing a package (if specified) since none of these are specific to the installation system.

	if ! $suppress_status_messages; then
		echo 'mkuser: Validating specified options and parameters...'
	fi

	boot_volume_is_apfs="$([[ "$(PlistBuddy -c 'Print :FilesystemType' /dev/stdin <<< "$(diskutil info -plist /)" 2> /dev/null)" == 'apfs' ]] && echo 'true' || echo 'false')" # Need to check if boot volume is APFS to know whether or not a Secure Token can be granted.

	if [[ -z "${user_account_name}" ]]; then
		if [[ -n "${user_full_name}" ]]; then
			# If no account name specified, use the full name and convert it into a valid account name containing only lowercase letters, numbers, hyphen/minus, underscore, and period characters.
			# If an account name contains invalid characters, "dsimport" will not create the user and the invalid account name will be listed in the "Failed" and "Users not imported because of bad short names" keys of the "--outputfile" plist.

			# Use "stringByApplyingTransform" Cocoa method via JavaScript for Automation (JXA) Objective-C bridge to properly convert full name to latin characters for the account name and remove diacritics leaving the base character instead of just stripping out the characters with diacritics (and also convert to lowercase and strip other illegal characters via JavaScript since it's convenient).
			# This means that a full name like "上海" will be properly converted to "shanghai" and "P̃īçø" will be converted to "pico" for the account name like System Preferences does.
			# Helpful links for the "stringByApplyingTransform" custom transform rules: https://nshipster.com/cfstringtransform/ & https://oleb.net/blog/2016/01/icu-text-transforms/
			# Useful "Iлｔèｒｎåｔïｏｎɑｌíƶａｔï߀ԉ ą ć ę ł ń ó ś ź ż ä ö ü ß" test string from: https://javascript.plainenglish.io/not-so-obvious-removal-of-diacritics-in-javascript-explained-and-done-right-52f4aeb3c85

			user_account_name="$(OSASCRIPT_ENV_USER_FULL_NAME="${user_full_name}" osascript -l 'JavaScript' -e "$.NSProcessInfo.processInfo.environment.objectForKey('OSASCRIPT_ENV_USER_FULL_NAME').stringByApplyingTransformReverse('Any-Latin; Latin-ASCII; Any-Lower', false).js.replace(/[^${a_z}${DIGITS}_.-]/g, '')" 2> /dev/null)"
			# For information about why the full name (which is user input) is passed to JXA as a command specific environment variable,
			# which is then retrieved within JXA, see: https://paulgalow.com/how-to-work-with-json-api-data-in-macos-shell-scripts
			# (This blog post is specifically about handling arbitrary JSON in JXA, but all of the same security precautions apply to handling user input, as well as the benefit of not needing to escape any special characters.)

			# Some characters such as "ԉ" and emoji are not converted via "stringByApplyingTransform", but will be properly stripped out using the JavaScript string "replace" function.
			# Characters like emoji could be converted to their Unicode names with "NSStringTransformToUnicodeName" but that seems unnecessary and possibly confusing to include in an account name. Stripping these kinds of characters out also matches the System Preferences behavior.
			# NOTE: This code DOES NOT properly transliterate some languages such as Japanese where "日本" will be transliterated into "riben" instead of "nippon" since each character is being transliterated individually instead of as a single token. System Preferences transliterates this properly to "nippon".
			# It seems like using CFStringTokenizer would be the solution, but I haven't tried to do that yet in JXA: https://stackoverflow.com/questions/37685877/how-to-customize-cfstring-transliteration-in-cocoa-cocoa-touch-foundation/42330497#42330497 & https://stackoverflow.com/questions/1752946/how-to-get-the-first-n-words-from-a-nsstring-in-objective-c/1753141#1753141

			if [[ -z "${user_account_name}" ]]; then
				# If something went wrong with the Cocoa conversion via JXA and the result is an empty string, fall back to just stripping the illegal characters from the full name and setting it to lowercase in bash (which will just completely remove any characters with diacritics).

				user_account_name="$(echo "${user_full_name//[^${A_Z}${a_z}${DIGITS}_.-]/}" | tr '[:upper:]' '[:lower:]')"
			fi

			# ONLY WHEN converting full name into account name, removing any invalid leading characters ("." and "-").
			user_account_name="${user_account_name#"${user_account_name%%[^.-]*}"}"

			# ONLY WHEN converting full name into account name, truncate to 244 characters if longer. This just won't do anything if under 244 characters.
			user_account_name="${user_account_name:0:244}"
		fi

		if [[ -z "${user_account_name}" ]]; then
			could_not_convert_full_name_note=''
			if [[ -n "${user_full_name}" ]]; then could_not_convert_full_name_note=' Could not convert full name into account name.'; fi
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: No account name specified.${could_not_convert_full_name_note}"
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if (( ${#user_account_name} > 244 )); then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Account name must be 244 characters or less. Specified account name is ${#user_account_name} characters long. See \"--help\" for more information about this limitation."
		return "${error_code}"

		# System Preferences does not allow account names to be over 83 characters.
		# But, the *true* limit of the account name seems to 244 chars/byte (the char count will always be the byte count because of the allowed characters).
		# Any longer than 244 chars and "dsimport" seems to execute without error (no non-zero exit code and no errors in the "--outputfile" plist), but the user just DOES NOT get created and fails on the first verification check.
		# Using "dscl . -create" also fails silently with account names over 244 characters, and the user just does not get create (like "dsimport").
		# Using "sysadminctl -addUser" fails gloriously with a bunch of errors with account names over 244 characters though. The errors are on multiple lines of "DSRecord.m" with error codes "-14136" and "-14071" and the user just does not get created.
		# So, limit the account name to 244 chars since that seems to be a true limit of all macOS account creation techniques.
		# This 244 character limit was tested and confirmed on both macOS 11 Big Sur and macOS 10.13 High Sierra.
	fi
	(( error_code ++ ))

	if ! [[ "${user_account_name}" =~ [${a_z}]+ ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Account name must contain at least one letter."
		return "${error_code}"

		# System Preferences states that account names "Cannot contain numbers only" which is also shown when a hyphen/minus, underscore, or period is included, so it really means at least one letter is required.
		# Setup Assistant will automatically add an "a" to the begnning of an account name that does not contain any letters.
		# "sysadminctl -addUser" DOES allow account names that don't contain any letter and "dsimport" will also successfully create a user with an account name of only numbers and the user
		# seemed to work fine in my brief testing. But still, I've chosen to match what System Preferences and Setup Assistant allows for consistency with normal user creation on macOS.
	fi
	(( error_code ++ ))

	if [[ "${user_account_name}" == 'guest' ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Account name \"${user_account_name}\" is a reserved by macOS."
		return "${error_code}"
	fi
	(( error_code ++ ))

	if [[ -z "${user_full_name}" ]]; then
		user_full_name="${user_account_name}" # If no full name specified, use the account name (which will always be a valid full name).
	elif [[ "$(echo "${user_full_name}" | tr '[:upper:]' '[:lower:]')" == 'guest' ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Full name \"${user_full_name}\" is a reserved by macOS."
		return "${error_code}"
	fi
	(( error_code ++ ))

	if [[ -n "${user_uid}" ]] && ( [[ "$(( user_uid ))" != "${user_uid}" ]] || (( user_uid < -2147483648 || user_uid > 2147483647 )) ); then
		# bash arithmetic cannot handle numbers outside of the signed 64-bit range, they just rollover.
		# We can detect this rollover by seeing if the arithmetic value is not equal to the string value.

		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: User ID is outside of the allowed range, it must be between between -2147483648 and 2147483647 (signed 32-bit integer range)."
		return "${error_code}"
	fi
	(( error_code ++ ))

	if [[ -n "${user_gid}" ]] && ( [[ "$(( user_gid ))" != "${user_gid}" ]] || (( user_gid < -2147483648 || user_gid > 2147483647 )) ); then
		# bash arithmetic cannot handle numbers outside of the signed 64-bit range, they just rollover.
		# We can detect this rollover by seeing if the arithmetic value is not equal to the string value.

		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Group ID is outside of the allowed range, it must be between between -2147483648 and 2147483647 (signed 32-bit integer range)."
		return "${error_code}"
	fi
	(( error_code ++ ))

	if $prompt_for_user_password; then
		if $has_invalid_options; then
			>&2 echo 'mkuser WARNING: NOT prompting for password since INVALID OPTIONS OR PARAMETERS are specified and user would not be created anyway.'
		elif $did_get_password_from_stdin || [[ -n "${user_password}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"--password-prompt\" option because \"--password\" or \"--stdin-password\" or \"--no-password\" has already been specified."
			return "${error_code}"
		else
			echo -en "\nSpecify Password for New \"${user_account_name}\" User: "
			read -rs prompted_user_password

			echo -en "\nConfirm Password for New \"${user_account_name}\" User: "
			read -rs confirmed_prompted_user_password

			echo -e '\n'

			if [[ "${prompted_user_password}" == "${confirmed_prompted_user_password}" ]]; then
				# I don't believe it's possible to include line breaks within a prompt like this, so we don't need to check for them to be disallowed.
				user_password="${prompted_user_password}"
			else
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified passwords did not match."
				return "${error_code}"
			fi
		fi
	fi
	(( error_code ++ ))

	# TODO: Eventually extract and check against ACTUAL password policy regex in policyContent (if a pwpolicy is set) and use the policyContentDescription when it doesn't match.
	# PlistBuddy -c 'Print :policyCategoryPasswordContent:0:policyContent' /dev/stdin <<< "$(pwpolicy -getaccountpolicies 2> /dev/null | tail +2)" 2> /dev/null
	# PlistBuddy -c 'Print :policyCategoryPasswordContent:0:policyContentDescription:en' /dev/stdin <<< "$(pwpolicy -getaccountpolicies 2> /dev/null | tail +2)" 2> /dev/null

	if [[ -z "${user_password}" ]]; then
		if ! $set_service_account; then # Service Accounts will have the password set to NO PASSWORD (*) which are allowed when FileVault is enabled.
			if $make_package; then
				# Do not bother checking if FileVault is enabled when making a package, but show a warning that this user cannot be created on FileVault enabled Macs.
				>&2 echo 'mkuser WARNING: This user will be created with a blank/empty password which are not allowed on FileVault-enabled Macs, so this user WILL NOT be created if you try to install this package on a FileVault-enabled Mac.'
			elif [[ "$(fdesetup isactive)" == 'true' ]]; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Password cannot be blank/empty when FileVault is enabled."
				return "${error_code}"
			fi
		fi

		# Blank/empty passwords are not allowed when FileVault is enabled.
		# System Preferences explicitly doesn't allow blank/empty passwords when FileVault is enabled and "sysadminctl -addUser" silently fails and sets NO password.
		# When FileVault is enabled, the "dscl . -passwd "/Users/${user_account_name}" ''" command will error with: DS Error -14165 eDSAuthPasswordQualityCheckFailed
		# and the user would get created with NO password (and not the intentional "*" no password, just no password at all) which also happens with "sysadminctl -addUser".
	elif [[ "${user_password}" != '*' ]]; then
		if (( ${#user_password} < 4 )); then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Password too short, it must be at least 4 characters or blank/empty password (unless FileVault is enabled, then blank/empty passwords are not allowed)."
			return "${error_code}"

			# If password is 1-3 characters, the user will be created but the "Password" field will end up as plain text and no "ShadowHashData" etc will be set and the password will not authenticate the user.
		fi

		user_password_byte_length="$(echo -n "${user_password}" | wc -c)" # Use "wc -c" to properly count bytes instead of characters. And must pipe to "wc" with "echo -n" to not count a trailing line break character.
		user_password_byte_length="${user_password_byte_length// /}" # Remove the leading spaces that "wc -c" includes since this number could be printed in a sentence.
		if $set_auto_login && (( user_password_byte_length > 251 )); then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Cannot set auto-login while specifying a password over 251 bytes. Specified password is ${user_password_byte_length} bytes long. Choose a shorter password or remove the unusable \"--auto-login\" option. See \"--help\" for more information about this limitation."
			return "${error_code}"

			# Read "--help" information about why passwords longer than 251 bytes are not allowed for auto-login (it's because they just don't work). The described behavior was tested on macOS 10.13 High Sierra and macOS 11 Big Sur.
		elif (( user_password_byte_length > 511 )); then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Password too long, it must be 511 bytes or less. Specified password is ${user_password_byte_length} bytes long. See \"--help\" for more information about this limitation."
			return "${error_code}"

			# For information about why passwords longer than 511 bytes are not allowed, search for and read the comments above "THIS IS WHY PASSWORDS OVER 511 BYTES ARE NOT ALLOWED" (or read notes in "--help" info).
		fi
	fi
	(( error_code ++ ))

	if (( ${#user_password_hint} > 280 )); then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Password hint must be 280 characters or less. Specified password hint is ${#user_password_hint} characters long. See \"--help\" for more information about this limitation."
		return "${error_code}"

		# System Preferences does not allow password hints to be over 128 characters.
		# In my testing on macOS 11 Big Sur, I was able to create password hints up to 550,000 bytes without issue in the non-FileVault login window but 600,000 byte hints did not load in the non-FileVault login window (just and empty password hint popover window was shown). I didn't bother narrowing that range to find exactly where it stopped loading.
		# But, no matter how many characters are in the hint, it's always truncated in the non-FileVault login window password hint popover. Only 7 lines will show of about 40 characters per line, making 280 a reasonable limit. Even if it's all 4-byte emoji, that would make a 1120 byte password hint, which is nowhere near the upper byte limit I found.
		# Since each character is a different width, 40 characters per line is just an estimation and less or more may fit depending on the characters, for example, only 14 smiley face emoji fit on a single line in the password hint popover.
		# If line breaks are included, they are rendered in the password hint popover and that can make fewer characters display since only up to 7 lines will show no matter what.
		# The FileVault login window on Apple Silicon behaves the same and non-FileVault login window since its full macOS and not an EFI app. But, the FileVault login window on Intel (which is an EFI app) actually shows longer lines and more lines. I'm not sure of the limit there, but decided to stick with 280 characters since it's long enough.

		# When testing on macOS 10.13 High Sierra, I found that it could actually display more characters and lines in the non-FileVault login window since the password hint popover would reposition and expand to the full height of the screen.
		# But, if the hint was longer than the password hint popover, the beginning would be clipped off and only the end of the password hint would be shown.
		# The FileVault login window would also show more characters and line on macOS 10.13 High Sierra, but it would just continue off the end of the screen and cover the shut down and restart buttons and push the "If you forgot your password, you can reset it using your Recovery Key" button, which is not good.
		# So, even though macOS 10.13 High Sierra could display longer password hints, I still thing 280 characters is a reasonable limit to set for all possible login scenarios and macOS versions.
	fi
	(( error_code ++ ))

	# REMOVE any and all trailing "/" characters from the home folder path.
	# Just remove these instead of forbidding them since it's a simple mistake to make and represents the same intended folder whether or not it has a trailing slash.
	# Do this before other validation since trailing slashes could make some issues not properly show as errors, such as "/Root Folder/" being allowed instead of forbid.
	user_home_path="${user_home_path%"${user_home_path##*[^/]}"}"

	if [[ -z "${user_home_path}" ]]; then
		if $set_sharing_only_account; then
			user_home_path='/dev/null'
		elif $set_role_account || $set_service_account; then
			user_home_path='/private/var/empty' # Will be converted to "/var/empty" below to match macOS, but set to "/private/var/empty" here to make the following conditions simpler for all possible situations.
		else
			user_home_path="/Users/${user_account_name}"
		fi

		# Cannot leave "user_home_path" unspecified since "dsimport" does not set any "NFSHomeDirectory" by default which will prevent the user from being able to log in.
	elif [[ "${user_home_path}" != '/'* ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Home folder \"${user_home_path}\" is not a valid absolute path, it must start with \"/\"."
		return "${error_code}"
	elif [[ "${user_home_path}" == *'//'* ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Home folder \"${user_home_path}\" is not a valid path, it contains \"//\" (an empty folder name)."
		return "${error_code}"
	elif [[ "${user_home_path}" == *':'* ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Home folder \"${user_home_path}\" is not a valid path, it contains \":\" (not allowed by macOS)."
		return "${error_code}"
	elif [[ "${user_home_path//[^\/]/}" == '/' ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Home folder \"${user_home_path}\" is not a valid path, it cannot be a folder at the root of the volume."
		return "${error_code}"
	elif [[ "$(echo "${user_home_path}" | tr '[:upper:]' '[:lower:]')" == '/var/'* ]]; then
		# Replace "/var/" with "/private/var/" so that the home folder path is not a symlink path.
		# Don't worry about resolving other possible symlinks since that would be more tedious and this is the most common home folder location other than within "/Users/".

		user_home_path="/private/var/${user_home_path:5}"
	fi
	(( error_code ++ ))

	user_home_path_byte_length="$(echo -n "${user_home_path}" | wc -c)" # Use "wc -c" to properly count bytes instead of characters. And must pipe to "wc" with "echo -n" to not count a trailing line break character.
	user_home_path_byte_length="${user_home_path_byte_length// /}" # Remove the leading spaces that "wc -c" includes since this number could be printed in a sentence.
	if (( user_home_path_byte_length > 511 )); then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Home folder path too long, it must be 511 bytes or less. Specified home folder path is ${user_home_path_byte_length} bytes long. See \"--help\" for more information about this limitation."
		return "${error_code}"

		# Through testing, I found that the total home folder path length must be 511 BYTES or less (less than 512 bytes)
		# or "createhomedir" errors on GetSingleValueAttribute when retrieving NFSHomeDirectory even though the longer value exists.
		# When NOT creating the home folder via "createhomedir" and then logging in with a 512 byte home folder path for the home folder
		# to be created during login, login just hangs forever (presumably because home folder creation failed in the background).
		# So, must limit the total home folder path to 511 bytes or less so that "createhomedir" can always work and someone doesn't get hung forever during login.
	fi
	(( error_code ++ ))

	IFS='/'
	for this_user_home_path_folder_name in ${user_home_path}; do
		if (( $(echo -n "${this_user_home_path_folder_name}" | wc -c) > 255 )); then # Use "wc -c" to properly count bytes instead of characters. And must pipe to "wc" with "echo -n" to not count a trailing line break character.
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Some folder name in the specified home folder path is over the macOS maximum of 255 bytes."
			return "${error_code}"

			# No folder name in the home folder path can be over 255 bytes, as that is the macOS (HFS/APFS) max file/folder name limit.
		fi
	done
	unset IFS
	(( error_code ++ ))

	user_home_path_lowercased="$(echo "${user_home_path}" | tr '[:upper:]' '[:lower:]')"

	if [[ "${user_home_path_lowercased}" == '/users/guest' || "${user_home_path_lowercased}" == '/users/shared' ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Home folder \"${user_home_path}\" is a reserved by macOS."
		return "${error_code}"
	fi
	(( error_code ++ ))

	user_home_is_var_empty=false
	if [[ "${user_home_path_lowercased}" == '/private/var/empty' ]]; then # Except if the home folder is "/private/var/empty", then use the symlinked "/var/empty" to match macOS exactly for Role Accounts.
		user_home_path='/var/empty'
		user_home_is_var_empty=true
	fi

	user_home_is_dev_null=false
	if [[ "${user_home_path_lowercased}" == '/dev/null' ]]; then
		user_home_path='/dev/null' # Make sure "/dev/null" home is in the proper lowercased form even if it was entered with incorrect capitals.
		user_home_is_dev_null=true
	fi

	if $set_sharing_only_account; then
		if ! $user_home_is_dev_null; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Sharing Only Accounts must have their home folder set to \"/dev/null\". Change or remove the unusable \"--home\" option."
			return "${error_code}"
		fi

		if [[ -z "${user_shell}" ]]; then
			user_shell='/usr/bin/false'
		fi

		if [[ "$(echo "${user_shell}" | tr '[:upper:]' '[:lower:]')" != '/usr/bin/false' ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Sharing Only Accounts must have their login shell set to \"/usr/bin/false\". Change or remove the unusable \"--login-shell\" option."
			return "${error_code}"
		fi

		if $set_admin; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Sharing Only Accounts cannot be administrators. Change or remove the unusable \"--administrator\" option."
			return "${error_code}"
		fi

		if $set_prevent_secure_token_on_big_sur_and_newer; then # Sharing Only Accounts will always have Secure Token prevented on macOS 11 Big Sur and newer, but do not allow that to be set explicitly to avoid confusion that it could get a Secure Token if that's not set.
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Sharing Only Accounts will always have Secure Token prevented on macOS 11 Big Sur and newer. Remove the unnecessary \"--prevent-secure-token-on-big-sur-and-newer\" option."
			return "${error_code}"
		fi

		set_prevent_secure_token_on_big_sur_and_newer=true
	elif $set_role_account; then
		if [[ "${user_account_name}" != '_'* ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Role Accounts must have an account name that starts with an underscore (_)."
			return "${error_code}"
		fi

		if [[ -n "${user_uid}" ]] && (( user_uid < 200 || user_uid > 400 )); then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Role Accounts must have a User ID in the 200-400 range. Change or remove the unusable \"--user-id\" option."
			return "${error_code}"
		fi

		if ! $user_home_is_var_empty; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Role Accounts must have their home folder set to \"/var/empty\". Change or remove the unusable \"--home\" option."
			return "${error_code}"
		fi

		if [[ -z "${user_shell}" ]]; then
			user_shell='/usr/bin/false'
		fi

		if [[ "$(echo "${user_shell}" | tr '[:upper:]' '[:lower:]')" != '/usr/bin/false' ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Role Accounts must have their login shell set to \"/usr/bin/false\". Change or remove the unusable \"--login-shell\" option."
			return "${error_code}"
		fi

		if $set_admin; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Role Accounts cannot be administrators. Change or remove the unusable \"--administrator\" option."
			return "${error_code}"
		fi

		if $set_hidden_user; then # Role Accounts will always be set as hidden, but do not allow that to be set explicitly to avoid confusion that it won't be hidden if that's not set.
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Role Accounts will always be hidden. Remove the unnecessary \"--hidden\" option."
			return "${error_code}"
		fi

		set_hidden_user=true
	elif $set_service_account; then
		if [[ "${user_account_name}" != '_'* ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Service Accounts must have an account name that starts with an underscore (_)."
			return "${error_code}"
		fi

		if [[ "${user_home_path_lowercased}" == '/users/'* ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Service Accounts cannot have their home folder within the \"/Users/\" folder. Change or remove the unusable \"--home\" option."
			return "${error_code}"
		fi

		if [[ -z "${user_gid}" ]]; then
			user_gid='-2' # Service Accounts can have any gid, but default to "-2" (nobody group).
		fi

		if [[ -z "${user_shell}" ]]; then
			user_shell='/usr/bin/false' # Service Accounts can have other shells, but default to "/usr/bin/false".
		fi

		if [[ -z "${user_password}" ]]; then
			user_password='*'
		fi

		if [[ "${user_password}" != '*' ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Service Accounts must have NO password. Change or remove the unusable \"--password\" option."
			return "${error_code}"
		fi

		if $set_no_picture; then # Service Accounts will always have NO picture, but do not allow that to be set explicitly to avoid confusion that it will have a picture if that's not set.
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Service Accounts will always have NO picture. Remove the unnecessary \"--no-picture\" option."
			return "${error_code}"
		fi

		if [[ -z "${user_picture_path}" ]]; then
			set_no_picture=true
		fi

		if ! $set_no_picture; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Service Accounts must have NO picture. Remove the unusable \"--picture\" option."
			return "${error_code}"
		fi

		if $set_admin; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Service Accounts cannot be administrators. Change or remove the unusable \"--administrator\" option."
			return "${error_code}"
		fi

		if $set_hidden_user; then # Service Accounts will always be hidden (because of having "*" password set), but do not allow that to be set explicitly to avoid confusion that it won't be hidden if that's not set.
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Service Accounts will always be hidden. Remove the unnecessary \"--hide\" option."
			return "${error_code}"
		fi

		# User password and picture changes will always be prohibited for Service Accounts since they will not have any "_writers_" attributes. These are just being set for accurate display in "--check-only" output.
		set_prohibit_user_password_changes=true
		set_prohibit_user_picture_changes=true
	fi
	(( error_code ++ ))

	if $do_not_create_home_folder || $user_home_is_var_empty || $user_home_is_dev_null; then
		if $set_hidden_home; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Cannot hide home folder $($do_not_create_home_folder && echo 'while specifying "--do-not-create-home-folder"' || echo "when set to \"$($user_home_is_var_empty && echo '/var/empty' || echo '/dev/null')\""). If you want to only hide the user, specify \"--hide userOnly\" instead or remove the option."
			return "${error_code}"
		elif $skip_setup_assistant_on_first_login; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Cannot skip first login Setup Assistant $($do_not_create_home_folder && echo 'while specifying "--do-not-create-home-folder"' || echo "when home folder is set to \"$($user_home_is_var_empty && echo '/var/empty' || echo '/dev/null')\""). If you want to only skip first boot Setup Assistant, specify \"--skip-setup-assistant firstBootOnly\" instead or remove the option."
			return "${error_code}"
		elif $do_not_share_public_folder; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Public folder will not be shared $($do_not_create_home_folder && echo 'while specifying "--do-not-create-home-folder"' || echo "when home folder is set to \"$($user_home_is_var_empty && echo '/var/empty' || echo '/dev/null')\""). Remove the unnecessary \"--do-not-share-public-folder\" option."
			return "${error_code}"
		fi

		do_not_share_public_folder=true # Public folder will never be shared for these home folder options. This is just being set for accurate display in "--check-only" output.
	fi
	(( error_code ++ ))

	if [[ -n "${user_shell}" ]]; then
		if [[ ! -f "${user_shell}" ]]; then
			if possible_user_shell="$(which "${user_shell}" 2> /dev/null)"; then
				user_shell="${possible_user_shell}" # Use "which" to allow user_shell to be specified by command name such as "bash" or "zsh" instead of only the actual full path.
			else
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified login shell file \"${user_shell}\" does not exist."
				return "${error_code}"
			fi
		fi

		if [[ ! -x "${user_shell}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified login shell file \"${user_shell}\" is not executable."
			return "${error_code}"
		fi

		# When creating a package, doing this user_shell check here could give a false error if the login shell does not exist on the current system but will exist on the deployed system.
		# But, that is not a typical scenario and it's safer for most typical packaging to make sure the login shell is a valid executable that should exist on any system by default.
		# When creating a user immediately (not creating a package), it doesn't matter either way whether this is checked here or lower down.
	fi
	(( error_code ++ ))

	user_shell_lowercased="$(echo "${user_shell}" | tr '[:upper:]' '[:lower:]')"

	user_shell_is_false=false
	if [[ "${user_shell_lowercased}" == '/usr/bin/false' ]]; then
		user_shell='/usr/bin/false' # Make sure "/usr/bin/false" login shell is in the proper lowercased form even if it was entered with incorrect capitals.
		user_shell_is_false=true
	fi

	if [[ -z "${user_shell}" ]]; then
		if $make_package || (( darwin_major_version < 19 )); then
			user_shell_byte_length='9' # Default of "/bin/bash" is 9 bytes.

			# When making a package with no shell specified that could be installed on any version of macOS, we must always reserve 9 bytes for "/bin/bash" instead of 8 needed for "/bin/zsh".
		else
			user_shell_byte_length='8' # Default of "/bin/zsh" is 8 bytes.
		fi
	else
		if ! $user_shell_is_false && ! grep -qxF "${user_shell_lowercased}" '/etc/shells'; then
			>&2 echo "mkuser WARNING: Specified login shell file \"${user_shell}\" is not listed as an approved shell in the \"/etc/shells\" file. The specified login shell will still be set, but be aware that this may result in this user account not behaving properly or as expected in all situations."
		fi

		user_shell_byte_length="$(echo -n "${user_shell}" | wc -c)" # Use "wc -c" to properly count bytes instead of characters. And must pipe to "wc" with "echo -n" to not count a trailing line break character.
		user_shell_byte_length="${user_shell_byte_length// /}" # Remove the leading spaces that "wc -c" includes since this number could be printed in a sentence.

		# The user_shell cannot be longer than 1023 bytes since that is the macOS full path length limit.
		# But, we don't actually need to check that explicitly since we've previously checked that the file exists and files cannot exist with longer paths than 1023 bytes.
		# Also, a user_shell of 1023 bytes would not be allowed anyway since it would surpass the combined 1010 byte limit that is checked next.
	fi

	user_full_name_byte_length="$(echo -n "${user_full_name}" | wc -c)" # Use "wc -c" to properly count bytes instead of characters. And must pipe to "wc" with "echo -n" to not count a trailing line break character.
	user_full_name_byte_length="${user_full_name_byte_length// /}" # Remove the leading spaces that "wc -c" includes since this number could be printed in a sentence.

	critical_combined_byte_length_difference="$(( (${#user_account_name} + user_full_name_byte_length + user_shell_byte_length + user_home_path_byte_length) - 1010 ))" # Get the difference right away to only need to do math once since it will be used in the error if the limit is hit.
	if (( critical_combined_byte_length_difference > 0 )); then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Combined byte length of account name, full name, login shell, and home path must be 1010 bytes or less.
  Specified account name is ${#user_account_name} bytes long.
  Specified full name is ${user_full_name_byte_length} bytes long.
  Specified login shell is ${user_shell_byte_length} bytes long.
  Specified home folder path is ${user_home_path_byte_length} bytes long.
  You must adjust these parameters to remove ${critical_combined_byte_length_difference} byte$( (( critical_combined_byte_length_difference != 1 )) && echo 's') to fit within the combined 1010 byte limit.
  See \"--help\" for more information about this limitation."
		return "${error_code}"

		# System Preferences does not allow full names to be over 83 characters.
		# When testing throught trial-and-error to see if there is an actual length limit for the full name, I noticed two things.
		# First, after a certain point the full name would no longer show in the "Log Out" menu item of the "Apple" menu.
		# Second, with an even longer full name the user could no longer login via login window and the "login" or "su" commands.
		# Through trying to find the exact full name length limits for these issues I started noticing inconsistent behavior and eventually realized that these issues were not hit exclusively because of the length of the full name.
		# Instead these issues were hit when the COMBINED length of the account name, full name, home folder path, and login shell TOGETHER got longer than a certain amount of bytes.
		# I confirmed that these limitation are just because of these 4 attibutes by adding other longer attributes when these 4 attributes were at the combined maximum which did not break it,
		# and also deleting all other attributes when these 4 attributes were just just 1 byte over their combined maximum which did not fix it.

		# Through testing on macOS 10.13 High Sierra and macOS 11 Big Sur, I found that this combined length of these 4 attributes must be 1010 bytes or less for the full name to show in the "Log Out" menu item of the "Apple" menu.
		# If the combined length of these 4 attributes is over than 1010 bytes, the user account still seems to work otherwise, but only "Log Out …" is shown in the "Apple" menu with no full name shown.
		# My assumption here is that something internal and static is taking up another 13 or 14 bytes making the actual limit be 1023 or 1024 bytes since these limitations usually fall on or one byte below a base 2 byte range.

		# On both macOS 10.13 High Sierra and macOS 11 Big Sur, the user seems to work properly like this until the combined length of these 4 attibutes together goes over 2034 bytes.
		# If the combined length of these 4 attributes is over than 2034 bytes, the user will fail to login via login window and the "login" or "su" commands.
		# When watching the console when the "login" command fails, the errors are "login (libpam.2.dylib): in pam_sm_acct_mgmt(): OpenDirectory - Unable to get pwd record." and "login: pam_acct_mgmt(): unknown user".
		# And the "su" errors are "su (libpam.2.dylib): in pam_sm_acct_mgmt(): Unable to obtain the username." and "su (libpam.2.dylib): in pam_sm_acct_mgmt(): OpenDirectory - Unable to get pwd record." and "su: pam_acct_mgmt: authentication error".
		# When attempting to login at the login window when the combined length of these 4 attributes is over than 2034 bytes, the password field just shakes as if the password is wrong, but I'm assuming the same "libpam" error is getting hit.
		# When tested with FileVault and Recovery authentication, the combined length of these 4 attributes being over 2034 bytes was not an issue. After successful FileVault login, the non-FileVault login window would get hit since actual login still failed. And there seemed to be no issues unlocking in Recovery.
		# As with the 1010 byte limit, my assumption is something is taking the same 13 or 14 bytes making this actual limit be 2047 or 2048 bytes since these limitations usually fall on or one byte below a base 2 byte range.

		# Regardless of this issue logging in the combined length of these 4 attributes is over than 2034 bytes, we want to make 100% fully functional accounts.
		# While the full name not showing the "Log Out" menu item of the "Apple" menu is not a serious issue, it does indicate a bug or limitation within some part of macOS that we do not want to trigger.
		# Therefore, the combined length of these 4 attributes is set to a maximum to 1010 bytes.

		# Also, full names being over 226 bytes is an issue when used in a SharePoint RecordName, which would make the SharePoint RecordName over 244 byte max.
		# In this case the SharePoint RecordName will be truncated, see more info in SharePoint creation code below.
	fi

	if [[ -n "${user_picture_path}" ]]; then
		if [[ ! -f "${user_picture_path}" ]]; then
			# Use "find" to allow user_picture_path to be specified by default user picture filename (with or without the file extension) such as "Earth" or "Penguin.tif" instead of only the full path.
			possible_user_picture_path="$(find '/Library/User Pictures' -type f \( -iname "${user_picture_path}.*" -or -iname "${user_picture_path}" \) 2> /dev/null | head -1)" # Only use first match (just in case, but there should only ever be one match with this search criteria and default picture filenames).

			if [[ -f "${possible_user_picture_path}" ]]; then
				user_picture_path="${possible_user_picture_path}"
			else
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified $([[ "${user_picture_path}" == *'/'* ]] && echo 'picture path' || echo 'default picture name') \"${user_picture_path}\" does not exist."
				return "${error_code}"
			fi
		fi

		if (( $(stat -f '%z' "${user_picture_path}") > 1000000 )); then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified picture file \"${user_picture_path}\" is over 1 MB. Choose or create a smaller picture file."
			return "${error_code}"

			# Do not try to set picture that is over 1 MB (and exit with error).
			# This check was inspired by code shared by Simon Andersen: https://macadmins.slack.com/archives/C07MGJ2SD/p1621271235165000?thread_ts=1621186749.143600&cid=C07MGJ2SD
			# But, much larger pictures DIDN'T appear to have any obvious issues during some *very minimal* testing (tested with up to 138 MB heic desktop pictures).
			# Still, limiting the user picture to a reasonable 1 MB seems to be a wise practice as all the default user pictures are under 1 MB (the largest being 850 KB).
		else
			user_picture_file_type="$(file -bI "${user_picture_path}" 2> /dev/null | cut -d ';' -f 1)"

			if [[ "${user_picture_file_type}" != 'image/'* ]]; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified picture file \"${user_picture_path}\" is not an image (file type is \"${user_picture_file_type:-UNKNOWN}\")."
				return "${error_code}"
			fi
		fi
	fi
	(( error_code ++ ))

	if $set_auto_login; then
		if $user_shell_is_false; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Cannot set auto-login when the login shell is set to \"/usr/bin/false\" since this user will not be able to be logged into. Remove the unusable \"--auto-login\" option."
			return "${error_code}"
		elif [[ "${user_password}" == '*' ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Cannot set auto-login while specifying \"--no-password\" (or \"--password '*'\"). Remove the unusable \"--auto-login\" option."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if $user_home_is_var_empty || $user_home_is_dev_null; then
		if ! $user_shell_is_false; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Cannot set home folder to \"$($user_home_is_var_empty && echo '/var/empty' || echo '/dev/null')\" UNLESS ALSO specifying \"--prevent-login\" (or \"--login-shell /usr/bin/false\") since this user will not be able to be logged into."
			return "${error_code}"
		elif $do_not_create_home_folder; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: The home folder is set to the special \"$($user_home_is_var_empty && echo '/var/empty' || echo '/dev/null')\" folder. Remove the invalid \"--do-not-create-home-folder\" for this case."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if [[ -n "${st_admin_account_name}" ]]; then
		# Check that Secure Token admin exist BEFORE prompting for Secure Token admin password so that it's not needlessly prompted if the specified Secure Token admin doesn't exist.

		if ! $boot_volume_is_apfs && ! $make_package; then # Secure Token can only be granted if boot volume is APFS (but still check if making a package since it could be run on another system).
			>&2 echo 'mkuser WARNING: IGNORING "--secure-token-admin-account-name" since Secure Tokens are an APFS feature and the boot volume is not formatted as APFS.'
			st_admin_account_name='' # Clear specified st_admin_account_name so that Secure Token granting code during user creation will never be run.
		elif $set_prevent_secure_token_on_big_sur_and_newer; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Cannot specify \"--secure-token-admin-account-name\" to grant the new user a Secure Token while specifying \"--prevent-secure-token-on-big-sur-and-newer\". Remove one or the other of these options."
			return "${error_code}"
		elif [[ "${st_admin_account_name}" == "${user_account_name}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified Secure Token admin \"${st_admin_account_name}\" cannot be same as the new user \"--account-name\"."
			return "${error_code}"
		elif ! $make_package; then # Only check that the Secure Token admin exists if not making a package which may run on another system.
			if ! dscl . -read "/Users/${st_admin_account_name}" RecordName &> /dev/null; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified Secure Token admin \"${st_admin_account_name}\" does not exist."
				return "${error_code}"
			elif [[ "$(dsmemberutil checkmembership -U "${st_admin_account_name}" -G 'admin' 2> /dev/null)" != 'user is a member of the group' ]]; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified Secure Token admin \"${st_admin_account_name}\" is not an administrator."
				return "${error_code}"
			fi

			# DO NOT check if the specified Secure Token admin has a Secure Token YET in case we're running on macOS 10.15 Catalina and they are the first admin created which may not have been granted the first Secure Token yet.
			# In this case on macOS 10.15 Catalina, the first admin will be granted the first Secure Token AFTER their password is verified below (using native "OpenDirectory" methods).
			# So, we will confirm that they have a Secure Token AFTER their password has been verified to allow for the situation on macOS 10.15 Catalina where multiple users are being created by mkuser before going through Setup Assistant
			# and all of them are intended to get Secure Tokens from the first admin created by mkuser (which, again, will not get the first Secure Token on macOS 10.15 Catalina until after their first authentication).
		fi
	fi
	(( error_code ++ ))

	if $prompt_for_st_admin_password && [[ "${user_password}" != '*' ]]; then # Do not prompt for ST admin password if NO USER PASSWORD is set since that will error below anyways.
		if ! $boot_volume_is_apfs && ! $make_package; then # Secure Token can only be granted if boot volume is APFS (but still prompt if making a package since it could be run on another system).
			>&2 echo 'mkuser WARNING: NOT prompting for Secure Token admin password since Secure Tokens are an APFS feature and the boot volume is not formatted as APFS.'
		elif $has_invalid_options; then
			>&2 echo 'mkuser WARNING: NOT prompting for Secure Token admin password since INVALID OPTIONS OR PARAMETERS are specified and user would not be created anyway.'
		elif $did_get_password_from_stdin; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: CANNOT prompt for Secure Token admin password since user password was passed via stdin. Use another option to specify the user password or the Secure Token admin password. See \"--help\" for more information about this limitation."
			return "${error_code}"
		elif [[ -n "${st_admin_password}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Invalid duplicate \"--secure-token-admin-password-prompt\" option because \"--secure-token-admin-password\" or \"--fd3-secure-token-admin-password\" has already been specified."
			return "${error_code}"
		elif [[ -z "${st_admin_account_name}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: CANNOT prompt for Secure Token admin password since \"--secure-token-admin-account-name\" is not specified."
			return "${error_code}"
		else
			echo -en "\nSpecify Password for Secure Token Admin \"${st_admin_account_name}\": "
			read -rs prompted_st_admin_password

			echo -en "\nConfirm Password for Secure Token Admin \"${st_admin_account_name}\": "
			read -rs confirmed_prompted_st_admin_password

			echo -e '\n'

			if [[ "${prompted_st_admin_password}" == "${confirmed_prompted_st_admin_password}" ]]; then
				# I don't believe it's possible to include line breaks within a prompt like this, so we don't need to check for them to be disallowed.
				st_admin_password="${prompted_st_admin_password}"
			else
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified Secure Token admin \"${st_admin_account_name}\" passwords did not match."
				return "${error_code}"
			fi
		fi
	fi
	(( error_code ++ ))

	# THIS mkuser_verify_password FUNCTION WILL BE USED TO VERIFY THE SECURE TOKEN ADMIN PASSWORD NOW, AS WELL AS THE NEW USERS PASSWORD AFTER USER CREATION.
	mkuser_verify_password() { # $1 = Account Name, $2 = Password
		if [[ -z "$1" ]]; then # $2 (password) can be an empty string.
			>&2 echo 'Verify Password ERROR: An account name must be specified.'
			return 1
		fi

		# If the password is verified to be correct for the specified account name, the string "VERIFIED" will be returned (via stdout) with an exit code of 0.
		# If the password is not correct for the specified account name (or the account name doesn't exist), an error message will be returned (via stderr) with an exit code of 1.

		# Since the encoded password is placed directly within a shell string that is piped to "osascript" and then is only ever passed to native Objective-C methods,
		# the password is handled as securely as possible and is never visible in the process list. See "password ($2)" comments below about the security considerations of this process.

		# Unlike other secure password verification technique, this technique does not have any (known) length or character limitations (for example, "expect" does not support emoji and would fail to verify them in a password).
		# See the old "mkuser" code for more information about length limitations and the much more complex code that was required before: https://github.com/freegeek-pdx/mkuser/blob/552933a6f06daa43c5c9cf4a1c3a813a838a1d82/mkuser.sh#L2660
		# This password verification technique was tested with passwords up to 1,000,000 bytes long (didn't bother testing longer) and with multibyte characters (including emoji) in the password.
		# I've also tested and confirmed that this native password verification is an authentication which triggers macOS to grant the first Secure Token to the first user to authenticate with a UID of 500 or greater on macOS 10.13 High Sierra and macOS 10.14 Mojave,
		# and to the first admin to authenticate on macOS 10.15 Catalina (just like "dscl . -authonly" does). On newer versions of macOS, the first Secure Token is granted earlier when the users password is set rather than the first authentication.

		# The account name ($1) is passed to "osascript" as a command specific environment variable to that no special characters need to be escaped.
		# See https://paulgalow.com/how-to-work-with-json-api-data-in-macos-shell-scripts for more information about this technique and how it avoids
		# the possibility of any intentionally malicious code being able to be executed as well as avoids needing to escape any special characters.
		# Even though valid account names should never contain characters that need to be escaped, it is still user input and all of the same
		# security precautions in the blog post apply to handling user input so the code doesn't break if invalid account names are specified.

		# The password ($2) is also user input, and could also contain special characters that would need to be escaped if the string were placed directly in JXA code.
		# The password could be passed to "osascript" as an environment variable and then retrieved within JXA like the account name is, but environment variables are always visible
		# for running processes using "ps -E" on macOS 10.15 Catalina and older. But, on macOS 11 Big Sur and newer the environment variables are only visible if SIP is disabled.
		# Since this code is tested to support macOS 10.13 High Sierra and newer, environment variables should not be considered a secure way to pass sensitive data, they are
		# essentially as secure as passing data directly in the arguments of a command, which is not secure at all since they are always visible in the process list.
		# But, the password has to be passed to or placed in this code somehow, so I investigated the security of all the different ways to pass stdin to processes by using "lsof -p <PID>"
		# to observe the files associated with a process and found that here-docs and here-strings both create regular temporary files within "/private/var/tmp/" in both bash and zsh.
		# Even though these files existed so briefly that I could never read the contents of them, they did contain the contents of the data passed to stdin via here-doc or here-string
		# (which I confirmed by matching the filesize shown in "lsof" with the known size of the data being passed).
		# The only other way to pass data via stdin is by using "echo" and a pipe "|". By observing the output of "lsof -p <PID>" when piping code to "osascript",
		# I found that piped data is NOT created in the filesystem and exists only as a special "PIPE" type and is NOT a regular file with a node number and path in the filesystem.
		# Since "echo" is a builtin in bash and zsh and not an external binary command, the "echo" command containing the script as an argument is also never visible in the process list.
		# Therefore, I am considering echoing and piping to be the most secure way to pass senstive data to other processes.
		# That means the password must be placed directly in the JXA code that will be piped to the "osascript" command.
		# To avoid all possible issues (such as special character escaping and malicious code execution) when placing a raw user input string directly within the JXA code,
		# the password string is first base64 encoded *in the shell* and then the base64 encoded string is placed directly in the JXA code.
		# This is done using "$(echo -nE "$2" | base64)", and since "echo" is a builtin in bash and zsh the password will not be visible in the process list for that command
		# (the "-E" option of "echo" is used to be sure backslashes are never interpreted if run in zsh with default options since this password verification function may be used by others).
		# Since only the base64 encoded string is placed directly within the JXA code, there is no way the base64 string itself can contain any special characters or intentionally malicious JXA code.
		# This base64 string is then decoded from into the actual password within JXA by Objective-C methods, which also never reveals the base64 string or the decoded password in the process list.
		# Since that base64 string is decoded by Objective-C methods, it is returned as an NSString object which can never be interpreted as code, and no special characters within it need to be escaped.

		local base64_encoded_password
		base64_encoded_password="$(echo -nE "$2" | base64)"

		# Since the "base64_encoded_password" shell variable is placed within the contents of a double quoted shell string all special shell characters need to be avoided or escaped.
		# I have chose to avoid the special shell characters instead of needing to use backslashes to escape them throughout this code (since it's is accidentally miss a necessary escape).
		# Therefore, "ObjC.wrap()" is always used instead of the "$()" alias so that the later is not misinterpreted as command substitution.
		# Also, JavaScript backticks "`" are never used for template literal strings for the same reason, and the
		# "${var}" syntax for variables in template literal string would also be misinterpreted as shell variables.
		# Finally, all double quotes within JavaScript strings do need to be escaped to not prematurely close the shell string containing the whole script.
		# These considerations could have been avoided by passing the password as an environment variables as described above, but since
		# that is NOT secure, and this code is simple, it was not hard to avoid the JXA and JavaScript syntax that conflicts with shell code.

		local verify_password_result # See comments above about the security importance of using echo and pipe (which seems sloppy) instead of a here-doc (which seems cleaner) to pass this JXA code to "osascript".
		verify_password_result="$(echo "
ObjC.import('OpenDirectory') // 'Foundation' framework is available in JXA by default, but need to import 'OpenDirectory' framework manually (for the required password verification methods):
// https://developer.apple.com/library/archive/releasenotes/InterapplicationCommunication/RN-JavaScriptForAutomation/Articles/OSX10-10.html#//apple_ref/doc/uid/TP40014508-CH109-SW18

let accountName = $.NSProcessInfo.processInfo.environment.objectForKey('OSASCRIPT_ENV_ACCOUNT_NAME')
let password = $.NSString.alloc.initWithDataEncoding($.NSData.alloc.initWithBase64EncodedStringOptions('${base64_encoded_password}', 0), $.NSUTF8StringEncoding)

// Code in Apple's open source OpenDirectory 'TestApp.m' contains useful examples for the following OpenDirectory methods used: https://opensource.apple.com/source/OpenDirectory/OpenDirectory-146/Tests/TestApp.m.auto.html

let odSearchNodeError = ObjC.wrap() // Create a 'nil' object which will be set to any NSError: https://developer.apple.com/library/archive/releasenotes/InterapplicationCommunication/RN-JavaScriptForAutomation/Articles/OSX10-10.html#//apple_ref/doc/uid/TP40014508-CH109-SW27
let odSearchNode = $.ODNode.nodeWithSessionTypeError($.ODSession.defaultSession, $.kODNodeTypeAuthentication, odSearchNodeError) // https://developer.apple.com/documentation/opendirectory/odnode/1569410-nodewithsession?language=objc

let verifyPasswordResult = 'Verify Password (Load Node) ERROR: Unknown error loading OpenDirectory \"/Search\" node.'

if (!odSearchNode.isNil() && odSearchNode.nodeName.js == '/Search') {
	let odUserRecordError = ObjC.wrap()
	let odUserRecord = odSearchNode.recordWithRecordTypeNameAttributesError($.kODRecordTypeUsers, accountName, ObjC.wrap(), odUserRecordError) // https://developer.apple.com/documentation/opendirectory/odnode/1428065-recordwithrecordtype?language=objc

	if (!odUserRecord.isNil() && odUserRecord.recordName.js == accountName.js) {
		let odVerifyPasswordError = ObjC.wrap()
		let odPasswordVerified = odUserRecord.verifyPasswordError(password, odVerifyPasswordError) // https://developer.apple.com/documentation/opendirectory/odrecord/1427894-verifypassword?language=objc

		if (odPasswordVerified === true) { // Make sure odPasswordVerified is a boolean of true and no other truthy value.
			verifyPasswordResult = 'VERIFIED'
		} else if (!odVerifyPasswordError.isNil() && odVerifyPasswordError.localizedDescription) {
			verifyPasswordResult = 'Verify Password ERROR: ' + odVerifyPasswordError.localizedDescription.js + ' (Error Code: ' + odVerifyPasswordError.code + ')'
		} else {
			verifyPasswordResult = 'Verify Password ERROR: Unknown error verifying password.'
		}
	} else if (!odUserRecordError.isNil() && odUserRecordError.localizedDescription) {
		verifyPasswordResult = 'Verify Password (Load Record) ERROR: ' + odUserRecordError.localizedDescription.js + ' (Error Code: ' + odUserRecordError.code + ')'
	} else {
		verifyPasswordResult = 'Verify Password (Load Record) ERROR: OpenDirectory RecordName (user account name \"' + accountName.js + '\") does not exist.'
	}
} else if (!odSearchNodeError.isNil() && odSearchNodeError.localizedDescription) {
	verifyPasswordResult = 'Verify Password (Load Node) ERROR: ' + odSearchNodeError.localizedDescription.js + ' (Error Code: ' + odSearchNodeError.code + ')'
}

// DO NOT 'console.log()' the result since that will go to stderr which is being redirected to '/dev/null' so that only our result string is ever retrieved via stdout.
// This is because I have seen an irrelevant error about failing to establish a connection to the WindowServer (on macOS 10.13 High Sierra at least) that could be
// included in stderr even when password verification was successful which would mess up checking for the exact success string if we were to capture stderr in the output.

verifyPasswordResult // Just having 'verifyPasswordResult' as the last statement will make JXA send the value to stdout.
" | OSASCRIPT_ENV_ACCOUNT_NAME="$1" osascript -l 'JavaScript' 2> /dev/null)"

		if [[ "${verify_password_result}" == 'VERIFIED' ]]; then
			echo "${verify_password_result}"
			return 0
		elif [[ -z "${verify_password_result}" ]]; then
			verify_password_result='Verify Password ERROR: Unknown error occurred.'
		fi

		>&2 echo "${verify_password_result}"
		return 1
	}

	if $boot_volume_is_apfs || $make_package; then  # Secure Token can only be granted if boot volume is APFS (but still check if making a package since it could be run on another system).
		if [[ -n "${st_admin_account_name}" ]]; then
			st_admin_password_byte_length="$(echo -n "${st_admin_password}" | wc -c)" # Use "wc -c" to properly count bytes instead of characters. And must pipe to "wc" with "echo -n" to not count a trailing line break character.
			st_admin_password_byte_length="${st_admin_password_byte_length// /}" # Remove the leading spaces that "wc -c" includes since this number could be printed in a sentence.

			if [[ "${user_password}" == '*' ]]; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Cannot specify \"--secure-token-admin-account-name\" to grant the new user a Secure Token while specifying \"--no-password\" (or \"--password '*'\"). You must specify a user password to be able to grant the new user a Secure Token."
				return "${error_code}"
			elif [[ -n "${st_admin_password}" ]] && (( ${#st_admin_password} < 4 )); then # A Secure Token admin passwords could be blank, but it will be verified below before continuing.
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Password for Secure Token admin \"${st_admin_account_name}\" is too short, it must be at least 4 characters or blank/empty password."
				return "${error_code}"
			elif (( st_admin_password_byte_length > 1022 )); then # Search "1022 bytes" in this code for more information about this limitation.
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Password for Secure Token admin \"${st_admin_account_name}\" is too long, it must be 1022 bytes or less to be able to SECURELY grant the new user a Secure Token. Specified Secure Token admin password is ${st_admin_password_byte_length} bytes long. Specify a Secure Token admin with a shorter password or remove the unusable Secure Token granting options. See \"--help\" for more information about this limitation."
				return "${error_code}"
			elif ( ! $IS_PACKAGE || ! $check_only ) && ! $make_package; then
				# Do not check Secure Token admin password when only doing the initial check from a package or when creating a package (since the admin may not exist on this system).
				if ! verify_st_admin_password_result="$(mkuser_verify_password "${st_admin_account_name}" "${st_admin_password}" 2>&1)" || [[ "${verify_st_admin_password_result}" != 'VERIFIED' ]]; then
					>&2 echo "${verify_st_admin_password_result}"
					>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Password verification failed for Secure Token admin \"${st_admin_account_name}\"."
					return "${error_code}"
				fi

				# Make sure the specified Secure Token admin has a Secure Token AFTER the password has been verified (the reasons for this are described the comments above in the first round of st_admin_account_name checks).
				if [[ "$(sysadminctl -secureTokenStatus "${st_admin_account_name}" 2>&1)" != *'is ENABLED for'* || "$(diskutil apfs listUsers / 2> /dev/null)" != *$'\n'"+-- $(PlistBuddy -c 'Print :dsAttrTypeStandard\:GeneratedUID:0' /dev/stdin <<< "$(dscl -plist . -read "/Users/${st_admin_account_name}" GeneratedUID 2> /dev/null)" 2> /dev/null)"$'\n'* ]]; then # DO NOT bother also checking "fdesetup list" since that requires running as root and these checks are thorough enough and could happen before running as root.
					>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Specified Secure Token admin \"${st_admin_account_name}\" does not have a Secure Token."
					return "${error_code}"
				fi
			fi
		elif [[ -n "${st_admin_password}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: You must specify \"--secure-token-admin-account-name\" along with the Secure Token admin password."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if ! $set_sharing_only_account && $user_shell_is_false && $user_home_is_dev_null && ! $set_admin && ( $set_prevent_secure_token_on_big_sur_and_newer || (( darwin_major_version < 20 )) ); then
		set_sharing_only_account=true

		# Make set_sharing_only_account "true" if it wasn't set explicitly but all other explicitly set criteria match a Sharing Only Accounts so that the creating_user_type display is correct.
		# After this point in the code, set_sharing_only_account is unused otherwise.
	fi

	if ! $set_role_account && [[ "${user_account_name}" == '_'* && -n "${user_uid}" ]] && (( user_uid >= 200 && user_uid <= 400 )) && $user_shell_is_false && $user_home_is_var_empty && ! $set_admin && $set_hidden_user; then
		set_role_account=true

		# Make set_role_account "true" if it wasn't set explicitly but all other explicitly set criteria match a Role Account so that the creating_user_type display is correct.
		# After this point in the code, set_role_account is unused otherwise, except if there was no UID set and a UID starting from 200 would be dynamically assigned,
		# but that situation will not get within this condition since the UID would have to be manually selected to get here.
	fi

	# DO NOT make set_service_account "true" based on other criteria if it wasn't set explicitly since it does things (such as no "_writers_" attributes) that cannot be set explicitly otherwise.

	if $set_sharing_only_account; then
		creating_user_type='Sharing Only Account'
	elif $set_role_account; then
		creating_user_type="$([[ -n "${st_admin_account_name}" ]] && echo 'Secure Token ')Role Account"
	elif $set_service_account; then
		creating_user_type='Service Account'
	else
		if $set_hidden_user; then creating_user_type='Hidden '; fi
		if [[ -n "${st_admin_account_name}" ]]; then creating_user_type+='Secure Token '; fi
		creating_user_type+="$($set_admin && echo 'Admin ' || echo 'Standard ')"
		if $set_auto_login; then creating_user_type+='Auto-Login '; fi
		creating_user_type+='User'
	fi

	user_full_and_account_name_display="\"${user_full_name}\"$([[ "${user_full_name}" != "${user_account_name}" ]] && echo " (${user_account_name})")"

	# The following subshell_function_pid will be used for "caffeinate" right now as well as "shlock" later on.
	subshell_function_pid="$(bash -c 'echo "$PPID"')" # Must do this silly thing to be able to get the PID of the *subshell function* rather than the parent script in case this function is included in a larger script that we do not want to "caffeinate" for the entire run or "shlock" on the wrong PID.

	caffeinate -dimsu -w "${subshell_function_pid}" & # Use "caffeinate" to keep computer awake while the user is being created. The user creation should always be pretty quick, but this doesn't hurt.

	# <MKUSER-BEGIN-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!
	if $make_package; then
		# SAVE A USER CREATION PACKAGE (IF SPECIFIED)
		# The checks after this point will be done during actual user creation (when the package is being installed) since they are specific to the installation system.
		# Also, packages can be made without running as root so only check root if not making a package or during package installation.
		# When a package is made, all of options to create the package will be used to create the user, except the packaging options will be removed (so that it creates a user instead of making another package),
		# and the picture file will be stored within the package and the option will be updated to point to the location the picture will be extracted to.
		# Also, the passwords will be obfuscated (see below for more information about passwords obfuscation).

		if $IS_PACKAGE; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Not creating package since this is running from a package (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)."
			return "${error_code}"
		elif $has_invalid_options; then # DO NOT make package if invalid options are specified that could create a user with possibly unintended settings.
			>&2 echo "
mkuser ERROR ${error_code}-${LINENO}: NOT creating package since INVALID OPTIONS OR PARAMETERS were specified.
Check ERRORS and correct the invalid options or parameters to make a user creation package.
Check \"--help\" for detailed information about each available option."
			return "${error_code}"
		fi

		if [[ -z "${pkg_identifier}" ]]; then
			pkg_identifier="mkuser.pkg.${user_account_name:0:237}" # Truncate account name to 237 characters since it could be up to 244 characters which would go over the 248 character package identifier limit described below.
		elif (( ${#pkg_identifier} > 248 )); then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Package identifier must be 248 characters or less. Specified package identifier is ${#pkg_identifier} characters long. See \"--help\" for more information about this limitation."
			return "${error_code}"

			# If the package identifier is over 248 bytes, both the "installer" command and "Installer" app fail with "An error occurred while extracting files from the package".
			# This is because the package "postinstall" is extracted into a folder named with the bundle identifier and appended with a period and then like 6 random characters like ".PevFY4".
			# If the bundle identifier if over 248 bytes, that would make this resulting folder name over the macOS 255 byte maximum.
			# This folder name suffix was confirmed on macOS 10.13 High Sierra, macOS 10.14 Mojave, and macOS 11 Big Sur so far.
			# This folder name suffix appears to be the same regardless of if the package is installed via "installer" command or "Installer" app or "startosinstall --installpackage".
		fi

		if [[ -z "${pkg_version}" ]]; then pkg_version="$(date '+%Y.%-m.%-d')"; fi # https://strftime.org

		if ! $suppress_status_messages; then
			echo "mkuser: Creating ${creating_user_type} ${user_full_and_account_name_display} User Creation Package: ${pkg_identifier} (version ${pkg_version})..."
		fi

		if [[ ! -f "${BASH_SOURCE[0]}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Failed to retrieve source of this script for package postinstall (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)."
			return "${error_code}"
		fi

		# Extract only the mkuser function from this source file for use in the package scripts.
		# NOTICE: Empty lines and lines that are only comments as well as blocks of code between "<MKUSER-BEGIN-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT>" and "<MKUSER-END-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT>" markers
		# are removed from the source for the package scripts since they are not necessary for package installation and removing it all makes the package reasonably smaller.
		mkuser_function_source_for_package="$(awk '
($1 == "mkuser()" || $2 == "<MKUSER-END-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT>") {
	print_mkuser_function = 1
}
($2 == "<MKUSER-BEGIN-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT>") {
	print_mkuser_function = 0
}
print_mkuser_function {
	if ($0 != "" && $1 != "#") {
		if (($1 == "readonly") && ($2 == "IS_PACKAGE=false")) {
			print "\treadonly IS_PACKAGE=true # CODE MODIFIED FOR PACKAGE INSTALLATION"
		} else {
			print
			if ($0 == ")") {
				exit
			}
		}
	}
}
' "${BASH_SOURCE[0]}" 2> /dev/null)"

		if [[ "${mkuser_function_source_for_package}" != 'mkuser() ('* || "${mkuser_function_source_for_package}" != *')' ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Failed to extract \"mkuser\" function from source of this script for package postinstall (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)."
			return "${error_code}"
		fi

		quoted_valid_options_for_package=''
		escaped_single_quote="'\''" # This must be a seperate variable or the bash string replacement within the following loop will not parse it correctly for bash.
		for this_valid_option_for_package in "${valid_options_for_package[@]}"; do
			if [[ -n "${this_valid_option_for_package}" ]]; then
				# Escape any single quotes within this_valid_option_for_package like this: https://github.com/koalaman/shellcheck/wiki/SC1003
				quoted_valid_options_for_package+=" '${this_valid_option_for_package//\'/$escaped_single_quote}'"
			fi
		done
		quoted_valid_options_for_package_check_without_picture="${quoted_valid_options_for_package}" # This will be identical to quoted_valid_options_for_package except the "--picture" option will not be added so that we can run a "--check-only" before extracting the picture.

		package_unique_id="$(date '+%s')-$(jot -r 1 100000000 999999999)" # The current unix time plus 9 random digits should be pretty universally unique.
		package_tmp_dir="${TMPDIR:-/private/tmp/}mkuser_pkg+${package_unique_id}"
		package_scripts_dir="${package_tmp_dir}/scripts"

		rm -rf "${package_scripts_dir}"
		mkdir -p "${package_scripts_dir}"

		# Since the package title dictates the width of the "Installer" app window, we do not want to make the package title too long which would make the "Installer" window wider than normal screen widths.
		# Truncating the full and account names to 25 characters each or 50 characters if both are the same (since only one will be shown) seems to generally make reasonable windows widths.
		user_full_name_for_package_title="${user_full_name}"
		user_account_name_for_package_title="${user_account_name}"

		# Truncate both to 50 first to see if the truncated names are the same and only show one instead of only checking if the untruncated names would be the same.
		if (( ${#user_full_name_for_package_title} > 51 )); then user_full_name_for_package_title="${user_full_name:0:50}…"; fi
		if (( ${#user_account_name_for_package_title} > 51 )); then user_account_name_for_package_title="${user_account_name:0:50}…"; fi

		if [[ "${user_full_name_for_package_title}" == "${user_account_name_for_package_title}" ]]; then
			user_full_and_account_name_display_for_package_title="\"${user_full_name_for_package_title}\""
		else
			if (( ${#user_full_name_for_package_title} > 26 )); then user_full_name_for_package_title="${user_full_name:0:25}…"; fi
			if (( ${#user_account_name_for_package_title} > 26 )); then user_account_name_for_package_title="${user_account_name:0:25}…"; fi

			user_full_and_account_name_display_for_package_title="\"${user_full_name_for_package_title}\" (${user_account_name_for_package_title})"
		fi

		# Even though we are making a "nopayload" package (which has only scripts and does not write a package receipt),
		# we may still need to include a picture or passwords deobfuscation script in the package.
		# To avoid having to include actual resources (which would require not being a "nopayload" package and would write a package receipt),
		# we can include resources as compressed or encrypted base64 text within the "preinstall" script and have that script extract those files manually.
		# While these files could be extracted to an environment variable path such as INSTALLER_TEMP (accessible by any user) or INSTALLER_SECURE_TEMP (only accessible by root),
		# we would not know those paths right now during package creation since they are randomized at install time.
		# Since the passwords deobfuscation script is restricted to only running from a specific path for security, it's most convenient to create our own unique path to extract our package resources to.
		# You can read more about the security built into the passwords deobfuscation script in the OBFUSCATE PASSWORDS INTO RUN-ONLY APPLESCRIPT comments below.
		extracted_resources_dir="/private/tmp/${pkg_identifier:0:255-${#package_unique_id}-1}+${package_unique_id}" # Make sure the folder name never goes over the macOS 255 byte max since the pkg_identifier can be up to 248 bytes which would be over 255 bytes with the package_unique_id included.

		# DO NOT to anything specific to the "postinstall" script in the following block since this header will be copied for the "preinstall" script as well.
		cat << PACKAGE_POSTINSTALL_EOF > "${package_scripts_dir}/postinstall"
#!/bin/bash

script_name="\$(basename "\${BASH_SOURCE[0]}" | tr '[:lower:]' '[:upper:]')" # This script header will be used for both "postinstall" and "preinstall" (if it exists).

if [[ "\$1" != 'check-only-from-preinstall' ]]; then # Do not log "Starting..." if being run from "preinstall" for check only.
	echo "mkuser \${script_name} PACKAGE: Starting..."
fi

current_user_id="\$(scutil <<< 'show State:/Users/ConsoleUser' | awk '(\$1 == "UID") { print \$NF; exit }')"
current_user_name="\$(dscl /Search -search /Users UniqueID "\${current_user_id}" 2> /dev/null | awk '{ print \$1; exit }')"

mkuser_installer_display_error() { # Only when running graphically via "Installer" app, display an alert if an error occurred since "Installer" doesn't actually show any specific error string.
	if [[ -n "\${current_user_id}" ]] && (( COMMAND_LINE_INSTALL != 1 && current_user_id != 0 )) && pgrep -qx 'Installer'; then
		error_message="\$2"
		if [[ "\$1" == 'Did Not Attempt' ]]; then
			error_message+=\$'\n\nThis error is only from checks failing. User creation WAS NOT attempted and this system was not altered in any way.'
		else
			error_message+=\$'\n\nView "Show All Logs" output of the "Installer Log" (within the "Window" menu) for more details. Or, you can view "install.log" within the "Console" app.\n\nTHIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE.'
		fi

		# The package title is base64 encoded (when this script is created) since doing the dual escaping to be placed within a here-doc that's within another here-doc is more complicated than just encoding the string and decoding it within AppleScript.
		# The "error_message" string is passed to "osascript" as a command specific environment variable so that escaping any possible quotes or backslashes is not necessary.
		# The environment variable is retrieved within AppleScript using "printenv" via "do shell script" since "system attribute" mangles multibyte characters that may exist in the error message.
		launchctl asuser "\${current_user_id}" sudo -u "\${current_user_name}" OSASCRIPT_ENV_ERROR_MESSAGE="\${error_message}" osascript << OSASCRIPT_DISPLAY_ALERT_EOF &> /dev/null
-- Telling "Installer" to "display alert" makes the icon correct and properly blocks the "Installer" app. This DOES NOT trigger TCC since "Installer" will be the parent process.
tell application "Installer" to display alert ("\$1 to Create ${creating_user_type} " & (do shell script "echo '$(echo -n "${user_full_and_account_name_display_for_package_title}" | base64)' | base64 -D") & " on This System") message (do shell script "printenv OSASCRIPT_ENV_ERROR_MESSAGE") as critical
OSASCRIPT_DISPLAY_ALERT_EOF
	fi
}

if [[ "\${PWD}" != *'PKInstallSandbox'* || "\${PWD}" != *'${pkg_identifier}'* ]]; then
	if [[ '${extracted_resources_dir}' == '/private/tmp/'* ]]; then
		rm -rf '${extracted_resources_dir}'
	fi

	package_error='PACKAGE ERROR: Script parent working directory is invalid (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE).'
	mkuser_installer_display_error 'Did Not Attempt' "\${package_error}"
	>&2 echo "mkuser \${script_name} \${package_error}"
	exit 1
fi

if [[ "\$1" != 'check-only-from-preinstall' && "\$3" != '/' ]]; then # This should not be necessary since the package configuration only allows installing on to the booted OS, but doesn't hurt to check.
	if [[ '${extracted_resources_dir}' == '/private/tmp/'* ]]; then
		rm -rf '${extracted_resources_dir}'
	fi

	package_error='PACKAGE ERROR: Users can only be created on the boot volume. Must set boot volume as target to install user creation package.'
	mkuser_installer_display_error 'Did Not Attempt' "\${package_error}"
	>&2 echo "mkuser \${script_name} \${package_error}"
	exit 1
fi
PACKAGE_POSTINSTALL_EOF

		if [[ -f "${user_picture_path}" || -n "${user_password}" || -n "${st_admin_account_name}" ]]; then
			# Package "preinstall" will only be created to contain and extract base64 encoded gzip compressed text of picture
			# and encrypted gzip compressed text of the passwords deobfuscation script since this is a "nopayload" package
			# and we do not want any explicit resources included which would make the pkg write a receipt.

			ditto "${package_scripts_dir}/postinstall" "${package_scripts_dir}/preinstall" # Start "preinstall" with same header of "postinstall" which includes volume check and display alert function.

			cat << PACKAGE_PREINSTALL_EOF >> "${package_scripts_dir}/preinstall"

"\${PWD}/postinstall" 'check-only-from-preinstall' # "postinstall" will log that a check is being performed during "preinstall".
# Call "postinstall" with special "check-only-from-preinstall" argument to run a check (without creating the user) to see if the user could even be created before extracting any resources.
# Calling "postinstall" in this way saves us from having to duplicate the entire "mkuser" function (or even part of it) in this "preinstall" script to run this check.

mkuser_check_only_return_code="\$?"

if (( mkuser_check_only_return_code != 0 )); then
	>&2 echo 'mkuser PREINSTALL PACKAGE ERROR: Did not attempt to extract resources since checks failed.' # Do not display this error since the actual error was just displayed by the "postinstall" script.
	exit "\${mkuser_check_only_return_code}"
fi

echo 'mkuser PREINSTALL PACKAGE: Creating extracted resources directory...'

if [[ '${extracted_resources_dir}' == '/private/tmp/'* ]]; then
	rm -rf '${extracted_resources_dir}'
	mkdir -p '${extracted_resources_dir}' # Create extracted_resources_dir and make sure it's only accessible
	chmod 000 '${extracted_resources_dir}' # by root since it could contain the passwords deobfuscation script.
else
	package_error='PACKAGE ERROR: Extracted resources directory path is not correct (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE).'
	mkuser_installer_display_error 'Did Not Attempt' "\${package_error}"
	>&2 echo "mkuser PREINSTALL \${package_error}"
	exit 1
fi
PACKAGE_PREINSTALL_EOF
		fi

		if [[ -f "${user_picture_path}" ]]; then
			# Save specified picture as base64 encoded gzip compressed text inside of the "preinstall" script to be extracted to a file manually in "extracted_resources_dir" since this package will be a "nopayload" package and we do not want to include any actual package resources.
			cat << PACKAGE_PREINSTALL_EOF >> "${package_scripts_dir}/preinstall"

echo 'mkuser PREINSTALL PACKAGE: Extracting user picture...'

if ! echo '$(gzip -9 -c "${user_picture_path}" | base64)' | base64 -D | zcat > '${extracted_resources_dir}/mkuser.picture' || [[ ! -f '${extracted_resources_dir}/mkuser.picture' ]]; then
	if [[ '${extracted_resources_dir}' == '/private/tmp/'* ]]; then
		rm -rf '${extracted_resources_dir}'
	fi

	package_error='PACKAGE ERROR: Failed to extract user picture (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE).'
	mkuser_installer_display_error 'Did Not Attempt' "\${package_error}"
	>&2 echo "mkuser PREINSTALL \${package_error}"
	exit 1
fi
PACKAGE_PREINSTALL_EOF

			if [[ "${user_picture_path}" == '/Library/User Pictures/'* ]]; then
				# If a default user picture is specified, check if it exists on the target system and use it instead of the copy that is included in the package (which will have been extracted if needed as a fallback in case the same default user picture doesn't exist for some reason).
				quoted_valid_options_for_package+=" --picture \"\$([[ -f '${user_picture_path}' && \"\$(file -bI '${user_picture_path}' 2> /dev/null)\" == 'image/'* ]] && (( \$(stat -f '%z' '${user_picture_path}') <= 1000000 )) && echo '${user_picture_path}' || echo '${extracted_resources_dir}/mkuser.picture')\""
			else
				quoted_valid_options_for_package+=" --picture '${extracted_resources_dir}/mkuser.picture'"
			fi
		fi

		echo "
${mkuser_function_source_for_package}" >> "${package_scripts_dir}/postinstall"

		mkuser_check_only_fake_stdinpassword_if_password_is_set=''
		if [[ -n "${user_password}" ]]; then mkuser_check_only_fake_stdinpassword_if_password_is_set=" --stdin-password <<< 'FAKE-PASSW0RD for-mkuser-check-only'"; fi

		cat << PACKAGE_POSTINSTALL_EOF >> "${package_scripts_dir}/postinstall"

if [[ ! -f "\${PWD}/preinstall" || "\$1" == 'check-only-from-preinstall' ]]; then
	# If a "preinstall" script exists to extract resources, this check will have already been run once before getting to the "postinstall" script.

	echo "mkuser \$([[ "\$1" == 'check-only-from-preinstall' ]] && echo 'PREINSTALL' || echo 'POSTINSTALL') PACKAGE: Checking if user can be created before doing anything..."

	mkuser_check_only_error_output="\$(mkuser${quoted_valid_options_for_package_check_without_picture} --suppress-status-messages --check-only${mkuser_check_only_fake_stdinpassword_if_password_is_set} 2>&1)" # Redirect stderr to save to variable.

	mkuser_check_only_return_code="\$?"

	if (( mkuser_check_only_return_code != 0 )); then
		echo "\${mkuser_check_only_error_output}"

		if [[ '${extracted_resources_dir}' == '/private/tmp/'* ]]; then
			rm -rf '${extracted_resources_dir}'
		fi

		if [[ -z "\${mkuser_check_only_error_output}" ]]; then
			mkuser_check_only_error_output="ERROR \${mkuser_check_only_return_code} OCCURRED"
		else
			mkuser_check_only_error_output="\$(echo "\${mkuser_check_only_error_output}" | cut -c 8-)"
		fi

		mkuser_installer_display_error 'Did Not Attempt' "\${mkuser_check_only_error_output}"

		if [[ "\$1" != 'check-only-from-preinstall' ]]; then
			>&2 echo 'mkuser POSTINSTALL PACKAGE ERROR: Did not attempt to create user since checks failed.' # Do not display this error since the actual error was just displayed.
		fi

		exit "\${mkuser_check_only_return_code}"
	elif [[ "\$1" == 'check-only-from-preinstall' ]]; then
		# This "postinstall" script will be run from the "preinstall" script (when it exists) run a check to see if the user could even be created before extracting any resources.
		# If this was a check only run from the "preinstall" script this argument will be set and we should exit to not start the actual user creation before the resources have been extracted.

		exit 0
	fi
fi
PACKAGE_POSTINSTALL_EOF

		# Create long random filename between to be used for the passwords deobfuscation script file so that the checksum of "postinstall" is always unique (which is verified during passwords deobfuscation).
		passwords_deobfuscation_script_file_random_name="$(openssl rand -hex 125).pswd" # This will be a 250 character hex string with a 5 character extension of ".pswd" resulting in the max allowed length of 255 characters.

		if [[ -n "${user_password}" || -n "${st_admin_account_name}" ]]; then
			# See (last paragraph) of OBFUSCATE PASSWORDS INTO RUN-ONLY APPLESCRIPT comments below for explanation of how the passwords are being (securely) deobfuscated in the following code.
			# Only attempt to deobfuscate the passwords after checking that the specified user could be created (to not deobfuscate when user creation would fail anyway).

			# The passwords deobfuscation script is also executed via "run script" in code piped to "osascript" so that its path is not even visible in the process list while running,
			# even though that doesn't hide much since the passwords deobfuscation script path can be seen within the created package "preinstall" and "postinstall" scripts.

			cat << PACKAGE_POSTINSTALL_EOF >> "${package_scripts_dir}/postinstall"

echo 'mkuser POSTINSTALL PACKAGE: Deobfuscating passwords...'

passwords_deobfuscation_script_file_path='${extracted_resources_dir}/${passwords_deobfuscation_script_file_random_name}'

if [[ ! -f "\${passwords_deobfuscation_script_file_path}" ]]; then
	if [[ '${extracted_resources_dir}' == '/private/tmp/'* ]]; then
		rm -rf '${extracted_resources_dir}'
	fi

	package_error='PACKAGE ERROR: Passwords deobfuscation script in package does not exist (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE).'
	mkuser_installer_display_error 'Did Not Attempt' "\${package_error}"
	>&2 echo "mkuser POSTINSTALL \${package_error}"
	exit 1
fi

wrapped_encrypted_passwords_and_key="\$(echo "run script \"\${passwords_deobfuscation_script_file_path}\"" | osascript 2> /dev/null)"

if [[ "\${passwords_deobfuscation_script_file_path}" == '/private/tmp/'* ]]; then
	rm -f "\${passwords_deobfuscation_script_file_path}"
fi

if ! encrypted_passwords_and_keys="\$(echo "\${wrapped_encrypted_passwords_and_key%%$'\n'*}" | openssl enc -d -aes-256-cbc -a -A -pass fd:3 3<<< "\${wrapped_encrypted_passwords_and_key##*$'\n'}")" || [[ "\${encrypted_passwords_and_keys}" != 'EK:'* && "\${encrypted_passwords_and_keys}" != 'EP:'* ]]; then
	if [[ '${extracted_resources_dir}' == '/private/tmp/'* ]]; then
		rm -rf '${extracted_resources_dir}'
	fi

	package_error="PACKAGE ERROR: Failed to decrypt wrapped passwords (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)."
	mkuser_installer_display_error 'Did Not Attempt' "\${package_error}"
	>&2 echo "mkuser POSTINSTALL \${package_error}"
	exit 1
fi

decrypted_user_password=''
decrypted_st_admin_password=''

got_decrypted_user_password=false # Must track if actually decrypted passwords rather than checking if the resulting password is not an empty string since an empty string could be a valid decrypted password.
got_decrypted_st_admin_password=false
for this_encrypted_password_or_key in \${encrypted_passwords_and_keys}; do
	for that_encrypted_password_or_key in \${encrypted_passwords_and_keys}; do
		if [[ "\${this_encrypted_password_or_key}" != "\${that_encrypted_password_or_key}" && "\${this_encrypted_password_or_key}" == 'EP:'* && "\${that_encrypted_password_or_key}" == 'EK:'* ]]; then
			this_encrypted_password="\${this_encrypted_password_or_key:3}"
			this_encryption_key="\${that_encrypted_password_or_key:3}"

			if ! \$got_decrypted_user_password && possible_decrypted_user_password="\$(echo "\${this_encrypted_password}" | openssl enc -d -aes-256-cbc -a -A -pass fd:3 3<<< "${user_account_name}\${this_encryption_key}" 2> /dev/null)" && [[ "\${possible_decrypted_user_password}" == 'DP:'* ]]; then
				decrypted_user_password="\${possible_decrypted_user_password:3}"
				got_decrypted_user_password=true
			fi

			if ! \$got_decrypted_st_admin_password && possible_decrypted_st_admin_password="\$(echo "\${this_encrypted_password}" | openssl enc -d -aes-256-cbc -a -A -pass fd:3 3<<< "${st_admin_account_name}\${this_encryption_key}" 2> /dev/null)" && [[ "\${possible_decrypted_st_admin_password}" == 'DP:'* ]]; then
				decrypted_st_admin_password="\${possible_decrypted_st_admin_password:3}"
				got_decrypted_st_admin_password=true
			fi

			if \$got_decrypted_user_password && \$got_decrypted_st_admin_password; then
				break
			fi
		fi
	done

	if \$got_decrypted_user_password && \$got_decrypted_st_admin_password; then
		break
	fi
done

if ! \$got_decrypted_user_password || ! \$got_decrypted_st_admin_password; then
	if [[ '${extracted_resources_dir}' == '/private/tmp/'* ]]; then
		rm -rf '${extracted_resources_dir}'
	fi

	package_error="PACKAGE ERROR: Failed to decrypt new user or Secure Token admin passwords (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)."
	mkuser_installer_display_error 'Did Not Attempt' "\${package_error}"
	>&2 echo "mkuser POSTINSTALL \${package_error}"
	exit 1
fi

echo 'mkuser POSTINSTALL PACKAGE: Creating user...'

set -o pipefail # Enable pipefail to catch any "mkuser" error exit code since piping to "tee".
PACKAGE_POSTINSTALL_EOF
			if [[ -n "${st_admin_account_name}" ]]; then
				cat << PACKAGE_POSTINSTALL_EOF >> "${package_scripts_dir}/postinstall"
echo "\${decrypted_user_password}" | mkuser${quoted_valid_options_for_package} --do-not-confirm --stdin-password --fd3-secure-token-admin-password 3<<< "\${decrypted_st_admin_password}" 2>&1 | tee '${extracted_resources_dir}/mkuser.log'
PACKAGE_POSTINSTALL_EOF
			else
				cat << PACKAGE_POSTINSTALL_EOF >> "${package_scripts_dir}/postinstall"
echo "\${decrypted_user_password}" | mkuser${quoted_valid_options_for_package} --do-not-confirm --stdin-password 2>&1 | tee '${extracted_resources_dir}/mkuser.log'
PACKAGE_POSTINSTALL_EOF
			fi
		else
			cat << PACKAGE_POSTINSTALL_EOF >> "${package_scripts_dir}/postinstall"

echo 'mkuser POSTINSTALL PACKAGE: Creating user...'

if [[ ! -d '${extracted_resources_dir}' ]]; then
	mkdir -p '${extracted_resources_dir}' # Make sure extracted_resources_dir is created for "mkuser.log" since it won't have been created if there was no included picture or passwords.
fi

set -o pipefail # Enable pipefail to catch any "mkuser" error exit code since piping to "tee".
mkuser${quoted_valid_options_for_package} --do-not-confirm 2>&1 | tee '${extracted_resources_dir}/mkuser.log'
PACKAGE_POSTINSTALL_EOF
		fi

		# "set -o pipefail" is used for the "mkuser" command since the output is piped to "tee" which makes that the final exit code and should always succeed.
		# Using "set -o pipefail" means that the exit code will be set to the exit code of the last command in the pipeline to fail, if a failure occurs, which will properly catch an "mkuser" error.
		# Could use "${PIPESTATUS[0]}" for the desired exit code as well, but that variable name is lowercased on "zsh" and would require a secondary check while "set -o pipefail" can be used the
		# same way on "bash" or "zsh" if and when this code is ever made to be "zsh" compatible (with "ksh" emulation and other "bash"-like options set) while also retaining "bash" compatibility.

		# MUST create *WHOLE* "postinstall" file *BEFORE* creating passwords deobfuscation script so that the checksum of the "postinstall" file can be used as a factor for the passwords deobfuscation to be allowed.
		cat << PACKAGE_POSTINSTALL_EOF >> "${package_scripts_dir}/postinstall"

mkuser_return_code="\$?"
set +o pipefail # Disable pipefail after retrieving the exit code of "mkuser" command pipeline to reset normal exit code behavior.

mkuser_log="\$(cat '${extracted_resources_dir}/mkuser.log')"

if [[ '${extracted_resources_dir}' == '/private/tmp/'* ]]; then
	rm -rf '${extracted_resources_dir}'
fi

if (( mkuser_return_code != 0 )); then
	mkuser_error="ERROR \${mkuser_return_code} OCCURRED"

	if [[ -n "\${mkuser_log}" ]]; then
		mkuser_error="\$(echo "\${mkuser_log}" | grep '^mkuser WARNING\|^mkuser ERROR' | cut -c 8-)"
	fi

	mkuser_installer_display_error 'Failed' "\${mkuser_error}"
fi

exit "\${mkuser_return_code}"
PACKAGE_POSTINSTALL_EOF

		chmod +x "${package_scripts_dir}/postinstall"

		if [[ -n "${user_password}" || -n "${st_admin_account_name}" ]]; then # st_admin_password will also be obfuscated, but that will only ever be set if st_admin_account_name is set, but user_password or st_admin_password could possibly be valid empty strings.
			# OBFUSCATE PASSWORDS INTO RUN-ONLY APPLESCRIPT
			# This *must* be done *after* the "postinstall" is fully written since the "postinstall" checksum will be hard-coded into the script to validate for deobfuscation.

			# The following information about password obfuscation applies to both the new user password and the existing Secure Token admin password (if present).

			# Even though encryption is being used, this is just *OBFUSCATION* since the encryption key will be *included* within the resulting run-only AppleScript
			# which will also have all of the strings within it obfuscated (including the encrypted passwords and passwords encryption key). This is not for *true* encryption,
			# it's just to make sure the passwords are not directly visible within the "postinstall" script or any package resources or ever written to disk or visible in the
			# process list and to hopefully make it *extremely* tedious and time consuming for someone to try to extract the encrypted passwords and passwords encryption key.

			# This run-only AppleScript (referred to as the "passwords deobfuscation script") will only output the encrypted passwords and passwords encryption key stored within
			# it under very specific circumstances (ie. during the package installation) and only when run by a unique "postinstall" script (by matching checksums).
			# Each time a "postinstall" script is created, it will be unique because it will contains the specific random filename of the passwords deobfuscation script.
			# One way to think of this is that it is *kind of* encryption, but rather than needing a text password to decrypt it, the "password" is the act of running the script
			# via the unique "postinstall" during a package installation process. This is just a metaphor, again, I do not consider this to be any kind of true encryption.
			# I believe this would be very hard if not impossible to spoof (i.e. make the script output the encrypted passwords and passwords encryption key under different circumstances)
			# because of all of the checks being done, including verifying the checksum of the "postinstall" script which ran the passwords deobfuscation script as well as verifying that
			# the "postinstall" script is being run during a package installation (by verifying that is is a child process of PackageKit). That means someone could not simply extract
			# the passwords deobfuscation script and "postinstall" script and try to edit it to output the encrypted passwords and passwords encryption key since the
			# encrypted passwords and passwords encryption key will not be returned since the checksum will not match the hard-coded checksum when the script was created, etc.
			# THAT BEING SAID, I GIVE *NO GUARANTEE* THAT SOMEONE COULDN'T FIGURE OUT HOW TO MAKE THE SCRIPT OUTPUT THE PASSWORDS IF THEY TRIED HARD ENOUGH!

			# In regards to actually extracting the passwords deobfuscation script from the package, since this will be a "nopayload" package which does not write a pacakge reciept,
			# the passwords deobfuscation script is actually stored as encrypted gzip compressed text within a "preinstall" script rather than as easily extractable package resources.
			# This allows the package to store resources while still being a "nopayload" package. Because of storing the passwords deobfuscation script in this way, it actually adds
			# another layer of tedium for someone who would be trying to get at the passwords deobfuscation script for the purpose of trying to extract the passwords.
			# Rather than just storing the passwords deobfuscation script as base64 encoding the gzip compressed text like the picture, it is encrypted using the checksum of the
			# specific "postinstall" script as the encryption key. Again, this is not for *true* encryption since the checksum of the specific "postinstall" could be
			# easily retrieved to manually decrypt the passwords deobfuscation script, it was just another layer of obfuscation that is simple for the package code to extract,
			# but would add more tedium for someone trying to even begin attempting to extract the passwords.

			# The other way someone may try to get the encrypted passwords and passwords encryption key out of the passwords deobfuscation script would be to try to decompile
			# and then decypher the contents. Simply opening the run-only script in TextEdit or the like would be useless since every single string is obfuscated
			# by a random huge caesar shift which pushes all the characters out of the range of regular rendered characters and the number the characters are shifted
			# by is a random amount each time a package is created. If someone were to use other more sophisticated means to try to decompile and decypher the contents
			# of this passwords deobfuscation script, I cannot guarantee that they wouldn't be able to do it (but I don't know how to do it). I hope that it would be very
			# tedious and time consuming and that it would not even be easy to write a script that could extract the encrypted passwords and passwords encryption key from
			# any and all passwords deobfuscation scripts created this way since they are randomized each time they are created.
			# THAT BEING SAID, REGARDLESSS OF HOW COMPLEX IT MAY BE, THIS IS JUST *OBFUSCATION* AND I GIVE *NO GUARANTEE* THAT
			# SOMEONE COULDN'T FIGURE OUT HOW TO EXTRACT THE ENCRYPTED PASSWORDS AND PASSWORDS ENCRYPTION KEY IF THEY TRIED HARD ENOUGH!

			# The point of all of this is that *hopefully* even when someone knows how this passwords deobfuscation script (which contains the obfuscated encrypted passwords and
			# passwords encryption key) is created, they could not get it back out since once it is put into a package it is unique and "locked" to that package. I believe
			# that it would require a high level of skill and knowledge to be able to even begin to know how to go about trying to extract the encrypted passwords and passwords
			# encryption key from this passwords deobfuscation script. As I have said, I give *no guarantee* that it is not possible to retrieve the encrypted passwords and passwords
			# encryption key contained within this passwords deobfuscation script one way or another, but I hope that it would not be easy or possible to do by hand and would require
			# that someone spend a decent amount of time and energy and probably would have to write scripts and/or programs to help extract this sensitive data. This should give some
			# piece of mind that the encrypted passwords and passwords encryption key are not easily extractable by the novice user. My hope is that someone would need to have a
			# strong desire as well as decent knowledge of shell scripting, AppleScript, packages, macOS, etc to even attempt to extract the encrypted passwords and passwords
			# encryption key and even then I hope that it would not be obvious, easy, or straightforward to do.

			# After the encrypted passwords and passwords encryption key are returned to the "postinstall" script, they are passed to the "openssl" command to retreive the actual plain text
			# passwords. The way that this "openssl" command uses "pipes" and "here-strings" instead of passing the encrypted passwords and passwords encryption key as regular parameters means that
			# the encrypted passwords and passwords encryption key are never visible in the process list. This means that someone could not simply watch for "openssl" commands during the
			# installation process to be able to retrieve the encrypted passwords and passwords encryption key in plain text. And as I said before, if someone were to try to make a copy of
			# this script and edit it to output the plain text passwords, that modified script would not be able to retrieve the encrypted passwords and passwords encryption key since the
			# checksum of the modified "postinstall" script would no longer match the hard-coded checksum within the passwords deobfuscation script and it would therefore not return anything.
			# It may seem less secure to do the passwords decryption within the "postinstall" script in this way instead of within the passwords deobfuscation script, but that is not actually
			# the case since if the "openssl" decryption command was run within the passwords deobfuscation script it would be run via "do shell script" which would make the entire uninterpreted
			# command visible in the process list like "sh -c echo ENCRYPTED-PASSWORDS | openssl enc -d -aes-256-cbc -a -A -pass fd:3 3<<< PASSWORDS-ENCRYPTION-KEY" which clearly renders the ability
			# of the pipes and here-strings to hide their contents from the process list useless. While they would still not be visible in the "openssl" process, the would be visible in the parent "sh"
			# process because of how AppleScript executes commands with "do shell script". So, it is actually more secure to run the "openssl" command in the "postinstall" script which
			# ensures that the encrypted passwords and passwords encryption key only ever exist in a variable within the "postinstall" script and then are passed to "openssl" using
			# here-strings which are interpreted by bash and are not ever displayed in the process list.

			# Since writing the description above (which is still accurate), another layer of encryption has been added to each password stored within the encrypted passwords inside the passwords deobfuscation script.
			# Instead of the plain text passwords being retrieved by passing the encrypted passwords and passwords encryption key (returned by the passwords deobfuscation script) to "openssl",
			# the passwords are each encrypted individually and the actual encryption keys are included along with other fake encrypted strings and fake encryption keys in a random order (as described below).
			# This set of real and fake encrypted passwords and passwords encryption keys are what will be returned by the initial decryption in the "postinstall" script
			# and then must be iterated through, attempting decryption with each possible combination to find the correct password for each account name (as described below).
			# This creates a sort of "wrapped" encryption, but since all of the encryption keys are still included in the results, this is still just complex obfuscation.


			# In the future, I may be able to do an even more secure method of saving the encrypted password by generating the ShadowHashData and saving that to be passed to dsimport directly:
			# https://github.com/puppetlabs/puppet/blob/d567575ba8c5b2c903044b80b0adaab176c8da5d/lib/puppet/provider/user/directoryservice.rb#L597 (https://github.com/puppetlabs/puppet/commit/688779d43c770598ca72c83e14b555f342252150)
			# https://github.com/puppetlabs/puppet/blob/d567575ba8c5b2c903044b80b0adaab176c8da5d/lib/puppet/provider/user/directoryservice.rb#L540 (https://github.com/puppetlabs/puppet/commit/de14d588679b29394ea37e8c55ac9bd071b51b83)
				# The main problem with this that the tools are not available by default on macOS (that I know of) to be able to generate the ShadowHashData via bash.
				# To do this I would need to require users download tools such a newer version of openssl, and up to this point my goal has been to have no dependecies.
				# Also, including ShadowHashData in dsimport has not been tested to see if it works properly with SEP Macs and that it sets up all other
				# AuthenticationAuthority values, etc. If auto-login is enabled, I would need to pre-process the kcpassword file and save that in the
				# package as well instead of generating it on-the-fly since the password would no longer be available during user creation.
				# This would also mean passwords couldn't be verified. Also, I believe including a kcpassword file would be less secure than the
				# current password obfuscation method since it is relatively common knowledge and easy to extract a password from a kcpassword file.
				# ALSO, ANY PASSED SECURE TOKEN ADMIN PASSWORD WOULD STILL NEED TO BE OBFUSCATED WITH THE CURRENT TECHNIQUE.


			# User creation via package with passwords deobfuscation:
				# Tested via "startosinstall --installpackage" on 10.13, 10.14, 10.15, 11
				# Tested via first boot LaunchDaemon using "installer -pkg" on 10.13, 10.14, 10.15, 11
				# Tested via "Installer" app in full OS on 10.13, 10.14, 10.15, 11, 12


			if ! $suppress_status_messages; then
				echo 'mkuser: Obfuscating passwords for package...'
			fi


			# Encrypt each password with a random key between 200 and 300 characters that also has the relevant account name added to the beginning.
			# These random encryption keys (without the account name at the beginning) will be included in the contents (which will also be encrypted by the random wrapping passwords encryption key)
			# along with 8 other random encryption keys that are not correct AND 8 other random encrypted "passwords" between 0 and 100 characters.
			# The encrypted strings will start with "EP:" (Encrypted Password) and the encryption keys will start with "EK:" (Encryption Key) to make the loop faster to not attempt decrypt encryption keys or decrypt passwords using other encrypted passwords.
			# I don't think this reduces any obfuscation since it'd already be pretty visually clear (by length and salt prefix) which are the keys and which are the encrypted strings anyways.
			# This means there will be a total of 10 encrypted strings and 10 encryption keys in random order so that it will not be clear what are the actual encrypted passwords and what are the random encrypted string.
			# Each encrypted string will attempt decrypted by trying all the encryption key lines with the account name at the beginning until one works.
			# To know the decryption worked, the encrypted passwords will also be prefixed with "DP:" (Decrypted Password) so that we can check for that consistent prefix since failed decryptions can still result in gibberish output.
			# We will know which account name the password is for by the fact that it was decrypted using that account name at the beginning of the encryption key.
			# It's fine if either user_password or st_admin_password are empty strings since st_admin_password will only be used when needed even if it's an empty string and if user_password is an empty string it will be properly retreived as an empty string after decryption.

			user_password_encryption_key="$(openssl rand -base64 "$(jot -r 1 150 225)" | tr -d '[:space:]')"
			encrypted_user_password="$(echo "DP:${user_password}" | openssl enc -aes-256-cbc -a -A -pass fd:3 3<<< "${user_account_name}${user_password_encryption_key}")"

			st_admin_password_encryption_key="$(openssl rand -base64 "$(jot -r 1 150 225)" | tr -d '[:space:]')"
			encrypted_st_admin_password="$(echo "DP:${st_admin_password}" | openssl enc -aes-256-cbc -a -A -pass fd:3 3<<< "${st_admin_account_name}${st_admin_password_encryption_key}")"

			real_and_fake_encrypted_passwords_shuffled_with_real_and_fake_encryption_keys="EK:${user_password_encryption_key}
EP:${encrypted_user_password}
EK:${st_admin_password_encryption_key}
EP:${encrypted_st_admin_password}"

			for (( add_fake_encrypted_passwords_and_encryption_keys = 0; add_fake_encrypted_passwords_and_encryption_keys < 8; add_fake_encrypted_passwords_and_encryption_keys ++ )); do
				real_and_fake_encrypted_passwords_shuffled_with_real_and_fake_encryption_keys+="
EK:$(openssl rand -base64 "$(jot -r 1 150 225)" | tr -d '[:space:]')
EP:$(openssl rand -base64 "$(jot -r 1 0 75)" | tr -d '[:space:]' | openssl enc -aes-256-cbc -a -A -pass fd:3 3<<< "$(openssl rand -base64 "$(jot -r 1 150 225)" | tr -d '[:space:]')")"
			done

			real_and_fake_encrypted_passwords_shuffled_with_real_and_fake_encryption_keys="$(echo "${real_and_fake_encrypted_passwords_shuffled_with_real_and_fake_encryption_keys}" | sort -R)"

			# Create random wrapping passwords encryption key between 500 and 600 characters (the following numbers are for base64 lengths).
			wrapping_passwords_encryption_key="$(openssl rand -base64 "$(jot -r 1 375 450)" | tr -d '[:space:]')"

			# Encrypt the encrypted passwords using the random wrapping passwords encryption key.
			wrapped_encrypted_passwords="$(echo "${real_and_fake_encrypted_passwords_shuffled_with_real_and_fake_encryption_keys}" | openssl enc -aes-256-cbc -a -A -pass fd:3 3<<< "${wrapping_passwords_encryption_key}")"
			# NOTE: Do not need to bother including "-salt" option with "openssl enc" since salt is enabled by default since at least macOS 10.13 High Sierra.

			# Every variable name set within the script will be randomized each time it is created.
			# Each previously used random variable name will also be kept track of to ensure there are no duplicate random variable names.

			this_random_variable_name=''
			used_random_variable_names=''
			mkuser_set_new_random_variable_name() {
				# Create random 5 character variable names containing numbers and lowercase letters and
				# always starting with a letter since AppleScript variables cannot start with a number.

				until [[ " ${used_random_variable_names} " != *" ${this_random_variable_name} "* ]]; do # Make sure all random variable names are unique. If both are empty, this_random_variable_name will get initialized within this loop.
					this_random_variable_name="$(jot -rc 1 a z)$(openssl rand -hex 2)" # this_random_variable_name IS NOT LOCAL to this function, so that is can be referenced after calling the function without needing a subshell (https://rus.har.mn/blog/2010-07-05/subshells/).
				done

				used_random_variable_names+=" ${this_random_variable_name}"
				# This function must ALSO never be called from a subshell so that we can store the used random variable names in a variable that can persist between function calls (which would get lost if the function was called in a subshell).

				# DO NOT ECHO this_random_variable_name since it will be referenced directly without needing a subshell.
			}

			# All strings will have their characters shifted by a random number from 100000 to 999999.
			obfuscate_characters_shift_count="$(jot -r 1 100000 999999)"

			# Break the obfuscate_characters_shift_count integers into seperate variables to be concatenated within the script and mix them in among
			# a bunch of junk variables which are set to random single integers to make the real ones difficult to identify in a decompiled source.
			obfuscate_characters_shift_count_jumble=()
			for (( obfuscate_characters_shift_count_jumble_junk_var_index = 0; obfuscate_characters_shift_count_jumble_junk_var_index < 100; obfuscate_characters_shift_count_jumble_junk_var_index ++ )); do
				mkuser_set_new_random_variable_name
				obfuscate_characters_shift_count_jumble+=( "set ${this_random_variable_name} to $(jot -r 1 1 9)" )
			done

			# Replace the first 6 of the 100 random variables set to random integers with randomly named variables containing each actual number in the obfuscate_characters_shift_count.
			# The obfuscate_characters_shift_count_jumble will be shuffled randomly before it is written into the script so it's fine to just replace the first 6.
			obfuscate_characters_shift_count_jumble_actual_variable_names=() # Since random variable names are used, they must be kept track of to use when concatenating the actual number within the script.
			for obfuscate_characters_shift_count_char_index in {0..5}; do
				mkuser_set_new_random_variable_name
				obfuscate_characters_shift_count_jumble["${obfuscate_characters_shift_count_char_index}"]="set ${this_random_variable_name} to ${obfuscate_characters_shift_count:${obfuscate_characters_shift_count_char_index}:1}"
				obfuscate_characters_shift_count_jumble_actual_variable_names+=( "${this_random_variable_name}" )
			done

			IFS=$'\n' # It's ok that these lines will not be indented, osacompile will still parse it correctly.
			obfuscate_characters_shift_count_jumble_var_lines="$(echo "${obfuscate_characters_shift_count_jumble[*]}" | sort -R)" # Randomly shuffle the rows containing the actual and junk variables.

			IFS='&' # It's ok to concatenate these without spaces around the ampersands, osacompile will still parse it correctly.
			obfuscate_characters_shift_count_actual_variable_names_to_concatenate="${obfuscate_characters_shift_count_jumble_actual_variable_names[*]}"
			unset IFS

			mkuser_obfuscate_string() {
				# From: https://stackoverflow.com/questions/14612235/protecting-an-applescript-script/14616010#14616010
				# I'm not sure how to shift strings like this using bash. It is possible to get the integer or hex of the
				# character as is done in the kcpassword code, but if I add such a huge number to that and try to convert
				# it back to a character, the encoding is wrong and does not get rendered as the proper single character.

				# The "$1" argument is passed to "osascript" as a command specific environment variable so that escaping any possible quotes or backslashes is not necessary.
				# The fact that multibyte characters would get mangled when in an environment variable retrieved by AppleScript with "system attribute" should not be an issue since they will never be in these strings.
				OSASCRIPT_ENV_OBFUSCATE_STRING="$1" osascript << OSASCRIPT_OBFUSCATE_STRING_EOF 2> /dev/null
set stringID to id of (system attribute "OSASCRIPT_ENV_OBFUSCATE_STRING") as list
repeat with thisCharacter in stringID
	set contents of thisCharacter to thisCharacter + ${obfuscate_characters_shift_count}
end repeat
return string id stringID
OSASCRIPT_OBFUSCATE_STRING_EOF

				# Doesn't seem like there would be any gain to set this output to a return variable (https://rus.har.mn/blog/2010-07-05/subshells/)
				# since that would require a subshell inside the function which is equivalent to just calling the function with a subshell.
			}

			# This random deobfuscate function name needs to be set before preparing the encrypted passwords chunk variables.
			mkuser_set_new_random_variable_name
			deobfuscate_string_func="${this_random_variable_name}"

			# Break passwords encryption key into 7 chunks with some reversed to be mixed throughout to source in random order to make it harder to identify and extract from decompiled source.
			wrapping_passwords_encryption_key_chunk_variable_names=() # Since random variable names are used, they must be kept track of to use when concatenating the passwords encryption key within the script.
			for (( random_variable_name_index = 0; random_variable_name_index < 7; random_variable_name_index ++ )); do
				mkuser_set_new_random_variable_name
				wrapping_passwords_encryption_key_chunk_variable_names+=( "${this_random_variable_name}" )
			done

			wrapping_passwords_encryption_key_chunk_length="$(( ${#wrapping_passwords_encryption_key} / 7 ))"

			# Since it's not easy to shuffle an array, create a string separated by lines to be able to shuffle with "sort -R" and then set those shuffled lines to an array.
			wrapping_passwords_encryption_key_chunk_var_assignments_shuffled=()
			while IFS='' read -r wrapping_passwords_encryption_key_chunk_var_assignments_shuffled_line; do
				wrapping_passwords_encryption_key_chunk_var_assignments_shuffled+=( "${wrapping_passwords_encryption_key_chunk_var_assignments_shuffled_line}" )
			done <<< "$(echo "set ${wrapping_passwords_encryption_key_chunk_variable_names[0]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "${wrapping_passwords_encryption_key:0:${wrapping_passwords_encryption_key_chunk_length}}")\")
set ${wrapping_passwords_encryption_key_chunk_variable_names[1]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "$(echo "${wrapping_passwords_encryption_key:${wrapping_passwords_encryption_key_chunk_length}:${wrapping_passwords_encryption_key_chunk_length}}" | rev)")\")
set ${wrapping_passwords_encryption_key_chunk_variable_names[2]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "${wrapping_passwords_encryption_key:$(( wrapping_passwords_encryption_key_chunk_length * 2 )):${wrapping_passwords_encryption_key_chunk_length}}")\")
set ${wrapping_passwords_encryption_key_chunk_variable_names[3]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "$(echo "${wrapping_passwords_encryption_key:$(( wrapping_passwords_encryption_key_chunk_length * 3 )):${wrapping_passwords_encryption_key_chunk_length}}" | rev)")\")
set ${wrapping_passwords_encryption_key_chunk_variable_names[4]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "${wrapping_passwords_encryption_key:$(( wrapping_passwords_encryption_key_chunk_length * 4 )):${wrapping_passwords_encryption_key_chunk_length}}")\")
set ${wrapping_passwords_encryption_key_chunk_variable_names[5]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "$(echo "${wrapping_passwords_encryption_key:$(( wrapping_passwords_encryption_key_chunk_length * 5 )):${wrapping_passwords_encryption_key_chunk_length}}" | rev)")\")
set ${wrapping_passwords_encryption_key_chunk_variable_names[6]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "${wrapping_passwords_encryption_key:$(( wrapping_passwords_encryption_key_chunk_length * 6 ))}")\")" | sort -R)"

			# Break encrypted passwords into 7 chunks with some reversed to be mixed throughout to source in random order to make it harder to identify and extract from decompiled source.
			wrapped_encrypted_passwords_chunk_variable_names=() # Since random variable names are used, they must be kept track of to use when concatenating the encrypted passwords key within the script.
			for (( random_variable_name_index = 0; random_variable_name_index < 7; random_variable_name_index ++ )); do
				mkuser_set_new_random_variable_name
				wrapped_encrypted_passwords_chunk_variable_names+=( "${this_random_variable_name}" )
			done

			wrapped_encrypted_passwords_chunk_length="$(( ${#wrapped_encrypted_passwords} / 7 ))"

			# Since it's not easy to shuffle an array, create a string separated by lines to be able to shuffle with "sort -R" and then set those shuffled lines to an array.
			wrapped_encrypted_passwords_chunk_var_assignments_shuffled=()
			while IFS='' read -r wrapped_encrypted_passwords_chunk_var_assignments_shuffled_line; do
				wrapped_encrypted_passwords_chunk_var_assignments_shuffled+=( "${wrapped_encrypted_passwords_chunk_var_assignments_shuffled_line}" )
			done <<< "$(echo "set ${wrapped_encrypted_passwords_chunk_variable_names[0]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "${wrapped_encrypted_passwords:0:${wrapped_encrypted_passwords_chunk_length}}")\")
set ${wrapped_encrypted_passwords_chunk_variable_names[1]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "$(echo "${wrapped_encrypted_passwords:${wrapped_encrypted_passwords_chunk_length}:${wrapped_encrypted_passwords_chunk_length}}" | rev)")\")
set ${wrapped_encrypted_passwords_chunk_variable_names[2]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "${wrapped_encrypted_passwords:$(( wrapped_encrypted_passwords_chunk_length * 2 )):${wrapped_encrypted_passwords_chunk_length}}")\")
set ${wrapped_encrypted_passwords_chunk_variable_names[3]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "$(echo "${wrapped_encrypted_passwords:$(( wrapped_encrypted_passwords_chunk_length * 3 )):${wrapped_encrypted_passwords_chunk_length}}" | rev)")\")
set ${wrapped_encrypted_passwords_chunk_variable_names[4]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "${wrapped_encrypted_passwords:$(( wrapped_encrypted_passwords_chunk_length * 4 )):${wrapped_encrypted_passwords_chunk_length}}")\")
set ${wrapped_encrypted_passwords_chunk_variable_names[5]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "$(echo "${wrapped_encrypted_passwords:$(( wrapped_encrypted_passwords_chunk_length * 5 )):${wrapped_encrypted_passwords_chunk_length}}" | rev)")\")
set ${wrapped_encrypted_passwords_chunk_variable_names[6]} to ${deobfuscate_string_func}(\"$(mkuser_obfuscate_string "${wrapped_encrypted_passwords:$(( wrapped_encrypted_passwords_chunk_length * 6 ))}")\")" | sort -R)"

			# Get checksum of "postinstall" script to be verified within the script.
			postinstall_checksum="$(shasum -a 512 "${package_scripts_dir}/postinstall" | cut -d ' ' -f 1)"

			# Create random variable names to be used throughout the script.
			mkuser_set_new_random_variable_name
			script_path_var="${this_random_variable_name}"
			mkuser_set_new_random_variable_name
			parent_script_path_var="${this_random_variable_name}"
			mkuser_set_new_random_variable_name
			intended_parent_script_path_var="${this_random_variable_name}"
			mkuser_set_new_random_variable_name
			intended_ancestor_process_var="${this_random_variable_name}"

			mkuser_set_new_random_variable_name
			wrapped_encrypted_passwords_var="${this_random_variable_name}"
			mkuser_set_new_random_variable_name
			wrapping_passwords_encryption_key_var="${this_random_variable_name}"

			mkuser_set_new_random_variable_name
			obfuscated_string_var="${this_random_variable_name}"
			mkuser_set_new_random_variable_name
			obfuscated_char_ints_var="${this_random_variable_name}"
			mkuser_set_new_random_variable_name
			this_obfuscated_char_var="${this_random_variable_name}"

			# Compile file with ".scpt" extension since "osacompile" uses the extension to determine what type of file to create.
			# The compiled script will be renamed to passwords_deobfuscation_script_file_random_name with the ".pswd" extension after creation.
			osacompile -x -o "${package_tmp_dir}/passwords-deobfuscation.scpt" << PACKAGE_PASSWORD_OSACOMPILE_EOF
use AppleScript version "2.4"
use scripting additions
${wrapping_passwords_encryption_key_chunk_var_assignments_shuffled[0]}
if ((do shell script ${deobfuscate_string_func}("$(mkuser_obfuscate_string 'id -u')")) is equal to ${deobfuscate_string_func}("$(mkuser_obfuscate_string '0')")) then
	${wrapped_encrypted_passwords_chunk_var_assignments_shuffled[0]}
	if (((system attribute ${deobfuscate_string_func}("$(mkuser_obfuscate_string 'SCRIPT_NAME')")) is equal to ${deobfuscate_string_func}("$(mkuser_obfuscate_string 'postinstall')")) and ((system attribute ${deobfuscate_string_func}("$(mkuser_obfuscate_string 'INSTALL_PKG_SESSION_ID')")) is equal to ${deobfuscate_string_func}("$(mkuser_obfuscate_string "${pkg_identifier}")")) and ((system attribute ${deobfuscate_string_func}("$(mkuser_obfuscate_string 'PWD')")) contains ${deobfuscate_string_func}("$(mkuser_obfuscate_string 'PKInstallSandbox')")) and ((system attribute ${deobfuscate_string_func}("$(mkuser_obfuscate_string 'PWD')")) contains ${deobfuscate_string_func}("$(mkuser_obfuscate_string "${pkg_identifier}")"))) then
		set ${script_path_var} to ${deobfuscate_string_func}("$(mkuser_obfuscate_string "${extracted_resources_dir}/${passwords_deobfuscation_script_file_random_name}")")
		${wrapped_encrypted_passwords_chunk_var_assignments_shuffled[1]}
		((${script_path_var} as POSIX file) as alias)
		${wrapping_passwords_encryption_key_chunk_var_assignments_shuffled[1]}
		if (((POSIX path of (path to me)) is equal to ${script_path_var}) and ((do shell script ${deobfuscate_string_func}("$(mkuser_obfuscate_string "stat -f %A '${extracted_resources_dir}'")")) is equal to ${deobfuscate_string_func}("$(mkuser_obfuscate_string '0')")) and ((do shell script (${deobfuscate_string_func}("$(mkuser_obfuscate_string 'stat -f %A ')") & (quoted form of ${script_path_var}))) is equal to ${deobfuscate_string_func}("$(mkuser_obfuscate_string '0')"))) then
			${wrapping_passwords_encryption_key_chunk_var_assignments_shuffled[2]}
			set ${parent_script_path_var} to (do shell script ${deobfuscate_string_func}("$(mkuser_obfuscate_string "ps -p \$(ps -p \$PPID -o ppid=) -o command= | cut -d ' ' -f 2")"))
			${wrapped_encrypted_passwords_chunk_var_assignments_shuffled[2]}
			set ${intended_parent_script_path_var} to ((system attribute ${deobfuscate_string_func}("$(mkuser_obfuscate_string 'PWD')")) & ${deobfuscate_string_func}("$(mkuser_obfuscate_string '/postinstall')"))
			if ((${intended_parent_script_path_var} is equal to ${parent_script_path_var}) or (${intended_parent_script_path_var} is equal to (${deobfuscate_string_func}("$(mkuser_obfuscate_string '/private')") & ${parent_script_path_var}))) then -- parent_script_path_var may start with /tmp/ symlink instead of /private/tmp/.
				${wrapping_passwords_encryption_key_chunk_var_assignments_shuffled[3]}
				if (${deobfuscate_string_func}("$(mkuser_obfuscate_string "${postinstall_checksum}")") is equal to ((first word of (do shell script (${deobfuscate_string_func}("$(mkuser_obfuscate_string 'shasum -a 512 ')") & (quoted form of ${parent_script_path_var})))) as text)) then
					${wrapped_encrypted_passwords_chunk_var_assignments_shuffled[3]}
					set ${intended_ancestor_process_var} to ${deobfuscate_string_func}("$(mkuser_obfuscate_string '/System/Library/PrivateFrameworks/PackageKit.framework/')")
					${wrapped_encrypted_passwords_chunk_var_assignments_shuffled[4]}
					considering numeric strings
						if ((system version of (system info)) >= ${deobfuscate_string_func}("$(mkuser_obfuscate_string '10.15')")) then
							set ${intended_ancestor_process_var} to (${intended_ancestor_process_var} & ${deobfuscate_string_func}("$(mkuser_obfuscate_string 'Versions/A/XPCServices/package_script_service.xpc/Contents/MacOS/package_script_service')"))
						else
							set ${intended_ancestor_process_var} to (${intended_ancestor_process_var} & ${deobfuscate_string_func}("$(mkuser_obfuscate_string 'Resources/installd')"))
						end if
					end considering
					${wrapping_passwords_encryption_key_chunk_var_assignments_shuffled[4]}
					if (${intended_ancestor_process_var} is equal to (do shell script ${deobfuscate_string_func}("$(mkuser_obfuscate_string "ps -p \$(ps -p \$(ps -p \$(ps -p \$PPID -o ppid=) -o ppid=) -o ppid=) -o command=")"))) then
						${wrapped_encrypted_passwords_chunk_var_assignments_shuffled[5]}
						try
							do shell script (${deobfuscate_string_func}("$(mkuser_obfuscate_string 'pgrep -qfx ')") & (quoted form of ${intended_ancestor_process_var})) -- Make sure the only running instance of...
						on error
							${wrapping_passwords_encryption_key_chunk_var_assignments_shuffled[5]}
							do shell script (${deobfuscate_string_func}("$(mkuser_obfuscate_string 'pgrep -qafx ')") & (quoted form of ${intended_ancestor_process_var})) -- ancestor process is an ancestor of this process.
							${wrapped_encrypted_passwords_chunk_var_assignments_shuffled[6]}
							set ${wrapped_encrypted_passwords_var} to (${wrapped_encrypted_passwords_chunk_variable_names[0]} & ((reverse of (characters of ${wrapped_encrypted_passwords_chunk_variable_names[1]})) as text) & ${wrapped_encrypted_passwords_chunk_variable_names[2]} & ((reverse of (characters of ${wrapped_encrypted_passwords_chunk_variable_names[3]})) as text) & ${wrapped_encrypted_passwords_chunk_variable_names[4]} & ((reverse of (characters of ${wrapped_encrypted_passwords_chunk_variable_names[5]})) as text) & ${wrapped_encrypted_passwords_chunk_variable_names[6]})
							${wrapping_passwords_encryption_key_chunk_var_assignments_shuffled[6]}
							set ${wrapping_passwords_encryption_key_var} to (${wrapping_passwords_encryption_key_chunk_variable_names[0]} & ((reverse of (characters of ${wrapping_passwords_encryption_key_chunk_variable_names[1]})) as text) & ${wrapping_passwords_encryption_key_chunk_variable_names[2]} & ((reverse of (characters of ${wrapping_passwords_encryption_key_chunk_variable_names[3]})) as text) & ${wrapping_passwords_encryption_key_chunk_variable_names[4]} & ((reverse of (characters of ${wrapping_passwords_encryption_key_chunk_variable_names[5]})) as text) & ${wrapping_passwords_encryption_key_chunk_variable_names[6]})
							return (${wrapped_encrypted_passwords_var} & "\n" & ${wrapping_passwords_encryption_key_var})
						end try
					end if
				end if
			end if
		end if
	end if
end if
on ${deobfuscate_string_func}(${obfuscated_string_var})
	try
		${obfuscate_characters_shift_count_jumble_var_lines}
		set ${obfuscated_char_ints_var} to id of ${obfuscated_string_var} as list
		repeat with ${this_obfuscated_char_var} in ${obfuscated_char_ints_var}
			set contents of ${this_obfuscated_char_var} to ${this_obfuscated_char_var} - (((${obfuscate_characters_shift_count_actual_variable_names_to_concatenate}) as text) as number)
		end repeat
		return string id ${obfuscated_char_ints_var}
	end try
end ${deobfuscate_string_func}
PACKAGE_PASSWORD_OSACOMPILE_EOF

			osacompile_exit_code="$?"

			if (( "$osacompile_exit_code" != 0 )) || [[ ! -f "${package_tmp_dir}/passwords-deobfuscation.scpt" ]]; then
				rm -rf "${package_scripts_dir}"

				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: \"osacompile\" (for passwords obfuscation within package) failed with exit code ${osacompile_exit_code}."
				return "${error_code}"
			fi

			# Save the passwords deobfuscation script as encrypted gzip compressed text inside of the "preinstall" script to be extracted to a file manually in "extracted_resources_dir" since this package will be a "nopayload" package and we do not want to include any actual package resources.
			# Instead just base64 encoding the gzip compressed text like the picture, the passwords deobfuscation script is also encrypted using the checksum of the specific "postinstall" script as the encryption key.
			# This does not really add any specific security, but it makes things a bit more annoying for anyone trying to even begin attempting to extract the passwords (which, as described above, would still be incredibly difficult even after getting the "scpt" file decrypted and saved into a file).
			cat << PACKAGE_PREINSTALL_EOF >> "${package_scripts_dir}/preinstall"

echo 'mkuser PREINSTALL PACKAGE: Extracting passwords deobfuscation script...'

if ! echo '$(gzip -9 -c "${package_tmp_dir}/passwords-deobfuscation.scpt" | openssl enc -aes-256-cbc -a -A -pass fd:3 3<<< "${postinstall_checksum}")' | openssl enc -d -aes-256-cbc -a -A -pass fd:3 3<<< "\$(shasum -a 512 "\${PWD}/postinstall" | cut -d ' ' -f 1)" | zcat > '${extracted_resources_dir}/${passwords_deobfuscation_script_file_random_name}' || [[ ! -f '${extracted_resources_dir}/${passwords_deobfuscation_script_file_random_name}' ]]; then
	if [[ '${extracted_resources_dir}' == '/private/tmp/'* ]]; then
		rm -rf '${extracted_resources_dir}'
	fi

	package_error='PACKAGE ERROR: Failed to decrypt passwords deobfuscation script (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE).'
	mkuser_installer_display_error 'Did Not Attempt' "\${package_error}"
	>&2 echo "mkuser PREINSTALL \${package_error}"
	exit 1
fi

chmod 000 '${extracted_resources_dir}/${passwords_deobfuscation_script_file_random_name}' # Make passwords deobfuscation script only accessible by root.
PACKAGE_PREINSTALL_EOF

			rm -rf "${package_tmp_dir}/passwords-deobfuscation.scpt"
		fi

		if [[ -f "${package_scripts_dir}/preinstall" ]]; then
			cat << PACKAGE_PREINSTALL_EOF >> "${package_scripts_dir}/preinstall"

exit 0
PACKAGE_PREINSTALL_EOF

			chmod +x "${package_scripts_dir}/preinstall"
		fi

		if [[ "$(echo "${pkg_path}" | tr '[:upper:]' '[:lower:]')" == *'.pkg' ]]; then
			package_tmp_output_path="${package_tmp_dir}/$(basename "${pkg_path}")"
		else
			default_package_name="${pkg_identifier}-${pkg_version}.pkg"
			if (( ${#default_package_name} > 255 )); then
				# If default package name is over 255 characters, build the longest possible filename that includes the most identifier and version info
				# possible by adding characters on one a time for each string until they are fully included or the total filename length is 255 characters.

				pkg_identifier_and_version_max_char=1
				until (( ${#default_package_name} == 255 )); do
					default_package_name="${pkg_identifier:0:pkg_identifier_and_version_max_char}-${pkg_version:0:pkg_identifier_and_version_max_char}.pkg"
					(( pkg_identifier_and_version_max_char ++ ))
				done
			fi

			package_tmp_output_path="${package_tmp_dir}/${default_package_name}"

			if [[ -n "${pkg_path}" && "${pkg_path}" != *'/' ]]; then pkg_path+='/'; fi
			pkg_path+="${default_package_name}"
		fi

		rm -f "${package_tmp_output_path}"

		if ! $suppress_status_messages; then
			echo '' # Line break before "pkgbuild" and "productbuild" output.
		fi

		pkgbuild_options=( '--scripts' "${package_scripts_dir}" )
		pkgbuild_options+=( '--nopayload' )
		pkgbuild_options+=( '--identifier' "${pkg_identifier}" )
		pkgbuild_options+=( '--version' "${pkg_version}" )
		if $suppress_status_messages; then pkgbuild_options+=( '--quiet' ); fi # Inhibits status messages on stdout. Any error messages are still sent to stderr.
		pkgbuild_options+=( "${package_tmp_output_path}" )

		pkgbuild "${pkgbuild_options[@]}" # Intentionally letting "pkgbuild" output to stdout and/or stderr (depending on whether suppress_status_messages is enabled) for useful user feedback.
		pkgbuild_exit_code="$?"

		rm -rf "${package_scripts_dir}"

		if (( pkgbuild_exit_code != 0 )) || [[ ! -f "${package_tmp_output_path}" ]]; then
			rm -rf "${package_tmp_dir}"
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: \"pkgbuild\" (first step in package creation) failed with exit code ${pkgbuild_exit_code}."
			return "${error_code}"
		fi

		package_distribution_xml_output_path="${package_tmp_dir}/distribution.xml"
		rm -f "${package_distribution_xml_output_path}"

		productbuild_synthesize_options=( '--synthesize' )
		productbuild_synthesize_options+=( '--package' "${package_tmp_output_path}" )
		if $suppress_status_messages; then productbuild_synthesize_options+=( '--quiet' ); fi # Inhibits status messages on stdout. Any error messages are still sent to stderr.
		productbuild_synthesize_options+=( "${package_distribution_xml_output_path}" )

		productbuild "${productbuild_synthesize_options[@]}" # Intentionally letting "productbuild" output to stdout and/or stderr (depending on whether suppress_status_messages is enabled) for useful user feedback.
		productbuild_synthesize_exit_code="$?"

		if (( productbuild_synthesize_exit_code != 0 )) || [[ ! -f "${package_distribution_xml_output_path}" ]]; then
			rm -rf "${package_tmp_dir}"
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: \"productbuild --synthesize\" (second step in package creation) failed with exit code ${productbuild_synthesize_exit_code}."
			return "${error_code}"
		fi

		# Need to escape any characters in the package title which would be cause and XML syntax error in the title text value.
		# There are 5 characters that need to be escaped for XML overall, but only the following 2 need to be escaped for a text value: https://stackoverflow.com/a/1091953

		user_full_and_account_name_display_for_package_title_escaped_for_xml="${user_full_and_account_name_display_for_package_title//&/&amp;}"
		user_full_and_account_name_display_for_package_title_escaped_for_xml="${user_full_and_account_name_display_for_package_title_escaped_for_xml//</&lt;}"

		# Need to convert all values that could possibly have multibyte characters to RTF encoding or else they will not be rendered properly within RTF.
		# "textutil" includes a full RTF header and closing "}" as well as a trailing line break that all must be stripped out for our needs.

		# Suppress ShellCheck warning that expressions don't expand in single quotes since this is "awk" code and "$0" are "awk" variables, not bash variables.
		# shellcheck disable=SC2016
		awk_commands_to_extract_rtf_string='print_converted_rtf { if ($0 == "}") { exit } else { print } } ($0 == "MKUSER RTF\\") { print_converted_rtf = 1 }'

		user_full_name_rtf="$(echo $'\nMKUSER RTF\n'"${user_full_name}" | textutil -convert rtf -stdin -stdout | awk "${awk_commands_to_extract_rtf_string}")"
		user_full_name_rtf="${user_full_name_rtf:0:${#user_full_name_rtf}-1}"

		pkg_overview_password_display='*PASSWORD HIDDEN*'
		if [[ "${user_password}" == '*' ]]; then
			pkg_overview_password_display='[NO PASSWORD]';
		elif [[ -z "${user_password}" ]]; then
			pkg_overview_password_display='[BLANK/EMPTY PASSWORD]';
		fi

		user_password_hint_rtf=''
		if [[ -n "${user_password_hint}" ]]; then
			user_password_hint_rtf="$(echo $'\nMKUSER RTF\n'"${user_password_hint}" | textutil -convert rtf -stdin -stdout | awk "${awk_commands_to_extract_rtf_string}")"
			user_password_hint_rtf="${user_password_hint_rtf:0:${#user_password_hint_rtf}-1}"
		fi

		user_home_path_rtf="$(echo $'\nMKUSER RTF\n'"${user_home_path}" | textutil -convert rtf -stdin -stdout | awk "${awk_commands_to_extract_rtf_string}")"
		user_home_path_rtf="${user_home_path_rtf:0:${#user_home_path_rtf}-1}"

		pkg_overview_picture_display='\i [RANDOM PICTURE ASSIGNED DURING CREATION]\i0 '
		if $set_no_picture; then
			pkg_overview_picture_display='\i [NO PICTURE]\i0 ';
		elif [[ -n "${user_picture_path}" ]]; then
			# Only show the picture basename since the picture will actually be stored within the package.
			pkg_overview_picture_display="$(echo $'\nMKUSER RTF\n'"$(basename "${user_picture_path}")" | textutil -convert rtf -stdin -stdout | awk "${awk_commands_to_extract_rtf_string}")";
			pkg_overview_picture_display="${pkg_overview_picture_display:0:${#pkg_overview_picture_display}-1}"
		fi

		user_full_and_account_name_display_rtf="$(echo $'\nMKUSER RTF\n'"${user_full_and_account_name_display}" | textutil -convert rtf -stdin -stdout | awk "${awk_commands_to_extract_rtf_string}")"
		user_full_and_account_name_display_rtf="${user_full_and_account_name_display_rtf:0:${#user_full_and_account_name_display_rtf}-1}"

		# Add title, welcome (overview) and conclusion (success) RTF, and other desired settings attributes to distribution.xml.
		# I wish I didn't have to repeat the following settings summary that is basically the same as the "--check-only" output, but I want it to be rich text
		# with styling for the package welcome info, and there are a few other differences in this output because of not knowing what system it will be installed on.
		# I did try doing all of this RTF text in HTML, which worked fine, but the RTF visibly loads much faster (or at least loads before the window is shown) so sticking with that even though the syntax is less familiar to me.
		# domains enable_localSystem=true: Set domains to only allow installation on current system volume. This make it not possible to change the installation location, which is what we want.
		# volume-check allowed-os-versions os-version min=10.13.0: Do not allow package installation on older than macOS 10.13 High Sierra, which is what the script is tested with and will error if run on older versions.
		# Originally inserted each of these lines into distribution.xml with "sed", but it would fails if welcome or conclusion HTML strings got too long.

		package_distribution_xml_header="$(head -2 "${package_distribution_xml_output_path}")"
		package_distribution_xml_footer="$(tail +3 "${package_distribution_xml_output_path}")"

		cat << CUSTOM_DISTRIBUTION_XML_EOF > "${package_distribution_xml_output_path}"
${package_distribution_xml_header}
    <title>Create ${creating_user_type} ${user_full_and_account_name_display_for_package_title_escaped_for_xml}</title>
    <welcome language="en" mime-type="text/rtf"><![CDATA[{\rtf1\ansi
\fs26 \uc0\u55357 \u56550  \ul User Creation Package\ul0 \line
\b {\field{\*\fldinst HYPERLINK "https://mkuser.sh"}{\fldrslt mkuser}} Version:\b0  ${MKUSER_VERSION}\line
\b Package Identifier:\b0  ${pkg_identifier}\line
\b Package Version:\b0  ${pkg_version}\line
\line
\uc0\u55357 \u56420  \ul Primary Settings\ul0 \line
\b Account Name:\b0  ${user_account_name}\line
\b Full Name:\b0  ${user_full_name_rtf}\line
\b User ID:\b0  ${user_uid:-\i [NEXT AVAILABLE UID STARTING FROM $( ( $set_role_account || $set_service_account ) && echo '200' || echo '501' )]\i0 }\line
\b Generated UID:\b0  ${user_guid:-\i [RANDOM GUID ASSIGNED DURING CREATION]\i0 }\line
\b Group ID:\b0  ${user_gid:-20}\line
\b Login Shell:\b0  ${user_shell:-/bin/zsh \i (on macOS 10.15 Catalina and newer)\i0  \b or\b0  /bin/bash \i (on macOS 10.14 Mojave and older)\i0 }\line
\line
\uc0\u55357 \u56592  \ul Password Settings\ul0 \line
\b Password:\b0  \i ${pkg_overview_password_display}\i0 \line
\b Password Hint:\b0  ${user_password_hint_rtf:-\i [NO PASSWORD HINT]\i0 }\line
\b Prohibit User Password Changes:\b0  \i ${set_prohibit_user_password_changes}\i0 \line
\line
\u55357 \u56513  \ul Home Folder Settings\ul0 \line
\b Home Folder:\b0  ${user_home_path_rtf}\line
\b Hide Home:\b0  \i ${set_hidden_home}\i0 \line
\b Do Not Share Public Folder:\b0  \i ${do_not_share_public_folder}\i0 \line
\b Do Not Create Home Folder:\b0  \i ${do_not_create_home_folder}\i0 \line
\line
\uc0\u55357 \u56764  \ul Picture Settings\ul0 \line
\b Picture:\b0  ${pkg_overview_picture_display}\line
\b Prohibit User Picture Changes:\b0  \i ${set_prohibit_user_picture_changes}\i0 \line
\line
\uc0\u55356 \u57243  \ul Account Type Settings\ul0 \line
\b Administrator:\b0  \i ${set_admin}\i0 \line
\b Hide User:\b0  \i $(! $set_hidden_user && [[ "${user_password}" == '*' ]] && echo 'true\i0  (because NO password)' || echo "${set_hidden_user}\i0 ")\line
\b Sharing Only Account:\b0  \i ${set_sharing_only_account}\i0 \line
\b Role Account:\b0  \i ${set_role_account}\i0 \line
\b Service Account:\b0  \i ${set_service_account}\i0 \line
\b Prevent Secure Token on Big Sur and Newer:\b0  \i ${set_prevent_secure_token_on_big_sur_and_newer}\i0 \line
\b Grant Secure Token from Existing Admin:\b0  \i $([[ -n "${st_admin_account_name}" ]] && echo "true\i0  (from \"${st_admin_account_name}\")" || echo 'false\i0 ')\line
\line
\uc0\u55357 \u57002  \ul Login Settings\ul0 \line
\b Automatic Login:\b0  \i ${set_auto_login}\i0 $($set_auto_login && echo ' (if FileVault is not enabled)')\line
\b Prevent Login:\b0  \i $($user_shell_is_false && echo 'true\i0  (because login shell is "/usr/bin/false")' || echo 'false\i0 ')\line
\b Skip Setup Assistant on First Boot:\b0  \i ${skip_setup_assistant_on_first_boot}\i0 \line
\b Skip Setup Assistant on First Login:\b0  \i ${skip_setup_assistant_on_first_login}\i0
}]]></welcome>
    <conclusion language="en" mime-type="text/rtf"><![CDATA[{\rtf1\ansi
\fs36 \pard\qc \line
\fs128 \uc0\u9989 \fs36 \line
\line
Successfully created \ul ${creating_user_type}\ul0  \b ${user_full_and_account_name_display_rtf}\b0  and all verifications passed!\line
\line
\fs26 \uc0\u55357 \u56550  \ul User Creation Package\ul0 \line
\b {\field{\*\fldinst HYPERLINK "https://mkuser.sh"}{\fldrslt mkuser}} Version:\b0  ${MKUSER_VERSION}\line
\b Package Identifier:\b0  ${pkg_identifier}\line
\b Package Version:\b0  ${pkg_version}
}]]></conclusion>
    <domains enable_localSystem="true"/>
    <volume-check>
        <allowed-os-versions>
            <os-version min="10.13.0"/>
        </allowed-os-versions>
    </volume-check>
${package_distribution_xml_footer}
CUSTOM_DISTRIBUTION_XML_EOF

		# Previously setup a stripped down "check only" version of "mkuser" to run during the "installation-check" in the Installer JS,
		# but this required <options allow-external-scripts="yes"/> which is not considered super secure since it must be allowed to run
		# when the package is opened in the "Installer" app, but it was a cool way to be able to quickly check if the user creation would
		# fail and to present the error graphically without needing "Installer" to prompt for administrator privileges to be able to run the
		# actual "preinstall"/"postinstall" scripts.
		# But, "productbuild" in macOS 12 Monterey warns that <options allow-external-scripts="yes"/> is deprecated and packages that use it
		# won't be able to be installed in a future version of macOS so decided to get rid of that checking.
		# Now, all the checks happen in "preinstall"/"postinstall" after administrator privileges are granted, but I still figured out
		# how to make those checks present graphical alerts when the installation is being done through the GUI "Installer" app and no
		# resources are extracted or user creation is actually attempted when the initial "check only" run of "mkuser" fails.

		# ALSO, previously had a macOS version check using Installer JS similar to this: https://github.com/open-eid/osx-installer/blob/132988de17a3378e1a55eff34e97944b22c87b4b/distribution.xml#L80
		# This worked fine via "Installer" app and "installer" command, but when testing with "startosinstall --installpackage" the package was clearly included and detected during the installation from the logs,
		# but then seemed to never even attempt to be installed by macOS. When I removed the Installer JS macOS version check, the package installed properly via "startosinstall --installpackage".
		# Luckily that macOS version check was not really necessary since the minimum macOS version can and is specified in other ways (volume-check allowed-os-versions os-version min=10.13.0),
		# it was just nice and fancy to have a graphical prompt when the macOS version was too old and the package was being installed via "Installer" app.
		# But, definitely not worth including it since it broke installation via "startosinstall --installpackage"!
		# So, DO NOT use any Installer JS without thorough testing with "startosinstall --installpackage" since I'm not sure if this was an issue with just that macOS version check,
		# or with all Installer JS (https://developer.apple.com/documentation/installer_js) since I didn't bother doing any more testing once "startosinstall --installpackage" worked after removing that code.

		rm -f "${pkg_path}"

		productbuild_options=( '--distribution' "${package_distribution_xml_output_path}" )
		productbuild_options+=( '--package-path' "${package_tmp_dir}" )
		productbuild_options+=( '--identifier' "${pkg_identifier}" )
		productbuild_options+=( '--version' "${pkg_version}" )
		if [[ -n "${pkg_sign}" ]]; then productbuild_options+=( '--sign' "${pkg_sign}" ); fi
		if $suppress_status_messages; then productbuild_options+=( '--quiet' ); fi # Inhibits status messages on stdout. Any error messages are still sent to stderr.
		productbuild_options+=( "${pkg_path}" )

		productbuild "${productbuild_options[@]}" # Intentionally letting "productbuild" output to stdout and/or stderr (depending on whether suppress_status_messages is enabled) for useful user feedback.
		productbuild_exit_code="$?"

		rm -rf "${package_tmp_dir}"

		if (( productbuild_exit_code != 0 )) || [[ ! -f "${pkg_path}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: \"productbuild\" (last step in package creation) failed with exit code ${productbuild_exit_code}."
			return "${error_code}"
		fi

		if ! $suppress_status_messages; then
			# Do an actual line break instead of "\n" which would require "-e" and would incorrectly interpret any possible literal backslashes in the full name.
			echo "
mkuser: Created ${creating_user_type} ${user_full_and_account_name_display} User Creation Package: $([[ "${pkg_path}" == '/'* ]] || echo "${PWD}/")${pkg_path}"
		fi

		return 0
	fi
	# <MKUSER-END-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT> !!! DO NOT MOVE OR REMOVE THIS COMMENT, IT EXISTING AND BEING ON ITS OWN LINE IS NECESSARY FOR PACKAGE CREATION !!!
	(( error_code ++ )) # Put the "<MKUSER-END-CODE-TO-REMOVE-FROM-PACKAGE-SCRIPT>" marker BEFORE incrementing the error_code so that error numbers are consistent whether or not it is a package installation.


	# DO REMAINING SYSTEM SPECIFIC CHECKS BEFORE CREATING THE USER
	# Such as making sure the user doesn't already exist, assigning an unused UID, etc.

	if ! $suppress_status_messages; then
		echo "mkuser: Checking that specified parameters don't conflict with existing users..."
	fi

	if ! $has_invalid_options && ! $check_only && (( ${EUID:-$(id -u)} == 0 )); then
		# Before doing any system specific checks, block simultaneous "mkuser" processes from running past this point at the same time since it could result in the same UID being assigned or user creation failing in a variety of other ways (such as conflicts during SharePoint Group creation).
		# The safest option is to only allow a single "mkuser" process to run past this point at a time, so use "shlock" to wait until other "mkuser" processes are finished before proceeding with any checks or user creation.
		# This correctly queues multiple simultaneous processes, but they are not guaranteed to run in order of execution, which I think is fine. If order is required, do not start simultaneous "mkuser" processes.
		# Thanks to Thomas Esser for noticing this possible simultaneous execution issue and for suggesting using "shlock" (and "trap") to avoid it as well as suggesting storing the lock file in the secure "/private/var/run" folder which is only accessible by root.

		# Do not bother blocking simultaneous "mkuser" processes if has_invalid_options, check_only, or make_package (which will have already completed before getting here) since a user would never be created on this system in these cases
		# which mean the simultaenous runs would not actually conflict with each other in a meaningful way (even though the "--check-only" output may not be the same as what gets assigned during an actual user creation, such as the UID).

		# Also, do not bother blocking simultaneous "mkuser" processes if not running as root since a user would never be created, but especially because "/private/var/run" is only accessibly by root and a non-root process would infinite loop when trying to check the file via "shlock".

		# Use "trap" to catch all EXITs to always delete the '/private/var/run/mkuser.pid' file upon completion. This appears to always run for any "return" statement, and also runs after SIGINT in bash, but that may not be true for other shells: https://unix.stackexchange.com/questions/57940/trap-int-term-exit-really-necessary
		trap "rm -rf '/private/var/run/mkuser.pid'" EXIT # Even though this command runs last, it does NOT seem to override the final exit code specified by the "return" statements throughout the "mkuser" function.

		while ! shlock -p "${subshell_function_pid}" -f '/private/var/run/mkuser.pid' &> /dev/null; do # Loop and sleep until no other "mkuser" processes are running.
			if ! $suppress_status_messages; then
				echo "mkuser NOTICE: Waiting for another \"mkuser\" process (PID $(head -1 '/private/var/run/mkuser.pid' 2> /dev/null || echo '?')) to finish before starting system specific checks and user creation for this one (PID ${subshell_function_pid})."
			fi

			sleep 3
		done
	fi

	# Search for existing account and full names using RecordName and RealName with "dscl" instead of using "id" so we know we specifically what existing user and name we are finding, "id" is just not precise enough.
	# Also use "dscl /Search" instead of "dscl ." for all existing user checks so that any Active Directory users are found as well. Do not want to accidentally make a local user that is a duplicate of an Active Directory user.

	if ! $suppress_status_messages && [[ $'\n'"$(dscl localhost -list /)"$'\n' == *$'\nActive Directory\n'* ]]; then
		echo 'mkuser NOTICE: Since Active Directory is configured on this system, these checks may take a few moments if AD is currently connected...'
	fi

	if dscl /Search -read "/Users/${user_account_name}" RecordName &> /dev/null; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Account name \"${user_account_name}\" already exists."
		return "${error_code}"
	fi
	(( error_code ++ ))

	# Also make sure an existing full name doesn't have the desired account name.
	assigned_account_name_as_full_name_dscl_search="$(dscl /Search -search /Users RealName "${user_account_name}" 2> /dev/null)"
	if [[ -n "${assigned_account_name_as_full_name_dscl_search}" ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Account name \"${user_account_name}\" already assigned to full name of \"$(echo "${assigned_account_name_as_full_name_dscl_search}" | awk '{ print $1; exit }')\"."
		return "${error_code}"
	fi
	(( error_code ++ ))

	assigned_full_name_dscl_search="$(dscl /Search -search /Users RealName "${user_full_name}" 2> /dev/null)" # Luckily, this RealName search is case-insensitive.
	if [[ -n "${assigned_full_name_dscl_search}" ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Full name \"${user_full_name}\" already assigned to \"$(echo "${assigned_full_name_dscl_search}" | awk '{ print $1; exit }')\"."
		return "${error_code}"
	fi
	(( error_code ++ ))

	# Also make sure an existing account name doesn't have the desired full name.
	if dscl /Search -read "/Users/${user_full_name}" RecordName &> /dev/null; then # Luckily, this RecordName query is also case-insensitive.
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Full name \"${user_full_name}\" already taken by an existing users account name."
		return "${error_code}"
	fi
	(( error_code ++ ))

	# UIDs CAN BE REPRESENTED IN DIFFERENT FORMS (this also applieds to GIDs)
	# When viewing UIDs/GIDs in "dscacheutil", they are always displays in their signed 32-bit integer form (-2147483648 through 2147483647).
	# While the "id" command always displays their UNsigned 32-bit integer form (0 through 4294967295).
	# And "dscl" displays the actual assigned UID integer which has no actual range limit and could be any integer that would map back to a UID in the 32-bit range (this is also the value stored directly in the dslocal plist files).
	# Even though any actual UID could be assigned to a user via "dscl", both "id" and "dscacheutil" stop converting them to their 32-bit integer form if they are outside of the signed *64-bit* integer range of -9223372036854775808 (equivalent to signed 32-bit "0") through 9223372036854775807 (equivalent to signed 32-bit "-1").
	# Any actual UID lower than the signed 64-bit integer minimum is also interpreted as 0 by "dscacheutil" and anything higher than the signed 64-bit integer maximum is interpreted as -1 by "dscacheutil".
	# The "id" command also maxes out at the signed 64-bit integer range. If something is below it, it is interprested as the UNsigned 32-bit miniumum of 0 and above gets interpreted as the UNsigned 32-bit maximum of 4294967295.
	# When an integer is within the signed 64-bit range, to convert it to it's signed 32-bit form can be done by first using modulo (UID % 4294967296) and then if that result is within the signed 32-bit range, we're done, but if it's less than the signed 32-bit minimum ADD 4294967296 and if it's greater than the signed 32-bit maximum SUBTRACT 4294967296.
	# For more specifics about converting integers to their signed 32-bit integer equivalent, see the code and comments in the "mkuser_convert_to_signed_32_bit_integer" function below.

	# While all UIDs forms are technically valid to macOS, the signed 32-bit integer form makes the most sense when it comes to assigning negative UIDs.
	# For example, the "nobody" user is both UID -2 (as returned by "dscacheutil" and "dscl" as that is what is actually assigned) AND also UID 4294967294 (as is returned by "id"), but if someone were to manually assign a new user to
	# UID 4294967294 using "dscl" it would be allowed since it's not already assigned as and actual UID according to "dscl" and manual calculation would be needed to know whether or not this would conflict with an existing UID in the signed 32-bit integer form.
	# If we allowed any range, someone could also assign -8589934594 and/or -4294967298 and/or 8589934590 and/or 12884901886 and so on which all also equal UID -2 when converted to the signed 32-bit integer form.
	# This applies to any and all UIDs, for example: 502 = -17179868682 = -12884901386 = -4294966794 = 4294967798 = 8589935094 = 12884902390, etc.
	# Now, it is possible to covert any and all of these UIDs to their signed 32-bit form to check if it exists, but it would be extremely tedious to manually check if *any possible form* of any UID already exists.
	# We can avoid the first half of this complexity by only allowing UIDs in within the signed 32-bit integer range, but if we were to only check for existing UIDs using "dscl . -list /Users", we would not find all possible conflicts because the actual UIDs in an infinite range would be returned in that list.
	# ALL of this possible complexity can be avoided if we only ever allow UIDs in the signed 32-bit integer range AND only ever check for existing UIDs using "dscacheutil" which will always be in their signed 32-bit integer form.
	# Nothing stops people from creating accounts with conflicting UIDs themselves using "dscl" directly, but "mkuser" will not contribute to any possible conflicting UIDs this way.

	# BUT, the one big issue with SOLELY relying on getting all users from the output of "dscacheutil -q user" is that it only includes *local* users and cached Active Directory (AD) users (which have logged in before).
	# To easily get *SOME* AD users (but not necessarily all because of LDAP listing limits) that are not cached (which have not logged in before), "dscl /Search -list /Users UniqueID" can be used which will have the actual UIDs in an infinite range rather than their signed 32-bit integer form.
	# For more information about the LDAP listing limitations, see comments under the "dscl /Search -list /Users UniqueID" command below.
	# While AD UIDs should generally be limited to the signed 32-bit integer range because of how the Active Directory plugin assigns UIDs (https://themacwrangler.wordpress.com/2016/11/29/reversing-the-ad-plugin-uid-algorithm/ & https://community.jamf.com/t5/jamf-pro/very-bad-active-directory-bug-in-osx/td-p/76831)
	# which will always be in the signed 32-bit integer range (and could even assign multiple users the same UID), it is still possible for the UID of an AD user to be assigned in different ways which could be in any range and may need to be converted into the signed 32-bit integer range.
	# So, even though it's likely increadibly rare, this conversions is still important for all possible edge cases. Thanks so Simon Andersen and Thomas Esser for helping me understand and test these limitations and behaviors.
	# Also, here is an example of LDAP assigning UIDs outside of the signed 32-bit interger range: https://www.rskgroup.org/macos/no-login-window-icon-if-your-uid-is-too-large

	# You can query an AD user that has not logged in yet directly with "dscacheutil -q user -a name" to get their signed 32-bit integer UID, but that will also needlessly load them into the Directory Services (DS) cache.
	# Since we don't want to excessively cache possibly tons of AD users that have not logged in before, we could only do this for users whose UIDs are outside of the signed 32-bit integer range.
	# Instead of querying AD users directly with "dscacheutil -q user -a name", I decided to go ahead an convert the UIDs to their signed 32-bit integer form manually with the "mkuser_convert_to_signed_32_bit_integer" function below.
	# Some reasons I decided to do this were speed and not unnecessarily loading AD users into the DS cache, but also because I found one teeny tiny edge case that "dscacheutil -q user -a name" would not be able to convert a UID for us.
	# "dscacheutil -q user -a name" WILL NOT show an existing user if it does not have both a UniqueID AND PrimaryGroupID, but they will show up in "dscl /Search -list /Users UniqueID".
	# This would be possible would be if someone created the user manually with "dscl" (for example), but if that user also had a UID that was outside of the signed 32-bit integer range,
	# that would make it possible for mkuser to accidentally allow a user with a conflicting UID to be created.
	# This this is a pretty tiny possibilty that I only really became aware of through absurd testing in trying break as much as I possibly could,
	# it can be made a non-issue by manually converting all UIDs to their signed 32-bit integer form instead relying on "dscacheutil -q user -a name" to do it for us.

	# Some notes about weird and invalid UIDs/GIDs: If a UID or GID has leading 0's, then both "dscacheutil" and "id" just interpret the number without the leading zeros (even if it's negative).
	# This makes it VERY EASY to accidentally allow duplicate UIDs if leading zeros are not removed, so leading zeros are always removed when validating specified UIDs/GIDs and when they are detected within "mkuser_convert_to_signed_32_bit_integer".
	# If a UID/GID is created using "dscl" (for example) to not be a valid integer (containing letters, etc), the users are not found by "dscacheutil -q user -a name" or "id", but still show in "dscl" with their invalid UID/GID.
	# But, for invalid UIDs/GIDs in the full "dscacheutil -q user" output, the user is included with a UID/GID of the numbers up to the first invalid character, if there are no numbers or it doesn't start with a number, 0 is used instead.
	# "mkuser_convert_to_signed_32_bit_integer" will interpret invalid UIDs/GIDs in this same way by only using any leading valid integer, or using 0 if there is no valid leading integer. (But these kind of invalid UIDs/GIDs are not allowed as parameter input for "mkuser".)

	this_signed_32_bit_integer='0'
	mkuser_convert_to_signed_32_bit_integer() { # This function will convert any number into the signed 32-bit integer range the same way that "dscacheutil" does for UIDs and GIDs.
		# this_signed_32_bit_integer IS NOT LOCAL to this function, so that is can be referenced after calling the function without needing a subshell (https://rus.har.mn/blog/2010-07-05/subshells/).

		if [[ -n "$1" ]]; then
			local original_integer_was_negative=false
			if [[ "$1" == '-'* ]]; then original_integer_was_negative=true; fi

			if [[ "$1" =~ ^\-?[${DIGITS}]+$ ]]; then # Make sure it's a valid positive or negative integer.
				this_signed_32_bit_integer="$1"
			else # If not a valid integer, extract any valid number from the ONLY the beginning of the string.
				local this_possible_signed_32_bit_integer="$1"
				if $original_integer_was_negative; then this_possible_signed_32_bit_integer="${this_possible_signed_32_bit_integer:1}"; fi # Remove single minus sign before extracting valid leading numbers (which will be added back),
				# since only a single minus sign is allowed for negative numbers and leaving it on would make all negative numbers appear invalid in the next step.
				this_possible_signed_32_bit_integer="${this_possible_signed_32_bit_integer%%[^"${DIGITS}"]*}" # Extract only leading numbers up to the first non-number character.

				if [[ -n "${this_possible_signed_32_bit_integer}" ]]; then
					this_signed_32_bit_integer="${this_possible_signed_32_bit_integer}"
					if $original_integer_was_negative; then this_signed_32_bit_integer="-${this_signed_32_bit_integer}"; fi # Add back minus sign if it was a valid negative number.
				else # Any input that did not have a valid leading number is interpreted as 0.
					this_signed_32_bit_integer='0'
				fi
			fi

			if [[ "${this_signed_32_bit_integer}" == '0'* || "${this_signed_32_bit_integer}" == '-0'* ]]; then
				this_signed_32_bit_integer="${this_signed_32_bit_integer//[^${DIGITS}]/}" # Need to temporarily remove any minus sign to remove leading zeros.
				this_signed_32_bit_integer="$($original_integer_was_negative && echo '-')${this_signed_32_bit_integer#"${this_signed_32_bit_integer%%[^0]*}"}" # Remove any leading zeros and add back any minus sign.
				if [[ -z "${this_signed_32_bit_integer}" || "${this_signed_32_bit_integer}" == '-' ]]; then this_signed_32_bit_integer='0'; fi # Catch if the number was all zeros with or without a minus sign.
			fi

			if [[ "$(( this_signed_32_bit_integer ))" != "${this_signed_32_bit_integer}" ]]; then
				# bash arithmetic cannot handle numbers outside of the signed 64-bit range, they just rollover.
				# We can detect this rollover by seeing if the arithmetic value is not equal to the string value.

				if $original_integer_was_negative; then # If it was negative, then it was lower than the 64-bit integer minimum and should be interpreted as "0".
					this_signed_32_bit_integer='0'
				else # If it was positive, then it was higher than the 64-bit integer maximum and should be interpreted as "-1".
					this_signed_32_bit_integer='-1'
				fi
			elif (( this_signed_32_bit_integer < -2147483648 || this_signed_32_bit_integer > 2147483647 )); then
				this_signed_32_bit_integer="$(( this_signed_32_bit_integer % 4294967296 ))" # First, get modulo of 1 more than UNsigned 32-bit integer maximum (which is the amount of numbers that can exist in the signed/unsigned 32-bit range, including 0).
				# If the result is within the signed 32-bit integer range, we're done.

				if (( this_signed_32_bit_integer < -2147483648 )); then # If it's less than signed 32-bit integer minimum, ADD 1 more than UNsigned 32-bit integer maximum.
					this_signed_32_bit_integer="$(( this_signed_32_bit_integer + 4294967296 ))"
				elif (( this_signed_32_bit_integer > 2147483647 )); then # If it's greater than signed 32-bit integer maximum, SUBTRACT 1 more than UNsigned 32-bit integer maximum.
					this_signed_32_bit_integer="$(( this_signed_32_bit_integer - 4294967296 ))"
				fi
			fi
		fi

		# DO NOT ECHO this_signed_32_bit_integer since it will be referenced directly without needing a subshell.
	}

	dscacheutil_users="$(dscacheutil -q user)" # This will get all local users and Active Directory (AD) users that have logged in before and UIDs will be in signed 32-bit integer form.

	all_assigned_uids="$(echo "${dscacheutil_users}" | awk -F ': ' '($1 == "uid") { print $2 }')" # Will be sorted after all have been added.

	dscl_search_users="$(dscl /Search -list /Users UniqueID)" # This will get all local users and *SOME* Active Directory (AD) users regardless of whether or not they are cached (ie. have logged in before),
	# but UIDs will be the actual assigned UIDs which could possibly (but very unlikely) be outside of the signed 32-bit integer form even though macOS will still interpret them as their signed 32-bit form (so they must be converted).
	# This will only get *SOME* AD users because the results are limited by the configured LDAP listing limits, which is often 1000 records, but could be set to anything. Thanks to Simon Andersen for informing me of this limitation.
	# Even though this won't get ALL possible AD users, it's still worth retrieving as many uncached AD users as we can to be as thorough as possible.
	# The worst case scenario is that a next available UID is incorrectly assigned by "mkuser" that is actually assigned to an AD user that did not show up in this list,
	# but that will be caught by a fallback "dscl /Search -search /Users UniqueID" check which will find the UID regardless of LDAP listing limits and then "mkuser" will exit with an error instead of making an incorrect user.
	# If this were to happen, the user would need to manually assign their desired UID instead of relying on "mkuser" to find the next available UID.
	# But, this kind of UID assignment issue should be increadibly rare since AD UIDs are generally in the millions range or higher and UIDs assigned by "mkuser" only start at 200 or 501 and it would be absurdly rare for every one of those UIDs up to a million to be already assigned.

	uncached_ad_users="$(awk '(FNR == NR) { if ($1 == "name:") { dscacheutil_account_names[$2] } next } ((NF == 2) && !($1 in dscacheutil_account_names))' <(echo "${dscacheutil_users}") <(echo "${dscl_search_users}"))"
	# I previously used "comm" with lists of only account names (without UIDs) to get a list of only uncached AD account names which was fast and worked very well, but then I needed to use "awk" for each account name
	# to get the associated UID from the full contents of dscl_search_users which ended up actually taking minutes if there were a thousands of uncached AD users. Thanks to Thomas Esser for discovering this performance issue.
	# Using this "awk" comparison (based on http://awk.freeshell.org/ComparingTwoFiles) is very fast and allows me to get the whole account name and UID row for each uncached AD user instead of only comparing lists of account names.
	# I can then loop this output allowing bash to split at all whitespace to logically set the account name and UID to seperate variables within the loop. This technique made a process that could take many minutes just take a few seconds.

	if [[ -n "${uncached_ad_users}" ]]; then
		uncached_ad_users_count="$(echo "${uncached_ad_users}" | wc -l)"
		uncached_ad_users_count="${uncached_ad_users_count// /}" # Remove the leading spaces that "wc -l" includes since this number could be printed in a sentence.

		if (( uncached_ad_users_count > 4000 )); then # Example processing time for amounts of users where most also need UIDs converted: 4K=2s 10K=4s 20K=8s (it might be up to a 1 second faster if many UIDs don't need to be converted)
			echo "mkuser NOTICE: It may take a moment to collect User IDs for ${uncached_ad_users_count} uncached Active Directory users (this IS NOT querying AD repeatedly and IS NOT caching these AD users)..."
		fi

		this_uncached_ad_account_name=''
		for this_uncached_ad_account_name_or_uid in ${uncached_ad_users}; do # Let bash split the names and UIDs and assign them to variables based on position in loop since its MUCH faster (ie. seconds instead of MINUTES) than many other ways of getting each of these values into their own variables.
			if [[ -n "${this_uncached_ad_account_name_or_uid}" ]]; then
				if [[ -z "${this_uncached_ad_account_name}" ]]; then # If this_uncached_ad_account_name is empty, this element must be the account name.
					this_uncached_ad_account_name="${this_uncached_ad_account_name_or_uid}"
				else # If this_uncached_ad_account_name IS NOT empty, this element must be the UID.
					mkuser_convert_to_signed_32_bit_integer "${this_uncached_ad_account_name_or_uid}"

					dscacheutil_users+="
name: ${this_uncached_ad_account_name}
uid: ${this_signed_32_bit_integer}" # Add these missing AD users to the dscacheutil_users output so that the user name can always be displayed when the UID is already taken.

					all_assigned_uids+=$'\n'"${this_signed_32_bit_integer}" # If this UID is within the signed 32-bit integer range, just add it to all_assigned_uids.

					this_uncached_ad_account_name='' # MUST reset this_uncached_ad_account_name to empty to we know the next element is an account name.
				fi
			fi
		done
	fi

	# Since account names that start with a dot/period (.) do not show up in "dscacheutil -q user" (or "dscl . -list /Users"), we must check for those manually from the "dslocal" plist files.
	# Account names like this are NOT allowed to be create by "mkuser", but they could be created by System Preferences and "sysadminctl -addUser", etc.
	# If we do not check for them, their possible existence could mess up the next available UID assigning, as their existence messes up the next available UID checks in System Preferences and "sysadminctl -addUser".
	# These account names existing can cause System Preferences and "sysadminctl -addUser" to keep trying to assign the same UID which is already assigned to a hidden account which starts with a period, resulting in all new users being created with NO UID at all.
	# To avoid this (rare but serious) possible issue, we must do this manually search for any account names that start with a period.
	# These account UIDs directly from the plist files, will be the actual assigned UID (like "dscl" returns) which could possibly be outside of the signed 32-bit integer range, so they must also be converted into the signed 32-bit integer range.
	# Once we know these account names, they could be queried directly with "dscacheutil -q user -a name", but like before we will instead convert their UIDs to the signed 32-bit integer form manually.

	for this_dot_user_plist in '/private/var/db/dslocal/nodes/Default/users/.'*'.plist'; do
		if [[ -f "${this_dot_user_plist}" ]]; then
			mkuser_convert_to_signed_32_bit_integer "$(PlistBuddy -c 'Print :uid:0' "${this_dot_user_plist}" 2> /dev/null)"

			dscacheutil_users+="
name: $(basename "${this_dot_user_plist}" '.plist')
uid: ${this_signed_32_bit_integer}" # Add these missing dot users to the dscacheutil_users output so that the user name can always be displayed when the UID is already taken.

			all_assigned_uids+=$'\n'"${this_signed_32_bit_integer}"
		fi
	done

	all_assigned_uids="$(echo "${all_assigned_uids}" | sort -un)" # Sort UIDs now that all have been added.

	did_assign_uid=false
	if [[ -z "${user_uid}" ]]; then
		# Cannot leave UID unspecified to let "dsimport" assign UIDs (even when using "--startid") since it starts from 1025, and
		# trying to set a lower UID using "--startid" will error with "--startid must be 1024 or greater" for whatever reason.

		# Start at the first UID that macOS assigns by default (501) and check for unused UIDs and use the lowest unused UID.
		# This mirrors the same behavior as "sysadminctl -addUser" and System Preferences, while "dscl . -create" does not assign any default UID.
		# Oddly, after 501 has been assigned, "sysadminctl -addUser" seems to always skip 502 and go straight to 503 as well as skip all of 701-899 and then increment by 2's after 900 but we will not replicate that very odd (and incorrect?) behavior.
		# Thanks to Simon Andersen for discovering this weird UID assignment behavior after UID 700.
		# In at least macOS *12.1* Monterey, "sysadminctl -addUser" appears to no longer skip 502, but still has the other odd UID skipping behavior as described above.

		starting_uid="$( ( $set_role_account || $set_service_account ) && echo '200' || echo '501' )" # Normal users start at UID 501. Role Accounts start at UID 200 (and go through UID 400, which will be verified below). Service Account will also start at UID 200 if not specified, has no limited range.
		user_uid="${starting_uid}"

		IFS=$'\n'
		for this_assigned_uid in ${all_assigned_uids}; do
			if (( "${this_assigned_uid}" == user_uid )); then
				(( user_uid ++ ))
			elif (( "${this_assigned_uid}" > user_uid )); then
				break
			fi
		done
		unset IFS

		max_allowed_uid="$($set_role_account && echo '400' || echo '2147483647')" # If a UID is being dynamically assigned to a Role Account (and NOT a Service Account), check that it didn't go above 400 in case UIDs 200-400 have all already been assigned. Otherwise, just make sure it's not over the signed 32-bit integer maximum.
		if (( user_uid > max_allowed_uid )); then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: $($set_role_account && echo 'Role Account ')User IDs cannot be over ${max_allowed_uid}, all User IDs in the range ${starting_uid}-${max_allowed_uid} already been assigned."
			return "${error_code}"
		fi

		did_assign_uid=true
	fi
	(( error_code ++ ))

	# Still need to verify that the UID does not exist if it was specified explicitly rather than just assigned dynamically. And, these checks are an extra safety net to make sure the UID assignment worked properly.
	if [[ $'\n'"${all_assigned_uids}"$'\n' == *$'\n'"${user_uid}"$'\n'* ]]; then
		# When using bash variables in "awk", set a command specific environment variable and then retrieve it in "awk" using "ENVIRON" array because any other technique would cause "awk" to incorrectly interpret backslash characters instead of treating them literally (even though this particular variable should never have backslashes).
		assigned_uid_dscacheutil_user="$(echo "${dscacheutil_users}" | AWK_ENV_USER_ID="${user_uid}" awk -F ': ' '($1 == "name") { this_name = $2 } ($1 == "uid" && $2 == ENVIRON["AWK_ENV_USER_ID"]) { print this_name }' | sort -u)"
		assigned_uid_dscacheutil_user="${assigned_uid_dscacheutil_user//$'\n'/", "}" # If somehow it's taken by multiple users, show them all seperated by commas.
		# To show the user who already has this UID:
		# DO NOT use "dscl /Search -search /Users UniqueID" since those UIDs are not guaranteed to be in the signed 32-bit integer range.
		# CAN'T use "dscacheutil -q user -a uid" since it doesn't accept negative UIDs as parameters, so must "grep" all of "dscacheutil -q user" output instead.
		# And, dscacheutil_users is already loaded above AND any possible missing AD and dot users are also also added to the output so that this check will be the most accurate and complete possible.

		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: User ID \"${user_uid}\" already assigned to \"${assigned_uid_dscacheutil_user}\"."
		return "${error_code}"
	else
		assigned_uid_dscl_search="$(dscl /Search -search /Users UniqueID "${user_uid}" 2> /dev/null)"
		if [[ -n "${assigned_uid_dscl_search}" ]]; then
			# It is important to search for the UID specifically since its not possible to list all AD users and some AD UIDs could
			# have been omitted from previous listings while this direct query will find it regardless of LDAP listing limitations.

			assigned_uid_account_name="$(echo "${assigned_uid_dscl_search}" | awk '{ print $1; exit }')"

			if $did_assign_uid; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: User ID assignment chose \"${user_uid}\", but it's already assigned to \"${assigned_uid_account_name}\" (THIS SHOULD NOT NORMALLY HAPPEN, PLEASE REPORT THIS ISSUE)."
			else
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: User ID \"${user_uid}\" already assigned to \"${assigned_uid_account_name}\" (THIS SHOULD NORMALLY BE DETECTED IN THE PREVIOUS CHECK, PLEASE REPORT THIS ISSUE)."
			fi

			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if [[ -n "${user_guid}" ]]; then
		assigned_guid_dscl_search="$(dscl /Search -search /Users GeneratedUID "${user_guid}" 2> /dev/null)"
		if [[ -n "${assigned_guid_dscl_search}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Generated UID \"${user_guid}\" already assigned to \"$(echo "${assigned_guid_dscl_search}" | awk '{ print $1; exit }')\"."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	# GIDs have the same 32-bit integer range complexity as UIDs, so we need to do all the same things for GIDs that we did above for UIDs.
	# This list of all_assigned_uids will also be used later in the code if and when creating a new SharePoint Group.
	# See "UIDs CAN BE REPRESENTED IN DIFFERENT FORMS" comments and following comments within code above for details about each of these steps.

	dscacheutil_groups="$(dscacheutil -q group)"

	all_assigned_gids="$(echo "${dscacheutil_groups}" | awk -F ': ' '($1 == "gid") { print $2 }')" # Will be sorted after all have been added.

	dscl_search_groups="$(dscl /Search -list /Groups PrimaryGroupID)"

	uncached_ad_groups="$(awk '(FNR == NR) { if ($1 == "name:") { dscacheutil_group_names[$2] } next } ((NF == 2) && !($1 in dscacheutil_group_names))' <(echo "${dscacheutil_groups}") <(echo "${dscl_search_groups}"))"

	if [[ -n "${uncached_ad_groups}" ]]; then
		uncached_ad_groups_count="$(echo "${uncached_ad_groups}" | wc -l)"
		uncached_ad_groups_count="${uncached_ad_groups_count// /}" # Remove the leading spaces that "wc -l" includes since this number could be printed in a sentence.

		if (( uncached_ad_groups_count > 4000 )); then
			echo "mkuser NOTICE: It may take a moment to collect Group IDs for ${uncached_ad_groups_count} uncached Active Directory groups (this IS NOT querying AD repeatedly and IS NOT caching these AD groups)..."
		fi

		this_uncached_ad_group_name=''
		for this_uncached_ad_group_name_or_gid in ${uncached_ad_groups}; do
			if [[ -n "${this_uncached_ad_group_name_or_gid}" ]]; then
				if [[ -z "${this_uncached_ad_group_name}" ]]; then
					this_uncached_ad_group_name="${this_uncached_ad_group_name_or_gid}"
				else
					mkuser_convert_to_signed_32_bit_integer "${this_uncached_ad_group_name_or_gid}"

					dscacheutil_groups+="
name: ${this_uncached_ad_group_name}
gid: ${this_signed_32_bit_integer}" # Add these missing AD groups to the dscacheutil_groups output so that the group name can always be found in the "--check-only" output.

					all_assigned_gids+=$'\n'"${this_signed_32_bit_integer}"

					this_uncached_ad_group_name=''
				fi
			fi
		done
	fi

	for this_dot_group_plist in '/private/var/db/dslocal/nodes/Default/groups/.'*'.plist'; do
		if [[ -f "${this_dot_group_plist}" ]]; then
			mkuser_convert_to_signed_32_bit_integer "$(PlistBuddy -c 'Print :gid:0' "${this_dot_group_plist}" 2> /dev/null)"

			dscacheutil_groups+="
name: $(basename "${this_dot_group_plist}" '.plist')
gid: ${this_signed_32_bit_integer}" # Add these missing dot groups to the dscacheutil_groups output so that the group name can always be found in the "--check-only" output.

			all_assigned_gids+=$'\n'"${this_signed_32_bit_integer}"
		fi
	done

	all_assigned_gids="$(echo "${all_assigned_gids}" | sort -un)" # Sort GIDs now that all have been added.

	if [[ -n "${user_gid}" && $'\n'"${all_assigned_gids}"$'\n' != *$'\n'"${user_gid}"$'\n'* ]]; then
		assigned_gid_dscl_search="$(dscl /Search -search /Groups PrimaryGroupID "${user_gid}" 2> /dev/null)"
		if [[ -n "${assigned_gid_dscl_search}" ]]; then
			# It is important to search for the GID specifically since its not possible to list all AD groups and some AD GIDs could
			# have been omitted from previous listings while this direct query will find it regardless of LDAP listing limitations.

			this_ad_group_name="$(echo "${assigned_gid_dscl_search}" | awk '{ print $1; exit }')"

			dscacheutil_groups+="
name: ${this_ad_group_name}
gid: ${user_gid}" # Add this missing AD group to the dscacheutil_groups output so that the group name can always be found in the "--check-only" output.

			all_assigned_gids+=$'\n'"${user_gid}"
			all_assigned_gids="$(echo "${all_assigned_gids}" | sort -un)" # Re-sort after adding this new one.

			>&2 echo "mkuser WARNING: Group ID \"${user_gid}\" (${this_ad_group_name}) DOES exist, but primary check failed to detect it (CONTINUING ANYWAY, BUT THIS SHOULD NOT NORMALLY HAPPEN, PLEASE REPORT THIS ISSUE)."
		else
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Group ID \"${user_gid}\" does not exist."
			return "${error_code}"
		fi

		# The proper default "PrimaryGroupID" of "20" (staff) will be set during creation if not specified.
	fi
	(( error_code ++ ))

	if [[ -z "${user_shell}" ]]; then
		if (( darwin_major_version >= 19 )); then
			user_shell='/bin/zsh'
		else
			user_shell='/bin/bash'
		fi

		# Cannot leave user_shell unspecified since "dsimport" does not set any "UserShell" by default which will cause problems for the user.
	fi

	if ! $user_home_is_var_empty && ! $user_home_is_dev_null; then # If home folder is set to "/var/empty" or "/dev/null" is will already exist and can be assigned to multiple users.
		assigned_home_folder_path_dscl_search="$(dscl /Search -search /Users NFSHomeDirectory "${user_home_path}" 2> /dev/null)"
		if [[ -n "${assigned_home_folder_path_dscl_search}" ]]; then
			# Also make sure home folder is not assigned to another user (it is possible for a home folder to be assigned but not yet created).

			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Home folder \"${user_home_path}\" already assigned to \"$(echo "${assigned_home_folder_path_dscl_search}" | awk '{ print $1; exit }')\"."
			return "${error_code}"
		fi

		if [[ -e "${user_home_path}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Home folder \"${user_home_path}\" already exists."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if $set_prevent_secure_token_on_big_sur_and_newer && (( darwin_major_version < 20 )); then
		# Disable set_prevent_secure_token_on_big_sur_and_newer if not running on macOS 11 Big Sur and newer.
		# This version check is done after package creation so that the option will always get included when
		# creating a package which could run on different versions of macOS but only enabled when appropriate.

		set_prevent_secure_token_on_big_sur_and_newer=false
	fi

	if $set_auto_login && [[ "$(fdesetup isactive)" == 'true' ]]; then
		# Do not set auto-login when FileVault is enabled (and continue creating user with warning about no auto-login).

		set_auto_login=false
		creating_user_type="${creating_user_type/Auto-Login }"
		>&2 echo 'mkuser WARNING: Auto-login will not be enabled since FileVault is enabled which does not allow auto-login.'
	fi

	if $check_only; then
		check_settings_password_display='*PASSWORD HIDDEN*'
		if [[ "${user_password}" == '*' ]]; then
			check_settings_password_display='[NO PASSWORD]';
		elif [[ -z "${user_password}" ]]; then
			check_settings_password_display='[BLANK/EMPTY PASSWORD]';
		fi

		# When using bash variables in "awk", set a command specific environment variable and then retrieve it in "awk" using "ENVIRON" array because any other technique would cause "awk" to incorrectly interpret backslash characters instead of treating them literally (even though this particular variable should never have backslashes).
		check_settings_user_gid_name="$(echo "${dscacheutil_groups}" | AWK_ENV_USER_GID="${user_gid:-20}" awk -F ': ' '($1 == "name") { this_name = $2 } ($1 == "gid" && $2 == ENVIRON["AWK_ENV_USER_GID"]) { print this_name }' | sort -u)"
		check_settings_user_gid_name="${check_settings_user_gid_name//$'\n'/, }" # If somehow it's taken by multiple users, show them all seperated by commas.
		# DO NOT use "dscl /Search -search /Groups PrimaryGroupID" since those GIDs are not guaranteed to be in the signed 32-bit integer range.
		# CAN'T use "dscacheutil -q group -a gid" since it doesn't accept negative GIDs as parameters, so must "grep" all of "dscacheutil -q group" output instead.
		# And, dscacheutil_groups is already loaded above AND any possible missing AD and dot groups are also also added to the output so that this check will be the most accurate and complete possible.

		check_settings_output="
PRIMARY SETTINGS
Account Name: ${user_account_name}
Full Name: ${user_full_name}
User ID: ${user_uid}
Generated UID: ${user_guid:-[RANDOM GUID ASSIGNED DURING CREATION]}
Group ID: ${user_gid:-20} (${check_settings_user_gid_name})
Login Shell: ${user_shell}

PASSWORD SETTINGS
Password: ${check_settings_password_display}
Password Hint: ${user_password_hint:-[NO PASSWORD HINT]}
Prohibit User Password Changes: ${set_prohibit_user_password_changes}

HOME FOLDER SETTINGS
Home Folder: ${user_home_path}
Hide Home: ${set_hidden_home}
Do Not Share Public Folder: ${do_not_share_public_folder}
Do Not Create Home Folder: ${do_not_create_home_folder}

PICTURE SETTINGS
Picture: $($set_no_picture && echo '[NO PICTURE]' || echo "${user_picture_path:-[RANDOM PICTURE ASSIGNED DURING CREATION]}")
Prohibit User Picture Changes: ${set_prohibit_user_picture_changes}

ACCOUNT TYPE SETTINGS
Administrator: ${set_admin}
Hide User: $(! $set_hidden_user && [[ "${user_password}" == '*' ]] && echo 'true (because NO password)' || echo "${set_hidden_user}")
Sharing Only Account: ${set_sharing_only_account}
Role Account: ${set_role_account}
Service Account: ${set_service_account}
Prevent Secure Token on Big Sur and Newer: ${set_prevent_secure_token_on_big_sur_and_newer}
Grant Secure Token from Existing Admin: $([[ -n "${st_admin_account_name}" ]] && echo "true (from \"${st_admin_account_name}\")" || echo 'false')

LOGIN SETTINGS
Automatic Login: ${set_auto_login}
Prevent Login: $($user_shell_is_false && echo 'true (because login shell is "/usr/bin/false")' || echo 'false')
Skip Setup Assistant on First Boot: ${skip_setup_assistant_on_first_boot}
Skip Setup Assistant on First Login: ${skip_setup_assistant_on_first_login}
"

		if ! $has_invalid_options; then
			if ! $suppress_status_messages; then
				echo "
mkuser: Check passed! Could create ${creating_user_type} ${user_full_and_account_name_display} with the following settings:
${check_settings_output}"
			fi

			return 0
		fi

		>&2 echo "
mkuser ERROR ${error_code}-${LINENO}: Check FAILED! Would NOT create ${creating_user_type} ${user_full_and_account_name_display} with the following settings since INVALID OPTIONS OR PARAMETERS were specified:
${check_settings_output}
Check ERRORS and correct the invalid options or parameters to create a user.
Check \"--help\" for detailed information about each available option."

		return "${error_code}"
	elif $has_invalid_options; then # DO NOT make package if invalid options are specified that could create a user with possibly unintended settings.
		>&2 echo "
mkuser ERROR ${error_code}-${LINENO}: NOT creating ${creating_user_type} ${user_full_and_account_name_display} since INVALID OPTIONS OR PARAMETERS were specified.
Check ERRORS and correct the invalid options or parameters to create a user.
Check \"--help\" for detailed information about each available option."
		return "${error_code}"
	elif (( ${EUID:-$(id -u)} != 0 )); then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: This tool must be run as root."
		return "${error_code}"
	fi
	(( error_code ++ ))

	if ! $do_not_confirm; then
		# Do an actual line break instead of "\n" which would require "-e" and would incorrectly interpret any possible literal backslashes in the full name.
		echo -n "
Enter \"Y\" to Confirm Creating ${creating_user_type} ${user_full_and_account_name_display} on This System: "
		read -r confirm_user_creation

		echo ''

		if ! [[ "${confirm_user_creation}" =~ ^[Yy] ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Did not confirm user creation."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	# After this point, use "dscl ." instead of "dscl /Search" since all subsequent checks will be exclusively for the newly created local user.

	# CREATE USER WITH DSIMPORT
	# Since "dsimport" is the most powerful and flexible, that is what will be used for all user creations instead of "sysadminctl -addUser" or "dscl . -create".
	# - A user must be created with "dsimport" (or "dscl . -create") when preventing Secure Token on macOS 11 Big Sur and newer since that tag must be set
	#   upon user creation or before setting the password, which cannot be done with "sysadminctl -addUser". "dscl . -create" can work for this case since the password
	#   can be set with "dscl . -passwd" after setting the tag, but could not be used in all possible cases because of the last reason mentioned below.
	#   See "set_prevent_secure_token_on_big_sur_and_newer" section below for more information about the tag to prevent Secure Tokens on macOS 11 Big Sur and newer.
	# - A user must be created with "dsimport" (or "dscl . -create") when specifying a "GeneratedUID" since "sysadminctl -addUser" assigns a "GeneratedUID" upon creation
	#   and has no options available to set a desired "GeneratedUID", while "dsimport" and "dscl . -create" can create a user with a specified "GeneratedUID".
	#   To do this with "dscl . -create" the "GeneratedUID" attribute can be added to the initial user creation command: "dscl . -create /Users/[name] GeneratedUID [SOME-GUID]".
	# - Finally, "dsimport" can set a "JPEGPhoto" from a picture path, which cannot be done with "dscl . -create". Setting a user with a picture
	#   can be done with "sysadminctl -addUser", but "sysadminctl -addUser" could not be used in all cases because of the reasons mentioned above.

	# The following order of the attibutes does not matter, but I chose to use the "StandardUserRecord" order for the first 7 attributes as described in "man dsimport" and here:
	# https://support.apple.com/guide/server/create-a-file-to-import-users-apd41051f16/mac#apd31dc619d2b014

	dsimport_record_attributes=( 'RecordName' 'Password' 'UniqueID' 'PrimaryGroupID' 'RealName' 'NFSHomeDirectory' 'UserShell' 'GeneratedUID' 'AuthenticationHint' )
	dsimport_record_values=( "${user_account_name}" "${user_password}" "${user_uid}" "${user_gid}" "${user_full_name}" "${user_home_path}" "${user_shell}" "${user_guid}" "${user_password_hint}" )

	# NOTE: If "user_password" is a empty string, it will be ignored by "dsimport" and no password will be set (preventing login) on macOS 11 Big Sur and newer.
	# But, on macOS 10.15 Catalina and older, some unknown password is set that is not an empty string and login is still prevented.
	# In either this case, the password will be properly set to an empty string after the user has been created using "dscl . -passwd".

	# The only other values that could be empty in the array above are "user_gid", "user_guid", or "user_password_hint" and it's fine if they are ignored by "dsimport"
	# since a "GeneratedUID" will be assigned upon creation and "PrimaryGroupID" will be set to the default of "20" (staff) if not specified.
	# Even though "AuthenticationHint" is not required when no password hint is set, System Preferences and "sysadminctl -addUser" still create the attribute with an empty string when no password hint is set.
	# To be able to replicate this behavior, the "AuthenticationHint" will be set to an empty string after user creation (if no password hint is set) since it cannot be set to an empty string by "dsimport".

	if ! $set_no_picture; then
		chose_random_user_picture=false
		if [[ -z "${user_picture_path}" ]]; then # If user_picture_path was not set (and not explicitly set to no picture) then, choose a random picture like "sysadminctl -addUser" and System Preferences does.
			user_picture_path="$(find '/Library/User Pictures' -type f \( -iname '*.tif' -or -iname '*.png' \) | sort -R | head -1)"
			chose_random_user_picture=true
		fi

		if [[ -f "${user_picture_path}" && "$(file -bI "${user_picture_path}" 2> /dev/null)" == 'image/'* ]] && (( $(stat -f '%z' "${user_picture_path}") <= 1000000 )); then # Still check that we got a picture path in case something went wrong with random picture selection (if something changes in macOS).
			# Add JPEGPhoto using "dsimport" reference: https://apple.stackexchange.com/questions/117530/setting-account-picture-jpegphoto-with-dscl-in-terminal/367667#367667

			dsimport_record_attributes+=( 'externalbinary:JPEGPhoto' )
			dsimport_record_values+=( "${user_picture_path}" )

			if [[ "${user_picture_path}" == '/Library/User Pictures/'* ]]; then
				# If we are using a default picture, also set the Picture attribute to the user_picture_path as "sysadminctl -addUser" and System Preferences does.
				# This is not really necessary and would not set the picture in all location when set without JPEGPhoto: https://www.alansiu.net/2019/09/20/scripting-changing-the-user-picture-in-macos/
				# But, adding the Picture path in this case is simple to create a complete user record just like "sysadminctl -addUser" and System Preferences.
				# If a custom picture is being used, there is no point adding this Picture attribute with the user_picture_path since it could only be stored in a temporary location anyways.

				dsimport_record_attributes+=( 'Picture' )
				dsimport_record_values+=( "${user_picture_path}" )
			fi
		else
			>&2 echo "mkuser WARNING: Failed to get $($chose_random_user_picture && echo 'random' || echo 'specified') user picture at creation time, user will be created without a picture."
		fi
	fi

	if $set_hidden_user; then
		dsimport_record_attributes+=( 'dsAttrTypeNative:IsHidden' ) # Must specify "dsAttrTypeNative" since it is not "dsAttrTypeStandard" (which can be omitted for "dsimport") like the rest.
		dsimport_record_values+=( '1' )
	fi

	if ! $set_service_account; then
		# Add other native attributes that "sysadminctl -addUser" and System Preferences add by default on macOS 10.13 High Sierra through macOS 11 Big Sur. (Unless is it a Service Account.)
		# This is mentioned in: https://gitlab.com/orchardandgrove-oss/NoMADLogin-AD/-/blob/main/Mechs/CreateUser.swift#L31

		dsimport_record_attributes+=( 'dsAttrTypeNative:unlockOptions' )
		dsimport_record_values+=( '0' ) # "unlockOptions" defaults to 0
		# "AvatarRepresentation" is also a default attribute, but it defaults to an empty string which would be ignored by "dsimport" and the attribute would not be created at all, so it will be added after user creation.

		# The following "_writers_" attributes set to the user_account_name are CRITICAL in allowing the user to be able modify the specified attributes on their own without admin authentication.
		# All of these attributes are what "sysadminctl -addUser" and System Preferences adds when creating a new user on macOS 10.13 High Sierra through macOS 11 Big Sur (and there is one new attribute for macOS 11 Big Sur which is added below for that version of macOS and newer).

		dsimport_record_attributes+=( 'dsAttrTypeNative:_writers_AvatarRepresentation' 'dsAttrTypeNative:_writers_unlockOptions' 'dsAttrTypeNative:_writers_UserCertificate' )
		dsimport_record_values+=( "${user_account_name}" "${user_account_name}" "${user_account_name}" )

		# This also means that these "_writers_" attributes can be intentionally omitted (or deleted) to prohibit the user from being able to edit these things without admin authentication.
		# Currently, there are options to prohibit un-admin-authorized modification of the user password and user picture, I'm not sure that prohibiting any of the others would be wise or useful.

		if ! $set_prohibit_user_password_changes; then
			# IMPORTANT: I have intentionally omitted "_writers_passwd" because that one gets added automatically by "dsimport" (or subspequent processes),
			# presumably because of how the plain text password is passed and is then encrypted to the actual ShadowHashData.
			# If the set_prohibit_user_password_changes is enabled, the "_writers_passwd" will be deleted after user creation.

			dsimport_record_attributes+=( 'dsAttrTypeNative:_writers_hint' )
			dsimport_record_values+=( "${user_account_name}" )
		fi

		if ! $set_prohibit_user_picture_changes; then
			dsimport_record_attributes+=( 'dsAttrTypeNative:_writers_jpegphoto' 'dsAttrTypeNative:_writers_picture' )
			dsimport_record_values+=( "${user_account_name}" "${user_account_name}" )
		fi

		# BACKGROUND: I noticed that *some* of these "_writers_" attibuted were set by "pycreateuserpkg" but I did not understand why at first glance, since there are no comments about them: https://github.com/gregneagle/pycreateuserpkg/blob/dcc9ee6d140048aa74fa33f880a4f3c3cb8ada17/locallibs/userplist.py#L29
		# So I initially omitted them from my own code since I didn't want to add things I didn't understand just because another project had added them.
		# Through various digging and investigating other user creation code, I finally stumbled on a comment about these "_writers_" attibutes in: https://gitlab.com/orchardandgrove-oss/NoMADLogin-AD/-/blob/main/Mechs/CreateUser.swift#L21
		# I then tested and confirmed this behavior that users cannot edit their own password when "_writers_passwd" is deleted and can also not edit their own picture when "_writers_jpegphoto" is missing without first authenticating as an admin, which is not default/normal macOS behavior.
		# After that testing, I went ahead and added all of the "_writers_" attributes that "sysadminctl -addUser" and System Preferences create on macOS 10.13 High Sierra through macOS 11 Big Sur (and then added options to intentionally prohibit password and picture modification).
		# NOTE: Both "pycreateuserpkg" AND "NoMADLogin-AD/Mechs/CreateUser.swift" add the "_writers_realname" attributes, but "sysadminctl -addUser" and System Preferences do not include this attribute on macOS 10.13 High Sierra and newer, so I have left it out.
		# Also, even when I tested with this attribute added, I did not see any way to edit the users real name without authenticating as an admin in the Users & Groups list in System Preferences and then going into the "Advanced Options" by right clicking the user, so I am not sure of it's usefulness.

		if (( darwin_major_version >= 20 )); then
			# A new "inputSources" native attribute (along with the associated "_writers_" attribute) was added in macOS 11 Big Sur and defaults to an empty string the same way "AvatarRepresentation" does.
			# Since "inputSources" defaults to empty string (which would be ignored by "dsimport"), only add the "_writers_" attribute here and then add the empty "inputSources" after user creation.
			dsimport_record_attributes+=( 'dsAttrTypeNative:_writers_inputSources' )
			dsimport_record_values+=( "${user_account_name}" )
		fi
	fi

	if $set_prevent_secure_token_on_big_sur_and_newer; then
		# The following information is from: https://support.apple.com/guide/deployment/use-secure-and-bootstrap-tokens-dep24dbdcf9e
		# In macOS 11 or later, setting the initial password for the very first user on the Mac results in that user being granted a secure Token.
		# In some workflows, that may not be the desired behavior, as previously, granting the first secure token would have required the user account to log in.
		# To prevent this from happening, add ";DisabledTags;SecureToken" to the programmatically created user's "AuthenticationAuthority" attribute prior to setting the user's password.

		dsimport_record_attributes+=( 'AuthenticationAuthority' )
		dsimport_record_values+=( ';DisabledTags;SecureToken' )

		# NOTE: This tag MUST be set upon user creation or before setting the password, which is why the user can't be created using "sysadminctl -addUser" for this case.
		# I tried omitting the "-password" option from "sysadminctl -addUser" and then setting the tag and then setting the password with "dscl . -passwd" but
		# the user gets a Secure Token right after "sysadminctl -addUser" is used even when "-password" is omitted (it seems an empty string password is set by "sysadminctl -addUser").
		# On macOS 10.15 Catalina and older, this tag does not prevent a user from being granted a Secure Token.
	fi

	if (( ${#dsimport_record_attributes[@]} != ${#dsimport_record_values[@]} )); then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Number of specified attributes does not match the number specified values (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)."
		return "${error_code}"
	fi
	(( error_code ++ ))

	if ! $suppress_status_messages; then
		echo "mkuser: Creating ${creating_user_type} ${user_full_and_account_name_display} with User ID ${user_uid}..."
	fi

	# The following structure used for the "dsimport" file is fully described in https://support.apple.com/guide/server/create-a-file-to-import-users-apd41051f16/mac#apdd7625a0b981d4

	dsimport_record_description=( '0x0A' ) # End-of-record indicator ("\n" in hex notation)
	dsimport_record_description+=( '0x5C' ) # Escape character ("\" in hex notation)
	dsimport_record_description+=( '0x3A' ) # Field separator (":" in hex notation)
	dsimport_record_description+=( '0x2C' ) # Value separator ("," in hex notation)
	dsimport_record_description+=( 'dsRecTypeStandard:Users' ) # Type of accounts in the file

	# The full record description goes on the first line of the import file and also includes the number of attributes and the attribute names.
	dsimport_record="${dsimport_record_description[*]} ${#dsimport_record_attributes[@]} ${dsimport_record_attributes[*]}"
	dsimport_record+=$'\x0A' # This is just a "\n" newline, but I want to be consistent since the hex code is what is specified as the end-of-record indicator.

	# Escape all special characters in every value (I'm not sure if there are more characters that need to be escaped).
	# The regular characters could be used below instead of hex codes, but I wanted to be consistent since the hex codes are what is specified in the "dsimport" record description.
	dsimport_record_values=( "${dsimport_record_values[@]//$'\x5C\x5C'/$'\x5C\x5C\x5C\x5C'}" ) # Escape all "\x5C" ("\") which is the specified escape character (MUST DO THIS FIRST so the following escaped characters don't get unescaped).
	dsimport_record_values=( "${dsimport_record_values[@]//$'\x0A'/$'\x5C\x5C\x0A'}" ) # Escape all "\x0A" ("\n") which is the specified end-of-record indicator.
	dsimport_record_values=( "${dsimport_record_values[@]//$'\x3A'/$'\x5C\x5C\x3A'}" ) # Escape all "\x3A" (":") which is the specified field separator.
	dsimport_record_values=( "${dsimport_record_values[@]//$'\x2C'/$'\x5C\x5C\x2C'}" ) # Escape all "\x2C" (",") which is the specified value separator (none of our passed values are arrays, but if array values are added in the future this would need to be changed to not escape those values).

	# The record values to import (which match the specified attributes) with values separated by "\x3A" (":") (as specified in the record description) go on subsequent lines (we are only importing one record to create a single user).
	IFS=$'\x3A' # This is just the ":" character, but I want to be consistent since the hex code is what is specified as the field separator.
	dsimport_record+="${dsimport_record_values[*]}"
	unset IFS

	dsimport_file_unique_suffix="$(date '+%s')-$(jot -r 1 100000000 999999999)"
	dsimport_output_plist_path="${TMPDIR:-/private/tmp/}mkuser+${user_account_name:0:255-${#dsimport_file_unique_suffix}-21}+${dsimport_file_unique_suffix}+output.plist" # TMPDIR is not set when running in "sudo bash". Ensure a unique file name that includes as much of the user_account_name as possible without going over the macOS 255 byte maximum.
	rm -f "${dsimport_output_plist_path}" # "dsimport" would probably overwrite the file if it already exist, but delete it to be sure.

	# Was initially manually writing a file and then passing it to "dsimport". Then tried using process substitution instead, but "dsimport" errored with exit code 65 and stderr "Unable to open import file '/dev/fd/11'".
	# Next, I tried specifying "/dev/stdin" and then passing the "dsimport_record" string via here-string and that WORKED to pass a string instead of a file (like it does with "PlistBuddy" as well).
	# Also, like "PlistBuddy", trying to pipe stdin to "dsimport" (instead of using a here-string) also fails (with the same exit code 65 as trying to use process substitution).
	# Using a here-string (or here-doc) DOES momentarily create a temporary file in the filesystem (which I think it why it is able to work with "dsimport" at all),
	# but I believe letting the shell handle the creation and deletion of that file instead of handling it manually in this code will result in the file only existing for least possible time.
	# Also, since this code is guaranteed to be running as root at this point, any temporary file created by the shell would only be readable by another root processes.

	dsimport /dev/stdin '/Local/Default' 'I' --outputfile "${dsimport_output_plist_path}" <<< "${dsimport_record}" # "dsimport" shouldn't output to stdout or stderr, but let it be displayed for useful user feedback if it ever does for some reason.
	# The "I" conflict mode is for Ignore, so that the import will fail if a "RecordName", "UniqueID", "RealName", or "GeneratedUID" already exists (but we know it doesn't from previous checks).
	dsimport_exit_code="$?" # Save the "dsimport" exit code to be checked after reading and deleting the "dsimport_output_plist_path" file.

	# Also save the relevant "dsimport_output_plist_path" contents to be checked after
	# deleting the file since we want to delete it either way (before returning if there was an error).
	dsimport_plist_results="$(grep -B 2 -F "<string>${user_account_name}</string>" "${dsimport_output_plist_path}" 2> /dev/null)"
	rm -f "${dsimport_output_plist_path}"


	# VERIFY DSIMPORT SUCCESSFULLY CREATED USER AND DO FINAL STEPS
	# such as setting as admin if specified, creating home folder, and setting up auto-login if specified.

	if (( dsimport_exit_code != 0 )); then # Do not check "dsimport" exit code directly by putting the command within an "if" since we want to delete the imported file either way (before returning if there was an error).
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: \"dsimport\" failed with non-zero exit code of ${dsimport_exit_code}."
		return "${error_code}"

		# "dsimport" seems to always exit 0 even when it fails to create a user (and never outputs to stdout or stderr), but doesn't hurt to check the exit code anyway.
		# Even though "dsimport" doesn't use stdout or stderr, it can output useful results to a plist specified with the "--outputfile" option, which will be checked next.
	fi
	(( error_code ++ ))

	if [[ "${dsimport_plist_results}" != *'<key>Succeeded</key>'* ]]; then
		# "man dsimport" states that "The format of this file is likely to change in a future release of Mac OS X." in the "--outputfile" section,
		# but I have checked the plist contents in macOS 10.13 High Sierra and macOS 11 Big Sur and it seems to be the same across those versions.
		# The expected contents of "dsimport_output_plist_path" are as follows:
			# <?xml version="1.0" encoding="UTF-8"?>
			# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
			# <plist version="1.0">
			# <dict>
			# 	<key>Deleted</key>
			# 	<array/>
			# 	<key>Failed</key>
			# 	<array/>
			# 	<key>Groups</key>
			# 	<array/>
			# 	<key>Succeeded</key>
			# 	<array>
			# 		<string>user_account_name</string>
			# 	</array>
			# 	<key>Users</key>
			# 	<array>
			# 		<string>user_account_name</string>
			# 	</array>
			# 	<key>Users not imported because of bad short names</key>
			# 	<array/>
			# </dict>
			# </plist>
		# When an error occurs, the user_account_name would be listed within the "Failed" and/or "Users not imported because of bad short names" keys and not the "Succeeded" key.

		# If the user is listed in the "Failed" and/or "Users not imported because of bad short names" keys, they
		# should NOT be in the "Users" key, but ignore it anyway just in case since it's not a useful failure reason.
		dsimport_failure_reasons="$(echo "${dsimport_plist_results}" | awk -F '<key>|</key>' '/<\/key>$/ && ($2 != "Users") { print $2 }')"
		dsimport_failure_reasons="${dsimport_failure_reasons//$'\n'/ + }"

		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: \"dsimport\" failed with reasons: ${dsimport_failure_reasons:-UNKNOWN}"
		return "${error_code}"
	fi
	(( error_code ++ ))

	# Now, to be extra thorough, independently confirm that the user got created (and do the final steps).

	if ! $suppress_status_messages; then
		echo "mkuser: Verifying ${user_full_and_account_name_display} user creation..."
	fi

	if ! dscl . -read "/Users/${user_account_name}" RecordName &> /dev/null || ! id -- "${user_account_name}" &> /dev/null; then
		# Check for user with "dscl" instead of only using "id" so we know we are finding a user with the actual account name, "id" alone is just
		# not precise enough (but still check it to be extra thorough since we want to know all typical user commands work properly for this new user).

		did_detect_user_after_delay=false
		for (( detect_user_delay_seconds = 1; detect_user_delay_seconds <= 5; detect_user_delay_seconds ++ )); do
			# When testing outrageously long passwords (in the megabytes range), sometimes the user was not detected immediately after creation and the "Failed to detect account name" error would be hit.
			# But, when I would check for the user myself manually, it would exist. So, it seems in some extreme cases, waiting a second or two after creation is important to be able to detect the user.
			# Even though these outrageously long passwords are not allowed to be used, it doesn't hurt to keep this extra delayed check in here just in case since it won't get hit if the user if detected immediately.

			sleep 1
			if dscl . -read "/Users/${user_account_name}" RecordName &> /dev/null && id -- "${user_account_name}" &> /dev/null; then
				did_detect_user_after_delay=true
				break
			fi
		done

		if $did_detect_user_after_delay; then
			>&2 echo "mkuser WARNING: Detected ${user_full_and_account_name_display} user after ${detect_user_delay_seconds} second delay."
		else
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Failed to detect account name \"${user_account_name}\" after user creation."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	created_dscacheutil_user="$(dscacheutil -q user -a name "${user_account_name}")" # Retrieve user info from "dscacheutil" to verify all values from cache
	# as well as the keys we want to compare against from "dscl" to make sure the new user has been properly created and cached.
	# Only get "dscl" keys we check instead of all of them to load much faster (as well as save a bit of RAM) by not unnecessarily loading picture data, etc.
	created_dscl_user="$(dscl -plist . -read "/Users/${user_account_name}" UniqueID PrimaryGroupID NFSHomeDirectory UserShell RealName GeneratedUID 2> /dev/null)"

	created_user_uid="$(PlistBuddy -c 'Print :dsAttrTypeStandard\:UniqueID:0' /dev/stdin <<< "${created_dscl_user}" 2> /dev/null)"
	if [[ "${created_user_uid}" != "${user_uid}" || $'\n'"${created_dscacheutil_user}"$'\n' != *$'\n'"uid: ${user_uid}"$'\n'* ]]; then
		>&2 echo -e "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but with incorrect User ID (${created_user_uid:-N/A} != ${user_uid}).\n${created_dscacheutil_user}"
		return "${error_code}"
	fi
	(( error_code ++ ))

	created_user_gid="$(PlistBuddy -c 'Print :dsAttrTypeStandard\:PrimaryGroupID:0' /dev/stdin <<< "${created_dscl_user}" 2> /dev/null)"
	if [[ "${created_user_gid}" != "${user_gid:-20}" || $'\n'"${created_dscacheutil_user}"$'\n' != *$'\n'"gid: ${user_gid:-20}"$'\n'* ]]; then
		>&2 echo -e "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but with incorrect Group ID (${created_user_gid:-N/A} != ${user_gid:-20}).\n${created_dscacheutil_user}"
		return "${error_code}"
	fi
	(( error_code ++ ))

	created_user_home_path="$(PlistBuddy -c 'Print :dsAttrTypeStandard\:NFSHomeDirectory:0' /dev/stdin <<< "${created_dscl_user}" 2> /dev/null)"
	if [[ "${created_user_home_path}" != "${user_home_path}" || $'\n'"${created_dscacheutil_user}"$'\n' != *$'\n'"dir: ${user_home_path}"$'\n'* ]]; then
		>&2 echo -e "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but with incorrect home folder (${created_user_home_path:-N/A} != ${user_home_path}).\n${created_dscacheutil_user}"
		return "${error_code}"
	fi
	(( error_code ++ ))

	created_user_shell="$(PlistBuddy -c 'Print :dsAttrTypeStandard\:UserShell:0' /dev/stdin <<< "${created_dscl_user}" 2> /dev/null)"
	if [[ "${created_user_shell}" != "${user_shell}" || $'\n'"${created_dscacheutil_user}"$'\n' != *$'\n'"shell: ${user_shell}"$'\n'* ]]; then
		>&2 echo -e "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but with incorrect login shell (${created_user_shell:-N/A} != ${user_shell}).\n${created_dscacheutil_user}"
		return "${error_code}"
	fi
	(( error_code ++ ))

	created_user_full_name="$(PlistBuddy -c 'Print :dsAttrTypeStandard\:RealName:0' /dev/stdin <<< "${created_dscl_user}" 2> /dev/null)"
	if [[ "${created_user_full_name}" != "${user_full_name}" || $'\n'"${created_dscacheutil_user}"$'\n' != *$'\n'"gecos: ${user_full_name}"$'\n'* ]]; then
		>&2 echo -e "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but with incorrect full name (${created_user_full_name:-N/A} != ${user_full_name}).\n${created_dscacheutil_user}"
		return "${error_code}"
	fi
	(( error_code ++ ))

	created_user_guid="$(PlistBuddy -c 'Print :dsAttrTypeStandard\:GeneratedUID:0' /dev/stdin <<< "${created_dscl_user}" 2> /dev/null)"
	if [[ -n "${user_guid}" ]]; then
		if [[ "${created_user_guid}" != "${user_guid}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but with incorrect Generated UID (${created_user_guid:-N/A} != ${user_guid})."
			return "${error_code}"
		fi
	elif [[ -z "${created_user_guid}" ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but without a Generated UID (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)."
		return "${error_code}"
	else
		user_guid="${created_user_guid}" # If no "user_guid" was specified, set it to the "created_user_guid" since it's needed for the SharePoint "com_apple_sharing_uuid" attribute if sharing the Public folder (when specified) as well as confirming a Secure Token was granted (when specified).
	fi
	(( error_code ++ ))

	if ! $set_service_account; then
		# Add empty string attributes after user creation since "dsimport" ignores empty strings and does not create the attributes at all.
		# "dscl . -create" ALSO ignores empty strings and does not create the attributes (and it will delete any existing attribute if "dscl . -create" is run with an empty string).
		# But I found that "dscl . -append" will properly create the attribute with an empty string value. So, that is what will be used to properly replicate the behavior of System Preferences and "sysadminctl -addUser".
		# Do not bother checking that these are set correctly and erroring if not since I think it's actually alright for them not to exist.

		if [[ -z "${user_password_hint}" && "$(dscl . -read "/Users/${user_account_name}" AuthenticationHint 2>&1)" == 'No such key: AuthenticationHint' ]]; then
			dscl . -append "/Users/${user_account_name}" AuthenticationHint ''
		fi

		if [[ "$(dscl . -read "/Users/${user_account_name}" AvatarRepresentation 2>&1)" == 'No such key: AvatarRepresentation' ]]; then
			dscl . -append "/Users/${user_account_name}" AvatarRepresentation ''
		fi

		if (( darwin_major_version >= 20 )) && [[ "$(dscl . -read "/Users/${user_account_name}" inputSources 2>&1)" == 'No such key: inputSources' ]]; then
			dscl . -append "/Users/${user_account_name}" inputSources ''
		fi
	fi

	if ! $suppress_status_messages; then
		echo "mkuser: Verifying ${user_full_and_account_name_display} user password..."
	fi

	if [[ "${user_password}" == '*' ]]; then
		intended_authentication_authority="$($set_prevent_secure_token_on_big_sur_and_newer && echo 'AuthenticationAuthority: ;DisabledTags;SecureToken' || echo 'No such key: AuthenticationAuthority')"

		if [[ "$(dscl . -read "/Users/${user_account_name}" HeimdalSRPKey KerberosKeys ShadowHashData _writers_passwd Password 2>&1 | sort)" != $'No such key: HeimdalSRPKey\nNo such key: KerberosKeys\nNo such key: ShadowHashData\nNo such key: _writers_passwd\nPassword: *' || "$(dscl . -read "/Users/${user_account_name}" AuthenticationAuthority 2>&1)" != "${intended_authentication_authority}" ]]; then
			# If there is no system password policy (such as by default on macOS 10.13 High Sierra), the password will have gotten set to "*" instead of not having any password set and "*" being literally set to the Password attribute to signify no password (as intended).
			# So, if a password got set, verify that it incorrectly got set to "*" AS LONG AS it won't unintentionally grant this account the first Secure Token, otherwise just assume it did AS LONG AS there is no password policy.
			# This could also happen if a custom password policy allowed a single character password, which is why we are verifying the password when it is safe to do so (ie. would not grant the first Secure Token to this account, which cannot be undone).
			# If somehow a password got set, some password policy is set, and it isn't safe to check the actual password since that could grant the account the first Secure Token, or somehow some password other than asterisk got set, just stop and present an error.

			password_unintentionally_got_set_to_asterisk=false

			if ! $boot_volume_is_apfs || (( darwin_major_version >= 19 || user_uid < 500 )) || [[ "$(diskutil apfs listUsers / 2> /dev/null)" == *'+-- '* ]]; then
				# If boot volume is not APFS, Secure Tokens don't exist.
				# If on macOS 11 Big Sur or newer, any unintended Secure Token would have been granted during account creation when the password was set, so checking the password won't make a difference.
				# If on macOS 10.15 Catalina, the first Secure Token would only be granted to the first *administrator* to authenticate, which this user will not be (yet).
				# If on macOS 10.14 Mojave or older, the first Secure Token would only be granted to the first user with a UID of 500 or greater to authenticate, so if the UID is below 500 a Secure Token would never be granted.
				# If the first Secure Token has already been granted, another will not be granted automatically upon authentication (and won't make a difference if that Secure Token is one that already got unintentionally granted to this account).

				if verify_user_password_result="$(mkuser_verify_password "${user_account_name}" "${user_password}" 2>&1)" && [[ "${verify_user_password_result}" == 'VERIFIED' ]]; then
					password_unintentionally_got_set_to_asterisk=true
				fi
			elif [[ -z "$(PlistBuddy -c 'Print :policyCategoryPasswordContent:0:policyContent' /dev/stdin <<< "$(pwpolicy -getaccountpolicies 2> /dev/null | tail +2)" 2> /dev/null)" ]]; then
				# If verifying the password could possibly grant this account the first Secure Token, just check if there is NO system password policy and assume that the unintentional password is an asterisk.
				# Not being able to safely check the password would only happen on macOS 10.14 Mojave or older when this users UID is 500 or greater and no Secure Token has been granted yet.
				# But since this is most likely to occur on macOS 10.13 High Sierra where no password policy is set by default, this is an important case to check for.
				# This intentionally DOES NOT catch the case where it's not safe to check the password and a custom password policy allowed a single character password (which is likely increadibly rare) and an error will just be presented in that case instead.

				password_unintentionally_got_set_to_asterisk=true
			fi

			if $password_unintentionally_got_set_to_asterisk; then
				if [[ "$(sysadminctl -secureTokenStatus "${user_account_name}" 2>&1)" != *'is ENABLED for'* && "$(diskutil apfs listUsers / 2> /dev/null)" != *$'\n'"+-- ${user_guid}"$'\n'* && $'\n'"$(fdesetup list 2> /dev/null)"$'\n' != *$'\n'"${user_account_name},${user_guid}"$'\n'* ]]; then
					# Delete all the associated password attributes AS LONG AS this account doesn't have a Secure Token.

					if $set_prevent_secure_token_on_big_sur_and_newer; then
						dscl . -create "/Users/${user_account_name}" AuthenticationAuthority ';DisabledTags;SecureToken' # Do not want to delete the entire AuthenticationAuthority because we want to perserve this tag when it was specified by the user
					else
						dscl . -delete "/Users/${user_account_name}" AuthenticationAuthority &> /dev/null
					fi

					dscl . -delete "/Users/${user_account_name}" HeimdalSRPKey &> /dev/null
					dscl . -delete "/Users/${user_account_name}" KerberosKeys &> /dev/null
					dscl . -delete "/Users/${user_account_name}" ShadowHashData &> /dev/null
					dscl . -delete "/Users/${user_account_name}" _writers_passwd &> /dev/null
					dscl . -create "/Users/${user_account_name}" Password '*'

					# These keys within the accountPolicyData plist would also not have been created if the password was properly not set in the first place.
					dscl . -deletepl "/Users/${user_account_name}" accountPolicyData failedLoginCount &> /dev/null
					dscl . -deletepl "/Users/${user_account_name}" accountPolicyData failedLoginTimestamp &> /dev/null
					dscl . -deletepl "/Users/${user_account_name}" accountPolicyData passwordLastSetTime &> /dev/null

					>&2 echo "mkuser WARNING: Deleted all unintentional password attributes since the password got set to \"*\" instead of NO password (because \"pwpolicy\" allowed it)."
				else
					>&2 echo "mkuser WARNING: Password got set to \"*\" instead of NO password (because \"pwpolicy\" allowed it), AND THIS ACCOUNT GOT GRANTED A SECURE TOKEN SO CAN'T REMOVE IT (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)."
				fi
			fi
		fi

		if [[ "$(dscl . -read "/Users/${user_account_name}" HeimdalSRPKey KerberosKeys ShadowHashData _writers_passwd Password 2>&1 | sort)" != $'No such key: HeimdalSRPKey\nNo such key: KerberosKeys\nNo such key: ShadowHashData\nNo such key: _writers_passwd\nPassword: *' || "$(dscl . -read "/Users/${user_account_name}" AuthenticationAuthority 2>&1)" != "${intended_authentication_authority}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to verify NO password."
			return "${error_code}"
		fi
	else
		if [[ -z "${user_password}" ]]; then
			# If no password is specified, it must be manually set to an empty string since if an empty string password is included in the "dsimport" file,
			# no password will be set at all on macOS 11 Big Sur and newer and some unknown password will be set on macOS 10.15 Catalina and older rather then setting the password to an empty string.
			# In either case, if the password is not explicitly set to an empty string, the user will not be able to log in with a blank/empty password or at all.

			dscl . -passwd "/Users/${user_account_name}" ''
		fi

		# Must verify password BEFORE setting users to be administrators (if they are configured to be) so that these authentications DO NOT grant the first Secure Token on macOS 10.15 Catalina.
		# But, these authentications WILL grant the first Secure Token on macOS 10.14 Mojave and macOS 10.13 High Sierra, but that is desirable over possible situations where no Secure Token will get granted at all.
		# See all the "SECURE TOKEN NOTES" sections within the "--prevent-secure-token-on-big-sur-and-newer" help info for more about how macOS grants the first Secure Token on different versions of macOS.

		if ! verify_user_password_result="$(mkuser_verify_password "${user_account_name}" "${user_password}" 2>&1)" || [[ "${verify_user_password_result}" != 'VERIFIED' ]]; then
			>&2 echo "${verify_user_password_result}"
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to verify password."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if $set_prohibit_user_password_changes; then
		# See notes above (where "_writers_" attributes are set) for information about why this is deleted down here when password changes are prohibited.

		if ! dscl . -delete "/Users/${user_account_name}" _writers_passwd &> /dev/null || [[ "$(dscl . -read "/Users/${user_account_name}" _writers_passwd 2>&1)" != 'No such key: _writers_passwd' ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to prohibit user password changes."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	did_create_home_folder=false

	if $do_not_create_home_folder; then
		if ! $suppress_status_messages; then
			echo "mkuser: NOT creating home folder for ${user_full_and_account_name_display} user..."
		fi
	elif ! $user_home_is_var_empty && ! $user_home_is_dev_null; then # Do not display any message when home folder is set to "/var/empty" or "/dev/null" folder (since it already exists), just don't try to create it or edit anything within it.
		if ! $suppress_status_messages; then
			echo "mkuser: Creating home folder for ${user_full_and_account_name_display} user..."
		fi

		# Intentionally letting "createhomedir" output to stdout and stderr for useful user feedback when status messages aren't suppressed and only output stderr when they are.
		# "cd /" before "createhomedir" because it could "shell-init: error retrieving current directory: getcwd: cannot access parent directories: Permission denied" if the current working directory is "/var/root" (root user home folder). Thanks to Thomas Esser for discovering this bug and fix.
		if ! (cd /; createhomedir -cu "${user_account_name}" > "$($suppress_status_messages && echo '/dev/null' || echo '/dev/stdout')") || [[ ! -d "${user_home_path}" ]]; then
			# Must create home folder manually when using "dsimport" (or "dscl . -create"). The home folder is created by "sysadminctl -addUser"
			# during normal user creation. Although, when specifying a custom home folder, "sysadminctl -addUser" will assign the folder
			# but not create it automatically. Regardless, "sysadminctl -addUser" doesn't cover all the possible cases mentioned previously.

			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to create home folder \"${user_home_path}\"."
			return "${error_code}"
		fi

		did_create_home_folder=true
	fi
	(( error_code ++ ))

	if $did_create_home_folder && $set_hidden_home && [[ -z "$(find "/$(echo "${user_home_path}" | cut -d '/' -f 2)" -flags +hidden -maxdepth 0 2> /dev/null)" ]]; then
		# Also hide home folder if user is set as hidden (only if root level folder isn't already hidden such as "/private").

		if ! chflags 'hidden' "${user_home_path}" || [[ -z "$(find "${user_home_path}" -flags +hidden -maxdepth 0 2> /dev/null)" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to hide home folder \"${user_home_path}\"."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if $did_create_home_folder; then
		user_full_name_for_share_point="${user_full_name}"
		user_share_point_name_suffix="’s Public Folder"

		# Since user full name will now be used at the SharePoint RecordName, removing any invalid leading characters ("." and "-") for RecordNames (see account name limitations for reasoning).
		user_full_name_for_share_point="${user_full_name_for_share_point#"${user_full_name_for_share_point%%[^.-]*}"}"

		# Full names longer than 226 *BYTES* will cause the Public folder SharePoint to fail to be created by the "sharing" command.
		# This is because the Public folder SharePoint's default RecordName "${user_full_name}’s Public Folder" would be 244 bytes when the full name is 226 bytes.
		# It seems that all OpenDirectory RecordName's have a 244 byte limit, just like the User RecordName has this same byte length limit.

		# WEIRD SIDE NOTE: When a RecordName contains multibyte characters, it seems that sometimes the max bytes before the record breaks can be a few more than 244.
		# When testing by adding characters 1-by-1 in Directory Utility and switching to the data view to see the current byte length, with mutli-byte characters in the string,
		# sometimes I could set to 247 bytes and save and it worked fine and then saving 1 more breaks it and with different mult-byte characters I could fit 248 bytes and 1 more breaks it.
		# But that is just an oddity and I could not discern any specific pattern to when or why exactly more byte might be allowed in a RecordName.
		# And, when there are NO multibyte chars, the limit seems to always just be 244 bytes flat and 1 more will break the record.
		# So, 244 bytes is the maximum safe limit in all cases that we will stick to throughout this code.

		# But, before worrying about the 244 byte limit, truncate the full name and suffix characters to fit within 244 characters.
		# Since 244 characters will be at least 244 bytes or more, truncating the characters first makes it much faster to truncate bytes
		# down from that this reduced length instead of truncating from a full name that could be more than twice as long to begin with.
		user_full_name_for_share_point="${user_full_name_for_share_point:0:244-${#user_share_point_name_suffix}}"

		user_share_point_name="${user_full_name_for_share_point}${user_share_point_name_suffix}"

		if (( $(echo -n "${user_share_point_name}" | wc -c) > 244 )); then
			# When truncated full name for SharePoint RecordName, add "…" to the end of the full name to indicate that it was truncated.
			until (( $(echo -n "${user_full_name_for_share_point}…${user_share_point_name_suffix}" | wc -c) <= 244 )); do # Use "wc -c" to properly count bytes instead of characters. And must pipe to "wc" with "echo -n" to not count a trailing line break character.
				user_full_name_for_share_point="${user_full_name_for_share_point:0:${#user_full_name_for_share_point}-1}"
			done

			# Remove any trailing spaces if full name was truncated.
			user_full_name_for_share_point="${user_full_name_for_share_point%"${user_full_name_for_share_point##*[^[:space:]]}"}"

			user_share_point_name="${user_full_name_for_share_point}…${user_share_point_name_suffix}"

			# Even when the full name contains no multibyte characters, this loop will ALWAYS be entered since the "’" in the suffix is a 3-byte character, which will make the user_share_point_name always over 244 bytes even if we already truncated to 244 characters.
			# This is fine though since it means the desired "…" 3-byte character will always be added when truncating and fit into the proper byte limit even if the full name is made up of only 1-byte characters.
		fi

		# Replace any forward slash (/) or percent (%) characters in the SharePoint RecordName with underscores (_) for the following reasons:
		# When forward slash (/) or percent (%) characters are included in a full name for user created by "sysadminctl -addUser" or System Preferences, they are allowed and properly displayed in the Shared folder name in the File Sharing section of the Sharing pane in System Preferences (as well as in Directory Utility).
		# What happens internally is that percent (%) characters are replaced with "%25" and forward slash (/) characters are replaced with "%2F", since literal forward slashes cannot exist in folder or file names and the RecordName is a plist filename, and then any escape character (the %) would also need to be escaped to not be misinterpreted when used literally.
		# In fact, "sharing -a" does this same escape/replacing automatically, so it may seem that these characters could be left in and "sharing -a" would take care of this escaping for us.
		# While this seems true at first glance, I found a bug when trying to use "dscl . -create" with a SharePoint RecordName that contains these forward slash (/) or percent (%) characters.
		# When using "dscl . -read" (and all "sharing" commands) the RecordName must be specified in its display form with literal forward slash (/) or percent (%) characters.
		# When using "dscl . -delete" the RecordName must be specified with the forward slash (/) or percent (%) characters escaped to their "%2F" and "%25" forms, respectively.
		# So far so good since those commands can still work and function properly when the RecordName is specified correctly.
		# BUT, when trying to use "dscl . -create", neither of these forms (or any other variations I tried) would work and "dscl" would display an "Uncaught Exception" error stating "[__NSArrayM insertObject:atIndex:]: object cannot be nil" (tested and observed on macOS 10.13 High Sierra and macOS 12 Monterey, which is enough to justify not using these characters in SharePoint RecordNames).
		# Since I could not figure out how to properly use "dscl . -create" to workaround this bug when either the forward slash (/) or percent (%) characters were present in a RecordName, they will both be replaced with underscores (_) so that "dscl . -create" can be used with these SharePoint RecordNames to be able to properly add the required attributes to the SharePoint record.
		# Doing these replacements AFTER truncating the full name since this does not change the byte count and doing it here means only the characters that would have made it into the RecordName are being replaced.

		user_share_point_name="${user_share_point_name//%/_}"
		user_share_point_name="${user_share_point_name//\//_}"

		# SIDE NOTE ABOUT THE COLON (:) CHARACTER BEING ALLOWED IN SHAREPOINT RECORDNAME (WHICH IS A PLIST FILENAME IN THE DSLOCAL FOLDER STRUCTURE):
		# The colon (:) character is not allowed in Finder, but actually is a valid character in file and folder names and will confusingly be displayed in Finder as a forward slash (/).
		# If you add a forward slash (/) to a file or folder name in Finder, it will be allowed and the actual file or folder name set will have a colon (:) in place of the forward slash (/).
		# But, unlike in Finder, Shared folder names with colons (:) in them are properly displayed as colons in the File Sharing section of the Sharing pane in System Preferences (as well as in Directory Utility) instead of a forward slash, so they can be allowed here without causing any error or confusion.

		if $do_not_share_public_folder || $set_hidden_home || [[ "${user_home_path}" != '/Users/'* ]]; then
			if [[ "$(sharing -l)" == *$'\t'"${user_share_point_name}"$'\n'* ]] || dscl . -read "/SharePoints/${user_share_point_name}" RecordName &> /dev/null; then
				if ! $suppress_status_messages; then
					echo "mkuser: Unsharing ${user_full_and_account_name_display} user Public folder..."
				fi

				# If hiding home folder, also remove the SharePoint (and SharePoint Group) as described on https://support.apple.com/HT203998
				# THIS SHOULD NEVER ACTUALLY RUN SINCE THE SHAREPOINT WILL NOT BE CREATED YET. IT WILL BE MANUALLY ADDED RIGHT BELOW HERE FOR NON-HIDDEN USERS.
				# But still, doesn't hurt to check and try to remove any existing SharePoint (and SharePoint Group) anyway. The code may be a good reference for something else in the future.

				# Also check for an associated SharePoint Group and delete it as well.
				# This must be done before deleting the SharePoint since the GeneratedUID of the SharePoint Group is references within the SharePoint.
				user_share_point_group_guid="$(PlistBuddy -c 'Print :dsAttrTypeNative\:sharepoint_group_id:0' /dev/stdin <<< "$(dscl -plist . -read "/SharePoints/${user_share_point_name}" sharepoint_group_id 2> /dev/null)" 2> /dev/null)"
				if [[ -n "${user_share_point_group_guid}" ]]; then
					user_share_point_group_name="$(dscl . -search /Groups GeneratedUID "${user_share_point_group_guid}" | awk '{ print $1; exit }')"

					if [[ -n "${user_share_point_group_name}" ]]; then
						if ! dseditgroup -o delete "${user_share_point_group_name}" &> /dev/null || [[ -n "$(dscacheutil -q group -a name "${user_share_point_group_name}")" ]]; then # Check non-existence with "dscacheutil" to make sure the group deletion has been cached.
							>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to delete SharePoint Group \"${user_share_point_group_name}\" for hidden user."
							return "${error_code}"
						fi
					fi
				fi

				if ! sharing -r "${user_share_point_name}" || [[ "$(sharing -l)" == *$'\t'"${user_share_point_name}"$'\n'* ]] || dscl . -read "/SharePoints/${user_share_point_name}" RecordName &> /dev/null; then
					>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to delete SharePoint \"${user_share_point_name}\" for hidden user."
					return "${error_code}"
				fi
			fi
		elif [[ "$(sharing -l)" != *$'\t'"${user_share_point_name}"$'\n'* ]] && ! dscl /Search -read "/SharePoints/${user_share_point_name}" RecordName &> /dev/null; then # Use "dscl /Search" for these checks when checking for pre-existing Groups and SharePoints rather than just newly created stuff.
			# Only add SharePoints for users with home folders that are not hidden and are in the default location (not hidden locations such as within "/private/var/").

			if ! $suppress_status_messages; then
				echo "mkuser: Sharing ${user_full_and_account_name_display} user Public folder..."
			fi

			# Create user SharePoint (using "sharing -a") since that is default macOS behavior for users created by "sysadminctl -addUser" and System Preferences (but "dsimport" does not add the SharePoint automatically).
			# After creating a new SharePoint (using "sharing -a"), the SharePoint structure does not match what would be created by "sysadminctl -addUser" and System Preferences,
			# and also a new SharePoint Group (com.apple.sharepoint.group.#) does not get creating like "sysadminctl -addUser" and System Preferences would create.
			# So, we will add a new SharePoint Group (com.apple.sharepoint.group.#) manually and modify the "sharing -a" SharePoint structure to match how "sysadminctl -addUser" and System Preferences would make it.

			# I am not actually sure what the purpose of the SharePoint Group (com.apple.sharepoint.group.#) is, since a shared folder seems to work fine without it, but the
			# goal here is to match "sysadminctl -addUser" and System Preferences as exactly as possible, so we will replicate those exact SharePoint and SharePoint Group structures.

			# Slightly relevant reference for SharePoint structure via "sysadminctl -addUser" and System Preferences (which does not match the "sharing -a" structure): https://malcontentcomics.com/systemsboy/2008/03/netboot-part-4.html
			# This references is also useful since it shows that the structure of a SharePoint created via System Preferences has been basically the same since 2008 and "sharing -a" has not been updated to match in all that time.
			# So, we should not expect "sharing -a" to match the behavior and structure of adding a SharePoint via "sysadminctl -addUser" or System Preferences in a future version of macOS (anything is possible, but seems extremely unlikely).
			# Maybe there is a new modern CLI way to add a SharePoint that matches the behavior of "sysadminctl -addUser" and System Preferences, but I haven't found it.

			# Find the lowest available Group ID for the SharePoint Group starting at "701", like "sysadminctl -addUser" and System Preferences does.

			# all_assigned_gids is loaded above when confirming that the users Primary Group ID already exists.
			# See "UIDs CAN BE REPRESENTED IN DIFFERENT FORMS" notes and following code for important information about GIDs and UIDs.

			user_share_point_group_id='701'
			IFS=$'\n'
			for this_assigned_gid in ${all_assigned_gids}; do
				if (( "${this_assigned_gid}" == user_share_point_group_id )); then
					(( user_share_point_group_id ++ ))
				elif (( "${this_assigned_gid}" > user_share_point_group_id )); then
					break
				fi
			done
			unset IFS

			assigned_share_point_gid_dscl_search="$(dscl /Search -search /Groups PrimaryGroupID "${user_share_point_group_id}" 2> /dev/null)"
			if [[ -n "${assigned_share_point_gid_dscl_search}" ]]; then
				# It is important to search for the GID specifically since its not possible to list all AD groups and some AD GIDs could
				# have been omitted from previous listings while this direct query will find it regardless of LDAP listing limitations.

				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: SharePoint Group ID assignment chose \"${user_share_point_group_id}\", but it's already assigned to \"$(echo "${assigned_share_point_gid_dscl_search}" | awk '{ print $1; exit }')\" (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)."
				return "${error_code}"
			fi

			# Find the lowest available name for the SharePoint Group starting at "com.apple.sharepoint.group.1", like "sysadminctl -addUser" and System Preferences does.
			share_point_group_name_prefix='com.apple.sharepoint.group.'
			user_share_point_group_name_index=1
			user_share_point_group_name="${share_point_group_name_prefix}${user_share_point_group_name_index}"

			all_assigned_share_point_group_names="$(dscl /Search -list /Groups 2> /dev/null | grep "^${share_point_group_name_prefix//./\\.}" | sort -t '.' -k 5 -n)"

			IFS=$'\n'
			for this_assigned_share_point_group_name in ${all_assigned_share_point_group_names}; do
				if [[ "${this_assigned_share_point_group_name}" == "${user_share_point_group_name}" ]]; then
					(( user_share_point_group_name_index ++ ))
					user_share_point_group_name="${share_point_group_name_prefix}${user_share_point_group_name_index}"
				else
					break
				fi
			done
			unset IFS

			if dscl /Search -read "/Groups/${user_share_point_group_name}" RecordName &> /dev/null; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: SharePoint Group Name assignment chose \"${user_share_point_group_name}\", but it already exists (THIS SHOULD NOT HAVE HAPPENED, PLEASE REPORT THIS ISSUE)."
				return "${error_code}"
			fi

			# Create the SharePoint (using "sharing -a").
			if ! sharing -a "${user_home_path}/Public" -n "${user_share_point_name}" || [[ "$(sharing -l)" != *$'\t'"${user_share_point_name}"$'\n'* ]] || ! dscl . -read "/SharePoints/${user_share_point_name}" RecordName &> /dev/null; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to add SharePoint \"${user_share_point_name}\"."
				return "${error_code}"
			fi

			# All of the following attributes for the "dscl" commands are "dsAttrTypeNative" types, but that prefix can be omitted when using "dscl".

			user_share_point_name_escaped_for_dscl_delete_and_create="${user_share_point_name//\\/\\\\}" # Oddly need to escape backslashes in "dscl . -delete" and "dscl . -create" but NOT "dscl . -read".
			# The former 2 fail WITHOUT backslashes escaped (eDSUnknownNodeName and no error but nothing created, respectively) and the latter fails WITH backslashes escaped (eDSRecordNotFound).

			# The "sharing -a" SharePoint will contain the following 4 attributes which are not created for SharePoints created via "sysadminctl -addUser" and System Preferences, so delete them.
			if ! dscl . -delete "/SharePoints/${user_share_point_name_escaped_for_dscl_delete_and_create}" afp_use_parent_owner &> /dev/null || \
				! dscl . -delete "/SharePoints/${user_share_point_name_escaped_for_dscl_delete_and_create}" afp_use_parent_privs &> /dev/null || \
				! dscl . -delete "/SharePoints/${user_share_point_name_escaped_for_dscl_delete_and_create}" smb_readonly &> /dev/null || \
				! dscl . -delete "/SharePoints/${user_share_point_name_escaped_for_dscl_delete_and_create}" smb_sealed &> /dev/null || \
				[[ "$(dscl . -read "/SharePoints/${user_share_point_name}" afp_use_parent_owner afp_use_parent_privs smb_readonly smb_sealed 2>&1 | sort)" != $'No such key: afp_use_parent_owner\nNo such key: afp_use_parent_privs\nNo such key: smb_readonly\nNo such key: smb_sealed' ]]; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to delete legacy attributes from SharePoint."
				return "${error_code}"
			fi

			# The "sharing -a" SharePoint will NOT contain the following 5 (or 4) attributes which ARE created for SharePoints created via "sysadminctl -addUser" and System Preferences, so add them.
			if (( darwin_major_version >= 19 )); then
				# This attribute was added in macOS 10.15 Catalina and did not exist in older versions of macOS.
				if ! dscl . -create "/SharePoints/${user_share_point_name_escaped_for_dscl_delete_and_create}" com_apple_sharing_uuid "${user_guid}" || [[ "$(PlistBuddy -c 'Print :dsAttrTypeNative\:com_apple_sharing_uuid:0' /dev/stdin <<< "$(dscl -plist . -read "/SharePoints/${user_share_point_name}" com_apple_sharing_uuid 2> /dev/null)" 2> /dev/null)" != "${user_guid}" ]]; then
					>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to add user's GeneratedUID to SharePoint."
					return "${error_code}"
				fi
			fi

			root_guid="$(PlistBuddy -c 'Print :dsAttrTypeStandard\:GeneratedUID:0' /dev/stdin <<< "$(dscl -plist . -read '/Users/root' GeneratedUID 2> /dev/null)" 2> /dev/null)"
			if ! dscl . -create "/SharePoints/${user_share_point_name_escaped_for_dscl_delete_and_create}" ftp_name "${user_share_point_name}" || \
				! dscl . -create "/SharePoints/${user_share_point_name_escaped_for_dscl_delete_and_create}" sharepoint_account_uuid "${root_guid}" || \
				! dscl . -create "/SharePoints/${user_share_point_name_escaped_for_dscl_delete_and_create}" smb_createmask '644' || \
				! dscl . -create "/SharePoints/${user_share_point_name_escaped_for_dscl_delete_and_create}" smb_directorymask '755' || \
				! dscl_read_modern_sharepoint_attributes_plist="$(dscl -plist . -read "/SharePoints/${user_share_point_name}" ftp_name sharepoint_account_uuid smb_createmask smb_directorymask 2> /dev/null)" ||
				[[ "$(PlistBuddy -c 'Print :dsAttrTypeNative\:ftp_name:0' /dev/stdin <<< "${dscl_read_modern_sharepoint_attributes_plist}" 2> /dev/null)" != "${user_share_point_name}" || \
					"$(PlistBuddy -c 'Print :dsAttrTypeNative\:sharepoint_account_uuid:0' /dev/stdin <<< "${dscl_read_modern_sharepoint_attributes_plist}" 2> /dev/null)" != "${root_guid}" || \
					"$(PlistBuddy -c 'Print :dsAttrTypeNative\:smb_createmask:0' /dev/stdin <<< "${dscl_read_modern_sharepoint_attributes_plist}" 2> /dev/null)" != '644' || \
					"$(PlistBuddy -c 'Print :dsAttrTypeNative\:smb_directorymask:0' /dev/stdin <<< "${dscl_read_modern_sharepoint_attributes_plist}" 2> /dev/null)" != '755' ]]; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to add modern attributes to SharePoint."
				return "${error_code}"
			fi

			if [[ "$(PlistBuddy -c 'Print :dsAttrTypeStandard\:PrimaryGroupID:0' /dev/stdin <<< "$(dscl -plist . -read "/Groups/${user_share_point_group_name}" PrimaryGroupID 2> /dev/null)" 2> /dev/null)" != "${user_share_point_group_id}" ]]; then
				# While "mkuser" does not officially support older than macOS 10.13 High Sierra, I did do one test on OS X 10.11 El Capitan and was surprised to see that "sharing -a" actually created the SharePoint Group, unlike newer versions of macOS.
				# So, I added in this simple check to see if the SharePoint Group has already been created (even though it shouldn't be on macOS 10.13 High Sierra or newer) so that the user creation process could complete properly on OS X 10.11 El Capitan (but no more thorough testing was done).
				# This check should make this one thing simpler if official support for older versions of macOS is ever needed, or if things change in a future version of macOS.

				# Create the SharePoint Group (com.apple.sharepoint.group.#) and include the "everyone" group as a member (which will add it to NestedGroups), like "sysadminctl -addUser" and System Preferences does.
				if ! dseditgroup -q -o create -i "${user_share_point_group_id}" -r "${user_share_point_name}" -a 'everyone' -t 'group' "${user_share_point_group_name}" || ! dscacheutil -q group -a name "${user_share_point_group_name}" | grep -qxF "gid: ${user_share_point_group_id}"; then # Check existence with "dscacheutil" to verify GID and to make sure the new group has been cached.
					>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to add SharePoint Group \"${user_share_point_group_name}\"."
					return "${error_code}"
				fi
			else
				>&2 echo "mkuser WARNING: SharePoint Group \"${user_share_point_name}\" (${user_share_point_group_id}) was unexpectedly already created by the \"sharing -a\" command." # Log warning if the SharePoint Group was created by "sharing -a" to notice if things ever change in a future version of macOS.
			fi

			# Hide the SharePoint Group like "sysadminctl -addUser" and System Preferences does.
			if ! dscl . -create "/Groups/${user_share_point_group_name}" IsHidden '1' || [[ "$(PlistBuddy -c 'Print :dsAttrTypeNative\:IsHidden:0' /dev/stdin <<< "$(dscl -plist . -read "/Groups/${user_share_point_group_name}" IsHidden 2> /dev/null)" 2> /dev/null)" != '1' ]]; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to hide SharePoint Group."
				return "${error_code}"
			fi

			# The "sharing -a" SharePoint will also NOT contain the "sharepoint_group_id" attribute which refers back to the GeneratedUID
			# of the SharePoint Group (com.apple.sharepoint.group.#), therefore is must be added after creating the SharePoint Group.
			sharepoint_group_guid="$(PlistBuddy -c 'Print :dsAttrTypeStandard\:GeneratedUID:0' /dev/stdin <<< "$(dscl -plist . -read "/Groups/${user_share_point_group_name}" GeneratedUID 2> /dev/null)" 2> /dev/null)"
			if [[ -z "${sharepoint_group_guid}" ]] || ! dscl . -create "/SharePoints/${user_share_point_name_escaped_for_dscl_delete_and_create}" sharepoint_group_id "${sharepoint_group_guid}" || [[ "$(PlistBuddy -c 'Print :dsAttrTypeNative\:sharepoint_group_id:0' /dev/stdin <<< "$(dscl -plist . -read "/SharePoints/${user_share_point_name}" sharepoint_group_id 2> /dev/null)" 2> /dev/null)" != "${sharepoint_group_guid}" ]]; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to add SharePoint Group GeneratedUID to SharePoint."
				return "${error_code}"
			fi
		else
			>&2 echo "mkuser WARNING: NOT sharing Public folder since SharePoint \"${user_share_point_name}\" already exists, maybe from a previous user that was not fully deleted (CONTINUING ANYWAY)."
		fi
	fi
	(( error_code ++ ))

	if $set_admin; then
		if ! $suppress_status_messages; then
			echo "mkuser: Making ${user_full_and_account_name_display} user an administrator..."
		fi

		# After creating user with "dsimport", must manually add the new user to the "admin" group using the proper "dseditgroup".
		# "dscl" is not as convenient to add users to groups since multiple "dscl" commands would be needed, specifically GUIDs are added to the "GroupMembers" attribute of a group and account names are added to the "GroupMembership" attribute,
		# and if only the the account name is added to the "GroupMembership" when adding an admin, the admin user will not show in Recovery as that seems to rely on the GUID being present in the "GroupMembers" attribute.
		# Credit to Simon Andersen for discovering that the GUID is necessary for an admin to appear in Recovery: https://macadmins.slack.com/archives/C016JJWLZUY/p1630918818230500?thread_ts=1630599345.159900&cid=C016JJWLZUY

		# "sysadminctl -addUser" is able to add a user to the "admin" group with a single "sysadminctl -addUser -admin" command, but "sysadminctl -addUser" does not cover all the possible cases mentioned previously.
		# Admin users created by "sysadminctl -addUser" or System Preferences are also be added to the "_appserverusr" and "_appserveradm" groups (along with "admin").
		# I have confirmed admins are added to these 2 groups on macOS 10.13 High Sierra and macOS 11 Big Sur, but I eventually want research more macOS versions to see if there are any variations.

		admin_groups=( 'admin' '_appserverusr' '_appserveradm' )
		for this_admin_group in "${admin_groups[@]}"; do
			if ! dseditgroup -o edit -a "${user_account_name}" -t user "${this_admin_group}"; then
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to add to \"${this_admin_group}\" group."
				return "${error_code}"
			fi

			for (( group_membership_check_attempt = 0; group_membership_check_attempt < 2; group_membership_check_attempt ++ )); do
				if [[ " $(id -Gn -- "${user_account_name}") " != *" ${this_admin_group} "* || "$(dsmemberutil checkmembership -U "${user_account_name}" -G "${this_admin_group}" 2> /dev/null)" != 'user is a member of the group' ]]; then
					if (( group_membership_check_attempt == 0 )); then
						dsmemberutil flushcache
						>&2 echo "mkuser WARNING: Flushed groups cache to verify \"${user_account_name}\" has been added to the \"${this_admin_group}\" group."
						# I've seen "dsmemberutil checkmembership" incorrectly fail (cache not updating quickly enough?), so flush the "dsmemberutil" cache and check again before erroring.
						# Unlike "dscacheutil -flushcache", "man dsmemberutil" does not have any note about "dsmemberutil flushcache" only being used in extreme cases, so seems fine to use here.
					else
						>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to verify \"${this_admin_group}\" group membership."
						return "${error_code}"
					fi
				else
					break
				fi
			done
		done

		# Double check group membership with "dscacheutil" after the user has been added to all groups to make sure all membership has been cached.
		# I found that maybe the cache may not get updated quickly enough if I checked "dscacheutil" after each group addition in the previous loop.
		# I chose not to use "dscacheutil -flushcache" for these verfications since "man dscacheutil" states that it "should only be used in extreme cases".
		# It also seems that multiple entries for a single group can/will exist and one of them will contain the new member, and the other one won't.
		# The multiple group entries exist even if "dscacheutil -flushcache" is run. So, the following check will verify the user exists in any of the entries.
		dscache_groups="$(dscacheutil -q group)" # Only query all groups from "dscacheutil" once.
		for this_admin_group in "${admin_groups[@]}"; do
			if [[ " $(echo "${dscache_groups}" | AWK_ENV_ADMIN_GROUP="${this_admin_group}" awk -F ': ' '($1 == "name") { this_name = $2 } (this_name == ENVIRON["AWK_ENV_ADMIN_GROUP"] && $1 == "users") { print $2 }' | tr -s '[:space:]' ' ') " != *" ${user_account_name} "* ]]; then
				# When using bash variables in "awk", set a command specific environment variable and then retrieve it in "awk" using "ENVIRON" array because any other technique would cause "awk" to incorrectly interpret backslash characters instead of treating them literally (even though this particular variable should never have backslashes).
				# Since multiple entries for a single group can exist, there may be line breaks. But DO NOT use "xargs" to convert these lines to be seperated by spaces in case it's an incredibly huge list and "xargs" will include line break after a number of arguments or bytes.

				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to verify \"${this_admin_group}\" group membership in Directory Service cache."
				return "${error_code}"
			fi
		done
	fi
	(( error_code ++ ))

	if $set_prevent_secure_token_on_big_sur_and_newer && [[ "$(sysadminctl -secureTokenStatus "${user_account_name}" 2>&1)" == *'is ENABLED for'* || "$(diskutil apfs listUsers / 2> /dev/null)" == *$'\n'"+-- ${user_guid}"$'\n'* || $'\n'"$(fdesetup list 2> /dev/null)"$'\n' == *$'\n'"${user_account_name},${user_guid}"$'\n'* ]]; then
		>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but Secure Token got granted when it should not have."
		return "${error_code}"
	fi
	(( error_code ++ ))

	if $set_auto_login; then
		if ! $suppress_status_messages; then
			echo "mkuser: Setting ${user_full_and_account_name_display} user to automatically login..."
		fi

		## THE FOLLOWING KCPASSWORD ENCODING AND DECODING CODE IS BASED ON https://github.com/brunerd/macAdminTools/blob/main/Scripts/setAutoLogin.sh & https://github.com/brunerd/macAdminTools/blob/main/Scripts/getAutoLogin.sh
		## Copyright (c) 2021 Joel Bruner
		## Licensed under the MIT License (The full MIT License text can be referenced at the top of the "mkuser" function.)

		# At this point, this kcpassword code is basically an adaptation of https://www.brunerd.com/blog/2021/08/24/automating-automatic-login-for-macos/ since I found that the "xxd" method used in that code
		# handles multibyte characters propery while printf's ord/chr equivalents that I was originally using do not (https://unix.stackexchange.com/questions/92447/bash-script-to-get-ascii-values-for-alphabet/92448#92448).

		# I originally wrote a direct port of the Python kcpassword creation code from pycreateuserpkg (which used the flawed printf ord/chr technique): https://github.com/gregneagle/pycreateuserpkg/blob/main/locallibs/kcpassword.py
		# Which is based on this Python code by Tom Taylor: https://github.com/timsutton/osx-vm-templates/blob/master/scripts/support/set_kcpassword.py
		# Which is a port of the oldest known kcpassword Perl code by Gavin Brock: https://web.archive.org/web/20180408062145/http://www.brock-family.org/gavin/perl/kcpassword.html
		# After I wrote my own port, I found another bash port of the original Perl code by Erik Berglund (which also used the flawed printf ord/chr technique): https://github.com/erikberglund/Scripts/blob/master/installer/installerCreateUser/installerCreateUser#L428
		# And then, even longer after I wrote my own port, Joel Brunerd released this bash code for kcpassword creation which uses a different "xxd" technique instead of printf ord/chr: https://www.brunerd.com/blog/2021/08/24/automating-automatic-login-for-macos/

		# At first, I started incorporating some useful techniques from Joel Brunerd's code (as well as Erik Berglund's bash port), but stuck to using the printf ord/chr technique for converting Unicode characters.
		# Then, I discovered that the printf ord/chr technique fails on multibyte characters (such as diacritics or Japanese, for example) and I found that the "xxd" technique for converting multibyte characters to hex and back worked properly.
		# So, I reworked this code to use the "xxd" technique and that is why I now consider this code to basically be an adaptation of Joel Brunerd's code rather than a port of the Python code I started with.
		# This code also includes other changes and comments based on my own research.

		cipher_key=( '7d' '89' '52' '23' 'd2' 'bc' 'dd' 'ea' 'a3' 'b9' '1f' ) # These are the special kcpassword repeating cipher hex characters.
		cipher_key_length="${#cipher_key[@]}"

		password_hex_string="$(echo -n "${user_password}" | xxd -c 1 -p)" # Convert each Unicode character of the password to their hex represention (seperated by line breaks via "-c 1"). Must pipe to "xxd" with "echo -n" to not include a trailing line break character.

		encoded_password_hex_string=''
		this_password_hex_char_index=0
		IFS=$'\n' # Only loop on line breaks, this is not required since default IFS would work, but I like to be specific.
		for this_password_hex_char in ${password_hex_string}; do
			# Do the kcpassword encoding by XORing each password hex character with a cipher hex character (and keep looping through the cipher hex characters in order)
			# which will return the integer representation from $(( 0x## ^ 0x## )) and then use printf '%02x' to convert the XORed integer to its hex character.
			encoded_password_hex_string+="$(printf '%02x' "$(( 0x${this_password_hex_char} ^ 0x${cipher_key[this_password_hex_char_index % cipher_key_length]} ))") "
			(( this_password_hex_char_index ++ ))
			# Using modulo for the cipher_key index will loop through the cipher_key characters, which is more like what is done in this other bash code rather than the Python code:
			# https://github.com/erikberglund/Scripts/blob/ac60be1e1284dc8cbb6d7a484ee8e3ad9c71b19a/installer/installerCreateUser/installerCreateUser#L436
			# https://gist.github.com/brunerd/d60343434a8a5121db423bf21025ea66#file-kcpasswordencode-sh-L40
		done
		unset IFS

		# Other kcpassword code has padded the encoded password to be even multiples of either 11 (cipher_key_length) or 12 (cipher_key_length + 1) using extra cipher characters as padding,
		# but through testing on macOS 10.13 High Sierra through macOS 11 Big Sur, I have found that this is not necessary. What *is* necessary is adding a *single* terminating cipher character.
		# For blank/empty passwords the kcpassword file cannot be empty, but the first cipher character is all that is necessary on macOS 10.13 High Sierra through macOS 11 Big Sur (which are the only versions of macOS I tested).
		# Other than that, a single terminating cipher character is required for a few other encoded password lengths, and the pattern of when it's required and when it isn't doesn't make perfect sense to me.
		# I did testing with 0 character (blank/empty), 4 character, 10 character, 11 character, 12 character, and 13 character passwords.
		# Unless otherwise noted, the encoded passwords (except blank/empty) worked for auto-login with both no terminating cipher padding and any amount of terminating cipher padding.
		# You'll notice there are no exceptions for macOS 11 Big Sur since all (except blank/empty) encoded passwords worked on there for auto-login with both no terminating cipher padding and any amount of terminating cipher padding.
		# Here are the exceptions (other than blank/empty passwords needing the first cipher character on all tested versions of macOS):
			# macOS 10.13 High Sierra: 13 character password with no terminating cipher padding failed to auto-login, adding 1 character of terminating cipher padding made it work.
			# macOS 10.14 Mojave: 11 and 12 character passwords with no terminating cipher padding failed to auto-login, adding 1 character of terminating cipher padding made them work.
			# macOS 10.15 Catalina: 4 and 13 character passwords with no terminating cipher padding failed to auto-login, adding 1 character of terminating cipher padding made them work.
		# I believe the behavior that's described in this issue (https://github.com/gregneagle/pycreateuserpkg/pull/31) on macOS 10.14 Mojave did not actually have to do with the block/chunk size of
		# the encoded password, but with those lengths not getting at least a single terminating cipher character. The fix worked, but added more terminating cipher padding than was actually necessary.
		# This research is further described in https://macadmins.slack.com/archives/C07MGJ2SD/p1631232311335200?thread_ts=1630698463.194700&cid=C07MGJ2SD

		# Since a single terminating cipher character is critical in some cases, it will always be added for all password lengths since it does not hurt and auto-login still works on all versions of macOS and appears to be what macOS always does as well.
		# Always adding a single terminating cipher character also means that we do not need to have any special case for blank/empty passwords (https://github.com/gregneagle/pycreateuserpkg/pull/27)
		# since a zero length password will still get a single terminating cipher character which will be the first cipher character, which works for blank/empty passwords on all tested versions of macOS.

		encoded_password_hex_string+="${cipher_key[this_password_hex_char_index % cipher_key_length]}" # Add the next cipher character as termination (as described above).

		encoded_password="$(echo "${encoded_password_hex_string}" | xxd -r -p)" # Convert the encoded hex string back to Unicode characters. Do not need "echo -n" since whitespace (such as a trailing line break) are ignored when converting hex.

		if [[ -z "${encoded_password}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to encode password for auto-login."
			return "${error_code}"
		fi

		# Although, when enabling auto-login through System Preferences, the encoded password *is* padded out to multiples of 12 (cipher_key_length + 1) bytes (not characters) *after* always adding a single terminating cipher character.
		# But, unlike other code that repeats the cipher characters as padding, macOS includes random data as the padding out to multiples of 12 bytes (after including a single terminating cipher character).
		# If the encoded password is already a multiple of 12 bytes *after* a single terminating cipher character has been added, no random data is needed or added by the following code or by macOS (but that means, for example, that the same 11 character password will always be encoded identically).
		# This behavior is noted in the earliest known documented decoding of the kcpassword file: "Interestingly OS-X writes the file in multiples of 12 bytes. Any excess seems to be random data." (https://web.archive.org/web/20180408062145/http://www.brock-family.org/gavin/perl/kcpassword.html)
		# Since only a single terminating cipher character is actually required, this random data padding seems to be intentional obfuscation (maybe to hide the actual length of most encoded passwords and maybe also so each encoded password is usually unique even for most identical passwords).
		# This extra obfuscation isn't required for auto-login to work and doesn't really add any valuable security/obfuscation since it's so easy to decode kcpassword contents: https://tinyapps.org/blog/201709070700_kcpassword.html & https://www.brunerd.com/blog/2021/09/16/decoding-macos-automatic-login-details/
		# But, since the goal is to match the behavior of macOS as closely as possible, add this random data out to multiples of 12 bytes anyway after adding a single terminating cipher character.
		# I don't think this random data needs to be XORed with the cipher characters since it's just gibberish either way.

		encoded_password_random_data_padding_multiples="$(( cipher_key_length + 1 ))"
		until (( ($(echo -n "${encoded_password}" | wc -c) % encoded_password_random_data_padding_multiples) == 0 )); do # Use "wc -c" to properly count bytes instead of characters. And must pipe to "wc" with "echo -n" to not count a trailing line break character.
			# Adding the random data bytes in a loop even though the following command *should* add them all at once, but it sometimes ends up with 1 too few bytes than specified and I'm not exactly sure why.
			# Maybe NUL characters or other special characters confuse "head -c"? But, adding the random bytes in a loop until the byte count is correct seems to work reliably.
			# Doing it this way rather than adding 1 byte at a time in this loop means fewer passes through the loop (usually just 1 loop pass will be needed) and when 1 too few bytes are returned in the first pass, it'll be fixed in the second pass with the same code.
			encoded_password+="$(head -c "$(( encoded_password_random_data_padding_multiples - ($(echo -n "${encoded_password}" | wc -c) % encoded_password_random_data_padding_multiples) ))" /dev/urandom)"
		done

		rm -rf '/private/etc/kcpassword'

		touch '/private/etc/kcpassword' # Create kcpassword before writing to it to make sure
		chown 0:0 '/private/etc/kcpassword' # this file is properly owned by root:wheel and set
		chmod 600 '/private/etc/kcpassword' # permissions for other users to have No Access, like macOS does when it creates this file.
		# Setting ownership and permissions BEFORE writing the contents is important since the file will contain an easily decipherable version of the password.

		echo -n "${encoded_password}" > '/private/etc/kcpassword'

		if [[ ! -f '/private/etc/kcpassword' || "$(cat /private/etc/kcpassword)" != "${encoded_password}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to create kcpassword file for auto-login."
			return "${error_code}"
		fi

		# VERIFY THAT THE KCPASSWORD CONTENTS DECODE CORRECTLY

		encoded_password_hex_string="$(xxd -c 1 -p /private/etc/kcpassword)" # Convert each Unicode character of the kcpassword contents to their hex represention (seperated by line breaks via "-c 1").

		decoded_password_hex_string=''
		this_encoded_password_hex_char_index=0
		IFS=$'\n' # Only loop on line breaks, this is not required since default IFS would work, but I like to be specific.
		for this_encoded_password_hex_char in ${encoded_password_hex_string}; do
			this_cipher_char="${cipher_key[this_encoded_password_hex_char_index % cipher_key_length]}"

			if [[ "${this_encoded_password_hex_char}" == "${this_cipher_char}" ]]; then
				break
			else
				# Do the kcpassword DECODING by XORing each encoded password hex character with a cipher hex character (and keep looping through the cipher hex characters in order)
				# which will return the integer representation from $(( 0x## ^ 0x## )) and then use printf '%02x' to convert the XORed integer to its hex character (this is the same as encoding).
				decoded_password_hex_string+="$(printf '%02x' "$(( 0x${this_encoded_password_hex_char} ^ 0x${this_cipher_char} ))") "
				(( this_encoded_password_hex_char_index ++ ))
			fi
		done
		unset IFS

		decoded_password="$(echo "${decoded_password_hex_string}" | xxd -r -p)" # Convert the decoded hex string back to Unicode characters. Do not need "echo -n" since whitespace (such as a trailing line break) are ignored when converting hex.

		if [[ "${decoded_password}" != "${user_password}" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to decode kcpassword file for auto-login."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if $set_auto_login; then
		defaults write '/Library/Preferences/com.apple.loginwindow' autoLoginUser -string "${user_account_name}"

		if [[ "$(defaults read '/Library/Preferences/com.apple.loginwindow' autoLoginUser)" != "${user_account_name}" ]]; then # Intentionally letting "defaults" output to stderr for useful user feedback.
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to set autoLoginUser for auto-login."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if $did_create_home_folder && $skip_setup_assistant_on_first_login && [[ ! -f "${user_home_path}/.skipbuddy" ]]; then
		if ! $suppress_status_messages; then
			echo "mkuser: Setting first login Setup Assistant for ${user_full_and_account_name_display} user to be skipped..."
		fi

		sudo -u "${user_account_name}" touch "${user_home_path}/.skipbuddy" || touch "${user_home_path}/.skipbuddy" # Create file to skip first login Setup Assistant for user like System Image Utility did: https://discussions.apple.com/thread/7501089
		# Run "touch" as the user so the file is owned by the user (as is normal for files within a home folder): https://scriptingosx.com/2020/08/running-a-command-as-another-user/
		# "launchctl asuser" does not seem to necessary or helpful when running "touch" as another user, "sudo -u" is sufficient. But, if "sudo -u" fails (like it seems to for UID "-1"), just create the file as "root" instead.

		if [[ ! -f "${user_home_path}/.skipbuddy" ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to skip Setup Assistant on first login."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if $skip_setup_assistant_on_first_boot && [[ ! -f '/private/var/db/.AppleSetupDone' ]]; then
		if ! $suppress_status_messages; then
			echo 'mkuser: Setting first boot Setup Assistant to be skipped...'
		fi

		touch '/private/var/db/.AppleSetupDone'
		chown 0:0 '/private/var/db/.AppleSetupDone' # Make sure this file is properly owned by root:wheel.

		if [[ ! -f '/private/var/db/.AppleSetupDone' ]]; then
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to skip Setup Assistant on first boot."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if [[ -n "${st_admin_account_name}" ]]; then
		if ! $boot_volume_is_apfs; then # Should never hit this condition since st_admin_account_name will have been cleared if not running on an APFS boot volume, but doesn't hurt to check anyway.
			>&2 echo 'mkuser WARNING: NOT granting Secure Token since Secure Tokens are an APFS feature and the boot volume is not formatted as APFS.'
		elif [[ "$(sysadminctl -secureTokenStatus "${user_account_name}" 2>&1)" != *'is ENABLED for'* || "$(diskutil apfs listUsers / 2> /dev/null)" != *$'\n'"+-- ${user_guid}"$'\n'* || $'\n'"$(fdesetup list 2> /dev/null)"$'\n' != *$'\n'"${user_account_name},${user_guid}"$'\n'* ]]; then
			if ! $suppress_status_messages; then
				echo "mkuser: Using existing Secure Token admin \"${st_admin_account_name}\" to grant ${user_full_and_account_name_display} user a Secure Token..."
			fi

			# When run in a Terminal, the CLI interactive password prompts of "sysadminctl -secureTokenOn" fails to accept passwords over 128 bytes for some reason for the grantee OR the Secure Token admin granter (interactive "dscl . -authonly" has the same issue),
			# but when run like is done below by passing the passwords via stdin, that odd 128 byte bug/limitation seems to not be an issue, and while I don't really understand why it is quite nice to not have that limitation (the input must be getting processed differently somehow).
			# But, all CLI interactive password prompts (including the "read -rs" prompts in this script) CANNOT accept secure input of 1024 bytes or more, which this technique is also limited by.
			# And while that doesn't matter for our usage since mkuser does not allow new user passwords over 511 bytes, an existing Secure Token admin granter password made by other means could theoretically have a password of 1024 bytes (or longer) which would fail to authenticate in the following command.
			# While passing passwords this way does actually allow a 1023 byte password for the grantee, there seems to be some other odd limitation (or bug) that I don't fully understand that limits the Secure Token admin granter password length to 1022 bytes instead of 1023 bytes.
			# What's odd is that when a Secure Token admin granter password of 1023 bytes is attempted, the failure error message states that the *grantee* password was wrong when that password is not the issue and it is actually the length of the granter password that is causing the failure.
			# This 1022 byte Secure Token admin granter limitation has been confirmed on macOS 10.14 Mojave, macOS 10.15 Catalina, macOS 11 Big Sur, and macOS 12 Monterey but it's actually NOT a limitation on macOS 10.13 High Sierra where 1023 byte admin granter passwords are allowed,
			# but still not going to allow 1023 byte Secure Token admin granter passwords on macOS 10.13 High Sierra for simplicity and consistency across macOS versions.
			# Therefore, Secure Token admin passwords used with to mkuser are limited to 1022 bytes so that they are always useable and any longer are rejected before user creation rather than failing when attempting to grant a Secure Token when the password is actually correct.

			# This process was previously done using "expect", but that had the 128 byte password length limitation as described above, and "expect" also did not support emoji (but does support other multibyte characters) so would fail if either password contained emoji.
			# While that is likely a very rare edge case, passing the passwords via stdin as done below is much simpler and more robust as it handles longer passwords and emoji just fine.

			# This technique of passing stdin via pipe to "sysadminctl -secureTokenOn" has been tested on macOS 10.13 High Sierra, macOS 10.14 Mojave, macOS 10.15 Catalina, macOS 11 Big Sur, and macOS 12 Monterey.
			# The passwords could also be passed to stdin via here-doc or here-string which have the same behavior and limitations as piping, but those techniques
			# create a momentary temporary file in the filesystem while piping does not, so piping is a more secure way to pass sensitive data to commands.

			# SIDE NOTES ABOUT ODD BEHAVIOR ON macOS 10.13 High Sierra:
			# While macOS 10.13 High Sierra allows 1023 byte Secure Token admin granter passwords, it also allows much longer grantee passwords, which I tested with up to 1,000,000 byte long passwords.
			# But, when trying to then use these Secure Token users with passwords longer than 1023 bytes as the Secure Token admin granter for another account, their password verification fails (via the native OpenDirectory methods used in the "mkuser_verify_password" function as well as "dscl . -authonly" and they cannot authenticate in System Preferences).
			# When testing this further, I found that while a user with a password over 1023 bytes can be granted a Secure Token, something about Secure Tokens is not actually compatible with those longer passwords and their password effectively gets broken and no longer works at all once the Secure Token is granted.
			# If a Secure Token is not granted, these passwords longer than 1023 bytes continue to work fine in all authentication and verification tests I did as long as the user doesn't have a Secure Token.
			# So, that means a 1023 byte password can be used to grant a Secure Token, but any longer will never work because those length passwords get broken once the account is granted a Secure Token.
			# On some newer version of macOS I had previously tested that longer passwords (up to 10,000 bytes) can work when passed to "sysadminctl -secureTokenOn" directly as arguments, BUT passing the passwords as arguments would make them visible in the process list so it was never a secure option for usage in mkuser.
			# And, I don't remember if I ever tried authenticating those accounts with passwords over 1023 bytes after they had been granted a Secure Token or used them to grant another user a Secure Token since I wasn't aware of this issue when I did that quick testing with passing longer passwords to "sysadminctl -secureTokenOn" as arguments in the past.
			# I haven't bothered fully testing if this brokenness with Secure Tokens and passwords longer than 1023 is actually the same on newer versions of macOS or if it has been fixed since that would just be for my own curiosity as it's not even possible to grant accounts with passwords longer than 1023 bytes a Secure Token with the technique used in mkuser in the first place.
			# None of this brokenness affects mkuser directly at all since these longer passwords would never be allowed to be granted a Secure Token, or allowed to be used to grant a Secure Token.
			# This information is just documentation of my testing when I was trying to understand some odd behavior on macOS 10.13 High Sierra that didn't make sense at first.

			# Do an actual line break instead of "\n" which would require "-e" and would incorrectly interpret any possible literal backslashes in the passwords.
			grant_secure_token_output="$(echo "${st_admin_password}
${user_password}" | sysadminctl -secureTokenOn "${user_account_name}" -password - -adminUser "${st_admin_account_name}" -adminPassword - 2>&1)"

			grant_secure_token_exit_code="$?" # Exit code will be 0 even if there was an error, but that's fine and doesn't hurt to check it anyway since we're also checking (in every possible way) that the user was actually granted a Secure Token.

			if (( grant_secure_token_exit_code != 0 )) || [[ "${grant_secure_token_output}" != *'] - Done!'* || "$(sysadminctl -secureTokenStatus "${user_account_name}" 2>&1)" != *'is ENABLED for'* || "$(diskutil apfs listUsers / 2> /dev/null)" != *$'\n'"+-- ${user_guid}"$'\n'* || $'\n'"$(fdesetup list 2> /dev/null)"$'\n' != *$'\n'"${user_account_name},${user_guid}"$'\n'* ]]; then
				echo "${grant_secure_token_output}" | grep -F 'sysadminctl[' >&2 # If there was an error, show the sysadminctl output lines since it may be informative.
				>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to grant Secure Token using existing Secure Token admin \"${st_admin_account_name}\"."
				return "${error_code}"
			fi
		elif ! $suppress_status_messages; then
			echo "mkuser: Do not need to manually grant ${user_full_and_account_name_display} user a Secure Token (as specified) since user already has one (maybe from a Bootstrap Token)..."
		fi
	fi
	(( error_code ++ ))

	if $boot_volume_is_apfs && [[ -n "${st_admin_account_name}" || ( "$(sysadminctl -secureTokenStatus "${user_account_name}" 2>&1)" == *'is ENABLED for'* && "$(diskutil apfs listUsers / 2> /dev/null)" == *$'\n'"+-- ${user_guid}"$'\n'* && $'\n'"$(fdesetup list 2> /dev/null)"$'\n' == *$'\n'"${user_account_name},${user_guid}"$'\n'* ) ]]; then
		# Update Preboot Volume separately from granting a Secure Token so that the Preboot Volume will also get updated when macOS has granted this account the first Secure Token or if the account was granted a Secure Token from a Bootstrap Token.

		got_first_secure_token="$([[ -z "${st_admin_account_name}" ]] && echo 'true' || echo 'false')"

		if ! $suppress_status_messages; then
			echo "mkuser: Updating Preboot Volume after $($got_first_secure_token && echo 'macOS granted' || echo 'granting') ${user_full_and_account_name_display} user $($got_first_secure_token && echo 'the first' || echo 'a') Secure Token (PLEASE WAIT, THIS MAY TAKE 10 SECONDS OR LONGER)..."
		fi

		# Update the Preboot Volume after a Secure Token is granted since I've seen that the new account may not be included in the FileVault login window (if FileVault is enabled),
		# and may not be included in Recovery for Startup Security authentication (if the account is an administrator on a T2 or Apple Silicon Mac).
		# So, it seems like it may just be best practice to always update the Preboot Volume after a new Secure Token user is added no matter what.
		# The only downside is that this process is not super quick, it can take around 10 seconds or so (but could be shorter or longer as the time depends on how many total Secure Token users exist).

		if ! diskutil_apfs_update_preboot_output="$(diskutil apfs updatePreboot / 2>&1)" || [[ "${diskutil_apfs_update_preboot_output}" != *$'UpdatePreboot: Exiting Update Preboot operation with overall error=(ZeroMeansSuccess)=0\nFinished APFS operation' ]]; then
			echo "${diskutil_apfs_update_preboot_output}" | tail -2 >&2 # If there was an error, show the last 2 updatePreboot output lines since it may be informative.
			>&2 echo "mkuser ERROR ${error_code}-${LINENO}: Created user \"${user_account_name}\", but failed to update the Preboot Volume after $($got_first_secure_token && echo 'macOS granted' || echo 'granting') Secure Token."
			return "${error_code}"
		fi
	fi
	(( error_code ++ ))

	if ! $suppress_status_messages; then
		echo "mkuser: Successfully created ${creating_user_type} ${user_full_and_account_name_display} and all ${error_code} verifications passed!"
	fi

	return 0
)

mkuser "$@"

exit "$?"
