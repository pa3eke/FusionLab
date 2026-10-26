# Bronvermelding

FusionLab is GPL-3.0-or-later. De nieuwe Swift-code en de C-interface zijn voor dit testproject geschreven. Er is geen gedecompileerde BlueDV-code opgenomen.

De bestanden `Sources/YSFCodec/{YSFFICH,YSFConvolution,Golay24128,CRCenc}.{cpp,h}` komen ongewijzigd uit [DroidStar](https://github.com/nostar/DroidStar), commit `becf1dede57c4a70a865e9cb4cac9247e505599a` (geraadpleegd 24 oktober 2026). Hun oorspronkelijke copyright- en GPL-2.0-or-later-vermeldingen staan in de bestanden.

De V/D2-transformatie en constanten in `Bridge.cpp` zijn aangepast uit DroidStar `ysf.cpp`, Copyright (C) 2019–2021 Doug McLain, GPL-3.0-or-later. De volledige GPL versie 3 staat in `LICENSE`.

YSF-foutcorrectie: Jonathan Naylor G4KLX, Andy Uribe CA6JAU en overige auteurs vermeld in de bronbestanden. Deze code bevat geen softwarevocoder: de externe AMBEserver verzorgt de spraakdecodering.


## YSF reflector directory data

`Sources/FusionLab/Resources/YSFHosts.txt` is the unmodified Pi-Star host-file export retrieved 2026-10-24 from https://www.pistar.uk/downloads/YSF_Hosts.txt. It identifies its source as https://dvref.com/api/v2/ysf/reflectors/ and retains the attribution: “Reflector data provided by DVRef - https://dvref.com/aup/”. This directory data is separate from the GPL application source; the original attribution and data-provider terms remain applicable.


## DMR payload / error-correction code

The DMR functions in `Sources/YSFCodec/DMRBridge.cpp` are adapted from nostar/DroidStar `dmr.cpp`, Copyright (C) 2019–2021 Doug McLain, GPL-3.0-or-later. The surrounding Swift Homebrew handshake/audio integration is FusionLab code.

The following files are unmodified copies from https://github.com/nostar/DroidStar (retrieved 2026-10-25): `cbptc19696.cpp/.h`, `chamming.cpp/.h`, `cgolay2087.cpp/.h`, `crs129.cpp/.h`, and `DMRDefines.h`. Their original copyright notices (Ian Wraith / Jonathan Naylor G4KLX) and GPL-2.0-or-later notices are retained. This is compatible with the project's GPL-3.0-or-later distribution. `CRCenc.cpp/.h` was already present for YSF and is also used by DMR.

A retained original `dmr.cpp` snapshot under Tests/Fixtures documents the source of the DMR reference vectors; see the fixture README for provenance and reproduction. No BlueDV proprietary source or binary is included.
