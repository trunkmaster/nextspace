/*
 * Definiowanie Menu Głównego dla WindowMakera
 * Fonty w standardzie ISO8895-2
 *
 * Składnia jest następująca:
 *
 * <Tytuł> [SHORTCUT <Skrut>] <Komenda> <Paramery>
 *
 * <Tytuł> Tytuł może być dowolnym ciągiem znaków. Jeśli będą w nim występować
 *         spacje umieśc go w cudzysłowie np. "Tytuł ze spacją"
 * 
 * SHORTCUT Definiowanie skrótu.
 * <Skrót> Nazwa rodzaju skrótu umieszczonego w pliku
 *         $HOME/GNUstep/Defaults/WindowMaker, tak jak RootMenuKey 
 *         lub MiniaturizeKey.
 *
 * Skróty mogą występować w sekcji MENU lub OPEN_MENU .
 * 
 * <Komenda> jedna z dostępnych komend: 
 *	MENU - rozpoczęcie definicji (pod)menu 
 *	END  - zakończenie definicji (pod)menu 
 *	OPEN_MENU - generowanie podmenu na podstawie podanego katalogu,
 *              umieszczając w nim pliki wykonywalne i podkatalogi.
 *	WORKSPACE_MENU - Dodanie podmenu zawierającego aktywne pulpity. Tylko
 *		             jedno workspace_menu jest potrzebne. 		
 *	EXEC <program> - wykonanie jakiegokolwiek programu
 *	EXIT - wyjście z menadżera okien
 *	RESTART [<window manager>] - restart WindowMakera albo start innego
 *			                     manadżera okien
 *	REFRESH - odświerzenie ekranu
 *	ARRANGE_ICONS - uporządkowanie ikon na pulpicie
 *	SHUTDOWN - zabicie wszystkich procesów (i wyjście z X window)
 *	SHOW_ALL - pokazanie wszystkich ukrytych programów
 *  HIDE_OTHERS - schowanie aktywnych okien pulpitu, oprócz aktywnego
 *  SAVE_SESSION - zapamietanie aktualnego stanu desktpou, z wszystkimi
 *                 uruchomionymi programami, i z wszystkimi ich stanami
 *                 geometrycznymi, pozycji na ekranie, umieszczone na
 *                 odpowiednim pulpicie, ukryte lub uaktywnione.
 *                 Wszystkie te ustawiemia bedą aktywne, dopóki nie
 *                 zostaną użyte komendy SAVE_SESSION i CLEAR_SESSION.
 *                 Jeżeli SaveSessionOnExit = Yes; w pliku konfiguracyjnym
 *                 WindowMakera, wtedy zapamiętywanie wszystkich ustawień
 *                 jest dokonywanie po każdym wyjściu, niezależnie od
 *                 komend SAVE_SESSION czy CLEAR_SESSION .
 *  CLEAR_SESSION - Czyszczenie poprzednio zapamiętanych sesji. Nie ponosi to
 *                  żadnych zmian w pliku SaveSessionOnExit .
 *  INFO - Wyświetlenie informacji o WindowMakerze
 *
 * <Parametry> zalezne od uruchamianego programu.
 *
 * ** Opcje w lini komend EXEC:
 * %s - znak jest zastepowany przez text znajdujacy sie w ,,schowku''
 * %a(tytuł[,komunikat]) - otwiera dodatkowe okno o tytule tytuł, komunikacie
 *                         komunikat i czeka na podanie parametrów, które 
 *                         zostaną wstawione zamiast %a. Niestety nie udalo mi
 *                         się uzyskać polskich fontów w tej pocji :( 
 * %w - znak jest zastepowany przez XID aktywnego okna
 * %W - znak jest zastepowany przez numer aktywnego pulpitu
 * 
 * Aby używać specjalnych znaków ( takich jak % czy " ) należy poprzedzic je znakiem \
 * np. :xterm -T "\"Witaj Świecie\""
 *
 * Można używac znaków specjalnych, takich jak \n
 *
 * Sekcja MENU musi być zakończona sekcja END, pod tą sama nazwą.
 *
 * Przykład:
 *
 * "Test" MENU
 *  "XTerm" EXEC xterm
 *      // stworzenie podmenu z plikami w podkatalogu /usr/openwin/bin
 *  "XView apps" OPEN_MENU "/usr/openwin/bin"
 *      // umieszcza w jednym podmenu pliki z róznych podkatalogów
 *  "X11 apps" OPEN_MENU /usr/X11/bin $HOME/bin/X11
 *      // ustawienie tła
 *  "Background" OPEN_MENU -noext $HOME/images /usr/share/images WITH wmsetbg -u *      // wstawienie menu z pliku style.menu
 *      // wstawienie menu z pliku style.menu
 *  "Style" OPEN_MENU style.menu
 * "Test" END
 *
 * Jeżeli zamiast polskich fontów są jakieś krzaczki należy wyedetować pliki
 * $HOME/GNUstep/Defaults/WMGLOBAL i $HOME/GNUstep/Defaults/WindowMaker,  
 * lub wejść w menu Konfiguracja.
 * Aby uzyskać polskie znaki należy uzupełnić definicje fontów.
 * np. zamienić
 *
 * SystemFont = "-*-helvetica-medium-r-normal-*-%d-100-*-*-*-*-*-*";
 *
 * na
 *
 * SystemFont = "-*-helvetica-medium-r-normal-*-%d-100-*-*-*-*-iso8859-2";
 *
 * i wszędzie tam gdzie występuje podobna definicja.
 */
                  

#include "wmmacros"
#define ULUB_EDYTOR vi 
/* Jeśli nie lubisz edytora vi zmień na swój ulubiony edytor */
#define ULUB_TERM xterm
/* A tutaj ustaw swój ulubiony terminal */

"WindowMaker" MENU
	"Informacja" MENU
		"Informacja o WMaker..." INFO_PANEL
		"Legalność..."           LEGAL_PANEL
		"Konsola Systemu"        EXEC xconsole
		"Obciążenie Systemu"     EXEC xosview || xload
		"Lista Procesów"         EXEC ULUB_TERM -T "Lista Procesów" -e top
		"Przeglądarka Manuali"   EXEC xman
	"Informacja" END
	
	"Konfiguracja" MENU	
		"Edycja menu"       EXEC ULUB_TERM -T "Edycja menu" -e ULUB_EDYTOR $HOME/GNUstep/Library/WindowMaker/menu
		"Ustawienie fontów" EXEC ULUB_TERM -T "Ustawienie fontów" -e ULUB_EDYTOR $HOME/GNUstep/Defaults/WMGLOBAL
		"Konfiguracja"      EXEC ULUB_TERM -T "Konfiguracja" -e ULUB_EDYTOR $HOME/GNUstep/Defaults/WindowMaker
	"Konfiguracja" END
	
	"Uruchom..." EXEC %a(Uruchom,Wpisz komende do uruchomienia:)
	"Terminal"   EXEC ULUB_TERM -T "Mój ulubiony terminal" -sb 
	"Edytor"     EXEC ULUB_TERM -T "Moj ulubiony edytor" -e ULUB_EDYTOR %a(Edytor,Podaj plik do edycji:)
	"Pulpity"    WORKSPACE_MENU
	
	"Aplikacje" MENU
		"Grafika" MENU
			"Gimp"        EXEC gimp >/dev/null
			"XV"          EXEC xv
			"XFig"        EXEC xfig
			"XPaint"      EXEC xpaint
			"Gnuplot"     EXEC ULUB_TERM -T "GNU plot" -e gnuplot
			"Edytor ikon" EXEC bitmap
		"Grafika" END
		"Tekst" MENU
			"LyX"                 EXEC lyx
  			"Ghostview"           EXEC gv %a(GhostView,Wprowadz nazwe pliku *.ps *.pdf *.no:)
  			"XDvi"                EXEC xdvi %a(XDvi,Wprowadz nazwe pliku *.dvi:)
			"Acrobat"             EXEC /usr/local/Acrobat3/bin/acroread %a(Acrobat,Wprowadz nazwe pliku *.pdf:)
			"Xpdf"                EXEC xpdf %a(Xpdf,Wprowadz nazwe pliku *.pdf:)
			"Arkusz kalkulacyjny" EXEC xspread
		"Tekst" END
		"X File Manager"     EXEC xfm
		"OffiX Files"        EXEC files
		"TkDesk"             EXEC tkdesk
		"Midnight Commander" EXEC ULUB_TERM -T "Midnight Commander" -e mc
		"X Gnu debbuger"     EXEC xxgdb
		"Xwpe"               EXEC xwpe
	"Aplikacje" END
	
	"Internet" MENU
		"Przeglądarki" MENU
			"Netscape" EXEC netscape 
			"Arena"    EXEC arena
			"Lynx"     EXEC ULUB_TERM -e lynx %a(Lynx,Podaj URL:)
		"Przeglądarki" END
		"Programy pocztowe" MENU
			"Pine" EXEC ULUB_TERM -T "Program pocztowy Pine" -e pine 
			"Elm"  EXEC ULUB_TERM -T "Program pocztowy Elm" -e elm
			"Xmh"  EXEC xmh
		"Programy pocztowe" END
		"Emulator terminala" MENU
			"Minicom" EXEC xminicom
			"Seyon"   EXEC seyon
		"Emulator terminala" END
		"Telnet"     EXEC ULUB_TERM -e telnet %a(Telnet,Podaj nazwe hosta:)
		"Ssh"        EXEC ULUB_TERM -e ssh %a(Ssh,Podaj nazwe hosta:)
		"Ftp"        EXEC ULUB_TERM -e ftp %a(Ftp,Podaj nazwe hosta:)
		"Irc"        EXEC ULUB_TERM -e irc %a(Irc,Podaj swoj pseudonim:)
		"Ping"       EXEC ULUB_TERM -e ping %a(Ping,Podaj nazwe hosta:)
		"Talk"       EXEC ULUB_TERM -e talk %a(Talk,Podaj nazwe uzytkownika, z ktorym chcesz nawiazac polaczenie:)
	"Internet" END

	"Editory" MENU
		"XFte"    EXEC xfte
		"XEmacs"  EXEC xemacs || emacs
		"XJed"    EXEC xjed 
		"NEdit"   EXEC nedit
		"Xedit"   EXEC xedit
		"Editres" EXEC editres
		"VI"      EXEC ULUB_TERM -e vi
	"Editory" END
	
	"Dźwięk" MENU
		"CDPlay"  EXEC workbone
		"Xmcd"    EXEC xmcd 2> /dev/null
		"Xplaycd" EXEC xplaycd
		"Xmixer"  EXEC xmixer
	"Dźwięk" END
	
    "Gry" MENU
    	"Maze"      EXEC maze
    	"Karty "    EXEC spider
    	"Londownik" EXEC xlander
    	"Szachy "   EXEC xboard
    	"Xeyes"     EXEC xeyes -geometry 51x23
    	"Xmahjongg" EXEC xmahjongg
    	"Xlogo"     EXEC xlogo
    	"Xroach"    EXEC xroach
    	"Xtetris"   EXEC xtetris -color
    	"Xvier"     EXEC xvier
    	"Xgas"      EXEC xgas
    	"Xkobo"     EXEC xkobo
    	"xboing"    EXEC xboing -sound
    	"XBill"     EXEC xbill
    "Gry" END
	
	"Użytki" MENU
		"Kalkulator"          EXEC xcalc
		"Zegarek"             EXEC xclock
		"Opcje Okna"          EXEC xprop | xmessage -center -title 'xprop' -file -
		"Przeglądarka Fontów" EXEC xfontsel
		"Szkło Powiększające" EXEC xmag
		"Mapa Kolorów"        EXEC xcmap
		"XKill"               EXEC xkill
		"Clipboard"           EXEC xclipboard
	"Użytki" END

	"Selekcyjne" MENU
		"Kopia"                  EXEC echo '%s' | wxcopy
		"Poczta do ..."          EXEC ULUB_TERM -name mail -T "Pine" -e pine %s
		"Serfuj do ..."          EXEC netscape %s
		"Pobierz Manual ..."     EXEC MANUAL_SEARCH(%s)
		"Połącz się z ..."       EXEC telnet %s
		"Pobierz plik z FTP ..." EXEC ftp %s
	"Selekcyjne" END

	"Ekran" MENU
		"Ukryj Pozostałe"         HIDE_OTHERS
		"Pokaż wszystko"          SHOW_ALL
		"Uporządkowanie icon"     ARRANGE_ICONS
		"Odswież"                 REFRESH
		"Zablokuj"                EXEC xlock -allowroot -usefirst
		"Zachowaj Sesje"          SAVE_SESSION
		"Wyczyść zachowaną sesje" CLEAR_SESSION
	"Ekran" END

	"Wygląd" MENU
		"Tematy"          OPEN_MENU -noext THEMES_DIR $HOME/GNUstep/Library/WindowMaker/Themes WITH setstyle
		"Style"           OPEN_MENU -noext STYLES_DIR $HOME/GNUstep/Library/WindowMaker/Styles WITH setstyle
		"Ustawienia ikon" OPEN_MENU -noext ICON_SETS_DIR $HOME/GNUstep/Library/WindowMaker/IconSets WITH seticons
		"Tło" MENU
			"Jednolite" MENU
               	"Czarny"            WS_BACK '(solid, black)'
               	"Niebieski"         WS_BACK '(solid, "#505075")'
				"Indigo"            WS_BACK '(solid, "#243e6c")'
				"Głęboko Niebieski" WS_BACK '(solid, "#224477")'
               	"Fioletowy"         WS_BACK '(solid, "#554466")'
               	"Pszeniczny"        WS_BACK '(solid, "wheat4")'
               	"Ciemno Szary"      WS_BACK '(solid, "#333340")'
               	"Winny"             WS_BACK '(solid, "#400020")'
			"Jednolite" END
			"Cieniowane" MENU
				"Zachód Słońca"         WS_BACK '(mvgradient, deepskyblue4, black, deepskyblue4, tomato4)'
				"Niebo"                 WS_BACK '(vgradient, blue4, white)'
    			"Cieniowany Niebieski"  WS_BACK '(vgradient, "#7080a5", "#101020")'
				"Cieniowane Indigo"     WS_BACK '(vgradient, "#746ebc", "#242e4c")'
			   	"Cieniowany Fioletowy"  WS_BACK '(vgradient, "#654c66", "#151426")'
    			"Cieniowany Pszeniczny" WS_BACK '(vgradient, "#a09060", "#302010")'
    			"Cieniowany Szary"      WS_BACK '(vgradient, "#636380", "#131318")'
    			"Cieniowany Winnny"     WS_BACK '(vgradient, "#600040", "#180010")'
			"Cieniowane" END
			"Obrazki" OPEN_MENU -noext BACKGROUNDS_DIR $HOME/GNUstep/Library/WindowMaker/Backgrounds WITH wmsetbg -u -t
		"Tło" END
		"Zaoamiętanie Tematu"        EXEC getstyle -t $HOME/GNUstep/Library/WindowMaker/Themes/"%a(Nazwa tematu,Wpisz nazwe pliku:)"
		"Zapamiętanie Ustawień Ikon" EXEC geticonset $HOME/GNUstep/Library/WindowMaker/IconSets/"%a(Ustawienia ikon,wpisz nazwe pliku:)"
	"Wygląd" END

	"Wyjście" MENU
		"Przeładowanie"    RESTART
		"Start BlackBox"   RESTART blackbox
		"Start kwm"        RESTART kwm
		"Start IceWM"      RESTART icewm
		"Wyjście..."       EXIT
		"Zabicie sesji..." SHUTDOWN
	"Wyjście" END
"WindowMaker" END
