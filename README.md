# MacUpdate Menu

**BitBar plugin for macOS to display the latest MacUpdate releases**

**MacUpdate Menu** is the reenvisoned revenant of the **MUMenu** native menu bar application for macOS, originally developed in 2002 by Unsanity LLC, and later bought by MacUpdate LLC, who in 2020 were acquired by Clario Tech Ltd. Like eosgarden's **[UpdateMenu](https://eosgarden.com/en/freeware/update-menu/download/)**, MUMenu has been abandoned for many years—it was last updated in 2012: while still **[available for download](https://www.macupdate.com/app/mac/8277/mumenu)**, it will not work anymore on newer versions of macOS. Clario Tech promote the use of **[MacUpdate Desktop](https://www.macupdate.com/app/mac/8544/macupdate-desktop)** instead. However, that software is missing the simple, yet very specific MUMenu functionality—and also the occasional excitement of discovering a great new application—, so I created this substitute. Feel free to install it, if you like!

**MacUpdate Menu** is a Z shell script plug-in that can only be properly executed in Mat Ryer's **[BitBar](https://github.com/matryer/bitbar)** application. It is a specialized browser for Clario's **[MacUpdate](https://www.macupdate.com)** website that resides in your macOS menu bar: it will display a parsed, reformatted, and human-readable output of the continuous public appcast of new software updates, which is also available in your standard web browser at **[this URL](https://www.macupdate.com/fresh-mac-apps/updated=all)**. To tweak **MacUpdate Menu**'s settings and learn more about its functionality, please refer to the included help. (*Note*: the HelpViewer bundle will be added later.)

You can write comments or report issues in the **[Issues section](https://github.com/JayBrown/MacUpdate-Menu/issues)**. *Please note* that as long as BitBar is only available as a beta version, **MacUpdate Menu** itself will remain in beta status as well.

![grab](https://raw.githubusercontent.com/JayBrown/MacUpdate-Menu/master/img/MUM_screengrab.png)

## Connections
If you are using a reverse firewall like Objective Development's **[Little Snitch](https://obdev.at/products/littlesnitch/index.html)** or **[Patrick Wardle](https://github.com/objective-see)**'s freeware **[LuLu](https://github.com/objective-see/LuLu)**, please allow MacUpdate Menu (via BitBar) to use the `cURL` program to remotely connect to the following domains:
* `corecode.io`
* `github.com`
* `githubusercontent.com`
* `macupdate.com`

## macOS Accessibility
Please allow BitBar to control your Mac using the macOS Accessibility features. This is necessary for MacUpdate Menu to determine, whether the frontmost application is running in fullscreen mode, in order to allow or deny update notifications using the macOS Notification Center.

For your information: the AppleScript routine used for this case is as follows:
```
tell application "System Events"
	set frontAppName to name of first process whose frontmost is true
	tell process frontAppName
		get value of attribute "AXFullScreen" of window 1
	end tell
end tell
result as text
```

## Disclaimers

**MacUpdate Menu** contains promotion for and facilitates the use of Clario's MacUpdate website. We are neither affiliated with nor have we received any contributions by Clario Tech Ltd., financial or otherwise.

**MacUpdate Menu** contains promotion for CoreCode's **[MacUpdater](https://corecode.io/macupdater/index.html)**, and facilitates the use of its associated website **[MacUpdater.net](https://macupdater.net)**. We are neither affiliated with nor have we received any contributions by CoreCode Ltd., financial or otherwise.

### Limited Liability

By using **MacUpdate Menu**, and in accordance with the **[MIT license](https://github.com/JayBrown/MacUpdate-Menu/blob/master/LICENSE)** that governs it, and to the fullest extent permissible under German law, you hereby agree and acknowledge that we, Joss Brown (pseud.), their affiliates, successors, assignees, and associated persons of any and all kinds, are in no event responsible or liable for any harm or issues, technical or otherwise, that you might sustain or encounter through the use of **MacUpdate Menu**, that you might sustain or encounter on the web pages or sites linked therein, or that you might sustain or encounter with files you download or install from or via these web pages or sites. You hereby agree to hold us harmless from and against any and all resulting losses, damages, costs, and expenses (including reasonable attorney fees).
