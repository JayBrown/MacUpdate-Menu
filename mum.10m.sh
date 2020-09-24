#!/bin/zsh
# shellcheck shell=bash
# shellcheck disable=SC2162
# shellcheck disable=SC2009
# shellcheck disable=SC2012
# shellcheck disable=SC2001

# <bitbar.title>MacUpdate Menu</bitbar.title>
# <bitbar.version>v3.0.0-beta10-b8</bitbar.version>
# <bitbar.author>Joss Brown</bitbar.author>
# <bitbar.author.github>JayBrown</bitbar.author.github>
# <bitbar.desc>Regularly check MacUpdate for software updates</bitbar.desc>
# <bitbar.image>https://raw.githubusercontent.com/JayBrown/MacUpdate-Menu/master/img/MUM_screengrab.png</bitbar.image>
# <bitbar.abouturl>https://github.com/JayBrown/MacUpdate-Menu</bitbar.abouturl>

# MacUpdate Menu (MUM)
# BitBar plugin
# Version: 3.0.0 beta 10 build 8
# Note: beta number conforms to BitBar's beta number
# Category: System
#
# BitBar: https://github.com/matryer/bitbar & https://github.com/matryer/bitbar-plugins
# BitBar v2.0.0 beta10 (requisite): https://github.com/matryer/bitbar/releases/tag/v2.0.0-beta10
#
# Based the original MUMenu menu bar application by Clario Tech Ltd.
# Abandonware (not compatible with modern macOS versions)
# MUMenu: https://www.macupdate.com/app/mac/8277/mumenu

export LANG=en_US.UTF-8
export SYSTEM_VERSION_COMPAT=0
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin:/opt/local/bin:/opt/sw/bin:/sw/bin

# download test
teststring="No matter where you go, there you are."
if [[ $1 == "-t" ]] ; then
	echo -n "$teststring" 2>/dev/null
	exit
fi

if [[ $1 == "license" ]] ; then
	osascript 2>/dev/null << EOL
tell application "System Events"
	activate
	set theUserChoice to button returned of (display alert "Limited Liability, Copyright & License" message "By using MacUpdate Menu, and in accordance with the MIT license that governs it (see below), and to the fullest extent permissible under German law, you hereby agree and acknowledge that we, Joss Brown (pseud.), their affiliates, successors, assignees, and associated persons of any and all kinds, are in no event responsible or liable for any harm or issues, technical or otherwise, that you might sustain or encounter through the use of MacUpdate Menu, that you might sustain or encounter on the web pages or sites linked therein, or that you might sustain or encounter with files you download or install from or via these web pages or sites. You hereby agree to hold us harmless from and against any and all resulting losses, damages, costs, and expenses (including reasonable attorney fees)." & return & return & "Copyright © 2020 Joss Brown (pseud.)" & return & "All rights reserved" & return & "German laws apply" & return & "Place of jurisdiction: Berlin, Germany" & return & return & "Some icons included under § 57 UrhG exceptions ('Unwesentliches Beiwerk')" & return & "Other icons created in temporary cache only." & return & return & "MIT LICENSE" & return & return & "Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:" & return & return & "The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software." & return & return & "THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE." ¬
		as critical ¬
		buttons {"OK"} ¬
		default button 1 ¬
		giving up after 300)
end tell
EOL
	exit
fi

# user stuff
account=$(id -u)
accountname=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')
! [[ $accountname ]] && accountname="$USER"
HOMEDIR=$(dscl . read /Users/"$accountname" NFSHomeDirectory | awk -F": " '{print $2}')
if ! [[ $HOMEDIR ]] ; then
	if [[ -d "/Users/$accountname" ]] ; then
		HOMEDIR="/Users/$accountname"
	else
		HOMEDIR=$(eval echo "~$accountname")
	fi
fi

# prefs (initial)
procid="local.lcars.MacUpdateMenu"
prefsloc="$HOMEDIR/Library/Preferences/$procid.plist"

# slow wake
if [[ $(/usr/libexec/PlistBuddy -c "Print:slowWake" "$prefsloc" 2>/dev/null) == "true" ]] ; then
	slowwake=true
	lastwake=$(pmset -g log 2>/dev/null | grep "Wake from Standby" | sed '$!d' | awk '{print $1" "$2" "$3}')
	if [[ $lastwake ]] ; then
		lastwakeposix=$(date -j -f '%Y-%m-%d %H:%M:%S %z' "$lastwake" +%s)
		executeposix=$(date +%s)
		if [[ $(echo "$executeposix - $lastwakeposix" | bc 2>/dev/null) -lt 10 ]] ; then
			sleep 10
		fi
	fi
else
	slowwake=false
fi

# system beep
_sysbeep () {
	osascript -e "beep" &>/dev/null
}

# open developer page
if [[ $1 == "opendev" ]] ; then
	if ! [[ $2 ]] ; then
		_sysbeep
		exit
	fi
	infourl="$2"
	urldump=$(curl -k -L -s --connect-timeout 30 --max-time 60 "$infourl" 2>/dev/null)
	if ! [[ $urldump ]] ; then
		_sysbeep
		exit
	fi
	devurl=$(echo "$urldump" | awk -F"developer-website_btn\" href=\"" '{print $2}' | awk -F\" '{print $1}' | xargs)
	if [[ $devurl ]] && [[ $devurl == "http"* ]] ; then
		open "$devurl" 2>/dev/null
	else
		_sysbeep
	fi
	exit
fi

# launch or open MacUpdater
if [[ $1 == "openmur" ]] ; then
	if [[ $2 == "launch" ]] ; then
		open -a MacUpdater &>/dev/null
		while true
		do
			sleep 1
			pgrep MacUpdater &>/dev/null && { sleep .5 ; break ; }
		done
	fi
	osascript -e 'tell application "MacUpdaterLaunchHelper" to activate' &>/dev/null
	exit
fi

# reveal apps in Finder
if [[ $1 == "reveal" ]] ; then
	osascript -e "tell application \"Finder\"" -e "activate" -e "reveal POSIX file \"$2\"" -e "end tell" &>/dev/null
	exit
fi

# check macOS version
prodv=$(sw_vers -productVersion)
prodv_major=$(echo "$prodv" | awk -F"." '{print $1}')
prodv_minor=$(echo "$prodv" | awk -F"." '{print $2}')
prodv_fix=$(echo "$prodv" | awk -F"." '{print $3}')
if [[ $prodv_major == 10 ]] && [[ $prodv_minor -ge 16 ]] ; then
	prodv_major=11
	prodv_minor=$(echo "$prodv_minor - 16" | bc 2>/dev/null)
fi
incompat=false
skipmur=false
if [[ $prodv_major -lt 10 ]] ; then
	incompat=true
	skipmur=true
elif [[ $prodv_major -eq 10 ]] ; then
	if [[ $prodv_minor -lt 9 ]] ; then
		incompat=true
		skipmur=true
	elif [[ $prodv_minor -eq 9 ]] ; then
		if [[ $prodv_fix -lt 5 ]] ; then
			incompat=true
		fi
		skipmur=true
	else
		if [[ $prodv_minor -lt 13 ]] ; then
			skipmur=true
		fi
	fi
fi

# BitBar stuff
bbminv="2.0.0-beta10"
bbdlurl="https://github.com/matryer/bitbar/releases/tag/v2.0.0-beta10"
bbloc=$(ps aux | grep "BitBar.app" | grep -v "grep" | awk '{print substr($0, index($0,$11))}' | awk -F"/Contents/" '{print $1}')
if [[ $bbloc ]] ; then
	bbprefs="$bbloc/Contents/Info.plist"
	bbversion=$(/usr/libexec/PlistBuddy -c "Print:CFBundleVersion" "$bbprefs" 2>/dev/null)
	[[ $bbversion != "$bbminv" ]] && correctbb=false || correctbb=true
else
	correctbb=true
fi

# mucom stuff
version="3.0.0" # only for display
cversion="3.00" # for version comparisons
betaversion="10" # matches BitBar beta version
build="8" # build number (this script)
defaultv="1" # version number for the default CLI favorites (also change in $defaultclis heredoc)
if [[ $betaversion != "-" ]] ; then
	vmisc=" beta $betaversion"
else
	vmisc=""
fi
process="MUM"
uiprocess="MacUpdate Menu"
mucomurl="https://github.com/JayBrown/MacUpdate-Menu"
mucomrelurl="https://github.com/JayBrown/MacUpdate-Menu/releases"
mucomvurl="https://raw.githubusercontent.com/JayBrown/MacUpdate-Menu/master/VERSIONS"
mucomcliurl="https://raw.githubusercontent.com/JayBrown/MacUpdate-Menu/master/command-line-user-favorites.txt"
mucomdlurl="https://raw.githubusercontent.com/JayBrown/MacUpdate-Menu/master/mum.10m.sh"
mucomdlmurl="https://github.com/JayBrown/MacUpdate-Menu/releases/latest"
mucomissues="https://github.com/JayBrown/MacUpdate-Menu/issues"
mucomhelpurl="https://raw.githubusercontent.com/JayBrown/MacUpdate-Menu/master/payload/MacUpdateMenu.help.tar"
mypath="$0"
bbdir=$(dirname "$mypath")
symlink=false
linkfound=false
github=false
if [[ -L "$mypath" ]] ; then
	symlink=true
	oloc=$(ls -dl "$mypath" | awk -F" -> " '{print substr($0, index($0,$2))}') 
	if [[ -f "$oloc" ]] ; then
		linkfound=true
		olocparent=$(dirname "$oloc")
		if [[ -f "$olocparent/test.sh" ]] ; then
			chmod +x "$olocparent/test.sh" 2>/dev/null
			if [[ $("$olocparent/test.sh") == "$teststring" ]] ; then
				github=true
			fi
		fi
	fi
fi
myname=$(basename "$mypath")
cachedir="$HOMEDIR/Library/Caches/$procid"
if ! [[ -d "$cachedir" ]] ; then
	mkdir -p "$cachedir" 2>/dev/null
fi
supportdir="$HOMEDIR/Library/Application Support/$procid"
if ! [[ -d "$supportdir" ]] ; then
	mkdir -p "$supportdir" 2>/dev/null
fi
userloc="$supportdir/command-line-user-favorites.txt"
if ! [[ -f "$userloc" ]] ; then
	touch "$userloc" 2>/dev/null
fi
allfontfamilies=$(osascript 2>/dev/null << EOF
use framework "AppKit"
set fontFamilyNames to (current application's NSFontManager's sharedFontManager's availableFontFamilies) as list
return fontFamilyNames
EOF
)
if echo "$allfontfamilies" | grep -q "SF Mono" &>/dev/null ; then
	monofont="font=SFMono-Regular size=11"
else
	monofont="font=Menlo-Regular size=11"
fi
read -d '' defaultclis <<"EOP"
# 1
Fink
Homebrew
MacPorts
EOP
defaultsloc="$supportdir/.mum_defaults"
if ! [[ -f "$defaultsloc" ]] ; then
	echo "$defaultclis" > "$defaultsloc" 2>/dev/null
	currentdefaults_raw="$defaultclis"
	chflags uchg "$defaultsloc" 2>/dev/null
else
	currentdefaults_raw=$(cat "$defaultsloc" 2>/dev/null)
	currentdefaultsv=$(echo "$currentdefaults_raw" | grep "^\# " | head -1 | awk '{print $2}')
	if [[ $currentdefaultsv -ne "$defaultv" ]] ; then
		chflags nouchg "$defaultsloc" 2>/dev/null
		rm -f "$defaultsloc" 2>/dev/null
		echo "$defaultclis" > "$defaultsloc" 2>/dev/null
		currentdefaults_raw="$defaultclis"
		chflags uchg "$defaultsloc" 2>/dev/null
	fi
fi
currentdefaults=$(echo "$currentdefaults_raw" | grep -v -e "^\# " -e "^$")
resourcesdir="$supportdir/Resources"
helploc="$resourcesdir/MacUpdaterMenu.help"
if ! [[ -d $resourcesdir ]] ; then
	mkdir -p "$resourcesdir" 2>/dev/null
fi
helpv=$(/usr/libexec/PlistBuddy -c "Print:CFBundleShortVersionString" "$helploc/Contents/Info.plist" 2>/dev/null)
if [[ $helpv == "File Doesn't Exist"* ]] ; then
	helpv="0"
fi

# preferences etc.
prefsloc="$HOMEDIR/Library/Preferences/$procid.plist"
if ! [[ -f "$prefsloc" ]] ; then
	defaults write "$procid" allIcons -bool FALSE 2>/dev/null
	defaults write "$procid" customAppsFolder "" 2>/dev/null
	defaults write "$procid" groupLicenses -bool TRUE 2>/dev/null
	defaults write "$procid" highlightCLIs -bool TRUE 2>/dev/null
	defaults write "$procid" Icons -bool TRUE 2>/dev/null
	defaults write "$procid" ignoreHotpicks -bool FALSE 2>/dev/null
	defaults write "$procid" lastUpdates "00:01 on Thu 01 Jan 1970" 2>/dev/null
	defaults write "$procid" lastRefreshAction -int 1 2>/dev/null
	defaults write "$procid" notify -bool FALSE 2>/dev/null
	defaults write "$procid" notifyApps -bool FALSE 2>/dev/null
	defaults write "$procid" playSound -bool FALSE 2>/dev/null
	defaults write "$procid" playSoundApps -bool FALSE 2>/dev/null
	defaults write "$procid" Promo -bool TRUE 2>/dev/null
	defaults write "$procid" RefreshRate -int 1800 2>/dev/null
	defaults write "$procid" slowWake -bool FALSE 2>/dev/null
	defaults write "$procid" sortByName -bool FALSE 2>/dev/null
fi
newlsplist="$HOMEDIR/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
oldlsplist="$HOMEDIR/Library/Preferences/com.apple.LaunchServices.plist"

# manual refresh
if [[ $1 == "manualrefresh" ]] ; then
	defaults write "$procid" lastRefreshAction -int 1 2>/dev/null
	exit
fi

# agree to license
agreed=false
if [[ $(/usr/libexec/PlistBuddy -c "Print:hasAgreed" "$prefsloc" 2>/dev/null) != "true" ]] ; then
	licchoice=$(osascript 2>/dev/null <<EOL
beep
tell application "System Events"
	activate
	set theUserChoice to button returned of (display alert "Limited Liability, Copyright & License" message "By using MacUpdate Menu, and in accordance with the MIT license that governs it (see below), and to the fullest extent permissible under German law, you hereby agree and acknowledge that we, Joss Brown (pseud.), their affiliates, successors, assignees, and associated persons of any and all kinds, are in no event responsible or liable for any harm or issues, technical or otherwise, that you might sustain or encounter through the use of MacUpdate Menu, that you might sustain or encounter on the web pages or sites linked therein, or that you might sustain or encounter with files you download or install from or via these web pages or sites. You hereby agree to hold us harmless from and against any and all resulting losses, damages, costs, and expenses (including reasonable attorney fees)." & return & return & "Copyright © 2020 Joss Brown (pseud.)" & return & "All rights reserved" & return & "German laws apply" & return & "Place of jurisdiction: Berlin, Germany" & return & return & "Some icons included under § 57 UrhG exceptions ('Unwesentliches Beiwerk')" & return & "Other icons created in temporary cache only." & return & return & "MIT LICENSE" & return & return & "Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:" & return & return & "The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software." & return & return & "THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE." as critical buttons {"Disagree", "Agree"} default button 2 cancel button "Disagree" giving up after 300)
end tell
EOL
	)
	if [[ $licchoice ]] ; then
		defaults write "$procid" hasAgreed -bool TRUE 2>/dev/null
		agreed=true
	fi
else
	agreed=true
fi

# choose new downloads folder
if [[ $1 == "changedownloadspath" ]] ; then
	selectfolder="$2"
	folderchoice=$(osascript 2>/dev/null <<EOD
tell application "System Events"
	activate
	set theOldDownloadsFolder to "$selectfolder" as string
	set theNewDownloadsFolder to choose folder with prompt "Please choose the new default folder for MacUpdater Menu downloads…" default location theOldDownloadsFolder
	set theNewDownloadsFolderPath to (POSIX path of theNewDownloadsFolder)
end tell
EOD
	)
	if [[ $folderchoice ]] ; then
		if [[ $folderchoice != "$selectfolder" ]] ; then
			defaults write "$procid" DownloadsFolder "$folderchoice" 2>/dev/null
		fi
	fi
	exit
fi

# choose custom Applications folder
if [[ $1 == "customapps" ]] ; then
	if [[ $2 ]] ; then
		if [[ $2 == "clear" ]] ; then
			defaults write "$procid" customAppsFolder "" 2>/dev/null
			exit
		else
			selectfolder="$2"
			sfstring="a new"
		fi
	else
		selectfolder="$HOMEDIR"
		sfstring="an additional"
	fi
	folderchoice=$(osascript 2>/dev/null <<EOA
tell application "System Events"
	activate
	set theOldCustomAppsFolder to "$selectfolder" as string
	set theNewCustomAppsFolder to choose folder with prompt "Please choose $sfstring custom Applications folder for MacUpdater Menu's software scans…" default location theOldCustomAppsFolder
	set theNewCustomAppsPath to (POSIX path of theNewCustomAppsFolder)
end tell
EOA
	)
	if [[ $folderchoice ]] ; then
		if [[ $folderchoice != "$selectfolder" ]] ; then
			defaults write "$procid" customAppsFolder "$folderchoice" 2>/dev/null
		fi
	fi
	exit
fi

# set update frequency
if [[ $1 == "refreshrate" ]] ; then
	currentfreq="$2"
	if [[ $currentfreq == "1800" ]] ; then
		freqprompt="30 minutes"
	elif [[ $currentfreq == "3600" ]] ; then
		freqprompt="hour"
	elif [[ $currentfreq == "7200" ]] ; then
		freqprompt="2 hours"
	elif [[ $currentfreq == "10800" ]] ; then
		freqprompt="3 hours"
	elif [[ $currentfreq == "14400" ]] ; then
		freqprompt="4 hours"
	else
		freqprompt="30 minutes"
	fi
	freqchoice=$(osascript 2>/dev/null <<EOR
tell application "System Events"
	activate
	set theFrequencyList to {"Every 30 Minutes (Default)", "Every Hour", "Every 2 Hours", "Every 3 Hours", "Every 4 Hours"}
	set theUserChoice to choose from list theFrequencyList with title "MacUpdate Menu Preferences" with prompt "You are currently updating every " & "$freqprompt" &". Please select the new update frequency:" default items "Every 30 Minutes (Default)"
end tell
EOR
	)
	if [[ $freqchoice ]] ; then
		if [[ $freqchoice == "Every 30 Minutes (Default)" ]] ; then
			newfreq="1800"
		elif [[ $freqchoice == "Every Hour" ]] ; then
			newfreq="3600"
		elif [[ $freqchoice == "Every 2 Hours" ]] ; then
			newfreq="7200"
		elif [[ $freqchoice == "Every 3 Hours" ]] ; then
			newfreq="10800"
		elif [[ $freqchoice == "Every 4 Hours" ]] ; then
			newfreq="14400"
		fi
		if [[ $newfreq != "$currentfreq" ]] ; then
			defaults write "$procid" RefreshRate -int "$newfreq" 2>/dev/null
		fi
	fi
	exit
fi

newsafariloc="$HOMEDIR/Library/Containers/com.apple.Safari/Data/Library/Preferences/com.apple.Safari.plist"
oldsafariloc="$HOMEDIR/Library/Preferences/com.apple.Safari.plist"
_safaridir () {
	if [[ -f "$newsafariloc" ]] ; then
		defaultdldir=$(/usr/libexec/PlistBuddy -c "Print :DownloadsPath" "$newsafariloc" 2>/dev/null | sed 's-/$--')
		if ! [[ -d "$defaultdldir" ]] ; then
			if [[ -f "$oldsafariloc" ]] ; then
				defaultdldir=$(/usr/libexec/PlistBuddy -c "Print :DownloadsPath" "$oldsafariloc" 2>/dev/null | sed 's-/$--')
			fi
		fi
	else
		defaultdldir=$(/usr/libexec/PlistBuddy -c "Print :DownloadsPath" "$oldsafariloc" 2>/dev/null | sed 's-/$--')
	fi
	if ! [[ -d "$defaultdldir" ]] ; then
		defaultdldir=""
	fi
	if ! [[ $defaultdldir ]] ; then
		defaultdldir=$(defaults read com.apple.Safari DownloadsPath 2>/dev/null | sed 's-/$--')
	fi
}

# default downloads folder
defaultdldir=$(/usr/libexec/PlistBuddy -c "Print:DownloadsFolder" "$prefsloc" 2>/dev/null)
if ! [[ $defaultdldir ]] ; then
	localdldir="$HOMEDIR/Downloads"
	defaultbrowserid=""
	if [[ -f "$newlsplist" ]] ; then
		defaultbrowserid=$(/usr/libexec/PlistBuddy -c "Print" "$newlsplist" 2>/dev/null | grep -i -A1 "public\.html" | grep "LSHandlerRoleAll = " | grep -v "\"-\";" | awk -F" = " '{print $2}')
	else
		if [[ -f "$oldlsplist" ]] ; then
			defaultbrowserid=$(/usr/libexec/PlistBuddy -c "Print" "$oldlsplist" 2>/dev/null | grep -i -A1 "public\.html" | grep "LSHandlerRoleViewer = " | grep -v "\"-\";" | awk -F" = " '{print $2}')
		fi
	fi
	
	if ! [[ $defaultbrowserid ]] ; then
		_safaridir 2>/dev/null
	else
		if [[ $defaultbrowserid == "org.mozilla.firefox" ]] ; then
			ffprefsloc=$(find "$HOMEDIR/Library/Application Support/Firefox/Profiles" -type f -name "prefs.js" | grep "\.default/prefs.js$" | head -1)
			if ! [[ $ffprefsloc ]] ; then
				_safaridir 2>/dev/null
			else
				defaultdldir=$(awk -F\" '/browser\.download\.dir\",/{print $4}' 2>/dev/null < "$ffprefsloc" | sed 's-/$--')
				if ! [[ $defaultdldir ]] ; then
					_safaridir 2>/dev/null
				fi
			fi
		elif [[ $defaultbrowserid == "com.google.chrome" ]] ; then
			gcprefsloc="$HOMEDIR/Library/Application Support/Google/Chrome/Default/Preferences"
			if ! [[ $gcprefsloc ]] ; then
				_safaridir 2>/dev/null
			else
				defaultdldir=$(tr '{' '\n{' 2>/dev/null < "$gcprefsloc" | grep "^\"default_directory" | grep -v "extensions" | awk -F\" '{print $4}' | sed 's-/$--')
			fi
		else
			defaultdldir=$(defaults read "$defaultbrowserid" DownloadsPath 2>/dev/null | sed 's-/$--')
			if ! [[ $defaultdldir ]] ; then
				_safaridir 2>/dev/null
			fi
		fi
	fi
	if ! [[ $defaultdldir ]] || ! [[ -d "$defaultdldir" ]] ; then
		defaultdldir="$localdldir"
	fi
	defaults write "$procid" DownloadsFolder "$defaultdldir" 2>/dev/null
fi
defaultdldir_short="${defaultdldir/#$HOMEDIR/~}"

# custom applications folder
customapps=false
customappdir=$(/usr/libexec/PlistBuddy -c "Print:customAppsFolder" "$prefsloc" 2>/dev/null)
if [[ $customappdir ]] ; then
	customapps=true
	customappdir_short="${customappdir/#$HOMEDIR/~}"
fi

# refresh rate
mucom_freq=$(/usr/libexec/PlistBuddy -c "Print:RefreshRate" "$prefsloc" 2>/dev/null)
if ! [[ $mucom_freq ]] ; then
	defaults write "$procid" RefreshRate -int 1800 2>/dev/null
	mucom_freq="1800"
else
	if [[ $mucom_freq -lt 1800 ]] ; then
		defaults write "$procid" RefreshRate -int 1800 2>/dev/null
		mucom_freq="1800"
	elif [[ $mucom_freq -gt 14400 ]] ; then
		defaults write "$procid" RefreshRate -int 14400 2>/dev/null
		mucom_freq="14400"
	else
		if [[ $mucom_freq != "1800" ]] && [[ $mucom_freq != "3600" ]] && [[ $mucom_freq != "7200" ]] && [[ $mucom_freq != "10800" ]] && [[ $mucom_freq != "14400" ]] ; then
			defaults write "$procid" RefreshRate -int 1800 2>/dev/null
			mucom_freq="1800"
		fi
	fi
fi
if [[ $mucom_freq == "1800" ]] ; then
	freqstring="Every 30 Minutes"
elif [[ $mucom_freq == "3600" ]] ; then
	freqstring="Every Hour"
else
	freqhours=$(echo "$mucom_freq / 3600" | bc 2>/dev/null)
	freqstring="Every $freqhours Hours"
fi
# last refresh (POSIX)
fetchedposix=$(/usr/libexec/PlistBuddy -c "Print:lastRefreshAction" "$prefsloc" 2>/dev/null)
if ! [[ $fetchedposix ]] ; then
	defaults write "$procid" lastRefreshAction -int 1 2>/dev/null
	fetchedposix="1"
fi
currentposix=$(date +%s)
posixdiff=$(echo "$currentposix - $fetchedposix" | bc 2>/dev/null)
if [[ $posixdiff -lt $mucom_freq ]] ; then
	mucheck=false
	if ! [[ -f /tmp/mucast.plist ]] ; then
		mucheck=true
	fi
else
	mucheck=true
fi

# last refresh (human-readable)
fetchdate=$(/usr/libexec/PlistBuddy -c "Print:lastUpdates" "$prefsloc" 2>/dev/null)
if ! [[ $fetchdate ]] ; then
	defaults write "$procid" lastUpdates "00:01 on Thu 01 Jan 1970" 2>/dev/null
	fetchdate="00:01 on Thu 01 Jan 1970"
else
	if ! echo "$fetchdate" | grep "^[0-9][0-9]\:[0-9][0-9]\ on\ .*" &>/dev/null ; then
		defaults write "$procid" lastUpdates "00:01 on Thu 01 Jan 1970" 2>/dev/null
		fetchdate="00:01 on Thu 01 Jan 1970"
	fi
fi
# MUR promotion
if ! $skipmur ; then
	if [[ $(/usr/libexec/PlistBuddy -c "Print:Promo" "$prefsloc" 2>/dev/null) == "false" ]] ; then
		promo=false
	else
		promo=true
	fi
else
	promo=false
fi
# MU hotpicks
if [[ $(/usr/libexec/PlistBuddy -c "Print:ignoreHotpicks" "$prefsloc" 2>/dev/null) == "false" ]] ; then
	ignorehp=false
else
	ignorehp=true
fi
# highlight command-line utilities
if [[ $(/usr/libexec/PlistBuddy -c "Print:highlightCLIs" "$prefsloc" 2>/dev/null) == "false" ]] ; then
	highlightclis=false
else
	highlightclis=true
	currentuser=$(grep -v -e "^#" -e "^$" < "$userloc" 2>/dev/null | LC_COLLATE=C sort)
fi
alldefaults=$(echo -e "$currentdefaults\n$currentuser" )
# icons
if [[ $(/usr/libexec/PlistBuddy -c "Print:Icons" "$prefsloc" 2>/dev/null) == "false" ]] ; then
	noicons=true
else
	noicons=false
fi
# all icons
if [[ $(/usr/libexec/PlistBuddy -c "Print:allIcons" "$prefsloc" 2>/dev/null) == "true" ]] ; then
	allicons=true
else
	allicons=false
fi
# group by license
if [[ $(/usr/libexec/PlistBuddy -c "Print:groupLicenses" "$prefsloc" 2>/dev/null) == "false" ]] ; then
	catsort=false
else
	catsort=true
fi
# sort by name
if [[ $(/usr/libexec/PlistBuddy -c "Print:sortByName" "$prefsloc" 2>/dev/null) == "true" ]] ; then
	namesort=true
else
	namesort=false
fi
# notifications
if [[ $(/usr/libexec/PlistBuddy -c "Print:notify" "$prefsloc" 2>/dev/null) == "true" ]] ; then
	unotify=true
else
	unotify=false
fi
# notifications only for installed apps
if [[ $(/usr/libexec/PlistBuddy -c "Print:notifyApps" "$prefsloc" 2>/dev/null) == "true" ]] ; then
	inotify=true
else
	inotify=false
fi
# audio
if [[ $(/usr/libexec/PlistBuddy -c "Print:playSound" "$prefsloc" 2>/dev/null) == "true" ]] ; then
	uaudio=true
else
	uaudio=false
fi
# notifications only for installed apps
if [[ $(/usr/libexec/PlistBuddy -c "Print:playSoundApps" "$prefsloc" 2>/dev/null) == "true" ]] ; then
	iaudio=true
else
	iaudio=false
fi

# disable or uninstall plugin
if [[ $1 == "disable" ]] ; then
	if [[ $2 == "uninstall" ]] ; then
		uninstallchoice=$(osascript 2>/dev/null <<EOR
beep
tell application "System Events"
	activate
	set theUserChoice to button returned of (display alert "Are you sure that you want to permanently remove MacUpdate Menu from BitBar?" message "This operation cannot be undone, and the files related to MacUpdate Menu will be permanently deleted or moved to the trash." as critical buttons {"Cancel", "Uninstall"} default button 1 cancel button "Cancel" giving up after 180)
end tell
EOR
		)
		if [[ $uninstallchoice ]] ; then
			chflags nouchg "$defaultsloc" 2>/dev/null
			rm -rf "$supportdir" "$cachedir" "$prefsloc" 2>/dev/null
			mv -f "$mypath" "$HOMEDIR/.Trash/$myname" 2>/dev/null
		else
			exit
		fi
	else
		if ! [[ -d "$bbdir/Disabled" ]] ; then
			mkdir "$bbdir/Disabled" 2>/dev/null
		fi
		mv -f "$mypath" "$bbdir/Disabled/$myname" 2>/dev/null
	fi
	if ! osascript -e 'tell application "BitBar" to quit' &>/dev/null ; then
		killall BitBar 2>/dev/null
	fi
	sleep 3
	open -a "BitBar"
	exit
fi

if [[ $1 == "reset" ]] ; then
	resetchoice=$(osascript 2>/dev/null <<EOR
beep
tell application "System Events"
	activate
	set theUserChoice to button returned of (display alert "Are you sure that you want reset the MacUpdate Menu preferences and favorites?" message "This operation cannot be undone." as critical buttons {"Cancel", "Reset"} default button 1 cancel button "Cancel" giving up after 180)
end tell
EOR
	)
	if [[ $resetchoice ]] ; then
		mv -f "$userloc" "$HOMEDIR/.Trash/command-line-user-favorites.txt" 2>/dev/null
		rm -f "$prefsloc" 2>/dev/null
	fi
	exit
fi

# pop sound
sound_loc="$cachedir/pop.m4a"
if ! [[ -f "$sound_loc" ]] ; then
	read -d '' popsound <<"EOP"
AAAAHGZ0eXBNNEEgAAAAAE00QSBpc29tbXA0MgAAAAhza2lwAAABCG1kYXQA0EAH
AOKZ5D26yFgraOHZBPXbyD+3/j78fHX3vzEOt11D9eBfIREEdflifIZhDCYbJ+Is
5uPGfc5IR05gfexWOd6Aurcdp6SIggurNH7O9ZyUyLLOkEniwSEv0BgqmZTKahgl
BgqR0Jaccj92xqpuZkus4w81UAN/SE6RsRj0XgEE1alWIQgkQgIQggQgg3n7S+/m
x/+WFyrlNEH+EA8lsuJjRMlx78o0aVBFV0zkTLGdyOYeMSICESi4jGMNYchaeMMA
XLOAAO4VgHB7EgQ8TLz1BcrMP7kfgccwwFkFkT7S3zI/FVX1Wfk4+Z27JDnYAw9w
ASwVg+wcATAVg+wcAAADSm1vb3YAAABsbXZoZAAAAADbinwe24p8HgAArEQAAA22
AAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAA
QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAHcdHJhawAAAFx0a2hk
AAAAAduKfB7binweAAAAAQAAAAAAAA22AAAAAAAAAAAAAAAAAQAAAAABAAAAAAAA
AAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAABeG1kaWEAAAAg
bWRoZAAAAADbinwe24p8HgAArEQAABgAVcQAAAAAADFoZGxyAAAAAAAAAABzb3Vu
AAAAAAAAAAAAAAAAQ29yZSBNZWRpYSBBdWRpbwAAAAEfbWluZgAAABBzbWhkAAAA
AAAAAAAAAAAkZGluZgAAABxkcmVmAAAAAAAAAAEAAAAMdXJsIAAAAAEAAADjc3Ri
bAAAAGdzdHNkAAAAAAAAAAEAAABXbXA0YQAAAAAAAAABAAAAAAAAAAAAAgAQAAAA
AKxEAAAAAAAzZXNkcwAAAAADgICAIgAAAASAgIAUQBQAGAAAAPoAAAD6AAWAgIAC
EggGgICAAQIAAAAYc3R0cwAAAAAAAAABAAAABgAABAAAAAAcc3RzYwAAAAAAAAAB
AAAAAQAAAAYAAAABAAAALHN0c3oAAAAAAAAAAAAAAAYAAAAEAAAAfAAAAEcAAAAt
AAAABgAAAAYAAAAUc3RjbwAAAAAAAAABAAAALAAAAPp1ZHRhAAAA8m1ldGEAAAAA
AAAAImhkbHIAAAAAAAAAAG1kaXIAAAAAAAAAAAAAAAAAAAAAAMRpbHN0AAAAvC0t
LS0AAAAcbWVhbgAAAABjb20uYXBwbGUuaVR1bmVzAAAAFG5hbWUAAAAAaVR1blNN
UEIAAACEZGF0YQAAAAEAAAAAIDAwMDAwMDAwIDAwMDAwODQwIDAwMDAwMjBBIDAw
MDAwMDAwMDAwMDBEQjYgMDAwMDAwMDAgMDAwMDAwMDAgMDAwMDAwMDAgMDAwMDAw
MDAgMDAwMDAwMDAgMDAwMDAwMDAgMDAwMDAwMDAgMDAwMDAwMDA=
EOP
	echo "$popsound" | base64 -d -o "$sound_loc" 2>/dev/null
fi

_appbeep () {
	afplay "$sound_loc" &>/dev/null
}

# main icons
icon_loc="$cachedir/mucom512.png"
icon_loc2="$cachedir/munet512.png"
if ! [[ -f "$icon_loc2" ]] ; then
	read -d '' muneticon <<"EOI"
aWNucwADD89UT0MgAAAAEGljMTQAAw+3aWMxNAADD7eJUE5HDQoaCgAAAA1JSERS
AAACAAAAAgAIBgAAAPR41PoAAAAEZ0FNQQAAsY8L/GEFAAAAIGNIUk0AAHomAACA
hAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAACkZVhJZk1NACoAAAAIAAUB
GgAFAAAAAQAAAEoBGwAFAAAAAQAAAFIBKAADAAAAAQACAAABMQACAAAAHwAAAFqH
aQAEAAAAAQAAAHoAAAAAAAAAkAAAAAEAAACQAAAAAUFkb2JlIFBob3Rvc2hvcCBD
QyAoTWFjaW50b3NoKQAAAAOgAQADAAAAAQABAACgAgAEAAAAAQAAAgCgAwAEAAAA
AQAAAgAAAAAAZ3+31QAAAAlwSFlzAAAWJQAAFiUBSVIk8AAAAxxpVFh0WE1MOmNv
bS5hZG9iZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0
YS8iIHg6eG1wdGs9IlhNUCBDb3JlIDUuNC4wIj4KICAgPHJkZjpSREYgeG1sbnM6
cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMj
Ij4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAg
ICAgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iCiAg
ICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8x
LjAvIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20v
eGFwLzEuMC8iPgogICAgICAgICA8ZXhpZjpQaXhlbFlEaW1lbnNpb24+MjU2PC9l
eGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6Q29sb3JTcGFjZT4x
PC9leGlmOkNvbG9yU3BhY2U+CiAgICAgICAgIDxleGlmOlBpeGVsWERpbWVuc2lv
bj4yNTY8L2V4aWY6UGl4ZWxYRGltZW5zaW9uPgogICAgICAgICA8dGlmZjpYUmVz
b2x1dGlvbj4xNDQ8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOllS
ZXNvbHV0aW9uPjE0NDwvdGlmZjpZUmVzb2x1dGlvbj4KICAgICAgICAgPHRpZmY6
UmVzb2x1dGlvblVuaXQ+MjwvdGlmZjpSZXNvbHV0aW9uVW5pdD4KICAgICAgICAg
PHhtcDpDcmVhdG9yVG9vbD5BZG9iZSBQaG90b3Nob3AgQ0MgKE1hY2ludG9zaCk8
L3htcDpDcmVhdG9yVG9vbD4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwv
cmRmOlJERj4KPC94OnhtcG1ldGE+CumwEmkAAEAASURBVHgB7L35jyXJcecZmfny
vjOrsqr6qK7qu5tkH9MtiqSoa8CRlhJmV6J2tAD1iyBoAQkENNK/tTuLwUKLxQAL
aTjiTVHiqWZ3sw+yzzqzzqy8M/f7sfBvpL/I9/Ku6jrCq16au7m5ubuFh5u7+RFF
0bhGAo0EGgk0Emgk0EigkUAjgUYCjQQaCTQSaCTQSKCRQCOBRgKNBBoJNBJoJNBI
oJFAI4FGAo0EGgk0Emgk0EigkUAjgUYCjQQaCTQSaCTQSKCRQCOBRgKNBBoJNBJo
JNBIoJFAI4FGAo0EGgk0Emgk0EigkUAjgUYCjQQaCTQSaCTQSKCRQCOBRgKNBBoJ
NBJoJNBIoJFAI4FGAo0EGgk0Emgk0EigkUAjgUYCjQQaCTQSaCTQSKCRQCOBRgKN
BBoJNBJoJNBIoJFAI4FGAo0EGgk0Emgk0EigkUAjgUYCjQQaCTQSaCTQSKCRQCOB
RgKNBBoJNBJoJNBIoJFAI4FGAo0EGgk0Emgk0EigLoGeOqIJNxJoJPCJSOCo38Wj
5mehbNpzRPCo+R1RsRo2jQTufwn03v9VbGrYSKCRQCOBRgKNBBoJ1CVwu2YJ9Xya
cCOBB00Ce3239kpn+e2V3nSf1Ax7v/nulX6vdJZXAxsJNBLoIoHGAtBFMA26kUAj
gUYCjQQaCdzPEvAs4X6uY1O3RgJHKYHd3pmDxtfT1cOuw37xTne7YLcZ+V7xe6Wr
l79bOtPtFm+6BjYSeGAl0Hpga95UvJHA3SWBumKvh13aTnhwKLxOcU53OyB5YkU8
jLI9TNrbUaeGZyOBB0YCd7rDeGAE21T0npVAt3fioPh6OocNc0GBqyvyOp3Dhk5f
DxtvuFu86brBboq6ju8WzvH4KU+Oc751nMOGu9E53rCebje84xvYSOC+l0BjAbjv
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
MUAb0Myetf6Z8XKtf85r/TL7s9Y/kI5j0k7zNX9zPBSkTaiNxyN3+z8Uw/bEwTeh
tmreTnOg0G0ud1WmlE/0BUJaTnldcn+VbgdPWAIkc/oc/Fh+OB6gPiuOLU9wc6Bu
h5KxcobBgpYDFjTo4430mn9jCdhBvncqqhkAHF7SVjN1uN+Zv9f+gS2Z0qaeffbZ
qa/99V9/5bhm/p/7/Oefx+R/ZX4+lL9Ma+XMX1+6Q7HyAvsldkE6Va2iSR0lHWfu
HLIyt4XAewK0iJ+TlwMMMOJDWvOnQwDHmv+avhT3/nvvxcmE733/e1L8N4rX3n2v
WJL5d3l4Wh/kmS2GTj8cX+JrjYzHOX7M/WIg83A5adjahJ5K6IJuRVAKOUeUIXd6
KbQ9fiui3eeKVPzNt4xIw6sqjckrRPJ0w9fp6mHnVsfvl5/5bE/nmF1yMFmyuJQD
MT6+FI9XX/gbiLX+px89qc19I8XnnynX+p86Nl0M6qNLvRs6BaZbABcXyjvm/dU/
W47czuql2BauK/Z6WAlcVNIyu6XOFf8O9NBVcknx4PbkutBv41fPtx5WZh3LnQpR
WSCkaHGuj9/LRFbVo55/hPN3nPeUMqRykHfQpLD5bYNd4itLgPjGBETlHFBH9dKL
Lz6u2wMf1oRlSMr/0ne+853/qu+QXFFfdVG8ffbf1bAlAEhxwLto+ebBKKricE5b
hlI1HGjg3iTQDAD2JqeDUNGA/W7bD/SsH9hp5t+S+Yyv+c08cfbszNzJk9zuNyOF
OiJl2u+Zf+z6Z1atF86f9qSQZFC9JXpp8UcheIHzjgDiI3JVnu5cxDfKpLLxaV4s
FSxVYPI/f/lK7O6/odv7VlAqOrcfM35m/vL3aRZJOaurZbcqI65RkyMqdcNmfxKo
HkQ8h34t5Ov4t870D2utfyB29+siiuLY+IjW+gd1zW9v0ZJ5YF17UVFabg8eKG5T
QPsrTEfqqq0rNi9tR+KdkEnZBY/cv1Oa/cTl76L8R1bubmW4jfnVLQHsCeAtxXop
0CtLwLTgpoyXxzg1oInLdQ0CILEloBzpl3sEEIUnTt4zQD9ZV/ZCNe4oJNAMAA4u
RWujOqTBGgf30oa9pey9299r/p75g2/pRZl57rnnpv/mb/7mKzKfHX/llVeek/If
lALtR+lf1mY5BgGY0XOTPxnhqs4kvfRVQXZR/tHZBYPkS/TGe+bhdUPPTIyP88JK
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
nbYeJg3p87QJFzIXfcUnlS/KXOeTh1N5mMlC6/LkJPjNt4ImqOVTz68edrKoB3yN
SHyM9/SVsJ89Htczkilx19cl8a3zd/krGZrO+SfZulguj8PmZ+i9Co43dP9VheUh
Df1ZWALS6QD4xz0Bzz33kKyes1pe/IqWAS7+4Ac/+C9Xr169QhL9cksAbDpZAoSu
rAXQuIgWn8PQNS5JoBkA7L8p0KD886CAsAcGDAL4EebHV/1aZ8+enXj00Uen+KSv
PpU9y8xf6+MDPue/pnV1LtLx2qrS3XYXnUHqQHk7YrBBRyCcTHAqC1/vu1ncvHmz
uDR/ubisXf7XFpZ0o996sT6V7vBnzZ+LfeJiIHWi7kg6lj69gxWNxJby60jeFRml
TbG5v0uClG3E7ki+A6HLzJOW84CApZFAqf7sd2D3PPKjA2SQsIalw2nLpHf2L1Vy
nVXQ1qbX+gfKtf6J0XSufzTW+se1SZtz/T0b6XO9DGBU/kohHaT01J92hjsCWbjd
Ui3zCz/hu8mleof4U733Vc5EHGyiXgyf2+WYv2+RT4rfVz53SGb0Ly4XpwKoSWYJ
4MbAYmxsbEZ94CabpBW9qUHAoiDNz7qKvhXnvtcQGvyNJQDp7NFZqHskfyDI0hvm
N62CNC7i/GOmj581/24zf/AjUvwTf/VXf/XlkydPnvjiF7/4gqwBI5r5h/K/qJk/
gwCO0qH8+eVu24zEHWki8gvlQudp8buDqOJT+rKzCILonB0/qIt6KMOVq/Oh+L/x
T9+I430//MU7xaIue9mYOhE3+o3OnYpNfj0y/8eLXSv3pqwBOCtKd9SlIiC3XUpe
6zCranvKE9wjA/tKmNJtKZwU7Qqa2nsCXIzgm5XLGSZ+sS1JaVk6h6ql2bO+bVIM
6wNGXJYzqTPyKP/jEyPqrjYKbm5c0sVIv7pwtVjVIGBgeEwJs6WRVA5n72J1g9vp
XKH2GGPNR8M4eUsFTqd7fGK8GNWmvhcff7iY1sz/1Scf0sd7BopH5Getf2N9RWf6
N/QrL5yypcN823NzLrtAyxIy/JIp7bITr0644M5zII15EcbtxifRVXzr4ZLLtr9+
bwzJp6Or88vDqawhu1Rv3mc4mZuh+Vt7Vfk6U5jQRlOCspdQIOXn51SR2wKV4o33
e+EZegz6ibRcTVhL53Juk7/pE9xWbuNrdEwY2BioyVHV58kS0P/pT33qMS01clfA
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
AhBkOgT+ZAwzOsHodz+AgxjJmmHBeSzVv3YAUrI6sbHRwmBHb390CsKPm/7U8M9I
P6SLfxaVJ+kYxNO+jLaZ8udefQpgKOvJltzrgmP3+6i78eehoTjjr+WImzqaxqM+
A9rpz8if9f60MS1XOhKXANbttkW3ngBSuSd0uUoFK0sfFMInO+xTc5yBljhYMwtz
ooKgkRtXODgGtzCj43dqGI9ohMza+CHd0MeIf4olAcRS2Ol8rDPSV4Dc0FpAQPaq
LAPwWcqCykZAvhInRF6JwAK2owFZWPscVueM6X4u9iFcPOLDPf7s8J9g1C9AHv0h
XFSShMsV544M3ifPOm7qONuVfR1ftXlXxPcJAJmU9yJ8Wb49h0+ApFOqAlT2Sgvd
mwKufOSJEhXQCFf74Je6Ao6BLrKASQVOmOkw4CCqgyoPmgqIJQLVemwe3LV6yuHv
CAStJFHICbOsMmtb963TMYcmZQpaGmwNqXMyylFr5fm72iw4p6UBbgpckzcg1N3o
1NkolgcgYdHwL9Ej8wdSfZA6ACQ8yjoZAIWOm0f82PkY+aN75O+b/kbU45z6rd/6
rU8899xzR7/4xS9+in0AerEq7vhn5E8eZNTdmU4WFRQlyqW3T+nqV1CoLBKJJP62
EUym5xEsfDjz/a1vM/K/0rz29W81y3c0IzGtmzV1sc/kkZNp5K+ClWRqc04jXEdX
zA7AmoohaUme+MUBfPkk8WRNhhLMNvk8hbA9OqAhbngUcpgTPTVx4hX/MdU/P6Ur
eTXdf/akRsRqJF9+6rhuvBtpTmkXPGv8Y9x4p0pxbflGc0eNoxtI6EEy2GRzEZ7g
5HAlrh17CidBTT72z+CBRxro2FJ8o4LjsqAtXtfjSMIYlCssM8oE7uaRHUcU+Z48
shjh+uSZk80C4XvikDYtaq1fmwCZo+GmQU4pOK/RGbqnUX8OVwmnA7Yf3YkKTjYT
zFZQd6ZY4QUgctV0W9j9aPdzL+gtPi5nBa/NswVf6NjQ9m/ZPQNg8G49NZ64eeTP
hWFWkWs6gkV8MrzFkCcKAg8QKIWe4dMMFC2e3CUTpRuvNAGmfBR7TLQcwIyV8u+0
OtScMmHpCb7OlzJ2lPMKLlX6VLk7cLMIHTxMOV66HfvbuCI45BYesxLrmgmQ26j2
Xz2vmYATumjtXXUGzu9wUyAR6dkAREQs3JgtQFls6z3FTqCPz+8HqQPQK9Wc2PjR
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
mMocSIwnW8BZNxi12fBPq4MzSTfRcjkd6C6CbqDhz2HNR4RTPjWv4LObYazjHn4q
C4eBJxzpPavTAOvqTM+oYd3Quv2OmKCBnVXngJMhV3VvAGf4r2p3Px2Bcp4/8lJa
2yYvP9K6PleHs6F1XiP+O/OLzSNtal1mv452u4/pQathNXjD6nSytFXindPNeTk6
fnLj8inS/p5mAMgR80t6GV1/E3q+lnPrLr/gSbmGGP1+qEhH86h8TKeLmRHtd0sd
Oz3FExUqQ/GeVI/QfSIyyB1Q+1nvEzyc0rIfxzLT64bMAKTg9C9IipOWJfVf9bHX
TatS2t6dZgD6FvdBsTkJ95PsAFi2tY7ZkUYnOVKXWJ1i9Yy2v/jii3m5nZXHY68n
yh6ARoS9R5EB+6j+rt2AwDDVT4Uzl2cA2Cm6qcK8o/sAKMBnJ9STZwaAzSMozFJU
gYTvIi9GTTc6srLYP+kdAEbzQLvyzPP7ja7/V2bVVNrGVrOmiuvBCp3FoeZ5zQCk
xYjgWm44Jx6SZcCvGWh5m8+Wc6+1Ff6gcMzeUDGzNkov+KGmSBnN37xxM/ZanKFi
0xrrN994TTMtO81XXny+WdGO4Z+8+4FmBFabv3/vY816bDdLqkO4FCa9ly55SxZB
m9J7CKWJ2tj88/yVi1rzn22+9/rN2NDFlSS6kDtLv7si6MI8iE52N6z1qFUqvtru
xZ4bfOx8jpMbM8O17YFatGNpKoe1G7SNL8LBY/UZV8AP+HG6mn5kXPKX8OBnHN6b
EB1k8kbOH6yHo2hsUcCVvI0DuEJLlNxBxCtUhk/TxUk20CynA4w3g/P2AMr0Ct/Z
H3qEJw+irl67rls/Z5rvaPf9/cWl5h8fPdYFdePNX/3Rm1oemGm+fuNqrMmf167x
2DCmPJviEFOUze8+/CgusPp//7+/aeYfKfynd2IJa1O7+/cm5pqJK3NxpI/8H/FW
x50qruoqBR/+YYmLRmlM5QHIj+aXmzt6F+N/+cHbcanQ//wXfxgzEUgNiUV/topk
kqKxdfQKpON4EqYq7ZHzusrUCh0jHXu8ozK/qxmOId0AOMItgCyHML8XzLU4b1mF
KlTOVjlMFQHDO6K2Z5D0lkXa8MtVzBf1wufczETsMULeLKmyz+rYVWaYfE1ZoG7j
1kdmRfTtrq2tPVSdOK+OABmSwoJOJvaHW/3B5AkwKqxSJ9kBSBQO/xsnASQgTQBI
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
dloNvzZPa/1/WOf/xXTKKyZkRtr2fXMkeQXGOunew6Z4SSg1i6PK+MoF3eaqmxPn
NFt4TnX5npZwH6sDNUjsPfgGOVR5yyBECdrousWu0Rn2WP/XAJaN0Cxnc739PZnv
AZJBafP4aMj4CM5HFuSzHf3E1Gl2AIiEI1NHzm5EOpV+wWkGYIuTAJoyeayNJjqR
13X13okJBMRUTHwcJZnSOfLJVe08V+YZ0gbOOP5HLoqCKhi4d2a23o+7lh9WOgtk
6TQGSoFiU2AdviscU4Gah9DwdkMj7Q2tf9Pux/s4dZgvwYy8EAVTXsrs+Uz+no5R
8jIa54GfjKkkJ4XNayacf+C0AHcLbAxzV7puGZQA1ne2mildx+oCDi98p6IiP6T4
mwEy82FVNHxZfg6/H++1X5fZkRfhwJkZ6II5LFP7wVV0gl/x3k/Bgxv52mxYu5nX
yENVmDYcdmZ0AucAmgFjHNKJe8DLLAPelWwo56p01GDwYiQbDdMh41piEeT340ds
6SL5tM6uUzMsWZDLk9yI2/HyXWOrzZYjac9sJEsocf5fuqZO9T+GUEPex8OVsaDv
p8Sl0hDSvB/CnqAzbP4jkaPxP0qp3I/OYL/oWCqPsl+DGQCN/vV+k9ZFdPuf8jmz
ABYlzNgMQsy1HbcTVyfZAWhHBnudgtjrFKEXFCmtBmSHNwGkRvU9UK9q+OKlS5d1
nGuECx0A9AxAFG7Zn1qRSSoFXka1zz37vHra483U0Ntxu9PjrTVlcu0yHZ1RXtPF
IMOKgmLiRjz0CpXRFv/KD3L403QU/9KjSIDFPfO2w1S4zv5/oStKNZ+kC3D0ZoEu
20AujG7KiCjDt8glgtnvUJojMAAY/PTa0B9rBuCjTz5pPtfDKWs7OrkwpNv38lTg
kApgKI9wkm2f3xbnihsuygAhLSprKu6Fhs7ZmGQyJnppr0GEpMLny6pjSg7FXsEY
Ft2Nkt0Gwdvdeox4ciDc7G7d/rYbJkam4sV023qJSytehb+2O7gyfdMCti9ewrbS
2dKvw5pWl05YKeNth4u1/8jk2SfDU0GiIu/Ivy7H4DK+CB+AQCZ5ginkFS7pxxWJ
bxBkHZg4dfFfx1Nm8IzpfvhxPQzELXFrunVyQXU1o8WRCTqtguhCAK0cj0T28L8e
0fciHIDDhNFzIy/TqjbFLmtqmxcyKVtzOqVE2Y87LgZg2s/ZVNowIWM52h+7zcDG
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
ZlQuS5mU8+erUCVc4RuWiiLzdb6QgmAQCpDgmTaAw2WaSqwUqIvo5kNKV/G301Ka
P3jYx4dBaH8hJUBlsR8QUwJGnoSUanIbm+b4pdjV43/6jHr8UvSff+HZ2Mr32SdP
d6a0Zvf4tI5jFqdtre6PxXM6w4G0u9w4Jq/O92p84+seeZHO35LLovibvtkYcHhD
UlWbZji7WeHPdITm88sq/+j5p/3+G5rr/wXKXyMA/7caANeuaueS+KL43fOnp08j
wD1//CitNAjIwrbnr0x4WKYdAXhYOZ8KPx+AB3P5SLD7++bd4A8e4yqeVbbsDrgu
uPvaa69dVEVCS/yGaLZHh4ZmuEawHkKEyUMxVL6upCyAcMjjCuahyNajFO6/PE5r
QOUHlb5uROlwkc9l9fyvarHf1Zu3Oisbmlcd04yPhvpHY65fK/x1Hnzs63exqGV3
nt4RJMfrNzA4sAuiqR2yGwIMxrBpD89D/DiGuw1/iCiC5E7jcUOhV65YjqdmOsp0
ghP81Ouf1xw/1/VyWx839506xhz/ZJzdzyK/cdHQeohb++jxe09/Vt6DFHO/lDm3
3XiK9yTed8KjH98aB28e5GSKKvf4Y84/9/x1m+/aqpQ/e/sva8j/iuzUQfVKf0Rt
e/51xj5idtdNj5hYn0pxnNdN2BwJQPFDA6RB4JEAFgXiZpcAMI4I1hkBC6dOnZr/
wz/8w38tePq7f/zH/2pqcnJmZHxcbQH1PhkRELGNV7PbbVho9NH3mOxuYHt4Bn0z
XGYS4fCjoqtpZMePhNa8XakZOrPsNq1hD8+aVx3XIDwyVHKFPFmuwt89fPEIk/ke
yh9a3oGg0wGkMv3hj38Syv8/f/8fOsu6D2pj+njs6585q56/FviNaNFfVOgOmOUo
8TrXsjxZui5o4J1/XQJs4hYME1d+o4cfluQNASI4/L4Rmyp84pd4dcVzu1VMwsif
/zwCUN6f+TTWEqRSooCZren34bsEJZqGRTzEJL9vs0s0kUJZndkJS6SsbSCuvZjj
14enA7njyF4N6zPH/5kzJ+Oa3peeeTp6/C89eSZ6/Memx+MjZT9/9Pg30hodhtIx
JSbkCUSCfNjh1Jx/bUxflLzCgSMdgXPaciDTR3qhMb4RX0YXf9y8a4b5UfzXr12L
0Sr299Pzv3zlCp2N1TfffPO/o/zPnTv3dyrPN9UAuK6g9Oa9v989flb7k+iDev7u
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
Ln3LAAAAAElFTkSuQmCC
EOI
	echo -n "$muneticon" | base64 -d - -o "$icon_loc2" &>/dev/null
fi
if ! [[ -f "$icon_loc" ]] ; then
	read -d '' macupdatericon <<"EOI"
iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAYAAAD0eNT6AAAEG2lDQ1BHZW5lcmlj
IFJHQiBQcm9maWxlAAA4y42VXWwUVRiGn905M2sCzlUFLUmZoAIhpVnAKA0B3e0u
28LabrYt0sZEt9Ozu2Ons+OZ2fITroiJxhtQ7wyJ8e+OxMREA/5E8EJuMJgQFLAx
0XAB8SckJNwo1IvZ7g7YBs/VN+/5vvf9vvecmYHU5Yrvu0kLZr1QlQtZa//EpJW6
QpLHWEE3Kyp24GdKpSJAxfdd7l0JuP0jCYCLm5fYf9BaMS0DGxIPAY3pwJ6FxEHQ
T9i+CiHVBWw/EPohpIpAl9o/MQmpl4GuWhSHQNdUFL8BdKmx8gCkTgCmXa9MQ+ok
0DsVw2uxOOoBgK6C9KRybKtcyFol1ag6roy1+4Dt/7lm3eai3lpgZTAzuhfYCInX
piu5vUAfJE7alfwo8AQkrs45+4Zb8V0/zJaB9ZBc15wZzwCbIDlYVbvHI56kqjcH
F+N3D9fHXgBWQfJbb2p4pFV72Q4GJoF1kLxbl0NFoAc0ywmHxqJabZdqlEciXa06
LXN5oBe0N2cae8sRp/Z5MDeaX+Q8XB8YbuHnX6nsKQHdoP0m3UI50tL+8cNSqwfR
47nDxUhL5GSQH13Ew/rYYKQr3FCNtWrF8aqze6iV/2ldDZZb8VXfLRWj3vSkapbH
o3y9r6LyhYhTL0lvvMWvz7EvUUHSYAqJjccdLMoUyGLho2hQxcGlgMRDopC47ZzN
TCEJmEHhMIfEJUBSQqJalR2+GhKP6ygcbAZ6PqaJRZ0/8KjH8gao08SjtgxP1MuN
Fk9DrBZpsU2kxQ5RFDvFdtGPJZ4Vz4ldIifSol/saNeWYhNZ1LjR5nmVJhKLMvvI
chaXkAouv+LRIFjalePdzY2dnaPqJce+cOxmzCuHgJmYW3FHRx7kuX5Nv65f0q/p
V/T5Tob+sz6vz+tX7pml8R+X5aI79828dFYGF5caklkkDh4yNvPmOMe5I1892uG5
JE69eHHluSNV73h3B7UvHLspXx++PczR3g6a/in9Z/pS+v30R+nftXe0z7SvtdPa
F9p5LO2Mdlb7RvtO+0T7MnZWy9+h9tmTifUt8Zb0WuKaWXON+biZM9eaT5rFDp+5
2txiDpobzJy5pn1ucb24ew4TuG1/ltaK8mI3IPEwMzjLvFXjeDgcQKIIqODicei+
nFal6BFbxNB9t3u72CHa0xh5I2dksIxNRr+xxdhjZDqqxgYjZ/QbG4z8PbfTXmZS
GcqDIcBAwz+knFo9tLam089YGd93pTXk2X29VsV1LeXU6mFgKRlINSen+9g/MWlF
n/RbZRJAYtWFDhY+Dzv/Au2HDjbZhJMBrH6qg23shkfeg1NP2001t/iPTXwPQXXb
1uhpZRb0XxYWbq2H1Ntw562Fhb8/WFi48yFo83DG/ReoNHxWWyl58gAAAAlwSFlz
AAAWJQAAFiUBSVIk8AAACc9pVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBh
Y2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+
IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFk
b2JlIFhNUCBDb3JlIDYuMC1jMDAyIDc5LjE2NDQ2MCwgMjAyMC8wNS8xMi0xNjow
NDoxNyAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3Lncz
Lm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlv
biByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hh
cC8xLjAvIiB4bWxuczpkYz0iaHR0cDovL3B1cmwub3JnL2RjL2VsZW1lbnRzLzEu
MS8iIHhtbG5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0v
IiB4bWxuczpzdEV2dD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBl
L1Jlc291cmNlRXZlbnQjIiB4bWxuczpzdFJlZj0iaHR0cDovL25zLmFkb2JlLmNv
bS94YXAvMS4wL3NUeXBlL1Jlc291cmNlUmVmIyIgeG1sbnM6cGhvdG9zaG9wPSJo
dHRwOi8vbnMuYWRvYmUuY29tL3Bob3Rvc2hvcC8xLjAvIiB4bWxuczp0aWZmPSJo
dHRwOi8vbnMuYWRvYmUuY29tL3RpZmYvMS4wLyIgeG1sbnM6ZXhpZj0iaHR0cDov
L25zLmFkb2JlLmNvbS9leGlmLzEuMC8iIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUg
UGhvdG9zaG9wIDIxLjIgKE1hY2ludG9zaCkiIHhtcDpDcmVhdGVEYXRlPSIyMDIw
LTA5LTA5VDAwOjI3OjIyKzAyOjAwIiB4bXA6TWV0YWRhdGFEYXRlPSIyMDIwLTA5
LTA5VDAwOjM4OjAyKzAyOjAwIiB4bXA6TW9kaWZ5RGF0ZT0iMjAyMC0wOS0wOVQw
MDozODowMiswMjowMCIgZGM6Zm9ybWF0PSJpbWFnZS9wbmciIHhtcE1NOkluc3Rh
bmNlSUQ9InhtcC5paWQ6YTMwYzhhM2MtYmJmOS00M2YxLTk1OTAtNTI0OWJkMTE0
Mjg2IiB4bXBNTTpEb2N1bWVudElEPSJhZG9iZTpkb2NpZDpwaG90b3Nob3A6NzQw
ZGUxNTYtNDc4NC0yODRkLWEwNWYtYzlkY2Y0NjQxZWYyIiB4bXBNTTpPcmlnaW5h
bERvY3VtZW50SUQ9InhtcC5kaWQ6NGI0ODM3NDgtZGVhMC00NGJjLTkxNWMtZDUy
NzM5ZTFhY2NmIiBwaG90b3Nob3A6Q29sb3JNb2RlPSIzIiBwaG90b3Nob3A6SUND
UHJvZmlsZT0iR2VuZXJpYyBSR0IgUHJvZmlsZSIgdGlmZjpPcmllbnRhdGlvbj0i
MSIgdGlmZjpYUmVzb2x1dGlvbj0iMTQ0MDAwMC8xMDAwMCIgdGlmZjpZUmVzb2x1
dGlvbj0iMTQ0MDAwMC8xMDAwMCIgdGlmZjpSZXNvbHV0aW9uVW5pdD0iMiIgZXhp
ZjpDb2xvclNwYWNlPSI2NTUzNSIgZXhpZjpQaXhlbFhEaW1lbnNpb249IjE0NjMi
IGV4aWY6UGl4ZWxZRGltZW5zaW9uPSIxNDYzIj4gPHhtcE1NOkhpc3Rvcnk+IDxy
ZGY6U2VxPiA8cmRmOmxpIHN0RXZ0OmFjdGlvbj0iY3JlYXRlZCIgc3RFdnQ6aW5z
dGFuY2VJRD0ieG1wLmlpZDo0YjQ4Mzc0OC1kZWEwLTQ0YmMtOTE1Yy1kNTI3Mzll
MWFjY2YiIHN0RXZ0OndoZW49IjIwMjAtMDktMDlUMDA6Mjc6MjIrMDI6MDAiIHN0
RXZ0OnNvZnR3YXJlQWdlbnQ9IkFkb2JlIFBob3Rvc2hvcCAyMS4yIChNYWNpbnRv
c2gpIi8+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJzYXZlZCIgc3RFdnQ6aW5zdGFu
Y2VJRD0ieG1wLmlpZDowMGY3NmU0Mi1jMmFiLTQwYzgtOTJkMy0zZDMyNzhhZmJm
YjEiIHN0RXZ0OndoZW49IjIwMjAtMDktMDlUMDA6Mzg6MDIrMDI6MDAiIHN0RXZ0
OnNvZnR3YXJlQWdlbnQ9IkFkb2JlIFBob3Rvc2hvcCAyMS4yIChNYWNpbnRvc2gp
IiBzdEV2dDpjaGFuZ2VkPSIvIi8+IDxyZGY6bGkgc3RFdnQ6YWN0aW9uPSJjb252
ZXJ0ZWQiIHN0RXZ0OnBhcmFtZXRlcnM9ImZyb20gYXBwbGljYXRpb24vdm5kLmFk
b2JlLnBob3Rvc2hvcCB0byBpbWFnZS9wbmciLz4gPHJkZjpsaSBzdEV2dDphY3Rp
b249ImRlcml2ZWQiIHN0RXZ0OnBhcmFtZXRlcnM9ImNvbnZlcnRlZCBmcm9tIGFw
cGxpY2F0aW9uL3ZuZC5hZG9iZS5waG90b3Nob3AgdG8gaW1hZ2UvcG5nIi8+IDxy
ZGY6bGkgc3RFdnQ6YWN0aW9uPSJzYXZlZCIgc3RFdnQ6aW5zdGFuY2VJRD0ieG1w
LmlpZDphMzBjOGEzYy1iYmY5LTQzZjEtOTU5MC01MjQ5YmQxMTQyODYiIHN0RXZ0
OndoZW49IjIwMjAtMDktMDlUMDA6Mzg6MDIrMDI6MDAiIHN0RXZ0OnNvZnR3YXJl
QWdlbnQ9IkFkb2JlIFBob3Rvc2hvcCAyMS4yIChNYWNpbnRvc2gpIiBzdEV2dDpj
aGFuZ2VkPSIvIi8+IDwvcmRmOlNlcT4gPC94bXBNTTpIaXN0b3J5PiA8eG1wTU06
RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDowMGY3NmU0Mi1j
MmFiLTQwYzgtOTJkMy0zZDMyNzhhZmJmYjEiIHN0UmVmOmRvY3VtZW50SUQ9Inht
cC5kaWQ6NGI0ODM3NDgtZGVhMC00NGJjLTkxNWMtZDUyNzM5ZTFhY2NmIiBzdFJl
ZjpvcmlnaW5hbERvY3VtZW50SUQ9InhtcC5kaWQ6NGI0ODM3NDgtZGVhMC00NGJj
LTkxNWMtZDUyNzM5ZTFhY2NmIi8+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpS
REY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+PycHxgABm4VJREFU
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
Q7mtptzIaYiz84S/BHALgE9OVN4EAGTjEgAfHp+BHUKPu1pcauz4Vv0idU/vWxHp
U7VSHujlinUEmlP8ssVaKuZA7PL6ULd7wVxrt8Kf7MqrCGxQVJtgyFNb7iP5qaD3
pRwImI/20PtWvBoH0fx2d8+SPMqQkIfeRtf/ElBQhTtpODvS1PAMWT01DAvvRr38
J67hfSCPtCRj3WSQ7KEPA7gewP0TADAZGwD8PYB14Y4obiwMzt6oaizb5t2p9Qwy
tB7G+kZoz/Dn0nsWgcqiMROTy5k+dohH7mTEwsKigPPqc/uHgt+O71WDKxhGMFWX
rq/bjoZdywuqebtrPZnrkkQ1U/7+M0QBe6JASZKZx2JdIvPFdQCOTQDAhT0+BGBP
s+vFwcf97Cp+9zzC6H2zf5AIYT1ruh5CCs9aq98tx6L8NRBQstSp8coDWYKlAlx4
PEeDqyxuzt4vlBFONN/vIHpfOymMum7c9PuIytnnq2H8d30gW3y+Pm7lAKkl7QyG
XoBIgDf3o9mcsxJlu1RWHxRD6Ah8Tyr7nzwBABfueB+Am/yKKcRKqrhSq0bt655b
ff3V3sLmUsPypvS+YSEUl1fBFiWgMYE1G01q8nuTzAWdNJ0xS+rc7XtD3rENzbBx
pqnmHKhahZi6Ha6e9aVSRW59h91nfBx321G7YMTdGzGPlrxbdvmQ8CRxgEj0nxk2
XoWz6vzA/aBap7U2JfhNqQ548QQAXHjjHQBeFCb4mpsFrtIlk8qjW+XflCKU7b3s
ncLJR+8rO7CoPM1nAmL/eQyTCrWopBx1rhDcKy/TGVuIXdqUFub0vr4acN/sqv5c
j+o4DGTam72EOpTJJtydzWXIk2YhHde8XjiLO5cY1etm9nGgNieU0rg5acjKo0NN
Zki3RzD/V6KAva23mtIBFrm+zHhRqgu+cwIALpzxEwC+I5zzu766rqxZNjhVqGMh
Uab3tbDaawnF3DG9b/FzOpOXCMBaHdP7EuXpQUWRGbmFj8lsWElx66P3Zc1qLdaY
wRAdWf+Usyjm8IY975eFUEyFx0322r0OouJ8spbgV3U+PfTTRtmIpOT/QirEK6hk
4YMOHLAmXXn61HMkDTa/yrx+Z0KntFj+HmBNVcrftg6U3r8qL4l9T2z31SzqyNaD
GRCVMsO6Tt+BJCHwFycA4PwfXw/gF4L9dtxeNXMwmUYXqUVKnFzl4iad5S5jyYpc
wszKthdGf8tK9rck6aGdpQrLjD1+kxpzyEmLCjs8mxexRZGY/PAUSglrhgAopxWO
wJBs0uiqjR3qnTNWykolsSYqM8pfmO+nnQuLOqNMbYfvtfreOu0Lpatos1JVbvii
LbCtqM9FdEzk8CLYKyvL58i11xU31FJRaFVuzVuCVQFNqSXLMhhSKS+sTqJ1KHAq
yiYpN1C4rJNLYTlfMC1R/jY6ICaLmLHQ+5KhwPNsIMvak23O4TLjFwC+G+A/mQCA
83fcAOD/1IsJ1iCYCbE4LE/tprmP+uS43MijqAY3Pp0gZ6rT+pWBILpXH72vlUch
hNu/CkLZnuijnjUZAHwtZ6jmbuusie5PtgsxuddHGna4RHXin9H4h6tPW0gLHRMA
WGPOjk+HJIETG4qnlresi71ejcFeGmWqSU6khsacZ9FGxd0qzFhvT8zOjhxAWFT9
Kef4PwDfCOBzFxAA4AvlXTcA9Nd+d+/Zu/Ld8vsXF1lSlfCWht3FNah929L7wrCy
LVapdw4uU6LJHMJBRT3fj9pyhlw5WC0hH9U4WVSjkMPTHyAIxugExnnrGuV8MtUr
vHPpaRsPYNgqjy/tv0VjcOefibsxQEqeMk3RUst1I8MXVGd+VOHXIyfQDjpBlfEZ
+mtAXoELpDzwQvIAfBDAlnoKvRvhsPr0vhRwsWyUxj7G+a4tIteqdFMtT6TmSVvo
fUsiigPXtOJTgRWDbc4EUxPAyg3PULiSY4fyKAIKHOBnIj9OVDBM7uFVPDnc6mbW
JJJipdLQcbbqgYDqHgQmjTK18R5Zb4fnQoW0Nm/9Cfdddf68t9iD6t6VLamuuOVs
+HjOAgC4IFojvhPAzSadrf1c+RKBwnuCk4Gxx0PvqzfIKXecowrLQWngYTpg2a4q
dUWt5xeorsQiRpnGa5kKBK+5axWq0dJ7BTQRIceekI1lThGXjBLjvNYtkLni/e1T
YLOFryFss+/RWykFErNSGQAUgIOV+v6aVpHmHdAZIe3eJbYuCWnn3dJtkZSgCOl7
rSe269zuRLqPCur2uHpEmUpES0x1s/JxQNmqTkVPjr83lhQKlW5Q3wR9nUlb3Sz5
j5SzHAjYWD+LZuBA3bsyXbTbI6SzO7MVEOutfI08DlIzdPTvkDZ7n9XtZ20duLQr
FW3cyy6xm1Od8drzXT9eCB6AHwHwrWFotEamf0DoYPWofcvkLVnqm73wjS3/LUeu
Q+l9ZRW9L5O7QL6ybrdOjTOs9L5ZQpxgl1uYqx9WyzJ0109zi/dj4sBT1ubUicCz
756FqDyfqqgXmkVtN6cLMn229U9gctesO7fSU+LIgWctdAfzXj41wBnZrf8cEDA1
sv6dJZdcrtl3L4ptt6Ujgl+xJWR9Q5iR/0p3P8PjFfGtk3Rt2LcC+BxAb5kAgHN3
fA2A/xImNOsK/LXiGuKKv3XVGsgKmFLH5c9epUU5w5+PQrSq81yAUvLS+6rv5FMW
lDAecr0SPcUP459jQ3dP1Y8xwfAA1J19+3Nf3jE7MLTOsgEHEYcSKQVRydJY7zXX
eUFPYielHYWIqUNpAd2Kb7QEfpY/kyiKKDyxl2udua5WA0h1x2d5nH1iJgBgbGM7
gD+3ShhqSSXbQaS7m+9mq36RFGLJZe77tvS+/rez0/uSBX23tP69b0qaa7naRBKN
9qQyn0A2q/tnYk/cnz30vq70PGp6nL1hL1G1Qqm0llQ3T3scRXXdnrFVMxS4rvLn
0iqy8642WTeuBL5mQRAF3FcZuG5ibHuTz/LPkTSLOzABAOfW+ACAGftGc+dXe/yR
orbpNV2tAXdQqdA++U+LM1Y6b3hMez0+LxA3YpBp0l29grK3VX4Kd3z7GpRSUo3P
Bnk0xrEX3IEg8dMr67ifW98GHtu55HHeqiafnAHwASa+cQIAzp3xdoBv8NePtxBD
ZOfOJh4XBaj98NoMATvKryIuDRTn1EGGPoVSdbrFg53/3hURla1X37rXKb1v+Qy0
E2B+a9+tZO1npKo80MOVJ9ruNaUERSE7zeVEPWWOzKS4jDPWN/NM2xJHVbIaV3ip
TF1rpquQI7HTnSgckmiW7bd0WsE1XALlU0+O28Pcip6QwTXBqQzyvHjlS2tEIFvd
dyT8MW8H+LvPt6TA8xEAvAbgN9gRsZI8RGHMbiXFH/DvhK6b/Sj0qeSmtlQbrOn0
vg7lmlOWVa+FdjnJIAzlyvZ6sGf7u2xrcitHpYqjbM85yEpsgc0W9L7Zd+fKgetb
l9XKn42SZapQNCFCLqyqQT1jbHgBQtzPsgqwavS+HmCaWqvMmcKnpOyO40BAVKWQ
qQSx2brXRYWLBvLJd+bU0hB79jxTmo9PZbuXUONOGXeJVeZK89nM7c6n5f5Vnk+q
Aqe6XMt+z0ZFUXur3w+QtTtPetImMd4A4B8B+fsTALB2xxUA/57JdFW2okUjWBmS
N+63xNse4lj/JtKLDLO4qkBVlyw1XlxjLbJyP5PetxIMcIWAVkmFKHweam8xcsga
ctCW1qHgLdV6q3z2Ui83pHCQ4d1tYo3dTRXq5TWW4WsXst+KAJbExitxUYLGVbYW
GWDCRsqqsCVa2QHVVtBCT/wzwTCH3tjyWWPfYzSokP5cJQ+O+tn0v2zv8CczMKDs
a0FVTTXkgxKNJ873w3UkGxspxv3TzyeloK7i/pVmliUhckpORsXzqUsw4GtXrJ8B
jScx2dPfA/hjAO6ZAIC1Od5fbRVQawEdcsy6f7LUOemh1t4XaolUBVWqrXeEEzj8
zaxuOmLPeoa7Q0MXNhWZNtsnVRNUcw4UJDZQAgHtuuc5Z0fSEQnlwNm1cYcWK1ns
dYnI12qlcmmF/OEQqmDeLteFV5U8Ut2Vrqk4uPwosu23dMyr/FkGvPS+Qd4Aaw4B
V7EYdHr//ArWk8CqBVfYYCZN2Uz1LgXd7J/t7DAMThPrPXs/gMsnAGDtjd8DcFnw
pWdyXM5ugUBXT2Als5+dVkqWPysV71sIvW+2BpH1srBBZxtmJbg6h1Vk3laYKBZK
nwCxRh3uoxl6oBaMfm6R5F5nDrRoTKu/QvmbwI6qV061AKXtvYgrlT95t8j0Gfiq
HFzr4FJIOhlO5URtvSuoyZkjy1d0Se/rZfbvbLSh1zb5ItmABOOTwr490WdFboB9
GSW65lsnAGDtjNekvzybu3bUemO/WxoX5lpzq0t13Ha9upjDWPS444HVD21Rvl/D
q8ANcpS7yEr3Za5m7ndyWG+iDEmoBttd9vXKmWbW56t7ASoCa1ZmX2p9mLTyTi/l
LLsxx9jP8rjkXXE6ue4UKPTVq1pKjV9Ws9MQZJe++SuAzvl8gPMBAFyMhLaxbNEz
ldzmzQ5OYevxWK9Z1cGlCnnCQfaP+zm6sLcKcpXRg5soqQo3uUt4kCmMuxHrYZ9k
LZqS50yy33bwrgrVEVRtyX1COwDabhFV2HKeJQ0xQ4kcLG9k0QnK2Skpd5vLIpTk
ioMUFCkNjNyQzoj3B0SFSI13G39PNVvplDAStTxGzg11rRlZ76vZeZNtcoLLIry+
t8Etv11/z7XvHQHAO8H09wAenACAszveC6dvLsR0C+kMqJPjhjheuXU9r5p8UiTa
aJQzTLYiptK7FEnqVRav8jNUxvyUKn/OvpcV+0zzlKp0uGyBIhWUMVp0hjVhQun/
xxSDVHpfdig0naQcdZr6ZD8kzTIwJWOMU/dAiGwteW+I7bY/i5ygibhOiEqE+RsM
d3/5rEql8Q55nARs8Psrb5LnnRaCnRQO/uL3BGZp3Ru2Zs8rEJBC+e+lRxuyrryE
AyxQ2mZbvUPM1fS+Gr0eGblmadAuTfgTKgFVuAMFzErPSdI3lFGPhEefuv18EpPB
75/IBSJY4GLiRSJl3RhFEqGu/It+AM2T/bgCBKh31wZGOPX4sX42yvKTUt1z4wQA
nL3xn5DUaLZ3hdE4XFBdegAoz44N8y82pzr2ZQ0wE1jIQHpf2+9rspiRS9WJevtM
3JjeF2Og9+U8uz6kO1rdEr/uvAlMgOAQm5D1WQYTzhj9BDmQiJ94TPeOggEW132s
xwPQxqVYSe/LbVYkrEsm1fTLOeWLpSKiuxUppUkjlKnC8YY3pDroxyYAYPXHMwD8
aH1FuJaHvat5QU4h4Kp6192j4wMz5HRvhDal6SbmX0tA8BjJO7h5tj/DT+/rXtMu
hGPY+QhVHrya/ChnjYuljjypEWIa4+KNS/nXmXOR6c9Bn20uuqrknsGb4robxHVS
e38UwP8F8A8TALB6ow/gPd1a22cLKHCN2YWWt3HnF7768vs7DNZeD+pm/ZprqG6e
245OFi0BgBmjl7X3hjhsRu1ZNbi7PRnbPW2hqBtXKNrzLDjQ21IXAPAY6I5rN6ge
1111qnXzb+uyYPJ7AOwEMDwHAYDEOTh+D8DmABeNfbPJzlJmOxxibDJHBuuTevS+
4THjbuh92eFxoBoCwk4vupr0vsn3SXc1Wuiukv39KJhXnxNHj3QpRl9zJfWklJU/
UztF6l638lPzfA2yA9SE3lcPsdjd/2FUslVzZotirOe7qaoj999hanSnqs9W3n76
rNP7Uj350klCIrc6t+5nhMqufN02pzrp1RMPwPjHywG8yn2iPGmvVK46VZOYXAKd
GqLpUOuHiZ0gxkbvC3bEj61Ux+53a0/vqwigyr0IofdVyU/g2E8HvWiA1eCn95WN
6X2ZPDKN9IyKjCWNlI54bHyWGnVl8wjnXPkzTIrhkHPtez8bva8f6yiJZTJlkyOy
GLB1qGT9Vid7zkI1bbdjHszuu5qf5ZoAwJOELF3P5pY9Phz3zy4DPHtioUVmKj+3
XYKfS3G7V7pM71v8PDFayk9WQrT8KoD/iInfMwEA4xvzAH6/+tqHIDiZ22aVSgpd
hx1V8SQNy014AUlY4liIoNS5t016X9SiIG06h5KYU+h9lYxg68+76G+p5WxZORXh
dCphpUTKnBkVdep16H0JYTz47LV5wiFrs50mYqUoQBaUr2xvzqN/o5kAW702dVMQ
wyxfhd7Xc0fM3QtL3+Ugz4NWrEvUkUWt37/qHVXfUK87JOupy2ppOF2+rvJY/BTP
Ft+TEQjgVvIzY3JMKjn49wHsAnByAgDGM94J4nVWxMcU4Jh0u9hYa1gjGrru6h5i
mcZlSbPKCwAgNL8A54jfYoVrM04/HZC9DbLT+2bd4IiF4zlVMVxCrTBAif6WNZc1
lRgC2eOREAHfp1PNFLnBsuyNUSlxOcwbYK4Rlehh1XUzehQEW3W+LElZFn2kv12I
NVyCEFSx0xpfQrk7RsH1Lo3jwXaVTIxyJz/196JalTpCACUQ4NMfZKP31c9KhgnY
0YY3774RdCVkeZuJLf6dFK5SOy8lW+inC5lIRtsFmwVuL5BOPAwWel+SuZehGcWv
rceAozMkOeCx8h5klZ8hXkXO3wXAOiScNF83AQDdj1cCeEUYhq9KO1E2l8KPW3eK
X22SIirdrKbQIgYqk2WZDJtDembTvG1sEIKupPf1c57bE+m6ovctXPTU0MfiV5ll
T0KZsI4NKVX1fhTs3THnE7xqVKb3DTmfwa7u7D2DmjK1OZ81y/WEzwInu+PFrpJr
nlV2rpVOxd21GcIBPQfMb/bPRDb0ADYb1WTVmceJKu+pDclX51QZEuMVia7id58j
AOCc6G88D/A7cd4MdlijYbKznjQgv7Q6KxdzPNBqbeyrI++Ez90TWud8sgIEsvCp
mdxHTA4CHTov7/e42oN1eVPPHsE5nYX9kF3eDtsH3gnggzgHQgHnCADgdwI0V9D7
thXOBN0BnLHcjfsihPWU84lDJjJAAFdYggazYKjS5bpKmqolTAC9r50SNURkUdAM
c78Ll4lrzCnqp8S/WKRYfqZ3oX7zxfAs5LqAKmTlXG2cgnddrTZglzXtmRiFHqAw
A5U860mlvWf/UpuskuRSalwzQ8WxiyqToO09W1r/PitXc4sb62lrD2atq2e2zrm5
27/6NJf9XSEx/5rzIe8GzBHwTmJa86GAcyEE8BKAXqHFmbiGS5rYK/ISayWhhWQ+
O/S++nyosrMdk+LWrxQCMn9laSMaUmhsCxIOztPFuEogBipIzRFBrAmTPDJMEsRU
tPM9C/S+jILuOPShKowr9cfjMoCrtiSq2ipz5UtaS9FYSXD2nHX25IISszPOr/5e
sl3hc55noWcjFM0uTQhGsGUusDQVjWOvCfZkS0e5LdjV6lbNq1FLg/S+dtnXxWlv
e6GiyzqmSnYviUtnfDz0vsXZzCi/yYpxsv0q0hrV06+lmRpkVt3S+9qhlY3et+hW
btL7EkLTX9UqGv3uq0Bfld30ikR34c8nAKD56CNv9NOgbW8QI97ZcEGp3x1K71vP
0rOjffaCmyKXZZy0yOx0BRIoUSI8HsY1aOqkK3pf1uwiRp0Evi4/B4TWD1bR+3a+
42z4E8iW/Oi7A7asdB7T6eSKvVY0jHDPy845R61vd1bT3j3DH6UUvPohcdciEfSc
Fn+/wPHS+wonTDDJqqnV97MDlCQlj6L8fu8EaAfWMEHQWgcAbwWwCefpsImK1YYg
ufJaAzFqwaImE1mzUalSeVz5CzSmz9Z8Ko/n7cK9FU3OvFgDNzb8XIzrJI/znlIt
4C1qnZJ21n94EMpXjjvWVEQ7PfomgN4K4HsmAKD+uBHAG5tbRI2il6umeovEKtHo
ONdj2vM/i9hmqYxB0gTI/eAcfKbO9qKbZ7ue77L+uNs519gvCigPZWpL76tazG2T
4qiVY6TevH0PJs+UyuW5FHQO6u9kExCgu+hD5UC19AnyYfHZqwIoPiZrtEUPtf69
yj97/hsB/HcAn12jAGCtUgHT/66OhQYcegsj12pbu1yL154DhYX0vDMrKUgcIE0s
ArBtghGVewpmDsOx0PuSXZSTViuc8fzVe7+EKIkNQUmByYlNzq6st87EjZ9huyO+
N3HT+6oboUSF2SZACW2y/9kybzMaXS3o2TGHOvS+Mhyck90oKdPUtu2l4b5/dY0l
ctD7gqT25tRZ9nQNel9nWWrb8KXJzGrxaFFIWFlbu/8N4NqJByB8fD/A1zSy1Em3
YlwCr8j+X027X5eRBflIOVs/Q611kEWZ1lN6UCob/uDumiJ56UV9ljAZllKgI8AZ
HUxJlSgT1owaAoa1/5aXnTUw4Lf8Q3uU16E65pTvSEnqIvuP+u4Je/QXGdOnCqGd
EPoVyY9sAhEtm12R4FS3VbWd1EVlcCSuu852UFim9/XUhZDJ8uh/E2mUmusG+Bqg
94Vbvqh3gLWkv6ZDeqRnFb2v+n725knlxGE3aCrLTyV/gULucmnzr0l0Gv7rBABU
j00Afs3uNuNgARHymbNRAOlIv0HzHmsusWxBquwjTHKwaLV8SzZshbJidJHWhM0j
sGUHdOb9sPerapCSM7tpiswlHKTHs0OBJ5msYKlo5sL5aaqKmMta5zN012PY0/G9
TRiCL6MMOAlFLUb2eKqQI6biEQGyhdNPkiXRL+REyhZ+zTb3z7ajrvtHCqByn8+C
Xpc6rOmvR+/rTxCsf5oJhBixlqzKaV6HgyYy5Nm/lnoCjqwtAEBrLgTwdoAircsI
wlmZ9O0nh2trlZW+4aqUqZhJmr75yhZtdJs2SlzSUY1C70tquWGa3U6lGn8L/W3j
6gTVPatzi2dWatFwR0kkIouCdNAzV1u0ZXrfomJZpfelYLpPUyiRwiSpNWPztRMs
Hd8Q+luy77UCbnJaVWXfZF7SVZ19YJ5PG8N7oU/LBffMGd0rG9ar8l/t5wSs5Ag1
0wLsFeAyv/ukuiLI+BICSoz9REp9oZHHb6FRzmm7S1UVFbwcauMthd6XtHcj3eDs
4P7pZ9lG7yu1U0CaJE0aNnEmX5TPmvS+gpsmbFrOvcUgYJRFnu2u2ul9PUcqfb+Y
4hz852co3yc1259TGzrIWIsS3YZvmHgA3OPpAP6NH7HXKQ8LsRm6Q+DscB+yVc6l
LkvOLhhb0GxIl72y9Ey6VJH/lI8ZElXTi6oCUbaeh34FpbEq5dY+3G5nS/MlIoNY
RfVwuLo2hlKvGv9GuieAAq0Q8zy6zqc5VQpZGpLOnvTeybTcgWJNoPuFK493WFIe
oaItE1V45rjssSligDw2T2Q4va/7Dc1mRsV6dD3r+qReulcv0ANTqvt39YkJTUY2
vEsVlOeJbsPTAfzjBADYx2/jPBnVWdQqUmXF6bYK42xyf5oXiyTO72Ha0vVrwsO+
o56YrZvlX8YsrAniNXCoullXonpApqQnKPCyjWe9+Ly4L1VvSF74v8ZX7rcBXL2G
AMBaoQLmNwB4gi40UfswEMpxwNXZ2jqCnS1vESIk7OvCmeBSLYyQWq8xlfq5MDaZ
l5XaCwQzmdM0LG30vnUhB7EwOiaW90FSiD+JK2Y2vjLM1owF+WXiMtWx1aJn/wFx
JeAHOUXYU0eQEtU6Pb7GP5QOq17OZzjQC8ua4GizoeQRsP0ea56+zl0AgXX5+T4k
HiUy5uWucOGKQsm2hGb2p/vpfTsChFT39tUpI8w/+wQAbwD4t9YGAOA1AQBmAXpL
8CEhfz9ogfBium7pfZM/S9KPUJm2U1WCvnIdPxDSZ6Bn/HNZbgMmvS/7DnSdi8OG
fC8kI+f0vlDyEjzCilWLmYK2gRRLlNTe8mQEVZjACOP3J07i/FkJIHnimvZkQRf7
nUvjSX0NDDnHmi/eyOqm8n6aek0959JG7+sQ4lnMP2EAtoU02PH3Zr4AlTdN2e98
p2S1uE3yLVlPKwAZWexCSSNS699j/WeydyflzAn1E6ytG4HSZDAuftQrstLTmc6B
STFMuByaqoWNLeePDdpdzRZIl4i0LHp1t/W8H9aS/OICHykPVUsA6yl/F72vJRRB
pkNepfc16vu5Soax8dHyPSWtmsVWvOyQy+RL5NZ2+S0A/z6AM2vAA7Amxq8mICBU
2VRbWON1SAa0G3YeQz+pROd4n1UFM6YV8TREoVxWcAPS3rBPOe0FQ9+unifIJQia
mHsh3V8IrZjOQkKwVFjIXEr0k47yqBDmJ6XvA4fNk5y5m56KmKo1tmfzld6kGkLa
F08FYS64OA5631JZrXBb+GQhMOYqGjFuc+Cqidr89L5dWOY21FzkRFDj53vrbGZT
nXfWGQJ7Z59iky8B+I045wZ3dx/G6uw7u6MwXAnj6stAa3otbFUs40BgPOYzw2M6
eTyGtRjPiaDa+x2+V+2Kbrt6V7GKN4mD12f173ZoX4pW440A/jOA+y9wDwD9Zr1t
5lrbuJqRVKYQY4oCPBntV0En/BhjQyQKnYet3lhYXmoMnOEtwlyFK7UJ/bQZqqpR
fcEU/FEt7OEhaW1P7zsOUaya9WdF/uhotQLMhh1P9YOWkBtZnjsm5a/z+3MQNBkv
vW/L1uJG6HQ89L6uxkWiw3cEAPwmwHdcyADgNgC311H+Lh0xHkY/dqL6eudfdjqT
s2Uju2LdVEXZbKUbruZ391XJtW2LbnsX26U3aYD9F53DAEnl3ExRVkUvrCuchM40
XNTqsXrzO1VX7Bg1NLtbGNcHgeHcDmb6WxdkNixYiUIp1RLcLi1Zj/VXnQ2zOsOf
EZVwGmTZNOmq8FiKo4MwL1eC+3oyLd/vEqNfJlBsILqJ8q9CkNq4HeDbAPzThQoA
/ltdwehTvDQuyWRV4u5WH3pWfxU/efUhlh77YrWG2e5TrTOmWug6DKv41Gcrdylx
iT7U/O4w60YGCGCXwKpHe5tntnvXmbVdqXKwUuC3s+FJYh7PDZMBxyLcogvlA9XP
dRfKXyrCnr2Sov39I+/K2NbC1YVDGt4E2RHUk05AGSYxuKIeP/ROSQWcyTyZkUqK
uYJ9s/Upt8lE+m8AnnQhAoA7AdwYRO8bYM2o4Lqb8j9ToMj0O8rxXDbOYpL4Jv1I
MN9/0h9A7viXiZDDraNurX82avfLlhPXN+GybPAAcj4mjfQwmD9BiipiKIVPn6mG
YGN73ZxWn4iidiwgUlEdTjIFijSy+6vOZ9h5YfYB3/bdNjlLxHcYdFZuFao446SA
My5bb+r5lZZQXDMgkHmKyK7yuZ0Pz3b/ciVZqlCRHu+bcTZI/6zqsRAQY+i46Fgj
Mn8vHXLOIH0iv8BgpVohJlmcjZTvwZ2f1HHeDrnop3EjQHcC/N6zBADOVvoU/Xoj
V44nicZXWd3aPqGMwDcr+4tzsllK+4JFmnWsSlyGnWw1+2P1rE26VqdwHOuWcW6J
mPS+JXpRUm27qkvk4DegUE9aO4FaPFeN91POFuwFAuSK+UNh7CNkxM8hVKRl2lnW
srGFzVInI+5M5dppVwf3Mr0v8rK1hOGPgi25RhA7BSSyKgRQxRdAZrWF2xTgjCqX
CrcwG0Cudpw701YWel92lAW3vX+FEicLSDIZ/rgE2Ys9KNP7hgPiKoVvo/fl8t0P
ovetIqu2z0Vq9OjFnSkMCfUbI4ynS66tGogB8K8DuKAAwLcB2NfgBgRtTPu+dmw5
fKQpJRe9L2rR+1KZRcyoY28USSbLdzK3PLi6k9l8D1b+P9gNa7HOqnwXpLwfqxzv
td+vulEIgS2xVuO/DD2BzZcvEERFCueZyQU1K07+TCkQtDg6exQ1cZXoVErzyOfB
IgMEBdRK1/VRKVwOFFSLZukGx1zLe8HgVoQ2XUtUtt4/1/dT5dki5S05J/dl73fT
GIOOtiCWW5Kz1XPo29cEVLu1gpcE2ZozgBayxvqcfalO/J9nAQCs+ogA/ArOqZE1
uwi2aXKUSRWixs3L36ZUSI55JepYgr5/b5pYI7t08bj3huAAM4YFw813yvV+7naz
XF4JKnuJQr2SevJ9VT9cGwjo+t0D4AH5vqcm28SYiNDGV/BJnc2EV3HWzc59t/S+
dFZ3rvL5vwLQ70FnqjovAcAPANha4Udz/tvZqfn2xYiaHNR6bW7rBknGdWapZBfY
iJhDZ0uVK23tJMvlJI/gb0yZ/UJ/SpLLk8E1zkl9z421EpoAf300e4u8fE1MnfS+
IQii7rF0MAaT49ybK0s+W9tFE+/IFdPCWK2sXNbZFs9Sr3Eq0Szrq+qi93Xl0DRf
lyacFFzjGfW8S5UdqRsBC6o0AmuOralu/LXzGQAMAPy0HdWzB5eyFq8aD7Vv2eWU
Jf0xcR7vN6dLto0nPWO3mp5S/ajd0ac28SOjxAiqR7bkDm8YszVeUM07yHqhl41l
Czd8SZtR5RZocVM2DD7mkpvQVRFcbe25L3G5BXCTvqwEXzNe+3Rsmc9s1bVFMhiV
3t/kgSjR+7IL4HCOs4qQW3Hw7Ma3I7PbVtdldj6GkgcAaGV55VItldaZ7Qok77Rn
aGNht6JlSlVNBl1kiNJjdQ6kzEllGDadScFHpx69r46WSLlDUvO06dUEMi31o1S+
6PS+zah9gZBM+tWm902ORBW9r+X5VIfVs0qnue5J/tuf5qQybuV8BQA/AmCDXdlU
C9vVsf5dh1e/SPXpfTuIh1Z+0FcK1QAZkQ7C1MtQn6iXan2t9dWyd2JYeigEzkjz
AlQheImqZLJuXYlcBgPc4oz4tr/UwEZXbJ1dOq7+uwSP1Evf5aD8EjhLHrIkN1L+
1+TVuMpAHBu9b/EFRO5bZL6XrNqc1gK2ql7fxm4R4pVrQ++rezmo8Z2tYRSQr/y7
/L7p32xIdeQvn48AYArAj7dUeWNW/G3Lmqi18q8yKJvnotT0S5J9f6gupz0xwPVj
/fX1zjj8rrY2vlXTEFX1aoHPCatjJ58SqiGomUN+SLWsx4C5V9ltnrnMu8kD6Jpz
lJ0yQJcDXSjNwutArXzlVcBaVEpau3ShlvtCuVfPvtchIYW6rv2wtbAUMf84J2GA
5fMNAPwQgPVrT/n7BTzn1glVH0eSaEMkYZJ9mMNfxl6XCKVCaXvFZo2ugbKLXhNG
9QfJDva7zr/5yFQsbkBuaf1XEKCw1qGOyl4QrvOeFQCnDpVzJ4La9V0NXVdVn5R1
3dxqRYZ7ak2BejW1r0rvGxD2Amm0Pj64IBrf1RDjiaqlPUlbMKvFPLji/QirkrRa
XmnfJ9enunJVEuVXCwD0ALzZZ9l2dYGablB9md1WyRYx7sZQiFwCvCZFpsVDR129
Z+A6E7t2KLCTHtnDBuTqkRsECJu4/DnMe0Pq/rEF6Ojf7z6fdkplNz1zg+RVqsOQ
ZjAHBt9tVjwMzbw5eQybdcuvcWtrZYnM91Dr51sVHJNNBoSDN3K9XypfmOsBjGby
s4Lel20nkDuQI0aIzErvC4yHU9R3mLnVaqa68r8AGJ0vAOAHYYv9w126xGPDZ+EX
1lYxqvfOdh2qap+mVEvZWr1HVZzJ/SW5x4HK6oGcnAvN4vqhdoL//eyxQnZR3+Z8
7yFKoMrq7ID4hqpWI7Yrf/iyYuoAZ9t6koXzvSrWSa1OZ+kJZAKiJgpCsc5Jnze1
OaEZqQ9Z7hW3beiV3b9QkBLu+crpfckZzWs4ZP3VJBsE6Ybe19xr90UIk4nNZXCn
mmoDk/zBFASc8wBAwBL7r6xZJj1HqaMoOtz0vuVe2NASirkmvW81PWX2c+qfiUWA
lpSKAHLd7moqy/x786oFLjjCyNiEGu9Xe68N5Uiu9yvR6jor5pX3ylKhpBE3pRoK
r9qV5xI0ZXrf4rtEgOdBOhK8WCn5IlLPjr1kUPUsSJmeZ3J5BRpQOStrWtklQaVy
LrHEhZxl6b1T0mCOoyqB77TipZGAbqk8aJPkRwVjJGvvRJZunvbmWmx5P5PeV6r0
vixayk/bnCqYPPP7Lx3Hqi69r0rlrBNRCUbAOera+leNpTCz1ZsHkbzfjyPJBRgf
qcsqAYDXA9jsX4zwHtntKwGUDG9S3ISkV7dndmPkEmbW8hARpEBYKXOSJD20nlSB
wNnjN6kxB6OQjlP7gXJXMtV6v3AruIyfyJLBG/J+5efqhEwwCIy915JC4vii9nub
qk5SEesntlv+VkCsfDLK9RBp5pZeGpaKX9bLopjNdbUBzRDrxhHjJYf/IChrsb5V
5aL3lYoVXJ3w5wgBkZ3QFg2J4uz3T6dyLj3XsidkIbuRKFzkrJRxEsgwNtq09JWG
RNb9h+xZNxX86KemjnzJ6H31xmvFnTJBlFrS2oTXgCvOCTvXosoMNatlmQDBvFkA
r5fAb5/rAODf10OW5UtWg1w20FKJLU132OowJBjUqyFWIpfEhB39E1d4E6gCgVfN
hQJX3u4uy8IDZazTDj1zgxk615jCxa3d4qbwfQ2aNVsBK9uvvgY5fRFgd7DHEeAg
B3Rml8u5ackjNdm9wE/XBZ3u1s3V3fMs8yDfHenGivTvOCo8VeWYOldIy26ofUPp
iKvNkFpWgvqeBGf83d3WuU4pYR1Tk4OlHHtOuvZ5YoDlvyc6twHAK9CI87+tIPE/
Qe3qJyvaC6uuOapg4y5bRISqZqcUKpCs3aQCIuoBXNbkSCLy02dRJ7vjp9MIyRig
Gp+tgxMVu4Wbc9wr9rfRfrScmU02i4Dc8DjHiVyt2tjyebtrjS3Nq7rxgriVcpVS
IYSCLqdV65XnbmDdddS4uQyoD7h4zLOu98kqA4o8lrN5JgsQSyXZ6qtMqTpDTYm/
6rb31kVrKdJZwMJ9YH4FgD87VwHAT4cu3+oWA1YRj5polktXilscgvA52uOSnawA
uXEuuTRzF9/r9K6HrHGT54asPVms825gKusX2hFvdqYxNi6AYzYbN7GHvx8GSOwu
a9qaelVE3WoeM9udNOlu9bpqouY3ksckn7iOd8XKpOmivyKMT5pyx/KtxfkKireI
mu/Gna9F6Dfop1mFbQSAf/pcBQBPB/GN1VvNY6T31eMypiHHGrUvubeN9GtbhKZ9
6FLCzC9Q3X1FjBKgXHuxEss13IPMAVZRQM2VQvGrxRyVaL86AWKX1VsDynC11ccG
K52d3rf8foKL1rfELiVGlnPk6O5XQj91SufYSe+rWkLM+jqTxdpncliJrCs7ZOen
9Da2WDYZZzM7B2xJy7ffWubqM5B1uM7fkXxPJoPSOrCsiki7nzZefzJEAOWeHfd+
aj4+JuvuUx09lO+n0cIXrADXzKOTPj2zbi30vjY+O2nuPBc5BWZnQ2Kq0e2QLeAY
1hVRqw3YAczJ605hB+ix0XJna4Wcdpms7AEUaNUHbCT5VDmV14sJJpmzerdVqmjS
KMANoAzcCKKnA/jH8QCA8RXc/1TVwq4etS+X0GGRG0sWR5xNObDFtRaWUCRd+C8r
DmcqZ4JYFEjrOKQx5fySkADASgataWFRt/vBfou57vvlQsZZr17VKpVRXbjW1AJQ
PBrky/4P+BZ2nA1FU7CDQdBN79sg5yFQXmatEKjykWTp8VDxZZSdS1kGSZRURFBg
xLVKWmSYi1sKLDvRl/pQob0eldaKSnRkrMEJS/8Ry5ypFbmOe87d5GiZk/WFTzPj
UYB8+KUzH0VVWbR7LapyIai81epP/RSAO8YDAMbTDvMKkLwda2JUuVZdySKyAqbU
cfmz3zKQQhOEbkekrDrdfi3paWBFziyybs4HAcEZFM2ezy2ebVr/XcY/WN9rp+Il
eMMfDaQrcxWoYYTT+9ZMDuQ6JnLNnSMPXCRSElebEEr7SW2ooQ5JotXS/2xWPx0e
huEq+cLjSPir90kmKqz2YJBdDQiZbKV/iuFS6xzWVf4utGHvr0jwM7d43v12AFcA
uKd7ADCe8aa1ofDZaikmiX8iQMpwa3rfqsNup9+01TuPr8cAqRZDF0DZYwXjrDR0
rqO8TI8HdXYWhXQp/lRgpBpGEneQPe+xQ9jXUY0q1qOuku7SmxIgkDWq3Pq75afK
7dLyV+USaeyFVOk51el968uXppa/fYMrP8l1dbCtLNUOHkp7whbDJUdXVWRBrsqL
ejLD9ROSakhxLlGyvgnAG8YAADoXxusBvHYcV76tIKlXktLcmuTW79A++a+UCEXj
3Y2qfl9tvi/s2dxw5zs8jeSbm80az5S/DlK64blgjBtosdVyGbPip26fy2Nbm6Zr
wWOUL6tg7ectkQuvZu6VIZFwUbCEEAyWEmAGEQX2f7Wd7bbeOh77qeCSFRp+2JXd
fi2AHwVwolsA0H0OwHcg6fxXFoE0zkMbxu9vR/l14r8evEwdZOhTKL2vx9ogW60w
OQmB266+zXlAFo4+rnn+JdnfT1iTwkItxSpmicB1dubJyQpLqni+JHLYd/byMyI7
MRSzmjCWBp2Y/fekNM8a9L5krqarioFqWJZca50paO3rna1Uf7VW/FxLpsogpOOV
L6tN7+utDGX0AEiMwASsrEicPnMGK3EMsMR0FGF6Zgr9QR8CSfNMzomwmiYaK3ea
2DDmV9fb6NYkRVozV5J2UMpmqY2pRLfSW9a6B+CHrAeYQqy69iCA7R1X9Dlo9L4e
qzunp6MKqV+m39QzYSlA6adzaEHvy8Qaw1jZoeUgFbEFNivm7KX3JVYi6SrLXfVu
M3mufgqOpGo3s+simexcUnmGJeGyFpWz+fti/9yxvCJjXToqOPIyQRag9Dz55VeW
/y3BCr0vs2evawlF1UPhEGzEWoWLlmpCvjPHFq3rkBkUEIQjX7gsXBa1kkKO+2eX
ARX3r9RUSc8lUX0B3cX4q9fNVqWS7XlMDNkXmBeMEwcP4sjpY9i4fgOu3bEdG/p9
nDxxCpL62H/yFO59+CFcsXcv+ps34Mip45hGlIpZMrJH6+QLENzUjFXAvDvl7zob
he5hvTiGPOeTNHPnh4ixpgHACwHsrcLqvkIcarX8sf4UUosMScvVLBVOkesyiPCD
kpX7mfS+qnVXSUZSRe9L4fPIS4Ggd/ljm8fBeDaFAQGbgCatGE1q5YYGH6h/Jbyc
LuUmP3oanfo0aSFSMoj067LOUQErtNJJUiiIuXye2ANKOZWkgsv02OQwpvMSsBK9
r+VGNaT31VbEG8dUzhFVPFr7bPpfCxDIlI4544zel6zZkhLeUkafLKIGOKni/hUK
gFIZwNX3z/IOGe2tCoFJk3NdgAFGZXmxCtLTY7LCEpIYM8x4+NAj2DYc4XuuuQ63
PuEKXLlrNzann38cwP7Dx/G+z/0rfveuLyKSp7Awvx4rsUQfEQSTpfy3CZip+vvu
c5HYBzLTe12Wiepek2FGsHkK9jLhhQDe3yEA6HT8SJVaH09nA1XI67W2XHKvVl1w
R7leMBWpdFv4HApxuPkyZHzoDhrQRM2FuNrCYZndkR5aktfUZemmOQ35bBcn0b1q
Np5zS0peTt9PeXWkZkEz/IKLCJBSUSIUMLsmiZANHJ8lFyx59sTFuQDLClq+oqT8
XU+gLm5Z4/vnVrBuxaWnBLLBTJqtprRIty4c10acnUn30OUgmBENIkxFMR6978vY
vWk93vLSl+Opm7eWvmMXJHZtXsCTv+Y2XLxvB/7jB96HkzLG3IbNiJclBPVb7kxd
Br/uQwTuBu0+Vtgq3hJNx65JAHAxgOdVLQiNZamzxRLV7mlDLuXGR9BhiayXRa3C
pWpC1haHlipNFLZCnZB36+rKmaEHGmPhn19daILfbHxTyTzlV6ZcsnytcFBp/GNR
/KyHloipKGdk185YhLQLWJLJuRByA0W902nrjBN0rMJ52avzC+r7ELmTk+97u+b3
z5elwp3POHTtWA/pkDofxhxiHD28H3u2LuD/u+Pr8OT169OfixEjBkMihgSzRD+O
EPVm8NpLL8XMi16K7373n2LT9CZwNI2hjB1VqU1peldnhNb5Z17gEm0RydQDlvo3
1Q6fevjueamufXCtAYDvObtbUCwcN9o9DumogtUvY6OxfDT8gTWIeLr+dvb0+/ag
7WriJB7j1S/AYDmgQGCy9W/ziBDO0gLJoIlIk4qoInFtDPS+duFm8Pv61t2JQ2iM
Z7mGCd+oUoXrJHd7sRg5f4DH8L7hd4K4CIgyASOWECJCbxDhCw9+GVdumMe7XvGN
uKw/SJ8uMQJBol/4RAgY9VZAfAaCZ/ANF+/DPTc/E7/9mbuwfe88RNodkUq8/+fz
UNC+6vN3b8v3APh3awkAEIDX2Sy08dzkUGFGlYicSaTnK0VgXlIUPSJjJflhS/s8
Np/RQpO7hAep9pvQywAbWTx1PsmaEspzJi1871UWDHkVehduv5bvS+xV22S9A03n
TmXnhbkywXqdAqw9UqwQ20fZq6DI67o0Yt0cXslhaxOTeVeo8j0t7X2YxgQw3ApV
5Rst5eQonHblc8WGp6d8+KhRe9smwLjwnsXMmB4MEMUr+NyXv4hbL9qFt73kzlz5
F58WiABEmceOM7WzDMgYED38xDNvxqfuvRsfefQ+7LzkSkytLIHiGBKyXhfWs2Dl
+4JL4QwMspCLahibne/7OgBv7mIxem07eqUzfSmAbepSMFUzJrfbBqUtpJJoo1HO
MAWpGy4tuu+7Wfkuk2goUf7MadEdq7aBhxOQ6ygiNooBuCRMAECmiYiCVZ5xyxeW
SLzDdkZltJOmm5ZVi9fkxQ5/PRYu969AFkdmogaCQbVGXZUVRtY1+UmKybWXRuZ0
KVkyV7gCIFZgsyiOpIPRj1klumcNfJITBJR/z9Iv6rQwPjn6BlDaZlv1Gmn0vuwF
OTp6LBIpCVnCH2uSigKhAqfgtAQJ2ILXa+ICMxtflQM6/33yJRm9L5U8bLLUiUMn
DyrCPDn4YepEftb1jCV8hgJEwAAjPPzAvbhi/Tx+/2WvwJ7+AENF8REIkXqG8iMs
ABoAEWFpxJjuEX7+BU/Di9/7fjy+cga7CCDEecMyU/aeFeXP/pNsXntB7DnnavIr
6wypeXWayM8YlUX3NgAvBfB/14oH4I2q0zOAfLTTqHNx2c2e5uNDgi6HHzMlikuu
Bmp10/sK5RqGZbUn5Wd1beYqquOm8YFwRyyhWUJfDapj8nPHC8/M2TtLVaTIoH48
zIEekXHQ+1YuV2iXA5thaZLfcwNflLrSQgMBbiVuREmoO+pgE5ZTjUVlT17J+Oh9
q28dC4YUEoPREPc89ACu27MT//POl2NPL8IQRWYOaYaYElyhzEOZlLqKKNmta3dd
im+/7Rl4y9/8PU6sW4d1GzejJwZAHI+JP6aJzO/KyxgCa5QmS+zSuWsDAOwE6I5O
5EeDw6v3UBdwVb13pW6C3o/rNzptdZ6sOqvGd4/zho1FUPlil651H0/xNwXOmYMY
7Gx95wJdoNYeAx3T+3KX9yg85EKNmyK3wnatlH89BR0OxAjU4uyG0Puyd4okgbmI
8fDhx3DzxXvw2y+/EzsScgsg9diRI0iUsAECkjPIKxApH/3O667HP3/+0/iXQwcg
Ni+AuRdmZJwXwxbf8ZWN445E92L/2QYAr1McmqsEAlwOreYta7tB+5n7hsby/doz
u+Za5y7iiKv4XOfnfXXMNfaFuPFZ5sbWQ13QyAEzCeNxqA59oSJ5rSXg7TTRq4Ys
4npnjlufz/afpDHeKc7zOfQ1YjAQESBX8MBDD+LJl1yM333JS7ERBIwS26sXsO4S
BSe+TBVQ5jfeIQg/96IX4bV//Ds4fvoINq3bBWIBSfFZV8vdyGaVHi3k6TIPBXh0
7y+1AgCy/V37ttXcDqZQGXYW6H3J8Z1johd10/vK1ofets42et+67yfJLq6pFu2n
T7WKxgqWRXtuAEnuBDAuvTMcDUkopfdlw+XvO9O2PAURtJrSIrSa0fuGeSuY2qjs
emfL7e2uA8u6oPelevKl9XLUg51WOu80hyomiUgAEit46ODDuPXKS/H2F7wwUf5D
JNXRQldw2htT+ZSU6NlkchKv37wdL3/as/Grf/+P2DC7Fwlh8OoBgHpE1bDTT6vs
scpf6uczlIrbK7O+rTUAaGmO34KkTWGQPTIWFEZKFV+WFMdcrs+uusAWqVSL3pcY
AHd1e5U5sJYgwiVfRyC9b4DV4Kf3lRZ633pOABe9L6t8jazxJjpAXS17KehEqsqf
jdyKKovLSEu1HyuNdNChXHPsUHABJEBAKtz+rjPNtdbCu4qePfHT+ypP5IorRjbS
JIuS1qi43R4D6Yrw2Lwb5OvWTkH3z34uPPfPsm45qCCVS6RtfN+mxnzvZzJvpmyF
6U+tECCnIswIxv2fuwsvvOxyvP32F2MOQJ7xlyWupcmMrLVSJ612SuTqj8u18BwD
iPCmG2/DJ/efxL9+dQnbFzYCYhl6Xsf4lT872MLdyt9fD6Rx+5P3KBvP8J6FKwC+
BcAnmgOAduN1Zdy3uu6ZMlGuyxIJ68RsTdSgMr2vLs0snO9B6K7u+0qF3pe0cqiy
pHNRvlJLdxdrBDeh7xf2bKnRp1Yj43A3VZ0zJYktq0a138+VqupPmsyMA1nkwrPr
TMsG70gBK8j2vSZbHY/vzJH33qrO0LD03bAiUQkgHLLZGjXZSYa41vmUFukETblq
gDOvpeE0QbyL3JmQ97MbrwzCEMBynxHREAfuewh3XHwp3v51dybKf2TTHkKDl+b/
q6dC5KTYadqgAMA9MIA5AD//7Ofidf/rL3Hg5BFs2TINlqzchdXTL24bnC13kSxn
tLzbMojOKThP53UAnxUAEAH4hirh1y0oSMUnlbOsRXaROMQqt8xOa8ij2Gdkp/fN
LEZis1BbWt5c1t1UqzeCTbFRmn5WEmahv9XeL8A1TK7GtZb3I+XvOKzZT3lnZQlY
sCbADKFMHFi2GJ7lz8Qpraqe25+Vl1KgN4DJfpXNcDORTcnA4/Xwua6rILinZzkZ
OfeUWf0GtGculzJpZ8C0eNXmBCIvCGGyeEuoIPESbCoVG8GQPXFBVpw5YjsMqRL5
5fuXySFLspbVw0BWUyk5W7IENCUV8qUZxW/I+yl+UirObiZj5RQBo0Ucvvth3HnJ
5fivd96OKSSGOpUIPqi096S9mb4i5ZJORkwiyyXEjbMDfN/Tr8Ob//bD2MA7IFhA
yiGEiMav9MnuM8m8TPr5NIG4vyJKWuSnXY4H7/k3APh+NIyT9Frk3tzOhM2rb/mz
RaylDRaYoFKHcgckEtX0vs2tzfA5sNcK1a002Wge/pXiVh4e7uATTjcrt90Dj0We
0XBSXR+X3fa3UoCWTH8GibTG3/Q9ZtrT2yWNalkT5beXpbVluHgFvJvgvSHlPFly
e85KsSkqfBOGMVA/3dMfe1XVGAXHaf1nRa6CzAh9tlZrouC8SAj0MMLhex/A1191
HX7pRc9NlL9UQq0Bz6fgk0r5uoj0UL7+2kvw51/cjA/dexeuvPJqyDMSUdTzewHI
4eWtIGDxl+tWrWa4v4lqNuEKkF2bAdwO4C9W2wPwGpyNQf4FoYaKvv2kznKZCvHY
p8AlG5KCPuV8Hmfl32SxTMznC9SjLiUNHpFrliVvr7BwFzTZX7sy47QbHJG70p1V
amqbx0Ehl0mABWnUOUSm5ySkAp00h23eZc5iyJKhiOsCOy2XBDLvglieq1vJ8Cre
uepvojF+9+qaV5IZ1O/h9PAMjn3lYbz62uvxy3c8B1NIvP7RWGRJ8aZ5h0cJCAH8
+HOejg+9+xGcHC1jx/pNOHPmTDITJyLlVd+jbk8aNfgZ+RoQryoAmANw52qoGW1T
zQ6uVdZwg0PQrGFfqDJqAnYUitVSwpQKeKij5is1QYfCUsYQAEXJrDhWvlKWpiAi
ASEE4ngIlgnlZ8a4lyg0VoQ8Fe1/FV86KWuk6gpKFXlhQJMSnbDla5gOPwNsVBr/
nOtqbTquLaHgUhaHoMv+nPOs5dHXBEBQIUUtXyLz7BHOHZiSJYgomRqp4QoCBEGk
TGhFW1MDp5HR5ta0wqm4mYLTZ5AEKE5+6YSxAddOd09YgQhbyKqoWrWzB0w6bxTp
qszWHsz6TcxWzNPc7V99oKwBJEr8HIM+YXHlJA488gi+44Yb8MvPewYiAKMR0OsB
I8FG6ZiPa6L8Ocrvcvn9IuVHYyERrcS4detW/NSLXoaf/fO/RH/bALNRH5AjD920
7+8p+Ce8EtRJP202Sqr75MadYu8EeA7A6doAoGGuycsBzJhHrLGL2JuVa9WJhkON
NYXEbZQ/ypm+WvqOQe/LpaznliRAhp+YlKShjBZSZN2jQo4yjyNzNonXiozBjpKe
ChJ9ME8BHIGEBGgI4lh5r1RRCoIQBCEYSytLGC2dQa9HoEiAJGOIrJwuOx9ZylAS
5olAEHFiIkT9CIIIEMW+yXQphCRETCDEiAGMiNIEP5lQJGc9IPIVFobHQQEJTB7l
z7npXiRxmX0ZJYgE9OKncilQ4V41hAKnLCpKNrRaXSEYiGQCXCRJxMg850pyEvfA
JFJgkoCEEUuMRkPELEGC8zCalCNgxBAgkIgQiRRcjCSkTOLhQlCqvwj9XoRe1C+C
w6mCl4IhqagpiKRAxAKRlJAkMOqNtLtMpU6MSitxJf8gdwOTBDj5N8Fslfl13LYF
va9+pxKnECmAsgCgZLHiSKFFVonAtbwW1iVot/S+doVsq8hhYsQgoAdwfAYn7r8f
33njTfhPz3sGAGDEQC8NS0WQWudVvYqDrH4lk1lAVO2ISJlMUxz+YxddhM9cchX+
30MP4cpduxCNEipwNg2RSmNFt/Ak27WF6gDUOswTW/ca1rg+W85QsQfEzTSmPSEY
M2DxcgD/e7U8AK8KsdvHP8wDLzt7WlkwoAa9b/erQalyoFrQcow7QpnxwhA8Apgx
iBIpHccRpKBEYEcJhBmNRlhZWcLp5RUsDyVkHIMiRr8HzESUXPilJfSEQBRFALMi
YhKrnFIzezgCICJIJpw8dhqjYYylHjCaIkz1+ugPphEN+piNgI0rKxAYYaVPiAVB
psT3EUWKokqVKzOy/GQKdgCzBgS0RNRQRt46J1QJ2ObKmoAhAcMIINFLrDk5BKRI
+0EAJARWmLC4vILh8jJ4ZYSVYWJJTU8NAJaI+gKDwTSEjNEbpT8HQiQA6qXegziV
0MwYxhLUixBLxtHFE1iOR6CIMBP1MJiextI8gEGEaUSYjgExSlpqxyLCMEr6OCTe
hJG7FMq5/KoHwO71ExkYpLAD7cocyv9d5WVPXSEU4M7V/S1uI4jGxprpp2gWzIgE
4/Ezx3Dq6CH82LOegTff8pQc1PbyhGNuIy5qFfIl4Erk+PxXnnsb7v6T43j45FHs
mJ9Gf9TE7GQ0or9mpGG1MAueVXBiPUeVBD9NtNSrVgsArAfwvO5UTVdNHnisP10v
WXI8ilekdeGrATgq7H9AAhQRYtGD6E2hRxFOHT6O/mgFvaiH0fISVkbLOB0vI44l
ZufmsGVhDjdtncGmaQkixmBqCutmprFpYR7rZ2YQr6xg3Vwf8zMReCRLTpFIEFZi
4OAJiWgQYWU5xmP7D+LUyVM4OSAcjCIcPTHEyWMncfLofiwtreBQvAAhIozmCNG6
KWC6j2khIEZDyJEEKApoUkUVWQ2mH8yXNMgl2yjoJOYfLTjuRdokh6LERBvREKeW
T2E0GqHXG2AUM0aLixhKicXlZeyWS7hqboANGzdi/ex69GiI2cEAO7ZuBcdDzEzP
YMP69ZCjGOumBOamBFgmSYm5I0ICUUQYDRlHTgwR9fs4M1zGQwf249ipkxgJwpnF
ZRw+fgx3L/Vx8ASwdOYMZiOB2ekZ0PQsRv0eWESIAPQ4QkQEkSYxM9xdAsnmaPMA
NDa8hhyQxOjvrFwn70DUkkvtrH8OlkVcNinBA8JILmJ08BC+/6m34s03J8pfxoCI
2JJ012yu1PSHYuCi6T5+6Nbr8Ma/eR9GG/eApEBfNqWP6jp3xFNh0+lee8fzQHI9
gBPjBgAvBjDd/jh01cI1vQDUkvGv0w2jLs5ReZZMliRHh7Lp8JCRkuyVxIgFRiPG
6dMrWJESIzCGK8tYQIRBvIINA4k9ezZj++6t2DA1xBRLzG3YiN3bN+GadYT1zm+a
CZvQDuX3V+3LfzsEcATAqaMncOzYEew/sYR7Fhdw7wGJ+/c/jAOHjqA/O4tDKys4
E69g7/atmJmawmgYF1Y/qQqfLdactAIvvQpMpdFxWSqWv0+9Ebq1kYCU3FvBESAI
TIQRxRjxCoiXgdMrWDx6BsPFZUwNeljY0Mf6DXPYdPF2zC5MYztW8PSpCNdu2YAN
mzZjqotyqu2ZGJgGrljI/zrGEIdOncBDpyM8eHIZjx4+ivuPn8T+Y0dw8PjDOH5k
CMl99OfmIebWQUZTYNFDRAxiaUnEUWLqmeefDH4ElXDJjMqxXkjRVB4R1/hsDdOG
eHWqAGy5DaIX4djiUZw+cRBvvu1Z+IEnX5+7x0UUwp2idoPsVipqRTASeM0Vl+DD
X9mFd3/1YVy68wqIoYTMQxIoEKoTmNdYtUaYR83S4jHsN/uePQ0WLwbwB+MGAK9s
rGiJm7thNGXXrJWl7rA9u4Mt+QpUsjYtEIVsSWtkN0AqJJBUAlzC/CgRWDIEEUQk
kjhrPMRKzDizvIJDjx/BEAPs2r4e12xawc4ZwpP27MJ12xawa1piemEePdJVep5w
VnIFSv22Z3FgV+o+K1lqoli5PhjbQdi+cT2wcb2ikIATi9ux/8gpPPzIIfzj48fw
odOzeOTx0+gPD2HD7Cymp6chegSiqAj729SQmbSVSifiJD5HIokV57FsYs+BUy+0
sCsjIghKwigsklCIlITl5RUcXTqBx1eOYv2gh4vQw/UbFnD91Rfh6j0bcPE2YGFu
ClMzM5i1uV4lGx340n3Qfs8WwivFuiUTgEaAjBEJgR3rNmPHOuCW7QAu344hgBPD
IU6ePoUHDx7HFx87gC+fXsKnDp/EA8cOohdNY9PcPKb6fQyifrKOMkaGByjfAYOk
KFtf6ce+Japbb76Q9bZ4/ULaCpE0KJqoI4FTg96XKvxVLCGiCMcXl3DywOP4gWfd
gu+/6fpCfJB5PlepwZkBpGMAMiKAJfoQ+I/PfAE++sd/iJOnT2PLzFySk0I9EMUg
GVcrT1Wzu8oJNT3lBxC2tvDNYA47QwpWL6FR6ZPSKr1y3ABgFknNYQOFJ62/D0NE
HgrYTImVUrDte6a6EMPoGMej/O30olXKv86ZCiOsyZJVJCdJc5QKMMGMaGYGZ0bA
0TPLWBkRBiPCHIbYFJ3Bc564CTdfvg2X7dyEyzb3sVD6hli5Z5xbbZE6P0o/pzLk
5G5uKu8jWS6pVs/HgIzBkkCil/xdDER9wsaZHjbu3oBrdm/A7QC+A8An7n4cXz5w
GB994FE8eOIATkbbMJhewKaZAQYiRk+uIIpXQIjTgjUBRqQsLxdZ68SFp8RaQshg
jvUrnpf5UR7nSGrbk/cn7gOjCMOlIVYGPSxihJUTRzE6dhA7N0/h6bs34aKFi/CE
Hdtw7c5tuHb9wB5jza6ITOcsONfhukoxOpGVDDvhEFJctNLNPQuMUfrvPQB9AJv7
fWzesBH7NmzEs6/chxUA//zYITx45Cg+c/AoPnTX/TghpyB5BjyzHrPr12PQW8JU
vIIoZsQCGEbJXvRiKujnAS8HlXm369P7GrEEl3tdea4aM2dwB1ZHOO2sSe9rXpsh
SfRmIiyfPIFjjzyCNz/32fjhm24AkCb8kfl9lgtYIv4Zj/eCqOiZIHmIPevW4Tee
/TV47Z//OR7Zeyl2iAgroxVE/R76RnmsW49QheJ3gT4dDEvSaZ81EnMOEtKo5hA1
GAqMfjN6bgbfzomOPjMuAHA7gHVtUSyXFlaY7SNqIl+bRWznVOsyANEe9cHClSXg
oiINT3IU4c36UvUGIZLMfCYQEeLREIsnjuLQkcMgGWP31o244fI9eO5V63DtRsJl
66YVRT/UFUHmmiUqC2ByxL5JGACANWCkf1Yqa2HQj4oIECLPsidhs7AJFwG46Mot
wJVb8KVbL8YXDxzF3927iI995QD2338E87Pz2LxxI6JeL3mfmEFEkEIofgxDoJBD
MaaLwCzz9UjqnUVKM0OQAoiFAJMAcR8RR+iTwChexqnTx3F0/xI2z/TxpJ193Pyk
q/H0y7fjmu2bMRUCnXMi9tjj9C57kjIbWWhWhgkGMgAklfAIpYrfZkEVazYA4Wk7
tuJpO7biVdcAn77hSnx+/xF8+MsH8cn7l/DA/kex8eIedsxPI1pJ1j1CYhWCRBIu
qLjXZbuVS14Ev6/X1XyKDBpuu8zK/p9AHdb016f3zSWIAEZ9wpkzx8GHD+LHvva2
XPkDmfKv6cQfl2MgY95DUo0Sj0YQvT6ed9mleNXVT8T/d+BxrFuYRRzHmJUCIk7u
EVMIdW8VcjG5NHw/wyWW1rB0R67+99wjmip/djOBMrBOArcT8GfBAKCmInxZG8BX
0F7qTmBOG80QyJIdyR6UphUiG2Q4njCDxbi004WOS/1T2lyHtZrYol6ay7SzxIEH
t87uCLAUidu7JzASMZZHKzhy5AT6iyu4dIHxNVcN8LVXbcNNl+3BfH/KsEnilMI3
LUtjUXKzlcvYyV8yTLpCsr+xKK0FWxz2GWQyU3QyxwMYkD3g6sE0rt67E6/cCxx4
ylb87T0P4a++cgKffvgATvfWY37LdkxPE6J4CJJDCI4V6tuym4JIj+tbnc0M9FhC
ABgKYAXAUIwgBrPoLc9g+cQJHDr2IKLBKVyyawO+5arNeNkTr8IVewxfC8sCPAV6
0djar13NZSAFVJGnLt4Ujp5QhkWxSjkCWEJEAwDATRs34qaNG/Haay7DZ/afwgc/
9xX87r334PPHh9i5aTu2DOYxt9SHhMRyTwY25y7uVO45JTUEoNd8sMKk6abXNgvb
Uu9PHr1irSGOSe8rWmWAS4d80/vrqSGA4vcMniKcPHYYKwcO4hde9EK8/qorHZqc
UKu925hAgEjPLTGBaIBhPES/N4X/8Pyvwcff/W588sSjuHjzDgzOABFHiPP18XWn
JMWQyISZCuKlQ8eYHSyg0fvazlG5rDXE84C0fNuXSVLuqSgLHR0OAGrtBfDC9og1
VEkZbn/iajte2hLhCGaSYK2z6uq41gokcEl9udemKqvcRDCBb8aMCD3MTq/DyvIK
jhx8BMdWjkHMCty6cz1eeeXFeNJFC7hkg5rvuZyscabgKEKMvkXRk9NnIWqeGg60
VisbnBi+pmxZxSh7nAREjO3r5vGNT7oWdz4J+Nu7HsKffOI+fHj/IxBT09i2bhrT
gwiCRCposhCA0HfLycpYuO0SFkTKX3JmMABFEvc+9BDEcowrFqbwjKs34fnX3oCb
L96JTaKvPGeU/GJKEwSFFw4WVqowZkIl8SYc/+5yBeu/izxn2PITQqRVLQzwCjCK
E0A6mMJNO9fhpp034qVHrsD//OLd+OA99+Gho0exe2Y71s/OQGAp53sou/4dDX0I
eo8CVyFGoL9Q/RapOWq71oYtsvDzHD0BEcU48NhXMVhcxM+/7KV4/WWXJj68GIii
GnPm1Sz4pgQEECCESMt4JdaTwI8/9cn4uj/7XcRTU4iiLZBECSWWRkIWKKhF83qC
9p4dj4K3ns9yKykFxr4wvcZB7uI6AOBWANs79e2Ein9qm7rXljZ03AGDrlonlfnI
WbFWklL35O9FlHTeevzoY1g8cxzTfAovuWIed9ywD8+9ZDv6qgYfJZeOIwEpUp6z
LE4dyr14dogiqiEtJIAlgEbpJAcA+phGD3c84SLc/oS9ePe9j+PPPnsvvvTQQZye
3oKpjdsxJVbQHx7P2QnZBhyZFEIR0h3PEeFUT2BEhChmrJwa4tCxEfZNzePf3DiL
O2+6CpfNzWmPHGIlZ6fP6qRFMDkrw9VEmpx/R4Gnsk5SL2uinVKLi5FUN5AAMBom
H+sxrt00hV99xpNw101X48+/8iD+4l8exP0HDmPdho1YNz0NkiMIlohTJkkmAlgU
wJqk0axrNe7zeBVifclC4D7hyIlj6J1awk++9MV4/SUX5R+Iog5k5ircbSEIIpVM
DIkX79mH7732Jvz+F/4Vc3s3A4LQJ17dhK5xD66ti7anuvqjXQOAF3fxBmTlD6eA
F2zO8Ty+AsEm95dLkdayN8Dmhqtqq2Fz6yqNkThx0VPUB0HizPIQB48cBskDuOOW
y/D1T7oeT9s0m3vA4lFmz2VZ7z2MREI4k9mcQmGgtzkySs1vMkremjKFWvoc1Q4D
RoQBMWJIjBBBJmREuYEoEwUlCF9/2Va89LKt+LMvPYj/+ZH78JUHTmPjtg2YWt+H
HMVFgxQ2WqEyAUJCskKDyikLYdTD8b7EgRPH0Du+jCvmNuA7br0E3/6kHdg1ZX+L
PkSi6DLa5Y4jy23vT9NG0xJJ7kNy4AgQcZpPEGOEoxigjyfMbsATrr8KL7pkD97x
0X/FH33hXpycnsaOLZuSSgmOQCTScytAiDHqjRATI0qTTIXFgC0cupY2Tbl7pGBz
dEf9C0+d/6ZSy9V3PZ0ccIzRGwgcPHYIpw4dxlvufClee8lexDJdblElW9n/16sC
6svzWMEypjCDn33GC/Gp+w/hS8eOY+vWnYji04g4Dmi4yxXSglvehzoeWc/3hRQt
lD/64mAAEFyTSPySWsfWYrVnVhAZTU5qlb0xBYkcdQ4m4ChRPULP1FWzvN1JF3Xc
cHomsaqEZOqWVtvFWh3o+cLBkueQvS9pgkbIESLEIAmsyB5W4qTRzdEjB9CbifHi
m3fgNddfixu2zKUWJrAyijFFAPUEYkqtzZTWVVCSuEUl27DoRUA2AWpRxHXpVEKs
2lqfpEwpCBBmlKieSBLMKO0xyYyIgCkIvOrqi/HCS3bibz/2z3jrJ76MuxZ3YseO
DZiSjMEoqRHQBI+Q+TpIIdGLgdloClNigHsf+SoePX0ET7p8G175NdfilVfuxvZB
VCFyIkRgcL7cAVI4/4hSjaDtH3kWijWeQ39TIa5wh9oJacopgol3SYIQoY8B+mCM
EHPSgP6a+Tn82gtuwddftxe/8bF/wofv/zy277wcm+Z2IV6eQX84xDSWMIxGGFLS
aIiINEZ+yjrOcFruRjYQm1XEqFkRUQm6F8G5uChmKbhetRJAqs1aZ0HV1jNPJXET
ySSMzH2Bw499FdPHT+JnX3QHXnvJ3uI4lDSMeaVTWmPis2LxV33ZsjyD+cEsfva5
L8Q3v/evMdwaYabXAy8va9UozlwAcvnE7JLH1saaNC9fnQVS8gWYw8IqpMt4T2/R
lxD4J7v0AFwM4IbubAfW1Ijf6m6nfDk8Hd74M7vj/3VPvyVGmXVso2CsWA27SUEQ
EgIs+ogxAA2msbg8xNHjj4NPHsILr9uGb3jmJXjK9vn8Z0ecZKn3I1ISYUirKEwj
bM6kMII/9Eb63WspRKiTTyeqIXKcUSBSGxoxY2F6gDuf8zRceeXl+MkPfwkfuu8u
bN29E7unNyM6M8KIsgQgBVCygCTCqM84efoYjj92CNdPr8OPPP8mvPxpl2OTBviG
SIrm3ArXbBcwHmOM6twera7FaiM7eI9cFjLlHPpJk6DsWCY1EwJP37kTT33FK/HW
T3wSv//pB3D/8Ycws2kvNszNQCwmoYA8PYpM4ayUUJn/phxgm3FEDknFnbsfubEc
ABgsCNQDDh18DFPHTuI/vfwleOllFxc+l1JOpvB8rZ3vfnWH+r0xeogSLn8Gnnvp
LnznLTfibZ/7Z8zv3YSoF0HKbsM9TG1aS1fIdK4xCZIhp+IGgC4G8GBXAOAFXbnO
iaqtiQtjmJnE3Tlrs0znkehDiik8dnQFo2P34vbr5vDKG27A1+zbmnx8OEqK+Hq9
tNdA6olIE9TIY7mdVYNg1Z3bqdhkCRmP0OtN4epdW/HH37IVv/6xL+B3P3kPDg+A
7Ru2geUQ4BhRJBLXPwHTvSkMRxKPPfIgdg8W8S3PuBzf8ORrsW42iWeuDIGon9mX
USpso+5ftYS6yG10ehCaq89blwLXLVEo6zOESAA/csvNuG3flXjbRz6Dv3jsy4h3
7cDm+WnQcKR1SFQoBHUvYMkdRRaHOq9R+eGAtMTgKMbjRw5j6sQJ/MbXvQRfe8nF
BTVHxN26qc/Cu0ec5I8sISEb+/dPvx4ffeCL+JdHHsDOPXuVFkwXrJ55AYB3dAUA
nteZQOWqqGUGy2Ur67+q+YY/T4SDwEzYWWWva49qZLNXuokoafXKTBhEPWB5EQ88
eB+2bpnFj7xkL77xxt1IktzSx/V6uY2V55KSsIhCTuvVvTumK4+1KjdbmGZCCAiR
rNYQhD6Af/vUJ+K2rdvxw//vH3Bf7wz2bNyJaJmwMlwBA5iancLhowcwPHYUL9y3
B2967lXYsyllKUyT+Qf9BHUxmSeiBXMF11AaHK5kCLZUUxXKVpj4efvecDWnMwhQ
oceHiaf2qdsW8NRXPgc//6kv4Dc/+QlMrV/A3LqNEDGhx0kmDCkkPZTzhlGJM4ak
r+vjatH7Nm0vnqyW6PXw+OOPYtNohF9/9dfj6Tu2FRWEkVmyyQ3mdLYVq0gdnRKC
GKNlxmBK4Gee9xx8/Z/9b5xcPoP1/TmwzFpNi5Kc5Rpr3j1VfMPzQFTjVPDzwgBA
dcZkBNDXONUsdWEByvZLREWyW32ByQbLF7eaQ1lwUDdgwuNHYGYIxKD+DIZiDkcP
PQo+cj++9ZY9eN3zn4B9UwNtThJZ1aQyOzabepIBBbhUEub05bBDxqwZQM4NV5tS
CyTN3yDgaZdtxVte+1z87If/Hnc9+gh2b7sI8zMDnDh1Cp+//wAunwe+9zlX4VVP
vgbrACynFiwJBk3L/MkiX3NC+E0nu1h2ADB2fTZgSVzFl5X4oeH+OxsDpwUbHBWS
IwLwk095Ijb3CG/9x3/CKUHYsG4raDmlak7/JxvJG1LauyqgZ5UBLtsoajkJzCVV
Pgz0Be45cBjbhjHe+soX47btWwveqh4rnh2hr6q33KybZkDdroUAScKUZAzjZWA5
wm3bd+AVz342fvczn8KcmIIgAZHG6CWF+TE4AMO2ky2hBqwschSCShpLhubXpNci
rvAAVL7izQBvqWLps3Q2D1ykqkNWHeGUao8AoQg3rpt00xR5mx4HtrSRsb1ru3Ta
5B0lKEpoV2PMYfnMCIeO3oWtvSW88UWX45tvSYk+hkDClal7RjiN7Ask3oOqsESR
hhRgBZzH3jc1RWgZwG0bN+B3X/5C/PKf/BM+9OWvIN61GSdPj/DyK3fj337tE/CE
2eQnllLFMUXAiBgxZFpRQUDt0BhZ05usIIDg/6y+ubVEPvnAhfHc5kJV+a4sJE1A
TAVtSw/AG2+8Fpdt2YyffO/f4NHjj2HXnr2gJQBymCTFpaWCbAtEsk8ykHFvVhuu
KjTDOb0V0IuAnhBYHC1hSCs4deQEdpxawa/deQdu274VUgIiiygRKSmgZJygKkra
tWL9q4I17REw089v5I9f/WR8+t77cPdj+3HZlj0QcYSRSFpmg4yjyP5+nc0ks0+P
BPZTINbohVnpJ2LXq9KGtLckuhsfawsAvtYuBriYGEFjvgpzi0j/AqjZy55nMRm8
yMT6Ma10m0sYrgOP2VI1j/Kckj+T3hBEE8zUiFiDWIBYQNIKRmIFU3MzOHJgEYcf
egjPv6mP7779Kbh+fi6xlpYATMVgZOUxIlVilKf6ZQl+WcdBm7cpSwujkvoRfhmx
5oAAt/95KjYzq9rbGfXx1m94Nn7yd96PP73vAbzxm16I7792i3bi+1wYZBEIUeoi
IS1uEpJBTJUiWrUeOOSzDuvH6+UxLCuueG4ozPaStEZJzhrlJalpiZ+UgIjwgj07
sP4lz8N3/eEHsT86jL1b92K0cgbgOA9lZZ0dyuupVxzlln+a2Z+z6nE9UquuPJy5
fMx+KwS4LzGMRti//1FcGhN+9xtfjmt27Ux+TiT0v05HcZpuScZz1/qgXOxEUBNu
9xDhLbc9H6949+/h+Jlj2DS9OU1qkhpBFxug2NotUjmzYUtTl7LeDfayz0o16S8l
DiOvHmVTd1cBgMrxHJ/QTC5IXPL3SopTpWeL+RtuLB+9b3D3Ky7oF7PLTL4mH1a3
ieXva/T1JlbofdWfSnmc8y5xNZ/r+C4Jwko0CzmYwelDB7Dh5EH86CuuwZ0370Uv
NfqZgP4MwBEp+dkF5xsFC15S7CDO4IJyCMkhYAIUyTk12P9nAn78NS/Aq48t4dpt
c1lGpXayRcmXUC8tNiRQVSfYVGWzNIVUY2DRKNaxhKdjSMEJx4IUeOrFW/FH33Yn
fvgP/xpfOfgVbN2xHTRkRLFAP+WjkCTzMFj5PajkFtaYuUm3GWhs58uULzJv4iVA
OBMvYpmXcfDo47h8BPzOna/ANbt2YJg29QmnXGMFEAHhfPZrBg7kouhpmzbih55y
G37mIx/AzMXziNCHTM+LUMSUpluhk6mWCJeDqOLZ/6HgkvvU40MmVXVmdFt6rJRo
ojnT3b/QBgCsA/A0u02ASkcJe9VBIL0vE3xByqSE0sP+ZIN21sS8KrGqSACyz5kB
ewMbcq0FGe+HemK7l5D0PXL3fly+7hT+4ytvwM2X7kjuQQz0o4S4JxZZhbYoue6F
av2Y+RxOPzAFuwbXUupQ2RXXvRBaXlrB3PRUovzjGMsxYTBQKJ4s8XvWyqxqCrxV
gDsiAP9QB+79Om+nUxgnxEhDSPQobXCyCFy9bR1+8zXPxze99z04dOR+bF3YCYym
ML1CkBGw1EsBLQndc6kod07JnGy8Jt2VX1Yle3L5mxmgSAA9xuOPHcKTojm85aUv
wBN37YBkZD0rW8yOzvrZa2IUQSba+01PuhkfeOAufPrRe3HpxZdBpghAquLbqAix
uf6J6+lu/z6GJNsoFMAeD4GegeVKmMfTUh1+qikAeBqAue4Ekq+vfYhTkL2Ckiq7
O9nyeGV9S9zXUdJ3cbgDwZhZlKKHE8Mhjh85jGftnsJPf901uGxhBsvyJKaESBqs
yB56nLaB1UgkSFH+dd+eGouS84ig06kqp6ankpbEGAEkMNXvoYrngybrGXbXLCGH
zIciIZA1bu71kPS1XQEu2TiH/3znC/DGP/s/eHyph03Tu9Bf6YE4Sj2G0npP3SwI
XWe0hstB1QdHRFjkZex/9FE8dd1WvOMlL8Hu9TPJetQqL1fNlvMgaYckIJO8iF9/
/svwone+DY8cegQ7tl2EeMRWzgcmqyNvjZgq1EAy5GMu1eF/1RQAPNP/ZdJjUTWx
ak2FH2BdUtGJy+kFYApw34YnHboq94oUOsORaJ0+1ZeBRIgBTPUHOHH6DO7b/zBe
/9yr8LPP2o0BgFMMLNMAA5wEYQTQLIh7SR5oTvCTuZup0e64q2up0tZeW+JlDF6A
lJhkRBFGaZlZj5OKAUFuUa+f9rVledHZ/j5bZNBxtihPZJXAlExpnnt4xsat+IXb
X4hvf/9fYInmcNH0LvTkEIJGaQqmx3OlHRPZ8YKEKH/Ok24jOYJkQEzNYkUOcc9j
9+FZ23bjf3ztHdi5fiapSknlIFMdABD6WmsfILBIW4BL4IZ1C3jTc2/HT334fVje
uAM9DBKPDkFpXe13KKi/r/YCeKjbeRwyiCwIufSZZ1YAAO9b3VboULarAU7LT4wg
Wbf0vpy7OZh0glJtKdQyNnY51mz0vib/PgWcCGiuGlOhlvqusfquFOAu0lFtDInl
3gxoZh0OHfgqRgfvxa/feSNefePuZF2GEtN9gQgDSMwlojDzYQlRuLPIZAoXHsBh
x6OVyp/cUG5tAYAuQACVgSABPUSlRDw/40P9eGvLLJJmot6Dy6mFd4KqXtKyROZU
pvPfJyQxCcejBJjwst2X4Oef+QL85F/+HVZ2rMdgagYrKzK5Gxk44ySZWaM/5qJM
k/PGot30gPO5/lnJAs9unmCJGfSwNGTcf+QI7th1Gf7Hi27H1sjM56muwAoL4q3p
TN6Ae0344Wtuwefv248/fvCreML2nYh7wLJg9FivZXJFiHNdQiGJgEqs3swy9Big
thA2sa3FvVn3I0Ms09t8M/Z5AOYA3FJ1pSmfUsZqH4J0mxD8sB81qzukpuqWFHiI
FyDw8pZkv8IBzm47pe6QRFgSEYb9AZaOHcOpww/ix172BLz6xqSjF8fLYGL0OELE
BCmmCtFBZIAUrhRD1F5sn0s+w84fF0FPHmolRs/Raktaxe/JlqhvIIcCLyRkMG+4
6go8/PAxvPOz/4J9V1wG0Y8g46KPRd4imDPRagsbcqOb4lf+DhCgfZPEIIpAcYxH
Dz2Gp160F79zx7OwRZTFkduvwEAFCfu5f8dFuloxeMiI+j28+enPw2cO/l8sLZ0G
rZ+FACGSQquQIPaLee5ie1276wiHE2x0cbUpom9JdfnpugDgKQDmQ90VTCEtlas7
WbVxmDFxICtTHU6vehKObAElFo1LbAgMSX1E0/M4vv9RrFt8DP/xm27Gyy7diliO
EGGUs/dxxnoGleeUPHOmhi8u7RbrBc++iTq8juc+xlpDJeHskRhJkl8iG376uTfj
3tOH8PGDD2PP1oshhEDM0rCs2ConwqzApgvJHjmX3OPRcITDyyexb+8W/Mbzno4t
InFQkMURxY2MMPgbRZ0Dty+vsSIBTrXbVRvn8KanXIcf+If3YcP8LmzEOrBMmp1l
fpaqwNvYiE0rljjRq6EXzfq5+VSX/11dAPDUMg51Kz3iAO5yK71v2/aYCvaTokJp
seI64bFtmrXssSFdpJSM2dlpHH38BBaOP4b/8prrcevFW4rvYUrKC0mthyWYveIK
z7/Q3qOZy1b4vW+TcWEMsdanQpCIIFO664x2+Wdf8Ey88Dd+D/txDHt3bsdw8TSE
iBK6YFYFPkOtVhKyq9myV/mX3oIAQoQDx45gw8ZZ/Orzn4N9aedICujYq19PnweD
tKDqOX2VSZ//N193Lf7gnn/CJx55ENt3X4vl1PrPoqK5SaM2K1O971xUBTjVTFDr
dpuy9um0Osaq8OlyOwBgB6Qlpqd2iWqbKFkupbI2pfcNQ78ur4ItSkDN/D71bH8C
aGqAQw8/Cn7sQbz1u27Olf8QQF9EWeASajIPWxjiJmMyLlSfDAEgyXmw98qZebzh
9hfgFz72ZWwbjdDr9RDLgn5FjsUDYw+0saNltvaTqdIZyhFesmcvbh5M55+NjZCT
Sw5TcOMxWqNJu23GCEQ9/OrXvhyvfOfb8dWTj2PD5j3geCkhCMr0DZcZLLnSXq2p
S6BSeHGNM9NAvxT5ck919cXpuY16vqVLZGvHpj56X9nBKQyZg0+dp/SbVL6cVCOK
Fg5YOPfpMQgDMY3HT8aITzyO//ya6/G0K3Zq3yKTdCdniioFei8mYGEyzm8nBSE3
4VkCJPAD11+Bf3zkIL746EFcsnkXTsXLWOklLZ9FlVTtRA4pfG9UcR8JOL20iF3r
N+LfXPPE9EPLOE09ECLMOmfJ+bdUNxA+n+UAA1jG1Ru24See/WK84cN/jnhhAbNT
EXrpkRBQvAAeFcVBq2ZzyWSeJFmiiYOX3rfpG2uU77e43BIuAHA1E+9S6X2psotf
xaRr0/sWP6cz+omAXgsd0/sqVMcMW5tc4yCYzIYcQO1KDCAGiDESQIQIS0dPg5YY
v/z6W/Hci9cBCi9UD2pWv0IoRHBS+aLzYzYZk3GuOAIyCuwExk8D+JknXYbXP/Qw
4hPL6EWEMz1GRBY7Jr+fXSn/VESTaqnpMoU0mkHCysoIGwd9XLQwD0BiBctYBqGf
VpvYnk+aEiC3hwEV1UDnvPrvI6t8+JYbn4wPP3Yvfm//F7Dn0muAxSjJF0jpVaQj
l83uKOeyzsnDvWoXNNYaOUlDP5S/TzrOT0ijMLWOJR+7AFwN4IslAMBkVQFP5twZ
JpTDmmW4h02kvFhhhUuslAtKknoOJBW0s/aEPxngQhH15pC70YrIYDavMrFEtm6k
W/Ya64TlIEkAkcCwLxHxNJaOreDwsYP4pVdcjeddvC73ipDSM07loy9pfK62+D2J
r5NQ/mScpyAgsXmkjPGknTtw5+X78Mefvhfze3cXd1wLALdJ/3KHHgv5IhTTQjU+
dDFKJCBljKXhCOsGERiMxP73Ma6q9L5F+yO1zPFCueestH7+kee+EP/wp3fjzIEj
WLewC5JHSoUU5VrPth+F3jFL2hX6+hwQsMZBw6n+qk/va9Z3uI1X6TCkGXiyHQDY
1+vJ5WPFjg72XKFsXcDJnwBRSe9r85054/wudz8FXWF3xqxZD+xjKvSrVSEERjFj
BRIQIxw68jh+4PbL8LLrtiiuPAp+Xth7defknIzJWNvKX//j6eEK5qdm8Lqbn4i/
vudunMApTMk5yFiCIjGmvn/skCFcYUsxBCRGU30s95Nixz76AQpcNeKydt6kKUVv
cvd5tPWqtnni1Dx+6taX4yf+9H2YvpQR9xgrYCCixMhKq6rA9YFd+TM6wQA7y7DN
3eTaJhr7DNkEAPx+CQCQdUL0pPDtl4bVzzW2pC29Lwwr25xTgJozoXbjObS5NsmG
RmKASPbx5Qe/hNc8dQ++99Zd6b8P00ss3Ob9RGtPxmQEj8FgCqcxwr6FdXjhLZfi
f33hPvQxo6TVW/jY2UZ4JS0GRp38IPbXeKeG0NQgwoHTJ/HA8ePYvWEBgiQGLhY/
hre2PBsRkDInXnhGwGsufSI+fs1BvPeL/4LLr7oIh0dDDCO1+Y7eeY+9faOrWGMp
UJfYKzNCPi9JP6aWk/Qk2xN6xKXYzxQT31CdKGcreWhvV9bjpGc/IGnpLVSbjdj7
hKk1syFNTsvumWT9CcwEmpnCfQ8/jFt29PFzX3tV8jmWSQyr4wLkdowMkzEZ5/bo
E4GwAoDw4muuwXu+cA9O8hALs3PAcBlEVE4hqgHm3TeLa/oUkucNpqaw/+BX8Y//
+gU8/elPBzAFgah8adW8oJKr2Cg9Y1YagJFTup9PXqC8/UMP+NHnPQefeewxnDxw
GNG2DVjGCAJAJMt5AG4qYLdFX1+r1WEnVSpJVHufnOfrBgBTAJY1AGDZ4uuIeSFD
LkVpBLndHGR5SbarSl1RU/7zhXNEzTPIzjPn9TKs0CtqC822MpsANEVs/zNBi9OU
rglbOrKr7fRK5A1UQmiUttXt0QDLw9N49O5/xo0LMd72Dc/FjOhBgtMGPhkmlZ2Q
dFDH/ovJmIxzbUiMkHTWiHHjzCa8ZOc1eOdXHgDNz+R52kSGYNZks1uRMxuGExWk
s7p1xqliqeDjZ0BEhMGGdfjDu7+M2665Ac/YuK7iAiseQ6mIxJUVoCeBXgTIKOHN
V2iHz/usACrUz8UDge+69cn4lQ9+AL3tGwEiCMma8terwFPQZFXsao6bVNSB3pI+
w2fMXNIv5DS4XZwBrLMNG8rfyJFbAHAdgE8ZAABlAACRZ70La8KBjRaTHWim2t6X
VfS+bGTSWxPv0N6mtRLnUZ6kIdjV4Ki6xYs5sqhcjAhRRIhPnsLciUfxlm+7A/sW
5rAIIMpT/thwFVKnd2EyJuNChADJLUys6G97yk348H2P4NjJY5iem0/6bHsvDcPt
IjDAvybCQhqTmV/JYMlY2LIJp1eG+P6/+DCeuWUntsZ9bJoWuGzXOow4xvq5Wexe
N4PlUYxtc3PYNDeLZQAzqpN3eqD8YQQhBTiiC6caiBStxxK3X3kJ3nXXLnxx8STW
LcwgkoXKIdNvwxY9xVQQ3FkLv9iQ+1kmhigbkFbl5k+e5yoSKV3KBwGAG6rVRFUn
wHD1whWHn9PdyC1fZ2mf2VO9ZpIcsZ/e13t51Q+nB4KF96t6MsnRXRwQTvNJjI7s
x/e+5Jm4Ys9ujJxyhC6gvN3JmIzxKf8oYdeHZAHBwEWb+njaRdvxhw98BTPr58Ex
W7qI2rx6XA0AUI8XzvZvDMJACvRED6fkIt7/6AOQZ1bAoxGm74uwNFxBBKDXj7C4
soInLGzHJRu2YoWBrRvXYd1sH2K4hC1iERvmZ3D51p24adN2YBQDkkFCXGB8IAzw
EDv6U7ho+3Z87P5DWEdThd+EzSB3RX5bqOeeQmnzw06HS/s5xg3mX9gAwLWJkhLV
bwLugN7XvxJ2el/SXC3l33dtKZPGtlf5OlzNkSqYklakA+DRBx/Gcy+ew2uffSUA
YMhIWsgK3ZdAgas4gQiTMRlVN7oPkTWFHQEYAC+74Ql49wP34fjp05iPplKKbVRk
g1f9uSIhkAJZ+jjGaHEIEoSFTRuxGI8gtyYGweLiMqaiaQCEZbmCKBK4exm46/Ah
yHiEpf0xRgCWl8+gNzoIwcfwmutuxk3PezkgCMRxXiJ4IZ0BiMQbsjAaYcgmVbK+
X2p0nstWajjVO8PwJFchBzcVsNpvLlD7XVsFAITtQ3VdVlUr0Bxp+lz93HgWVHn2
u8fGIwHEUQ9njpzBvuk5fO/Lb0AmiyKo8ccJT99kTEa3xp/ifKWiV9etu7fg0t27
8ZnDj2N2YYBIEMCxQlzWxLBhe8VyfXWFXi8p/Rsur6BPBI4TgrL5fgTCCCCBmX4f
EBFGgxhJi6MpzDEQQwJYj2hxG5ZPHcGWHZemdhNfwBZD8uKn5EihUGen5Ld7q42K
tpInuY1pxsGaOFBLXIuC9NAKAPYB2OlyQrVRSBkJQvs9C6X3dSt+s/9Blvxi3x45
lmO33IsQC4nF/QfxxhddjqcsTOHUaIS5Xi+1CqjshZjY95MxGZ3eQ87MnhiIesAT
d23BRx99GKNoAUIQeCS1xsJVFj1nBmGpnx8FyFKTg1ZLF8zj0D0GejJR7zEBIyoU
D0kCS0pYAtJkM+akmkhQD2I4QD+ewRN37ClsPgrvFLAm8FuoFDT4eWwfOAXC4mAa
M4MIsUQe/Ofc8Z+q/cwDTGbzJuGx0n26qmrY9Y505bFTkGbeCfA+APe5AMDVtRR/
liJJPpa77J90vgBPtqLjDdM5tKD3ZZWIgWz82A4iBmuVQ4ssfErK/g4/9CDueEIf
r7l1GwBghopMf+ubsLsTUTUtxAQ4TMZkqLo1I2zNWYIBPGPbOvyBPIaTciPmKcKA
GDLrD6CE9rTSKzYsfY3KXPkJk+UtJ59Tmo04ZBjllUXJ82NNfqUeCpl8UGSJY5ya
e8xgJkREkP3T6A8fwr6sGoyAWJxbyr8SAEggXoohCKBB5DH+CQ+cWMZ9jx7C/Nw8
+jJCxJysB0udQ5ESSCAV/cMK8ytroE16IvahbX11XckOOa6mqVAlpQ0D4Kt9AOBK
52TI5XavptXV526h91VxcmW8zRVno/AFpqJZAmVRH3Lo+hLVo7EPDYAART0MTxzH
tmnGd7/4WiSRqBhRxJCQaX6oWpTTxP0ozYkCEy/CZEyGdgXIuF5P2b0H11+0G589
vYK52VnEFCcSjm0ewrLXkRX5ot8+mTfp0KhkfeRe1qYxUmnx4yp0LstWgkDMjBPL
J3Dt9g3YuX69olAp6T1wjogFAeAox7jv1FFsmJ7Bpv4cCEmR+0z6gWi2uj09A3jX
pz+PBw9/FXN7t2Fh1AONJE4Nku6LxHrnPubEe0yKwtD3wiSkY4s+CyW2U8EFGbqr
+EMD7XclgPe5AMATqx1mjnK9QPICaQsDEFsQcCBCauA74vQSlf+ZU0hDAd9XM7bD
QK8XYSWWOH3qFI4/fgg//Ion4or1c0lrX0jEqbOx/T3kir+fAIDzZ4xvTy/EnhB7
e1O4ZstufPLAvejNCnDrteWSAVReYW5mSNRRmkQYEnB8cQk7LtqHrYO5XHSfS3uc
ubsfiRfxYx/8Y9DiENvXbwZEBIolLh3MY/eGTVi/ZQu2btyEmaiPuUhgvj9Ar9/H
TK+HdSlQ+I1/+Ve8+66PY/tF2xFLQAxjECfNeWKyFL5r/C6sKWH3rrOHR8d/bmw6
Slbd92rVqOl4EwBc3g5SR1AbUaivAsOmrSdyajAp6V0bPOJy3PS+5W+O4xi9wQCP
PXIYl29bwEtTnn8ZD4EI/jhcbTm/1q+1UWeTlniqPQ+IJkClPtgLX7OEjARpGzTO
LVSWMvm3tDTsQtuHaxY2Yzp+ADyMgbwvgGEhs3khSYsPk1X5O4wqtn2oTp95vxTI
9i8SAtwXmBlM54KfRDqLc2yPv3r6FP755GH0F0fYFAmsrCTJmh/hQ6AD9yG6W6AX
RYhIYLiyjKneAJfs3Yf5uXmACf3eAP/y5S8hmusDMqk2WxZptj8LRGqoOQ/TsNUr
E75y4bqtdJICYvxkcPI5zsXlql5UAUAfwFX1rEryeApW2Zd3VnRimGue06QSAWD5
zAiYW8Br79yHrSmimxIxmHuoqDla/fUaqw1pMT3InYqpP0kqRIviAvZnqFFKma6q
2jPCvxuaYlfiwCSEl/hbtUfU4qnzZR+eePGl2P7ZB7B0ZhmDhQgcc2DbsNV3o4dK
C+akrjge9LB9dj7dvRhCRmki5BreQYWYJ5vig/sPYnl6PS7avQM9GWF6GBcBkiTr
EVKmjHz9Po7KIRaPHUJ88ACWlpZBALbObsD62XUYrozAESPuATExiFlvxwxrj+hV
89j5lH9JA1WXrF6V6vqhCQB2AdhmcR6lP5/W+3uRokQ5/mRjTmLPKQ7Juq+AvJ6e
CiL9fzbSKupvSzjRkUxFdG92Ho/e/yC+9qo+XrWzVziQKFLIjrpQ2IRVSwJkJLWL
veQrlmUMKSVmen3r6bj3jMT+Q4exsryCoUyO73A0wjCW6PciTEWM+fl12LR5I66Y
znjastnHSLIkMhcdJd3Qs7W74JCA6m2T+TljMCIWEETWE3BoBBw7fgYnTp3EqdEQ
h+MYMUtASgghMBDA/NQUtm3YgJ3rZ7FRXVopwTyEBCOiCBDROeJxCserl831sK23
iLuHMXo0l5wxHxEL2XL3OcBcb7FmFEpBVIx4NMI6McAlcwsAgBEkBhwlClas0R1k
XbMITnTQkROnMcMLmOttwuKJ40ljZEraIyfqReaIYTAzjfmIsDIagqcYczNziGTS
KnmFh6BIQJLS1onY3s0+30IKksB+/4A/TMtGjoHtzFCo6Nf/Yluq6x80AcBl5Wda
Esg4RCAZGfe5iyJR/klCTUGuo+Y5cuVaBdALa7lurCf85N2TkkTEjJSBmF27bXh9
6l2TrK0xCeDxxZOYmx3ih27bmdTtci9NvhEWS9ZI2KOa0mG1rH5Z/JIREBOhR8Xc
T3KMzz58BJ++7yC+fErinjM9PHTwMEZLS4ii5AxkaS5xnJyDuYWN2LxhAVevW8HX
XLYdz9m7AVtn+wAiLPESgAEiEjlF8nmjgBrbfgUQSJJaBZaIMKt84uiJRXzsgWP4
2weO4t6Dx7FIQ5yMl3BcSBztS6wMV4CRREyM5WFSjrpn/Tz2DHq4aUrgxTddg5t2
bwOEADGDRyNA9M+/RAEGthLhmvVDfG5xiCmsR99ilBAlrWPZkpRMitgmWCqkuLpj
YMl9qyYjUxEok6ZkS8WqYENyC8JwcQk7MIN9W5JKb5KyEC9pT4I1yTTKRZFDBmqP
j1Ywj1kMTw9BHKUvwBZQllZpjBg9ROnCcEqek5RRCshEJ8kEQBQOtCykLNPS8fJh
L29TiDnpLxdkpQcFk/5NxAGEcFT2EGpTZrrMBgAu6dYuccQ2mMCCoecC8vhOjmO1
itreQLc7cRDDX1kVM2KKMTU1wGNfvg933rwTV2/bDeA0QD0wIu0rdHDZxWWkMd5L
BiIkDUUkICQwKwQQCTx4+jT+7xe+gk99ZT8ePD3AgVPA8pCxbuN6bFpYAC3MI4t/
kgIYer0emIDF02fw9w8fx8fvPoTfnpN4wWVb8K03X42t80nyEpYBRGk3s4hTC+FC
IUo2y3OTsqNI9gAmRJFA5n/56FcP4C+/8gg+es+jePQoI5bA1CzQm5tBf2EWU33C
BhlDSi7qiUUPcQwcXVzCgaOn8HlIvGf/J7Fnc4R/c8tl+Ja9VyB38MhU0dF5ggQk
gAi4cfc+/MlX70nyIWrLJy68pdzVnSznVkmP9V8K9wiB5ZUVbJqawd7sDnFRC8Vr
eftIkTcgHJKLeOT4YfRAGI2Gqcw0YvNMJb6XsqVMCheETFL/keTDZCV+CSMuV26b
ythfPwzO1n1ky5PbGQplXd9T0Mpl9VzKLfaSaxQtjEn3UZ2s28Y1/4mTeiBiHNz/
KPbOS3zHMy9JDea+lYe5u1I9Wr27meV/AlgB8Nuf/Gf86UfvweLKZkzPbMBgdh57
t89icbgM8BCCJXIESEasbThCFAlsmB1gS7Qdi/EIB+kM3v6vh/C+e0/hjbdcin9z
w06gB8jjBDEPxFEipCNEuDAGKa6XTJb3EksoXYKPHz2E//VPn8BH7jmMM1Nb0N+w
BdPrGYMoqcSRI0YsR5ArjAE44aZIo3M0ikEyQjRYj/667ZiancOBw0fwiUf34zPv
+0f83d6v4E1PuQVXbd+MkSDIGBhQIjTPl3zBKzbuwuDEFzDYmHgA47R/QKgcJNga
mIWW81ZwnYSIzuxjyo8uD2Ps2DCLnQLASEIKgSGFUY2f1aPOerH5/Y8fwhcPPYrp
2d0Qjiz8sCUmS8l3CgzYArMyzw35KvO7MWiLuD81lOpefsDLFACQ/8DlrScdWApI
TJ0tlPPyUM3Pdw4CEtdTFAERxXj88FF8++1X48a5aZwAMIO+o5vYuSNBCQTJRf7Y
h+76Kv77J+/Cx46dwO7pS7F7YTuWEWNlFEOeGWKmD8QiieTbrk+mhJgZK8NhAp56
Agu9eUzPrcfDZxbxbz/4RRw6cRTf88xrIOaT+xkj41O/EACAWvlLAIaJ458S5b8M
4G0f/gR+8+4vYjFm7N56ETZObcaQABZDrPAQEQMRBHqpszpW+3ESAJYQAhBYRrwc
49TiEHODOVy+/SqI5V344N334LP3vh/v+LrbceOerTiTtLRQXN8EzltYn2O4Kp3w
5es3YG9vBo8vS/BMhOpS4KqcGwp3CVP7hDOTRzCWMUARLt26XaEwSUoDewD658D2
9NKZ3zM8hsf5DDZSlCtjbivT865+srBmSltJ9hw2wNHZL1z/uIMC3dAHG5+5XAEA
OcLZ1chjVofel9iOTLitSGSru2dc9L7swANUYoBKYtunTp3Gnt2b8KInJ56XpNky
teqKcDbUjkpdkpEoCQJGzPjFD3wK7/rsgxit24WLdt+IaZY4snwMzDFISBCPwCSz
TtlO2Utp3EsKxuloBAFgEBMGQ8L01DSO792CX/rEXTh5eoh/d0fWP0Fi6oKx/rO0
0swvGoNoCgDw2eMn8Zb/9w/4268cwNarrsbO2VmcPHkMU9EQjBgkGZEE+kwQo4zE
lEBEGGkxSMawN8IyycQTwEmZVG9lgBk5hyt3XIP7Tt2D173v/XjHS+/Azbu2pap/
BQIRJARiRHk9wjkFAlJv68LsLJ6wczf+7uTj6M/Mp0yARYyO4ZBlYNRJwvXTo7OP
1s3rOyRGUc8eRRjFI4CBS7duTyV/QgnP58iRF6n+kCA8OL2EaH4GQzm0VE7JaqVP
fqWT5W1pIIHSZ1OwlV1Dh5bPSz2fu6NZkCMCJcC7TA9AD8QX+zCkTePJOvS+1L6f
gGuzWLH6uYSbAul9ObScz3X7pMYIRRl3dDSFw0eHeOXNW/CU6cRiS3NVE4sX50TF
vvbeK1gEI0mQeuz4SfzAe7+ATx1cxPbdl6E/tQAxPIUhr4BpGUSJu584PSssNGBm
S6shUorLMo6UiCHiIeYHEbBrL37jUw+CxTTe/IKrkuQex9POK72v5rTkVTmzAAT+
6IGH8dN//g9API9911wHihgrK6exbtADD4eI0uTb5OQJCJJpLQwlf87WGpxkhMec
UKkyQLQCQRLcX8SZCIBgbNu8GfsPL+G7Pvhx/MErb8cT5gc4A4mpNLtGrmW3csDo
9wiSYiydPoF1mxYKaliWDksdOqGZld7XMFuIC3q1klvZVXpmSwYrVzSJVIeNBBAN
+hieGaE/XMLNm+cU4yQ5DyabPa1F4ZOurQDw6H0nceZMD7Pr49TkKvxNYT0CyKpi
Oe0KRcRFGmeu/+t4gMJ0icv+Z4WqWqWtrpTOpEBTsui09IxJ4OJU94+yHIBtAO8o
p5F46ukMi4ENel/9y03lP54StYzhjxQXJGtMTCZS9L1fM+dKNg9Ckhy3uLSMDbN9
3PnEHcoc++ecQCyyNmIAwBTW4+ETR/FD7/57fPbUTuy79Gpg5TTilUUwRgl3NlFy
mSgtnbEYNGT5IspRf3LtpJLVGg1jLPRmIS66CO/83D248qoN+LqLt0OOoWnTGkQA
ikQqfCbvuu8r+PkP/xNWphewfWE3ZBxDjk5B9ACi1MknlZ9jQAqRK7WEBZbyOmri
DKhFCl3DECwYoyj5ARETdm/eg7sOHMVP/81H8UcvezZmMIUhzoAxi+E5qPwz4tUo
XYu59esgHiXEwyFEmgxGxAHSIbywOFP+SVWSzgxIwbfS7QlgASzJEZZHEht7ES4a
JC4OyQSiJFk0A39rf8MIQwCH9i+Bl6PEuJCsNTOiVglzhUc51w6ZkVvaD3Z75Rro
kqqGwIG+hNQgriw13ZHofDzaSyXydoB7+lRM7nu1IY+Ch1LlX3pBIQtPAJsLZU5M
Go7gJp4AM1uXLaSAGZyScMfdwrL9TW9AQYfCuStREuHU8cdxxzUbcP22+fRfdbrf
c0FIFvGtFQCMAWbw+MnT+N4//Qi+PJrHpbu3IV4+DSmHicIggXItCFX7towkMtfH
+isjbO3P4My6WfzS33wET/uml2DnYPo8Vv2yWBcmxCOBKMWQv/aVu/FLf/0h7Jjf
ge3TW4CVpeTmil7uQSnON+X4mwmISUDl6VRZ/8oJ7BnfgsLqKYFLN2/ER79yN97x
+Q34rutvwBRP4QwlAlScc+ucAYDkfS/asxWDB2YxHI4w1Rs4XPQ25R9SMl3ILUll
sJDJM2IyOoGaCdR2sMEA4ogwEozFM6fBSxJbptchEr3iTHESwqNzQwABAA5KicOj
RfSno1zGE6m2NGtekiZGjsw9MiokKGrzheXU2NW5vRUhlzzpNjd9TV+5RacVoQw9
cZRY9hKdj0ezEMBFTWvHq+l9m+OZOogNnnlomIhkJ/NgywwSqmiGEEC/P8DRU0vg
ldN4yXVXIgKwkmYS91P/xLklJDnhLsAclpZX8MPv+gd8abgJmy7ai5XFJQgeJYdN
ZsjZwUepKvkGrbJFGtuUscT6rdtw/6MH8Ucf/xJ+6JlPOq/t/xhJW1qSBMQA+sBf
PHIUv/qRT2N60y7MiE3g5ZTVNwMMUnEWqApLdQ+qyepk3muH85oKYNKLBNZv3Yk/
/Px9eMmlV2LXuhkIjDB9DgIA8303TxNiSPQgrMDVzVwiLYvKZcCQtfAthSmrzAMj
aJYZLFTIOUmJt2YFQNTrYcAruHTnRZifmc5lpSAyVOba3ZTMo3twaQmLfUYP/dQj
o2TsM7c7dCRz1EDaYQ8ouQgyUlk3nOGnAyIY9L7WELSHC4VgN+ZznY/PZABg9+o4
kM/mQeJVmQIJQixjjOIYxxZjXLx5PZ68axOQd/kTiM7+agQCO9P1PAMA+MW/+jw+
enoaOy+6CHRmGZBxSr8Z4tCqr/QZnMBkStpxDsEYihH6cR+XTO3Gh+87jFfevIK9
0wOUSKvOg5SAzDUvAfQZiKaBux85jl959z9hYdMOrKdZzJyOEQvCUl+CRdIz3l+a
rySzUeOtAbPEupmNOPj44/j9L30Z/+7mGzGNCBilXrKIz1l2BilHGMplzND6bnaR
qkKhZVlZrwis+FlJwJASltHpqWksrSxj76ZNqXeDV8k069Izk+TmP37sKA6fPA7M
TSGiKJE7aZyK1rhcZa0uo8ZcGeOQZ7sBoJc+cWfodJo17OOAg9vUNVQImHICICtK
rMrXVS/iljlPyzm/AkSEeBhj8eQxvOiZVyaZlnIJQswiS/sROBcEo0Ribor0+hF+
65++jPfcewQ7Lr8S0eIypkZLGBKVAzse657rbS/yQLXiMpUk0VscYb63Hl85uR9/
f+8j+OZrL80ztc+h7qYhfo/UqhwBvQEWhxL/6X2fxWkZYVO0gP5piT4nip/yrgBJ
3oVTKJIsCaWqa2xXS4wpHmCF5vH+ex/BN950DfZFg4Qeuo9zmpppTkToJTxxNdWV
cPx9/Yz+cPlULoQTktETAvFIIl45g0vmyHm6eI1vUza9Bx97FEdPn8TChvWJwa7O
PfUG+HUUl41CqjZXqZn0sn6v7yRYfT+V9L6Fl0nz+DvXggDwzgQAJKt3kbM0gklz
WZhCg5R8ABu9b/5ZNt+mqdLXJTsp+bJZr2YBAkgiSO3UYPdTQ3V5op925QmSBUA9
jJaP4rK507jj8pn0Z6by1EQCVZ+Aswm3Ne1bBCretwS89bMHML9uARswwqJcSqwM
Zr3qgg3XZ8Z3kCbrWLEBGe2m2fDYCKn9VF8CFI1wukdYOj3A339pP7752kty5X++
jQgSgkYABviFj3wZH1w+gyu2bMayXMJKjzCiZGUjpjSoyGCR0qByuctcHh8sJWbq
uRtaWjChfHYJiDHCwvx6PPLg4/jsFx/BvusuTTKKzkHdr6Y+752axXqawWkmTNU1
L/PPF8BVBV6aTFGuSjlhOSRbiEs+u7TOCLEETpxZxJaZIfYtTBVS0yCaWcXuIc1E
fjqZzx89CJoeYGF2DisnTkKk1NRZugsrsoOdQjxJ2GPYQwYE/c5QyQz3rZKj8Jz0
pHmtmyBTW3pfrfKEZJJ8LbOQUHYO9a6TF6UeAABJQkAAHnHbC1zSuRzkYO4OIRbl
YzUyJxohUdcRYAAxBHpC4PiRQ3jlTVtx+bp1uQgnPgelIfUARHgEwDve/3kMqY+Z
mT6WTp8Gy6S0LICdulDqRG684TglrBzeItVnlIQEhMDm+fX4wsMP4YsHDuGa7dvW
bklTGx8AxwDN4h/uP4A/+Mxd2LJtG2KSyUUHJ7UZVIRBkxwARmUfO6rw1gUovhgS
vZ7AzKCPzzxwBC+/7tLk2JzjQGxaRA2Z5tiwdTjoJ0S1LRhyYZUzg5TimbBvx05s
3LDBKbdWsXtIY/P/DIDH4iVM9fuIl4fokShAjNlZOeTQU/BXQ+28UM/zo+eo2SL/
1PR8mU9Rw9wOwiJlbAc4BwCb3FOhAAcW1VRuNCYh6SDXWyVVwBAgEoiXT2PjFPDU
q3bhnB5UkOu85xN34a4v3IPtl1wGAjAaycA+8dTQCWr7Gbbu+XQvwtFY4p8PHsU1
27fl91sSziN6oGmcjCV+7hOfgpgZYF5MY0TLuRyzrxO5t4TC15884idLAh5JiZkN
M/j8oa/i8TPXYcvslJVUbc3jXRTNjTlK+x1xV/lD7PxrCjI1qm9IbnEiLensCQzj
Fcz312P79NxZkMrthlQ8GvvPnMKBkyfQm57CMB5iQFQyFUxg09D1WXETmjG4sqW3
XxtpaLXCw5+/CaAcAGz1ddyrEtxUN/mrTczfF9thslAyOmzBFkEvYnb8uACJCKdP
ncBN22bw1H3bASwDPEBNuHl20baRQHb30gjv/9gDmN+4BYNeDzwaeZR/U0ei3lCV
UVU8o8IugcXpWfzLkePGdRtBIlIaP53LYIzwOx//HP7l6CIu3nkFlk8vgSMJwWSQ
bqm56Y61Z72jXOlnDQOJqexB1FPZGJFgiF4PD585gS+fOo4ts9vOOQCQ3uB8HUQk
0Bv0IFk2uEQyf2JxoRzJd5oXTakQqBn3V+WxjICliDAgwmhliDlJ2OATq2vUXcZI
GtdHAB499Dj2nz4F3rUZ8Qh5qEv1KhYhaQ5Qom4mx3FUtlk75Ha9WG5Eac55K5Aw
AG4CsFXvQxzgOtS0v4UEoy29r4XjmXJHimdTrfNxFFqqIWdL6S451tKFHSQkZDzC
8vIKnrBnM9YBgDydu9Fdu87jOhBtQIDCa/Huv/k8jgynsGnPNiwtL0KIaoJXL2ti
KALP9pLdTN8kE5/3cG4Wdx85ijxngWIkmWgEnJMAQOfSO7CyjD/913uwd90uDGQP
p2gEimIIFhCSCubJFCyQzW63xscsMUVSlt1I6eDSPUgEbswSok84GcW469QJPH3b
Nji6XZ0jvoBErwgh7IXaHhuds3KyjCyB6vi+KFB5eexUShgA40hgaThCJCJcvHNX
6WStZctfHSsApgHEscRSLEE9AY4z0MJaA2ZXJ1quFVExic/rGbhZZc04rH0b/wxK
mVVBYyuATT2ANwOYg7l4RNZGSW7lz47j1Uz52+h97erfpEIMvd9UqajYpo8cBpUQ
hJlehOOnVzCMR3jiFduSfxPrizrdWlf57F7MzCD44sFFvOfzj2L64gWgPwItR6n1
ryQdsfuQlmkASLE2ClYazmOlSoc7I+bGLhBGEtPUw6KYxn4I7ETCCBZh0Akz2Nnb
gbTgH8BvfeIL2L8ywEUb1mFp+QxEj3MDCCIpxysgMjscMcVdLXJp2XqtOaSTbY4p
GEwxuC9weiTwwPGlc0OzBFrWoYwobND/qh5ZZ6pdcFmVg4LY9fNMiLgHjJZBvVPY
umWq7muf9f3LouoZBdNjp06hz8DMMgEjiVHaSlwqdRomya/mFSf2GFuuEEAN+npi
JwBRJ0UKyxY5s5+4NGcbva+aUEiGMCY/LJgDsLkHOD1DNS6KDQhQJxdQVwK2CoIa
jSBU85/91rxNGbq8ZJTWp8fLpyGXR7hszw5cv3MBALCIHmYQFlnqavU6EX+p3nzv
p/bj6MxG7Fo3wuKJk+hHG1SiTOu6c5VtT8Z+EqeUngoASBhtKucpRXLo57mPeKmH
e06NsHNdL6WyPYeVEAMjitFDH3efWcRffuERTM1sxpIcgilGH4SYbdZ9URKrZzOb
d9Vz0nwsQBYBSqmgIgJiHuDQ8RWcH4NqWn8pCCPFJiOGT9Q3805xWQCx7tiMZASK
CfFoGesHQ+ydnw1X/GsMimUcn1989FEMej3MDhnLEhilTIlMSiMxOKreYCfspf+f
vT+PlmbNzvrA334jMvPMwzcPd741S1VSCUmAJAsMshC2wAJbxm3aLex2Y7No2xhY
xhgPq8EG2k1jDAtE24CEWdgCIWtAQpQoDaWppCrVpKpbdae603fvNw9nPjlEvLv/
iMiM6Y0pM8/58pQrtEpV3zl5IiPeYQ/Pu/fz1GKxzQfHVqSSNt0BRl17rBaibK1Z
l5ra21VMErlrywfdyhqRaChtjuMvS6srOYPiovKdRg4k9TITQYZcn78kxk3Sog6i
Dd1neWGU8/BAmwXEIoaRFXYe3OIPfsP7uWgMx4zbcRyOq2LJPXbILVB6vvDWzhEf
f+0dLm2tE+4f4dnl1DqQStjSdaQyCaQkncjE5w3GOhe+A5kuZqdGMMbw8P59du7e
h7UryRI8c3J0pIx5lPv84gtvsXsQsPFUD42xT4kV+sY6HChZ9YsYwTOZSVCKfX/q
joJTQUDtGo0lhEUU3/e5ffvOmaQCLqQTarFBgEiHJkV549FXSZzBBJNRF6jccmGK
g0o9Hvvon2byHZ4FDyUcDrjuL/G+zmaC1knFi0uNPzzl8Gv8tvujkC/v3MfrdAlE
sLGyqBnLy4/Xqmbty4Ted6JHkmpmT2XXRqsy/no/VuDLyJ3364QEvuHRwFh9MBfS
OOl9ddzUaFNIUz4xN2UBgFxwZXDSFI6ay+ooAuJ19L71uXQREqt61iphz/o4MC5E
6a6z3hW+7Wrym67jK3W6Nzg1A9iJyxV+8kv3eOnhI65urOGPVrHiRTSz0KgIsBZC
rpXEkNrNFtEQKF7HZ6TK3u4OcGVeSp2PMfk0GIR7Fn76N2/TWd7AkwBrY0WvHJxZ
5p+ca0qb129oNomt/jtVVno9ArHshEPOed0zGQBMxiy02FGILPWaJc5F2nU3pKJt
7WZTbD4x9kYNWIP0h7z74jaXe8ugFqsaMegtWNJRgdUC8PrhPi8ePISNdaxKJjEs
0innk5BcjVjD1swmuKzmRB8VN0V0+vkkXbhbWivQlN437r/PRXZ1TYvxdcEHthc7
Dj8pSG+ed41gqLfu7PCtT13im56KIoBOprCyqslykUDPiF97GFr+2ZduYbYv4quH
sT6h0ShTF3EaHVoo8qWZ+rTOizW4l+d5eB2PIAzPhmWrXfrRC/zyy+/w2Xf6nHvm
Aqp9x0f09HZfDbWwquL7Hn7XZxiEZ64DIL/6jCpq7YLZoDp0UxKLYxUNLB84fxUP
CCUEMQtre6re9uXRIQ99YcV4hAQTfFkbW40cA+AJ7JWpco7Hm/Vt+8DGhBWpHtg4
gcsWZrw5CpVnzNKajVG+6V3aNfX5Z/Izo8LAwpMX1vGNDwwQfEI85zHAYjJvJfDi
L7x+hxfu7XP++hOIBqg1RFX1jlGIVJCc71PsqkhV62rqPLpQUFoiqVrG+W0UG1r0
K0EV2Cp4EYT/a688oru5gSx1sHrsXDlJB4C4V71U75MqG1TPJ5JDfayiVpGvAAam
YxsQoPgpp6m1liRN+JJHXLQBt3+T0mCtRWI8G1UhDIMhz25fACBQpSMmcw4ui5yN
pAb8xvEOo66Heh7hONeol1JwHEFOQ8Tj9h9F/LKpP6r6dTWMJ5kTu3xlmht7qLg2
fJ0EAJIlsBqrImUY2Gz2C7TKhTWhrkxz9GsuAEiz+MukuCVLO2tzgzQFxKbpznPN
tlNRpbad/pEQBEM2u8JT1y6mnk0nrdBVa1UahSonnHGOD+fHrX9v96G3zLIOCVUQ
z8Z4nCRrIbWIVdyQl+RT9bg8Kk8PFAUDOZpUB7Wja2xMfNAdZWtnm37OqkVDi+f5
vHR3wK/dGHDpUsiQ+1jpFM/vS1ZNtsq/aJTypwBlcZOxTbZ0fhXbGVugHnfGGf3/
Vx/c425/n/ObFxDCVE1ESnUkroeK1r+JY1nNZNqoFhUZC/PndikUAgktajWn4OT0
/HvGEAQBWyvdFL6XbhlL/Z3znEcWZULoP9hFh4qsmthW5B1v8W8kbsMcz5bJjWeW
Vd7BxdCg1Xn833nejXF9U/lhjZYch2phTsfTk6a7n+zaXCam7SK6DV9hvZ2nmHVj
azEuk3LpCzEJxbA0joyl1frShgDO5HOaPwP3GIwCtsweH7ie3mz1gd/jpeDMiBtM
vv2Fh0d8/M1DLl86R0dHqI3Ed1yxVlR4Ux4mOePTiV5EerdoK9yn6MSEMAyx9oxD
ACIYL3Iev/zyHe7uP+LCuXi8pBs5lwbrVRqu+KmDxardrRq3JZ7ta2BHqCd4Jjre
kNJRL9/VSaFrnfhrDTJamTZQCJwNQn804Pylc2xvRWqGJieedvLo7vyu2zs7WBTP
dLE6KrQIu97GkD9fnx9RXXmeL66QpCHyWjLXqWBCRefp/9Z9YHNxYm93T7KcsM7j
rLe3AsPBiPduWN616WWyYJnbkpu/81eiyu1okXmoRK1zX7x5h72H97j6/PMEh/uR
MU+fkch035eJfksDwmnmLSYCUT3zQkAGwDOMgF97802W1kJCs0Qo0XxFlN/lOvFy
Kiu+/L6iCuGZlwGIJ8ODwEbdFkZYiMUlDeeh02Fv5z7vfeo85ze3JrtEFrLxuPoa
Al8+fMio4yOeh7EjbKrjodla/8rRBp3jtRnXAOB0vNWZ+5zcl6uQKeVspA1l71T0
vjrlIye919Z6DEYDfuf7rnPFjFVQigS0rkbFx9vvbwkY4AFGlyNxHeATDw9Z7XUZ
HB9jbI5kSbQxMQpIjZKWAyZoKH6dZ2kMLHi+h/G9xxlVzX7ZEXgdPvXggC/u3KG7
vhpzHaRpPdyrSLQt9uXeA9k2zeJfJXBk8feeRjK0cgYjgIQENnqxBzqifxAFwJ7x
CG0QsyymwtiS93QpLM7FJjUhDhIl9JXdgwMu9Z5iI/68V5j5BYX9c9c7/T1u2j52
eZVQJa6pGmeG+aoKnbSpT7COEgpemWGdpJO/2Wq5tIFPUxrS+7Z9lQ0fWD6ZrVTx
U6l57DYFElPEA5LLQJV2vLXRIoucvBrFimFwFPCe7W4K0ulE8qyTbtUZgJoTSiUU
CDjCwwDLUfYfHPGpt26w0r2IhkEkKTl1xp8/ADhBr6AWa4cM7DAZ3LPIAeBFOrq/
/uIb3A5GXF3xCFVKWpfSQtRNgcu6c+cU8qaKNTniOSkCnIlPiqV0Qgvh2TsCkCwO
Q390zPmtTbQDgQYprooxA6aWREnawm5pczsn7gBQU5Lo42tkR6hvuLKyig+M0JhT
0sw/iTvh6/U7t7h5vMfKxefgKHLwRiAsO8qQdI/AmCzIVucdDRaHlh6dTdvOGfsf
KbPODQsKp/fPyycQALizvYSjKP1byRWEuf7Uth5orQ1DtBAEtEzT8FBEDUMMh8E+
G+t9tlc7KQNSUddAUxrKk70MPl1dI0UZw2feOGDnwLC84jEu5tKW0hjZHWZP5R1H
dkSv43FpeTn56jOJ+kUP/eK9hwy6PZAeZqRgpLS6t/muKLJmltOF2tgwpYrOKqkV
IznuURCwsrrEZm/pTI78eCyOgZu7yuq5i+CFhHaU1P2oVpgNxU0pVjcndZ8vYypJ
J1ZCGOsXDIZ9NjzLb9laiwOAsMT5n3rZcevrc7u7HB2HPNXpoNonjGmWkqp+aWD9
s060jfOvVvFrug+LdU5pLQ3XdyYz094H1j+HTgKAOe7U8ixPU1B/ltN4PIU2+2HR
lPNokNZnIjUqImjNLB7RpDa2TfGHF1etq/E5PHrAB58QnrxyweHq62JF64hJ5ZQM
nuDZlcxuuPPmHsdHy6ysx70LqYK9MvIfKfACaCKhmivwU22aGbUbg6EGbC/1ePfm
eSBqWDScRSkg4e5hyMuPArpLK9igg9Eg11iWrJEM7K/SLAuN95XBrRooajO8WWmO
EckgO5IzrspgNGR9aYMV/+yRAKWv+8d9XnmohJ1lPEZZwpZJMb4UWamciYVLKz6v
YaIVRqzI3phJYdKkUCKoEY4HRzy17PHbLkWaJB1VFC8XFJ+NnfHCKGCNZbqHx/Tt
iMBkGe9MGZ6VQs2MgpVU2X5DAR0rFcWGcfuzxMx81cfV2f2XdA4o5LViJN1tZzOk
qDKN7E95ELLkq+hStIbm4XTqsmqZvHgiW5KIDyVtePkHzlP+SmkwYEtjBcnhEDn6
4vQmbMCUZrGYIJILDYIRF/wem6aNO8u1QjrH7RQCAQPp5ODu3jGeWDxjYKqK+pSW
rIwFbXJjPOeTABHwfcPwYD+mCEnWwhnjogHgC3fucr9/xPrWeQgksl6actjiChWF
Wt5K0dQeSPemq7NDXSeFhzJx/V5JUGtFUDEQgh2e3Q6A8duFwyEHh4cEK11Ube4Q
LwUJ56STE4dtc+f1JSJpLnrfcYutKxDIBATJEUDGBqpi1XJpa5utjY2Jk1GJGujl
MaCN7fxH8myHwJ2HD1judglHg8l7j1dwVXd+Xlg8zQQsjThebS4m04JQuWnjkMVt
81Vya2PCvWFxtdhOV0GW980WhCUf0W7y+6Ya79N8KYlaVv7hJd+cUlcq5yDblGIA
7RKRlRxJYnNKlLRhhKEndCyoBngoz50/1+Y2DcZNTmW7WYnag0Tg5qMjXr27w/Jq
L0UgM2u0mdummv+5rehBbt5DMRr2WesaNs5tTLbJ2cn8s0/7peM9Drshm56PCUPC
VPyUo8yogbyKq7wMypQca6U64FQpBKqSBUk1pOcZVpdXznwAMEAIbRhpHKTb+BRy
ZYA5dDmX2Wu1g2tvB7T09/lqm9XuEktiiOrovcTGLyTi79Zy2Ts+5uGDh3jdDmFs
6CNHngQAGZpdJ1wfITCR/y107Jf4uDzioiXsMIkUt6Qic61JjAtEaoX+f53kSnmF
nbYHGPm1kmol7Pokaounvsnc/5iuplIrnT/O+07rZq1EGY/4hqPDXdb9Hu976pnZ
YqXH5HZGQDe2CV+6fZt39u+z/sR7sVP3cTecP9EmYgGNr6PBkOcub3BtfXlh8xv3
SNlUVmYIgF+7/zbDrmKIykfHBwC+y0Rquz1SxkWX/m9b6vRrAmMbgHhcuXwtCfbO
WiFGbBTu7+8wCsbUuaFzrOa31Wcbo3z8LFYZhcrG2nqMgKWJgmRBjZQ7sBkNhxwP
+9BdRuPiv/GycrKrVkX+ml/PZTNpSwKTpr5WKymzT29tqDvzT+7b9RkLjpdGqNry
YR0QtrjuqjBtcVmFiGPpdFV4+7ZbwqoQiMHrGI4P+pxbFt51aWXKOXt8PaoSm7Yx
admbR0ccEbLmG+yoXQCgLoIace5Ah+WaZm1lI77QhmwvrzKeBX8C0S2unwlTTtaL
l8E+I768/wD8JYzGLGaiGZdMYynR+t9kT6elkB1pZdaZ5CceilVlNBpyZWtlLo7t
1OdEFQkt+B5v3bnDKAgwxsSKcy40scZu6Jw2qTa0UBqdE6kKw9GQixdimRdrUCXu
6NBI+W6hgACNXZPGx0xMFP5ev3OXo9EQ8VZiIlKp9gi5MhiVtnZWC2nipJRAmlHF
uYhrmgnLjaG+YnJkWwcFWhPYANDxsXSKwKBOuZrTo589HJOUQVESVqrEL7hoL127
rAj9q+N/RwtAM98xnknNctimvrk55CzxxrJquNA54pleboVUKABKpUzj6TIEjAto
RsCnHhhGnXWGQR8PnwQxi0cnt/mS37kgLknB/cnvRNpEuWVHAppZZ6Ea1vvK129e
SX6vGimiLXSRcyS7nc7Sbu0EHDxaZrnTQzQAM25jKgmZpS5DiYsyUxX8dXoX2Xm2
uRChGB5gFSOCVaXj7XJh+ZizeMWKuoTAr+0PGHg+644gdmI9qhK9pgVhTgpzsi1/
jiMy0cIsJOZSQ1Z0n6vrfgJZxhwfnkgp04aLlvw0r2ASACTf/PmDXfpYlkXiTCUp
SB7D/wldfbalzhqXQ6xLbjWzr9KVMknBbYlKjGjh3+mDNYvDpwlFdk+b/Y7m9L4u
PZWUTZaC3+z4oN58Aa204y9vkZDaaMUxUtPkWXn2rtztpnnriHreTI6vr53bojd2
/oZS0e2qmuB5QoJtZmqcKd/pD3n5dp+VjfMEwyBFqKPNxtn5o7FUpcz4WuWrRxFG
1rKhPr/l8rnJT8/K+b+Ni/C8+JW+fLdPf9dj5UIX0Oj8fw5IhtahKlIMcTXDOy+l
e9dgEWsYhSHbq4YnVs9eC2ASYwq3gC8NQsTrTArHXEcl2jK/q0e22t3DVRGuQBAG
nO8Kz6zUIzGLchiQ9GeB2mg94cPrxwdop4MxfoYS18my2ggoacLJUIE2Nn0fKasa
yDET1h4XzKN9uvSdPZ8TKZSWSpNTXhzj+oNq7CU9PKdVeywKno0iwuFwyMXzl7MZ
k7gXjlTEoo/L3o0dSzgYEg77dLorQJjJ/JvBp003WBtyZGn0ucAGrPrwxHKc4QYg
vsy+b07Y4EXjr5HQjBoQ4cb9e4SM8GPPo5LmFp8uCC7yB6Sz+nK5v7HMdVU2O44N
DEo/GPLE6iZPrm1PMd+LMinCrh3xcHefzhgeUynt1m7pfaYxmY4PJvNX0J8T6AcB
Ty9v8771C7FDBXyp5MVahFnyckZ2iPDm3XdQoxjPR8JsLcZpRS/ThHalvAHSdqnU
p4vlfrTuOFA8n5M4Jq1nqmweg1rT6HVtJrLQ+tqNadseJcp5JJb5HQV9lpZNLuut
j9yl9N1PdyuKWhDD3aMhGlrUWoxvGjhwLfnvPALj2j5asrDbApCKYAmCkI3eEitx
9bmKEhIVDC3qCUAsYBhnmMm43nhwB0uIkTz3fJs3SSskuJZ88y0vtpkEV2iEoR1y
ZfUCa52orCiUM9aGGUPxO3v7DPtHGH8jdv7VZi5yyTOkHyotnZkp/ZcoDPoD3vfE
da51V+P6GMWPIWx1M+g+9kAgHZyIGDDC3SDgwaiP53Um3NOunFhSx7w6UTxQTOpI
QLQuD0nXLs2mKqp1VM75lrXK75rW+Rd/Nq6JSHylGL/5nGupCS7/6fx72jPnGIVB
19y46hy+Tx0WL1pyNgjwlnpsbfWSERatzP6rEYDT334mNnp37tzh8PgQWVrH8yTS
pJ8hwixGfE27O1qMgShWlP5gxPWLVzm3Fs+DJ5N618VmA44Kssbn8/sh3N47YrnX
jc44RZ1Ki80hyLQ5kin2mZaf7uRmyxplL+hzfXOLJaLGM3NGBVhu3b3LMBywvGxQ
tbVA7Mkkom7HUBx7HdNEROf8Bg76R7xrYysBJP2k40klQpUeqwR55c7XieDYzYNd
BgJ+t4daMCXefMzHoCkoUhonqPH+kDRIr43n11Wfqe5MtyLpbAMJNP+cVoo+RkbH
b/6lWvvTRCjOFQCUsdw1f/nypN4WSB/mgcpFm2Ws9S2pWpyIHGVgAy4vGT60sTyV
/14UTQCAF27eYxjCRidSBrClo91EFrpK3nfGN9aobiGUiCNHjXLY3+XauavROXqq
qOpsdGTaCR70+u4h7xwP6HV7U45Q3unbkrSnCeNlWoO7uqLZU8GoYgcBT69GQdiI
uVKMnup1Z2eXgR2y2gE0zBSuzkIgPp11KO6oMRVORHSlePGp48hTArGoHXGx20lW
gg+h2kmwv3jOP3eAGwoYePPhPR7YEd2l5VShHFFgPHH2+ZN2bRikJZ9Vx5GtZE7t
yw+AsuUx+U6opuJ5bZx/03ua4udTBGLjn/r1396A3lc0AzrWl5y0z0a0QYYuEkPa
k6U/2+mGiou7edxDY9g/OuK7Li/xDZtrjveqU2SXdPzaGvCZ57WD8ot7gL/MkkTC
IZIp4kzR+6Yzeklgt9IFLW00uKX2M4ZIk8WayE5YEzAKH3B1Yz8z7HIGs897owF3
O4oYQaxO1nTTQELTdLUOhT+JjxpUSriXHOtexc2DnslERWA45JpZ4tnVSF28q0wC
57N23R0NMR2DamJBVHLkP+7Y6HTCgXFigoIVjEbU5IEXUTFf7q1yfjOqwwg9m6AD
KBJzGkrZjjtlItJicuhNjOBrew+5MTzmPavnUavx/lfsuCxM6hxtss6zqn22kCem
pR3TGIJUFDBn6LIzAbN1mz1nPVvTImtttEKKZHuWQhdATKYEqB+XiNCMBdBR1ShS
ILIcM8wVhH50ulWlpSiKxIuauA85R++b7tPRtkGHZiGmTM+PomIZDPs8eeFK0kg/
U4w/MeMT5yWntO9uqHDU2aTbPXbkeI7dlKajFNzHBZNdZRs59mZZqWIxcfavhD4Y
A9srq1w/dzETRJ0JtxPXk2gc2Nx+cJ/DQDm3vpS0zWozA5FTXMhob1RlCi4fram/
15SxdJW8KUqn4zM67HNla53Ll6N58MTGKNLiVwGkh2DXWl5/eBdEMRLiaFB2mrP5
yR9rZSKUtk3RcbKNFnwQ4vkdhv1Drm1ucuHS5ZKUKzmAlIViAgCLwSBIvGTe2j/A
2hAVjbN+xY55/DVBZ8trynJIoGRRsbS6n6SSO9G6RDZ7T5sJGTSTHIvOCfmsXB8N
2xJJ5K7HcZEPGk7PKUxKRKcI92fJRWUur+qm96379PQD7zKkoVp8zzAaDAlMUOkz
27+xOb3a6fiLHtw9IjgcstTrYWvPTWzDcW7KoNVcgGlcP2MNDIwFDwb7h2x7yzx1
+UoOwjsrl8TuH+4/PMQEitfxYRTM7jLELTAj2uR0zK2h7kKyjOdx2O9zrdfj6tpY
XDSMZabPxjXec3f393h19wHdzjIeUS3D6ZHmtI8iQoGRZ7Eh+B2f/s4x26vrPL3c
TeexZ2AP6ESf0gOOgBu7e6x6XbwCu2tzdr5sbKClkIfbUzRLSjJqPaV1UjLTPFev
kzrMvYjQxqYh9BnzXM40feqAHKTE2GujwcjA/hX0vmmusjQpxLyGOuNOJnMd8UqL
dNla8XIBgDRPN8qYE08xAwW4f/cOe/tHXNy8HPXQtSGC0oZf4rxMS+ArssSBUUY+
dDw4fLTHtfU1rq7684z7TsncCxpnPVh4tBfQ7fhoqt1pTMqjKrX7ROvoR3PLzZQa
NJyBg+vyxDAcjTgY9jnfXWOjFaazeAjA6/0D7uqA5e42xip4kcSuP+5BV3Hkj7Ps
wXpnpiXzM+ZqGBro+h4aKqPjIZc3u2xN5lgSApqqZKlJl+MJz4HGmrAe8MpwyIPh
MVudpUgQTxNpXJs+c08d4msG/SLFy5+qDdBUcCv1Xq2g+1C6u7QGBkqdvsv8Ry8N
/VeXrWbWWxhJRbeKOlLKShmb0gZaqs9xG9H71ridqSWMavC8jucxPBqwsbHBE1ev
NvFlFc/3GLm54ym4/WCfYDjE+B1GGkziuCL8rBkNn/rBnj7AKZtzK0I4TmGDEBN2
uba2xjpn8wrj/N/2h9y5e4uwdPc4BLBqnVATrfLZ1p4R4eD4GBHhA88+mwvxFz8E
yDekvqgHDLrCcghW1FkmPT8tgHaWrax7KJTIkg/6x3TxeN+Tz6ae1VSIrC0WCmDj
7B/gxd0H7I6OWe8uEYQBxogzm81KlkiBy6eI4KaK/+aCyWhFEKet/V57z5YNtVsG
pSMfZFSfpdliNZK4N7mkGY5yxKHl7r2Y1TiRABz0vpOzShe9r9CGAzp/xhZ9n2T+
bVG6nk9/cMil5QHPXllpP3+pkdWMKFETgz3fawTcVZ9Oz8dqSEgY0+jmEeRx5W2R
4lfyGKmUt7to2XndpKAwPQB56tqxwzN0raKhxQsCvnGzl4q/NMc25dowi1ec9uLR
IS8cDFjZ2sBIIqIcbaVUPYomJaSTqRifCU+0dySXv+SBAFeFuS1Mi0y01dQ9zykI
dEkNH1jZjGNDXWzXX8EG+sr9fZQ1PDUg0VmzxIswW9Mkmcr06bP/4oONabRLgd60
TRJFYy6PQEP8sM97zy1n7mgcULC0AepOxf0LXRtTxAvcOtrl8OCQ8+fXGJkxz0Lc
65VWFE3x5mvM5KiZZpfy1uVMdb+6U9civW/6LjajNyCZIwCd6+iUJVKZoj/JIUTq
xhxTvxz5IMMGcb4TupDMQ0TVqM3PJ6Y4wxn/RLUUplKmX9nlmX+O+NMaGIY8dTHg
ye58Fv/j2n93gXeGA0y3QxgEqBdJchiVwsJJ99kWhreSl1MawY2FYM/5xBbPGjyF
IBDWO4avubRZE3UvZkOgkihxfWYIN2WVy16nRvxFyRf9aZt1JTidv5Y0M2c6AnKi
3RBpzxvjca6zytO9ldha2BMwgic0AWnueODGjQMYrWKWO1E0FYInY+2S08AiKlZt
bIJtWiBIdOLgbQgbXcP19Y7LNC78jJgUccf9vR00UMLQoh3BWptCM8qo1tXRiFXX
uCmNm2NLu9EKj6PNIs92o0Mdh2x7Wjkd+sR1LjMHslKLB7cO0Fv/Niv/1O47WzDU
htYShMq1jTX8OWz7x1kq1T844s1btwlkEyPRebRiJw5fC1lomxeQuZqg8RwZBWMt
YmF9dYtzFy+W3NtFEL042X/6KW7vWzoihGoRa2sh+0aU5zL7bnObynQAEGk9bK8u
c367m3NfZ6MKIM0fMjg6RkOLMR52XOtzIq9SdcipDTCUBAU12JgR03Jp6zzbq1uZ
JTDP8rMT3xCxLXnr9h3o+ZH0utoiQtj6nYq2ID2v7Z1/7l9aVYx+UkjAtDt5cg19
oD8XQ6bzWWJayOZTE6dUZ0d2yna8CdlPFVIXTa8nwigMGIRDrm1cndmvPO466Tv7
B9w97rO8fZ3uyMcPYWTyNeDazItN94HWmFACTFt837C+0qnNqBYx+RwXPCnwzo27
+GiscpYFbucSuNY6wJL1qabC/kjEu2Et21ub9JZ7uajwbHEAvHN8yOFwwFKnF8HD
6rYBWema2Z2/OGibKm3GpLgtlsWRqJfLoly8cJGV7kqpbVnovoz44Q6B28f7BB2P
0I/KGG2MdogaVOxkPjSNc03UXserM00FbF218FO2b2YXRnI0ZBvYwvmL+pQhE6WC
e0nNQj8OACp6J2nTqDW/V5t1izVx+tM8magwIsAseVy7GEXaAcTiuYtMOuuez9cO
Dxh6yobvI6OQjkZt/aM5USk3eSZxwnVSEwhbRqOA1Y1t1lZ7nMUr/f4P790BYzGe
Kc3xM5C/NJndE3hgyYKmgjAYhWxduMRq189ac5Uz0ImRjNnb925xeHxId+Mc1UeX
OqedOI31dBERRd0JQTBg8/wWq5zNy8YqK7cPj3nYP0Z7HfAiOuZmo1WWHM4rGdDC
E58sttIc22iHC0x+1vfBHuezgTyDnkrMsncCA6slWcyYXkjzhWJlONCcsv26AbQa
xZxbKx5Xt5KFG5XNy9SkQCe/uVJ5WSpWefPBASI91AYJXWhJLNOUhJIa06mOQjIp
1JikzxYkA9mFYvGNMDjsc/npZTa73gluwpO/AuAgHBGYaPmoFo+yrFO++vRRDskD
yp7h+PiY8ytKUg7jReqGi+5wJA22Czfu3ONwMKDrd9BJO2wFq6W2SCJES21f8Qi5
TKnHOh2QqmB94XB0zCWvdyY7YhQYWaXnCa89uMu9wRH+5maqZDdd7BajMzHurpIm
G5OSbFxmTCjze83mKIC1due0i4ZtY8RP06rdDe6RChmOfeC4CCVYklphqW8hclVb
1mCTjel9C8pms5D6aJbhT7KZfRVMl45S/aHlqoRc8iV5RhtV4iabtK2y3cluLktK
RDT1ODfuC8IFvFiRNiDqIzWaJYjQiqmVFlunMOeSUQJPoFZJDO6kT0IjWNyKouJh
+rs8t3ochwl9oHdmgoD0mH1hP+A1I8iaV/ht3T4RHdP1SswpqJxeF76g+Hijhzwn
u9ns//Ev+0rbE8SBl4fSjZ/3U/f32Q2FqyJoaJHKgrKmQ1RFpa6xIqQU0J2ipph1
7KhYHU88HnYt2vX5cHc9sf1nh4cJAXwvnoedmzzw+lzvXMQPDEF+IVlJ2KxqSmHH
nRqaPjIpiecaIz7StkndsR+zzqfS96iUW9s058EkSVdbsRZJUx8e+8Ceq3hqbFQm
XRZKjhErf57gEOJpEAiMP+sqgZGYcnfsnCdBwJT0vtlB1UxVc5q3XNQBuo6dkQij
wRGXLmxwcX05BZEoEIJ68eC6pHMfn1XMuIXQgmd4YENu7w/pShcfsJ5ibVz852CL
UykHwqoqabVirsefkAwzQtwGldMjkJgRREQYhJbekvD8dqzDYAdgls4QCqBYDUA6
vHZ3h93jIStbnTj7rwigpBh8i6QQqBTZyIn34gsMRyPOr/g8dX5zOljoMQbFMfP8
JHy8013B73bAjigStzjsnNQlPG5RrDR3imIyLbYJn5iiuFu5CpmdGvqjI66urfG+
MSW25t8UFr0wczwXr+49jNhWjR/t99RgqyTN3XbCHZieE5uNpCastFnGmvz8lQcD
LgRITzDzz9/fFvxqnv9WwPV2JV0QkvJX7Pmgu9m+einNOsY/N9oEHG7u9BQ3kbCg
OZStTpizwSRSLnBSvLeSJ3oQIxwdH7Fx7hxdE4fYNg1fjyfMVNz39KNrb7xQLFF2
4xneOthnr79P19/GSMQ7r+ke+oaEYVWmpT3NSWoMNRXaToKAaGQPdcjGyjLXts9F
v7FmUU9fSt/WaAjS4cbtO5jDIb1zK4Q2xMTdLE4acXWPm6gW4fkT9cYRN8jx8JDr
2+e5fumJMwU5+xOsIlo0dxR2BgOWuyl5lAJ2lS+LrWJba5BJxmu7KEFT5NlyO39F
xMPveOjDA57cusiTWxtZb3rGrkPg1v4uq9aLkpJCsJMdbiVXtTbuGGigOttkh2ip
Y9ZTsBDF1ntb+dS5Fvmy50yCiF0fdL8comzaJyEzv2o2G0xP7gz0vlKy6WjKFp+O
+pOFOLIh21vRDgs1IWHJjMZpSoU1uAwanwMI+NGzPzjYZRAM6fT8mAhGy2LJaZdv
ET0oo4nQIkX0xJ9Pfmcm8jL7OuD6uU2e3NoEAkLPxIWYZwjyNNE8vLN/QDeEDh4j
sXQo6rVrqRkjJqmJGjjTHzy5fC8OOkQ5Hhxx9cknebaTkM+E8X+8BfVDkkZDY6Tk
7q2bvPz2m/S2zsUj6XD4UsVnkUYMqo2wzTxJGrkpyR0zHPa5zxnB63jowRFPnF/m
3JTh96Jcb4/63BscsemvoEGAFc3wy2T3gkuo12RPpifjXd0UqTlgWUuz/3ktwppm
99x8W6lLuxIFQqkpoU+OQ9iPjwBOKlFoBn80bd9vxzBQFrHrFBOVbO4wDPGXVrl4
LpLbDGyAMd4kYV5UJfr0erMoHsLNOzc4GhyzvuqhNmg8ozUxaGEEqudWi2x1pWwb
Fk9BrcfuaMjK1gaXuuNs1HD2LsMBsI/Hqt8l0EjjwA/j+TI5nyIR6VY2OEgZgRw/
1kmMiInZ2kJR1AhH4YDuaESaASAgqR9Z2GbAcVGMHz3g7Z1ddo6PuXq5gwZhC/vW
TKZ1GsvptsnZ7xwFIeFxQDeEa+LVQ3KLDIkJ3Ll/l92jY5aXliGcjTe/jb+QgtfQ
OczjfGpxajU+yNfMadPEbM8Hs5eHWU0u3pICGjsflbf0Q2cy6Gxb52QtW2hOkCGz
On9HziXCYBRwYdnyoe3OOO6KDa3UTPpj59qcWOTx//zivSH9oce5MaVsIeOpup1M
YWy05BAnt5Cl/O81Lp02w5CLYYoF7cw5/+hg5nZ/yI2DA1jpMjJKIOqE+wVKeBnS
vzFZyerJ/7KFegCd4ljKKPg24mu3BgIJ6aBcXVoqBB5pLGkh/ZBmbc3dwKOztIy1
Fk9SBcdSkfAX9n0dttkkSHC4rRJKCCNCaEP6R8d4PY9zl84tjLmZ1j49OjjiQEds
L63DyE6OaIp2xHVw4uqRkZSgT5VF1qmz9fk6/+y+rNLklBoko4H/2fMx8ihdLpRu
ohASCszJEKqj2l8aeg3nmGrMHa7OzaWu89DabD0eOnFTbGT5m12Lp+zowLB/HPDh
y8IHz0VGzxgv0qZmrNwmjkl4vNpo6fY7I9G55yHw5f6FaPpzLU/RZ/N8/5GwiJ1A
qGnLaAvQc6ZoLe3XJd9kml5gmgkTJlzrY+pTiebUWmV7YPjQSoTChKpYkUb8aYuW
8dy6dYcXH95lc/MKoSaBsOQjsZhwxKrDYUgqcpbsvsrmM9PzqEUfjSiYfRsJ0ByN
hlzwuvyWZ97l9FdmkYMAsbG9iLLm2w93WVpaQsRAijQmQyuTO6YqVupX1Qxo0apM
sqo4pLapokPJI2MO2XURPE8I+wGd1SWuvOtphws5W9eDYcCxKuueoRdEaz4U11n3
eNhkwsGvSEr8JyseJCndmOzRus24MmexrWjDGKCi2l9yLYS4AsgYupe0/8t+TrQi
cJEc9J87WnK83yMfuO+M9gt+UeujpJa9v41Om9OHdY2jp/zmrUuLq2hqk58ZYzju
D1juLkMMt9XDTI9fGFVSiCexybsXwGBg6PV8rA1zuHEFMxw1gs4VxznVjkAojdLi
Tag2xO8tMRoZlqXHM9cvT7bTWdKeT7/uzYMjdg6P2T7fxbODYgNJeo1NOOnFmSuk
zctJ0ZJoTMLU9TxsGLLqeTy5Vew895i+ZPdUoi+TTWbeunuX4ShgXVJn+FaScxQ7
Nm8noHWoeZ0Fbczi7PkeASGbYniuF3VihJxFHsboeuXBAw4GAy6OA1tbaD8r7CNN
CfloZvOI0+FI0+BX2gTNs2T8ddofpiFi0BoHve8DOzOjHnqS7GMyU7tf2WBJG/J/
IudjjaHT9VlbX0/9dhzCeLnMTYoZ2gJ4nVAVT4S9ew/Z39lleWUZaxWTshh1QZlU
BnPVS0IaBWTje2QNoTHCMAw4DpTVjsel9XjMRc6swbs1NCytrKGh0DWCBs33nlRA
g3pCWzEwYEIDRjk+POCq1+P6Si+T1yz+PER7cuzfHw5HvHGwg/F8kgMlk3IAEhdh
NWXWVxqJ++THS9odrQpCoMpROOTrl87z3k7P8QxnZ1cECm8c79FdWY7+MR73Gpp2
bWhhxA3BJP9Ssm3KWlaDUC3JW24Am8oGp7N1afZ20oAMONUFGF87pQFA8eF0zkGA
Nrc6jSKo1oBmg4lJ1Y4KjEYjuivrPP3UE6m0wMYULDhqtxfrimLJGPt5eED/8Jje
ykYkI0a29qKtPS1snpmCNXcG5BnD8WjEfj/giY1Vtlc7MSohk7rtsxYE3HpwH3+5
R8cYPCtYMYCg891FcwsAhiLgC4YAtQHXz19i1bQJVBbE2aQ4Tz/54CHvDPqsn78Y
Z1th/L5S8RL1io04cJrqMWry2WxF08AGqAdfe/Eqm5JFX87a9WYQ8lY4YHV5JQJo
xkfAVbZZW+wDLXG2+TmWOmetc8j8W0KFtbveTmMjdnzgAVH75Wp9rNoSKiy8SonK
mba4s5NSMz79lbZPWT/0EodiptPheDDC7whPXFiNh9zGyYSeLAoyxxDAi43aO48O
GY4svVhMpB1clR97UJNfN6btiims9/w32RjyHIyOuLZxjiu9zoQKRM6k0VNu3LnL
sG8xKxYT8zBYieFgbbLP7AlFBkU7oEBoPCxK1wqrfo9nrlzFa54XLcwVCSCHQIdX
7t/lQC0Xu11Ug8Txa3KWXCSSVU5o4Eszd5uba4sSmpClpR7PXrxUTAbP2Ia4EQy5
cXyA73t4xqChRiiNUpoh65RrOZtl5w2/beFgpUVGPo/cuZbet+b9JmNxCDzwgYfA
vSgAyBtibfWUVbSliE2BUjop3Gi0UkUbQCVayB0lVViRHaRmrPZGoRtGqgTBss9w
OGT7+HXe23sOWMYqGE2qTMc0trKAm8/LGeTPHRzxoOex0fGQUZhZsI2am2Q83rZw
ZBDV643ppCWNpDZw/ppj8UqeSq1gPIMZHPDM8jFrca6mZ1QD4MuDgC+HhlXPgB0R
YgnQmAiIpPixdA5sgsCkuOVk5mDUTd6sxmKNoOIRWDjc2ecDq91JC6DkhWoW2AMJ
IZ4NwMD+4R5DXydEWFpaR52l4HUfBwiNUdM2Zj/tlGTM1ql40mF0MOJir5cELVZS
RVz1gcWiXJ++e4MHg32uLm1koH3NUSO7i/XK/G7RviS1LOKwaQm9dnI/V//AtIi3
OJ676LhTtaEpNkQt940JvW++pL7k/bgHPBwTYt0DnilGGq4FU6sMUDsQUVvSfI4M
XLX72c1ZphFfFXzIZJF4avAx9IOQ49ER37jd4Wq3cxYD7MlBxR7wykGfcKmLim0o
PJuHIFO7Ul3njbm2gNogYDwvJRQ4alAVhA5LRnn6XLeI2p2xQ4BfeOcR90PD+dUu
oQ7ASCxQE3HUSwMoODFpdiKUHE3NvGRHswG0YsAYRmGIWOX6cjfzN3JGHI6vIBI5
zRsPdxA/OnqxCiomoSKfkM0U9Umqi4dPDjUaI4+IEIxGrJolLq2uJ3ZbvXbZ6oJc
X3rzy4Qa0hMfDZtD2vnQS6pwH8n3CjVVfZxXHZo7a6/7VJk2TfHbGhwfCoC9B1Fb
LwIPM5GTVAkgNKv2zxYxJNz+TggjLaCjbaRl0sMjjoWRDgfUvRdKikKipzYMjOAZ
jyAY0T885tn3P8mS8eOsWnId1mfD+dw+Pube3h6bnYuxzy3qFkiFela+91alHFlp
2BSa1ZSI2zej45d034Fg1dJd6nBpM13x7KrBWPzr3t0HSBDQ9ZcYhRYrXuY8Mmov
lUqzEhk0m0O9koxRUgjVVChAat+nW2aDIGRzY5vNtQ1nhlMMyRdpbhTBB/EJgLuj
AX63g4qdNAakO5rHddj58DQDFVvhxE1Abq4xMOz3eXrjHBdjSuwCC/nCBgBFVz3q
DxCNanpsDU+/S5dEU/lGoXZQLC5K+IRhiwwraYZVc2r6+TLkINupYB3dBibjw7Ta
N8eF8irakIBNEfQhxJTYCnfmHbnn61/zmfm0MXPxmCEt6OnIHAvePrdkXMU9mmS5
IwOhH/W/h4MhWynKU8Wk+JOkOHqymNvt9kGf45FhY30FTwwQZN6jyvEnhtFOwrqi
acz2vJbXseah5mLVapqhAhGGgwEbG5tsjTUAOJsFTwBBMEj2RqQDDCKpzd/YM5zg
wkkMlRqZBBnDwYgr5y+ydu5chdk4qX6EmT3ppI33rdGAOwyRjo81kdhUUYRnnA5Q
ruJmKo4pZ967mgvNmVCySKBcWNlgq+Mn+8ksYtDltkia4qDrhyEdzy/y/0+RW5ch
WO5t40AvNXusW6rIlz6fyJxVuM/knTm9jl1+EnDHPRAZet9SrECyaocFwTD32N+Z
BADAW2fBYJYy+ze2M0I9xWPSdxnJB0OognoGfCatZ9HtykVzFm3v2RixALh79xGj
wLKKB2GQUi9MvYopgjX1dfrtRj75TZMCG8WI4fh4xPr5bc5trcYoTKbSYCHXbNkb
7R0cRBmdOjqX5+Q35zkuEvsWYwz7gxGd3gYXPZNkwDIP+tTTir4s+B5ffvSAO8cH
dJa2sKqLH7uk50MMx6OQDa+b0gCI5HMNi6sGnJAiWUxM4X388ICD3T16ve5cxr2N
TNPMAbIzAKheREWaNSeeMXH+eRbV/C7X2qy/cL0F4Md/eqs4bNrao2VISVWzZt0h
TpIWgK2fzIpGr1p1Qp15NXkj5UpniSdWeu7pPQNpqLUWYzxefXSHXQm4IIKGIeI5
RqtKgKlAVJPEp2Vts1o3FyVBVIYZzxgGwwOudHtcjj/inYHBH5MwmRRbxM5Rn7fu
77LU68bn9jKp2zI4jpQyfFhannXrLI5fK8M2UfDijC0YHvGct8VK5fpf5HmJnu1L
9+/x8LDPlbVupJKZGbl0YCyZIkCXo9H5PloJEpd6Js8QHB/z3KifOehcdFNkU0K+
Ngjo+D6v7zzg9tEuy6tbjTP9avea9R3OOykN+/wr1vSYsEy0cQBcrjfgWllawXCa
sPa2R0L0VhQARBb2nWJUk0+xm2UI4z8qo/cdF49pw1ClWJVbTfgqTuefp+dM1yK4
+hXtxK2hnUg852jIh9YucWX7QmbtyEIR/VTbFJFIo+1z4TH7K4qnihWTO0MeE3Bp
Rh8gPQ+a+n8SuyyTb50p69/VesM26d+QrDEMEYRdPrjis0qsOGeJhIBEF3bcxwI5
ndT7feFgwDsDZXnJiyq2reSKMcfneqmh06jye9JyWSjTmbVQqezYLIWNKfSHykXP
8q9c2Syxc1J+u0W5/Cjz/MLBA0Kr+CJR+6XVis7rhJIZYpK6ib1jcjTmemmRdiGZ
S7Jc4vJwjQsAD4OQa57yr127kPnGxVYCjimtsRi8mD4dPqP7vG36bIpxHnGX+hrJ
FsKrpKngC5BJ6oaRmmUGh1dHkJW5h6lyeg4VyPw7qMOlapbeN599SS5UcND7ur4j
+dOSWgSJfH6DI4Bpod462mBpZZqiFxxT7szW/5lV+Kv6W0FU6eAzOBqwubXCpU2v
5VMvhuUzWJAO+xZ2jwYsdTuTwrkmIiVlXZvJgYmL+NXN2dB05vK1A6MgZKXT4elL
l3LbsQaBeIxZaZF8LAoY37j/gAfHR2xunEs6/jSnOJtx/lo5dio6x8r/spGzYDyG
wxEXVno8d+lCbtOfLTaGPvDg+IiNzgpibVzSm34HySQKWoBhtbHcT7uZqJ7r8SMe
HB3z3PY2X/uu90zWiMiij386o1V8L3JBLxw/wvhTEHpLUitU7XskRxtYh9nkf29m
2fW5FZM9X5VS66cz7tqKlneVt9IBwJ04SfFPZw3I1CZpPlusuaEyonRU2Okrq2sB
S3HkL6V662XVn48bd4uM983dPY4fHbHpXWKk4IWzgJjintups/FK+UGGoyEbK+s8
ffXpBO0xEvO2CV5j7YfTRQC8dGYWP8LtnUcMRscY38OG1oGStHTOM2X/9U1IY1Qo
FEv/8BBfhcvbl7PZlZ4tPoaHg2N2Hx2w1F2OFKUllpXWqhZinSmImsuKUrA2JAxG
mO4q3aWVFG62+FikyfUYDYA37t9BrIcYk4ZWGqz7djxyc7NHU35R8/T1RNdSEPv8
icO/C9wGnmjrpKd66BmMldaUk5UbNq3ML6teKdQQKx0unduIfanieVI4VZE5sCie
XAAQBZ63dx4wODhi9VwXG4IxaeHJ6ll1szumPyQzBgCuQDhxQP3RkOvb6zy3vp3K
yqLVbCiDPh9/VmoYF4lr5GCAe6GH1+uh1iYnt1KBwFQQh4iePBWpAGI8DrEcHB9z
YXWdS34n99Gz1Y8xGvQ5HgwRs5TrzIo3i7oQrFRXRJpPROaX/TcJ9uwoIAyVzY3t
JDc9I8MvZGtc9qzl5qMdQhNJHLci9iq0bWoLv9PirH8ezt9R4Stlf19KgSyN7HJN
YH879vmTACAA3swEACUPX6T6VIrq39pOZVQ0dXYTfVnrvnqxFd/p4g5o9oBWQkZB
QG+5y6XLEfTse9Kg2SfdG78AOzPmLnjnwX2GRwN650vabSSRpHW1XNZSX8p041yQ
bB5XMlshEAMejCxov8/51NOEjGmdogI7s2DOf/JqNo4CJIKe7xz38ZeXItjWsZbH
osmacQyzBpjNKFHHdjRTeaNgOj4DOWZkQ97/5FOT30dPK4sAuDSPKwHjdTDdZcKB
oShkUal5WZNgtLR9DSFflaiWQIMAPENolMuXL3LmLlUIdQKN3d3f4Z2DHbprq41R
pHKaWxzMsXKCVO15/zdNjquN0SbXe4tqsTi42le+Gfv8DOR/s/lAj39n0xQt8Qdt
o50/oZIV9xm9FoKB8Q6w2ecRJVsm6Oorzy2MVGaJVjnoqPf5eDTg0lrIB6/2HBs+
z0OfDoBkcQxhXGL++Z0Oh7rFEhLxoWuiQT0JWSTq3lfVctefLs+vrH6tE7MooZ9W
xbeCEY9RCIFRvM6AK9sJ9aydZNjqOKFboPPoXKj+cP+Im7t7dJeXM6wlY8qsaM/Z
bLGrzur8bTbPzAT0DoVxyU5JtLUtKyimZ7l6vpsHl87MNX7bcDRiMFI8fykuOg2y
RWGSkmLViqB3ynmxKSpnsJm8UByFlWFcgOh7PmE4xB/u8rUXtmgaoy/UDIzpigUe
HB7yKAxZ9Zq1AGZ8UooGe0Lg4wrWppCrb7enbKHPv5BA5+h9EwyzzPdLIS5Vhx8V
1VRZnZYnzwmqMPH16QDg1XaARh620haKVpQ7/7KJ0zJq9HR/VJga5dxO0CqAtvoZ
BnbI1sqAd61IymVVFZ0tZjHUMfDa4Sp2ZRuritiwQC+hIpOgoNqbNaFBzRcGauMN
JYAXs9gpQhgELMkhH3juejo8KxCfKYsqDZQ4k9tHfR4eHiOrqynUPK3yJpPNPDk5
mOvRktYCkenQzIwNbWhZQVjuKZ45zlkAOXOETA/7A3YO+3S3ziGEGEYO+Dmd0EhL
y9h8PrRg5o1jJxlCLB0fhsNjtjXkQ6sbk8dUcxZOAcbHXWZyHPbOw0eYXg/jmdbD
mmVGtI/pBNaFBpnKlVJOh+f+tNYhQ44gv8IPveoKAL5cF7Qp5fS+BcMbt9I1ExEq
QvTZc80qiEwSMFgqYLrM+aRH0+5JjCXUEcFwEBeZSYaeMYs8LHYDzv2DAXu7j+gt
L6OhYtKOXt1HZOryz5N+tTzyUgX/1+zM3BpQgdDEkXLHx9Mh3rHy9Ob4ACDMhSGS
CwAW6PKyfuT1vUN2+33WV1dyTPMyOQ7TwjxIptp5JkMluV72NBV3RtjKYYjUEARK
GNjMyLtIfxe5CxDgzt4xh8MRnfH7q4mRUQd9jAti1VnErxNU0mY0LdNzkrWD46LX
kYQMwj7PdlZ4rrM6GWD3nOWR0AWYCR0HANE/X7hzE88YljpL2P4IMQ14YSQJmySf
aY/XpWpJ8DZXWC/a3JJz6xOkOtkRpQyf4hKsc3+6it63kP2nu90yp9H6ZVcA8Hrz
GMfmltNs9L7V8g7ZGEgz8ZAm2IprdKRMzEgzFKeV21RDwnDEtWtPFRyLKfOWUpEs
PMb9dzAYEQxGdJa6qGVCezp2AFGld0Uh0hjGsombLSVnKs38qzS2s+FEYEJCDNbv
IkPFHI+40umlIn9xGLfFczVKtoX19sEeR6Fl03RQtWkdv6xzmLuxKqQMzXM2BfEM
4LO3f8Dq8tLEFpxVKub90YiO5xFqSEjUBnjahYxNA9bxMYsohKoc9Y/4pie/lisr
S4vk2htckrHLB8AX9u7jhxJpqzTUi3fizJrTFKkMhuaD4miO813rVbwn/fmSDwYL
gcWYC6RJLUqEwYm6g6Hce79ehgCckXWkua2h81mYOU83HtBAhGvPXK5w/ixWhF1y
He8fMxgMoOcjGkkZkRVpbnSCI86Mf9oxL79HIBB4US92eHzI5c1NLmys1dxp8cY/
AEKBpfjZ3jrcAc8kxk4X6bmr17CidFeWOL+91SqkX8Tr4NE+QTBEdTQOf2OissXc
xcZC6Cmhr4Q24AMXLy80wlK572MD+umjPV4d7NHzfBgFJTwGTbnWHy9/s21Ts66P
beIUxIkA3CRqDbjsGlIpSbLL6X3bDIZJwZBVkZZLTbA9UWS1yRojBIr4hkDAhCOe
XbGTcEOaxBALeL156yF7h8csbaymYFsdC/BVOvUyQZ964qcGXQHi/p1OVAEt+/t7
/Pb3Ps2TPZ8kfs6jONJAEvQxOx3gtf0DOkux5KlJcJQ0cje/ouX66uJ0AVExQ0pV
A6pyPBpybnmVJ5eWU3eUytPMRZ2TN269w1G/z6YxiEYkQJPC1xNEAqZBeCbYkAfH
wYie+Fzd2G5oexYsHJMkwrq9/4iHwYD1pdWSx6yyLg57ouX2ZH5j0t6vSAnyoKWf
boKqT1OPpXcpKQIcAS/lA4BJ8d0YZkifqzhoCrVhJiYanW+NzzyltEJTU8GB0k6D
O2V6SrOsvINKAgxrYHdwxFN2j29dkskgdRuhCIsXGPz8nQEjemx6wlCV6BwgMUqS
cq2aWYap98jwvSSdFNlmtoogTVKcXVIoKshFk9FdPeMzGA15shOwGt8/CcQk83DK
4lWkd+L/ALxyNOLNA5+l3gpGwYaSqsjPu0ydqJG1X0ZaEYDJhH50TJ8qmocUk/0w
fj5rhIOjY941sjwvnVaLe9Gc/wh40Yzwl7p0DFFbWnrkG5zvt2XdK6P3Vcllhc4R
izo31BgOd/d5ZmmLb7z+TCWj+eQXC1UCkEUZb925w8HxAdsb5ymqtmbpeLOK9anu
pcwASrlAi8yCWhZh+jH872qXFs0GbtVn+abQu2ZLeD9Ey/Z2ZFvTJ+Jk2EPD8Z+8
FC//QgAAUXXgt7tjLC1+cS4AmX+cWXWWMwfWuprIzsZn3c+f3+bc2mpDkHQxr3vA
WwOfru+jNsR4fkwvmyk9aoab5FEgbTOuplyAoyB0I5H4jIZ0OoZrm714KVvHAy3w
jKTK6d+4t8v9R33WznXxETTUBst0Wj3ymqC4dtfmRL1FsQjXty6yvrqSQV0WC4yt
v4bAoNej0+0gsWM2J1B9UeX829qoiPTKEgQjPnz1ea56XnICKlMshce1HRI+LF69
dxcjHqbjYUOd7fFP3DA3nb92Wqm21bdUEQRlE4iS+2S6/fIBwBdY6M3csu9WZzvM
EwzBYMS5py7gLXVq1tdihwR3jmA4FJaXDGFgMZ5MCHTKzfg8rhbLu6AyGPX16nDA
ylKPrdS5s5y1GbBRBXf/+JDh8BDP9FCbemZ5HHtJWuwF4uf1uPrEdfDOaulfggCI
VTpiouJ/A2IXO2zxPA9r+9h+wIcuPZWAZ/aMDb61YAwPgxFfPrjP6uYWo4lS5lm+
0oXIC7uOvlAVALw8Vfw1w4HlGL7RxlSaWpERSS5kmf4wVRDECA/39lld28Qj3SAk
uS6CBSL8Kblu3dzhcO+IpZUlhp6NjPmYxEfnGUBreaTqJA3KfSAF5437/AfBkLWN
NVbOReIz4/LF8sqEBQ0AEB7tH2FU8D0fjYOCzJpVG727zmMOqEEBtM2GwKoSDEds
rCyduYw/f+1Y5WAY0PFNdASCnpiiZJ24Tx2Vsyp4vsEzluHRIee7K3zn0+9K4usz
FouN3/ezj+7y8sFdOpvnsRhEbEyZnazhiLPNOhTfYy3WvHqephK/uc1nhbiPZOv5
22b/OqfnSMakdl9nfLyf++iXIiRWc8tX2hM0OAbftdALNMDOoXH1mNPQyJU/m7hu
pQkvu7UB1vfZXl2a7DUvHQQsqNXLhEfx6xzvPmBvb4cLW+fwJSTQItfrdEpibkrU
qHWlqMYtbW4rigj0g4DOqnB5ey0VnmXfdeGZ6DqxBsC9e6x4PTwr8VGGZIOmGdnl
qmJyUVe/ccP7KXQ8QzAaEA72C3tNZzJsj2GPBBYbGryOj4l4L2NnEycks/T4S7le
4FQOMybnCofHHBzt8U3Pv5f3ry7HFNMa9wfK2YHD/OjhXjh+wJ4Hq0YYS3pVsOPn
FzPF+i6dk+MvO++vsn8y9covVz9ooV0gjmNR9xr+UjYAyA7WG8At0KsyJc+1xtVF
WkFxWC9eMh+ebedl0sUlWhwjM/4+wygYcH0J3r29OXn8cS8ustg5j6KoVUxcdPfW
cchRxxKaFJGGZiHo9ghAnbOKxqhIc9IwfkOwRhkGxzxrhOeluBXEHfYs1lyoRYxh
GAS8cniMXetirMXquKtlHHTOoS+5dEby5bl2qvHqdWFtUgVrJ5ZRFx8EKxpdAYyJ
g3pF5yDnlehraG5FzibVrKHF8w2d/oBv3biYRGVST8S8UDsjtWm/eOdthp6y5hHL
MU9Ty6PFIHo2qK7kPq7AxKbex04x19ogSJQWz1yLFNyKfXwSAOSMjgVeULg66QzX
tBJ29cNYY2udUtJAIFOZsQrP3jAyH7+ZzTxP4bNGGAyPeX7F8r4rWxBn/2Ne9MxE
j0vPy5IrOW3jlgLQ4szgiwOf0XqHUCIiEU05/ekeU2sRljESkMcBmopBCxBYheCY
37p9jiXn1lh0vjmw1uIZw639Pl8awmDNx1jFUwiNOta8Tm1bq4RINa12p/lmzvor
CEasLRkurI8LAENQHz2j5QDjPeJpdNhkp0/iiqinpL+BTDfHVGvIwF4w4D3r2/yh
y8/FNiqMk5FC8YxzTTx2qqzU8LwTDPnizbfodjw8idqunRC2NAhn5gr1l+yZwsPo
pGlM4mdodSDZqCOhSQt1GVLu7Id6IR8t+I5bviDod2QzhFyFtk7H858975cJW3C9
SZuPNPF4CC02aS10VGGJKmJgMOiz5A25utydBDCCIJIaHVkwFdR4yIzRCYn7w/6I
m/fu0lvuEYqN2f5IgprmQFMlTJb53xIb1VSfgbbat4KIElqL8T2uX71a8oSyqLnO
5PIkGuW39g/Y3T9kefU8asOJ6JXMCenKzIK4s14XZBlVwUvN3o51GYIBYTBc9Jir
gX3ysCIMbUiiPWkb6vI50tmMhy3S+6btYVv5ZkHxfHjn7i1++7Xnee+F8/EWC0E8
55xV9U+d7tS57fdn7tzi5v4uy9sreEp0DCMUBHuKnBha8yYyp2fO0vuO92oBMDYJ
FX7mGKANyZfLEKqUOPIyfRWl4LOLY/RC/mt8x+N8rpyooI0zrmdvkoIUzTTZv6TA
C4czEMc9pY5aMkIIrLVcXtuYDFJI1J/ptw8kT2/XjTVyYVJg9uU793jr5tusXnuO
kOisf5IJqGYk39qz6WnJStESCg9JraKKfDUWN+l0OlgRts9fTC1BWQTL1iYCAODN
gz4yDFkbGVRC7ByPkLTxb3ViUrL5Vs3eFgjDEN8YVpeXKwPG2U5ET+fa9IW1jsfx
wTCSOk7x/2hpBNBEIrgK0m0boCZHleGoz6bv863veX+yQSTF39GW2vk0sxEHOvGZ
W29y72iPc+fWMCqT4xdTmVw0zZRnDQ6LPftaM39pCW3N+Jjsu5etmGrfVrajFKij
Ps48w+eaBACfLxrqE1ocmYPcMiij6glMg6BBS9GA9J9Ekxbh+IJiR5auejx/7cnM
34WpzHlhkx+bgiYE7g4tQ+OzpNGRgCkQ8+hE3GfekfR0MH1cOzAcMbDQ7S1zflx5
LmVuZ8HF54F3dg5YWVrGCy3qj2HD035umd4J2JAlv8P60nIj1GiRCwHXBLq+YWBt
hD6rNhyQZm8pc5wta4RHe7u8/9xl/uDTHzxtLz6j8x8bpCSL3UP52DuvoB0PXz1E
yVROSA2SdZr7pBm9b7OTf537ntC2q+7zjgBAXR/aBTarNrcbyZBU9FT/V7aUfrYl
y19VgNHg3jpxhBK1ZsUdAEaFpy9dSIUbWfb8hUdA44e7OVA63V789I5aCW0KWWjj
78QRs7YZK9/36R/u8+D+Q558+iLnx1mncmLtWic5B1jl9qMHmKVuameYKZCu6t3Q
pqfTtnRZIiYKWFQLwUTlyeMC+isFhsMhozDAGomr/22DChX33tDabK75OI8zzkgM
MyRUy6ODXf6VD38LF4HRMKDT9VFMafavCzPO8YiGMZbvwxduv8MLO3e4dPk6HfFi
FDJFXqNSw7eiU49t83nVmbZ8Xgmwek5cyYzMYUYz99h1BwDF+w4U+Rzot49XYxt6
32YTog4J4KaVkHmHZNMPkFt6OItIjIJNw8hSHHCrFg2OeGYjWyrlzwTpndJlss/0
xu4Dhh1hyXopl5Omdi6Clqp18+Kg95U0dhR9xsqY0GcsSdmkCFCx1rLSXWXNPOCZ
8yFbnpd4LU9OLuU6oWswsrw+OOCo26PneRgdRQGwtIGDcwYlnqTxf0u+qFVL0LQ8
FNkwzbKqeAjGmEaeXRZ4errAU+c68GhEgGLGvBM6kQFL2RR3yK9OBtT4HuKSVW5Q
SC2JvTUC2u9jR4d8w5Wn+MPv+mBqf5cHkE0s6WnOh4779eMH+8Wd2ww6wnZvCYap
ozBJ7LZKVZY7L/QvixxrCl0s0Pum7JY4KHgLT5rbU+l/5hUE6wtE822l6vhVsS4q
Z1o+BwyaBAAAn0EiSuD2wj519iQPDZUpiDex8DXAo5QPZDpK0/GJqAq+CIaAYX/A
1fPrXNnsODObhRWfHfcqmugJrYbcuH8P7fZy2Vvx4XXaiNMhV5noKdqEpV+a8Uko
oFZZWl6hszvifedWWBsvl7mSFp3edfvwiHcODxmtLGERPDvNxOZqaESw1mZHTtsE
Fe1HUIzgjQMADeGM8rcJ8N4rF1h56w2sSqaNXBtnnG32THNroTHa6FlDX+Dho0f8
sQ9/O0/5kS3q+D4JiXd7lo3T3Tfx+vQ8EOGOKj/39sssr6yggY0RVxeErqf0Fs3p
fd3f2iwYaSxm1Mw6TrG/9TNOpLXkLz8129bSKT6rpzCZbrxt7KzGsKwgDAdDrj3x
BBux7rk81k00RQAQP+CjobJ/HOLhZ49E5sVYWVk3pg6gtMHIqYInjDrCcBTyTGc9
a1Lik4xFFP4pu17feci9gwP81QtRrDk32tmyIFjKgzWxhWrrRjtLwfOSxTVhk9RY
UOgxVDTMcj27cZFN04NRbFZNhFih09iZOmi62cgYBQ+DscqKZ3inv8/V8xf43uff
l3Gp0YGFZAGBhTxoiUOVcTvywS43H9xnaaUXHRmTSf45XSpdbfwbKdW8TGe+Zl5e
aYb3Ke3i+VS7AGBGet96dr+yqEZabJ50NmsrvkOd85X/rSCENsQTWPJ7rKwsT1Tc
6iGkxRSkuffwiEE/pGO8FM0mueLLpnrbLaGgKe9iVLBW2GFEb3WF893lUltrZeGl
gAB4+fARQc9nVToYhNDMb7trGzMTebopA+UIwQlsVAornky6paSsMnoBr/G4fXj9
HBdMh0eDIZ1udN6OeJTWZuSOLbN4YpZYSXS6UVCgq4auKsHoCPYO+X/+q3+Aq10/
Eu80RYuW5yWRUid22nMi5PlAf+m1F3k4GrLVWUMTPvK0pOwp1fi4fYLKuDZNHDa+
fG80a40/acTCVAQE2ioA+BKRZvC17As0o/dt9gLT1kS66gZsLAvZ7p5pFfl0G4rv
eRxbYWujZTuciPsxH0Oh93jqj+7dY2dnB7m0XTM0DWAsp2xpOicpm58m/iVlTr2o
QfT2cIf3XLrAs+cvARBIoiJ21trPX+rvEnjCkvEhCLBCNiBrCf4lNM/jOg5i7gVt
brhc0XD8J8Vw3GLFgmewXqpZKwedn4V5GT/j1fUNnr16lYdv3cFbWmFkSBHrUGmn
tCZfbBhTkZaOBUGNEPaHdHodPnfjVX7vtffw7z7znkm3bgglmag0Wj+nOz+aQQKP
R5Zf/NLn0ZVljOkQBqNTfCKtd8ja3m41cfb6GLCA3PfdBP1SmwBAgU8A3zM2zlVi
PVIoeGiShbfZNBWkMynudJUpAwq1SOxZxECIwuCQr1m2NbtnUemAE4f8pYcPeTCw
bHt+XIk7+zuok3a8bD7rCyXTDJIRPbMBIwx39rh+/RLPb0bMc6FEAZqXuuVZcDgH
wCv7Qwh8fGsRta0cZrrCfFwlrfHaF9VM3NkaEXCKNqkjXBfEKCMbMByN4p+Zcdxx
9oKyELqe8OGti/zyCy+xfGEZPD/SCVZbm7C4s2yZYp+CYKPWXIWOCsa33N+5z3k1
/Lnf+bvpAYcDy9KScT7D4o68QApD/dm3XuOFhzdZff6Z6Oz/1J7bNn7cMSH0tPlb
BT/qY/IVSuzLtU0AAPBrwPfU0vvGwYGoVKAB03D7p8+CtDRz0RSMna/cFG0WF8tE
hU3AWHaOjnlGjvlt20vFBLciziXFevd492T0HCHwM8dKsLLNit9hMIrZthpRUFZX
sepE+SpfwJOrpJJqeEwd2ZYVi2c8tnZHvOvysFBmtsjV5a7r9YMBb933WPc3YDjE
873GCq52XLeprv2UrHnBTvx2o1pLKWu/zdKf2jTbdcfjcOeInd1duHotws7kbJIB
qrWIZ/i9V5/i74Qj7vV3ubh5DoahY/k3gaXLAHYpTYAmBwdiMRrgYemgHIXH3Lv9
Jn/lO/8QX791Hg6U3lI22K6rt3j8REyRgJFaxcSI0Y/cf5WjjmErlFM+F6ckSTQO
WxSREojJK/vVH6ColDt/HSt8poKMpvct2mVtgxOOfTnTBAAFuKo0+5cm0rsuKtK2
68rNna5SlDfRBrSzmQYLjQQeRliuXj7P+a3NGuxMS0ObRXBSt4C74QqdTpcwtLM/
hySNl5IeAXGhAW2LeSLHD6AeDHWEaMD1c9vZxZ+6pRQG/ARqGeZwPXzwkMPdPmsb
K1gbEsaWQlKCUio1a1MSo5o1SRGVb3urr5VZ7tiYjVnNlEi9MBSDHaNlZ6L6wn0F
JkKSvubKOb793e/hx26/gr91gZEEsQplS/6LRkGBFkyZjxIape+FqIywXbh9+wZ/
+MO/lX/36z4cNW75guenrc3ZGHMNQYcBrHT51N4Ov/LiCzz51LOghiAYTo7zTi8Q
yHoIzXHRT+jRjaZEnRznng2ol52uUNxU3Bkth7kyH02SsakCgN8A9oH18o3QpL57
WpIfSjOUfPZeBa606dQfk+cNRwFLl9ZZXu7miuXqjikWQ5suVlrg4DDkYPeAjm8I
JnK/bca/fAsVkJiyIKuxbkSWKz0YjVhZW+V8RgMgoed2dngumEKjWkWMRIJGGmBU
JzzxiWtwi4FqnYmpKuCsHIb6PVXWWSCx9nlnrOkxJqI5i5cHx6qsIvyBr/st/MJr
r3C4t0uvuwoazCUDbvIJXyPK8eGSIEtLvPz6S3zTuSf4C7/7908stHoQxJVKZ2nE
jWdgKToC+Okv/Ca7ewc8/fyz7B0eFxj/Tt4iaglhUmKpNYOwNPcmzXsJ6u4tDe/R
Cv3YR/iNaQKAQ6Kzg99d9TIFdRetMixNotcS6F/qGQObuGeXCh4xFzVEpCqDQcDa
kp9rr2nCcL4Ym3MMDj7afcTew4esbm9ipq6RqAr5pjGGWhofTIRTFOzQcv78ebYu
nSvcRVxaQJqa3MfMFDjBP+Is8sHOHqFGlLOeZxICnwyMmzyzdTTCTDJ/objfMtuq
SjM8v4dsreFKAyueGIJBSH84iv86cUhSZ/8WyG9NjuwkOib7l69f4VuvvYsfu/MK
zz61iuClMsBmGEr2BU2xrlKydm2iRBgCHYGOz5233+L93Qv87d/zh9kWLypP8tI0
ubLA/UZlUYCwa0M+9saXWD13jv2jIwIN6cjptvqlyXes1HuefDdHWR6Thv2L5EXl
/q8GUChXC9TWY/aJ2Je3DgAAfnUcAEStfQ3iHRmfbE2b+bdz/k2JhysBPYmla4zB
jBRPDVcuXsqmnDVlP5oyhI/T/YQa4mn0Ll++e4/R8ZCNKz00DEsgyebUza5PucGR
ZiZq4gZzbaMiQqAwGB5zxU+ez6TclllAC6iplS+qeHEAcOvtd6JiPd/DSFhZDaNx
EDoeU5VG1ioTQmnpXDZx/m61sXGr3yhUbu0eTX4fQk2r7OJdkhqrAbAC/Ae/89v5
6R+7ye7BLturG3hqCEMbs9TGWoGNj5mUdGOkxd1VARbfE7yux+tvvcaz/jL/6Hv+
KB9cWokeTIBu8vfmDDj/DGBqI6Tll7/8Mp+5d4Nzzz/DwAb48ZjqiVvKYpagMp/V
0xipG/9MtOXRnM72fDKhV/7Vqk/XBQC/ZKyZVGlXt/ylM8wmBX9l1DpaGQlpGfSZ
6sLL63pIZbQWZ5wSbVlvFLJhj3nuXDe3hsopKfM50OOg20w7z1AED3jnyOdgrcuW
sXgjnVRt10Famd6ucbJU+AvJCipV6stnoWtNqZwl02wmEs2KENiAd3PEu32ZZJtS
lW3KYiAxY7dqbYjn+QRBwGcP+nQ7PTomLzUXKzCOC/1EM+tTJO5NL+QlFBVHU2JO
7mOa8ozWpXmeZD5plyX4vS7vBH0OgaW0yT8T4hjpHD3iMBw/9ree2+DPfvNv5b/8
+E+ga09i+kK3u0bXCqidHDaKI4tMj1FUeKxZYMrEn49qjPGspaMKHjz0j3nj9tu8
r7fFD/6+/1vk/Mdqy/EDGmmPMz7OmvOJyY5ADH7oi5/hqAubPQ9r4+JA7Ak+AW6H
L5KpqxF14kIZg6f59e2ignYozhaQvYK7Sq0QlWJbaUmmL7XSj6mDjOjY95dmCQA+
DhwaK6vWVO3wMnrfumVYVjVr63KkyrzFtF0qErWY+SowUK6v+kkAkAlCpCKfWBTD
ZgiAPvD2gRKs9AjURvT5WofISGUSL/kAcwqHq5S1iSb3CIFwOOIbr67j+71Gq2aR
Lgt4sdX+4mDIK8ajt+ThCxHtbL5RL2Vj0mvSOlrPpGIKmxv9OuNbgmap4PkeN4ID
3sHybkyCeJwhBECz/nUikfWffu3X8RuPvsw/eu0LPHH+CUKjhBoRaJkMOUKdJkrq
W+JOJSsgajFW6SD4vrA3OuBLr7/Etz37Xv7ud/47vKe3DEH8QN3kXp7MlhOe5riO
efzHI/Rjt17n5+6/wsWrlxlaix9X/umJntS57Ys6EAGpRcFMw2/RggOu3pGSSUDL
DVy+BU0a7d34OrSqH58lADiIggD5DlEaniHPk963mfNPR2Si7Z6QlDEQoD+yPHdu
netrSw2c/wJuQmvxjWFnFPLOrdusSwcrQoDiT7aANBukMuMms8hvVJdrxocxjMIR
ly8/G/8uaLBUF8MAmvgd/NhJvHhwwMGwT6+zQb6LYVKvoGSDAtWcAJfGBNXzgEKn
25MiEQJoQ48b79xheHSIrKxPkJmzFAAICddffjS+/1u+h3AQ8JE3XuTK2nW8pY0I
OYvZk6VOZ0FSabCAUYvacNIu2fENEga88eA2R3u7/Nmv+138md/xXWyOV7k4lro2
ijtqXeBJO/6xu7SpoOWffPrjLC312Frb4MFgCEYfW4lOG42HdveyudvW+b80C0gT
Ie3y1sUGCfzBLAEAwC8ofIe2BptmpPd1wCp1E1ZFWaCp4MxKMRkeAxyHhGyuXWQN
gXAYmV7P46xgnBILtdw6HLBz2Gd9ZTXKcgzYUEtIe9ql2NNuYK384wgKM6p4xjAY
jNje2oh/Y85E5i/x66Uh272jI45GI3odQa2dVD8rGb9fCGSL0+EIQgutt3Wta+1h
V5PaeiKGVX+Zw9EeD4JjYD2We4qLAc8QFFA2amue4e9+x7/Fn/7JH+anXn+V9dUh
25sXOO52GMYUyE28oQh0PAHxCY6P6RpDZ3OZl+/d4PjuI77r0nP88W/9bn73u94z
mRnfTmPjp0WBTsa5mtQa+Pm3X+NTt17jwpPXoS+sBoZRx8ZxsJzQU7gZ/1yJT7Vm
nTRy/m42QW1iCBvc3Zb8vlFPG4r+Qt2n/AaL5WcR/rtm8zXL8iuj35x9SdeWI8bw
nGXEkS+cv3QuioyESHlGTS4oWXwr985Bn9Az9MTQV8UaImz9VPOFpkU3drKbjBiG
1rK8dp6ttc2CRVzkkY90z2MrGD/y/f19Rr5gxWI1qpPJ8OxJETycrxHXuc21Vcuy
12GkPm8d7cLGpUjXgLN5FW131J65jOFvfvf38p2vv8I/+OQn+NWbb2HPb7O+uklP
DJ4YMNGGUrUpBxMVEBvjg1oGdkTf9unbAYO9HcxOwAc2L/BvfPu38Mc/9Fuj4sl4
0k0bApEKE/S4jgnC+Lu9OPsPgR/43Mc52lpirePDwYCOGFSj49aTWdvV+fY8Rkrn
JuBFTXKrDd+7smHxZ+sspt/AQH8SuA9cqHb4LrM1Pb1vuR50i1hQmi2IcT9uYAz9
YMhzMfdMaDw80eSQ8CzkobFxuPlwj9AzmJhXf6x6WBuwyXzes45BMpNlolEAZj1k
qcvBwR7Xz69yeYIAnJFLU0FWDAO8fX8nQjB8JVDNoANJO2CZtnxFhckYRLOaAtTy
Kn9aUrw6xYgaIIhUJY+tx1s3b8OVdyPAiBAfD8zC1GJOGQRoqrVR+NeffTff8tRz
/NDrL/PP3rnBK2++xaPhAPFAPY+ut4TneRMFQUEgtAzDPqojRscHLBnDytoyX//M
c/y+6+/he5//IBvxIjhS6Epy/FgY70Xx7k3NTsqc/IvXXuXTb7/F2nuucTgI6Ymd
oJPzuWzjxF2bK5FXAAJa4vxlhhU3RrttxeeaHA+Io1tI74N8sh4BqH/+EPg5gX+r
fEU2zVmkfkU76H3zqGfdV9g6VCet2zNmf7TgGcP60QHP2H4q3vNSfeey+MYtfq63
7hyxM/A4t27xETwVN8VpBtmYj/VWsaUogKuTxLdCN1CGBkZdj4Odd/gdGxd5olP0
d2cntxR2AugfKSumE6V4qpP4IELvZXLmj43Xp1A4U5dCYWxqy5ncPpSQekKRBvvQ
sXkEQ9f3GR4LL755G74hutPQjuiaqADV2SVyZmbNY9J0F6/Ti57Hf/yu9/Mfvuv9
vHj/Np+48Rqf373Jlw8esHvcwZeNiIYZEHyO/T2Mv8ez61t8zcb7+a1PPsvTK1tc
3thmJfd9K0LFAncd+cwjHz6ZyycKZPDgIfA/ffIX2RuO2LQ+Izsk9EymgNjKLCcd
FZX+ZRTmsc2XlgNV7viZCNAlZLi5dvG8Y0//XmzFxLURUUv7ynT/CT8H9eBc08qq
j2oqAJCSrL0Z3ivFCE4caEIMleZrIDUt/6o1m0DcOENaUkPiH6gIo/4hT25scGlz
KxUA1OhAL+BlgbcfWYYxTWw3dAxkIXjLGxyXVGebRRlnVGKzdDcphEEmGXCIiGJE
GdgRGg55fnUp004pteZuQdxN6mHvHh7y8MEexvOiArKUAIrNMFhmKYEEckalLHMv
49ywJZmEVPxcGyRcAr6l2+twa3/I/aMhF1a6LIk/Kd6UxZ6dBtM3icKSK7B0jeFD
F67woQtXAHiEcn80IgjNhAfBAiPPstrxuIjHaj6NEhp4PS38/+S55gYQzn3JmziI
xRN+6K2X+cTebc5dvowdWgTLyJc50qOnbZctJGaa81LlpOT1617zMyFt2K1cjGVN
QreqWVI3zCbkdiAfbRq4Nbl+pvLhZXp62aLBUur0zLQij6kT8hQHmqAKXtdwuHvA
89sXuHBpNbXtzpbzB3h4FHBrfwe/p3iAF8StdaVdjFrixLSmYKV6EZerQma3ZWiU
vlisEUajEV3P58ntc5zJyyRG/taj+9zYeUTv8lVEwggZUc89ZrVJeVtuem1glJoZ
weRjyoiQpbVlbt25ySdff53f+zXvZUl8QorIwxmjBih/Wl8IgxAbWDwRTMdnG2G7
023OguTRes60ULcuiz1qRrgzGPC//tLPsHRuA7u2TBCGkyBW56pf6Kb3tXXn49py
3ZNzGBkKv9Ss6JRrayr8Rh0etJAm/UzDAKDRF78J+jng6yofRlICCuqiw2nuSJrG
TZOiqYJaXf1cTv47jlxHIVzeWGY9NuBGJf7c2TJhd/f32A0O6a1t4FuLF8LIS5Tl
ioXj0mqpugdTC9BZtdHSzOINPEHEEI76bC53eebixRabSVkI3lkhc6D79sEeu+GI
890eI3uUjJVm4yylKGwkjQyINvwZhXyyBLKp7tIQRVUQ3+ehHfLpu7f5vV/z3gKq
BougRjfHSwUjUYEqIpGsdirx0YJezPgH0q53z0H4pDkssmm+OY0LmikZj9/zf/jU
z/Pi7k2evPwBjoIgXhviqMLXWack80ZWGpqpdOInzbJ/p/Of7GVJ7efx/7Yx31dy
ENZOL6DKzmVXhkxKVzP3+1zks+eHAAD8ZBIAaIsXcbFX64zLuHwx6xTFHgIENkDp
cn1rdfKMomczl3nz/n0GOqTb7cDoGB+P4MSaF1w4i21lPSKilOhIQNRyZX2LSzEC
MP3GeWy+YrLp3xgdQNcwCsO4h7wBrFULATZ3IvM3/4qoYjXEW1/hxcFBmt38jMzQ
lKMqgvpRZBYS1V4ixnnkOG5aHYNB7WiyymZOHvvs1/h+fvbOm/y9V3+VC089gXc0
Yg0hMGCNpPjdZiVL14pgoPi5Qj2NntzqnAQWM79j2l+mKtBFK5PgnK9udPktHvSn
gD83T9iCBstdq3OXuWRt4gvDUUDP9nn/ZvQNBeqZBW8BTD/Z5w+G7AXKFU/QAEKj
WFNVoyG5O0hJ4OaYz1yRTDFmqgsMx0qCHp4VCGBrpcel5aXHnc/PNA8B8OqDI2Rp
lVBHlUwGY1lfENdIzhGemH1vSqyX3ltf4cVHd3lpd5/3ba47aKY5u0qBZRmnpCou
YkY74wh9rcOMTztnMueZntc1oSyIv+xhGPBnf/GfMPBheXkVDkJMut9/ZiTVfZir
FY15rtx7TBaXN4XasBC2zTNKHXFd5kFNic2Uwh2dNkdTLOPCTzUOAJqfccuvg94B
vZyFBSGvs9zWwGTXhmRvndkIxQG1FdD/uMgsYdKSTESf/MMwDGC7M+S95/zcfKdy
HNEGjvF0nU0enxgBXxgt06eDZy3q+wzEEjqIMCfvMdbFTreQVS12sZlto5qT9NXs
xpIURuo6JZa4bd4LBRMoW0s+617VilpcNcbxCN477vPq7RDprWN8ncSP4zUpAppa
vGMGwYwsuCbyPqX5nbpKm4vFR+mRt07G5/o9akQxKEaVbq/Dgwc7/LOX3+Z93/T+
DLPe2erYaJFWKxgp4h1a/JgzOGjruhfP+SdaEyESJUjxhP+Vz/0qn9y7w9c+/W7s
YIT1o2ZKKxNVq7lZujT8rzkVTFGtVSxNP4qVZmilaPMzhmg72hwSEfsnB0ItYnKT
V16sOxEKK6uAU+6I8usngACoBX4a+CNu9zMlhCla+VEtOCwtXfh2yuTGqqIhXNxa
59y5zXjzOiCYad/xFIKA8bUfhty+c4+VXhcNgyj7l0RG1K0xITN841hkqKpVpmrI
4kLFMJ6HYcBT209McEVbGgsvdr4ZjAJ2+0cE6yuol3Q8FGIvrVimhQlrWthXPlo6
JQIQGbU43xKLZzw63Q6/8cbrHH7T+1mN91GaZV2+gqKAKgrgfLj1FRX85N7UErWy
WiAMFN8XvnR4wD9+4VNcv/AEGuS0LpQWa7ZsbTZOUmnXQqdzHJmq1Kz9m5R/Q7Wo
l8BPt1Faakuw/hNJAJD+VgNTqztVT1rTDTVLgCmAhpa1tWVWl7oOX6XOaOxxBwHp
p7KhBc/QH47Y292h63XjrZqrOpek6axwsNKkFqwUEbC5+ZT6+8SogWfBw6NvhOHR
gGub6863zc7CYprZcbh4+/iIIwkJljxCYzFhcfLyRUnjn+cLWmvH0ZUROI6sdCoy
lGynQmgi6yKhsLKyxitHu3x+v89vW1/CqDDudJSvXC+4oNjTydoZV/2+7wkD4E9/
9Md4IAOeWr7EKAiRCZLoLlxUJvKXU/OKZ+l99bHPg1IvFHziazCyKT/R5m/aBgAf
IRIXWKt207NklK6NpbV/YaeasmQBDYOQ1fVLkYiFTWVeZgo+zlPO/NOF/Hu7xwz7
I/z1FUQMqjlpX03OmpsB6W6mwPoZiTXRNQ+MFu8+RuH2/BCz0uXq9kppFhCtNMOi
XmEcALxy9yaHWDrdDoEd0AkbhsFTL6m6CsNpjuey3BwqoDFnrRcoXm+Zt493+dhr
L/Hbvu7roqL38QBISpb7/2TBwFea88+jG97YcQj8D5/9NX72zstcuHwRtW6HX2rD
K6PbpujAdP0mWlk9MD/b3Oxt5tPBJMpB7KNPLAA4ir/g35gGfmmXpbtdlG1B7yvO
fqqYNQmZrDuLZTgccOl8knkaOz7zL7acLFK2aeMN6cU0m2/duc9oFLLa6eaEGbN0
GLULUtQdZIljfmo9V0kXRXzGLQKhKId2xFMbKzy9vppypra5guFjn4/EAL559w5W
wJNUoaNrP2jiLCvnpeysUt26zcmUpM8i2wplZ6lKExldRaxEcrmrPr/6yguM3vte
OktLiX59m6/76rXQzj+/JsfT+qOvvcz/+zM/zbPPP0Mn9AmGo/ioJE+949DhE5fj
b07vW/50TcPlpIjwJBx/PrZJ/1ul8i8dI50PeLQqQT86yQAA4EeiACAVeakLBSif
RK1luCxmHuBWdCqj963Tcop42CNrFYbQG93la9aeAC4U/378flKFejyeACAAsBZP
FTyPz+0OCUyPjnixV8np94YVhjlVyKeaPQKxuV6aZt00VYqQyRgGxiISsrI75H3b
XZ5bjdhVglDpetkNKw1ji8dzRYVRQ+DTe0M6pstGoEjgXq/55eXeHzVGTvLEWZIp
0swGGzZhutM62Yfi+US6uEkFVIVLvTU+++bb/KNXXuf/+sH3Y/yvOv+vpMvm/tOJ
//Pi/g5/8Vf+Kd2VVdYGPojBGi/n/G3pPat/WkfvG9FqJ+jSfCmG5hIA1Po9bTj6
rfzMj7R95mkCgJ8C+sDSND2dLnpfxxTnwJr8PaoLckp/F5Ow2NiQKRGxySAIudAd
8e7Y8aS1LbXSeT3e6HyswDUuUAqBl3f6GK+Db0wsFNMmUlYHbOfovEg5ZDcCl4b9
bYU3iLDiQCyesXiHRzz/1BrduCrWk4Wg92l8jaVQb6py36yxQp/eyKIqE+i8BWDW
wlCkGYRsI5RHGiMAtmySMcByKByubPC/v/gq//bXvh/fcKZkgb96VYfuafZiiZ3/
AfAnf+FHeDHc5bnz78Hfs4ReCJ0817HJIVBNjqGqPUSC38aCt05vIAs1juVPNNfs
pR/75rYBQGsIZA/4KMh3Fx++/gjAOiYrzSMu+SUo+UKm4qczgFO6ZslRiTSOHtOO
bRAMeWJ9g2ubEfmMtWC8EDtpW1vM2t7xVvNixrH7Crd3dun6JtJpV1us+m/8Grb4
NzIuL3WEa2XHeZmJSY9jYixUI56Cg/CQrVgBEMAzcrYomGLZsfsHh5hRyJLnR0hT
lXSrtDUlZasgu6ajvaakR9A0avgrIgvuFkOJ9I2wnNta5+Ub7/Av3rzF733m6led
/1dIADAJ0XO++0/+xkf4uXuvcvnaU9ggRI1MEMIsm0W8xyVOVVRKQoyc85eizU4f
okVJT95z5NftrK2HM46ftAnjXUym0iBwylwfjX3ziSMAAD8EfHcxBRTqFM0b84VN
ggXJDGhdUXkd9B8dFYwdY5THDoZDnrh2mXNLq7GIkxL6EXe+p5EegGCjAgSRhfBI
kpq8ceZ5+6DPo/4Q31vB2rjMRRJIXwtRuXseMksuRfRT7IwoQ0bS+HZOnpb8vyOu
LhtaxPfYWl/PbQNp5gsXASqIC0bv3b7Lndt36F28nhLpmMeMu144JQYk+ZHVwliT
CgqagRDV6JeGir/SJdzo8Dc/9Um++Znfz/mv+s8zf03C9PE5Y9Qcxd/44m/wv//m
L3Hu8jVW/RVkaBkZg0pkh6xkV5ZKyqFJKuXTihJkLa7lrL2ApK4me5zVxuefXAlg
W60OrUEGGj3pD03ztNMGAD8GHAPL87a6rjKHNu1LY1akMv3ndF1UxObpcXQ84tr2
ZmJPjRAgkbxJHAQkyZAuRI+TAF7uBe/ce8hBMGSpt4baRAJQxsGwTkstonP8fC6M
UKXT7XI8OGZ14xznLl4688bzzu27HPaPWe12GMkwDiB19qGd3x8jc7qLEWFkFbmw
xS/eeIOffOMm3/fMNfeMn6XznP+zpftlXaRBErP/7Tc+z3/9az/Gk+sXWTfrBMeW
UCAwtBINPU2Oy8cznMIptwEexz751AKAQ9AfB/7tZrOjlWYrT3aYbvpyN2tk6EYa
rIjkDkYjkR8rwlCV0IZY7bPp2wnmpXE2l/6/hTRYOcqxNw/22TeW1Y6JahxMBNGK
SmtTnynyG5PYZyy5lCjWVTPSueEyYRgEXFzyeH5rJY7D9ExqygPcOjoEP6ptCEzE
TtY5ZUcvNQRdSlOJ5ZrvFkEHAUs9H7O5xD/45C/x+5/5Q2y71tFXr4UOAsZ5zuTs
f1ww7MPP3nyLP/PRf0T34iZb/gamH6IiWC/qBlEjhTNYTWXqs6z3hMVcnJ/NJo3V
GKXOOkgnEuLMHDD8eOSTpwoApv7if5AEAMUXUId6kotxPrlsJuPPQ/8J1SO5c/70
/5bC4issSIFOCKFvGKil3z/i3NqA5y4k3PPqJYIe2epzWejM5QYhu0uGSyIJ5q+R
zK62KcvWGCiekEw7NlZqs7t55qTB/1Y8z+PwuM/h4T7feKnL837q+yVFY3TqMmfT
XQcob9g+nbVVRhISGMWo4IU6ZWH8uNzJun8nefJZS1bIqgRalPzOcFAMQy1RiwJL
oWHpULHrW/zGvRv8j1/6LH/+/V/vDv1OPTn66tXG/4yr/QUYF/V/8t4t/uNf+CHW
1te4uHyegzCErkyQVsZ1VepAbhNjgTo7edz1JYmEcORHREvsi5C5d8aTyPyWmlJW
E1MaF9O0DFe17Di18ff9g2nfy59hTD4CPADOu8liqkUQTInzr8an2loPdZjSyLGE
CuL56OGQS+vrXLt8afIkY7ILb/wXMnUl3clv3HTm+XAXtRYPMDEPYDmRUc3IafmI
aisCr5oilvg+YRjw3Plr8ZmeRUQmfExyhmjl3nh4n1fv32Z160rsijU+ApijlS5d
403OH12FVzrDwpOYglTp0mFjfZN//PGf5Xc+8Sy/a30z85Vhyjh+ZVPmnqnEPxNL
ejb6j/jRzz527yb/yU//fXY6yuaFq/QDG9lFjwxdSN5eVLnLaotQZPbT2m1RR3U9
j0xdOTnxu5muB7Qk/5lXABAC/xj4Y20ysvYcgfM1FRqfWQ0NmG4POwpZDw2XV5Yd
wcs4/1/8pubd0YC379xjRboYUUdb3pxijtbruq7hTDHGMAqVi+vn4p8GiHqYlCLD
WbkeHO5x/+CA5fMrjIagYYgRnfEwQx0Y2ix8mDqf+YsNbygSHZmpcGFlizu33+Fv
/ez/we/4nn8v9hPR+4+rUvwZDc9Xr/le4TjpsSDDeHIEXtzd4Y9/9B/yRm/A0+eu
M9CQ0IMVFYzOJ6ytDgJkvkv5K/P6xySx9akGAAA/6A4AtIVJcZPKZrmeZ4ptcybS
EvpKKIIRRUfKhd4Sm85ITzKGbuaIZs6XlYixEIG3d/e5t7PH5taTIB7WhgW97smp
wLTJ5lRBgBQcfsYZqhJ6gun1OL+9nTgy6xGRG56tEOBueEzY6xAiGLX0rM02QszF
OLqEQU4oO6lc+0l1tyKIFYzAlaef5uffeIG//cVf5o9/4NsyjTNjdO2r1+PJ9l3N
uOOfe2HsETrwhZs3+U8++sPcXQrYunyN/kjohEI3TotUpZHpaE9+0/LzKlPm6CdY
sni6JusHZ/njWQOAT6joK4i+uxk8754ip0Si+5Mx+5OrvSnffpbK5nOfD8WAb+j3
j9EA3vvsM3Sdzxcr3S3y0X/8uHcOjjnYG7J5voeIwVqbOH4S6F6d3tzRkiKzaVc5
51qk0BanCkOB1bVlntxYjf/Sz0gIF7oudFFMabQ+RJMo6837twiNIQwVY6GDR6i2
lMK63lRXwP6yGOnPuPXLU4HAQ5eWWX/iCv/jb/xTvu76M3zb5hNgoSNKKBb5agjw
mFdttrbGjFuufcDAb968yf/jn/1vvNXtc2HzMuHQJ8TSGwk9Kxz7DqoeKeP+K7f5
RVPU3OY0aQt3pJUNHXh+/8miIg2vAJ+YKQBQY2d9iB8A/qLmCByK+snN6X1J69ek
JFHLW6liY6x5g2lzQZmisTSuDwyDEeHwiHev9iYbIv88dV0Li3J96f4ORyGcG1rC
jsGK1FfAOsleWm6WBpFzwtdlMWkNbwVrgCDkivhc8uN41PqTD9j4fDnzNs25p07Y
lKYizSCyqi89EEbeeVZDnfAuiFXENJEf1RYBmE6V98x9JCSFlqlBRbFDn3Mrz/Jm
sMx/9DM/yT/5fd/H+5aW0eAwipO8ta9648eTJ0wYRMf8nAbwAvBi5/8zb7zGn/6Z
f8zOxRUun7vK6PCYnlWGnkENhHE2lGV8SfHxaZp+2qbA1Loe0FS/l+RtvZQnjHm2
UK3aU+mRcGWdWuI/7KIikT8w6w38ObzWD1r0L2qh4r+q0Egd5Xnl9rwpf5lqmPyF
pE6o1KY4ow2+NZgwxBDS8z2eXPFT013kJGRBgwAhCeU/c/M2S1ubmFFIoAbxDVbj
inCRGirKeTsRm8oOU1SgMnYYMkEkrIFw/4gnNja4sBK1AIpN708tVGQszmWxCJ56
UZGbws3jZawXYqzFihBqzIamOkXGrhUrb16B2pzWoo5ny+CHHeSow/aFr+FLr7/A
n/zoj/EPv/v/wra/jGjIV7mCH4+tGGf+IZFehQf0xpk/8MMvvsB/8Us/yf7FZc6f
3yY4HuKJF3XjqBCahNcrj+yXYVWGMuU9h39Isw9p/smlJs2oT0SKR2ZV9WWu47WF
W7M/OHMAYGc3ILes2H8OfFfaQNvYihfZ+ayD3jdRfJPYOZR1rkv6himlJbW5heWi
YI3/bdQgNgBV1tZXubDVq3RlUpF0Ps4lIWESAOyMhvR6S5G4kcYtZ9KAGbFCtGP2
7NBmnF4iXKdJZ6ER+v0hF545z5rv5Q4qNeIxwEyMiDx2doCEgU/TaogefPHmXe7s
3mdldQ1RnRyRt+5ekao5sQtkf7SA9IlGLafWhvR29vjw08/zqS99lv/2lz/C//Rt
vwcRj69Wbj2uIC1aiT2JHHNAQpj253/95/mff/EjLD1xmWvblxkcD0ATil+jdXvd
2XQds5HaXCqn8d7OIq2Jokku0M1wj8jEdjjJhKUYlCZZRc6RZ2iDyfGcaOHJphDn
OcnrnwO3Zg4AdA7niIJ8P/BdbmOZ5/FPLQTHOY6WLNrKsJYmH0g0Ui2CUcUYD8/z
QMuLKE1FzFoZBLSJEhp91hEFBwqe8JkHj7g9PKbbWyO0EbvhOONMk/iKk1py/nQZ
WZRHnGWektrbYgTjeZn9ls76FT0Rp1/EoWo1JDPGQaMDjUi1CPj4jdd4eLzP9uY5
NBzmmpnE3YHXaK4XKNtP24sUpGpz7B5GYEkt3shy/trT/MRnP8dqZ5W/8Fu/DR9B
Q0W8r6IApxuuKYMgoOcZOsajA7w5GvKnfvkn+clXP8elpy6xur5NcDiM0DlJ+FCa
oFfqsMdjTpcsVTApMpE0MVUcEjRgLC3PyV21R3UZvGu/Lfza/P553GRe3Tj/FLgL
NOZx1ZZ1FZKuxcj49LrJLcIAY25/4wmhVUKrmfhuUbdvgROhE/3vj7z6Rd7au8PV
rU0kNDFvQZj6uNSEMK0jq8YbVOt2rVV8z0StZKmoSyTDcn9im1NT2FMbMHGcvaRr
R35z/zb+UgfNyyfP7LgXhT0nO6uqMskgx0jN5F8mSi8H/T7rvTWWtp/g7/7qJ7mw
tMGf+roPIUZQq4j5ahAwD6tAZW4aV6OI0PVMjMLAr+3c4r/52E/xsbs32Lxyke3e
Jv5QOLYB2pGIjTPWQlFpkCZoRWBA00LvebTL5h3HVxzidDf2uQsTACjRecR/XmbA
FK2RIHHBQflfSzZzU4pwUeVWiLMTVcR0CEKLh8XzTBwAaCxQWx1KVBNbaIMgZLqF
rTFEFkXJBoxhgPKpO7fxl9exYY8uPlaCmEo3/feGky8Y06n+RAGJ56BuCufl/vPn
klUog4LzDFNSIcqbuw/4jbfeobf2JGYs1DxO+tUB6Wv+bfKmfAGNlhTDIFVX+aii
JnIavnhwOGKlu87V91zi//PPf4ZLt27y737Xd+WYO6N6ijFOJV8tE2i022xqZXnO
hFcjWXAT0fIZE33q+1//NH/t0z+LDZSvefZZjkNLd6jYIET8OPtXSSR3LJkivXxx
fHTiKjnGvNzzxpS+xeNdmeCEmvrfTlsrLeyP0qLuRhrYx4VZkD84LwPhzxFa/Vto
EgBIrsBMU2ehVqQUVczz+4+NhI4Xo0NDNTnqyQH2qrkMODLGomDsNsHQMgwe8XBk
eYYJuVXBGFedOiuJfkEG7JZinpn1bRkO48p7J/+KnT8BSFTC8xOfv8HnvmxZffK9
+MMeHiEBo1Sj1ThYsjknpimef5jtbDmXGUqamlMrfYgI0PF5uPuQ0CqeiSxEaKZ8
hJp9qxUM5a4gQAuzF6+0cU1fbFB/4vNv8s7hNue31uIjpYi8N+Jkiv9etYigux5c
XdTaj8vp5052NVtVrZJwZSRnvfHRnY3eLxRBjWFFYOnaVf7UF77Ag8sX+RMf/i3x
pwMUQxBjCL4L9PpqMFC4bITz5cV3M0fm1sIohF68r36ZPv+vT/44v/HKS5xb32Z5
bYnj0RBDjz42UhiTKEkq5liuThxBNQlDJGcHMj8xkrEV0fFuMfDVgpKbFILMCQOh
aOqsP37p8QAYLYcjCvs6TH1BUcNEpGkgEN9V54H8lRq6vzWvu/lzfMY3Bfko8B1l
5D7lVllrAi3J6MpPN7bjwo9osWro0fE77Cu88mCPb7i0hUEJJtStpjEgqzWcWONI
vZoDuxzeG28Smfyrg+BxGMAP/eLrLK9ewHircWAQxpCdU1ex+F1zy7RcUXs9yGeA
ju9z6/CQ3ZHlXM/LOGg5kS3UvHtYS4KY6JTFByN8/uFd/tcXXmLtytPgDbFhkFs/
09LtPm4UwNUWleRqCfe7pGRZkj/xxuGUL4QaEhzuce3iJfY3t/gLH/95vnh0i7/8
rd/NOXwMStfG35A/sfqq868NBDQVAEyWTgjGk8j5A//H26/y5176BV688wbPrF+l
43cZjmycc48IjTeJtbK11q7MWrL2uDEC2ERgKuuobdPIX8Yfruu4EWajv54VSZjp
+ijw5twCgPnuLf2rIN9RPV1zMGyqM5g0ieDJYI/VtTUeHQqfunmXf/P9T+Hh4cdg
ZPPlkIdx3ZeZYVElztBLm1V+5LO3eftgyOazWxzZI1Qs1tgJIpHdHKkoea7UdE1g
s/Lfi4Ver8OdYZ8X9/f4lt72JHi3C2H4S6oQxExqMP7Wx36dlwZHPLdk4nYUba2B
1twA6cKMQxYjMeVnwONMr2PoHx3QlZD16xf53268wOv//C5/6du/l29cWY+kt8PU
Zvlq5l95mdwOtMSV/cRLM/7AS3s7/Hcf/xl++sYLbFy8yDc++UH2948IhyM830uF
cOU5QcHk6vw59yapts7A0veVeeafvv7qPN9v3pTcPw16A3jSOV1T0fvqDNlQqvJ6
rGAjSijgyTG+gL/R4Rff2uG1Iby7C1ZDjPgT9TXTDMOodOgy4wYPxwGJ+pP06Kdu
PuAHPvEinSuXCe0IwzHqKYHme2ilYkzTmzmVbs2wibSItOWeoNj/u7y8wotvv8ZP
vvxFvuXCt0ZFgDY+5ZjbaDYxINLgkxHFsokf7iOff5NfeuuQS5efROwoUl8UE0Gx
M2vhSglS9BiJf3C1U0WMCKjJrLjJkYokTJQDzxKIZaW7wvOdp/nV11/m39j7Af7W
v/Sv869dfXqiTyppWbqvBgGlq8MAnXhGRsAAWI9/eazwdz/9cf7Wb/4K9+yASxev
0Vlaon/Uj9an34kIqmZeUhXn/tJyzzqURyvHIF9lXAnFtllMUm0zH8/uuxH52Pk9
xwlocuhfA/6/Tav8Ba2QTkyZksIqbWK8NQcjxuZLwPdCBsePWN9Y5ebtkF/67Eu8
+5vfi+qYQlcqp1/muiSq7iQx+B/gxdN1d+eAv/kjv8C9zhWWV5fxwwGegkqAlUhJ
L8ryyzBUyabgBeeiDRymOgI7l1GQQteGppU8VfEsnNu+yEdf/SJ/+rd/M+dMBxlF
x+tKsV94/llsXfimKVRF8OMKi4+89iJ/4qd/ntUL7+VCd4PjcJ8RITbT8VehilkC
U0rj1tY5rT2pW4upMkiheOCV4m2YLIYJj0P2fNeXaATNIITQ4/3v/yZeuP8af/R/
+wH+1Nd+C3/kX/6XOdftJI3quarcSVHagpnm00dgEmnd8bAvEf0H4J+++iJ/4wu/
xqs33mT93AWe277GAMswDKL1LCaur7LQGq8q2oGTrVGZ13qXqfeRZo4V0jVl0hIR
bfNuBbv91+Yd/Pvzhyr5Owp/kZhkqsx8ZY2jlg5KFg2yqUCggcikFCcmmUODVaWL
x4XNc/z9j3+J73z/kzyxvjIB1EIMfk5nOmZ8xWO+zWhpgplJ2mMjDdXACrbr0xHh
9s4Bf+6HfombusLKhVWUfZAgTtoFnaTNY8vppe6bv2zJM0iDKL+sz7+ABaRKurXw
7QrI0PL8k+/ii6+8w5//Fz/OX/vOfzMqTw0VPDNxwZX7pjp+zCCMCT9Z+qPixCom
Z9thgPE6k/H87M4j/uuP/RKHm+uc31xBR32MCSMBo1ot8Lq+/tNyZ1pi0NVl/qrD
Vx3zfETaDdmTUM3sPz+usVEsw/0+T29cx3vXBn/l87/Cj9/5Mv/t7/mD/K7Ll6P0
JIhT215CYZteSYYsr/1XTCSgZTYshQ2G8X+6ycc+cecWP/Cz/4KfuPMK/WubPPOu
Z1jSDsfBiJFH3HaZacYv0PpWX7ZxAjZ7P5S2u5OaCvTy8SCH079f4d4D4O/Me4HP
hQgod+0Bfx/kjxZQHU2McKXwQ7rgT23D7DRv6d18gmPbrOrhe6vYvrLtdbljzvNf
/fMv8D9/7zfTTZqRJo0EKhF95iCObKraBduTAI1h9/GOFlAPRgaGwtJSRDX76Qc7
/Pc/+ou8OOqx/dRTaLiPaJ8QE1Mfm6QXW2Km77iiXNUUDb2UBQP5B8+Ne8zcmBh3
k8tsbWrGbJwdxOGC5M4GPANhyPHdh5y/8BR/54uf5PmrV/mPP/itICaSJ/WYcOlL
gcHQNNgTqbWgSU6fzyMzU5F6VxkEUVvCSvSeP/v6a/wXP/+L3PUucPnKNkN7DH5S
pClaXviotcFBFhlwb885oABSFkRXi3Wpk+iFpHNBUtXVUnFkoWCMYEYhHSvY3ipb
H3o/X3pwj3//p3+U733qvfyJb/5mrq+tggf7RwP8pQ6+GEJJbi9N49cz5vyVfDmZ
TMSxJ68ZZyJD4OM33uAnXvk8P3/jVW4fH9B78hIba2schAGHhBhfSgNdMvz+qYRH
LXVRt5ZUx6dtvkgTZKvJ+mxgZNUVgMvUEMW4s0XKOrVSbIKi0mJvNkEKMgv678e+
db4BwAmdJ/4VFf5ozu1milYycy3qFPNTZ680ObrGKslexUWgIzEbIJhYTjfk2oVN
fvnlz/Lv/9h9/ub3/F42MRHgngpavJTzd2Y3LQPC5Lgr3QHdmbyO9GSCo/z1l77E
3/m5X8eza1x/8mmOR32EMMqlxMZCSFKx4POLM52h27w1r0BULEWGR1uOGkgeNfCS
KYtHzViLCSzeUo/LT72Pv/G5T7LeW+OPvOfroMsk9RMkalOKux0sqUBE6sA/k5oh
kwkKxv/fIJn5i5iWFXrRJOxY+F8+/Un+zsufJVhe4+LSBqJhpEExdpI26ZjSygwq
bTzqYMXTSDfLsxFNOR6VMhOV3cDqLEBlYiQl3lTiRaiBHVhMp8P5C9d4dO8Of+/F
T/Lrd7/Mv/q+r+Hf+dA38dRKL3ZKIAH4NhWFS11EfrYSfyvu1j6be80A+Lmbb/A3
v/jrfOLLL+F1fVa3N1m9cAURwYbhJBnQAhvojE+ZPzqUdINtkhAYZq0mivyDuqLS
05wXVWcl91z2qlS1K05s7V85iffyT6jS+hXQjwC/x1kqVyYe4UwYpAF80rZFIxuK
WBsQMODc9Yt87OVb/Hs//FH+w6/7IL/nPVcmHx275k6p0Wy/zCWzxdPvFLXj7AC/
+tYNfuKlV/iRV1/n4so5NlYuMhwO8Cd+Mc7+03UL4/P/SaeOxOyArgJbt6FOetHd
7IFai1mmc5esI0l/nQHUKLZjkFBZX7nAYcfjv/6lj/HW3R3+79/4TVxfWkn+aGjA
C7BeGHdFVDVspi8vM76FPt/C+WACLT8CfuyFF/jHn/w8v7m/w/ITV9nsrWP6Adam
e4Q1k31I7ZlFsYWqmYGeD1Vz5f8WMs2n6Q2rpYaKTFjsDAlTCEsiUx0z1VklHAVs
bJ3DXr3Iy/uPeOnXf45//uqX+CPf9G38waffw4aAGS/+dFz7FXQMMAnVh0HEixFX
6hvgEHglPOaT77zKP/v85/i1N18i2Fxm/ep5etqhGytqWguBQ0p7PsNTVvHjtsmS
MzFaybSmjrXU8qhMpcHntNV7ltbrOJ1WW4Su7v30IyCvnEgAcILr+C9EAUB14CPi
IEWrJU1vy5iWy47TeYoCNiDwQrqrWzzzxBU+v3PEf/5Tn+djn3yVf/1feoZ3Xb3I
dqeXczQnU5480pAv37/PJ+484Ec//wqfftDH+ss8e/79dE0HCaKeamMiEpak/9o4
13u2q6YprCYNxrOFOdMM0ljgBw7jk4ouHuGxwecCq1vr/OALX+affuEN/sCHPsx3
v+d5PnBhFb8L0MXQPTG01wIPg5CbB3v86ls3+PEvfpHP7+zhr5znwhMfoDtQZGix
/jgvE2owe+rP2RcvE9VUUKPjgFKLsKqkETDV7Fw7zLdxRP4jL+Ku6FkweBz2Lcsr
a1y6usLDR7v8tx/5Kf7Jxc/z+979tfyuZ67w7rXN7C3CVMp5lp1/GjTr+JOldRxa
fm3nNv/L65/loy9/lnvDYzY7q1y8fo1OpxMFqypxG7xmqVNOZIFIiSmQ2kS3PAhQ
qgu9myR309iohb/+wknN5EkGAL8CfBb4evd0aCY4rW9FKZtgaRQLqOaChhRubDB0
rDCyysDrcmHjArJ2zE8cvsGP/+QvcH1rnW947j081fMxgyE9z2Op28VM4PApmxtj
B24HxxyP4P4IXtg74OWHD9kZQGg6PH31CZZlmfDgOOox95SRB2F8PqeiWXa2/Ptp
lcNpttk0V4ZXzukteTC7tEQwv+XVKN0AlkKDqE/oLbNycZt7Ozv8xY/9Jn//M+/w
wWef4euvLvN8ZwBhfPxhJKpoTj+buLIQg1v+x0wCpeFgwI4KN0LLZ268ykt7dxgG
AVvDLpeuP8twdYtg37JkA8QLUvLRddH8PJ2/Tvk30njeCzlYigheMv0Q2TVg4z3t
1mSXpP7GsVdsXPPqB0IvtBgPhqEBa7i0cZn14z6feucNPvbwNu9+dYnvuX6Z3/Hs
1/DhC8+ykYZrGqS7Vm2MiElJ2eeUcXHpKKbuqzauzym5b+4RPn3nJh97/WV++Z0v
86tHt9nVgPOdNd5/7gp+r4vFEoYBo1jyPPCiATaAsXUoVJt1Vk1VnWi1qMMOZI9x
tbSeNyMV1zCha7rv8uhks/BogoOOa6lq5VQmbEQzBi+TL/os6K+clJP2TzIREeTP
A/9Hkd43gqknBtR1BKI4d4eUJt5SsHHpzLdQw5Eq3rCRB8IzIR09RmyAMbCxfZ7D
oyVuHQ35qc/cYDgcoYHiG6HjpSoBJJyapgCIqTih63cIlpdY3TjP+nKkiGNtyHG4
j3ghhkie06YWjcR681r2fpoOrjT37vnNLQ4ULWnEsxWNcpVUmekYTd3K4KJxEmcs
whAbhWVcurDF+toSQRDyyXde45NvhazQBxuCCGok46DS59Q6KSTVyQYeZ+wiEmei
CdXnYBSCMXSWu4z8ELN8gYvLSyyFHoEV/KM9jGgklCJpnsYK5kspPyqKhFaqMxYV
pgsexOXkyznaSXGxp2NIHRv1sXKjmhyNtaZCqYSKVSYtgFI4J1XRbIeuCp1QYwU6
wzAWKfdDj0BgF8WsLnFx5QnWjHJgh/zdz7/ED7/yFk9tn+eDzzzDd1x/nn9p40K2
9cjBch19R4JNGFKKd6kgZabYy7m/JFr7ozBij/aKxasWuLm/zxf27/GxR2/w8t1b
vHzrNg+Oj+iur7O0eY7N3io98RGrhDaugpFYPQuLl9rv7rIorRTA0rqjoXyIP8k1
NMUe6Kpt0QKMnhUJSinFiC05ZqqH87VFG7NIfRW+plkuVQrBrToEkFsslHzW4rr+
/ElCC/4JFxz9KPAG8AzicNZaZZBmhKBLGaXyaUEYGzpBxMPXECRAreINPLa6G5HB
1wA1sVNWRW3MuZWpTJ/uWo7vK6qoDVEbdQOICCMbYEQxXlonVxwbzbXWtWJ9j4MX
pepEv/hvKUT0SBkpkpbPbZ4oSMGKEpoxlBwiYYBYWPE9rGdYW1rGKgS6jkjkeMfk
tKEkssGaQn2iwrxwoj/uxTz9Ih6GIMUtLqx4HUIEtcJ6jL7a0BJgEQ3xR4oYxXqJ
NnneY0y3Epqe+7e9e1OEpwl1d7p6pkLnYcp809N4/QuMJDG0FqKqf1E64tNRCI3P
8sXn6I9GfPrhDp84/iz/8JXP8wFvje945j186NJlPnThClfHLbEm65t9lRguT5xA
VOWtJSm/q5+0CiWIj4XUZEqORATpdjJ/9sCOuPHwPjcO9vmNu2/z8Re/wMt2n/vb
BkbC9sYmG5cu4Gnk9AlhhMUYO3G6CXd+NIbN69BnYNzLoGhV9yophRW3XdaZW2Pn
2Yffni2g/Z6v/Js3Yh96cgHAKZxf/PfA/1I3WKpz4pEuPQIo+YekOQekgCZYG0yW
udgI8jeZ7gJl1tKayOHrJBxJt5wYE1fu5s7NXWITWtBLbrpBXBXczQsrpXLTauXS
lzLp7jhLBwitTccadGJ4J53teyR1i5qCGjWtDyKKUcnne/HXeXHbU1RUqTZFYaNJ
K4iWZtl1RqEMGjwZtYNZzwyrGc1dUPB0vdeaPWEoDGu6LGjclhbFAwErHY8Vbxsb
RgRYn+OQX/jNn+Wqv8QHz13nGdPjWX+N3/7er+FdFy6wZmA5tcVNGeQvabSoTCte
s+cOGQjMcyPVCq8dHvLy3gNefnibl+/e4rW9ezwYHLAfBvQ7htGagNnkstfF9z1E
DGZELOY1vq2rijoblMvcVlpbNb2T+I6TSlK18ZvBY6na+e9P+gtOIwD4e8BfBs5P
FynNuBYq4RVtMeV1cJHOZTlKybdKpRFugJqU9dVayR5RNhrkBAUQaT5hkVkKM868
6fasyy41e9Yx+W+TOnIwNnbCQsEZaywG7SpSnE92cZrOf/ZPWykPE6UKYRBtFERW
M4U21MhQiw1D1Cp+4PHk8nkur68SBAO+cP8+vzI6gsBy/fZrbHd6rCo8uXWepy5d
4hs2zvOM18XzhHNbW5hejx6wlnkGr/YZxmSFfaLixv3BMS/1DziylgHKvYM9bt6+
w82DXd4e7XPr4IAHwTE7wRGjENY6S6wvLdPp+BgTdxnZSIrXYBIJ3Tx8rlUcETi5
KNwI6KyGWFuvu9JPimV2kp2vGB2AB7HvPNkAQOTEqyUt8JeAv+JuFTvZyXQoq8Y6
7pIVyKlxdNMs9MY5YdoYuriMGMteuu+jTmffbCzz9Ng1Zrsk0xRnwJHu7tCaKEUd
xwhphF2r8lzJj0bROMn4yEmy1L6TTFdSkipSP9+lgZk0OUOd4yUNGDGb7JFWdj//
9mmyJ53r29ZhWcb3UHxCVcLjARiDest015a56G2iquwP+uwMDgg14FM3H2DffoHu
4ZDztsPW5jrnL5zDGoOEIe/dOEdXPUIxrC/1IgdsoyAjiiKjwlMPjzs6oC/Rufut
u3cxYUjQM7xuD9nZP6B/cEwwCukYD13uQq+Db3zMygob/jq+6eBhMKHFhhY/BC+u
ubCSbqqLw1PJcnlo6RqVmp/Pti6KwYW2sr96WntjytxQ9ES/sen1l5hNo31hEACA
/wn4r0C3XAPhhv9tifGRxkPtJonJE9jmU1Fp9ixzgFotVFTEZvJ7qqtnp3kmyfDy
1wtwtHtXm+IIl/zO0raZQXk2mjieuBogTo3SLWz57xckpq3NiRdpldPX+meuZC87
iTYlbfWs0+R4Wrk6LExks3Tq95MZdteYP1MN4AmhxPU8Cl4QcQsseV1kpUtolJEB
9ZTBcMC+Gsz6Jq/eu8fuwT6+7/OxndvgeQShMAxGUYWQxHwTMTuZYvExLHkdjGcQ
LKEdIdayvLTEcq9HP/SQlTW2VtfQ0OKL0FGT8CuEoKGNjyKiQj7JCHlRQgOsDdZW
2c/mse5s+9XZ+D3KV93JBM+nHW403pc7sc888cs/pegrAP3LREcBWFtnLGyJUW0m
EG4rM2OdkFZMdN0L6WcDhGJG2ckmYkmSM6+F78zL+pZWnLvPOlUSrk6tjYLV+T1J
f0eeGTD1WU3XF0iaPCwT1LhWRVmUrulQw8aBjET/bdRdmJlUHZf0SU/ey8TGPg4U
xJa616ieLHlyUzVu8+aOENcRQ7M9Uhk6OGm7k38XW7qUhC8gNdPazMqWkgZVBIDp
IZUUz52vWfkoNeN1LqiGeKEiauj6y6gVhgcDNnqrbC6v4Xt+VGcQE2uF8XsbMYjx
4qLQKGERk3SWiETZeWgtQWCRALaWNjC+wXgmYqxUxaYh7nFXxYRHwk6U82wmUUmP
R70slmjRgqSJ1+rQnurfp4R/RHNzLOX3msyfLXnOXE2DyIkx/ZWrlJZ8Zm7uUct9
WvFd/3LkM79yAgCAvwb8l4rdSHpHKkxALrNrCmm5SATVkfsWC5lKOLKxFbDuHJaD
ZLhTJj8ULQZCmuaZzRgPcmi85hxCkQ5ZE+s5ydbFsQlEq+dEHJXgNpWZR1oAqXK7
tDPJ9TIUEI4mHP+SjoN0kqFFdkRKN7rmchkp4Bdj9sRqeNPmxsCKptrbyK2tOav4
FbAuabxHMn9dJu5Hvr/BVRqYOP9sCCKx453OkKb3h62w2M5Wes1ThkdzKhIrZaii
QbK1PRNV62sQJC2tAt44kFQmXScm88XjfRMS2iiQ9uPWVEFQq4Q2iDULXGugmA2X
18KPq1mdTbQpQ1LNSNdmFZYeAbjsS/a80jl/Wfvi6vk3c7WxjdbYaR4BOKnUC2O3
F/vKU7lOMwAYgP4lVP9S5oVLt3JdP6e0MyS1+c9pUbDSgKXLJbGpJVwuLhPYpFBR
HHlGE8DVlsxEqo/cMcaaCz3yoYO2m9aKOS0poaypItRc7tyMwEidZ/Cnz0arjeYa
oHWFQlWgLlX6cfOBcatXcpM9nK3nSP7Cy/EVuMGTCLEy1XtMBDGSEHJJcqyZtBc6
bI6UN+CmM3Z3v7qW3KgofpYO+3VKPT6X1Wgy51qHXmlrGOJEd42c+DfW+rS/FPnK
UwoAmrXfze36qyB/BmWrZdg0UxBQuJUmDkhmNkWzrwlxuZZMSpPLrXSWcSuiHFJi
LOucSd0o1XUUaLMYpfqva8YiHWtW8pCTEBI1XkuiOVPX4FDnRPBFaW1+Mgp/da9Z
ut30VMhXpTDl2kByuSoGkUSwSYtCRolflypPnWu6i9p3VTWmN08HAEJZAXT5UeD4
GW2jzSE5yLMsiBVNhezi9rnNSjllzquz6q/a8BWcKAHyHEKNytHYiXzk6V3+KY/E
kIjZ6K82dU5TSUJW3EGyIGWze88xpWtGjOty/qki9lJYQRt8f3qTyBQv6JBXLriL
OW3AwgvnBY2KGXj6GDGPWFd1FLhIQtuFOrMSmEybOUx3B825mjy9bz3Fe1uj3AhP
qV172qqIrMFqFslwakhO67PqHSZOMlMjEUuIi9SGxtrIHjRgZEit6WxirbWYSPk6
mbIQtrHtmGdRbLsjWqkKFfQkdl/jgOfPxz7yKzYAAPjrIH8W9GJamT17iCeVPqFu
cQqpuj5xxNWplCZpU1GHc0hNvUrWv0kbp6nVNlFcEKU6z9fFihs6kDJBdC0kMUpW
b358Xi+5YoRM77HkGb9SuuGZd0y0CYSEnc+5/VI/Nrjqi9VJbJSHITU2whEpsjgM
YfTyNodM5Me3jqM8BR5NzoaJtRjEnYs5FuA0VfvqXCuV4Uv6HJZix0N6qkWKzy1S
nkZrSblOsW6kRZCgrh2Qu0s6G1Zt4I40JVSkOSNii65Ay5ICdXqKTNasQGGtl41D
9ogvEVRMiuHEgXBk+MsmaJIWHb1orbtW11w6izjVjTRILqFIt/tKNiBJ1kVqvAse
uPxIWN2roSSga7HuXPOt82pQdDyvpiZXC07gHqJ//QR7EBcmAAiBPwPy9zIk8VIX
LbaL9kSJeOKpo6lNaIm1jqcg80/TciGUBPcuiC/F408l6FcF02cLa9QpXVMh7oEr
gCpy12c7krXoTSt1n2fPfidNBuKGQqtnQkr3rErV/KXPadWxfOf3fsXgoardyzTK
+Ktwiia8Tto629aGo6Dlf+ogbyofyzGJT7pSvXzcC9Uo2mCOCqYpCiqiMsGq7L/i
HUyDcdJshKYlQVrinpu2B5YhY3Vth6blSpbyiLv0qexcXLLTk5yov3Xd3FBSdP5n
UAlP2xk/jgAA4AdA/hvgmWroWmYff6HRvbUAuc2AaDZaiK5aX00WSK1tbQu1SyVf
t+amQVrMiVZWyitt9SaEanb9rHjNXFZKNvCRJtBsYsOMzrJAZ3H+ZQvTPddVYLI0
mA0tDSBTIJlOOxLacDNrg511OqWYmoP/a8Dl8pHLc2I3eM362i0tyZrb1OS0YPer
2TPJ2mhrt9oSsGkLG6MntjJKn0Mm2Wn6p29EPvH0r8cVAAD6J0B+rFHKcSITJZXw
3Cm8Pybm9FdJZ5U2Mio6PqLQFHwmmdxbG75f3QmraAn/eoWJtQ3HydjmAu0mB/zp
CdIut9m6Wvl+0wat8zxZzGYTbeh92zyxtB6Lee/UPLxPDm5OaWg4m8/mt3aqi+Qs
VYRieR6J5k6tBKfRqoJfW5nBZNt2W6yLFkG96DSB4emcuuupWJD8rws28U88Li/8
GAMAfhz0s8DXT7sIps/+5qFFMBvnukhZJFoDec8pn5p+PPRE3e9jFN445W9uU+A6
23Pp3Od6EaqsqxoBT4hEplUWqtXPK03Gsz0JWts5Kscrpg1QZy3s0wVdbydmMz4b
+cLHFgA81sH948CvlFO1OErypAQ4V2bYnOWTWE2G0fDbStqnTC2Xd+7pGlb5a6tw
2zYKNaL3sCfkM+2p4T7VPrlpCltWzdzW4InbUch8K/7TP3Ufb4gDLbAt18sJmVZp
uqdy9N442kCmXp22xdSWjH4pRG5bUv6WpNjO73c9h7QIAmZddWUEay33n862Xhqa
zvln+80Chz/+OB2wf9pVh7nrV4GPgPye8oHVFKtcWrI3b7Ca9HGne8LyVcEOp1do
A3a0vzmr7zVTYlRWCT4GBKWiWG0Ma2pMWJLU1knhbF0zpCbqvI97LOqCkGxQoZIt
/RM9oRaespY9mTesqzVsjyVUeWXzO3UAUmW8ZSZzpKm2CBHNNpFIfh3lGSj1hA1p
jTGXMlopJt0fhd6LFCveLMvTte6b7SnNBiuOz6popsKiXMGvzRorUoFXvb+mm4qk
Gb1C+ZqdARFw8h00C6zb0PvOd/2W2c8mPO8K6EdiH/gYA4DHD6/8MbCvuSv9UyIv
GYNUnO40u3CtZlBGuSzVjqbqDAKST2omD0rINhxGW1wnl0KWHid5v/re3GygMQ4G
JnmO5ulTk1a8xHhFn84YGslTyebfMDsWwphqV3LrfV7BQFnxVt2EzlN/rvh+WUty
GgcV7cei6mx5rJEQfc7m2tWy75tWWLTY3OtPT+87XVDkPqNuw9o4p6rdRPMh400k
bslTp31RSVfsSFZpciJAVcVM2sT5q2PNlCAI4mY4mG4HpaqLypKI1hSfjv3XlojM
tXX1JPZnhf2UGkgi+vs/9rid72nIAdddrwPfD/rHXJlnOQGJ1M+PUAFjVh0DSH1+
GQvPoOoov2qaoWqludIGf58sPZn03Grl+2mr58t2yyc8+wWIFEp6oNs4O2041ycl
NlukOj55R990fVYbwTr+xmzoSqO1r8wuNTz7DOUrZLQlt6TM6RnKeiA01giQ6vlL
CejknYJkoK5px7hZq6FtuyUa4E1SSFDajL84Er4pbT6Pg94X6ut1nMHM98e+7/EG
ACzG9aeB7wNWCgOlMj2EJ00npdrIOfmvpW4BSM291Xn3gppXgW89vdFMxavLtANV
eEpH7fXJpXtTbbgpNqwUXaQ2IXcSzSEBudxJXMGMQCOCmPZjkf4mm/ozVUpnLVKH
s5XPpim6pNM0pcXnsBkqYqnpZqn7eVtbojT7Y5fV0KbTqWnyKilHkNXBaS3ujN+F
ADVCpfNLvPSDWmIhqixJk1ovmfP6Kb+rnrjdysNWk+DmKPZ5j/1alADgCPiTwN+u
78MvNhtLWUA5FTowj3U4L7hactIgVDr8xlXKNVy35cRJ886ET4dks9nW1ynu8djR
s2zmL7O8P5yMauFsbyc16EXznHCaXiFtuee13WqSiqUo0xoidzDQlNWj/linmBKU
7+J5IXfN12ST3pr5FDzOZCP+ZOzzvhoApK7/H/AnQN9XmM7cHpZMx3hxuZWzuGkD
rKjoHfM/GR/duYqP6teE5h60in7DBbOVxUX1MqBJoECBOS9RVHc9A855SI4yZcYN
VHambhxubg41BlPz2ruu1HmlaM26k5oARBuYsWSuKmq9M3xjTQK/YlPd6QUC2igK
1ZLweL4EMVVomta4lkqGxCainYU/k5p0vSnDYvM0RUvWSLt20KaBZJs5MdQfmaoL
/pqEklLcsSfo/EuDnxdjX7cQ12mrAdZd/wHoL5dtwAlRnrOy3jVXtmTTOqiAC/z0
SXXxuMPAaFb/q2qTZmDH/BlfrmBP0wxZIg54zebEeyVVflM0TpI6NklgRZ1U+Uph
o9qUXnlS2qMF55+wrE1f7Ne0yl1S0+E4kMh3X9TJ/GWUAIr3S/+5zdXyiDogSnFn
Q83rPaqOlBxjoVqohM/zuWekHESL9EBSnlnmA75o3RhU7PTsfm1sizhO2MVO3iW/
j0Vt0cTK7I5GxR1qi0oqzpNCu20hAM8F+ZIRp1AHbKM5FKe8e6huXWkp2260bxtx
r5HuPqJm/6XfRRohAJpT5ijKGaeslJSMRyoIn2T2qqXHROmuLG25LkrtlkpBZdb5
t8nc/QeLxGuwSAgAwK8APwx8b3nofAICvjXtqrOUINTyTWdoIYXqIi2d8NS2A8Xq
aomb0/uODd/8Wv9aTEQlZlo1U9owCKnLdGTKXKvJt1TnaXUlVrZyVvMBpVKn7J6x
b6dgr9rQ0Mokn2uCmLR/EqV++bU6cmvdNdK08l9nWINNgiGtyLl1imeu33/uQmVp
McKu0lczJzRIG9rx0uuHQX5lEY4OFzUAAPiPgD9IpObBXPusp3TrJ2oAtU73WlNO
XIryXaXPPE0RYBMpD5nBxtQZqLq5ruItaGsoi459clZa6vW0JEipgPxrK6pmW58q
RedfPoriRBeq49NpdNnnvFM1O4dFBGuOTq9uLJqiGtpGanuaQkut/fr5V8SXZP9z
HelZbX1d8fUJrIxmezuMfNtisRouYgDwEPjPgL8+nwXRdFGfdEYzzeLJAr7SmH9w
umi3cX6ickLPIA3PGk+SjU5yAYCrbEgbGBd1Ott5UfxmQ5i2yIPMMNd6svswE2BZ
snK3ZWhg+vMns2fHx1461Rg0cZizOn49Yaulp7T/XGPRXMxImEatcg62S2v7DP6z
2LctVgCgwiJefwPlPxL4wEkYGhdVrswhArBStfldRUFS4RTyJ295yLHqeW0jA3Oy
9L7NswQtjYOqgO+GMrRSMqZSkS2YvKOp4wZoCofm2M5EW41kKV+7FEdGHJ0bs5vt
+WTbLmrsYp0GVOew0uj5tMI2m4ZvNz72at5lc1IO0paMpz2BvVrVDHyKnSKSr6/I
1qg0N1s6d7tVOU/ZNfdF4G8soqP1F1ZmQfjDCp+pp/dtPuFjJq8xM2ehsGiGIMBK
0Whkmb5cdqz+HC9zDicmR+9bsXjzMHnB4aUCodRYzFbg53qH6mK/DFQpWeFZKVZi
pWyT1CAoxV7/SkrU+APpc3NnlXlbSH9cVj0lbKoVJmmiFDn+5ISUqniEYSVb9Jr+
y9Oi982fXmUJs6v47LUisBKnw1KpMfuSYvOsRHfT9NrFYtvi2tDWmWt7568VnU6p
JZfy1eXdSuWFfYX/5dx/83i38rVd+tSpgLEapXIVVUsF0lBiP5vs9/I9/ocX1c36
LO71WeD7Ff6YFNObmd2TFZtydmmK3jkgAZBU/dYGzFqTaSY30Vavb3ETfYoD0I46
DSYog5wUv3/1BI67D6Qyu26JABTGouRJJZUuip5Af7mrzU8a/0URPNJJU4xOOkUc
VNRaFCuyM63z+WR/2RnR1Eptr2M/j5xPqO8RV2zM35/qBLHS6A3nEwRMrJfTNlTN
2FT3ltSoaNkaOEkIuc13CEXeiCYoh5nj/DlRlO+PfdlXA4Aprv8U+EMK55JOvekj
gDGBlpUiwSgik9Y3U1vNWb7MbD6lEo3aoURz2VZFIZkUHYarqCcjgqF1mYjgqrCN
MhxbQEHGanBR29C01KSKm/2wWEjnfr8sD0Jh3LTNc1COPMSXSTmj2k2ezsDqq39L
nqmFaXa8chSrKKgtQZdyzynGoUhfsY7mDeqNqarFlV3GDpbxCYwyjSBS2dgVeBm1
GH5XOn9TbCnWyXGRRKi/NkX2zJQjGDvonOkoO/BzH4iUtTpZ3LB/qvtoqv03+5VX
Y3QJoUFeaaWWYSmdrtVn8umfOfe7E8F6CPqfLlLV/1kLAEag3wf8U6dxmzoHmG8b
W0q3MJX5z3KWlOpPL+Tuzd6vatFNw6c2g9mvfM8k37cuAeLyN1AXjKcOVbGazD9z
H5uhhRBsoY+6PBicH41xJgd2UvumvzlZb9VNkJLpJ5ne68+hBgBXE2Idn8L0gX8T
hYkyrktVRU0dOqiOYH6eeyrNVSGNdkh+ahP2YNezqvMgprLAVfP7e95rSEtNiJum
Wkt2gRZC/NnnL/X7Qv1FZla+L/ZhixwAWBb8+kngR4E/oCfurOaQ4pQatKpFXk0J
djIlN83uKqcw3sWOatts8+V/7nT+0wUpkio2qo4V508J3C6EbJPtLNyGobrg7/Su
mUu/ZLGeVyqDgCYu+SQL/drde7oneRyU1hm79aOx71roy190ExHP5fcpfCew2tTE
aUVylqb2lIKER3MRltKoWMrYrdJbU6ruRBvyi/w/JMN0JSXfNFYmU+dJhMysSFa2
CYWa8p6at3VF63VBgytWq8oUxmRHtNATbapcKI1GrjX4LVSM8+MInPNHbFWrQlvs
uvbvYbRcTrhgL/J5ppC0/5UhJUqjdT/7fqp3/mUFc6Ll97VzcZZt9EKaJR5KuuC2
TX1/U6rxNsGD1Nwv8/nDOPtf+MtHzkQIsB8P6D9RzVFd1mSWedRH4v8LJUSQ5Lxf
221LVRfrVLqSPu+ATaMta0VzTjwdvafqCFIMlCJF5TkhpFhWlZM11exiny+9r7ta
u3iWnVT8p7s0Mh92bb6cIpk6f55/TFPhL4ubOfn6GsPmRH4kdyZc/NYxVa5TyjcF
/QvjI9h8aBivb1VHl0f6fiYbl+ZV9dqsfW3xB5JuudWKlaEt6jmaGWHRQl1n+V1z
jt9KST48Ue2TlhX/s9TQpJ8xoefNL7/a8rSSQDb5uSm0Ewr5IsDygF0zQXgDB9/o
KFcm+0Qq2Upn5uenUPHfjt43/wzfpyL7ZyMAODvXjwA/ivAH5gHLjQOB6fMbLd0I
k+xx8hPT+IGlUl0r93VGa+h9JbWNba2Y0MnR+5pSR5clp7ElSoQNMszGCEKbe9Xl
WzXjoaa2J1wb5FLp000nvW/ubFcdzr86I5zHPLvXVL2KpW35HScr8KqlWb7EHQBt
B1H+/+19edCuSXXX7zz3qmBCUMiUSrAYYsWIFCRCEISAVtjCFiaWUUAZIgFDyZYI
AQlUQlIwUGxhCRYIIWEGZzGkWJRJWI0OohMWw0SCZERmKgOGGmZgZpD99vGPZ+vl
dPfpfvr57rf0mXrnfve77/u8vZ79/E7TNeZEo6/tu5myfLUZ8O2aM7V14tdCR2tQ
HAPX/+8QH964/1FVADB5AR4M4Lu3HrABQ2G7z4Ljcij2figayDbrX1+ElGNt21hZ
a2/Wxo0kbraihQGh5KcOpO5/d8ein73Nu+83HWhcOdfQ5iAaNNDBgUQcCO2xbs7z
vooj4vpfFAA+/EmANt3CwOMBfsdmLsR1bWxVOr+2pafwdFY/V3PUddClxGevCmB9
W631P72PpLLDUtkwlzw1aqpCrGcdFnsyQbxacP1n12loqJeUoMCVtKjaH6a1hOVn
VVkumSM1nxMLST9b1pHFZ3tKFZdY/mcrVXkHxZ5LPIbL3x+PMVx9lBSAI0fvBOhS
gB/T9qTFHdRiPxTeemxLL0z4fkqUt5ldLJcCeN9oqfBWRsEeopzJM16ya+lsaLQU
+tzB2HfRBCbSBAdiq0k77HUikWrGkiCtRW62na1pOMHouBT0piD3fTd4X1tpzaFW
bheycpOgwueSP+aCJknz3lELxbQ93yqWD+t6XjrKpqNFRy0EMNP5AD0Y4Nu3MVBl
hhTA+xISBcOI9FrPwW8C6QQi/Xul+vF5dtsvl8nYrhEmE8CnsvzRIPFGYl5+YpRx
cwJjHI/ye12Czb8fO2I3zux0MA/X3pB9Ltzqim1Tkc7cXDUyOO9xs+ONBy9AmZlr
cjfcs2IySoFOmMh3aozmauF9WyhZxvlZtsKtsz9DPQcJoZQXuJFVXhJvLZyA6DOD
tTA2hykyqin377zDbfMTctXu3Ajo22rk3EDA+UdRkB5VBeDbAM4DcEXbSyhZgnbm
LblWpXMuhsDu1rmQco17Yu8lK/edVMKmnaO/DN63rIOZEuh40MIZLT1+hTdwiVun
ufBnwdPkCnrjMsLBZ1wugG67HZbOXGSNLAZpippsJUI2BX4DpPTwXe+f1Ba6lUro
Jw6zXeciqCl1kNJpQyg3P7OTUrQn1ewf5z03ROcx+NtdAThY+jCAlwP4hT3ssrVR
jplbTjgGPk8WIxn7EBXUmy4XTkbmSsNTEvykObLL/Uj2E5gmLEuCDBWEEckzScP7
crbaboRyNgEamO11GDimnERc/rRP/DLFTuzQku+1OcU8wp9KPu4FtnpWak5NALrs
rfNGSyo4nwLyGdOiB9vw2mQpzTPK/xDUodvwrsZyr+XZcOyME4fsnQvuHztnwVfw
JVV6C7wvC2thj8PA9wUNBABnQmVv2ZPQtx6oFpTmf45B4a+FCHVMVRzG+FPAzg44
EvYvC+8bBxZby6pPvXyURUczWfL0UR34RM/BCBD0Q9stHfmw5GxbF8wsgipOnPhu
CmzpUEOVlQKbddlKilFrsTXMSqfpcyCUFFY2J/ojeMybktYHCVClOKvCP+jqJ4RN
191eSzIpKdI8L1ATH6pmr+e1G2BjSxRD5XLegpWUpBzuYVb4w+rWGW2kY98/g72Q
FQN4X5J4gJvsR9PaERJl6hQPCcZOJnmhIxc7oDHUMek8N9z05jWB97Un8UmAn7NX
R8TuAdDRowF87uzugHS4BuyVGXu4SVqLFi52TRihdee1HXxLtPVE0Fney4NfO2SE
f+sTdbbIkH7/cw2MdMK/U/5UmNQbH02HBMr6JCsA12Ksvbyw2RFY+l1rYS0l7Xh2
10qWsczOXcuFIpZYKtrLkae2vBDyuoQ4bzlw2wqBZiUpRXMLFs53OLDwWbmSpFjj
g6PcHsPyVbADra17pm5+2hOkP0VcdisoFULaopDx5r1h8cyUfgNn7qy0f/W7YN9b
qS8Bo6610Pb5UZH/YfrtE0bZc7QNvNNEx0I9vAgjQNDjtwj9uW6eiKdwNDmlsDZk
qVuSK/V695gNscckSbZfHYhf/31ujI2X/zz2ykboIFgKtBOD9xVCEUQBe11hZ72E
JdZUSNhv9eqMF4z+OSudIvsBhW20g8Bnjgp/ttIcZnhfEtQCorjyYzz7j/zzWSxj
pnbV/vnlyYtF9pljb19cfzF5fJYSCawqBYDilj9xWuTIXRy9rnpij4BUguAWiN8Y
1LTd6tuG5Zb6880lrN59Y4rOPZgfJ+4GkQu7z2wp2mdsZhYIVyIo7jU79yREy/OT
WWsU4cj82BpkLPREjBiugcvj6CKALzoOgvM4eABmOh/AfQH8jVpdMSc2qBivfBWC
GquIp/9LAoAsaF95zCWZ9pWXSGB+aXjfmB1OFbsCN2lsUobKlJqDAb3KAQuv68Lx
yoXoisrWSjt4X2HElhThIXGSF4iFEosyb7u1sbtZXkvHFC3xYLTwpsW/h7JvoQ3f
EllRYkfAcxH/IPW7WKx6aJljoJlfjQeMAOCzo6w5HnGV46QAAMDDAPzJHg/e88rr
acDZhiJNC6d265bfjaN3Abl4jn7CX1xo7pdBTTsedtrllpR7fA5L62TFOKgQdKdk
k86aN5saDmj3+T3sOAnM46YAXD15Ai4sOSicMUi2g6poGT0nmzOWNNyk3cabe7qb
Xd/M+vd+LocvPtgyv8D3QLX2kr/z1Oh8Kj9k/JhU/HPENSdUQMHzvp6bnW0hMY4P
4lYloJ/IviWct/4zFmw68S8zx01rUaJE0U53UzM/zR4ZRNA2z59kTFcADjFdBOB+
AH42bNdIwR1aIvN2XLn2+JF9aEqhgNPuRSZjqwlTe9LWDVBYfX84y+DK4ncrIplU
wM5rD+TiZ0dgG3fo2pQOnLAC9XHd69Xq11qxNXudEiRmwjiBN+6oirPN+qN8L4za
sxyFvyUh0MDY5U7ly/DqvSHx6oiCDHUJUptrocrJ4xlCUIhjpg0VKBQbM/Cj8L6i
MvrGSbYcKzqOCgAAPAUw90GAD2BWAIoAIG6j8PfYVx6lTy/8ZygiCwS2kejSo3nJ
6gpnmpFo46brOHgwIXAfcUbRiD1/I/RsI9tjToRkBXyrsdcCNmgSNRghq6zSscG8
29561WFIIfzLXOpt7O9wfhyr858VmmWYpoFvwV+LvN+CZ7AnawxUMI50P4kS+GJT
uSOa2zA3I9cq7tpxb0EiTMD7Loq3k0b9yVGmHD86vV+Ti7NOD8WID3DrRWgmADNy
KHRF1j8ZV0gGmVPG00LjzMJJILTQ1hiMAUNDORYi+kWtf4thhcmR7Ml9Sics0Srg
DJl1vlOskxZY1Jo+5QcD9pNKILXPxYKTyOsU3b3m+LnYDDbCgrU3j+WUMwN7HMYe
B5FQ2WoSjFWBCOfjs9upZ27SuwLff50fO/d6CAQv2Yo6l41Zrway2MHPuScLCCCX
wfsmMBF4qZSZDZHE/MgkTvJQcPIp4jFki8cO06AMylIYSc8/Od8XIR6Osc8QTQ4Q
+vokS44lnT7GQDVfBPBIAB+Ussl9nd/mr1vgUxnGqY1ehTi5z14OokEMVteJyM0d
1xZxSRaaGTbExBnyaghQnyp4X0KIYpi+jwzGGTKWMsCLIBqfdMaKL9MksIxufsSQ
+zu074zgd4608f1deF+C1G9iHRrDB6B2FIlaZJegZfIc3z/jMc/J90D+WWanJwZJ
8L6OILfj+0Oa1VshAHt1itJeIy2h7fvn6hkSrDUrlcvciXDhfUFy7vvpgSee4d0/
iit+aXhfuz5SmB955y26f1SozPkhlXlskgeG1tLo5WP2mfHPi9BsSDU/jefA8xpN
/GUOgYHxyEmWdAXgCNKHADwLwCttzY8rHIzpo79a5brCprgbys5UYCvzm+P94xxB
sZeFu46YM05IFsyABDDRbKARkg5NCtbOu+Sk7VHfVvCzz6NZwKifAXM4FWChYE/z
Z6jWMo0xcMtKS3gG3fCWDZWr/G6C17eCvPCZINdtnZlSdSictvrs8zLJi/C526oC
mGItY73aef83DryvsNfBuiFxF61OkixY5ar9i503DpUNiuRfRO4+z/gdzEplowS0
KNZLJaVGubd1WqhnAfjQcZaQp3H86VUYcwHObyPuFR6moqfnnWEhOuA+o86TqcIb
0womajrWfXc7Bu/LmnFoqr12LUujgne2OMsugJTJsGGVJkqt9pqUz61b493gfbNK
eI2ySOX3tsZdyr5xwNv2L6sI6PNfrNFcOMmOY02nTwhM9BMMcBcG7nU2B0GzyzVA
ooqJ93RZTr31zxXvLAVmVSYyEax45dGgVMw/THsULBfKsJ5k6IQajJwSwsJ33eeY
ryaD3avA8cCvYmecWp3l5evnsAfLAJfNlNlWUM4h8Fd+/pYrXtUDeB8UD1aeHqpa
j1Jworzw93bvozxC/R57Om1wMogZD2HQ1QC+14X3TfDkpOAKS/7m2KyDykZuKHD8
nR1VNbDjXW41gVlgWonJSZiLZ2RrTaj0RT9oeN8x2cs4zyOxuU+ha28Owm+p8MjA
+7LtCSWISVe0xCzJYUyre9hYUyIhslEGOxuWiLK3Fl6/efLHgPE9nrAsg8oNSzmX
LA/yEOE4H3lPwfs6b/BREZc5TN/n9aJ1w+xUfZ/YekaQpMdszc9vAynU0iThfd0z
HmByBlE2csZh85e11C8H74tQUbR5IMsnhJgDXhuOObf2QhWQ/VBOPIPiwt+D951/
/SUaO8yeCDptTk63uq8AeBCAP6w0hqMWeM4qooTFR4mc6qgbrykwUdwFV9Y6ZQu8
L3uFN7XfsZ86qykgjMP7kvAnK7u0NcagZLhCPVGk4YoEjbWY9mDYdn8b/0bi/vE0
Ytob3rfMCqWsFU6KmbLrTWI9hgAXMZJE7g6F781+O+uhkIFW8MwZbJPwcw8C8JWT
0kDxNE4WfRLATwH47e0CIYHsRb7l1ojdEddngGedcux5IuTxsqITWfm4ZoEYm5/G
WViPO48NTy6H922kx22VSaw9c8DANetYtuZl7uAUhsH81dqAvqbcrXz3hRZPaRFJ
HG20EBXapL3bWgUhtWYU97woz9EucNWJdQvHb3K791OTjDgxdNIUAAB4O4DnE+PF
LQW/fR7dkrXcsSQH1ifFNgezhVHpY/bRd5IRLFzaMA7OzG9rOZZteVjPKsAF4ARD
K4eo1VtqxK2boVhjMKfUTxoMFQj2+PzsDs2G9lLH4LZdVH1LO+E/9xUyVCgwmaBx
BwVv4VCohR8qmd+QUAhsPAguO3FcKvwLlMckT4yHqwR/zPMn2XCi6CQqAABwAYA7
A3iSxuoOu6xqbcKlwbB4xnmGIC5QMKqZZITpxi/mNtS8OdYfxGLtZ1KOOTZwxBF7
CgC3WE1rDnrvDXbpKUFxBkpuzHQt3kvlmdeuffrM2YBR3GDeTLGt4GZHJzcOjqY8
bL/DETjaBq4fUzlnCeW09fi4zX2XxpzWQN48yYQTRydVAQCAJwO4A4CHp6x9LsoQ
1F+uBd6XnJSwBnfAVNn/4aVpA+/LsQQ80ucibGMo++D+zyWR4UpQdK/rp1SKZMje
CxZAih2BZ6/FskbBYNX4xA4MVLrTwnMpMooATrftXmvlKweoBsXpmwlDgAqt5VZ3
KHwuo7WC0gKtU36GDe8r3NPLJ1lwIukkKwAA8AgAHwdwj6QWTrBQ+CYbiil+8CzL
a03zi8P7Ghvel4dGl3Ucg3Gym2W4zhWAjuMMvgjed52fIeOURAycszobsm+SXIC6
sEKKHbnwvjaULAnwvjKU8/jXoYqhhXvDHnauESyg9XkueBFj4JhQ18bQ2Znf+rRB
tpgr4X2ds+zfP/JEEtv+DmoUcmDPkhyEczFWGdDgd/bLn2274Zd0T+dzNv5McW/P
sthUOV9ZwXfhzskJXBIaerjIG0MW3jfVbdGF9zXsQFh9YpIBJ5ZOugIAAA8E8EcA
7ihp4quA9iFRBQYmwFOSAHZjLIbMFswlgdpAvjpCgAQXGAkyklcNOaiNZI/h6W66
meB9ybaF7e6yXAYbXMdQfHhYTZOWHLwvY2BgwAzZK0M5+0wqhPe1IaI1TE6a5rD+
O9tQqDLSmXs6VyWRllLWnBVJCY+Of+aMo3CV7bQE5Rzev3CkErxvC6s4N7/1m04N
bDV1EhgFU1bVcwUXKnpBNLT+ybX7mU45sORAOyj1OnjfVLjSgDEAGFZlfNRVrgPw
wJOS7d8VgDh9BcADAFwF4Lvlo6WFyZRdoS4ESg4KuAW0bymULIc1AJRJWspYDyxm
/hDmTob5cqiWpI93R5v6xOaazKGwXe4le8KV84gpQKsAzpUw5oWHPAaO3BROlLLS
lv0jqR6chbMMVYGpyiomRO8rnGwfzhTzKapBSMAK4JyA3UGcRRP+qNpnVOl3gxyO
Una4dBf6qwAewCPv7wpAJ3wOwI8B+AP5WrXTvFlxkdrIPEoMx75Muc6Esc9RxOPg
au2kZhEcuvua1Q1ROfuxE9ikEugJAIjmOUamxs5OV8CWqvbEtxLjLv29LB52LGN9
hbkvx7cLtlXdLmoklJkZW6Edk8BN8GG7c/Oz1yq9Bux57jxvCGvDNSWKtiT8Zx8m
FSiuJd+j3GvSCX+2OqtYYZEfA/hzAE4OCk5XALL0UQA/DuD3uKTWWUSi4shx3sPV
rbx8bBsRMfukBBhktehDa0WTQNh67rzbE6Rkv6CdSxLeVwtqUrGvwuCZW8HQQjF+
drxasvDfAarakYcCvC/81D3acKfSoYctyign31eDQJFLrmX9MMn9LCf5wEGLUj28
rze6H594faeuAAT0XgCPZeJLbFk2Q0Yunatm61aE9+VAyBrnOPIK77tkprqaPQsI
gUVWo/XZgScGPecKScycBPEfxBy9dqowrtrgZdrbUMjMMsuYRqhQHljPDMTSQgrX
iwk+mLNtifnwvp5dF8I7C84XwEoEk86ROD7Zz8uIpL9zagxxxAb2rEjXO0BJn5WP
RMfWHbC76c0ymRI1Eu5aCWeZlw3AYMt4B943PK922+IyBcBP+nPvuA+N7Yf4yDYM
lpNFQv8Pq6KBQoUx5/xi8jtO6IJXpKqIocX1xUJ4LETt5OXClId1ZChnGchJSjLw
PWYkPHkpfH3sxOM7zQoAn3gnSGDPXIoxF+BNsv234mSH8OEU/N8t6okddv+YbwHX
8R865OBZEpZDbBzG+pMQSzrzU/zqrMIC657yaxF7qhYwlKLPtTPhEVFCWFZ6tFae
sijAXVqKG3jVXgjZKmRhftsR/qx1i8L7cqQusCWMsgRWzYl1zO910lOiTvpjr0Kp
bVU+584Y8wYfS21DsfjN9WsvrKc9GcClXcL5CgB1BUCgNwO4NYDX2vLaLr2hgtrb
lJK1Dd63xYWPgYNoLh8hhxsQAq2WWGVbhX+Ma8lo9Cn8OMruNXklcFv2muqEf+rz
3m4Pjc4bO8/dChLNNVNqPkPd6AjxZL8tMy11p5dC8/KBcZaqe0005hNlS2Qpa9JY
9AwAb6adZ3UkFYC+BFF6HYDvAvAS4tklxxnhv6oH2iZL+8L7xt7p1leXd+VKCV/y
5kd1hn/Ty6qDOo5B1JKSEeVY95CFLeXEnrSjbaJR9m+M2zxUbnUue5tcd/9uM5S9
WGvZrqsipnP2SHWqmbbvw9mgertRA+WsgfeNcbVgQZ838fJOXQEoppcCuBXAv6y/
eLyz5rz1nXwWxlPSjKT2u1uhy5eNgXdZxw1PJTRcY/mzXO+nyY4j15eybRmDDo2A
mu70VrRL3vlO7/FE3uWOKPbkVyYe3qkrANUH74UA3xrAc1KcdgTIMDudf1N0TZhq
PAYK1uU09M71greMMZODgCnEJ6c9Mv6n6KEyi93Q1tbDJXUHXGNoNt5/29KvU+9S
4zAUE75mp9JFo15P9mCfq3abJIEVz5CRj8Ve/EWBr9P8jG+774ayp+5lAF7Y5VdX
AFrQc0F8CsCzZKHAHkymm/rXLsafdtUz+XXsq7uMYp2ArCzrNLyvPT/jFgVEjRIJ
xjNRluQ/iEM0vXjMkzaxI7Y61dC0Lmtup7/OPryv/dcNeQ12txwibx0TTJtCLwZt
OEfS93BOcLCVGMuKuRO7CqvY3YeDrPs2roBEpn8M/naC9y3NcJAF/7p2xDaqKCmF
fwjy1ELw+/u8vYUGRx6kAYrQwfuyUJgL4JUAntvFVlcAWnoCnj398KzVgggFMHnw
vr4w3q4MxMB03O9bgTptIBM/SlYIlzLBIo/wviR/tVPuVDBXEubnYL9z3VrE2D6F
jHDgWW0zXiWGAPlKs23ovtcu6SLWzlmyCFllX89M24OJ8fbaFxgG+b7vEXWBwkYw
xegWdl8CssvYKKg9pwWi2i2OJWwB0rLXQ7qr6zfMhXBEdrGoXY6WVp6d+h9JEDqr
qB27QbxUs5K/UCQQVQ3vm4JytqdeU3kynwUCD+y7j15JwLO7vOoKwB70bABnsIQD
2EsJ9EtyZnbrYsDXC/5UrHjt6sPKjm1p/1/kCZQG3KgS/tn5sTO/FS8caibIGTuY
HeaaYkgUMHfdOEr2hFIyPyJiXEESXw0jSGvWCX9NcqtqzML+kSUsghJZlnxuG4We
DO9rvDO3FPORyex3BuCHBKuWLa6QhPf1FRbdGLS6WPun6oV5/p7E+MIwqmauYfAy
Bp570vH9uwKwLz2Xga8T8MvS8WTsefwoc41JGEVJHC4HABPCGwXCXtXhrnR+9e9l
z+61ME4iuzZa7pQxzPI9G3wEvRJ4X+P69zNKBEl7RbleBfnlNYKnIVnA5nVeLoL3
zbx3O858TOfNwfuuNT00KaE541WE95X2nNipcCBL8eHo/W3PX/avJ1B6m4IcB5Pk
d7wsMAHAr4z5Wp26ArA/vZCBbxJwgSuAeYerqcPv5qiruJXAjdnRJZyENzIRrlo9
y9hSrECuv7p2HBSXktmGJVqoVU7OnKJ2aUycuo1tNMKf1Fus8Bxkps3R/dgm7rg0
UpX4bRw8hxRBdU5vT7N7vLfwL8EkKCs5jjz5FwG8pIulrgAcJL2Ega8D/GvL0YyE
bamJoI23snUjbBp8u9r4vKKhLpnCuJ4SK59ya2Fbi677VgpaDFk+S056BIv7gcRq
FGIpOLKZEYYaWMHz2VEHKWZNKRIV5WprzqtD4rL4+7x+aoAV0WZvaBxTT2qEv5w4
lyomI8GTE44hVACiWoym5TMDpXUVegWZvVlYq8EEpzs316oVrNRgKHEv4sgl7IJx
g4GfB/DqLo66AnCgNCGfvXpSAt5gx/MYW9D9tFnutGKJe+xp9Cx6oJisYZp+JYPr
th4hunnKkieBQUrCWiKTsJBmRskC5nd8LUbccgT4/ss/w8X3n+fj5C2Q3enMikML
8L7E6x5QErbVRNeFOYXv754DlkxtMlZPAuMy7eqWsey4x/2cD0r2dfAh71k+0/Ze
G8JAPGXLwwLcErwhFHonau6UOz9XgBJzRJyTo/GwkDXnZ9S7qgJn4X3tREG2em2E
C+ulfFLubhvnVnDKrcLk9Yio5VvCXkfnn7rrgKEhdpKfwsAbuzTqCsDZpDcCuBnA
xcsF2w3e1+4xn3pnzE6nyjFY+jcxDDEGbg+CWldsTRGbwX2kHuFv8PwpmdALMYgH
5ThN0XKU7E8IuVz/Jbx9cGXfzZpU8/QM8xZpAyuanJayZWe0CMkwdbslC7sEc5Gj
PhU3SsGN7zZXw/tG6HEALunipysAh4EuAXATgPeQpsa1mlnlIG3Zstb3iO6RZfmX
M58sk7Db8GWZgTIJkEKxm2fhhFhQJeRrJf3LWwl//9E5PHiu2+rqVVecZS4pgdsh
8Y3koFYW3jeFlcGQoS9a38GdPk/seWBa3uvKMxNJqn4EgMu72OkKwGGiywHcB8B7
iem2za2k6fLqUmPMtstL6feVezdY954q12OJDaUcByib8Z5WALaiHeZmZEffjXUy
WsEhb0lprRQepGxR2/rMlcTbmZrNWOPV0a+FrkqAMxZ3HcCm8kOqe7KeushTbwLw
UABXdnHTFYDDSFcCuBeA9wE4d5u1772zCN5X60pjubWqzRSrYXdLRAgrSuPy3xSD
95V5Ygred485692bcrzfViLYUyo2rh1tGW38+2MIgsNmZShGenjf1KnRexFiKYQH
De8rIFoIzZnSz+Ud7nWZwmfSS3YNgIcAuLqLma4AHGa6GsA9AfwugL+bv0Sl8L7r
54M7lIKSjTCwJUbuCWCKlhNqYo8h5GuUGxMnLB89vC9H5rc+JQ3vazbD+0aYaHRP
MoKK3Ox/imZJV7biSQyF7SzwbEa4vdeTUokIvO+018baExc5spXwV8D7zsl+05hJ
e+ZISKTz1vRg4H01/SHMxD/IO46plt5+tUZ6r3PekfRdl4Q/BQEZAv4AwMMA3NjF
S1cAjgLdCOC+AN4J4JEajT1nna7XLwL8EljvGiG9Cn9DxnrunBFNFcK/dH7sMXF9
glNU8FtCfJgFQgDvG8s1COF9y+Yb2xM9vK+7Euw9haF3FW8bcbloNpNVTIqzbDx4
n9okP2lmAky3V1Y5ryWLUebUmfOEf3QrU7kNUj8MAynDX7eLGre/pcmx9jal9sRU
nBTOKM9k5Usuz/qPBJyHEYG1U1cAjgydAfAoAG8A8LNp25WE33sJfxJWN8V6k8+1
SrpmJWFnO3aqGShgBgqhE8UAt37HEkOJMaWh2KJdmq2wyYLczmMzghuZrTGTppY7
FZbhdBLWnGcWREJpFT0D11v+0szjKHgFQSph3rxklZEHoR8bu1HtdVb4+/C+FCJl
EK0KQPx8Zloq2dCHTgkrFTTS8YF4yVoLbSiBA5wMJorXENAIYE4qpUXoGxFDNVxK
/wblvP1KlsG6CADGCqundFHSFYCjTE8B8KcAXhRnsyl7Y77IRmpAnJeICmszn+su
WP+caweo8UDMDM4U2ZqOA1yE9vUFGCl8IVjhXotHYa8Bxy0msYRM6nNu4JaRG6Xv
I6fsheEkTVM2GxaZ1WcEHigBBXvfDt7XjnunlGZ7hzmA902V6cvwvon9duB9/Vwb
U8ADFESacB2vnhCO3YAhc1dLvBv5c+7+ROs9Hu/JCwB+cRcfXQE4DvRiAJ9FZd0q
BRHHVhnlajNlJ6rrsl4d/Y56TDd2e1clMNYyeaOw4et2Xa22JRGEC2vsI0vdHESb
yjtgpE5BIPwPC1Hh+Q0AhbjxXW2i1j0WwKVdbHQF4DjRpQB/FmNewB3il4oyVcnc
RsCQxitQ83zWMw3Sx8R9V21ZR/tZ+FDSBkntSdoCr+2NIH8NIQwB0AEJf1LzfhkW
2fH4s9AGl/MzrJuVqy7r5kfCycp3RFx+G3QtzGmdtY25MufaiyxxwglAydvDbe61
6pyKIYovEHAeAx/t4qIrAMeRPgrwDwN4B0D3ky5hGMteM/5DeF9SMAvbPSrD+y6/
d0B+7GcOCeEdsVQD5piD9w1tMWbfAOXg8TwxNfL6FSzPoUiIgTgUQYu7ljLwvhxd
B46anmGIILAmaYwHk+1VYKkDY51FHPteYsUJovg8VsNvCrVMYeO5ymSRSELGv++2
LxP+LDxn3D9XKZHgfcn5gyMtmEXXvwPvS5lInH2Tvax/jgt9yq4LWU+V+28sXTG4
1hcSuas52G5F6bCQo/BfCfhJA1zfxURXAI4zXQ/gRwH8BoAnwslVl3iQ3aHNbLTM
OSKQxhilDO+rSegxWSNFx3xMqAQkHukhvCdSplxFiTMAv3p433qLPL8/bSx/yQbd
6DuKP4XWPIdVYW1h6erXnIVZpjsNpyFqkz4yLkFK0KA10sZ1kRU/Ut8/rrm4qEGN
8OgtAH6mi4auAJwk+hkAnwbo5SWsbZuASfFBasScJdOzpduzJgWuBL+d6rGPmpGk
rHHzp7Yftu9gp2wvhdbn2YX3peIx76HatTz7xU/lvcdbF/O3hvULAF7RxUFXAE4i
vQKgP8aY8HKb5DUh0yguH/49Lvyp4tmxfy63BjliZxiSR0pbx5pcD+8ZscS/ajhV
26/BFmDLNg7ul0Vy5QlSTbAoQ659MykJQTH7LazvKVFn+WpSVknhEag70WUKAOnn
x3WH3nrnLQAeg47p3xWAE06XM+FuPHYTvO92ps8Z16sWd50KmEYMAW+725qTAlgC
1/EZN2+0QjmjjlQZx4jDH29D+FueQHtYsDwpEWtt4KwskVgz36qbIAfrXQaNXeLE
8M+LJs8mdvYtTwRz5bzXcTDRRldF6iyXzM8UnXtheB/B2M3v2s7+uwLQabwI92Pi
1xPzvxRV+KCvtsy8bKhOO+5IQcvVlC24tS45sD2Lnh1n47wmlgFYG+FI9fs8AcDA
gaidf5G3jFLwvpaUpQKjeGd4X1AiG0OA99XuNFtnxoeMZg+Apq3L2Tg/+0l47hiN
Oz8VAsR6xziitCxw0szgqS99dI6BQmesP0u8aZS4264iwFziJ+DMjRuUio3uXhsS
3/lvCHhqZ/ldAegUXsSnAvg4gDdjY0NWA+NYIiPOVsytWGHlFDDuUHLq4H0D8Uhh
RvySrU8p5DQW+qDnkvxKW+vq4H194U6thD/iwn9b4p+xvAomrSSwq4htRFdIqIT+
/vmlfKaoZTWrvRX2GUsBURP83gS6VU8CLngqChUucqv5pU5bupkyA0+iMeGvU1cA
OkXoLUz8MYAvJuCusGxcuXTIVdCZxsY2QSMc4oWVDw7G/2nslx7m44VLLW3jLNAv
iZz/fooZBuzVlNtMy7KtLXhfcsrPZgVC4f50LB+yBBCprTumgHU77uaB27XzjYUA
CoCcY0+1rHAXXnf2MM1Z59sBc+yTYGzTflFG/OK+gQDgTAiOTVYZKKfxNFf4Ysdt
Y80zpvBRRImzz1creF9P3bF0AVIlBQiWO1OBQsuQ+1qsiILeSnwKo8v/qs7euwLQ
KU9XAbg7gH8LuzwmEFYcNUb18L4sM0cqaQ+a+n1ZZr8DVcvhaOfiwCX2rHhuW3hf
73eZPRlVBLvpTCaJsFRMCkpSO3jf2FhZtlanLnvz+WvR9DcN72spINZ4VfC+JENK
y0iHJKyb71Uyzo7vA++ruPtVihYllC/tZ6L0GwD+RaPj0KkrACeGDIAnAbgCY1OM
v1AniA8/BYJ/K/9qYUdXC2jJJ+u3UTXYYcRF8Ld5b3NbRaXJhSDt+ufhfUXh32Td
Ok30TYxN0N7al6IrAJ3q6a0A/jvG2Nl987yPC2KvJZZxbclhgQBL+yeEcfNGJpyy
qLh4iiz8YxgAkcB+Kpv7FKx8WfuD+K7IAD9pmGZsnlm5AsbRM4PoLiyYuinvF6Ei
o1973+RMzdU7JoEFFYL1BPOr0X7i3zv99iMAngjgM519dwWg03b6DID7AXgJwP8a
juXiRdtoxmNf4X3HKytl+UttPqN2UprxBO7ySFmejSjqAx5baQ4zvC8JagEtVjQF
yoDxxkpMCAogROGfgfcVJYdvDrIQSl3bHJMF77sK/nqBxxS3/CmT5c9Z3s/Os2ax
ysQR+ThnqDfxZVjzI2t+Vn9Hliop3J4PDNnED2GR1zySEd53iG4LO0qnFwZgjqqu
bgVfapEGAAbMHKAY0BJ6mHV9oxThXp5MEuUyd6/lb7QqE14KxvM6y+4KQKf29DwA
HwLwJgB3CgXX/INZBCRVW/6mgEkYBeORxH66Cp6iQC6EADKY8sKSWGmBSTj3VVar
m+2/Zspvt3Tbw/vmJ5zG9WvhE9eCRWUAfggVCH+JvtLR5+zR3Ce/EmX4/oLXTP2R
oi6X1wJ4MoD3dzbdFYBO+9H7AdwNwGsB/DSyArKtaNiTyljagFjXhCgvazyC4tnx
QX1Xq10oaRtNBzS2XMVGGnTnKGTKJIV/2NTyMIz3twA8AyO6X6euAHTamW4B8M8B
/j0ArwNwjs+sqbqxTymbLBMMsXdL8L5aazBvyCg5JtVa/zn73Ib33Z4AyN66bYf3
za2FySwFbfzWBPQT2fY+561/1q1Am1BFiUJU4iGhtJ+C9x57ek+skVwP4OkALuss
uSsAnQ6eLgPwAYBfC+LHpXOfh+3fRiUWYZz9RNOHAu4Wh/e1AY7QeCSqJ8Qy50XM
gHbft4cFy0KZH3nCX69u1XkZ4gJZhgIun5+0flRx9u2y2VqBapc1RvoAcMt1rq1m
kT877dXFYDyDgBs6G+4KQKezRzcA+KcA3gOY1wD43h3sQcTbCevr/OMM2jjNf1MV
/jOoz1guaMqtfJVlU2CtLRa4EYoSDFph++/RWJeXLHMOlJg5zkzNv9VEToQECmWs
rTDZs6GbX834OXH+G1ji5Pk1+Oze1czufQnAMwFc3KsguwLQ6fDQxQA+CODXADy2
ObwvSaAnOiaasoFt64wmm37Jkg9AYHItcjWwQBz3Pix8kjxXMketf54FFdgCYJJm
XQnvm+r/4ia9F+HwB01v5sqRAPcfiWpLwfWfBJMK/87R7HheMHVoelYRvG+iCdRa
CcdecqimqZW9pxqvmokrOJbHy0cvbJbE6Y9/A0QjEy4B8PMAvtjZbVcAOh0++iKA
xwHDuwDzCgB3rJT2CYElwfvaf9fB+9p/JzBO8WTds//91rOX+sAQ3tdRJJiUjNFn
+kP4nRnL38d8M7TGqddM7Q1d/bzv853hA2qDMV5Dn8HPIZH7MLonY0tLXxfed/Y6
+KL29MCYgJ8h4j8IMX8Z3hdxRSV69v1zaDzFp6CenlnUF1Z4X8mrhPrmShS5q2Tf
J/X+XQfg2eix/q4AdDoSdBlA7wHwIjA9s5yTpIrzUp+RGbFvTLNgQ/KUJBdCGIcu
eW4CP5xo5KKAXGbEgH0auInJXbec89lreqiA9/VQ/ghR747ftcHkBJ7inPlAQmud
v1c77//GgfcV9lpYt+iYplLBJcwxdZpiEfI41fhHed4olvkieR8o6BuxUX3M3tXE
M14D4AUAvtrZalcAOh0Z4q8C9HMA3g7gFQDu3e7ZhS19qSQdScdUqXnZGR3gp9Jk
EtasaumS8L6t4tht1ns3eN8aWRmsGx/Abh/MOlfQlZPV/+HOS7sC0Ono0ocB3AfA
vwLwqwC+K9dudLPqkWDEIUaaNsM75potYXiJZ3AspsuRx8fcxNsL4rS7QdW7Etry
nPk200SwaPavVLgpwHN2g/fVgvvIgNCcOaO0+fRUjfv/AfglgF/VWWdXADodG6JX
AeYyABcAfH66C9j8kTbwvmy5qGV43zmRjd24MNvuYTfjP4T3LURaY8lXLtuVLLjK
w2Q/9sZTIR4p0dWP82mdrIT2XRLqeN0zSgUNiGThEQjWlMVsJ/xRMD875yAYCwm9
LbPwvp7nIFFHmYb3jauuenjfyaUvwvuu60LLZeIK5c6bnP1QVgv/CwH8IoDPd37Z
FYBOx48+D/ATAPw7AC8G+EfiPCsHWBOPyaew5GR4XyNKTl13u1I7aUotzz7YYqoR
SFSy5tTKe5Kyj9s5oFlt+Zd/c0wJyHlsUrDP+bAQJ55bsi37wPvqVrm+yRASJ0YV
7/8YgOcDeF9nkV0B6HT86X3T62kAfgnAOcUCtEIcUZRx2YA5LbvKNZLGGbZL4mj5
IIdRIBxKx7lF+Mefz2q1x/JGMam/dR/arwdwLkqRHlPdumFE8vtVAL/eWWJXADqd
PPp1AJdizPJ9pp6lDtl36qz3HFohJfjaFkasiUHb+e8msxKNGuBOX2loJ6FGITZB
eiUydf6Fwn+WRYYKFQsmVcna/vC+Q6VCkEasdOAXWpOJYhW8BsCLMAL7dOoKQKcT
Sl8C8HMA3gLiFwL4yVLxkyw5oxjDdIXRfj3kSW+Vkh9/5YrvLKh38MLSFu5OA4uS
g4dL8L4oEf6iQhFfC6b9THU5pF/S6S7yft7eB4OJnKVpN23e/nnCO8D0QgBXddbX
qSsAnWa6CuB/COAhk0fg/htNDyf6GUK4svVOySovdT1vzJenNdYfIseTOL/ycaTf
GcvbKlsJD/52Sa7kxc2gg/ctrfNXeFVIrvmoCTLwhrVP718boWwnTnITbP96NMmJ
rpgs/h7n79QVgE5RmvMDHoMxI/hupeyIyS4xM26GN5HTr90BhSE3RVDfwpcV/56y
aNkZs/Ea+gycEh6F3f0o/gkbkbYG3tdIiZvWXOw5FsH7qgXgXJ1B4r5snV8qrMTE
C8idW9UgzIdiSAsaeF+OKoZsVxLQnPFPSYdD1Tr7DafSsY8/AvEFAC49Er2QO3UF
oNOhoEun11MAPAfAnWMsU4L3HZgxLCCugquYyGW6NFjwvj5DTQkKHwYvJlWVqgSZ
SYCQw8wXRh7U5vm+XlLbnf7QbDVls7M3KF1kcQ3L4X0ZulFTiPi3YX4hvG/M0ZOD
v/Wfaie0lvom2HnbovYI8L720TggeN/PAXgZgDd0VtapKwCdaukNAH4TwDMAPIOn
/gLpXHKLkXLMuIznzzexkgImrsH3lxvIyGGMSSQVJIYX5d/zxnzzRPMm387lovXV
h1pYO7yN3+q/M10rQJmnFsJJU7gGLYCqy1diOYjXAXjt9PpmZ1+dugLQaSt9E8DL
GXgDA08H8HQQ/uriBWCBBU4AQLLMt4W/XQdOWrNfKfxTLJhFuUU1uAKKrzbkvl1b
fLfk8lHJ/PNwv7MSwAkBrn3W6nEYnyjPz/7tEGxxbH52Vz8X4CfWqyH01KTXrm1Z
X3VSovqp0fH+GYDXTa9bOsvq1BWATq3pFgAX8Fg++DQATwVwBxeqxYcxlQTtDrXU
TGEYgGMMf4sPtvzzuSbGe1C6/FvyCxC2dfcbFjWOmwIYb7XSS/ePFM+YFpjcZ6XL
KXmvk/8FAK/HeCdv7iyqU1cAOu1NNwO4AMCrwfxUIjwT4O8LAGN9gS+WbtFk+c9N
+Fju1JthyGumtZeQEHG8r/CvbPH0dZzMbh6Ardy4goKzeglHnAUkRBDyXWvjLmDb
/uaMA4WDWnwrhkw5q99S9ygirslYj2FhDSlrnc85BMu2WloNOZn1HJwzdtpI26Ed
tlxWIVJeHt7X8l6xDFxlq0DkfWdZRoqv0DrJBp8H8BoQvx7A1zpL6tQVgE4HTV8D
8HIAryPgCQCeTsBdF+mWRYEbGgwhkm+QY6pDul0RYVAg/JV5Azhhk+qfkK54IDWm
whaLP2Wtk6iexYSo2vq3kxoXrSoFfzsIT2kB8Ut5D4WTo6dPr1SemE8B/DoAbwXw
jc6COnUFoNPZpm8AeCMBbwTwzwB+MoAHBBYT0tnm9XCoKPOrU/xDNCHVDY389LYl
aApFTZnwLxVwrZ3RU7UE6z0WaWx/S6kbpP6SlJ4aa9cl54M5GyTu9X8B8CYAb+vs
plNXADodVnrb9HowgKcBw0/4tnWM0Q6m5usaawwMDFxi2fupdLK9KfW931P4yzOI
rD1TwbqG32OWFk/saHIU6y7JUvhEXjceUIEJVbp/NZSH9210Lt+NMb7//s5aOnUF
oNNRofdPr7sz8GQAjwdw23YWFuvfF5QhcIPnxkQ5B7ZqXeJfvolOCrKYRcw8ar7G
64qyIP3qZr2t5c5W141ReQTaJnIGPTNvAnDRZPF3yN5OXQHodGTpKgBPZ+DFAH4a
wPkA7rKNWSq7zhGvgDgq1m02TzZl6fOG+UnPHQWlkYIpZSKKcvgJMWcBL5YwkZ1Y
mZjton+Fz3V3yfcoKFYw1sKaa86YN0cSGhu0h/f9NIALAf4tjGV9nTp1BaDTsaA/
A/DS6fUTAJ4I4NHVDJNCJr26fue68TUpzkelc7sJ5pSEtD2ahqi1HBFZORbOb/Vo
CwKI3AQ34hROf31bXyZRgi9rPL+JiLz5eUoEz+AQ1h45gQIfWpdAzMv8kx0gA3hf
+89SdEN/7lNlBa0hFAfSYqvlT/wuAG8B07s7m+jUFYBOx53ePb3uirF64LGYEAZ1
FqstLH1IVDiAQwyGmcBkyEX8AUCC0PThYZFVBtj7Z0E1KasXEITOkmFPPnAvL9j3
i6HsjFMj/Mu66K15HMaaH6vaDK3pkOyK6mz5XYlQ9fdPEwaxlAUSKj2IgiqHuTyx
ThHg6wBcgjGb/1OdJXTqCkCnk0afwthn4AWTN+BxAB4F4FT6Ywbp8rzB8gIgAu+7
KhAUCI+EcBD/xe9suFXWCvOb6+DBQttAu8a8NoIe83q4gtTknsEpQV6Tf0EJz0ZM
+Ov3T177cMS53oHKFT8D4D8AuBjAuwB8q7OATl0B6HTS6VsAfnt6nQvgHwP4JwDu
kRdQPqvmIKZdBu+rfC/NjY6gh/dl11osgqjNvHcF/qH4+9lCsbN/FuL9PlAQC8qO
ND/7T/cZDH+VWKUIEOZM/XHt1vDOJlFcoBiFng1WqTMWfQLAZQD+PYBr+nXv1BWA
Tp1kugZjF7OXAbj/pAycBydEIFm5fpvWUmCAfeB91UB+ue/nvEHNJQpNFvHPBXfW
zk9b/lYVOq+Ot5P+DBTA+2Ygl64D8M5J6F/Rr3WnrgB06lRGV0yvZwN4GIB/BOAR
YPpLAeKvQyYrLVwHdw7dL65s5IRj8DQxud7PZ1g/NcCKaPv4/hwT2QrBRyU1CTHV
gqyRsqNXrOM0WAGAWdBnNO55Awm2t1wJyPQAoNHDwMLZGpMR5yTG8U+h799XALwH
wNsB/C56N75OXQHo1GkzfRPAO5n5nQDfHqCHA+Y8AA8CD98zCzQWStDIzoxjEjAJ
JeFPSaHEVva9X2ZIPIiGejAyJ3PM+9MesyEMUznj6ua3oY/tJEj7KULyH3FEAYhl
/bP1Fbx8zFcwyFk7dx/CHAyvbRTNLXwtRUDUctjKyJ9x+OcvN97CSvj+qWRIL9SR
8tIw/JyEmwF8YLL2LwdwQ7+unboC0KnTPnQDRpCUiwCcA+BBAB7FwEMB3C7KutXw
vnOW+pC0ilP+hzJSfN6J12vnQI3GEAMxTglSOwGz9Lt549glKCFqshIWHMGNAN6L
MaHvAwCu79eyU1cAOnU6WLoeYynVJQBuOykDD8cIQ/zXHS9AkXChvICIVBc0g/ct
GnN7LPtVeHPl/Grn63ksuKblby0llZ0/Jcb7iXH5JPRv6tevU1cAOnU6HHQTgN+Z
Xn8OwI9OCsEDAdybuMRip6yNyGB1371ii18ShFnrvw3ML7cYL2rhj6lw7LFvocQc
qGRFrgTwwUngf5gY3+7XrFNXADp1Otz0bQD/aXzx8wH+AQD/YFIG7g/gDiUPMwLE
LBU03i2B9wWAoQEkcWQmauO79Bm++18PfxzJt5ijGIblbEoqWaMwB2EEWAoUhS+A
6QqAPwjg9wFc3a9Sp64AdOp0tOnq6fUmAH8ewI9MCsHfB3BvjOEDTyiulr4ks5gn
ZMG5eiyJMGcnrHEc3ndKiFtx7Ngy/Le69l2o3BTyHi9zwpIZT1lxXtmqOKZ9zMs2
wFs/rWahgve9iYmuBOg/A/h9MD6GDs7TqSsAnTodW/oWgI9MrwswJg7eE2PI4O9N
P9+Og1Q/dn6m6b8AYjgjhMdsfk23OWMjztvScCPJUMcpGN+88K8XxnnvwFzSabsA
qOw75/I94EaAPg7gvwH4MICPA7hxW/fBTp26AtCp01GlG7G2LgaA2zL4ngDuNXkH
/o4hc66vDNgKgEoYURgG4CW2T06u31hmxgkrvlYRmIS/J+0M2Znza1GfWDkfzIPS
lrwjsLcqEcWfvwaE/wGYK0H46CTwb+rivlOnrgB06iTRTQA+NL3A4NMA/haAH568
A/cg0F0B3J7BILtLHSGjEMTgfX0bdG6z2yyn35LRVs076eCLl1AExZIESWH3tyyX
FL/zBoA/BeATAH8cwB8C+F8AvoNu4nfq1BWATp0q6DsA/uf0etv0u+8B8DcB/BCA
vw3g7gB+AIw71QsaK/DOOWHaQCWgVMa/G9Qgzsr6nSg662sx5nRcBeCPAXwSwJ9g
BOXp1KlTVwA6ddqNbgbwsek10ykAd54Ug7sA+EGA7wLwuQDdcRZojsefESDtrb/w
q/BbdPgD1gbCKR9FiAzoluTLAMpxkV2tvlwH4BqAPg3wZwB8ehT09DmMnfU6derU
FYBOnc46nQHwv6fX5d4du9PoHaDvB/D9ZOhcIj7XEN+RgHPAuJXbStd109cLf6m7
H3slcIyBOSusbeFvkv8eH4NA38AI5nQdM18zCnv8n+l1LYivpdED06lTp64AdOp0
5Og7AD47vT7k/dsA4K9Nrztg7Hj4fdPPfwXAOQCdA+AvA7iNXhNINdot73xYYcsz
gFsAfHkS8NcD+CKALwD4/GTZfwHA/51eph+TTp26AtCp00kiMwnEzyfeQ5MCcLvp
T/vn206v22DMS7gNgL8I4NYA3wrArTDiHsyv0zyGKk4BPMxtcrDWBp6ZXt/BWC45
v74xvb4O4GuTcL95+vOm6fVljBUVX/Z+5r7NnTodTvr/Ssw9Og1vlToAAAAASUVO
RK5CYII=
EOI
	echo -n "$macupdatericon" | base64 -d - -o "$icon_loc" &>/dev/null
fi

# online searches
if [[ $1 == "musearch" ]] ; then
	if [[ $2 == "mucom" ]] ; then
		searchterm=$(osascript 2>/dev/null << EOR
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theAppName to text returned of (display dialog "Please enter the search keywords or the product name in the field below, separated by space." & return & return & "Example: text editor free" ¬
		default answer "" ¬
		buttons {"Cancel", "Search"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "Search on MacUpdate.com" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOR
		)
		if [[ $searchterm ]] ; then
			open "https://www.macupdate.com/find/mac/context=$searchterm" 2>/dev/null
		fi
	elif [[ $2 == "munet" ]] ; then
		searchterm=$(osascript 2>/dev/null << EOR
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc2"
	set theAppName to text returned of (display dialog "Please enter the search keywords or the product name in the field below, separated by space." & return & return & "Example: text editor free" ¬
		default answer "" ¬
		buttons {"Cancel", "Search"} ¬
		default button 2 ¬
		cancel button "Cancel" ¬
		with title "Search on MacUpdater.net" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOR
		)
		if [[ $searchterm ]] ; then
			open "https://macupdater.net/app_updates/search.html?q=$searchterm" 2>/dev/null
		fi
	fi
	exit
fi

### move About here after Help implementation

menuicon="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z2AAAAAJcEhZcwAAFiUAABYlAUlSJPAAAAPQaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA1LjQuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIgogICAgICAgICAgICB4bWxuczpleGlmPSJodHRwOi8vbnMuYWRvYmUuY29tL2V4aWYvMS4wLyIKICAgICAgICAgICAgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIj4KICAgICAgICAgPHRpZmY6UmVzb2x1dGlvblVuaXQ+MjwvdGlmZjpSZXNvbHV0aW9uVW5pdD4KICAgICAgICAgPHRpZmY6WVJlc29sdXRpb24+MTQ0PC90aWZmOllSZXNvbHV0aW9uPgogICAgICAgICA8dGlmZjpYUmVzb2x1dGlvbj4xNDQ8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOk9yaWVudGF0aW9uPjE8L3RpZmY6T3JpZW50YXRpb24+CiAgICAgICAgIDxleGlmOlBpeGVsWURpbWVuc2lvbj4xNDYzPC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6Q29sb3JTcGFjZT42NTUzNTwvZXhpZjpDb2xvclNwYWNlPgogICAgICAgICA8ZXhpZjpQaXhlbFhEaW1lbnNpb24+MTQ2MzwvZXhpZjpQaXhlbFhEaW1lbnNpb24+CiAgICAgICAgIDx4bXA6Q3JlYXRvclRvb2w+QWRvYmUgUGhvdG9zaG9wIDIxLjIgKE1hY2ludG9zaCk8L3htcDpDcmVhdG9yVG9vbD4KICAgICAgICAgPHhtcDpDcmVhdGVEYXRlPjIwMjAtMDktMDlUMDA6Mjc6MjI8L3htcDpDcmVhdGVEYXRlPgogICAgICAgICA8eG1wOk1vZGlmeURhdGU+MjAyMC0wOS0wOVQxOTowMzowOTwveG1wOk1vZGlmeURhdGU+CiAgICAgIDwvcmRmOkRlc2NyaXB0aW9uPgogICA8L3JkZjpSREY+CjwveDp4bXBtZXRhPgoIHCN2AAADjklEQVRIDa1VS2gUWRS9977qrv6kYyKRGPwlmoT4AfGHI4KzmhlGx41uFFeKG9GF4NqNoqggii78oKiogzMbxRFhmI0DI/hB/EE0McbEoERtoqQTk05/yltddd97FUd0YTV0nXvOue9VvXfvKwXf/8KqnbF4ofv7DxyMSOoIePgy1RCE6v/mmVhdmoWt1KRq04WxEeOonVBuYb5R1WTG8qOGt5BDR8tbOZ5QqvcuW7yBzi90EXswDx7/iviaLjrLWCW1iv7AlzBW4QvYR2djC01WiBx1oqL7uZ5a95nuzsQrxqDRKO3Gv3RUSfYjzNGWyBAunbZd2JecEtFji/GFbfgGXFJr9RCKzo3PoEtaBUg0Ye94w9dj7JxYHQyyKEZn8C6+j+ak9DsSXo1Iw5iNxLIwQ+N5tdp6SsDrJgv/pPOZjaGqVhoBPDrstqbr1XoYtFko0T63OT1ZbYKPhqe91gQuPhUFRxLTLQWvicDDnxSBjhuW+UOa/93w6qywvMzTUT8S9kyq8hXy/3iuFf7dv3Awti9AjO8JYpxN7peIHgrie2WEIC7O8jJa6X435OOKXFhiCbfyusk9R9sB/h3ul6iMggC8twaX5xiMTwJcmcCbbwl3DYZWg9HmpxkeOi08z8LtBjv4UK9pMbZAhKlJ7BIeR+NtwtenUfcLDpqtnFSFPdo/lGgUP6QacEALbzJ1InBnDGu+t06vrtuCI5pvB1f88bbwgPG7vBMSAc9LVJjh1YgJenMDgnnLUoKhO5sTXGz2wmRmnkNe+FKLFxcM3RAehjxBuQ30pmEHlMVUni2Ia+ipwV6jwag3nrdbLy77H4mHJ/DmSsD3xxa2agLCmqio9Zbng8bo/awx4E3B/gRfelKLJ6smICbJnNskWP3qLRWM/an/BAO4XLHhSYN5Uyt1GT79hR92Z5oE2iE83wedH33FWW4qiHv+iHFH29uqFZ4q+Oj4NfFsatKkOD9ZE/BXAf/BG6Drit3ZhH4vf+4Vxs5GfanfLP5vTTPgd9P9YTwGqc22m+gHE3IN6cveeruGALI52qNtnwHaUzoVIavvWHNbX1HnoMWviaRwFdIBoxqE72nbOCdAfA7exC7+PeGT3TQK8Af0doVvp1123cgAagPe554Jy4BX/hUdi9uFHRr9FsMG3sJ0qUv3ZKhRA3dsbbF9TAaN3pvdnkXl+TXbSwO5C9SRfJDLRvUg+gQ6b+9MU1m5xQAAAABJRU5ErkJggg=="

menuicon_grey="iVBORw0KGgoAAAANSUhEUgAAADAAAAAaCAYAAAGGMu9BAAAAAXNSR0IArs4c6QAAAPJlWElmTU0AKgAAAAgABwESAAMAAAABAAEAAAEaAAUAAAABAAAAYgEbAAUAAAABAAAAagEoAAMAAAABAAIAAAExAAIAAAAhAAAAcgEyAAIAAAAUAAAAlIdpAAQAAAABAAAAqAAAAAAAAACQAAAAAQAAAJAAAAABQWRvYmUgUGhvdG9zaG9wIDIxLjIgKE1hY2ludG9zaCkAADIwMjA6MDk6MjMgMTc6NTk6MzkAAASQBAACAAAAFAAAAN6gAQADAAAAAQABAACgAgAEAAAAAQAAADCgAwAEAAAAAQAAABoAAAAAMjAyMDowOTowOSAwMDoyNzoyMgCo8zSGAAAACXBIWXMAABYlAAAWJQFJUiTwAAARV2lUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPHg6eG1wbWV0YSB4bWxuczp4PSJhZG9iZTpuczptZXRhLyIgeDp4bXB0az0iWE1QIENvcmUgNS40LjAiPgogICA8cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkvMDIvMjItcmRmLXN5bnRheC1ucyMiPgogICAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0iIgogICAgICAgICAgICB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIKICAgICAgICAgICAgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiCiAgICAgICAgICAgIHhtbG5zOnN0RXZ0PSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvc1R5cGUvUmVzb3VyY2VFdmVudCMiCiAgICAgICAgICAgIHhtbG5zOnBob3Rvc2hvcD0iaHR0cDovL25zLmFkb2JlLmNvbS9waG90b3Nob3AvMS4wLyIKICAgICAgICAgICAgeG1sbnM6ZXhpZj0iaHR0cDovL25zLmFkb2JlLmNvbS9leGlmLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOnhtcD0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLyIKICAgICAgICAgICAgeG1sbnM6ZGM9Imh0dHA6Ly9wdXJsLm9yZy9kYy9lbGVtZW50cy8xLjEvIgogICAgICAgICAgICB4bWxuczp0aWZmPSJodHRwOi8vbnMuYWRvYmUuY29tL3RpZmYvMS4wLyI+CiAgICAgICAgIDx4bXBNTTpEZXJpdmVkRnJvbSByZGY6cGFyc2VUeXBlPSJSZXNvdXJjZSI+CiAgICAgICAgICAgIDxzdFJlZjpvcmlnaW5hbERvY3VtZW50SUQ+eG1wLmRpZDo0YjQ4Mzc0OC1kZWEwLTQ0YmMtOTE1Yy1kNTI3MzllMWFjY2Y8L3N0UmVmOm9yaWdpbmFsRG9jdW1lbnRJRD4KICAgICAgICAgICAgPHN0UmVmOmluc3RhbmNlSUQ+eG1wLmlpZDo5MjEwMmM2NC05NDgyLTRmMzktODIxOC00ZmE1MzQxNmYwNWM8L3N0UmVmOmluc3RhbmNlSUQ+CiAgICAgICAgICAgIDxzdFJlZjpkb2N1bWVudElEPmFkb2JlOmRvY2lkOnBob3Rvc2hvcDo4ZDY0ZDBkZi01MWEyLTFlNGItYmY1My05MjFkZWRkMGRhYzk8L3N0UmVmOmRvY3VtZW50SUQ+CiAgICAgICAgIDwveG1wTU06RGVyaXZlZEZyb20+CiAgICAgICAgIDx4bXBNTTpJbnN0YW5jZUlEPnhtcC5paWQ6ZmVmNjY4MTktNDVkMy00NGE2LWE0YmYtOWY2NGMwNzI5ODc2PC94bXBNTTpJbnN0YW5jZUlEPgogICAgICAgICA8eG1wTU06T3JpZ2luYWxEb2N1bWVudElEPnhtcC5kaWQ6NGI0ODM3NDgtZGVhMC00NGJjLTkxNWMtZDUyNzM5ZTFhY2NmPC94bXBNTTpPcmlnaW5hbERvY3VtZW50SUQ+CiAgICAgICAgIDx4bXBNTTpEb2N1bWVudElEPmFkb2JlOmRvY2lkOnBob3Rvc2hvcDplMTczYmQ4Mi0zNDk5LWNlNDUtOTVkNC04MTZjYjEyMGRkMjY8L3htcE1NOkRvY3VtZW50SUQ+CiAgICAgICAgIDx4bXBNTTpIaXN0b3J5PgogICAgICAgICAgICA8cmRmOlNlcT4KICAgICAgICAgICAgICAgPHJkZjpsaSByZGY6cGFyc2VUeXBlPSJSZXNvdXJjZSI+CiAgICAgICAgICAgICAgICAgIDxzdEV2dDpzb2Z0d2FyZUFnZW50PkFkb2JlIFBob3Rvc2hvcCAyMS4yIChNYWNpbnRvc2gpPC9zdEV2dDpzb2Z0d2FyZUFnZW50PgogICAgICAgICAgICAgICAgICA8c3RFdnQ6d2hlbj4yMDIwLTA5LTA5VDAwOjI3OjIyKzAyOjAwPC9zdEV2dDp3aGVuPgogICAgICAgICAgICAgICAgICA8c3RFdnQ6aW5zdGFuY2VJRD54bXAuaWlkOjRiNDgzNzQ4LWRlYTAtNDRiYy05MTVjLWQ1MjczOWUxYWNjZjwvc3RFdnQ6aW5zdGFuY2VJRD4KICAgICAgICAgICAgICAgICAgPHN0RXZ0OmFjdGlvbj5jcmVhdGVkPC9zdEV2dDphY3Rpb24+CiAgICAgICAgICAgICAgIDwvcmRmOmxpPgogICAgICAgICAgICAgICA8cmRmOmxpIHJkZjpwYXJzZVR5cGU9IlJlc291cmNlIj4KICAgICAgICAgICAgICAgICAgPHN0RXZ0OnNvZnR3YXJlQWdlbnQ+QWRvYmUgUGhvdG9zaG9wIDIxLjIgKE1hY2ludG9zaCk8L3N0RXZ0OnNvZnR3YXJlQWdlbnQ+CiAgICAgICAgICAgICAgICAgIDxzdEV2dDpjaGFuZ2VkPi88L3N0RXZ0OmNoYW5nZWQ+CiAgICAgICAgICAgICAgICAgIDxzdEV2dDp3aGVuPjIwMjAtMDktMDlUMTk6MDE6NTMrMDI6MDA8L3N0RXZ0OndoZW4+CiAgICAgICAgICAgICAgICAgIDxzdEV2dDppbnN0YW5jZUlEPnhtcC5paWQ6NjY1YTQzNjMtY2Y0Yi00NGQxLWJjNDQtYmUyMmY4MmJlZjA3PC9zdEV2dDppbnN0YW5jZUlEPgogICAgICAgICAgICAgICAgICA8c3RFdnQ6YWN0aW9uPnNhdmVkPC9zdEV2dDphY3Rpb24+CiAgICAgICAgICAgICAgIDwvcmRmOmxpPgogICAgICAgICAgICAgICA8cmRmOmxpIHJkZjpwYXJzZVR5cGU9IlJlc291cmNlIj4KICAgICAgICAgICAgICAgICAgPHN0RXZ0OnNvZnR3YXJlQWdlbnQ+QWRvYmUgUGhvdG9zaG9wIDIxLjIgKE1hY2ludG9zaCk8L3N0RXZ0OnNvZnR3YXJlQWdlbnQ+CiAgICAgICAgICAgICAgICAgIDxzdEV2dDpjaGFuZ2VkPi88L3N0RXZ0OmNoYW5nZWQ+CiAgICAgICAgICAgICAgICAgIDxzdEV2dDp3aGVuPjIwMjAtMDktMjNUMTc6NTk6MzkrMDI6MDA8L3N0RXZ0OndoZW4+CiAgICAgICAgICAgICAgICAgIDxzdEV2dDppbnN0YW5jZUlEPnhtcC5paWQ6OTIxMDJjNjQtOTQ4Mi00ZjM5LTgyMTgtNGZhNTM0MTZmMDVjPC9zdEV2dDppbnN0YW5jZUlEPgogICAgICAgICAgICAgICAgICA8c3RFdnQ6YWN0aW9uPnNhdmVkPC9zdEV2dDphY3Rpb24+CiAgICAgICAgICAgICAgIDwvcmRmOmxpPgogICAgICAgICAgICAgICA8cmRmOmxpIHJkZjpwYXJzZVR5cGU9IlJlc291cmNlIj4KICAgICAgICAgICAgICAgICAgPHN0RXZ0OmFjdGlvbj5jb252ZXJ0ZWQ8L3N0RXZ0OmFjdGlvbj4KICAgICAgICAgICAgICAgICAgPHN0RXZ0OnBhcmFtZXRlcnM+ZnJvbSBhcHBsaWNhdGlvbi92bmQuYWRvYmUucGhvdG9zaG9wIHRvIGltYWdlL3BuZzwvc3RFdnQ6cGFyYW1ldGVycz4KICAgICAgICAgICAgICAgPC9yZGY6bGk+CiAgICAgICAgICAgICAgIDxyZGY6bGkgcmRmOnBhcnNlVHlwZT0iUmVzb3VyY2UiPgogICAgICAgICAgICAgICAgICA8c3RFdnQ6YWN0aW9uPmRlcml2ZWQ8L3N0RXZ0OmFjdGlvbj4KICAgICAgICAgICAgICAgICAgPHN0RXZ0OnBhcmFtZXRlcnM+Y29udmVydGVkIGZyb20gYXBwbGljYXRpb24vdm5kLmFkb2JlLnBob3Rvc2hvcCB0byBpbWFnZS9wbmc8L3N0RXZ0OnBhcmFtZXRlcnM+CiAgICAgICAgICAgICAgIDwvcmRmOmxpPgogICAgICAgICAgICAgICA8cmRmOmxpIHJkZjpwYXJzZVR5cGU9IlJlc291cmNlIj4KICAgICAgICAgICAgICAgICAgPHN0RXZ0OnNvZnR3YXJlQWdlbnQ+QWRvYmUgUGhvdG9zaG9wIDIxLjIgKE1hY2ludG9zaCk8L3N0RXZ0OnNvZnR3YXJlQWdlbnQ+CiAgICAgICAgICAgICAgICAgIDxzdEV2dDpjaGFuZ2VkPi88L3N0RXZ0OmNoYW5nZWQ+CiAgICAgICAgICAgICAgICAgIDxzdEV2dDp3aGVuPjIwMjAtMDktMjNUMTc6NTk6MzkrMDI6MDA8L3N0RXZ0OndoZW4+CiAgICAgICAgICAgICAgICAgIDxzdEV2dDppbnN0YW5jZUlEPnhtcC5paWQ6ZmVmNjY4MTktNDVkMy00NGE2LWE0YmYtOWY2NGMwNzI5ODc2PC9zdEV2dDppbnN0YW5jZUlEPgogICAgICAgICAgICAgICAgICA8c3RFdnQ6YWN0aW9uPnNhdmVkPC9zdEV2dDphY3Rpb24+CiAgICAgICAgICAgICAgIDwvcmRmOmxpPgogICAgICAgICAgICA8L3JkZjpTZXE+CiAgICAgICAgIDwveG1wTU06SGlzdG9yeT4KICAgICAgICAgPHBob3Rvc2hvcDpDb2xvck1vZGU+MTwvcGhvdG9zaG9wOkNvbG9yTW9kZT4KICAgICAgICAgPHBob3Rvc2hvcDpJQ0NQcm9maWxlPkRvdCBHYWluIDIwJTwvcGhvdG9zaG9wOklDQ1Byb2ZpbGU+CiAgICAgICAgIDxleGlmOlBpeGVsWERpbWVuc2lvbj4xMDk4PC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjYwMjwvZXhpZjpQaXhlbFlEaW1lbnNpb24+CiAgICAgICAgIDxleGlmOkNvbG9yU3BhY2U+NjU1MzU8L2V4aWY6Q29sb3JTcGFjZT4KICAgICAgICAgPHhtcDpDcmVhdG9yVG9vbD5BZG9iZSBQaG90b3Nob3AgMjEuMiAoTWFjaW50b3NoKTwveG1wOkNyZWF0b3JUb29sPgogICAgICAgICA8eG1wOk1ldGFkYXRhRGF0ZT4yMDIwLTA5LTIzVDE3OjU5OjM5KzAyOjAwPC94bXA6TWV0YWRhdGFEYXRlPgogICAgICAgICA8eG1wOk1vZGlmeURhdGU+MjAyMC0wOS0yM1QxNzo1OTozOSswMjowMDwveG1wOk1vZGlmeURh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"

genericappicon="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"

blankicon="aWNucwAAA9RUT0MgAAAAEGljMTEAAAO8aWMxMQAAA7yJUE5HDQoaCgAAAA1JSERSAAAAIAAAACAIBgAAAHN6evQAAAAEZ0FNQQAAsY8L/GEFAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAACEZVhJZk1NACoAAAAIAAUBEgADAAAAAQABAAABGgAFAAAAAQAAAEoBGwAFAAAAAQAAAFIBKAADAAAAAQACAACHaQAEAAAAAQAAAFoAAAAAAAAAkAAAAAEAAACQAAAAAQADoAEAAwAAAAEAAQAAoAIABAAAAAEAAAAgoAMABAAAAAEAAAAgAAAAAL6+g2YAAAAJcEhZcwAAFiUAABYlAUlSJPAAAAJmaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA1LjQuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIgogICAgICAgICAgICB4bWxuczpleGlmPSJodHRwOi8vbnMuYWRvYmUuY29tL2V4aWYvMS4wLyI+CiAgICAgICAgIDx0aWZmOk9yaWVudGF0aW9uPjE8L3RpZmY6T3JpZW50YXRpb24+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgICAgIDxleGlmOkNvbG9yU3BhY2U+MTwvZXhpZjpDb2xvclNwYWNlPgogICAgICAgICA8ZXhpZjpQaXhlbFhEaW1lbnNpb24+MzI8L2V4aWY6UGl4ZWxYRGltZW5zaW9uPgogICAgICAgICA8ZXhpZjpQaXhlbFlEaW1lbnNpb24+MzI8L2V4aWY6UGl4ZWxZRGltZW5zaW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4K+qzMvQAAAChJREFUWAnt0IEAAAAAw6D5Ux/khVBhwIABAwYMGDBgwIABAwYMvA8MECAAAc4qtccAAAAASUVORK5CYII="

blankslimicon="iVBORw0KGgoAAAANSUhEUgAAACAAAAAQCAYAAAB3AH1ZAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAApGVYSWZNTQAqAAAACAAGARIAAwAAAAEAAQAAARoABQAAAAEAAABWARsABQAAAAEAAABeASgAAwAAAAEAAgAAATEAAgAAAB8AAABmh2kABAAAAAEAAACGAAAAAAAAAJAAAAABAAAAkAAAAAFBZG9iZSBQaG90b3Nob3AgQ0MgKE1hY2ludG9zaCkAAAACoAIABAAAAAEAAAAgoAMABAAAAAEAAAAQAAAAAIRInlQAAAAJcEhZcwAAFiUAABYlAUlSJPAAAALmaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA1LjQuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjE2PC9leGlmOlBpeGVsWURpbWVuc2lvbj4KICAgICAgICAgPGV4aWY6Q29sb3JTcGFjZT4xPC9leGlmOkNvbG9yU3BhY2U+CiAgICAgICAgIDxleGlmOlBpeGVsWERpbWVuc2lvbj4zMjwvZXhpZjpQaXhlbFhEaW1lbnNpb24+CiAgICAgICAgIDx4bXA6Q3JlYXRvclRvb2w+QWRvYmUgUGhvdG9zaG9wIENDIChNYWNpbnRvc2gpPC94bXA6Q3JlYXRvclRvb2w+CiAgICAgICAgIDx0aWZmOk9yaWVudGF0aW9uPjE8L3RpZmY6T3JpZW50YXRpb24+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgIDwvcmRmOkRlc2NyaXB0aW9uPgogICA8L3JkZjpSREY+CjwveDp4bXBtZXRhPgqzYcEqAAAAHUlEQVRIDWNgGAWjITAaAqMhMBoCoyEwGgIjPQQACBAAASmbIf0AAAAASUVORK5CYII="

searchicon="aWNucwAACzZUT0MgAAAAEGljMTEAAAseaWMxMQAACx6JUE5HDQoaCgAAAA1JSERSAAAAIAAAACAIBgAAAHN6evQAAAAEZ0FNQQAAsY8L/GEFAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAACiZVhJZk1NACoAAAAIAAYBEgADAAAAAQABAAABGgAFAAAAAQAAAFYBGwAFAAAAAQAAAF4BKAADAAAAAQABAAABMQACAAAAEgAAAGaHaQAEAAAAAQAAAHgAAAAAAAAAkAAAAAEAAACQAAAAAVBpeGVsbWF0b3IgIDEuNi43AAADoAEAAwAAAAEAAQAAoAIABAAAAAEAAAAgoAMABAAAAAEAAAAgAAAAAF2lYLQAAAAJcEhZcwAAFiUAABYlAUlSJPAAAANvaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJYTVAgQ29yZSA1LjQuMCI+CiAgIDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+CiAgICAgIDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiCiAgICAgICAgICAgIHhtbG5zOnRpZmY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvIgogICAgICAgICAgICB4bWxuczpleGlmPSJodHRwOi8vbnMuYWRvYmUuY29tL2V4aWYvMS4wLyIKICAgICAgICAgICAgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIj4KICAgICAgICAgPHRpZmY6WVJlc29sdXRpb24+MTQ0PC90aWZmOllSZXNvbHV0aW9uPgogICAgICAgICA8dGlmZjpYUmVzb2x1dGlvbj4xNDQ8L3RpZmY6WFJlc29sdXRpb24+CiAgICAgICAgIDx0aWZmOk9yaWVudGF0aW9uPjE8L3RpZmY6T3JpZW50YXRpb24+CiAgICAgICAgIDx0aWZmOkNvbXByZXNzaW9uPjU8L3RpZmY6Q29tcHJlc3Npb24+CiAgICAgICAgIDx0aWZmOlJlc29sdXRpb25Vbml0PjE8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgICAgICAgIDxleGlmOlBpeGVsWURpbWVuc2lvbj4yNTY8L2V4aWY6UGl4ZWxZRGltZW5zaW9uPgogICAgICAgICA8ZXhpZjpDb2xvclNwYWNlPjE8L2V4aWY6Q29sb3JTcGFjZT4KICAgICAgICAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjI1NjwvZXhpZjpQaXhlbFhEaW1lbnNpb24+CiAgICAgICAgIDx4bXA6Q3JlYXRvclRvb2w+UGl4ZWxtYXRvciAgMS42Ljc8L3htcDpDcmVhdG9yVG9vbD4KICAgICAgPC9yZGY6RGVzY3JpcHRpb24+CiAgIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+CjnTR68AAAZjSURBVFgJxZZNTJVHFIYHvMi/ICqKJdqACFIEQ1CsUVmx6bKycdXEbsFEI2pM2pp2h11pRWNE0lXTpmncEmJCDEnTilUaq2gEEotXvQJei4ggat9n5Hz9/ERrVz3J3Pn5Zs77np85c537nyXlv+C3tLSk19TUVGZlZVUvWLCgVGfzOf/8+fPks2fPBp88efJ7f3//1WPHjk2/q953ItDe3l6ydOnSTzIzMz9euHBhhfqYCLiUlJfHX7x44WZnZ93k5OTs9PT0gPqf7t+//+2ePXuG/o3IWwns378/t7a2dl9eXl6zWoEByeJX9LJuZCCGJJPJcbVvrly58nVbW9vEKwdCkzcSOHXq1AfLly/vkOX1AMrFDqCwhOc2pqdBhF6e+CUeH/10797mP8JnbTwvgY6Ojg+Liop+XLx48Uq59K3AKIqCGwn6tLQ0Nzo6GheRpubm5p8N2PrXCJw8eaayuLiwu6CgYOXMzEyg3IBMuc3N9Ta373iNMX0sFiMk8ZFEonHf7t1XDZz+ZcDmVo4fP55TVFR4trCwsBzLw2JxVwI65YNbtGiRYwwIRAkRYgQMnHNPnz5lb6421W/YsOG7np6eGdMdswG9XN4q8LooOMqzs7Pd6tWrnTzj0tPTg2OAy8VueHjYPXz40KWmpnqrwwQgoSvq8vPz61asWNGqw1+YgsADJ06ceF/gnbpmGWatKQG0qqoKgt6dU1NT7vHjxx4oIyPD5ebmOp11jx49chMTE4EX0BNt0llTX1///blz55KQCDwgdrsEkI9FCOA0LK+oqPDuBmBwcNA9ePDA33ushdSaNWs8ifXr13tiirfXEQVnriKWr/Dt0obP2ZTKz+HDhzMUox0GSo/Q43ZiDfjly5fd3bt3fUxRRmzj8bi7cOGCtxxvQIZvhC1MgDmNM0rKHWCC4Qnovq9TXNdSzUwAB3jJkiWeCJarwvkYh4niBdw+MDDg9xGKnJwcD2agRoYeD+vMWoVtXUBAbq6Ra2IwNmGsNaec8AmE27lyBh62jnXdc+9+7j0EMCZMIExCHoiJRE1AQIdKrIQaAD33F4E1ClkzYNtnc/ZY/qCLMe7mXJgM+xERKKH3CLLAv2ooRaznIIJVuBqFiBExC9kHWbyFcI35xhnbC7CNWZd4TD9iZmLgzIktlpALZLtZAhFAzErGyiMfMr6NjY15dYCa66PjwBPs1KakMWRuJEg6igwxJrshwhqAkKExpjJSJ9h3+/ZtNz4+jpogXGES4Mw1f1e9B2TJEMoQc5MRunnzpk9Cis2mTZv8tcTVgNGXlpa6hoYGT4LzrCN4Yj5g1miSIX58DqhM9quyzeoe+5sACRobE4mE6+vrc3V1db7+b9682XsB90OAQhUW6sa2bdtcT09PkJRmlOnV2Vm1fs55D9y7d++aCNwIJw0ANGRkZMQrvHXrlrcMUHKCHkt5ByhSc5a5srIy7xX0sRZyu/eQ5jcUumvoDp7jzs7OL1etWvUZjwbAHDTGKCBEzHkFiTk3g/gTbxpEqqur3ZYtW3z2o/z69etONd/vMy/wkOncV62trb4UB2+B6vcZWdSiDfkGZocggDAHjKLDGnMTrL106ZJf37p1qydRXl7O/wB3/vx5bzn5IaJJ6T9j54LXsKurK9nY2JilKtYAAQAMJEoERQZOb99RSrjwILkA0d7eXl8h+UbOiEDbwYMHzzJHAg8w0ccjusMf8W7z5IaVG4j1Ri5MlDHkLl686EHv3LnjSeAdCpVc36dcOwKWSZADtnD06NFKxblbd97/HzSgMLCthXsb2z68iEBorszH5ZnGQ4cOvfKX7LVKuFv/2fTwNKngxGFtCknKaEYDamu2z4hgNTL3nsT1vSkKzvcgB5iYKB9GVFy6NK9TUr4XBQcsCmhz+4YuMl6EfpU3mg4cOPCb6Q/3UQKEBOoxkUjo4Nlly5ZhRaUSKBPrwi0KyhyXc0W1L6m3pL27u7vl9OnTf6IzDGzjaA4wZ2OaGv88abHt27fXbty4cafINCg3igAwSyGE0FMXlGQqnoleVc8f9E8Jq6lmU3ONv9okx8tDGkQJaMmv4QVI8L5mqlFv83RFS/ToVBUXF5fpphSKSLaIpAh4Snkzpko5rOJzVfkzpP08iX+pTaoBzFsO+D/FQ5P5CGh5XoGUNUJHY44OLKLxylgLrNTaG+VvRufJ6BegZcwAAAAASUVORK5CYII="

updateicon="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"

ccmu_icon="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"

infoicon="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"

ccicon="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"

findericon="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"

dlficon="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"

alerticon="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"

offlineicon="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"

offlinemenuicon="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OmNvbS5hZG9iZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IlhNUCBDb3JlIDUuNC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFkb2JlLmNvbS90aWZmLzEuMC8iCiAgICAgICAgICAgIHhtbG5zOmV4aWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20vZXhpZi8xLjAvIgogICAgICAgICAgICB4bWxuczp4bXA9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogICAgICAgICA8dGlmZjpQaG90b21ldHJpY0ludGVycHJldGF0aW9uPjI8L3RpZmY6UGhvdG9tZXRyaWNJbnRlcnByZXRhdGlvbj4KICAgICAgICAgPHRpZmY6UmVzb2x1dGlvblVuaXQ+MjwvdGlmZjpSZXNvbHV0aW9uVW5pdD4KICAgICAgICAgPHRpZmY6Q29tcHJlc3Npb24+MTwvdGlmZjpDb21wcmVzc2lvbj4KICAgICAgICAgPGV4aWY6UGl4ZWxZRGltZW5zaW9uPjg4NzwvZXhpZjpQaXhlbFlEaW1lbnNpb24+CiAgICAgICAgIDxleGlmOkNvbG9yU3BhY2U+MTwvZXhpZjpDb2xvclNwYWNlPgogICAgICAgICA8ZXhpZjpQaXhlbFhEaW1lbnNpb24+ODg1PC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICAgICAgICAgPHhtcDpDcmVhdGVEYXRlPjIwMjAtMDktMTBUMDA6MzU6NTQ8L3htcDpDcmVhdGVEYXRlPgogICAgICAgICA8eG1wOk1vZGlmeURhdGU+MjAyMC0wOS0xMFQwMDo0Njo0NzwveG1wOk1vZGlmeURhdGU+CiAgICAgIDwvcmRmOkRlc2NyaXB0aW9uPgogICA8L3JkZjpSREY+CjwveDp4bXBtZXRhPgpOUPcoAAACRElEQVRIDX1Vy2oUQRQ93XYm+QhBDWaTTAJqzATUINlkkU0g6EIQxG8RVyp5QBYJYiKKOyF+gEQSFxqML4T4ymMGfO0kBkPIOLl1+5Y9datq7sBU3XPPOVXd1X07gR9H0emDjGyhGqk0wWV8QiPy28CpJmZwWsaXiDg33dYWiWNTxiJvfwFLSMgoQRvV93EE/5BhENcpq2IMrx3V/6QXX3n1GRKGY4Lr2zgdKlv5NK0XiwS3YxaFPHXUJb6IAkpwiy2q7i76sMHwFFz5NbzHO1wt9DQrLM5Y3MrvKHkndtl2B8ctVcabsgu2OCarT3q3bphp5vguKgPghlicBEZ4OqdWN4oKHZ6R19HvGQBTXBtLaTCxRGQd3/GHod/4pkuUP2OsYW+aeWB0/ECNoS380iXKRWENAgx6At8y/AoHoXKOWYP8QjTvOQP5v65JnkXwHH5Jd6aO1Vac1gbr+Im/9Ia0CGsQvoQdfKCT2AvqRdHaAHghR+l7yLFbg7rPYORB9AREYQ32IwbrEdy0GY5U3v5LKAWoZ/EEj9EbqGS4zCj1ji5s8lM971m04w1Xlr0Wk2GWKzX0GJtBsVhQFh3Sn9eoHzZHhjmRX7BwzGKU2ucqhi2Nx4Dc4BXZxX20K7rbIUu4q1e3fLFIH6LDQt5YSu+J/LxXI6CS9yaycHdhuW3pPMuraJK7X4AKHuEE9c3FxlOrKsZkqDFOWQ1XsFKgejYgHdK0stDPWV2L83wAn4NSY7eJc1rkXkJe7UO3pkn+0f8qHgKZdfGeiyI7kgAAAABJRU5ErkJggg=="

commentsicon="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"

mucomiconsmall="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"

bitbaricon="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"

githubicon="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"

mumenuicon="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"

helpicon="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"

terminalicon="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"

appleicon="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"

mumred="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"

urlicon="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"

mudicon="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"

# has not agreed to license
if ! $agreed ; then
	_sysbeep &
	echo "| templateImage=$offlinemenuicon dropdown=false"
	echo "---"
	echo "Please agree to the license! | image=\"$offlineicon\" color=red"
	echo "---"
	echo "Disable MacUpdate Menu | refresh=true terminal=false bash=\"${0}\" param1=disable"
	echo "Uninstall MacUpdate Menu | refresh=true terminal=false bash=\"${0}\" param1=disable param2=uninstall"
	echo "---"
	echo "Refresh… | refresh=true"
	exit
fi

# wrong BitBar version
if ! $correctbb ; then
	_sysbeep &
	echo "| templateImage=$offlinemenuicon dropdown=false"
	echo "---"
	echo "Update to BitBar v2.0.0 beta 10… | image=\"$offlineicon\" color=red href=\"$bbdlurl\""
	echo "---"
	echo "Disable MacUpdate Menu | refresh=true terminal=false bash=\"${0}\" param1=disable"
	echo "Uninstall MacUpdate Menu | refresh=true terminal=false bash=\"${0}\" param1=disable param2=uninstall"
	echo "---"
	echo "Refresh… | refresh=true"
	exit
fi

# wrong macOS version
if $incompat ; then
	_sysbeep &
	echo "| templateImage=$offlinemenuicon dropdown=false"
	echo "---"
	echo "You need at least OS X Mavericks 10.9.5 | image=\"$offlineicon\" color=red"
	echo "---"
	echo "Disable MacUpdate Menu | refresh=true terminal=false bash=\"${0}\" param1=disable"
	echo "Uninstall MacUpdate Menu | refresh=true terminal=false bash=\"${0}\" param1=disable param2=uninstall"
	echo "---"
	echo "Refresh… | refresh=true"
	exit
fi

# offline checks
offline=false
if $mucheck ; then
	if [[ $(route get 0.0.0.0 2>&1) == "route: writing to routing socket: not in table" ]] ; then
		offline=true
		olstring="MacUpdate Menu is offline!"
	else
		((pingcount = 8))
		while [[ $pingcount -ne 0 ]] ; do
			ping -q -c 1 macupdate.com &>/dev/null
			rc=$?
			if [[ $rc -eq 0 ]] ; then
				((pingcount = 1))
			fi
			((pingcount = pingcount - 1))
		done
		if ! [[ $rc -eq 0 ]] ; then
			offline=true
			olstring="MacUpdate can't be reached!'"
		fi
	fi
fi
if $offline ; then
	echo "| templateImage=$menuicon_grey dropdown=false"
	echo "---"
	echo "$olstring | image=\"$offlineicon\" color=red"
	echo "---"
	echo "Last updated at $fetchdate | size=11"
	echo "Refresh | image=\"$updateicon\" refresh=true"
	exit
fi

# round function
_round () {
	echo $(printf %.$2f $(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc))
}

# notify function
_notify () {
	if [[ $tn_status == osa ]] ; then
		osascript &>/dev/null << EOT
tell application "System Events"
	display notification "$2" with title "$uiprocess [" & "$account" & "]" subtitle "$1"
end tell
EOT
	elif [[ $tn_status == tn-app-new ]] || [[ $tn_status == tn-app-old ]] ; then
		"$tn_loc/Contents/MacOS/terminal-notifier" \
			-title "$uiprocess [$account]" \
			-subtitle "$1" \
			-message "$2" \
			-appIcon "$icon_loc" \
			>/dev/null
	elif [[ $tn_status == tn-cli ]] ; then
		"$tn" \
			-title "$uiprocess [$account]" \
			-subtitle "$1" \
			-message "$2" \
			-appIcon "$icon_loc" \
			>/dev/null
	fi
}

# look for terminal-notifier
tn=$(command -v terminal-notifier 2>/dev/null)
if ! [[ $tn ]] ; then
	tn_loc=$(mdfind \
		-onlyin /Applications/ \
		-onlyin "$HOMEDIR"/Applications/ \
		-onlyin /Developer/Applications/ \
		-onlyin "$HOMEDIR"/Developer/Applications/ \
		-onlyin /Network/Applications/ \
		-onlyin /Network/Developer/Applications/ \
		-onlyin /usr/local/Cellar/terminal-notifier/ \
		-onlyin /opt/local/ \
		-onlyin /sw/ \
		-onlyin "$HOMEDIR"/.local/bin \
		-onlyin "$HOMEDIR"/bin \
		-onlyin "$HOMEDIR"/local/bin \
		"kMDItemCFBundleIdentifier == 'fr.julienxx.oss.terminal-notifier'" 2>/dev/null | LC_COLLATE=C sort | awk 'NR==1')
	if ! [[ $tn_loc ]] ; then
		tn_loc=$(mdfind \
			-onlyin /Applications/ \
			-onlyin "$HOMEDIR"/Applications/ \
			-onlyin /Developer/Applications/ \
			-onlyin "$HOMEDIR"/Developer/Applications/ \
			-onlyin /Network/Applications/ \
			-onlyin /Network/Developer/Applicationsv \
			-onlyin /usr/local/Cellar/terminal-notifier/ \
			-onlyin /opt/local/ \
			-onlyin /sw/ \
			-onlyin "$HOMEDIR"/.local/bin \
			-onlyin "$HOMEDIR"/bin \
			-onlyin "$HOMEDIR"/local/bin \
			"kMDItemCFBundleIdentifier == 'nl.superalloy.oss.terminal-notifier'" 2>/dev/null | LC_COLLATE=C sort | awk 'NR==1')
		if ! [[ $tn_loc ]] ; then
			tn_status="osa"
		else
			tn_status="tn-app-old"
		fi
	else
		tn_status="tn-app-new"
	fi
else
	tn_vers=$("$tn" -help | head -1 | awk -F'[()]' '{print $2}' | awk -F. '{print $1"."$2}')
	if (( $(echo "$tn_vers >= 1.8" | bc -l) )) && (( $(echo "$tn_vers < 2.0" | bc -l) )) ; then
		tn_status="tn-cli"
	else
		tn_loc=$(mdfind \
			-onlyin /Applications/ \
			-onlyin "$HOMEDIR"/Applications/ \
			-onlyin /Developer/Applications/ \
			-onlyin "$HOMEDIR"/Developer/Applications/ \
			-onlyin /Network/Applications/ \
			-onlyin /Network/Developer/Applications/ \
			-onlyin /usr/local/Cellar/terminal-notifier/ \
			-onlyin /opt/local/ \
			-onlyin /opt/sw/ \
			-onlyin "$HOMEDIR"/.local/bin \
			-onlyin "$HOMEDIR"/bin \
			-onlyin "$HOMEDIR"/local/bin \
			"kMDItemCFBundleIdentifier == 'fr.julienxx.oss.terminal-notifier'" 2>/dev/null | LC_COLLATE=C sort | awk 'NR==1')
		if ! [[ $tn_loc ]] ; then
			tn_loc=$(mdfind \
				-onlyin /Applications/ \
				-onlyin "$HOMEDIR"/Applications/ \
				-onlyin /Developer/Applications/ \
				-onlyin "$HOMEDIR"/Developer/Applications/ \
				-onlyin /Network/Applications/ \
				-onlyin /Network/Developer/Applications/ \
				-onlyin /usr/local/Cellar/terminal-notifier/ \
				-onlyin /opt/local/ \
				-onlyin /opt/sw/ \
				-onlyin "$HOMEDIR"/.local/bin \
				-onlyin "$HOMEDIR"/bin \
				-onlyin "$HOMEDIR"/local/bin \
				"kMDItemCFBundleIdentifier == 'nl.superalloy.oss.terminal-notifier'" 2>/dev/null | LC_COLLATE=C sort | awk 'NR==1')
			if ! [[ $tn_loc ]] ; then
				tn_status="osa"
			else
				tn_status="tn-app-old"
			fi
		else
			tn_status="tn-app-new"
		fi
	fi
fi

if [[ $1 == "about" ]] ; then
	read -d '' abouttext <<EOA
$uiprocess ($process)
$myname
$version$vmisc ($build)

BitBar Plug-in (zsh script)

Copyright © 2020 Joss Brown (pseud.)
All rights reserved
German laws apply
Place of Jurisdiction: Berlin, Germany

Some icons included under § 57 UrhG exceptions
Other icons created in temporary cache only

License: MIT
Limited Liability

———————————————————————

Functionality based on MUMenu
Abandonware
Last version: 2.1.4 (209)
Copyright © 2002–20 Clario Tech Ltd.

Code & Interface:
• Unsanity LLC (1.x)
• Peter Maurer (2.0.x)
• Chad Harrison (2.1.x)

Icons:
• Dan Sandler (MUMenu)
• Lisa Kirsch (additional)
• Slava Karpenko (additional)
• et al. (additional)
• Clario Tech Ltd. (online)
• Apple Inc. (system)
EOA
	aboutchoice=$(osascript 2>/dev/null << EOI
tell application "System Events"
	activate
	set theLogoPath to POSIX file "$icon_loc"
	set theUserChoice to button returned of (display dialog "$abouttext" ¬
		buttons {"Repository", "Help", "Close"} ¬
		default button 3 ¬
		cancel button "Close" ¬
		with title "About MacUpdate Menu" ¬
		with icon file theLogoPath ¬
		giving up after 180)
end tell
EOI
	)
	if [[ $aboutchoice == "Repository" ]] ; then
		open "$mucomurl" 2>/dev/null
	elif [[ $aboutchoice == "Help" ]] ; then
		_notify "⚠️ Attention" "Help is not yet implemented" ###
		# open -a HelpViewer "$helploc" 2>/dev/null & ###
	fi
	exit
fi

_mucom_download () {
	mucomddlpath=$(curl -k -L -s --connect-timeout 30 --max-time 60 "$mucomdlmurl" 2>/dev/null | awk -F\" '/\/releases\/download\//{print $2}')
	if ! [[ $mucomddlpath ]] ; then
		_sysbeep &
		_notify "⚠️ Error: no releases found!" "Opening browser instead…" &
		open "$mucomdlmurl" 2>/dev/null
	else
		mucomddlurl="https://github.com$mucomddlpath"
		filename=$(basename "$mucomddlpath")
		localdlpath="$defaultdldir/$filename"
		if [[ -f "$localdlpath" ]] ; then
			rm -f "$localdlpath" 2>/dev/null
		fi
		dlparent=$(dirname "$localdlpath")
		if curl -k -L -s -o --connect-timeout 30 -o "$localdlpath" "$mucomddlurl" &>/dev/null ; then
			if [[ -f "$localdlpath" ]] ; then
				xattr -cr "$localdlpath" 2>/dev/null
				echo "OK"
			fi
		fi
	fi
}

# update plugin
if [[ $1 == "install" ]] ; then
	if [[ $3 == "symlink" ]] ; then
		if [[ $4 == "linkgit" ]] ; then
			defaultgithubclient=""
			if [[ -f "$newlsplist" ]] ; then
				defaultgithubclient=$(/usr/libexec/PlistBuddy -c "Print" "$newlsplist" 2>/dev/null | grep -i -A1 "x-github-client" | grep "LSHandlerRoleAll = " | grep -v "\"-\";" | awk -F" = " '{print $2}')
			else
				if [[ -f "$oldlsplist" ]] ; then
					defaultgithubclient=$(/usr/libexec/PlistBuddy -c "Print" "$oldlsplist" 2>/dev/null | grep -i -A1 "x-github-client" | grep "LSHandlerRoleViewer = " | grep -v "\"-\";" | awk -F" = " '{print $2}')
				fi
			fi
			if [[ $defaultgithubclient ]] ; then
				if ! open "x-github-client://openRepo/$mucomurl" &>/dev/null ; then
					_sysbeep &
					_notify "⚠️ Error: GitHub client!" "Downloading release version instead…" &
				else
					_sysbeep &
					_notify "ℹ️ Update manually in GitHub client" "Please fetch origin from remote repository…" &
					exit
				fi
			else
				_sysbeep &
				_notify "⚠️ Error: no GitHub client!" "Downloading release version instead…" &
			fi
		else
			_sysbeep &
			_notify "⚠️ Error: plug-in is symlink!" "Downloading release version instead…" &
		fi
		if [[ $(_mucom_download 2>/dev/null) == "OK" ]] ; then
			_appbeep &
			_notify "✅ Download finished!" "$defaultdldir_short/$filename"
			if [[ $2 == "finder" ]] ; then
				osascript -e "tell application \"Finder\"" -e "activate" -e "reveal POSIX file \"$localdlpath\"" -e "end tell" &>/dev/null
			else
				open -b "$2" "$dlparent" &>/dev/null
			fi
		else
			_sysbeep &
			_notify "⚠️ Error: download!" "Opening browser instead" &
			open "$mucomdlmurl" 2>/dev/null
		fi
		exit
	fi
	localdlpath="/tmp/$myname"
	if curl -k -L -s --connect-timeout 30 --max-time 60 -o "$localdlpath" "$mucomdlurl" &>/dev/null ; then
		if [[ $("$localdlpath" -t 2>/dev/null) != "$teststring" ]] ; then
			rm -f "$localdlpath" 2>/dev/null
			_sysbeep &
			_notify "⚠️ Error: download!" "Downloading release version instead…" &
			if [[ $(_mucom_download 2>/dev/null) == "OK" ]] ; then
				_appbeep &
				_notify "✅ Download finished!" "$defaultdldir_short/$filename"
				if [[ $2 == "finder" ]] ; then
					osascript -e "tell application \"Finder\"" -e "activate" -e "reveal POSIX file \"$localdlpath\"" -e "end tell" &>/dev/null
				else
					open -b "$2" "$dlparent" &>/dev/null
				fi
			else
				_sysbeep &
				_notify "⚠️ Error: download!" "Opening browser instead" &
				open "$mucomdlmurl" 2>/dev/null
			fi
		else
			mv -f "$mypath" "$HOMEDIR/.Trash/$myname" 2>/dev/null
			mv -f "$localdlpath" "$bbdir/$myname" 2>/dev/null
			xattr -c "$bbdir/$myname" 2>/dev/null
			chmod +x "$bbdir/$myname" 2>/dev/null
			defaults write "$procid" lastRefreshAction -int 1 2>/dev/null
			if ! osascript -e 'tell application "BitBar" to quit' &>/dev/null ; then
				killall BitBar 2>/dev/null
			fi
			sleep 3
			open -a "BitBar"
		fi
		exit
	else
		_sysbeep &
		_notify "⚠️ Error: download!" "Downloading release version instead…" &
		if [[ $(_mucom_download 2>/dev/null) == "OK" ]] ; then
			_appbeep &
			_notify "✅ Download finished!" "$defaultdldir_short/$filename"
			if [[ $2 == "finder" ]] ; then
				osascript -e "tell application \"Finder\"" -e "activate" -e "reveal POSIX file \"$localdlpath\"" -e "end tell" &>/dev/null
			else
				open -b "$2" "$dlparent" &>/dev/null
			fi
		else
			_sysbeep &
			_notify "⚠️ Error: download!" "Opening browser instead" &
			open "$mucomdlmurl" 2>/dev/null
		fi
	fi
	exit
fi

# download update
if [[ $1 == "download" ]] ; then
	if [[ $2 == "mum" ]] ; then
		if [[ $(_mucom_download 2>/dev/null) == "OK" ]] ; then
			_appbeep &
			_notify "✅ Download finished!" "$defaultdldir_short/$filename"
			if [[ $3 == "finder" ]] ; then
				osascript -e "tell application \"Finder\"" -e "activate" -e "reveal POSIX file \"$localdlpath\"" -e "end tell" &>/dev/null
			else
				dlparent=$(dirname "$localdlpath")
				open -b "$3" "$dlparent" &>/dev/null
			fi
		else
			_sysbeep &
			_notify "⚠️ Error: download!" "Opening browser instead" &
			open "$mucomdlmurl" 2>/dev/null
		fi
	else
		if [[ $2 == "mur" ]] ; then
			murddlurl="$3"
			filename=$(basename "$murddlurl")
			localdlpath="$defaultdldir/$filename"
			if [[ -f "$localdlpath" ]] ; then
				rm -f "$localdlpath" 2>/dev/null
			fi
			if curl -k -L -s --connect-timeout 30 -o "$localdlpath" "$murddlurl" &>/dev/null ; then
				if [[ -f "$localdlpath" ]] ; then
					xattr -cr "$localdlpath"
					_appbeep &
					_notify "✅ Download finished!" "$defaultdldir_short/$filename"
					if [[ $4 == "finder" ]] ; then
						osascript -e "tell application \"Finder\"" -e "activate" -e "reveal POSIX file \"$localdlpath\"" -e "end tell" &>/dev/null
					else
						dlparent=$(dirname "$localdlpath")
						open -b "$4" "$dlparent" &>/dev/null
					fi
				else
					_sysbeep &
					_notify "⚠️ Error: download!" "Opening browser instead…" &
					open "$murddlurl" &>/dev/null
				fi
			else
				_sysbeep &
				_notify "⚠️ Error: download!" "Opening browser instead…" &
				open "$murddlurl" &>/dev/null
			fi
		fi
	fi
	exit
fi

# check for MacUpdater Menu updates
mucom_outdated=false
mucom_outdated_or=false
if $mucheck ; then
	mucomrv_raw=$(curl -k -L -s --connect-timeout 30 --max-time 60 "$mucomvurl" 2>/dev/null)
	if [[ $mucomrv_raw ]] ; then
		mucom_newhelp=$(echo "$mucomrv_raw" | awk '/help/{print $2}')
		if [[ $mucom_newhelp != "0" ]] ; then
			whoami &>/dev/null ###
			### download & install help (initial or update)
			# check if $helploc exists > not: download & install (initial) > test
			# if yes:
			# check local helpv in info.plist, compare with online helpv
			# less than: install & update
			###
		fi
		mucom_newvc=$(echo "$mucomrv_raw" | head -1 | awk '{print $1}')
		mucom_newv=$(echo "$mucomrv_raw" | head -1 | awk '{print $2}')
		mucom_newbeta=$(echo "$mucomrv_raw" | awk '/beta/{print $2}')
		mucom_newbuild=$(echo "$mucomrv_raw" | awk '/build/{print $2}')
		if [[ $mucom_newvc -gt "$cversion" ]] ; then
			mucom_outdated=true
		else
			if [[ $mucom_newbeta == "-" ]] ; then
				if [[ $mucom_newbuild -gt "$build" ]] ; then
					mucom_outdated=true
				fi
			else
				if [[ $mucom_newbeta -gt "$betaversion" ]] ; then
					mucom_outdated=true
				else
					if [[ $mucom_newbuild -gt "$build" ]] ; then
						mucom_outdated=true
					fi
				fi
			fi
		fi
		if $mucom_outdated ; then
			mucomrv_saved=$(/usr/libexec/PlistBuddy -c "Print:remoteMUM" "$prefsloc" 2>/dev/null)
			if ! [[ $mucomrv_saved ]] ; then
				defaults write "$procid" remoteMUM "$mucom_newvc;$mucom_newv;$mucom_newbeta;$mucom_newbuild" 2>/dev/null
			else
				if [[ $mucomrv_saved == "$mucom_newvc;$mucom_newv;$mucom_newbeta;$mucom_newbuild" ]] ; then
					mucom_outdated_or=true
				fi
			fi
		else
			defaults write "$procid" remoteMUM "" 2>/dev/null
		fi
	else
		mucomrv_saved=$(/usr/libexec/PlistBuddy -c "Print:remoteMUM" "$prefsloc" 2>/dev/null)
		if echo "$mucomrv_saved" | grep -q ";" &>/dev/null ; then
			mucom_newvc=$(echo "$mucomrv_saved" | awk -F";" '{print $1}')
			mucom_newv=$(echo "$mucomrv_saved" | awk -F";" '{print $2}')
			mucom_newbeta=$(echo "$mucomrv_saved" | awk -F";" '{print $3}')
			mucom_newbuild=$(echo "$mucomrv_saved" | awk -F";" '{print $4}')
			if [[ $mucom_newvc -gt "$cversion" ]] ; then
				mucom_outdated=true
			else
				if [[ $mucom_newbeta == "-" ]] ; then
					if [[ $mucom_newbuild -gt "$build" ]] ; then
						mucom_outdated=true
					fi
				else
					if [[ $mucom_newbeta -gt "$betaversion" ]] ; then
						mucom_outdated=true
					else
						if [[ $mucom_newbuild -gt "$build" ]] ; then
							mucom_outdated=true
						fi
					fi
				fi
			fi
			if $mucom_outdated ; then
				defaults write "$procid" remoteMUM "$mucom_newvc;$mucom_newv;$mucom_newbeta;$mucom_newbuild" 2>/dev/null
				mucom_outdated_or=true
			else
				defaults write "$procid" remoteMUM "" 2>/dev/null
			fi
		fi
	fi
else
	mucomrv_saved=$(/usr/libexec/PlistBuddy -c "Print:remoteMUM" "$prefsloc" 2>/dev/null)
	if echo "$mucomrv_saved" | grep -q ";" &>/dev/null ; then
		mucom_newvc=$(echo "$mucomrv_saved" | awk -F";" '{print $1}')
		mucom_newv=$(echo "$mucomrv_saved" | awk -F";" '{print $2}')
		mucom_newbeta=$(echo "$mucomrv_saved" | awk -F";" '{print $3}')
		mucom_newbuild=$(echo "$mucomrv_saved" | awk -F";" '{print $4}')
		if [[ $mucom_newvc -gt "$cversion" ]] ; then
			mucom_outdated=true
		else
			if [[ $mucom_newbeta == "-" ]] ; then
				if [[ $mucom_newbuild -gt "$build" ]] ; then
					mucom_outdated=true
				fi
			else
				if [[ $mucom_newbeta -gt "$betaversion" ]] ; then
					mucom_outdated=true
				else
					if [[ $mucom_newbuild -gt "$build" ]] ; then
						mucom_outdated=true
					fi
				fi
			fi
		fi
		if $mucom_outdated ; then
			defaults write "$procid" remoteMUM "$mucom_newvc;$mucom_newv;$mucom_newbeta;$mucom_newbuild" 2>/dev/null
			mucom_outdated_or=true
		else
			defaults write "$procid" remoteMUM "" 2>/dev/null
		fi
	fi
fi

_versioncompare () {
	remoteversion="$1"
	localversion="$2"
	bundleversion="$3"
	if [[ $remoteversion == "$localversion" ]] ; then
		echo 0
	else
		comparebeta=false
		comparealpha=false
		remotebetaversion=""
		remotealphaversion=""
		localbetaversion=""
		localalphaversion=""
		localversion=$(echo "$localversion" | sed "s/-$bundleversion$//")
		abort=false
		if echo "$localversion" | grep -q "beta" &>/dev/null ; then
			if echo "$remoteversion" | grep -q "beta" &>/dev/null ; then
				comparebeta=true
				remotebetaversion=$(echo "$remoteversion" | awk -F"beta" '{print $2}' | sed "s/[^0-9]*//g")
				remoteversion=$(echo "$remoteversion" | awk -F"beta" '{print $1}')
				localbetaversion=$(echo "$localversion" | awk -F"beta" '{print $2}' | sed "s/[^0-9]*//g")
				localversion=$(echo "$localversion" | awk -F"beta" '{print $1}')
			elif echo "$remoteversion" | grep -q "alpha" &>/dev/null ; then
				echo 2
				abort=true
			else
				echo 1
				abort=true
			fi
		elif echo "$localversion" | grep -q "alpha" &>/dev/null ; then
			if echo "$remoteversion" | grep -q "alpha" &>/dev/null ; then
				comparealpha=true
				remotealphaversion=$(echo "$remoteversion" | awk -F"alpha" '{print $2}' | sed 's/ //g')
				remoteversion=$(echo "$remoteversion" | awk -F"alpha" '{print $1}')
				localalphaversion=$(echo "$localversion" | awk -F"alpha" '{print $2}' | sed 's/ //g')
				localversion=$(echo "$localversion" | awk -F"alpha" '{print $1}')
			elif echo "$remoteversion" | grep -q "beta" &>/dev/null ; then
				echo 1
				abort=true
			else
				echo 1
				abort=true
			fi
		fi
		if ! $abort ; then
			remoteversion=$(echo "$remoteversion" | sed -E 's/([0-9])([a-zA-Z])/\1\.\2/g')
			localversion=$(echo "$localversion" | sed -E 's/([0-9])([a-zA-Z])/\1\.\2/g')
			remoteversion=$(echo "$remoteversion" | sed -e "s/[-,;]/\./g" -e "s/ //g")
			localversion=$(echo "$localversion" | sed -e "s/[-,;]/\./g" -e "s/ //g")
			remoteversion=$(echo "$remoteversion" | sed -e "s/[aA]/001\./g" \
				-e "s/[bB]/002\./g" \
				-e "s/[cC]/003\./g" \
				-e "s/[dD]/004\./g" \
				-e "s/[eE]/005\./g" \
				-e "s/[fF]/006\./g" \
				-e "s/[gG]/007\./g" \
				-e "s/[hH]/008\./g" \
				-e "s/[iI]/009\./g" \
				-e "s/[jJ]/010\./g" \
				-e "s/[kK]/011\./g" \
				-e "s/[lL]/012\./g" \
				-e "s/[mM]/013\./g" \
				-e "s/[nN]/014\./g" \
				-e "s/[oO]/015\./g" \
				-e "s/[pP]/016\./g" \
				-e "s/[qQ]/017\./g" \
				-e "s/[rR]/018\./g" \
				-e "s/[sS]/019\./g" \
				-e "s/[tT]/020\./g" \
				-e "s/[uU]/021\./g" \
				-e "s/[vV]/022\./g" \
				-e "s/[wW]/023\./g" \
				-e "s/[xX]/024\./g" \
				-e "s/[yY]/025\./g" \
				-e "s/[zZ]/026\./g")
			localversion=$(echo "$localversion" | sed -e "s/[aA]/001\./g" \
				-e "s/[bB]/002\./g" \
				-e "s/[cC]/003\./g" \
				-e "s/[dD]/004\./g" \
				-e "s/[eE]/005\./g" \
				-e "s/[fF]/006\./g" \
				-e "s/[gG]/007\./g" \
				-e "s/[hH]/008\./g" \
				-e "s/[iI]/009\./g" \
				-e "s/[jJ]/010\./g" \
				-e "s/[kK]/011\./g" \
				-e "s/[lL]/012\./g" \
				-e "s/[mM]/013\./g" \
				-e "s/[nN]/014\./g" \
				-e "s/[oO]/015\./g" \
				-e "s/[pP]/016\./g" \
				-e "s/[qQ]/017\./g" \
				-e "s/[rR]/018\./g" \
				-e "s/[sS]/019\./g" \
				-e "s/[tT]/020\./g" \
				-e "s/[uU]/021\./g" \
				-e "s/[vV]/022\./g" \
				-e "s/[wW]/023\./g" \
				-e "s/[xX]/024\./g" \
				-e "s/[yY]/025\./g" \
				-e "s/[zZ]/026\./g")
			remoteversion=$(echo "$remoteversion" | sed -e "s/\.\./\.0\./g" -e 's/\.$//' -e "s/ *$//" -e "s/^\./0\./")
			localversion=$(echo "$localversion" | sed -e "s/\.\./\.0\./g" -e 's/\.$//' -e "s/ *$//" -e "s/^\./0\./")
			if [[ $remoteversion == "$localversion" ]] ; then
				if $comparebeta ; then
					if [[ $remotebetaversion -gt "$localbetaversion" ]] ; then
						echo 1
					elif [[ $remotebetaversion -eq "$localbetaversion" ]] ; then
						echo 0
					elif [[ $remotebetaversion -lt "$localbetaversion" ]] ; then
						echo 2
					fi
				elif $comparealpha ; then
					if [[ $remotealphaversion -gt "$localalphaversion" ]] ; then
						echo 1
					elif [[ $remotealphaversion -eq "$localalphaversion" ]] ; then
						echo 0
					elif [[ $remotealphaversion -lt "$localalphaversion" ]] ; then
						echo 2
					fi
				else
					echo 0
				fi
			else
				largestversion=$(echo -e "$remoteversion\n$localversion" | sort -r | head -1)
				if [[ $largestversion == "$remoteversion" ]] ; then
					echo 1
				else
					echo 2
				fi
			fi
		fi
	fi
}

# check for MacUpdater
mur_outdated=false
mur_outdated_or=false
ccmu_present=false
if ! $skipmur ; then
	if ! $customapps ; then
		ccmuloc=$(mdfind \
			-onlyin /Applications/ \
			-onlyin /Developer/Applications/ \
			-onlyin /Network/Applications/ \
			-onlyin /Network/Developer/Applications/ \
			-onlyin "$HOMEDIR"/Applications/ \
			-onlyin "$HOMEDIR"/Developer/Applications/ \
			"kMDItemCFBundleIdentifier == 'com.corecode.MacUpdater'" 2>/dev/null | LC_COLLATE=C sort | head -1)
	else
		ccmuloc=$(mdfind \
			-onlyin /Applications/ \
			-onlyin /Developer/Applications/ \
			-onlyin /Network/Applications/ \
			-onlyin /Network/Developer/Applications/ \
			-onlyin "$HOMEDIR"/Applications/ \
			-onlyin "$HOMEDIR"/Developer/Applications/ \
			-onlyin "$customappdir"/ \
			"kMDItemCFBundleIdentifier == 'com.corecode.MacUpdater'" 2>/dev/null | LC_COLLATE=C sort | head -1)
	fi
	if [[ $ccmuloc ]] ; then
		ccmuloc_short="${ccmuloc/#$HOMEDIR/~}"
		ccmu_present=true
		ccmuinfoplistloc="$ccmuloc/Contents/Info.plist"
		ccmuinstalledv=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ccmuinfoplistloc" 2>/dev/null)
		ccmuinstalledb=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$ccmuinfoplistloc" 2>/dev/null)
	fi	
	ccmu_saved=$(/usr/libexec/PlistBuddy -c "Print :remoteMUR" "$prefsloc" 2>/dev/null)
	ccmuv_saved=$(echo "$ccmu_saved" | awk -F";" '{print $1}')
	if $mucheck ; then
		ccmuv_raw=$(curl -k -L -s --connect-timeout 30 --max-time 60 -e "$mucomurl" "https://www.corecode.io/macupdater/macupdater.xml" 2>/dev/null)
		if [[ $ccmuv_raw ]] ; then
			ccmuv_current=$(echo "$ccmuv_raw" | grep "sparkle:shortVersionString=" | head -1 | awk -F\" '{print $2}')
		else
			if $ccmu_present ; then
				ccmuv_current="$ccmuinstalledv"
			else
				if [[ $ccmuv_saved ]] ; then
					ccmuv_current="$ccmuv_saved"
				else
					ccmuv_current="[n/a]"
				fi
			fi
		fi
		if ! $ccmu_present ; then
			ccmu_size=$(echo "$ccmuv_raw" | grep "length=" | head -1 | awk -F\" '{print $2}')
			ccmu_mbraw=$(bc -l <<< "scale=6; $ccmu_size/1000000")
			ccmu_mbytes=$(_round "$ccmu_mbraw" 2)
			[[ $ccmu_mbytes == "0.00" ]] && ccmu_mbytes="< 0.01"
			ccmu_dlurl=$(echo "$ccmuv_raw" | grep "enclosure.*url=" | head -1 | awk -F\" '{print $2}')
		else
			ccmuvcom=$(_versioncompare "$ccmuv_current" "$ccmuinstalledv" "$ccmuinstalledb" 2>/dev/null)
			if [[ $ccmuvcom == 1 ]] ; then
				mur_outdated=true
				ccmu_size=$(echo "$ccmuv_raw" | grep "length=" | head -1 | awk -F\" '{print $2}')
				ccmu_mbraw=$(bc -l <<< "scale=6; $ccmu_size/1000000")
				ccmu_mbytes=$(_round "$ccmu_mbraw" 2)
				[[ $ccmu_mbytes == "0.00" ]] && ccmu_mbytes="< 0.01"
				ccmu_dlurl=$(echo "$ccmuv_raw" | grep "enclosure.*url=" | head -1 | awk -F\" '{print $2}')
				if [[ $ccmu_saved != "$ccmuv_current;$ccmu_size;$ccmu_dlurl" ]] ; then
					defaults write "$prefsloc" remoteMUR "$ccmuv_current;$ccmu_size;$ccmu_dlurl" 2>/dev/null
				else
					if [[ $ccmu_saved ]] ; then
						mur_outdated_or=true
					else
						defaults write "$prefsloc" remoteMUR "$ccmuv_current;$ccmu_size;$ccmu_dlurl" 2>/dev/null
					fi
				fi
				mur_newv="$ccmuv_current"
			else
				if [[ $ccmu_saved ]] ; then
					defaults write "$prefsloc" remoteMUR "" 2>/dev/null
				fi
			fi
		fi
	else
		if $ccmu_present ; then
			if [[ $ccmu_saved ]] ; then
				ccmuvcom=$(_versioncompare "$ccmuv_saved" "$ccmuinstalledv" "$ccmuinstalledb" 2>/dev/null)
				if [[ $ccmuvcom == 1 ]] ; then
					mur_outdated=true
					ccmu_size=$(echo "$ccmu_saved" | awk -F";" '{print $2}')
					ccmu_mbraw=$(bc -l <<< "scale=6; $ccmu_size/1000000")
					ccmu_mbytes=$(_round "$ccmu_mbraw" 2)
					[[ $ccmu_mbytes == "0.00" ]] && ccmu_mbytes="< 0.01"
					ccmu_dlurl=$(echo "$ccmu_saved" | awk -F";" '{print $3}')
					mur_outdated_or=true
					ccmuv_current="$ccmuv_saved"
					mur_newv="$ccmuv_saved"
				else
					defaults write "$prefsloc" remoteMUR "" 2>/dev/null
				fi
			fi
		fi
	fi
fi
	
# download & convert MacUpdate appcast
updates=false
iupdates=false
fetcherror=false
if $mucheck ; then
	rm -f /tmp/mucast-new.plist 2>/dev/null
	if [[ -f "/tmp/mucast.plist" ]] ; then
		oldhash=$(md5 -q /tmp/mucast.plist 2>/dev/null)
		curl -k -L -s --connect-timeout 30 --max-time 60 -o /tmp/mucast-new.plist "https://www.macupdate.com/mommy/updates.xml" 2>/dev/null
		if [[ $(stat -f%z /tmp/mucast-new.plist 2>/dev/null) -gt 0 ]] ; then
			newhash=$(md5 -q /tmp/mucast-new.plist 2>/dev/null)
			if [[ $newhash == "$oldhash" ]] ; then
				rm -f /tmp/mucast-new.plist 2>/dev/null
			else
				updates=true
				rm -f /tmp/mucast.plist 2>/dev/null
				mv -f /tmp/mucast-new.plist /tmp/mucast.plist 2>/dev/null
			fi
			fetchdate=$(date +"%H:%M on %a %d %b %Y")
			fetchposix=$(date +%s)
		else
			fetcherror=true
		fi
	else
		curl -k -L -s --connect-timeout 30 --max-time 60 -o /tmp/mucast.plist "https://www.macupdate.com/mommy/updates.xml" 2>/dev/null
		if [[ $(stat -f%z /tmp/mucast.plist 2>/dev/null) -gt 0 ]] ; then
			fetchdate=$(date +"%H:%M on %a %d %b %Y")
			fetchposix=$(date +%s)
			updates=true
		else
			fetcherror=true
		fi
	fi
	if ! $fetcherror ; then
		defaults write "$procid" lastRefreshAction -int "$fetchposix" 2>/dev/null
		defaults write "$procid" lastUpdates "$fetchdate" 2>/dev/null
	fi
fi

# check for file manager
fileman=false
filemanager=$(defaults read -g NSFileViewer 2>/dev/null)
if [[ $filemanager ]] ; then
	if [[ $filemanager != "com.apple.Finder" ]] ; then
		fileman=true
	fi
fi
if $fileman ; then
	if ! $customapps ; then
		fmapploc=$(mdfind \
			-onlyin /Applications/ \
			-onlyin /Developer/Applications/ \
			-onlyin /Network/Applications/ \
			-onlyin /Network/Developer/Applications/ \
			-onlyin "$HOMEDIR"/Applications/ \
			-onlyin "$HOMEDIR"/Developer/Applications/ \
			"kMDItemCFBundleIdentifier == \"$filemanager\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
	else
		fmapploc=$(mdfind \
			-onlyin /Applications/ \
			-onlyin /Developer/Applications/ \
			-onlyin /Network/Applications/ \
			-onlyin /Network/Developer/Applications/ \
			-onlyin "$HOMEDIR"/Applications/ \
			-onlyin "$HOMEDIR"/Developer/Applications/ \
			-onlyin "$customappdir"/ \
			"kMDItemCFBundleIdentifier == \"$filemanager\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
	fi
	if ! [[ $fmapploc ]] ; then
		fileman=false
	else
		fminfoplistloc="$fmapploc/Contents/Info.plist"
		if ! [[ -f $fminfoplistloc ]] ; then
			fileman=false
		else
			fmname=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$fminfoplistloc" 2>/dev/null)
			if ! [[ $fmname ]] ; then
				fileman=false
			else
				# get custom file manager icon
				fmappiconname=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$fminfoplistloc" 2>/dev/null)
				if ! [[ $fmappiconname ]] ; then
					fmappicon="$genericappicon"
				else
					if echo "$fmappiconname" | grep -q "\." &>/dev/null ; then
						fmappiconloc="$fmapploc/Contents/Resources/$fmappiconname"
					else
						fmappiconloc="$fmapploc/Contents/Resources/$fmappiconname.icns"
					fi
					if ! [[ -f "$fmappiconloc" ]] ; then
						fmappicon="$genericappicon"
					else
						resolution=$(sips --getProperty dpiWidth "$fmappiconloc" 2>/dev/null | awk -F"dpiWidth: " '/dpiWidth: /{print $2}')
						if [[ $resolution != "144.000" ]] && [[ $resolution != "72.000" ]] ; then
							appicon="$genericappicon"
						else
							if [[ $resolution == "144.000" ]] ; then
								sips -Z 32 "$appiconloc" --out /tmp/mucom-"$appname" &>/dev/null
							elif [[ $resolution == "72.000" ]] ; then
								sips -Z 16 "$appiconloc" --out /tmp/mucom-"$appname" &>/dev/null
							fi
							sips -Z 32 "$fmappiconloc" --out /tmp/mucom-filemanager &>/dev/null
							fmappicon=$(base64 -i /tmp/mucom-filemanager 2>/dev/null)
							rm -f /tmp/mucom-filemanager 2>/dev/null
							if ! [[ $fmappicon ]] ; then
								fmappicon="$genericappicon"
							fi
						fi
					fi
				fi
			fi
		fi
	fi
fi

# default initial print
if $updates || $mur_outdated || $mucom_outdated ; then
	echo "| image=$mumred dropdown=false"
else
	echo "| templateImage=$menuicon dropdown=false"
fi

echo "---"

if $fetcherror ; then
	echo "Error Fetching Updates | image=\"$offlineicon\" color=red"
	echo "---"
fi

echo "Last updated at $fetchdate | size=11"

echo "Update Now | image=\"$updateicon\" refresh=true terminal=false bash=\"${0}\" param1=manualrefresh"
echo "Refresh | image=\"$updateicon\" alternate=true refresh=true"

echo "Search MacUpdate… | image=\"$searchicon\" terminal=false bash=\"${0}\" param1=musearch param2=mucom"
echo "Search MacUpdater… | image=\"$searchicon\" alternate=true terminal=false bash=\"${0}\" param1=musearch param2=munet"

echo "---"

# print outdated MUM
if $mucom_outdated ; then
	echo "Plug-in | size=11"
	if [[ $mucom_newbeta == "-" ]] ; then
		echo "MacUpdate Menu $mucom_newv b$mucom_newbuild | image=\"$mucomiconsmall\" color=green"
	else
		echo "MacUpdate Menu $mucom_newv beta $mucom_newbeta b$mucom_newbuild | image=\"$mucomiconsmall\" color=green"
	fi
	echo "--Installed Version: $version$vmisc b$build | image=\"$alerticon\" color=green"
	echo "--local.lcars.MacUpdateMenu | image=\"$blankslimicon\" size=11"
	echo "-----"
	if $symlink ; then
		if $linkfound && $github ; then
			echo "--Update MacUpdate Menu… | image=\"$bitbaricon\" refresh=true terminal=false bash=\"${0}\" param1=install param2=\"$filemanager\" param3=symlink param4=linkgit" 
		else
			echo "--Update MacUpdate Menu… | image=\"$bitbaricon\" refresh=true terminal=false bash=\"${0}\" param1=install param2=\"$filemanager\" param3=symlink" 
		fi
	else
		echo "--Update MacUpdate Menu… | image=\"$bitbaricon\" refresh=true terminal=false bash=\"${0}\" param1=install param2=\"$filemanager\"" 
	fi
	echo "-----"
	if $fileman ; then
		echo "--Download MacUpdate Menu… | image=\"$dlficon\" refresh=true terminal=false bash=\"${0}\" param1=download param2=mum param3=\"$filemanager\""
	else
		echo "--Download MacUpdate Menu… | image=\"$dlficon\" refresh=true terminal=false bash=\"${0}\" param1=download param2=mum param3=finder"
	fi
	echo "--Size: < 1.00 MB | image=\"$blankslimicon\" size=11"
	echo "-----"
	echo "--Display the latest MacUpdate releases | image=\"$infoicon\" href=\"$mucomurl\""
	echo "--Developer: Joss Brown | image=\"$blankslimicon\" size=11"
	echo "--License: Free | image=\"$blankslimicon\" size=11"
	echo "-----"
	echo "--Releases… | image=\"$githubicon\" href=\"$mucomrelurl\""
	echo "---"
fi

# parse appcast
muraw=$(/usr/libexec/PlistBuddy -c "Print" /tmp/mucast.plist 2>/dev/null | grep -v -e "Dict {$" -e "}$" -e "Updates = Array {$" -e "DownloadURL = http" -e "OSX = 1$" -e "OSX = 0$")
mucsv=""
while read -r plistline
do
	plistkey=$(echo "$plistline" | awk -F" = " '{print $2}')
	if [[ $plistline == "Author = "* ]] ; then
		mucsv="$mucsv\n$plistkey"
	else
		mucsv="$mucsv;$plistkey"
	fi
done < <(echo "$muraw")
mucsv=$(echo -e "$mucsv")

# check for new version of MacUpdate Desktop
mud_date=$(echo "$mucsv" | grep ";MacUpdate Desktop;" | awk -F";" '{print $3}' | awk '{print $1}')
comp_date=$(date +"%Y-%m-%d")
if [[ $mud_date != "$comp_date" ]] ; then
	mucsv=$(echo "$mucsv" | grep -v ";MacUpdate Desktop;")
fi

# sorting routines
if ! $catsort ; then
	if $namesort ; then
		mucsv=$(echo "$mucsv" | LC_COLLATE=C sort -t ';' -ifk 7,7)	
	else
		mucsv=$(echo "$mucsv" | sort -t ';' -rk 3,3)
	fi
else
	commclist=$(echo "$mucsv" | grep ";Commercial;" 2>/dev/null)
	if $namesort ; then
		commclist=$(echo "$commclist" | LC_COLLATE=C sort -t ';' -ifk 7,7)
	else
		commclist=$(echo "$commclist" | sort -t ';' -rk 3,3)
	fi
	democlist=$(echo "$mucsv" | grep ";Demo;" 2>/dev/null)
	if $namesort ; then
		democlist=$(echo "$democlist" | LC_COLLATE=C sort -t ';' -ifk 7,7)
	else
		democlist=$(echo "$democlist" | sort -t ';' -rk 3,3)
	fi
	freeclist=$(echo "$mucsv" | grep ";Free;" 2>/dev/null)
	if $namesort ; then
		freeclist=$(echo "$freeclist" | LC_COLLATE=C sort -t ';' -ifk 7,7)
	else
		freeclist=$(echo "$freeclist" | sort -t ';' -rk 3,3)
	fi
	shareclist=$(echo "$mucsv" | grep ";Shareware;" 2>/dev/null)
	if $namesort ; then
		shareclist=$(echo "$shareclist" | LC_COLLATE=C sort -t ';' -ifk 7,7)
	else
		shareclist=$(echo "$shareclist" | sort -t ';' -rk 3,3)
	fi
	updclist=$(echo "$mucsv" | grep ";Updater;" 2>/dev/null)
	if $namesort ; then
		updclist=$(echo "$updclist" | LC_COLLATE=C sort -t ';' -ifk 7,7)
	else
		updclist=$(echo "$updclist" | sort -t ';' -rk 3,3)
	fi
	mucsv=$(echo -e "$commclist\n$democlist\n$freeclist\n$shareclist\n$updclist" | grep -v "^$")
fi
commcprint=false
democprint=false
freecprint=false
sharecprint=false
updcprint=false

# main application section
while IFS=";" read -r appdev appv appdate appcat appkibs appinfourl appname appdescr apphot
do
	devopen=false
	color_or=false
	appv=$(echo "$appv" | sed "s/\.$//")
	if echo "$appv" | grep -q "\." &>/dev/null ; then
		avmajor=$(echo "$appv" | awk -F\. '{print $1}' | sed 's/[^0-9]*//g')
	else
		avmajor=$(echo "$appv" | sed 's/[^0-9]*//g')
	fi
	if $catsort ; then
		if [[ $appcat == "Commercial" ]] && ! $commcprint ; then
			echo "Commercial | size=11"
			commcprint=true
		else
			if [[ $appcat == "Demo" ]] && ! $democprint ; then
				if $commcprint ; then
					echo "---"
				fi
				echo "Demo | size=11"
				democprint=true
			else
				if [[ $appcat == "Free" ]] && ! $freecprint ; then
					if $democprint || $commcprint ; then
						echo "---"
					fi
					echo "Free | size=11"
					freecprint=true
				else
					if [[ $appcat == "Shareware" ]] && ! $sharecprint ; then
						if $freecprint || $democprint || $commcprint ; then
							echo "---"
						fi
						echo "Shareware | size=11"
						sharecprint=true
					else
						if [[ $appcat == "Updater" ]] && ! $updcprint ; then
							if $freecprint || $democprint || $commcprint || $sharecprint ; then
								echo "---"
							fi
							echo "Updater | size=11"
							updcprint=true
						fi
					fi
				fi
			fi
		fi
	fi
	if $ignorehp ; then
		hotpick=false
	else
		if [[ $apphot == "1" ]] ; then
			hotpick=true
		else
			hotpick=false
		fi
	fi
	appname=$(echo "$appname" | sed "s/\\\U/\\u/g")
	appname=$(echo "$appname" | iconv --to-code="ISO-8859-1")
	# check for iOS et al.
	foreign=false
	if [[ $appname == "Apple iOS" ]] || [[ $appname == "Apple iPadOS" ]] || [[ $appname == "Apple watchOS" ]] || [[ $appname == "Apple tvOS" ]] ; then
		foreign=true
		apploc=""
		foreignshortname=$(echo "$appname" | sed "s/^Apple //")
	else # search for application
		if ! $customapps ; then
			apploc=$(mdfind \
				-onlyin /Applications/ \
				-onlyin "$HOMEDIR"/Applications/ \
				-onlyin /Developer/Applications/ \
				-onlyin "$HOMEDIR"/Developer/Applications/ \
				-onlyin /Network/Applications/ \
				-onlyin /Network/Developer/Applications/ \
				"kMDItemDisplayName == \"$appname.app\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
		else
			apploc=$(mdfind \
				-onlyin /Applications/ \
				-onlyin "$HOMEDIR"/Applications/ \
				-onlyin /Developer/Applications/ \
				-onlyin "$HOMEDIR"/Developer/Applications/ \
				-onlyin /Network/Applications/ \
				-onlyin /Network/Developer/Applications/ \
				-onlyin "$customappdir"/ \
				"kMDItemDisplayName == \"$appname.app\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
		fi
		if ! [[ $apploc ]] ; then # no app: search for PreferencePane
			apploc=$(mdfind \
				-onlyin "$HOMEDIR"/Library/PreferencePanes/ \
				-onlyin /Library/PreferencePanes/ \
				"kMDItemDisplayName == \"$appname.prefPane\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
		fi
		if ! [[ $apploc ]] ; then # could be a custom app name that MacUpdate doesn't support
			if echo "$appname" | grep -q "^Adobe " &>/dev/null ; then # Adobe apps tend to have an appended year
				if ! $customapps ; then
					apploc=$(find "/Applications" "$HOMEDIR/Applications" "/Developer/Applications" "$HOMEDIR/Developer/Applications" "/Network/Applications" "/Network/Developer/Applications" -mindepth 1 -maxdepth 3 -type d -name "$appname*" 2>/dev/null | grep "\.app$" | grep -v "\.app/" | LC_COLLATE=C sort | head -1)
				else
					apploc=$(find "/Applications" "$HOMEDIR/Applications" "/Developer/Applications" "$HOMEDIR/Developer/Applications" "/Network/Applications" "/Network/Developer/Applications" "$customappdir" -mindepth 1 -maxdepth 3 -type d -name "$appname*" 2>/dev/null | grep "\.app$" | grep -v "\.app/" | LC_COLLATE=C sort | head -1)
				fi
				if [[ $apploc ]] ; then
					appname_long=$(basename "$apploc")
					appname="${appname_long%.*}"
				fi
			else # not Adobe
				if [[ $appdev == "Apple Inc." ]] && echo "$appname" | grep -q "^Apple " &>/dev/null ; then # Apple app
					searchname=$(echo "$appname" | sed "s/^Apple //") # most Apple apps don't have a leading "Apple"
					if ! $customapps ; then
						apploc=$(mdfind \
							-onlyin /Applications/ \
							-onlyin "$HOMEDIR"/Applications/ \
							-onlyin /Developer/Applications/ \
							-onlyin "$HOMEDIR"/Developer/Applications/ \
							-onlyin /Network/Applications/ \
							-onlyin /Network/Developer/Applications/ \
							"kMDItemDisplayName == \"$searchname.app\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
					else
						apploc=$(mdfind \
							-onlyin /Applications/ \
							-onlyin "$HOMEDIR"/Applications/ \
							-onlyin /Developer/Applications/ \
							-onlyin "$HOMEDIR"/Developer/Applications/ \
							-onlyin /Network/Applications/ \
							-onlyin /Network/Developer/Applications/ \
							-onlyin "$customappdir"/ \
							"kMDItemDisplayName == \"$searchname.app\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
					fi
					if ! [[ $apploc ]] ; then # some Apple apps (like Configurator) might have a trailing major version number
						if [[ $avmajor -ge 2 ]] ; then
							if [[ $avmajor -ge 3 ]] ; then
								searchvn="$(echo "$avmajor - 1" | bc 2>/dev/null)"
							else
								searchvn="$avmajor"
							fi
							while true
							do
								[[ $searchvn -eq 10 ]] && break ### update if Apple app version numbers become two-digit
								if ! $customapps ; then
									apploc=$(mdfind \
										-onlyin /Applications/ \
										-onlyin "$HOMEDIR"/Applications/ \
										-onlyin /Developer/Applications/ \
										-onlyin "$HOMEDIR"/Developer/Applications/ \
										-onlyin /Network/Applications/ \
										-onlyin /Network/Developer/Applications/ \
										"kMDItemDisplayName == \"$appname $searchvn.app\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
								else
									apploc=$(mdfind \
										-onlyin /Applications/ \
										-onlyin "$HOMEDIR"/Applications/ \
										-onlyin /Developer/Applications/ \
										-onlyin "$HOMEDIR"/Developer/Applications/ \
										-onlyin /Network/Applications/ \
										-onlyin /Network/Developer/Applications/ \
										-onlyin "$customappdir"/ \
										"kMDItemDisplayName == \"$appname $searchvn.app\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
								fi
								if ! [[ $apploc ]] ; then
									if ! $customapps ; then
										apploc=$(mdfind \
											-onlyin /Applications/ \
											-onlyin "$HOMEDIR"/Applications/ \
											-onlyin /Developer/Applications/ \
											-onlyin "$HOMEDIR"/Developer/Applications/ \
											-onlyin /Network/Applications/ \
											-onlyin /Network/Developer/Applications/ \
											"kMDItemDisplayName == \"$searchname $searchvn.app\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
									else
										apploc=$(mdfind \
											-onlyin /Applications/ \
											-onlyin "$HOMEDIR"/Applications/ \
											-onlyin /Developer/Applications/ \
											-onlyin "$HOMEDIR"/Developer/Applications/ \
											-onlyin /Network/Applications/ \
											-onlyin /Network/Developer/Applications/ \
											-onlyin "$customappdir"/ \
											"kMDItemDisplayName == \"$searchname $searchvn.app\"" 2>/dev/null | LC_COLLATE=C sort | head -1)
									fi
									[[ $apploc ]] && break
								else
									break
								fi
								((searchvn++))
							done
						fi
					fi
				fi
			fi
		fi
	fi
	cli=false
	if ! [[ $apploc ]] ; then
		if $foreign ; then
			appicon="$appleicon"
		else
			if $highlightclis ; then
				if echo "$alldefaults" | grep "^$appname$" &>/dev/null ; then # known command-line utility
					appicon="$terminalicon"
					cli=true
				else # unknown or uninstalled app
					if ! $allicons ; then
						appicon="$blankicon"
					else
						appicon="$genericappicon"
					fi
				fi
			else # unknown of uninstalled app
				if ! $allicons ; then
					appicon="$blankicon"
				else
					appicon="$genericappicon"
				fi
			fi
		fi
		colored=false
	else
		apploc_short="${apploc/#$HOMEDIR/~}"
		colored=true
		infoplistloc="$apploc/Contents/Info.plist"
		if ! [[ -f $infoplistloc ]] ; then
			appicon="$genericappicon"
			installedv="[-]"
		else # search for and convert app icon
			appiconname=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$infoplistloc" 2>/dev/null)
			if ! [[ $appiconname ]] ; then
				appicon="$genericappicon"
			else
				if echo "$appiconname" | grep -q "\." &>/dev/null ; then
					appiconloc="$apploc/Contents/Resources/$appiconname"
				else
					appiconloc="$apploc/Contents/Resources/$appiconname.icns"
				fi
				if ! [[ -f "$appiconloc" ]] ; then
					appicon="$genericappicon"
				else
					resolution=$(sips --getProperty dpiWidth "$appiconloc" 2>/dev/null | awk -F"dpiWidth: " '/dpiWidth: /{print $2}')
					if [[ $resolution != "144.000" ]] && [[ $resolution != "72.000" ]] ; then
						appicon="$genericappicon"
					else
						if [[ $resolution == "144.000" ]] ; then
							sips -Z 32 "$appiconloc" --out /tmp/mucom-"$appname" &>/dev/null
						elif [[ $resolution == "72.000" ]] ; then
							sips -Z 16 "$appiconloc" --out /tmp/mucom-"$appname" &>/dev/null
						fi
						appicon=$(base64 -i /tmp/mucom-"$appname" 2>/dev/null)
						rm -f /tmp/mucom-"$appname" 2>/dev/null
						if ! [[ $appicon ]] ; then
							appicon="$genericappicon"
						fi
					fi
				fi
			fi
			# app version numbers
			installedv=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$infoplistloc" 2>/dev/null)
			installedb=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$infoplistloc" 2>/dev/null)
			if ! [[ $installedv ]] ; then
				if ! [[ $installedb ]] ; then
					installedv="[-]"
				else
					installedv="[-] ($installedb)"
				fi
				color_or=true
			else # version number compare
				vcom=$(_versioncompare "$appv" "$installedv" "$installedb" 2>/dev/null)
				if [[ $vcom == 0 ]] || [[ $vcom == 2 ]] ; then
					color_or=true
				fi
				if [[ $installedb ]] ; then
					installedb_short=$(echo "$installedb" | sed -e "s/^$installedv//" -e "s/^-//" -e "s/^\.//" 2>/dev/null)
					if [[ $installedb_short ]] ; then
						installedv="$installedv ($installedb_short)"
					else
						installedv="$installedv ($installedb)"
					fi
				else
					installedv="$installedv (-)"
				fi
			fi
			appbundleid=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$infoplistloc" 2>/dev/null)
			! [[ "$appbundleid" ]] && appbundleid="[-]"
		fi
	fi
	# print out app name and version in root
	if $colored ; then
		if $color_or ; then
			if $noicons ; then
				echo "$appname $appv"
			else
				echo "$appname $appv | image=\"$appicon\""
			fi
		else
			iupdates=true
			if $noicons ; then
				echo "$appname $appv | color=green"
			else
				echo "$appname $appv | image=\"$appicon\" color=green"
			fi
		fi
		subicon="$appicon"
	else
		if $foreign ; then
			echo "$appname $appv | image=\"$appicon\" color=purple"
			subicon="$appicon"
		else
			if $highlightclis && $cli ; then
				if $noicons ; then
					echo "$appname $appv | color=teal"
				else
					echo "$appname $appv | image=\"$appicon\" color=teal"
				fi
				subicon="$terminalicon"
			else
				if $hotpick ; then
					if $noicons ; then
						echo "$appname $appv | color=#8B0000"
					else
						echo "$appname $appv | image=\"$appicon\" color=#8B0000"
					fi
				else
					if $noicons ; then
						echo "$appname $appv"
					else
						echo "$appname $appv | image=\"$appicon\""
					fi
				fi
				subicon="$genericappicon"
			fi
		fi
	fi
	if [[ $appinfourl ]] ; then
		appdownloadurl="$appinfourl/download"
		devopen=true
	else
		appinfourl="https://www.macupdate.com/find/mac/context=$appname"
		appdownloadurl="https://www.macupdate.com/find/mac/context=$appname"
	fi
	# convert download file size
	bytes=$(echo "$appkibs * 1024" | bc)
	mbraw=$(bc -l <<< "scale=6; $bytes/1000000")
	mbytes=$(_round "$mbraw" 2)
	[[ $mbytes == "0.00" ]] && mbytes="< 0.01"
	appdescr=$(echo "$appdescr" | sed "s/\\\U/\\u/g")
	appdescr=$(echo "$appdescr" | iconv --to-code="ISO-8859-1")
	appdescr=$(echo "$appdescr" | sed -e 's/\.$//' -e 's/Mac OS X/macOS/g' -e 's/Mac OS/macOS/g' -e 's/OS X/macOS/g' -e 's/MacOS/macOS/g')
	# print out application submenu information
	if $colored ; then
		if $color_or ; then
			echo "--Installed Version: $installedv | image=\"$subicon\""
		else
			echo "--Installed Version: $installedv | image=\"$alerticon\" color=green"
		fi
		echo "--$appbundleid | image=\"$blankslimicon\" size=11"
		echo "-----"
	else
		if $foreign ; then
			echo "--Please update on your $foreignshortname device | image=\"$alerticon\" color=purple"
			echo "-----"
		fi
	fi
	if $devopen ; then
		echo "--Try to Open Official Homepage… | image=\"$urlicon\" terminal=false bash=\"${0}\" param1=opendev param2=\"$appinfourl\""
		echo "-----"
	fi
	if ! $foreign ; then
		echo "--Download \"$appname\" via MacUpdate… | image=\"$dlficon\" href=\"$appdownloadurl\""
	else
		echo "--Official \"$appname\" Release Notes… | image=\"$appleicon\" href=\"$appdownloadurl\""
	fi
	echo "--Size: $mbytes MB | image=\"$blankslimicon\" size=11"
	echo "-----"
	echo "--$appdescr | image=\"$infoicon\" href=\"$appinfourl\""
	echo "--Developer: $appdev | image=\"$blankslimicon\" size=11"
	echo "--License: $appcat | image=\"$blankslimicon\" size=11"
	echo "-----"
	echo "--Reviews & Comments… | image=\"$commentsicon\" href=\"$appinfourl#comments\""
	echo "-----"
	if $colored ; then
		if ! $fileman ; then
			if pgrep Finder &>/dev/null ; then
				echo "--Reveal \"$appname\" in Finder…| image=\"$findericon\" terminal=false bash=\"${0}\" param1=reveal param2=\"$apploc\""
			else
				echo "--Reveal \"$appname\" in Finder…| image=\"$findericon\""
				echo "--Launch Finder & Reveal \"$appname\"…| image=\"$findericon\" alternate=true terminal=false bash=\"${0}\" param1=reveal param2=\"$apploc\""
			fi
		else
			app_parent=$(dirname "$apploc")
			echo "--Reveal \"$appname\" in $fmname… | image=\"$fmappicon\" terminal=false bash=/usr/bin/open param1=-b param2=\"$filemanager\" param3=\"$app_parent\""
			if pgrep Finder &>/dev/null ; then
				echo "--Reveal \"$appname\" in Finder…| image=\"$findericon\" terminal=false bash=\"${0}\" param1=reveal param2=\"$apploc\""
			else
				echo "--Reveal \"$appname\" in Finder…| image=\"$findericon\""
				echo "--Launch Finder & Reveal \"$appname\"…| image=\"$findericon\" alternate=true terminal=false bash=\"${0}\" param1=reveal param2=\"$apploc\""
			fi
		fi
		echo "--$apploc_short | image=\"$blankslimicon\" size=11"
		echo "-----"
		echo "--Launch \"$appname\"… | image=\"$appicon\" terminal=false bash=/usr/bin/open param1=\"$apploc\""
		if [[ -f "$infoplistloc" ]] ; then
			echo "--Open Info.plist… | alternate=true image=\"$appicon\" terminal=false bash=/usr/bin/open param1=\"$infoplistloc\""
		fi
	fi
	echo "-----"
	echo "--Updated: $appdate"
done < <(echo "$mucsv" | grep -v "^$")

# MacUpdater section
if ! $skipmur ; then # compatible system
	if ! $ccmu_present ; then # MUR not installed
		if $promo ; then # promo setting active
			echo "---"
			echo "Promotion | size=11"
			if $noicons ; then
				echo "MacUpdater $ccmuv_current | color=blue"
			else
				echo "MacUpdater $ccmuv_current | image=\"$ccmu_icon\" color=blue"
			fi
			if $fileman ; then
				echo "--\"MacUpdater\" Direct Download… | image=\"$dlficon\" terminal=false bash=\"${0}\" param1=download param2=mur param3=\"$ccmu_dlurl\" param4=\"$filemanager\""
			else
				echo "--\"MacUpdater\" Direct Download… | image=\"$dlficon\" terminal=false bash=\"${0}\" param1=download param2=mur param3=\"$ccmu_dlurl\" param4=finder"
			fi
			echo "--Size: $ccmu_mbytes MB | image=\"$blankslimicon\" size=11"
			echo "-----"
			echo "--Keep all your apps up-to-date effortlessly | image=\"$infoicon\" href=\"https://corecode.io/macupdater/index.html\""
			echo "--Developer: CoreCode Ltd. | image=\"$blankslimicon\" size=11"
			echo "--License: Freemium | image=\"$blankslimicon\" size=11"
			echo "-----"
			echo "--Release Notes… | image=\"$infoicon\" href=\"https://corecode.io/macupdater/history.html\""
			echo "-----"
			echo "--CoreCode… | image=\"$ccicon\" href=\"https://corecode.io\""
			echo "--MacUpdater.net… | image=\"$ccmu_icon\" href=\"https://macupdater.net\""
		fi
	else # MUR installed
		echo "---"
		if ! $mur_outdated ; then # most recent version installed
			if ! pgrep MacUpdater &>/dev/null ; then
				echo "Launch MacUpdater… | image=\"$ccmu_icon\" refresh=true terminal=false bash=\"${0}\" param1=openmur param2=launch"
			else
				echo "Open MacUpdater… | image=\"$ccmu_icon\" terminal=false bash=\"${0}\" param1=openmur"
			fi
		else # new MUR available
			if $noicons ; then
				echo "MacUpdater $ccmuv_current | color=green"
			else
				echo "MacUpdater $ccmuv_current | image=\"$ccmu_icon\" color=green"
			fi
			echo "--Installed Version: $ccmuinstalledv ($ccmuinstalledb) | image=\"$alerticon\" color=green"
			echo "--com.corecode.MacUpdater | image=\"$blankslimicon\" size=11"
			echo "-----"
			if $fileman ; then
				echo "--\"MacUpdater\" Direct Download… | image=\"$dlficon\" terminal=false bash=\"${0}\" param1=download param2=mur param3=\"$ccmu_dlurl\" param4=\"$filemanager\""
			else
				echo "--\"MacUpdater\" Direct Download… | image=\"$dlficon\" terminal=false bash=\"${0}\" param1=download param2=mur param3=\"$ccmu_dlurl\" param4=finder"
			fi
			echo "--Size: $ccmu_mbytes MB | image=\"$blankslimicon\" size=11"
			echo "-----"
			echo "--Keep all your apps up-to-date effortlessly | image=\"$infoicon\" href=\"https://corecode.io/macupdater/index.html\""
			echo "--Developer: CoreCode Ltd. | image=\"$blankslimicon\" size=11"
			echo "--License: Freemium | image=\"$blankslimicon\" size=11"
			echo "-----"
			echo "--Release Notes… | image=\"$infoicon\" href=\"https://corecode.io/macupdater/history.html\""
			echo "-----"
			ccmu_parent=$(dirname "$ccmuloc")
			echo "--Reveal MacUpdater in $fmname… | image=\"$fmappicon\" terminal=false bash=/usr/bin/open param1=-b param2=\"$filemanager\" param3=\"$ccmu_parent\""
			if pgrep Finder &>/dev/null ; then
				echo "--Reveal MacUpdater in Finder…| image=\"$findericon\" terminal=false bash=\"${0}\" param1=reveal param2=\"$ccmuloc\""
			else
				echo "--Reveal MacUpdater in Finder…| image=\"$findericon\""
				echo "--Launch Finder & Reveal MacUpdater…| image=\"$findericon\" alternate=true terminal=false bash=\"${0}\" param1=reveal param2=\"$ccmuloc\""
			fi
			echo "--$ccmuloc_short | image=\"$blankslimicon\" size=11"
			echo "-----"
			if ! pgrep MacUpdater &>/dev/null ; then
				echo "--Launch MacUpdater… | image=\"$ccmu_icon\" refresh=true terminal=false bash=\"${0}\" param1=openmur param2=launch"
				echo "path | size=11"
			else
				echo "--Open MacUpdater… | image=\"$ccmu_icon\" terminal=false bash=\"${0}\" param1=openmur"
			fi
			echo "-----"
			echo "--Go to CoreCode… | image=\"$ccicon\" href=\"https://corecode.io\""
			echo "--Go to MacUpdater.net… | image=\"$ccmu_icon\" href=\"https://macupdater.net\""
		fi
	fi
fi

# MacUpdate Desktop
mudbid="com.macupdate.desktop6"
if ! $customapps ; then
	mudloc=$(mdfind \
		-onlyin /Applications/ \
		-onlyin /Developer/Applications/ \
		-onlyin /Network/Applications/ \
		-onlyin /Network/Developer/Applications/ \
		-onlyin "$HOMEDIR"/Applications/ \
		-onlyin "$HOMEDIR"/Developer/Applications/ \
		"kMDItemCFBundleIdentifier == '$mudbid'" 2>/dev/null | LC_COLLATE=C sort | head -1)
else
	mudloc=$(mdfind \
		-onlyin /Applications/ \
		-onlyin /Developer/Applications/ \
		-onlyin /Network/Applications/ \
		-onlyin /Network/Developer/Applications/ \
		-onlyin "$HOMEDIR"/Applications/ \
		-onlyin "$HOMEDIR"/Developer/Applications/ \
		-onlyin "$customappdir"/ \
		"kMDItemCFBundleIdentifier == '$mudbid'" 2>/dev/null | LC_COLLATE=C sort | head -1)
fi
if [[ $mudloc ]] ; then
	if ! pgrep "MacUpdate Desktop" &>/dev/null ; then
		echo "Launch MacUpdate Desktop… | image=\"$mudicon\" terminal=false bash=/usr/bin/open param1=-b param2=$mudbid"
	fi
fi

# settings submenu
echo "---"
echo "Settings"
echo "--Update Frequency | size=11"
echo "--$freqstring | refresh=true terminal=false bash=\"${0}\" param1=refreshrate param2=\"$mucom_freq\""
echo "-----"
if $catsort ; then
	echo "--Group by License | checked=true refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=groupLicenses param4=-bool param5=FALSE param6=\"2>/dev/null\""
else
	echo "--Group by License | refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=groupLicenses param4=-bool param5=TRUE param6=\"2>/dev/null\""
fi
echo "-----"
if $namesort ; then
	echo "--Sort by Date | refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=sortByName param4=-bool param5=FALSE param6=\"2>/dev/null\""
	echo "--Sort by Name | checked=true"
else
	echo "--Sort by Date | checked=true"
	echo "--Sort by Name | refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=sortByName param4=-bool param5=TRUE param6=\"2>/dev/null\""
fi
echo "-----"
if $ignorehp ; then
	echo "--Ignore MacUpdate Hotpicks | checked=true refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=ignoreHotpicks param4=-bool param5=FALSE param6=\"2>/dev/null\""
else
	echo "--Ignore MacUpdate Hotpicks | refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=ignoreHotpicks param4=-bool param5=TRUE param6=\"2>/dev/null\""
fi
echo "-----"
if $noicons ; then
	echo "--Hide Application Icons | checked=true terminal=false refresh=true bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=Icons param4=-bool param5=TRUE param6=\"2>/dev/null\""
	echo "--Show All Application Icons"
else
	echo "--Hide Application Icons | refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=Icons param4=-bool param5=FALSE param6=\"2>/dev/null\""
	if $allicons ; then
		echo "--Show All Application Icons | checked=true refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=allIcons param4=-bool param5=FALSE param6=\"2>/dev/null\""
	else
		echo "--Show All Application Icons | refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=allIcons param4=-bool param5=TRUE param6=\"2>/dev/null\""
	fi
fi
echo "-----"
if ! $customapps ; then
	echo "--[not set] | size=11"
	echo "--Add Custom Applications Folder | refresh=true terminal=false bash=\"${0}\" param1=customapps"
else
	echo "--$customappdir_short | size=11"
	echo "--Change Custom Applications Folder | refresh=true terminal=false bash=\"${0}\" param1=customapps param2=\"$customappdir\""
	echo "--Clear Custom Applications Folder | alternate=true refresh=true terminal=false bash=\"${0}\" param1=customapps param2=clear"
fi
echo "-----"
### needs a solution to notify & beep only once (sqlite database?)
#echo "-----"
#if $unotify ; then
#	echo "--Notifications | checked=true"
#	if $inotify ; then
#		echo "--Notify Only for Installed Apps | checked=true"
#	else
#		echo "--Notify Only for Installed Apps"
#	fi
#else
#	echo "--Notifications"
#	echo "--Notify Only for Installed Apps"
#fi
#echo "-----"
#if $uaudio ; then
#	echo "--Update Sound | checked=true"
#	if $iaudio ; then
#		echo "--Sound Only for Installed Apps | checked=true"
#	else
#		echo "--Sound Only for Installed Apps"
#	fi
#else
#	echo "--Play Sound on Updates"
#fi
###
echo "-----"
if $highlightclis ; then
	echo "--Highlight Command-Line Utilities | checked=true refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=highlightCLIs param4=-bool param5=FALSE param6=\"2>/dev/null\""
else
	echo "--Highlight Command-Line Utilities | refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=highlightCLIs param4=-bool param5=TRUE param6=\"2>/dev/null\""
fi
echo "--Favorite Command-Line Utilities"
echo "----MacUpdate Menu Defaults (v$currentdefaultsv) | image=\"$terminalicon\" size=11"
echo "-------"
while read -r mumdefault
do
	echo "----$mumdefault | $monofont"
done < <(echo "$currentdefaults")
echo "-------"
echo "----User Favorites | image=\"$terminalicon\" size=11"
echo "-------"
if ! [[ $currentuser ]] ; then
	echo "----[none] | $monofont"
else
	while read -r cltool
	do
		echo "----$cltool | $monofont"
	done < <(echo "$currentuser")
fi
echo "-------"
echo "----Open User Favorites in Editor… | terminal=false bash=/usr/bin/open param1=\"$userloc\""
echo "----Clear User Favorites | alternate=true refresh=true terminal=false bash=/bin/mv param1=-f param2=\"$userloc\" param3=\"$HOMEDIR/.Trash\" param4=2>/dev/null"
echo "----Online List… | href=\"$mucomcliurl\""
echo "-----"
echo "--$defaultdldir_short | size=11"
echo "--Change Downloads Folder | refresh=true terminal=false bash=\"${0}\" param1=changedownloadspath param2=\"$defaultdldir\""
echo "-----"
if $slowwake ; then
	echo "--Delay After Wake | checked=true refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=slowWake param4=-bool param5=FALSE param6=\"2>/dev/null\""
else
	echo "--Delay After Wake | refresh=true terminal=false bash=/usr/bin/defaults param1=write param2=\"$procid\" param3=slowWake param4=-bool param5=TRUE param6=\"2>/dev/null\""
fi
echo "-----"
echo "--Reset | refresh=true terminal=false bash=\"${0}\" param1=reset"
echo "--Open Preferences File… | alternate=true terminal=false bash=/usr/bin/open param1=\"$prefsloc\""

# MUM submenu
echo "MacUpdate Menu"
echo "--$myname v$version$vmisc b$build"
echo "--Open Plug-in in Editor… | alternate=true terminal=false bash=/usr/bin/open param1=\"$mypath\""
if $linkfound ; then
	oloc_short="${oloc/#$HOMEDIR/~}"
	if $github ; then
		echo "--$oloc_short (repo) | size=11"
	else
		echo "--$oloc_short (link) | size=11"
	fi
fi
echo "-----"
echo "--Disable MacUpdate Menu | refresh=true terminal=false bash=\"${0}\" param1=disable"
echo "-----"
echo "--Uninstall MacUpdate Menu | terminal=false bash=\"${0}\" param1=disable param2=uninstall"
echo "-----"
echo "--License Information | terminal=false bash=\"${0}\" param1=license"
echo "--About MacUpdate Menu | terminal=false bash=\"${0}\" param1=about"
echo "-----"
echo "--MacUpdate Menu on GitHub | size=11"
echo "--Repository… | href=\"$mucomurl\""
echo "--Releases… | href=\"$mucomrelurl\""
echo "--Issues… | href=\"$mucomissues\""
echo "-----"
echo "--Help | image=\"$helpicon\"" ###
# echo "--Help | image=\"$helpicon\" terminal=false bash=/usr/bin/open param1=-a param2=HelpViewer param3=\"$helploc\"" ###

# MU submenu
echo "---"
echo "MacUpdate"
echo "--List of Updated Applications | href=\"https://www.macupdate.com/fresh-mac-apps/updated=all\""
echo "--Explore Categories | href=\"https://www.macupdate.com/explore/categories/\""
echo "--Submit Application | href=\"https://www.macupdate.com/content/submit\""
echo "-----"
echo "--MacUpdate Homepage | href=\"https://www.macupdate.com\""
echo "--Blog | href=\"https://www.macupdate.com/blog\""
echo "--Support | href=\"https://support.macupdate.com/support/home\""
echo "--About MacUpdate | href=\"https://www.macupdate.com/about\""
echo "-----"
echo "--MacUpdate on Twitter | href=\"http://twitter.com/macupdate\""
echo "--MacUpdate on Facebook | href=\"http://facebook.com/macupdate\""
echo "-----"
echo "--MacUpdate Personal Account | size=11"
echo "--Login | href=\"https://www.macupdate.com/member/login\""
echo "-----"
echo "--Profile | href=\"https://www.macupdate.com/member/account-overview\""
echo "--Purchases | href=\"https://www.macupdate.com/member/account-purchases\""
echo "--Watch Lists | href=\"https://www.macupdate.com/member/account-watchlist\""
echo "--Downloads | href=\"https://www.macupdate.com/member/account-downloads\""
echo "--Preferences | href=\"https://www.macupdate.com/member/account-preferences\""
echo "-----"
echo "--Developer | href=\"https://www.macupdate.com/member/account-developer\""
echo "-----"
echo "--Logout | href=\"https://deals.macupdate.com/logout\""
echo "-----"
echo "--Applications | size=11"
echo "--MacUpdate Desktop… | image=\"$mudicon\" href=\"https://www.macupdate.com/app/mac/8544/macupdate-desktop\""
echo "--MUMenu… | image=\"$mumenuicon\" href=\"https://www.macupdate.com/app/mac/8277/mumenu\""
echo "-----"
echo "--Clario Tech… | href=\"https://clario.co\""

# screen sleep
if [[ $(ioreg -c AppleBacklightDisplay | grep "brightness" | awk -F"\"dsyp\"=" '{print $NF}' | awk -F"}," '{print $1}' | awk -F"=" '{print $NF}') == "0" ]] ; then
	exit
fi

# screen saver
if ps aux | grep "[sS]creenSaverEngine" | grep -v "grep" &>/dev/null ; then
	exit
fi

# do not disturb
if [[ $(defaults -currentHost read ~/Library/Preferences/ByHost/com.apple.notificationcenterui doNotDisturb 2>/dev/null) == "1" ]] ; then
	exit
fi

# final routines to notify & play sounds
if $mucom_outdated && $mucom_outdated_or ; then
	mucom_outdated=false
fi

if ! $ccmu_present ; then
	mur_outdated=false
else
	if $mur_outdated && $mur_outdated_or ; then
		mur_outdated=false
	fi
fi

# audio
audio_or=false
if pmset -g 2>/dev/null | awk -F"(" '/^ sleep/{print $NF}' | grep -q "coreaudiod" &>/dev/null ; then
	audio_or=true
fi

# frontmost app in fullscreen mode
notify_or=false
if [[ $(osascript 2>/dev/null <<EOF
tell application "System Events"
	set frontAppName to name of first process whose frontmost is true
	tell process frontAppName
		get value of attribute "AXFullScreen" of window 1
	end tell
end tell
result as text
EOF
) == "true" ]] ; then
	notify_or=true
fi

beeped=false
if $updates ; then
	if $iupdates ; then
		if $uaudio || $iaudio ; then
			_appbeep &
			beeped=true
		fi
		if $unotify || $inotify ; then
			datestring=$(echo "$fetchdate" | sed 's/\ on\ /\ \|\ /')
			_notify "ℹ️ Updates are available!" "$datestring"
		fi
	else
		if $uaudio && ! $iaudio ; then
			_appbeep &
			beeped=true
		fi
		if $unotify && ! $inotify ; then
			datestring=$(echo "$fetchdate" | sed 's/\ on\ /\ \|/\ ')
			_notify "ℹ️ New software released" "$datestring"
		fi
	fi
	if $mur_outdated ; then
		if ! $audio_or ; then
			! $beeped && _appbeep &
			beeped=true
		fi
		if ! $notify_or ; then
			_notify "ℹ️ New update available!" "CoreCode MacUpdater v$mur_newv"
		fi
	fi
	if $mucom_outdated ; then
		if ! $audio_or ; then
			! $beeped && _appbeep &
		fi
		if ! $notify_or ; then
			_notify "ℹ️ New update available!" "MacUpdate Menu v$mucom_newv beta $mucom_newbeta b$mucom_newbuild"
		fi
	fi
fi

exit
