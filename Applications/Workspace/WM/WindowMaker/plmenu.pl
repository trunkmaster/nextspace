("WindowMaker",
	("Informacja",
		("Informacja o WMaker...", INFO_PANEL),
		("Legalność...",           LEGAL_PANEL),
		("Konsola Systemu",        EXEC, "xconsole"),
		("Obciążenie Systemu",     EXEC, "xosview || xload"),
		("Lista Procesów",         EXEC, "xterm -T 'Lista Procesów' -e top"),
		("Przeglądarka Manuali",   EXEC, "xman")
	),
	
	("Konfiguracja",	
		("Edycja menu",       EXEC, "xterm -T 'Edycja menu' -e vi $HOME/GNUstep/Library/WindowMaker/menu"),
		("Ustawienie fontów", EXEC, "xterm -T 'Ustawienie fontów' -e vi $HOME/GNUstep/Defaults/WMGLOBAL"),
		("Konfiguracja",      EXEC, "xterm -T 'Konfiguracja' -e vi $HOME/GNUstep/Defaults/WindowMaker")
	),
	
	("Uruchom...", EXEC, "%a(Uruchom,Wpisz komende do uruchomienia:)"),
	("Terminal",   EXEC, "xterm -T 'Mój ulubiony terminal' -sb"),
	("Edytor",     EXEC, "xterm -T 'Moj ulubiony edytor' -e vi %a(Edytor,Podaj plik do edycji:)"),
	("Pulpity",    WORKSPACE_MENU),
	
	("Aplikacje",
		("Grafika",
			("Gimp",        EXEC, "gimp > /dev/null"),
			("XV",          EXEC, "xv"),
			("XFig",        EXEC, "xfig"),
			("XPaint",      EXEC, "xpaint"),
			("Gnuplot",     EXEC, "xterm -T 'GNU plot' -e gnuplot"),
			("Edytor ikon", EXEC, "bitmap")
		),
		("Tekst",
			("LyX",                 EXEC, "lyx"),
  			("Ghostview",           EXEC, "gv %a(Gv,Wprowadz nazwe pliku *.ps *.pdf *.no:)"),
  			("XDvi",                EXEC, "xdvi %a(Xdvi,Wprowadz nazwe pliku *.dvi:)"),
			("Acrobat",             EXEC, "/usr/local/Acrobat3/bin/acroread %a(Acrobat,Wprowadz nazwe pliku *.pdf:)"),
			("Xpdf",                EXEC, "xpdf %a(Xpdf,Wprowadz nazwe pliku *.pdf:)"),
			("Arkusz kalkulacyjny", EXEC, "xspread")
		),
		("X File Manager",     EXEC, "xfm"),
		("OffiX Files",        EXEC, "files"),
		("TkDesk",             EXEC, "tkdesk"),
		("Midnight Commander", EXEC, "xterm -T 'Midnight Commander' -e mc"),
		("X Gnu debbuger",     EXEC, "xxgdb"),
		("Xwpe",               EXEC, "xwpe")
	),
	
	("Internet",
		("Przeglądarki",
			("Netscape", EXEC, "netscape"), 
			("Arena",    EXEC, "arena"),
			("Lynx",     EXEC, "xterm -e lynx %a(Lynx,Podaj URL:)")
		),
		("Programy pocztowe",
			("Pine", EXEC, "xterm -T 'Program pocztowy Pine' -e pine"),
			("Elm",  EXEC, "xterm -T 'Program pocztowy Elm' -e elm"),
			("Xmh",  EXEC, "xmh")
		),
		("Emulator terminala",
			("Minicom", EXEC, "xminicom"),
			("Seyon",   EXEC, "seyon")
		),
		("Telnet",     EXEC, "xterm -e telnet %a(Telnet,Podaj nazwe hosta:)"),
		("Ssh",        EXEC, "xterm -e ssh %a(SSH,Podaj nazwe hosta:)"),
		("Ftp",        EXEC, "xterm -e ftp %a(FTP,Podaj nazwe hosta:)"),
		("Irc",        EXEC, "xterm -e irc %a(IRC,Podaj swoj pseudonim:)"),
		("Ping",       EXEC, "xterm -e ping %a(Ping,Podaj nazwe hosta:)"),
		("Talk",       EXEC, "xterm -e talk %a(Talk,Podaj nazwe uzytkownika, z ktorym chcesz nawiazac polaczenie:)")
	),

	("Editory",
		("XFte",    EXEC, "xfte"),
		("XEmacs",  EXEC, "xemacs || emacs"),
		("XJed",    EXEC, "xjed "),
		("NEdit",   EXEC, "nedit"),
		("Xedit",   EXEC, "xedit"),
		("Editres", EXEC, "editres"),
		("VI",      EXEC, "xterm -e vi")
	),
	
	("Dźwięk",
		("Xmcd",    EXEC, "xmcd 2> /dev/null"),
		("Xplaycd", EXEC, "xplaycd"),
		("Xmixer",  EXEC, "xmixer")
	),
	
    ("Gry",
    	("Maze",      EXEC, "maze"),
    	("Karty",     EXEC, "spider"),
    	("Londownik", EXEC, "xlander"),
    	("Szachy",    EXEC, "xboard"),
    	("Xeyes",     EXEC, "xeyes -geometry 51x23"),
    	("Xmahjongg", EXEC, "xmahjongg"),
    	("Xlogo",     EXEC, "xlogo"),
    	("Xroach",    EXEC, "xroach"),
    	("Xtetris",   EXEC, "xtetris -color"),
    	("Xvier",     EXEC, "xvier"),
    	("Xgas",      EXEC, "xgas"),
    	("Xkobo",     EXEC, "xkobo"),
    	("xboing",    EXEC, "xboing -sound"),
    	("XBill",     EXEC, "xbill")
    ),
	
	("Użytki",
		("Kalkulator",          EXEC, "xcalc"),
		("Zegarek",             EXEC, "xclock"),
		("Opcje Okna",          EXEC, "xprop | xmessage -center -title 'xprop' -file -"),
		("Przeglądarka Fontów", EXEC, "xfontsel"),
		("Szkło Powiększające", EXEC, "xmag"),
		("Mapa Kolorów",        EXEC, "xcmap"),
		("XKill",               EXEC, "xkill"),
		("Clipboard",           EXEC, "xclipboard")
	),

	("Selekcyjne",
		("Kopia",                  EXEC, "echo '%s' | wxcopy"),
		("Poczta do ...",          EXEC, "xterm -name mail -T 'Pine' -e pine %s"),
		("Serfuj do ...",          EXEC, "netscape %s"),
		("Pobierz Manual ...",     EXEC, "MANUAL_SEARCH(%s)"),
		("Połącz się z ...",       EXEC, "telnet %s"),
		("Pobierz plik z FTP ...", EXEC, "ftp %s")
	),

	("Ekran",
		("Ukryj Pozostałe",         HIDE_OTHERS),
		("Pokaż wszystko",          SHOW_ALL),
		("Uporządkowanie icon",     ARRANGE_ICONS),
		("Odswież",                 REFRESH),
		("Zablokuj",                EXEC, "xlock -allowroot -usefirst"),
		("Zachowaj Sesje",          SAVE_SESSION),
		("Wyczyść zachowaną sesje", CLEAR_SESSION)
	),

	("Wygląd",
		("Tematy",          OPEN_MENU, "-noext #wmdatadir#/Themes $HOME/GNUstep/Library/WindowMaker/Themes WITH setstyle"),
		("Style",           OPEN_MENU, "-noext #wmdatadir#/Styles $HOME/GNUstep/Library/WindowMaker/Styles WITH setstyle"),
		("Ustawienia ikon", OPEN_MENU, "-noext #wmdatadir#/IconSets $HOME/GNUstep/Library/WindowMaker/IconSets WITH seticons"),
		("Tło",
			("Jednolite",
               	("Czarny",            EXEC, "wdwrite WindowMaker WorkspaceBack '(solid, black)'"),
               	("Niebieski",         EXEC, "wdwrite WindowMaker WorkspaceBack '(solid, '#505075')'"),
				("Indigo",            EXEC, "wdwrite WindowMaker WorkspaceBack '(solid, '#243e6c')'"),
				("Głęboko Niebieski", EXEC, "wdwrite WindowMaker WorkspaceBack '(solid, '#224477')'"),
               	("Fioletowy",         EXEC, "wdwrite WindowMaker WorkspaceBack '(solid, '#554466')'"),
               	("Pszeniczny",        EXEC, "wdwrite WindowMaker WorkspaceBack '(solid, 'wheat4')'"),
               	("Ciemno Szary",      EXEC, "wdwrite WindowMaker WorkspaceBack '(solid, '#333340')'"),
               	("Winny",             EXEC, "wdwrite WindowMaker WorkspaceBack '(solid, '#400020')'")
			),
			("Cieniowane",
				("Zachód Słońca",         EXEC, "wdwrite WindowMaker WorkspaceBack '(mvgradient, deepskyblue4, black, deepskyblue4, tomato4)'"),
				("Niebo",                 EXEC, "wdwrite WindowMaker WorkspaceBack '(vgradient, blue4, white)'"),
    			("Cieniowany Niebieski",  EXEC, "wdwrite WindowMaker WorkspaceBack '(vgradient, '#7080a5', '#101020')'"),
				("Cieniowane Indigo",     EXEC, "wdwrite WindowMaker WorkspaceBack '(vgradient, '#746ebc', '#242e4c')'"),
			   	("Cieniowany Fioletowy",  EXEC, "wdwrite WindowMaker WorkspaceBack '(vgradient, '#654c66', '#151426')'"),
    			("Cieniowany Pszeniczny", EXEC, "wdwrite WindowMaker WorkspaceBack '(vgradient, '#a09060', '#302010')'"),
    			("Cieniowany Szary",      EXEC, "wdwrite WindowMaker WorkspaceBack '(vgradient, '#636380', '#131318')'"),
    			("Cieniowany Winnny",     EXEC, "wdwrite WindowMaker WorkspaceBack '(vgradient, '#600040', '#180010')'")
			),
			("Obrazki", OPEN_MENU, "-noext #wmdatadir#/Backgrounds $HOME/GNUstep/Library/WindowMaker/Backgrounds WITH wmsetbg -u -t)")
		),
		("Zaoamiętanie Tematu",        EXEC, "getstyle -t $HOME/GNUstep/Library/WindowMaker/Themes/'%a(Nazwa tematu,Wpisz nazwe pliku:)'"),
		("Zapamiętanie Ustawień Ikon", EXEC, "geticonset $HOME/GNUstep/Library/WindowMaker/IconSets/'%a(Ustawienia ikon,Wpisz nazwe pliku:)'")
	),

	("Wyjście",
		("Przeładowanie",    RESTART),
		("Start BlackBox",   RESTART, blackbox),
		("Start kwm",        RESTART, kwm),
		("Start IceWM",      RESTART, icewm),
		("Wyjście...",       EXIT),
		("Zabicie sesji...", SHUTDOWN)
	)
)
