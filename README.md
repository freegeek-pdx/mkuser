# `mkuser` for macOS

`mkuser` **m**a**k**es **user** accounts for macOS with more options, more validation of inputs, and more verification of the created user account than any other user creation tool, including `sysadminctl -addUser` and System Preferences!

`mkuser` supports and has been thoroughly tested with macOS 10.13 High Sierra and newer (it likely works on older versions of macOS as well, but that hasn't been tested). The newest version of macOS that `mkuser` has been tested with as of writing this is macOS 12 Monterey. Because of how `mkuser` is written and the built-in tools it uses to create user accounts, it should support future versions of macOS without any major issues as the fundamentals of user creation have been consistent for years across many versions of macOS. If somehow an issue does occur with a future version of macOS, `mkuser`'s excessive verifications should detect the issue and present a detailed error message.

Along with abundant options and excessive verifications, `mkuser` has detailed help info which explains each available option and what affect it will have on the created user account. This info may be informative beyond just using `mkuser` since it's really all about all the different kinds of advanced customizations user accounts can have on macOS.

`mkuser` is also focused on precision and accuracy. The user accounts created by `mkuser` should be indistinguishable from a user account created by `sysadminctl -addUser` or System Preferences. This may not sound like much, but if you read through the source you'll see that there are a variety of subtleties and nuances that took quite a bit of research and effort to match exactly what `sysadminctl -addUser` and System Preferences does. Also, `mkuser` actually does better in some situations to avoid possible errors or macOS bugs! If you're interested in this, there are many detailed technical notes throughout the source that basically serve as a study in user account creation. No other scripted user account creation that I'm aware of creates user accounts as accurately as `mkuser`.

`mkuser` is a single function within a single script written in `bash` with no external dependencies. If you want to incorporate `mkuser`'s functionality into your own `bash` (not `zsh`) script without requiring another file, you can simply copy-and-paste the whole function into your code. Or, of course, you can call the separate `mkuser` script file from any code written in any language or directly on the command line.

Some of the features of `mkuser` that are not available in other user creation tools are: create a user immediately or save a user creation package, setup automatic login, skip Setup Assistant on first boot and/or first login, prohibit standard users from changing their own password or picture, and prevent the first user from getting a Secure Token, along with all other normal user creation options you would expect and more.

<br/>

## ℹ️ USAGE NOTES

For long form options (multicharacter options starting with two hyphens), case doesn't matter.<br/>
For example, `--help`, `--HELP`, and `--Help` are all equal.<br/>

For short form options (single character options starting with one hyphen), case DOES matter.<br/>
For example, `-h` and `-H` are NOT equal.<br/>

Short form options can be grouped together or passed individually.<br/>
But, only a single option within a group can take a parameter and it must be the last option specified within the group.<br/>
For example, `-qaAn <ACCOUNT NAME>` is valid but `-qanA <ACCOUNT NAME>` is not.<br/>
Also, `-qan <ACCOUNT NAME> -Af <FULL NAME>` is valid but `-qaAnf <ACCOUNT NAME> <FULL NAME>` is not.<br/>
An error will be displayed if options with parameters are grouped incorrectly.

Long form options can have their word separating hyphens omitted.<br/>
For example, `--user-id`, `--userid`, and `--userID` are all equal (since the case also doesn't matter).<br/>
This does NOT mean word separating hyphen placement doesn't matter, all of the word separating hyphens must be correct, or all omitted.

Options and their parameters can be separated by whitespace, equals (=), and can also be combined without using whitespace or equals (=).<br/>
For example, `--uid <UID>`, `--uid=<UID>`, `--uid<UID>`, `-u <UID>`, `-u=<UID>`, and `-u<UID>` are all valid.<br/>
When combining single character options with their parameter, be careful to not set a parameter whose first letter is also a valid single character option as this would be interpreted as combined single character options.<br/>
For example, `-nuser` would get interpreted as `-n -u=ser` (which would error for multiple reasons) instead of `-n=user` since `-u` is also a valid option.<br/>
In these cases, the options and parameters should be separated instead.<br/>
But, something like `-u401` will always be safe since `-4` is not a valid option.

If ANY options or parameters are invalid, the user or package WILL NOT be created.<br/>
Instead, the invalid option errors and errors from other checks will be shown.

When creating a user on the current system (not using the `--package` option), you will be prompted for confirmation before the user is created.<br/>
To NOT be prompted for confirmation (such as when run within a script), you must specify `--do-not-confirm` (`-F`) or `--suppress-status-messages` (`-q`) or `--stdin-password`.

<br/>

## 👤 PRIMARY OPTIONS

#### `--account-name, --record-name, --short-name, --username, --user, --name, -n` < *string* >

> Must only contain lowercase letters, numbers, hyphen/minus (-), underscore (_), or period (.) characters.<br/>
> The account name cannot start with a period (.) or hyphen/minus (-).<br/>
> Must be 244 characters/bytes or less and must contain at least one letter.<br/>
> The account name must not already be assigned to another user.<br/>
> If omitted, the full name will be converted into a valid account name by converting it to meet the requirements stated above.
>
> **244 CHARACTER/BYTE ACCOUNT NAME LENGTH LIMIT NOTES:**<br/>
> The account name is used as the OpenDirectory RecordName, which has a hard 244 byte length limit (and the allowed characters are always 1 byte each).<br/>
> Attempting to create a user with an account name over 244 characters will fail regardless of if you try to use `sysadminctl`, `dscl`, or `dsimport`.
>
> **ACCOUNT NAMES STARTING WITH PERIOD (.) NOTES:**<br/>
> System Preferences actually allows account names to start with a period (.), but that causes the account name to not show up in `dscacheutil -q user` or `dscl . -list /Users` even though the user does actually exist.<br/>
> Also, since users with account names starting with a period (.) are NOT properly detected by macOS, their existence can break next available UID assignment by `sysadminctl -addUser` and System Preferences and both could keep incorrectly assigning the UID of the account name starting with a period (.) which fails and results in users created with no UID.<br/>
> Since allowing account names starting with a period (.) would cause those issues and `mkuser` would not be able to verify that the user was properly created, starting with a period (.) is not allowed by `mkuser`.

<br/>

#### `--full-name, --real-name, -f` < *string* >

> The only limitations on the characters allowed in the full name are that it cannot be only whitespace and cannot contain control characters other than tabs (such as line breaks).<br/>
> See notes below about the non-specific length limit of the full name.<br/>
> The full name must not already be assigned to another user.<br/>
> If omitted, the account name will be used as the full name.
>
> **FULL NAME LENGTH LIMIT NOTES:**<br/>
> While there is no explicit length limit, there is a combined byte length limit of the account name, full name, login shell, and home folder path.<br/>
> If the combined byte length of these 4 attributes is over *1010 bytes*, the full name will not load in the "Log Out" menu item of the "Apple" menu.<br/>
> While this is not a serious issue, it does indicate a bug or limitation within some part of macOS that we do not want to trigger.<br/>
> `mkuser` will do this math for you and show an error with all of the byte lengths as well as how many bytes need to be removed for these 4 attributes to fit within the combined 1010 byte length limitation.<br/>
> This 1010 byte length limit should not be hit under normal circumstances, so you will generally not need to worry about hitting this limit.<br/>
> For a bit more technical information about this issue from my testing, search for *1010 bytes* within the source of this script.
>
> Even though `mkuser` will not allow it, if the byte length of these 4 combined attributes was over 1010 bytes, the account still logs in and seems to work properly other than not loading the full name in the "Log Out" menu item of the "Apple" menu.<br/>
> But, if this combined byte length is over 2034 bytes, the account cannot login via login window as well as when using the `login` or `su` commands.<br/>
> For a bit more technical information about this issue from my testing, search for *2034 bytes* within the source of this script.

<br/>

#### `--unique-id, --user-id, --uid, -u` < *integer* >

> Must be an integer between -2147483648 and 2147483647 (signed 32-bit range).<br/>
> The User ID (UniqueID) must not already be assigned to another user.<br/>
> If omitted, the next User ID available from *501* will be used, unless creating a `--role-account` or `--service-account`, then starting from *200*.<br/>
> If you're the kind of person that has noticed that UIDs may be represented outside of this range, you may be interested in reading the *UIDs CAN BE REPRESENTED IN DIFFERENT FORMS* comments in this script.
>
> **NEGATIVE USER ID NOTES:**<br/>
> Negative User IDs should not be created under normal circumstances.<br/>
> Negative User IDs are normally reserved for special system users and users with negative User IDs may not behave properly or as expected.

<br/>

#### `--generated-uid, --guid, --uuid, -G` < *string* >

> Must be 36 characters of only capital letters, numbers, and hyphens/minuses (-) in the following format: *EIGHT888-4444-FOUR-4444-TWELVE121212*<br/>
> The Generated UID (GUID) must not already be assigned to another user.<br/>
> If omitted, a random Generated UID will be assigned by macOS.<br/>
> You should not normally need to manually specify a Generated UID.

<br/>

#### `--primary-group-id, --group-id, --group, --gid, -g` < *integer* >

> Must be an integer between -2147483648 and 2147483647 (signed 32-bit range).<br/>
> The Group ID must already exist, non-existent Group IDs will not be created.<br/>
> If omitted, the default Primary Group ID of *20* (staff) will be used, unless creating a `--service-account`, then *-2* (nobody) will be used.<br/>
> If you're the kind of person that has noticed that GIDs may be represented outside of this range, you may be interested in reading the *UIDs CAN BE REPRESENTED IN DIFFERENT FORMS* comments in this script.

<br/>

#### `--login-shell, --user-shell, --shell, -s` < *existing path* || *command name* >

> The login shell must be the path to an existing executable file, or a valid command name that can be resolved using `which` (searching within "/usr/bin", "/bin", "/usr/sbin", "/sbin", and "/usr/libexec").<br/>
> You must specify the path if the desired login shell is in another location.<br/>
> If omitted, "/bin/zsh" will be used on macOS 10.15 Catalina and newer and "/bin/bash" will be used on macOS 10.14 Mojave and older.

<br/>

## 🔐 PASSWORD OPTIONS

#### `--password, --pass, -p` < *string* >

> The password must meet the systems password content policy requirements.<br/>
> The default password content requirements are that it must be at least 4 characters, or a blank/empty password when FileVault IS NOT enabled.
>
> If no password content policy is set (such as by default on macOS 10.13 High Sierra), the default requirements *will still be enforced* by `mkuser`.<br/>
> Also, only the default password requirements will be enforced when outputting a user creation package, see notes below for more information.
>
> *Regardless of the password content policy*, `mkuser` enforces a maximum password length of 511 bytes, or 251 bytes when enabling auto-login.<br/>
> See notes below for more details about these maximum length limitations.
>
> The only limitation on the characters allowed in the password is that it cannot contain any control characters such as line breaks or tabs.<br/>
> If omitted, a blank/empty password will be specified.
>
> **BLANK/EMPTY PASSWORD NOTES:**<br/>
> Blank/empty passwords are not allowed by default when FileVault is enabled.<br/>
> When FileVault is not enabled, a user with a blank/empty password WILL be able to log in and authenticate GUI prompts, but WILL NOT be able to authenticate "Terminal" commands like `sudo`, `su`, or `login`, for example.
>
> **AUTO-LOGIN 251 BYTE PASSWORD LENGTH LIMIT NOTES:**<br/>
> Auto-login simply does not work with passwords longer than 251 bytes.<br/>
> I am not sure if this is a bug or an intentional limitation, but if you set a password of 252 bytes or more and enable auto-login, macOS will boot to the login window instead of automatically logged into the user.<br/>
> I am not sure what exactly is failing internally, but the behavior is as if the encoded auto-login password is incorrect.<br/>
> I have confirmed this IS NOT an issue with the auto-login password encoding within `mkuser` since the same thing happens when enabling auto-login in the "Users & Groups" pane of the "System Preferences".
>
> **511 BYTE PASSWORD LENGTH LIMIT NOTES:**<br/>
> Most of macOS can technically support passwords longer than 511 bytes, but both the `login` and `su` commands fail with passwords over 511 bytes.<br/>
> Since 512 byte or longer passwords cannot work in all possible situations, they are not allowed since `mkuser` exists to make fully functional users.<br/>
> If not being able to use the `login` and `su` commands is not an issue, and you want to use a longer password, you can just set a temporary password when creating a user with `mkuser` and then change the password to something 512 bytes or longer manually using `dscl . -passwd`.<br/>
> If you manually set a password 512 bytes or longer, you will be able to login via login window as well as authenticate graphical prompts, such as unlocking "System Preferences" panes if the user in an admin.<br/>
> For fun, I tested logging in via login window with passwords up to 10,000 bytes (typed via an Arduino) and unlocking "System Preferences" panes with passwords up to 150,000 bytes (copy-and-pasted).<br/>
> Longer passwords took overly long for the Arduino to type or macOS to paste.<br/>
> But, that longer password testing was done with non-Secure Token accounts.<br/>
> When an account has a Secure Token, there are other limitations described in the *SECURE TOKEN ADMIN 1022 BYTE PASSWORD LENGTH LIMIT NOTES* in the help information for the `--secure-token-admin-password` option below.
>
> **PASSWORDS IN PACKAGE NOTES:**<br/>
> When outputting a user creation package (with the `--package` option), only the default password content requirements are checked since the password content policy may be different on the target system.<br/>
> The target systems password content policy will be checked when the package is installed and the user will not be created if the password does not meet the target systems password content policy requirements.
>
> The specified password (along with the existing Secure Token admin password, if specified) will be securely obfuscated within the package in such a way that the passwords can only be deobfuscated by the specific and unique script generated during package creation and only when run during the package installation process.<br/>
> For more information about how passwords are securely obfuscated within the package, read the comments within the code of this script starting at: *OBFUSCATE PASSWORDS INTO RUN-ONLY APPLESCRIPT*<br/>
> Also, when the passwords are deobfuscated during the package installation, they will NOT be visible in the process list since they will only exist as variables within the script and be passed to an internal `mkuser` function.

<br/>

#### `--stdin-password, --stdin-pass, --sp` < *no parameter* (stdin) >

> Include this option with no parameter to pass the password via "stdin" using a pipe (`|`) or here-string (`<<<`), etc.<br/>
> **Although, it is recommended to use a pipe instead of a here-string** because a pipe is more secure since a here-string creates a temporary file which contains the specified password while a pipe does not.<br/>
> If you haven't used an `echo` and pipe (`|`) before, it looks like this: `echo '<PASS>' | mkuser [OPTIONS] --stdin-password [OPTIONS]`<br/>
> Passing the password via "stdin" instead of directly with the `--password` option hides the password from the process list.<br/>
> Since `echo` is a builtin in `bash` and `zsh` and not an external binary command, the `echo` command containing the password as an argument is also never visible in the process list.<br/>
> The help information for the `--password` option above also applies to passwords passed via "stdin".<br/>
> **NOTICE:** Specifying `--stdin-password` also ENABLES `--do-not-confirm` since accepting "stdin" disrupts the ability to use other command line inputs.

<br/>

#### `--password-prompt, --pass-prompt, --pp` < *no parameter* >

> Include this option with no parameter to be prompted for the new user password on the command line before creating the user or package.<br/>
> This option allows you to specify a password without it being saved in your command line history as well as hides the password from the process list.<br/>
> The help information for the `--password` option above also applies to passwords entered via command line prompt.

<br/>

#### `--no-password, --no-pass, --np` < *no parameter* >

> Include this option with no parameter to set no password at all instead of a blank/empty password (like when the `--password` option is omitted).<br/>
> This option is equivalent to setting the password to "\*" with `--password '*'` and is here as a separate option for convenience and information.<br/>
> Setting the password to "\*" is a special character that indicates to macOS that this user does not have any meaningful password set.<br/>
> When a user has the "\*" password set, it cannot login by any means and it will also not get any AuthenticationAuthority set in the user record.<br/>
> When the "\*" password is set AND no AuthenticationAuthority exists, the user will not show in the users list in "Users & Groups" pane of the "System Preferences" and will also not show up in the login window.<br/>
> If you choose to start a user out with no password for some reason, you can always set their password later with `dscl . -passwd`.
>
> If you include the `--prevent-secure-token-on-big-sur-and-newer` option with this option, that would create an AuthenticationAuthority attribute with the special tag to prevent a Secure Token from being granted.<br/>
> Since that user would no longer have BOTH no AuthenticationAuthority AND the "\*" password, they would show in the users list in "Users & Groups" pane of the "System Preferences" as well as the login window list of users, but could not log in since no meaningful password is set.

<br/>

#### `--password-hint, --hint, --ph` < *string* >

> Must be 280 characters or less and the only limitations on the characters allowed in the password hint are that it cannot be only whitespace and can't contain control characters other than line breaks (\n) or tabs (\t).<br/>
> Line breaks and tabs can also be included.<br/>
> If omitted, no password hint will be set.
>
> **280 CHARACTER PASSWORD HINT LENGTH LIMIT NOTES:**<br/>
> The password hint popover in the non-FileVault login window will only display up to 7 lines at about 40 characters per line.<br/>
> This results in 280 characters being a reasonable maximum length.<br/>
> Since each character is a different width, 40 characters per line is just an estimation and less or more may fit depending on the characters, for example, only 14 smiley face emoji fit on a single line.<br/>
> If line breaks are included, they are rendered in the password hint popover and that can make less characters show since only up to 7 lines will show.<br/>
> If for some reason you need or want a longer password hint, you can just set a temporary password hint when creating a user with `mkuser` and then change the password hint to something longer manually with: `dscl . -create /Users/<ACCOUNT NAME> AuthenticationHint '<PASSWORD HINT>'`

<br/>

#### `--prohibit-user-password-changes` < *no parameter* >

> Include this option with no parameter to prohibit the user from being able to change their own password without administrator authentication.<br/>
> The password can still be changed in the "Users & Groups" pane of the "System Preferences" when unlocked and authenticated by an administrator.

<br/>

## 📁 HOME FOLDER OPTIONS

#### `--home-folder, --home-path, --home, -H` < *non-existing path* >

> The home folder path must not currently exist, unless specifying the special "/var/empty" or "/dev/null" paths.<br/>
> The total length of the home folder path must be 511 bytes or less, or home folder creation will fail during login or `createhomedir`.<br/>
> Each folder within the home folder path must be 255 bytes or less each, as that is the max folder/file name length set by macOS.<br/>
> If the home folder is not within the "/Users/" folder, the users Public folder will not be shared.<br/>
> If omitted, the home folder will be set to "/Users/\<ACCOUNT NAME\>".

<br/>

#### `--do-not-share-public-folder, --dont-share-public` < *no parameter* >

> Include this option with no parameter to NOT share the users Public folder.<br/>
> The users Public folder will be shared by default unless the users home folder is hidden or is not within the "/Users/" folder.<br/>
> The users Public folder can still be shared manually in the "File Sharing" section of the "Sharing" pane of the "System Preferences".

<br/>

#### `--do-not-create-home-folder, --dont-create-home` < *no parameter* >

> Include this option with no parameter to NOT create the users home folder.<br/>
> The users home folder will be created by macOS when the user is logged in graphically via login window, but will not be created when logging in via "Terminal" using the `login` or `su` commands, for example.<br/>
> To create the home folder at anytime via "Terminal" or script, you can use the `createhomedir -cu <ACCOUNT NAME>` command.<br/>
> When using this option, you CANNOT also specify `--hide homeOnly` or `--skip-setup-assistant firstLoginOnly` since they require the home folder.

<br/>

## 🖼 PICTURE OPTIONS

#### `--picture, --photo, --pic, -P` < *existing path* || *default picture filename* >

> Must be a path to an existing image file that is 1 MB or under, or be the filename of one of the default user pictures located within the "/Library/User Pictures/" folder (with or without the file extension, such as "Earth" or "Penguin.tif").<br/>
> When outputting a user creation package (with the `--package` option), the specified picture file will be included in the user creation package.<br/>
> If omitted, a random default user picture will be assigned.

<br/>

#### `--no-picture, --no-photo, --no-pic` < *no parameter* >

> Include this option with no parameter to not set any picture instead of a random default user picture (like when the `--picture` option is omitted).<br/>
> When no picture is set, a grey head and shoulders silhouette icon is used.

<br/>

#### `--prohibit-user-picture-changes` < *no parameter* >

> Include this option with no parameter to prohibit the user from being able to change their own picture without administrator authentication.<br/>
> The picture can still be changed in the "Users & Groups" pane of the "System Preferences" when unlocked and authenticated by an administrator.

<br/>

## 🎛 ACCOUNT TYPE OPTIONS

#### `--administrator, --admin, -a` < *no parameter* >

> Include this option with no parameter to make the user an administrator.<br/>
> Administrators can manage other users, install apps, and change settings.
>
> If omitted, a standard user will be created.<br/>
> Standard users can install apps and change their own settings, but can't add other users or change other users' settings.
>
> For more information about administrator and standard account types, visit: <https://support.apple.com/guide/mac-help/mtusr001>

<br/>

#### `--hidden, --hide` < *userOnly* || *homeOnly* || *both* (or *no parameter*) >

> Include this option with either no parameter or specify "*both*" to hide both the user and their home folder.
>
> Specify "*userOnly*" to hide only the user and keep the home folder visible.<br/>
> Hidden users will not show in the users list in "Users & Groups" pane of the "System Preferences" unless they are currently logged in, and will also not show up in the login window list of users (unless they have a Secure Token and FileVault is enabled).<br/>
> A hidden user can still be logged into by using text input fields in the non-FileVault login window.
>
> Specify "*homeOnly*" to hide only the home folder and keep the user visible.<br/>
> If the home folder is hidden, the users Public folder will not be shared.
>
> Any other parameters are invalid and will cause the user to not be created.

<br/>

#### `--sharing-only-account, --sharing-account, --sharing-only, --sharing, --soa` < *no parameter* >

> Include this option with no parameter to create a "Sharing Only" account.
>
> This is identical to a "Sharing Only" account that can be created in the "Users & Groups" pane of the "System Preferences" when adding a new user and changing the "New Account" pop-up menu to "Sharing Only".<br/>
> A "Sharing Only" account can access shared files remotely, but can't log in or change settings on the computer.
>
> A "Sharing Only" account is equivalent to creating a user with the login shell set to "/usr/bin/false" and home set to "/dev/null" .<br/>
> This can also be done manually with `--shell /usr/bin/false --home /dev/null`, or `--no-login --home /dev/null` (see `--no-login` help for more information).<br/>
> Make sure to specify a password when creating a "Sharing Only" account, or it will have *a blank/empty password*.
>
> Also, when running on macOS 11 Big Sur or newer, "Sharing Only" accounts get a special tag added to the AuthenticationAuthority attribute of the user record to let macOS know not to grant a Secure Token.<br/>
> See `--prevent-secure-token-on-big-sur-and-newer` help for more information about preventing macOS from granting an account the first Secure Token.
>
> This is here as a separate option for convenience and information.<br/>
> When using this option, you CANNOT also specify `--administrator`, since "Sharing Only" accounts should not be administrators.<br/>
> Also, you cannot specify `--role-account` or `--service-account` with this option since they are mutually exclusive account types.<br/>
> For more information about "Sharing Only" accounts, visit: <https://support.apple.com/guide/mac-help/mchlp15577>

<br/>

#### `--role-account, --role, -r` < *no parameter* >

> Include this option with no parameter to create a "Role Account".
>
> A `-roleAccount` option was added to `sysadminctl -addUser` in macOS 11 Big Sur, but sadly there is not really any documentation from Apple about what exactly a "Role Account" is or when and why you would want to use one.<br/>
> I believe you would want to use a "Role Account" when you want a user exclusively to be the owner of files and/or processes and ***have a password***.<br/>
> All `sysadminctl` states about them is the following: **Role accounts require name starting with _ and UID in 200-400 range.**<br/>
> And `mkuser` has these same requirements to create a "Role Account".<br/>
> Even though the `-roleAccount` option was only added to `sysadminctl -addUser` in macOS 11 Big Sur, `mkuser` can make "Role Accounts" with the same attributes on older versions of macOS as well.
>
> Using this option is the same as creating a "Role Account" using `sysadminctl -addUser` with a command like: `sysadminctl -addUser _role -UID 201 -roleAccount`<br/>
> This example `sysadminctl -addUser` command would create a "Role Account" with the account name and full name of "_role" and the User ID "201".<br/>
> **IMPORTANT:** The example account would be created with *a blank/empty password*.
>
> If you want to make an account exclusively to be the owner of files and/or processes that *has NO password*, you probably want to use the `--service-account` option instead of this `--role-account` option.
>
> Through investigation of a "Role Account" created by `sysadminctl -addUser`, a "Role Account" is equivalent to creating a hidden user with account name starting with "_" and login shell "/usr/bin/false" and home "/var/empty".<br/>
> The previous example account could be created manually with `mkuser` using: `-n _role -u 201 -s /usr/bin/false -H /var/empty --hide userOnly` or `--name _role --uid 201 --no-login --home /var/empty --hide userOnly`.<br/>
> See `--no-login` help for more information about login shell "/usr/bin/false".<br/>
> See `--hidden` help for more information about hiding users (`--hide userOnly`).
>
> This is here as a separate option for convenience and information.<br/>
> So, this same example account could be created with `mkuser` using: `--account-name _role --uid 201 --role-account`
>
> Unlike `sysadminctl -addUser` which requires the User ID to be specified manually, `mkuser` can assign the next available User ID starting from *200*.<br/>
> So if the User ID is not important, you can just use `--name _role --role` to make this same example account with the next User ID in the 200-400 range.
>
> `sysadminctl -addUser` does not allow creating an admin "Role Account".<br/>
> If you run `sysadminctl -addUser _role -UID 201 -roleAccount -admin`, the `-admin` option is silently ignored by `sysadminctl -addUser`.<br/>
> `mkuser` also does not allow a "Role Account" to be an admin, but errors when using the `--admin` option with `--role-account` instead of ignoring it.<br/>
> Also, you cannot specify `--sharing-only` or `--service-account` with this option since they are mutually exclusive account types.

<br/>

#### `--service-account, --service, --sa` < *no parameter* >

> Include this option with no parameter to create a "Service Account".
>
> A "Service Account" is similar to a "Role Account" in that it exists exclusively to be the owner of files and/or processes but ***has NO password***.<br/>
> This is like macOS built-in accounts, such as the "FTP Daemon" (_ftp) user.
>
> Through investigation of the built-in macOS "Service Accounts", a "Service Account" is roughly equivalent to creating a standard user with name starting with "_", login shell "/usr/bin/false", home "/var/empty", and *NO password* (see `--no-password` for more information about that).<br/>
> See `--no-login` help for more information about login shell "/usr/bin/false".<br/>
> But, this is just a basic template of a "Service Accounts".
>
> These are not all hard requirements for a "Service Account".<br/>
> The hard requirements are that the account name must start with "_", must have NO password, must have no picture, CANNOT be an admin, and the home folder cannot be within the "/Users/" folder.<br/>
> But, you can specify any User ID, Primary Group ID, or login shell.<br/>
> If `--user-id` is omitted, the next available User ID starting from *200* will be assigned by default (the same as a "Role Account").<br/>
> If `--group-id` is omitted, the *-2* (nobody) group will be used.<br/>
> If `--login-shell` is omitted, the "/usr/bin/false" will be used.<br/>
> If `--home-folder` is omitted, "/var/empty" will be used.
>
> Also, you cannot specify `--sharing-only` or `--role-account` with this option since they are mutually exclusive account types.
>
> While you can pretty much make a "Service Account" manually using the other `mkuser` options, there is a difference when you specify `--service-account`.<br/>
> All other account types get a variety of attributes added to the user record that allow the user to manage some aspects of their own account, but none of these attributes are included for built-in macOS "Service Accounts".<br/>
> To match the built-in macOS "Service Accounts", these management attributes will not be included in the user record when specifying `--service-account`.<br/>
> Excluding some (not all) of these specific management attributes is how the `--prohibit-user-password-changes` and `--prohibit-user-picture-changes` options work.
>
> **GROUPS SPECIFICALLY FOR SERVICE ACCOUNTS NOTES:**<br/>
> Many built-in macOS "Service Accounts" have a group specifically for them, and often that Group ID is the same as the "Service Accounts" User ID and the Group ID is set to the Primary Group ID of the "Service Account".
>
> If you specify a Primary Group ID (`--group-id`), it must already exist.<br/>
> If you want to create a group just to be used with a "Service Account", you can do that easily before making the "Service Account" with: `dseditgroup -o create -i <GROUP ID> -r <GROUP FULL NAME> <GROUP NAME>`<br/>
> When you do this before creating a "Service Account" with `mkuser`, you can set the "Service Account" Primary Group ID to this Group ID with `--gid`.<br/>
> After creating the "Service Account", you can also add it to the group with: `dseditgroup -o edit -a <SERVICE ACCOUNT NAME> -t user <GROUP NAME>`<br/>
> But, that is not really necessary if the "Service Account" already has its Primary Group ID set to the Group ID.

<br/>

#### `--prevent-secure-token-on-big-sur-and-newer, --prevent-secure-token, --no-st` < *no parameter* >

> Include this option with no parameter to prevent the user from being automatically granted the first Secure Token on macOS 11 Big Sur and newer when and if they are being created when the first Secure Token has not yet been automatically granted by macOS.<br/>
> This option is helpful when creating scripted users before going through Setup Assistant that you do not want to be granted the first Secure Token, which would prevent the Setup Assistant user from getting a Secure Token.<br/>
> This option will add a special tag to the AuthenticationAuthority attribute of the user record to let macOS know not to grant a Secure Token.<br/>
> For more information about this Secure Token prevention tag, visit: <https://support.apple.com/guide/deployment/dep24dbdcf9e><br/>
> A Secure Token could still be manually granted to this user after specifying this option on macOS 11 Big Sur and newer with `sysadminctl -secureTokenOn`.<br/>
> This option has no effect on macOS 10.15 Catalina and older, but there is useful information below about first Secure Token behavior all the way back to macOS 10.13 High Sierra when Secure Tokens were first introduced.
>
> **VOLUME OWNER ON APPLE SILICON NOTES:**<br/>
> On Apple Silicon Macs, users that do not have a Secure Token cannot be Volume Owners, which means they will not be able to approve system updates (among other things).
>
> **macOS 11 Big Sur AND NEWER FIRST SECURE TOKEN NOTES:**<br/>
> On macOS 11 Big Sur and newer, the first Secure Token is granted to the first administrator or standard user when their password is set, regardless of their UID.<br/>
> This essentially means the first Secure Token is granted right when the first user is created.<br/>
> This is different from previous versions of macOS which would grant the first Secure Token upon first login or authentication.<br/>
> Since this behavior is more aggressive than previous first Secure Token behavior, a new way has been added to selectively prevent a user from being granted the first Secure Token.<br/>
> This is done by adding a special tag to the AuthenticationAuthority attribute in the user record before the users password has been set.<br/>
> While `mkuser` includes this option and takes care of the necessary timing, it's worth noting that when creating users with `sysadminctl -addUser` it's actually impossible to prevent a Secure Token in this way since the password is always set during that user creation process, even if it's just a blank/empty password.<br/>
> When users are created with this tag in their AuthenticationAuthority, the first user that does not have this special tag will get the first Secure Token when their password is set (basically, upon creation).<br/>
> In general, you will want to make sure the the first user being granted a Secure Token is also an administrator so that they are allowed to do all possible operations on macOS (especially on T2 and Apple Silicon Macs).
>
> **macOS 10.15 Catalina FIRST SECURE TOKEN NOTES:**<br/>
> On macOS 10.15 Catalina, the first Secure Token is granted to the first administrator (not standard user) to login or authenticate, regardless of their UID.<br/>
> Even though `mkuser` will always verify the password (using native `OpenDirectory` methods) during the user creation process (which is an authentication that could trigger granting the first Secure Token), this authentication happens before the user is added to the "admin" group (if they are configured to be an administrator).<br/>
> This means that users will never be an administrator during this authentication within the `mkuser` process and therefore will not be granted the first Secure Token at that moment.<br/>
> The first Secure Token will then be granted by macOS to the first administrator to login or authenticate after `mkuser` has finished.<br/>
> This is the same first Secure Token behavior that can be expected from any other user creation method that I'm aware of.<br/>
> If for some reason you want to immediately grant an administrator created by `mkuser` the first Secure Token, you can manually run `dscl . -authonly` after `mkuser` has finished.
>
> **macOS 10.14 Mojave AND macOS 10.13 High Sierra FIRST SECURE TOKEN NOTES:**<br/>
> The following information only applies to macOS on an APFS volume (and not HFS+) as Secure Tokens are exclusively an APFS feature.<br/>
> The Secure Token behavior is slightly different on macOS 10.14 Mojave and macOS 10.13 High Sierra than it is on new versions of macOS.<br/>
> Also, `mkuser`'s process has an effect on the default macOS behavior of granting the first Secure Token.<br/>
> Basically, the first Secure Token is granted to the first administrator or standard user to login or authenticate which has a UID of 500 or greater if and only if they are the only user with a UID of 500 or greater.<br/>
> This means that if multiple users with UIDs of 500 or greater were to be created before any of them logged in or authenticated, no first Secure Token would be granted automatically by macOS (which is not a great situation to get into by accident).<br/>
> But, `mkuser` simplifies this complexity since the password will always be verified during the user creation process (using native `OpenDirectory` methods), which means the users first authentication actually happens during the `mkuser` user creation process.<br/>
> Therefore, when using `mkuser`, the first Secure Token will always be granted to the first user created with a UID of 500 or greater when their password is verified during the `mkuser` process.<br/>
> If you do not want the first user you are creating with `mkuser` to be granted the first Secure Token, such as for a management account, simply set their UID below 500 and macOS will not grant them the first Secure Token when their password is verified by `mkuser`.<br/>
> Then, the first user created by `mkuser` with a UID of 500 or greater or the first user created by going through first boot Setup Assistant will get the first Secure Token as intended.<br/>
> You can also simply adjust the order of users created to be sure the user with a UID of 500 or greater that you want to be granted the first Secure Token is created first.<br/>
> In general, you will want to make sure the first user being granted a Secure Token is also an administrator so that they are allowed to do all possible operations on macOS, such as grant other users a Secure Token.
>
> **ALL VERSIONS OF macOS SECURE TOKEN NOTES:**<br/>
> Once the first Secure Token has been granted, any subsequent users created by `mkuser` or by going through first boot Setup Assistant will not automatically be granted a Secure Token by macOS since the first Secure Token has already been granted.<br/>
> If you're using `mkuser` to create users before going through Setup Assistant, and you want the user created by first boot Setup Assistant to be granted the first Secure Token, be sure to take the necessary steps for each version of macOS (as outline above) to ensure any users created by `mkuser` are not granted the first Secure Token.<br/>
> Once the first Secure Token has been granted by macOS, you must use `sysadminctl -secureTokenOn` to grant other users a Secure Token and authenticate the command with an existing Secure Token administrator either interactively or by passing their credentials with the `-adminUser` and `-adminPassword` options.<br/>
> Or, `mkuser` can securely take care of this for you when creating new users if you pass an existing Secure Token admins credentials using the `--secure-token-admin-account-name` option along with one of the three different Secure Token admin password options below.<br/>
> See the *SECURE TOKEN ADMIN 1022 BYTE PASSWORD LENGTH LIMIT NOTES* in the help information for the `--secure-token-admin-password` option below and the *PASSWORDS IN PACKAGE NOTES* in help information for the `--password` option above for more information about how passwords are handled securely by `mkuser`, all of which also apply to Secure Token admin passwords.<br/>
> Users created in the "Users & Groups" pane of the "System Preferences" will only get a Secure Token when the pane has been unlocked by an existing Secure Token administrator.<br/>
> Similarly, users created using `sysadminctl -addUser` will only get a Secure Token when the command is authenticated with an existing Secure Token administrator (the same way as when using the `sysadminctl -secureTokenOn` option).<br/>
> The only exception to this subsequent Secure Token behavior is when utilizing MDM with a Bootstrap Token.

<br/>

#### `--secure-token-admin-account-name, --st-admin-name, --st-admin-user, --st-name` < *string* >

> Specify an existing Secure Token administrator account name (not full name) along with their password (using one of the three different options below) to be used to grant the new user a Secure Token.<br/>
> This option is ignored on HFS+ volumes since Secure Tokens are APFS-only.

<br/>

#### `--secure-token-admin-password, --st-admin-pass, --st-pass` < *string* >

> The password will be validated to be correct for the specified `--secure-token-admin-account-name`.<br/>
> The password must be 1022 bytes or less (see notes below for more info).<br/>
> If omitted, blank/empty password will be specified.<br/>
> This option is ignored on HFS+ volumes since Secure Tokens are APFS-only.
>
> See *PASSWORDS IN PACKAGE NOTES* in help information for the `--password` option above for more information about how the Secure Token admin password is securely obfuscated within a package.
>
> **SECURE TOKEN ADMIN 1022 BYTE PASSWORD LENGTH LIMIT NOTES:**<br/>
> To grant the new user a Secure Token, the user and existing Secure Token admin passwords must be passed to `sysadminctl -secureTokenOn`.<br/>
> To do this in the most secure way possible (so that they are never visible in the process list), the passwords are NOT passed directly as arguments but are instead passed via "stdin" using the command line prompt options.<br/>
> But, this technique fails with Secure Token admin passwords over 1022 bytes.<br/>
> For a bit more technical information about this limitation from my testing, search for *1022 bytes* within the source of this script.<br/>
> The length of the new user password is not an issue for this command since it is limited to a maximum of 511 bytes as described in the *511 BYTE PASSWORD LENGTH LIMIT NOTES* in help information for the `--password` option above.<br/>
> Since `mkuser` strives to handle passwords in the most secure ways possible, the password length of Secure Token admin is limited to 1022 bytes so that the password can be passed to `sysadminctl -secureTokenOn` in a secure way that never makes it visible in the process list.<br/>
> If your existing Secure Token admin has a longer password for any reason, you can use it to manually grant a Secure Token after creating a non-Secure Token account with `mkuser` by insecurely passing the password directly to `sysadminctl -secureTokenOn` as an argument since longer passwords are properly accepted when passed that way.

<br/>

#### `--fd-secure-token-admin-password, --fd-st-admin-pass, --fd-st-pass` < *file descriptor path* (via process substitution) >

> The file descriptor path must be specified via process substitution.<br/>
> The process substitution command must `echo` the Secure Token admin password.<br/>
> If you haven't used process substitution before, it looks like this: `mkuser [OPTIONS] --fd-secure-token-admin-password <(echo '<PASS>') [OPTIONS]`<br/>
> Passing the password via process substitution instead of directly with the `--secure-token-admin-password` option hides the password from the process list and does not create any temporary file containing the password.<br/>
> Since `echo` is a builtin in `bash` and `zsh` and not an external binary command, the `echo` command containing the password as an argument is also never visible in the process list.<br/>
> The help information for the `--secure-token-admin-password` option above also applies to Secure Token admin passwords passed via process substitution.<br/>
> This option is ignored on HFS+ volumes since Secure Tokens are APFS-only.

<br/>

#### `--fd3-secure-token-admin-password, --fd3-st-admin-pass, --fd3-st-pass` < *no parameter* (fd3) >

> **THIS OPTION IS DEPRECATED AND WILL BE REMOVED IN A FUTURE VERSION!**<br/>
> THE MORE SECURE `--fd-secure-token-admin-password` SHOULD BE USED INSTEAD.<br/>
> *THIS IS BECAUSE USING A HERE-STRING MOMENTARILY CREATES A TEMPORARY FILE WHICH CONTAINS THE SPECIFIED PASSWORD WHILE PROCESS SUBSTITUTION DOES NOT.*
>
> Include this option with no parameter to pass the Secure Token admin password via file descriptor 3 (fd3), using an "fd3" here-string (`3<<<`).<br/>
> If you haven't used "fd3" here-strings before, it looks like this: `mkuser [OPTIONS] --fd3-secure-token-admin-password [OPTIONS] 3<<< '<PASS>'`<br/>
> Passing the password via "fd3" instead of directly with the `--secure-token-admin-password` option hides the password from the process list, BUT CREATES A TEMPORARY FILE CONTAINING THE PASSWORD.<br/>
> The help information for the `--secure-token-admin-password` option above also applies to Secure Token admin passwords passed via "fd3".<br/>
> This option is ignored on HFS+ volumes since Secure Tokens are APFS-only.

<br/>

#### `--secure-token-admin-password-prompt, --st-admin-pass-prompt, --st-pass-prompt` < *no parameter* >

> Include this option with no parameter to be prompted for the Secure Token admin password on the command line before creating the user or package.<br/>
> This option allows you to specify a Secure Token admin password without it being saved in your command line history as well as hides the password from the process list.<br/>
> The help information for the `--secure-token-admin-password` option above also applies to Secure Token admin passwords entered via command line prompt.<br/>
> This option is ignored on HFS+ volumes since Secure Tokens are APFS-only.<br/>
> **NOTICE:** This option cannot be used when `--stdin-password` is specified since accepting "stdin" disrupts the ability to use other command line inputs.

<br/>

## 🚪 LOGIN OPTIONS

#### `--automatic-login, --auto-login, -A` < *no parameter* >

> Include this option with no parameter to set automatic login for the user.<br/>
> Enabling automatic login stores the users password in the filesystem in an obfuscated but insecure way.<br/>
> If automatic login is already setup for another user, it'll be overwritten.<br/>
> If FileVault is enabled, automatic login is not possible or allowed and this option will be ignored (and a warning will be displayed).

<br/>

#### `--prevent-login, --no-login, --nl` < *no parameter* >

> Include this option with no parameter to prevent this user from logging in.<br/>
> This option is equivalent to setting the login shell to "/usr/bin/false" which can also be done directly with `--login-shell /usr/bin/false`.<br/>
> This is here as a separate option for convenience and information.<br/>
> When the login shell is set to "/usr/bin/false", the user is will not show in the "Users & Groups" pane of the "System Preferences" and will also not show up in the non-FileVault login window list of users.
>
> If FileVault is enabled and one of these users has a password and is granted a Secure Token, they WILL show in the FileVault login window and can decrypt the volume, but then the non-FileVault login will be hit to fully login to macOS with another user account.<br/>
> Unlike hidden users, these user CANNOT be logged into using text input fields in the non-FileVault login window.
>
> Even if one of these users has a password set, they CANNOT authenticate "Terminal" commands like `su`, or `login`.<br/>
> They also CANNOT authenticate graphical prompts, such as unlocking "System Preferences" panes if they are in an administrator.<br/>
> But, if these users are an admin, they CAN run AppleScript `do shell script` commands `with administrator privileges`.

<br/>

#### `--skip-setup-assistant, --skip-setup, -S` < *firstBootOnly* || *firstLoginOnly* || *both* (or *no parameter*) >

> Include this option with either no parameter or specify "*both*" to skip both the first boot and first login Setup Assistant screens.
>
> Specify "*firstBootOnly*" to skip only the first boot Setup Assistant screens.<br/>
> This affects all users and will only have an effect if the first boot Setup Assistant has not already run.
>
> Specify "*firstLoginOnly*" to skip only the users first login Setup Assistant screens.<br/>
> This affects only this user and will also skip any and all future user Setup Assistant screens that may appear when and if macOS is updated.
>
> Any other parameters are invalid and will cause the user to not be created.

<br/>

## 📦 PACKAGING OPTIONS

#### `--package-path, --pkg-path, --package, --pkg` < *folder path* || *pkg file path* || *no parameter* (working directory) >

> Save distribution package to create a user with the other specified options.<br/>
> This will not create a user immediately on the current system, but will save a distribution package file that can be used on another system.<br/>
> The distribution package (product archive) created will be suitable for use with `startosinstall --installpackage` or `installer -pkg` or "Installer" app, and is also "no payload" which only runs scripts and leaves no receipt.<br/>
> If no path is specified, the current working directory will be used along with the default filename: *\<PKG ID\>-\<PKG VERSION\>.pkg*<br/>
> If a folder path is specified, the default filename will be used within the specified folder.<br/>
> If a full file path ending in ".pkg" is specified, that whole path and filename will be used.<br/>
> For any of these path options, if the exact filename already exists in the specified folder, it will be OVERWRITTEN by a newly created package.

<br/>

#### `--package-identifier, --pkg-identifier, --package-id, --pkg-id` < *string* >

> Specify the bundle identifier string to use for the package (only valid when using the `--package` option).<br/>
> Must be 248 characters/bytes or less and start with a letter or number and can only contain alphanumeric, hyphen/minus (-), underscore (_), or dot (.) characters.<br/>
> If the package identifier is over 248 characters, the installation would fail to extract the package scripts since they are extracted into a folder named with the package identifier and appended with a period plus 6 random characters which would make that folder name over the macOS 255 byte max.<br/>
> If omitted, the default identifier will be used: *mkuser.pkg.\<ACCOUNT NAME\>*

<br/>

#### `--package-version, --pkg-version, --pkg-v` < *version string* >

> Specify the version string to use for the package (only valid when using the `--package` option).<br/>
> Must start with a number or letter and can only contain alphanumeric, hyphen/minus (-), or dot (.) characters.<br/>
> If omitted, the current date will be used in the format: *YYYY.M.D*

<br/>

#### `--package-signing-identity, --package-sign, --pkg-sign` < *string* >

> Specify the installer package signing identity string to use for the package (only valid when using the `--package` option).<br/>
> The string must be for an existing installer package signing identity in the Keychain, and in the proper format: *Developer ID Installer: Name (Team ID)*<br/>
> If omitted, the package will not be signed.

<br/>

## ⚙️ MKUSER OPTIONS

#### `--do-not-confirm, --no-confirm, --force, -F` < *no parameter* >

> By default, `mkuser` prompts for confirmation on the command line before creating a user on the current system.<br/>
> Include this option with no parameter to NOT prompt for confirmation.<br/>
> This option is ignored when outputting a user creation package (with the `--package` option) since no user will be created on the current system.<br/>
> **NOTICE:** Specifying `--suppress-status-messages` OR `--stdin-password` also ENABLES `--do-not-confirm`.

<br/>

#### `--suppress-status-messages, --quiet, -q` < *no parameter* >

> Include this option with no parameter to not output any status messages that would be sent to "stdout".<br/>
> Any errors and warning that are sent to "stderr" will still be outputted.<br/>
> **NOTICE:** Specifying `--suppress-status-messages` also ENABLES `--do-not-confirm`.

<br/>

#### `--check-only, --dry-run, --check, -c` < *no parameter* >

> Include this option with no parameter to check if the other specified options are valid and output the settings a user would be created with.<br/>
> This option is ignored when outputting a user creation package (with the `--package` option) since checking against the current system isn't useful when installing packages on other systems.

<br/>

#### `--version, -v` < *online* (or *o*) || *no parameter* >

> Include this option with no parameter to display the `mkuser` version, and also check for updates when connected to the internet and display the newest version if an update is available.
>
> Specify "*online*" (or "*o*") to also open the `mkuser` Releases page on GitHub in the default web browser to be able to quickly and easily view the latest release notes as well as download the latest version.
>
> This option overrides all other options (including `--help`).

<br/>

#### `--help, -h` < *brief* (or *b*) || *online* (or *o*) || *no parameter* >

> Include this option with no parameter to display this help information in Terminal.
>
> Specify "*brief*" (or "*b*") to only show options without their descriptions.
> This can be helpful for quick reference to check option or parameter names.
>
> Specify "*online*" (or "*o*") to instead open this README section of the `mkuser` GitHub page in the default web browser to be able quickly and easily view this help information from here.
>
> This option overrides all other options (except `--version`).
