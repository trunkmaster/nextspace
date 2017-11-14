Source: [GNUstep Wiki](http://wiki.gnustep.org/index.php/Nfont_packages)

# Nfonts packages

The Arts backend manages fonts using so-called nfonts. Nfonts are hand-crafted directories with a plist file and the font files, where the backend can find additional information to the fonts. System-wide available Nfont directories are usually installed to $GNUSTEP_SYSTEM_ROOT/Library/Fonts/.

Creating a nfont is mainly a trivial task, so there are tools to help you creating them. One of them is alexm's mknfonts package.

## Example

A typical nfont folder - in this case Arial.nfont packaged by Jeff Teunissen (Deek) - looks like this:

    Arial.nfont/
    Arial.nfont/ariali.ttf
    Arial.nfont/arial.ttf
    Arial.nfont/arialbi.ttf
    Arial.nfont/arialbd.ttf
    Arial.nfont/FontInfo.plist
    Arial.nfont/arialblk.ttf

This is the FontInfo.plist file in that directory:

    {
      Description = "Monotype Arial, WGL4 Character Set";
      Faces = (
        {
           Files = (arial.ttf);
           LocalizedNames = {
             Basque = Arrunta;
             Catalan = Normal;
             Danish = normal;
             Dutch = Standaard;
             English = Regular;
             Finnish = Normaali;
             French = Normal;
             Germany = Standard;
             Hungarian = "Norm\u00e1l";
             Italian = Normale;
             Norwegian = Normal;
             Polish = Normalne;
             Portuguese = Normal;
             Slovak = "Norm\u00e1lne";
             Slovene = Navadno;
             Spanish = Normal;
             Swedish = Normal;
             Turkish = Normal;
          };
          Name = Regular;
          PostScriptName = ArialMT;
          RenderHints_hack = 0x0002;
          Traits = 0;
          Weight = 5;
        },
        {
           Files = (ariali.ttf);
           LocalizedNames = {
             English = Italic;
           };
           Name = Italic;
           PostScriptName = "Arial-ItalicMT";
           RenderHints_hack = 0x0002;
           Traits = 1;
           Weight = 5;
        },
        {
          Files = (arialbd.ttf);
          LocalizedNames = {
            English = Bold;
          };
          Name = Bold;
          PostScriptName = "Arial-BoldMT";
          RenderHints_hack = 0x0002;
          Traits = 2;
          Weight = 9;
        },
        {
          Files = (arialbi.ttf);
          LocalizedNames = {
            English = "Bold Italic";
          };
          Name = "Bold Italic";
          PostScriptName = "Arial-BoldItalicMT";
          RenderHints_hack = 0x0002;
          Traits = 3;
          Weight = 9;
        },
        {
          Files = (arialblk.ttf);
          LocalizedNames = {
            English = Black;
          };
          Name = Black;
          PostScriptName = "Arial-Black";
          RenderHints_hack = 0x0002;
          Traits = 2;
          Weight = 12;
        }
      );
      FontCopyright = "Typeface \u00a9 The Monotype Corporation plc.\nData \u00a9 The Monotype Corporation plc/Type Solutions Inc. 1990-1992.\nAll Rights Reserved";
      Foundry = "Monotype Typography";
      Packager = "Jeff Teunissen <deek@d2dc.net>";
      Version = 2.82;
  }

## Rendering Hints

There's a hack for encoding rendering hints into Nfonts packages. You provide them using the RenderHints_hack value. It's a 24-bit value (usually given in hexadecimal form), where the highest-order byte contains information on if we want to use antialiasing by default and the two following bytes contain hinting information for antialiased displays and non-antialiased displays.

<-- high-order bits                       low-order bits -->
[  0 0 0 0 0 0 0 D  |  0 0 0 0 0 0 A A  | 0 0 0 0 0 0 N N  ]
                 |                 \ /                \ /
      antialiasing switch           |                  |
                            hinting type           hinting type
                     on antialiased displays    on non-antialiased displays


The rendering hint types are as follows:

    '0' - unhinted, use only the font geometry
    '1' - use FreeType's auto-hinter
    '2' - use instructions in the font, if present
    '3' - force automatic hinting


## Rendering Hint example

Let's say we have a RenderHints_hack value of 0x010203. This would then mean "use antialiasing, on antialiased displays use instructions in the font and on unantialiased displays force automatic hinting".
