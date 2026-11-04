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
# MD380 vocoder integration

`Sources/MD380Codec/FEC.c` derives from the supplied `md380_vocoder` source by Doug McLain AD8DP (2020–2021), based on travisgoodspeed/md380tools. Original GPL-2.0-or-later notices are retained. Changes on 2026-10-26 separate pure 49/72-bit framing from native firmware calls and make tables file-local. The decoding mapping retains the original library's behavior; it does not add independent channel-error correction.

The new emulator adapter calls the firmware entry points documented by that source. Firmware images are fetched for local use from the HTTPS equivalent of the original Makefile URLs on www.dudetronics.com, hash-checked and stored outside the repository. The firmware is not claimed to be covered by the wrapper's GPL notice and is not included in the app or repository.

Unicorn 2.1.4: https://github.com/unicorn-engine/unicorn/tree/2.1.4 . Unmodified API headers are in `Sources/MD380Codec/vendor/unicorn/`; COPYING and COPYING.LGPL2 are retained alongside them. The engine binary is obtained from the pinned official PyPI package during local setup and dynamically loaded. Its license files are copied into the local app resources. This experiment has not published the engine/firmware as a new downloadable release.


De lokale Fusion↔MD380-adapter gebruikt eveneens de 49-bits DVSI-permutatie uit DroidStar `ysf.cpp` (Doug McLain / AD8DP, GPL-3.0-or-later), in `Sources/FusionLab/Models/AMBE49BitOrder.swift`. De bestaande YSF-bridge gebruikt DVSI-volgorde; deze adapter zet die uitsluitend voor de lokale MD380-vocoder om naar de oorspronkelijke AMBE-parametervolgorde en terug.


## NXDN transport and host directory

`NXDNPackets.swift` and `script/generate_nxdn_vectors.py` implement the NXDNReflector transport using DroidStar `nxdn.cpp` as the framing, SACCH CRC6 and AMBE49 bit-order reference (Copyright 2019–2021 Doug McLain AD8DP, GPL-3.0-or-later; https://github.com/nostar/DroidStar/blob/main/nxdn.cpp, consulted 2026-10-29). The generated fixed fixtures are independent of the Swift implementation. The existing DVSI/native permutation is shared with YSF.

The 17-byte poll/unlink and 43-byte voice transport were also checked against G4KLX `NXDNClients/NXDNGateway/NXDNNetwork.cpp` (Jonathan Naylor, GPL-2.0-or-later) and `nostar/DVReflectors/NXDNReflector/NXDNReflector.cpp` (Jonathan Naylor, GPL-2.0-or-later). No new upstream C++ source is included for NXDN.

The NXDN directory is downloaded on user request from https://www.pistar.uk/downloads/NXDN_Hosts.txt. Its original file and attribution are retained in the local cache: reflector data provided by DVRef, https://dvref.com/aup/, sourced from https://dvref.com/api/v2/nxdn/reflectors/. It is separate from the application source. Three factual endpoint records (204, 205, 711) verified against that export on 2026-10-29 form the initial offline list; the complete directory is not bundled.


NXDN callsign display (0.6.1) uses the separate public RadioID NXDN export, https://radioid.net/static/nxdn.csv (endpoint verified 2026-10-29). The app fetches it on demand and retains only ID/callsign pairs in a local cache, with daily refresh and failure backoff. Other CSV columns are discarded. No directory export is bundled or added to the repository.
