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
	"Info" MENU
		"Infopaneel" INFO_PANEL
		"Juridische info" LEGAL_PANEL
		"Systeemconsole" EXEC xconsole
		"Systeembelasting" SHEXEC xosview || xload
		"Proceslijst" EXEC xterm -e top
		"Handleidingbrowser" EXEC xman
	"Info" END
	"Uitvoeren..." SHEXEC %a(Uitvoeren,Typ uit te voeren commando:)
	"XTerm" EXEC xterm -sb 
	"Mozilla Firefox" EXEC firefox
	"Werkruimten" WORKSPACE_MENU
	"Programma's" MENU
		"Gimp" SHEXEC gimp >/dev/null
  		"Ghostview" EXEC ghostview %a(GhostView,Voer te bekijken bestand in)
		"Xpdf" EXEC xpdf %a(Xpdf,Voer te bekijken PDF in)
		"Abiword" EXEC abiword
		"Dia" EXEC dia
		"OpenOffice.org" MENU
			"OpenOffice.org" EXEC ooffice
			"Writer" EXEC oowriter
			"Rekenblad" EXEC oocalc
			"Draw" EXEC oodraw
			"Impress" EXEC ooimpress
		"OpenOffice.org" END 

		"Tekstbewerkers" MENU
			"XEmacs" EXEC xemacs
			"Emacs" EXEC emacs
			"XJed" EXEC xjed 
			"VI" EXEC xterm -e vi
			"GVIM" EXEC gvim
			"NEdit" EXEC nedit
			"Xedit" EXEC xedit
		"Tekstbewerkers" END

		"Multimedia" MENU
			"XMMS" MENU
				"XMMS" EXEC xmms
				"XMMS afspelen/pauzeren" EXEC xmms -t
				"XMMS stoppen" EXEC xmms -s
			"XMMS" END
			"Xine videospeler" EXEC xine
			"MPlayer" EXEC mplayer
		"Multimedia" END
	"Programma's" END

	"Hulpmiddelen" MENU
		"Rekenmachine" EXEC xcalc
		"Venstereigenschappen" SHEXEC xprop | xmessage -center -title 'xprop' -file -
		"Lettertypekiezer" EXEC xfontsel
		"Vergroten" EXEC wmagnify
		"Kleurenkaart" EXEC xcmap
		"X-programma doden" EXEC xkill
	"Hulpmiddelen" END

	"Selectie" MENU
		"Kopiëren" SHEXEC echo '%s' | wxcopy
		"E-mailen naar" EXEC xterm -name mail -T "Pine" -e pine %s
		"Navigeren" EXEC netscape %s
		"Zoeken in handleiding" SHEXEC MANUAL_SEARCH(%s)
	"Selectie" END

	"Commando's" MENU
		"Andere verbergen" HIDE_OTHERS
		"Alles tonen" SHOW_ALL
		"Iconen schikken" ARRANGE_ICONS
		"Vernieuwen" REFRESH
		"Vergrendelen" EXEC xlock -allowroot -usefirst
	"Commando's" END

	"Uiterlijk" MENU
		"Thema's" OPEN_MENU -noext THEMES_DIR $HOME/GNUstep/Library/WindowMaker/Themes WITH setstyle
		"Stijlen" OPEN_MENU -noext STYLES_DIR $HOME/GNUstep/Library/WindowMaker/Styles WITH setstyle
		"Iconensets" OPEN_MENU -noext ICON_SETS_DIR $HOME/GNUstep/Library/WindowMaker/IconSets WITH seticons
		"Achtergrond" MENU
			"Effen" MENU
				"Zwart" WS_BACK '(solid, black)'
				"Blauw"  WS_BACK '(solid, "#505075")'
				"Indigo" WS_BACK '(solid, "#243e6c")'
				"Marineblauw" WS_BACK '(solid, "#224477")'
				"Purper" WS_BACK '(solid, "#554466")'
				"Tarwe"  WS_BACK '(solid, "wheat4")'
				"Donkergrijs"  WS_BACK '(solid, "#333340")'
				"Wijnrood" WS_BACK '(solid, "#400020")'
				"Effen" END
			"Kleurverloop" MENU
				"Zonsondergang" WS_BACK '(mvgradient, deepskyblue4, black, deepskyblue4, tomato4)'
				"Lucht" WS_BACK '(vgradient, blue4, white)'
    			"Blauwtinten" WS_BACK '(vgradient, "#7080a5", "#101020")'
				"Indigotinten" WS_BACK '(vgradient, "#746ebc", "#242e4c")'
			    "Purpertinten" WS_BACK '(vgradient, "#654c66", "#151426")'
    			"Tarwetinten" WS_BACK '(vgradient, "#a09060", "#302010")'
    			"Grijstinten" WS_BACK '(vgradient, "#636380", "#131318")'
    			"Wijnroodtinten" WS_BACK '(vgradient, "#600040", "#180010")'
			"Kleurverloop" END
			"Afbeeldingen" OPEN_MENU -noext BACKGROUNDS_DIR $HOME/GNUstep/Library/WindowMaker/Backgrounds WITH wmsetbg -u -t
		"Achtergrond" END
		"Thema opslaan" SHEXEC getstyle -t $HOME/GNUstep/Library/WindowMaker/Themes/"%a(Themanaam,Voer bestandsnaam in:)"
		"Iconenset opslaan" SHEXEC geticonset $HOME/GNUstep/Library/WindowMaker/IconSets/"%a(Iconensetnaam,Voer bestandsnaam in:)"
		"Voorkeurenhulpmiddel" EXEC /usr/local/GNUstep/Applications/WPrefs.app/WPrefs
	"Uiterlijk" END

	"Sessie" MENU
		"Sessie opslaan" SAVE_SESSION
		"Sessie wissen" CLEAR_SESSION
		"Window Maker herstarten" RESTART
		"BlackBox starten" RESTART blackbox
		"IceWM starten" RESTART icewm
		"Afsluiten"  EXIT
	"Sessie" END
"Programma's" END


