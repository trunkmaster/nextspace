Source: 11. Jan. 2000. Tomi Engel (http://www.objectfarm.org/Activities/Publications/TheMerger/OpenstepConfusion.html)

OpenStep Confusion
==================

    When people talk about Apple, Mac OS 7.6, the Macintosh or System 7.6 it is usually quite simple to understand what they mean. In most cases they just refer to the systems which run Mac OS or a certain kind of operating system release.

    Understanding the issues behind the words "Openstep" or "Nextstep" is quite tricky and people who are not familiar with them are bound to get confused. In contrast to the Mac world, naming in the NeXT world is highly "case sensitive" and small variations can make a big difference.

History
-------

    While the company "NeXT" has always been spelled with a lowercase "e", to make the logo look better and to make the name more recognizable in print, the names of the product changed quite often. Here is a detailed history as Garance A. Drosehn and we understand it.

**NextStep**

    ... has never been used as a spelling as far as we can tell. But the all lowercase "Next" portion can be found in default filesystem locations such as: NextApps, NextLibrary, etc. These folder names have lasted until 1997 ... no matter how NeXT called their operating system.

**NeXTstep**

    ... "originally" was the name of the GUI and API parts (without the operating system). This was back in the days when IBM was going to port those parts to run on AIX. So the name "NeXTstep" was used to indicate what parts of the system IBM was getting.

**NeXTStep**

    ... was used for the whole system (GUI, Apps, MachOS, etc.) and sometimes even referred to the hardware (e.g. "I use a NeXTStep machine"). The first release was in 1988, with version 2.0 following in 1990 and another major leap in 1993 when release 3.0 went public.

**NeXTSTEP**

    ... defined the entire software package (since release 3.1 in late 1993) and became popular as the system got ported to Intel hardware. It now no longer included the hardware and maybe they figured that the all caps "STEP" would be less problematic to the press which seldom got the spelling right anyway. But the lower "e" still kept the company visible. The product was sold as NeXTSTEP (for the original NeXT hardware) and NeXTSTEP/Intel.

**NEXTSTEP**

    ... was either the attempt to get away from the "NeXT hardware" association, since it no longer had the lower case "e", or they just got tired of giving reasons for the weird spelling. During that time NeXT also was on the transition to morph from "NeXT Computer Inc" to "NeXT Software Inc".

    NEXTSTEP was still based on Mach, but now sold as NEXTSTEP/NeXT Computers (black), NEXTSTEP/Intel (white), NEXTSTEP/PA-RISC (green) and NEXTSTEP/SPARC (yellow). The colors where a shortcut which sometimes have been used in the community.

**OpenStep**

    ... was born as part of the deal with Sun. OpenStep stands for an API specifications which was based on an evolution of the existing NEXTSTEP APIs. Most of the new technology already was available inside NeXT's labs but needed a renewed system to get integrated. OpenStep does not refer to any "real" implementation. It stands for the abstract API definitions which a vendor has to support in order to call his system "OpenStep compliant". OpenStep consists of the AppKit, FoundationKit and the Display PostScript layer.

**OPENSTEP**

    ... is NeXT's specific implementation of the OpenStep specification, and basically represents NEXTSTEP 4.0. This was yet another marketing move to get rid of the old name. OPENSTEP is a dual personality which still provides the NEXTSTEP compatibility libraries to run applications which are based on the old APIs. Additionally it has the new OpenStep compliant frameworks. The look & feel remained the same, and so users hardly can tell the difference between both worlds.
    The full naming is OPENSTEP for MachOS/[NeXT Computers, Intel, SPARC].

**OpenStep for Solaris**

    ... is what Sun calls their implementation of the OpenStep standard. While based on source code which Sun bought from NeXT, this package runs on the Solaris operating system and uses the X Window system. This makes it considerable different from NeXTs implementation of the OpenStep specification. Still both companies managed to provide a very high level of source code portability (not compiled binaries!).

**OPENSTEP for Windows**

    ... stands for a package, developed by NeXT, which puts OPENSTEP functionality on top of Windows NT. Obviously it does not include the MachOS layer but being derived from "OPENSTEP for MachOS" frameworks it offers considerably more then the OpenStep specification requires.

Whatever they mean
------------------

    While this already is quite confusing to outsiders, there are many situations where even insiders get stuck once they start mixing phrases. Many people still use their personal favorite spelling for whatever the latest release is. So if someone today says "NeXTstep" he usually refers to "OPENSTEP for MachOS". But when they talk about "NeXTstep" apps they sometimes really could mean "Apps written for NeXTstep APIs ... not the OpenStep APIs"

    Sometimes you hear "OpenStep/Solaris" when in fact "OPENSTEP for MachOS/SPARC" was meant. And you are in a real dilemma when some editor writes: "OpenStep/SPARC".

    The most dangerous confusion can happen with "OpenStep" and "OPENSTEP" since they are definitely not the same (OPENSTEP APIs are a superset of OpenStep APIs). You should check twice whether people talk about a product (OPENSTEP) or the features described in the specification (OpenStep).

    In many postings, magazines and articles you will find incorrect spellings and sometimes not even the context can make things clear. Our site will stick to the naming as listed above and you should especially be careful when we talk about "OpenStep" and "OPENSTEP".
