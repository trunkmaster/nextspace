/*
 * Hoofdmenu-uitwerking voor WindowMaker
 *
 * Opmaak is:
 *
 * <Titel> [SHORTCUT <Sneltoets>] <Commando> <Parameters>
 *
 * <Titel> is elke tekenreeks te gebruiken als titel. Moet tussen " staan als het
 * 	spaties heeft.
 * 
 * SHORTCUT geeft een sneltoets op voor die ingang. <Sneltoets> heeft
 * dezelfde opmaak als de sneltoetsopties in het
 * $HOME/GNUstep/Defaults/WindowMaker bestand, zoals RootMenuKey of MiniaturizeKey.
 *
 * U kunt geen sneltoets opgeven voor een MENU- of OPEN_MENU-onderdeel.
 * 
 * <Commando> een van de geldige commando's: 
 *	MENU - begint (sub)menubepaling
 *	END  - beëindigt (sub)menubepaling
 *	OPEN_MENU - opent een menu uit een bestand, 'pipe' of map(pen)inhoud,
 *		    en gaat eventueel elk vooraf met een commando.
 *	WORKSPACE_MENU - voegt een submenu voor werkruimtehandelingen toe. Slechts één
 *		    workspace_menu is toegestaan. 		
 *	EXEC <programma> - voert een extern programma uit
 *	SHEXEC <commando> - voert een 'shell'-commando uit (zoals gimp > /dev/null)
 *	EXIT - sluit de vensterbeheerder af
 *	RESTART [<vensterbeheerder>] - herstart WindowMaker, of start een andere
 *			vensterbeheerder
 *	REFRESH - vernieuwt het bureaublad
 *	ARRANGE_ICONS - herschikt de iconen in de werkruimte
 *	SHUTDOWN - doodt alle cliënten (en sluit de X Window-sessie af)
 *	SHOW_ALL - plaatst alle vensters in de werkruimte terug
 *	HIDE_OTHERS - verbergt alle vensters in de werkruimte, behalve die
 *		focus heeft (of de laatste die focus had)
 *	SAVE_SESSION - slaat de huidige staat van het bureaublad op, inbegrepen
 *		       alle lopende programma's, al hun 'hints' (afmetingen,
 *		       positie op het scherm, werkruimte waarin ze leven, Dok
 *		       of Clip van waaruit ze werden opgestart, en indien
 *		       geminiaturiseerd, opgerold of verborgen). Slaat tevens de actuele
 *		       werkruimte van de gebruiker op. Alles zal worden hersteld bij elke
 *		       start van windowmaker, tot een andere SAVE_SESSION of
 *		       CLEAR_SESSION wordt gebruikt. Als SaveSessionOnExit = Yes; in
 *		       het WindowMaker-domeinbestand, dan wordt opslaan automatisch
 *		       gedaan bij elke windowmaker-afsluiting, en wordt een
 *		       SAVE_SESSION of CLEAR_SESSION overschreven (zie hierna).
 *	CLEAR_SESSION - wist een eerder opgeslagen sessie. Dit zal geen
 *		       effect hebben als SaveSessionOnExit is True.
 *	INFO - toont het Infopaneel
 *
 * OPEN_MENU-opmaak:
 *   1. Menuafhandeling uit bestand.
 *	// opent bestand.menu, dat een geldig menubestand moet bevatten, en voegt
 *	// het in op de huidige plaats
 *	OPEN_MENU bestand.menu
 *   2. Menuafhandeling uit pipe.
 *	// opent commando en gebruikt zeen 'stdout' om een menu aan te maken.
 *	// Commando-output moet een geldige menubeschrijving zijn.
 *	// De ruimte tussen '|' en het commando zelf is optioneel.
 *      // Gebruik '||' in plaats van '|' als u het menu altijd wilt bijwerken
 *	// bij openen. Dat zou traag kunnen werken.
 *	OPEN_MENU | commando
 *      OPEN_MENU || commando
 *   3. Mapafhandeling.
 *	// Opent een of meer mappen en maakt een menu aan, met daarin alle
 *	// submappen en uitvoerbare bestanden alfabetisch
 *	// gesorteerd.
 *	OPEN_MENU /een/map [/een/andere/map ...]
 *   4. Mapafhandeling met commando.
 *	// Opent een of meer mappen en maakt een menu aan, met daarin alle
 *	// submappen en leesbare bestanden alfabetisch gesorteerd,
 *	// elk van hen voorafgegaan met commando.
 *	OPEN_MENU [opties] /een/map [/een/andere/map ...] WITH commando -opties
 *		Opties:
 * 			-noext 	haal alles vanaf de laatste punt in de
 *				bestandsnaam eraf
 *
 * <Parameters> is het uit te voeren programma.
 *
 * ** Commandoregelopties in EXEC:
 * %s - wordt vervangen door de actuele selectie
 * %a(titel[,aanwijzing]) - opent een invoerveld met de opgegeven titel en de
 *			optionele aanwijzing, en wordt vervangen door wat u intypt
 * %w - wordt vervangen door XID voor het actuele gefocust venster
 * %W - wordt vervangen door het nummer van de actuele werkruimte
 * 
 * U kunt speciale karakters (zoals % en ") uitschakelen met het \-teken:
 * vb.: xterm -T "\"Hallo Wereld\""
 *
 * U kunt ook ontsnappingstekens gebruiken, zoals \n
 *
 * Elke MENU-declaratie moet één gekoppelde END-declaratie op het eind hebben.
 *
 * Voorbeeld:
 *
 * "Test" MENU
 *	"XTerm" EXEC xterm
 *		// maakt een submenu met de inhoud van /usr/openwin/bin aan
 *	"XView-progr" OPEN_MENU "/usr/openwin/bin"
 *		// enige X11-programma's in verschillende mappen
 *	"X11-progr" OPEN_MENU /usr/X11/bin $HOME/bin/X11
 *		// enige achtergrondafbeeldingen instellen
 *	"Achtergrond" OPEN_MENU -noext $HOME/afbeeldingen /usr/share/images WITH wmsetbg -u -t
 *		// voegt het style.menu in met dit onderdeel
 *	"Stijl" OPEN_MENU style.menu
 * "Test" END
 */

#include "wmmacros"

"Programma's" MENU
	"Ynfo" MENU
		"Ynfopaniel" INFO_PANEL
		"Juridyske ynfo" LEGAL_PANEL
		"Systeemconsole" EXEC xconsole
		"Systeembelêsting" SHEXEC xosview || xload
		"Proseslist" EXEC xterm -e top
		"Hantliedingbrowser" EXEC xman
	"Ynfo" END
	"Utfiere..." SHEXEC %a(Utfiere,Typ út te fiere kommando:)
	"XTerm" EXEC xterm -sb 
	"Mozilla Firefox" EXEC firefox
	"Wurkromten" WORKSPACE_MENU
	"Programma's" MENU
		"Gimp" SHEXEC gimp >/dev/null
  		"Ghostview" EXEC ghostview %a(GhostView,Fier te besjen bestân yn)
		"Xpdf" EXEC xpdf %a(Xpdf,Fier te besjen PDF yn)
		"Abiword" EXEC abiword
		"Dia" EXEC dia
		"OpenOffice.org" MENU
			"OpenOffice.org" EXEC ooffice
			"Writer" EXEC oowriter
			"Rekkenblêd" EXEC oocalc
			"Draw" EXEC oodraw
			"Impress" EXEC ooimpress
		"OpenOffice.org" END 

		"Tekstbewurkers" MENU
			"XEmacs" EXEC xemacs
			"Emacs" EXEC emacs
			"XJed" EXEC xjed 
			"VI" EXEC xterm -e vi
			"GVIM" EXEC gvim
			"NEdit" EXEC nedit
			"Xedit" EXEC xedit
		"Tekstbewurkers" END

		"Multymedia" MENU
			"XMMS" MENU
				"XMMS" EXEC xmms
				"XMMS ôfspylje/poazje" EXEC xmms -t
				"XMMS stopje" EXEC xmms -s
			"XMMS" END
			"Xine fideospeler" EXEC xine
			"MPlayer" EXEC mplayer
		"Multymedia" END
	"Programma's" END

	"Helpmiddels" MENU
		"Rekkenmasine" EXEC xcalc
		"Finstereigenskippen" SHEXEC xprop | xmessage -center -title 'xprop' -file -
		"Lettertypekiezer" EXEC xfontsel
		"Fergrutsje" EXEC wmagnify
		"Kleurekaart" EXEC xcmap
		"X-programma deadzje" EXEC xkill
	"Helpmiddels" END

	"Seleksje" MENU
		"Kopiearje" SHEXEC echo '%s' | wxcopy
		"E-maile nei" EXEC xterm -name mail -T "Pine" -e pine %s
		"Navigearje" EXEC netscape %s
		"Sykje yn hantlieding" SHEXEC MANUAL_SEARCH(%s)
	"Seleksje" END

	"Kommando's" MENU
		"Oare ferbergje" HIDE_OTHERS
		"Alles toane" SHOW_ALL
		"Ikoanen skikke" ARRANGE_ICONS
		"Fernije" REFRESH
		"Ofskoattelje" EXEC xlock -allowroot -usefirst
	"Kommando's" END

	"Uterlik" MENU
		"Tema's" OPEN_MENU -noext THEMES_DIR $HOME/GNUstep/Library/WindowMaker/Themes WITH setstyle
		"Stilen" OPEN_MENU -noext STYLES_DIR $HOME/GNUstep/Library/WindowMaker/Styles WITH setstyle
		"Ikoanensets" OPEN_MENU -noext ICON_SETS_DIR $HOME/GNUstep/Library/WindowMaker/IconSets WITH seticons
		"Eftergrûn" MENU
			"Effen" MENU
				"Swart" WS_BACK '(solid, black)'
				"Blau"  WS_BACK '(solid, "#505075")'
				"Indigo" WS_BACK '(solid, "#243e6c")'
				"Marineblau" WS_BACK '(solid, "#224477")'
				"Poarper" WS_BACK '(solid, "#554466")'
				"Weet"  WS_BACK '(solid, "wheat4")'
				"Donkergriis"  WS_BACK '(solid, "#333340")'
				"Wynread" WS_BACK '(solid, "#400020")'
				"Effen" END
			"Kleurferrin" MENU
				"Sinneûndergong" WS_BACK '(mvgradient, deepskyblue4, black, deepskyblue4, tomato4)'
				"Loft" WS_BACK '(vgradient, blue4, white)'
    			"Blautinten" WS_BACK '(vgradient, "#7080a5", "#101020")'
				"Indigotinten" WS_BACK '(vgradient, "#746ebc", "#242e4c")'
			    "Poarpertinten" WS_BACK '(vgradient, "#654c66", "#151426")'
    			"Weettinten" WS_BACK '(vgradient, "#a09060", "#302010")'
    			"Griistinten" WS_BACK '(vgradient, "#636380", "#131318")'
    			"Wynreadtinten" WS_BACK '(vgradient, "#600040", "#180010")'
			"Kleurferrin" END
			"Ofbyldingen" OPEN_MENU -noext BACKGROUNDS_DIR $HOME/GNUstep/Library/WindowMaker/Backgrounds WITH wmsetbg -u -t
		"Eftergrûn" END
		"Tema bewarje" SHEXEC getstyle -t $HOME/GNUstep/Library/WindowMaker/Themes/"%a(Temanamme,Fier bestânsnamme yn:)"
		"Iconenset bewarje" SHEXEC geticonset $HOME/GNUstep/Library/WindowMaker/IconSets/"%a(Ikoanensetnamme,Fier bestânsnamme yn:)"
		"Foarkarrenhelpmiddel" EXEC /usr/local/GNUstep/Applications/WPrefs.app/WPrefs
	"Uterlik" END

	"Sesje" MENU
		"Sesje bewarje" SAVE_SESSION
		"Sesje wiskje" CLEAR_SESSION
		"Window Maker werstarte" RESTART
		"BlackBox starte" RESTART blackbox
		"IceWM starte" RESTART icewm
		"Ofslute"  EXIT
	"Sesje" END
"Programma's" END


