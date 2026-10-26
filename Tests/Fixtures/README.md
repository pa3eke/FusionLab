# DroidStar TX-referentiepakketten

`DroidStarTX.json` is op 24 oktober 2026 gegenereerd met de ongewijzigde functies `encode_header`, `encode_dv2`, `writeDataFRModeData1`, `writeDataFRModeData2`, `writeVDMode2Data`, `generate_vch_vd2` en `ysf_scramble` uit DroidStar `ysf.cpp`, commit `becf1dede57c4a70a865e9cb4cac9247e505599a` (GPL-3.0-or-later, Doug McLain).

De functies werden in een lokale C++-harness zonder Qt uitgevoerd, met call `PA3EKE`, hardware-AMBE aan, Fusion V/D2 en de oorspronkelijke FICH/CRC/convolutiecode. De vijf pakketten zijn start, spraak FN0, spraak FN1, telleromslag (sequence 128) en einde (sequence 3). De 35 invoerbytes zijn `(i*37+11)&255`, met alleen het hoogste bit behouden op iedere zevende byte. Geen netwerkverkeer is hiervoor verstuurd.

De app-test vergelijkt complete 155-byte-pakketten hiermee, zodat een gedeelde fout in onze encoder en decoder niet ongemerkt door een rondgangtest kan komen. De radiogegevens voor FN6 zijn bewust neutraal in FusionLab, in plaats van een FT-70D-identificatie over te nemen; daarvoor is geen gelijkheidsvector opgenomen.


## DMR / BrandMeister (0.4.0)

`DroidStarDMR.json` bevat tien volledige 55-byte Homebrew-zendpakketten: LC-header, acht spraakpakketten (inclusief alle zes superframeposities en terugloop) en LC-terminator. Bron: ongewijzigde functies uit `nostar/DroidStar/dmr.cpp`, opgehaald 25 oktober 2026 en voor reproduceerbaarheid bewaard als `Reference-DroidStar-dmr.cpp.txt` met oorspronkelijke GPL-auteursvermelding.

De referentiegenerator compileert de oorspronkelijke `build_frame` en payloadfuncties buiten Qt, met de ongewijzigde FEC-bronnen. De productie-adapter DMRBridge.cpp en de Swift-headerbouw worden niet door deze generator gebruikt. De FEC-algoritmen delen wel dezelfde oorspronkelijke DroidStar/MMDVM-bron; deze vectors zijn dus geen onafhankelijke validatie van de DMR-specificatie zelf.

Instellingen: source 2040001, peer 204000101 (SSID 01), bestemming 9990 privé, TS2, CC1, stream 0x12345678. Synthetische AMBE-bytes `(i*37+11)&255`, drie blokken van negen bytes per spraakpakket. De IDs worden uitsluitend lokaal in tests gebruikt; de generator opent geen netwerkverbinding.

Opnieuw genereren: `python3 script/generate_dmr_vectors.py Tests/Fixtures/Reference-DroidStar-dmr.cpp.txt`. Hiervoor is clang++ nodig.

SHA-256 oorspronkelijke dmr.cpp: `9d3ccd284ac2c66bae136da4298228c7e94023b41c3b0c3834d1cd070624ce65`.
