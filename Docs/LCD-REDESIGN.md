# LCD-redesign — FusionLab 0.7.1 (build 39)

Het centrale stationsdisplay volgt het aangeleverde transceiverontwerp: een lichtblauw LCD met donkerblauwe technische systeemletters en een subtiele verdiepte zwarte rand. De eigen FusionLab-naam blijft behouden.

De herbruikbare `RadioLCDView` gebruikt een alleen-lezen `RadioLCDPresentation` van bestaande sessievelden. DMR toont call, DMR-ID, TS, CC, ontvangen TG/privébestemming, BrandMeister en RX/TX/stand-by/verbindingsstatus. NXDN gebruikt dezelfde indeling met NXDN-ID en RAN. C4FM toont call en YSF-reflector; er verschijnt geen leeg numeriek ID-vak. Onbekende calls tonen het beschikbare ID apart. QRZ-links blijven beschikbaar voor bekende calls. Tijdens TX staat de eigen call met het eigen ID in beeld. Verbindingsfouten blijven zichtbaar met de volledige tekst als tooltip.

De meter gebruikt de bestaande genormaliseerde RMS-waarde: `20 × log10(level)`. Stilte en niet-eindige waarden tonen −∞ dBFS. Veertig segmenten bestrijken −60 tot 0 dBFS; waarden buiten de schaal worden alleen voor de segmenten begrensd. Er is geen S-meter, dBm of nieuwe audiobewerking. De LCD-basis blijft ook tijdens TX lichtblauw, met een kleine amber/rode TX-indicatie.

Het standaardvenster blijft 1120 × 740 punten, minimum 940 × 640. Het LCD heeft een vaste hoogte van 232 punten en schaalt horizontaal; compactere typografie geldt onder 680 punten displaybreedte. Op een laag venster blijft de bestaande verticale scroll beschikbaar. Het display gebruikt echte SwiftUI-tekst, links en segmenten, geen bitmapachtergrond met vaste informatie.

## Gewijzigde bestanden in deze opdracht

- `Sources/FusionLab/Views/RadioLCDView.swift`: nieuwe presentatie, kleuren en herbruikbaar LCD.
- `Sources/FusionLab/Views/ReceiverDisplayView.swift`: koppeling aan bestaande sessiegegevens en beperkte view-updates.
- `Sources/FusionLab/Views/ConsolePanel.swift`: donkere paneel- en knopkleuren.
- `Sources/FusionLab/Views/ContentView.swift`: achtergrondkleur, compacte tussenruimte en versietekst.
- `script/build_and_run.sh`: versie 0.7.1 / build 39.
- `Tests/FusionLabTests/RadioLCDTests.swift`, `ProtocolTests.swift`, `script/test.sh`: presentatie-, audiometerschaal- en native rendertests.
- `script/console_performance_probe.swift`: offline consolevoorbeelden op drie venstergroottes en drie modi; USB en globale PTT-registratie uitgeschakeld in de probe.
- `README.md`, `VERIFICATION.md`, dit document: beschrijving en verificatie.

Een lokale herstelkopie van de vooraf bestaande GUI, testregistratie en builddocumentatie staat in `.local-backups/before-lcd-20261030-124530/`. De werkboom had al wijzigingen; er is niets gereset of gepubliceerd.

Protocol-, vocoder-, AMBEserver-, audio-, PTT-, toetsenbord- en X-keys-code zijn voor deze opdracht niet gewijzigd. D-STAR blijft gedimd en P25 is niet toegevoegd: alleen reeds aanwezige modi worden weergegeven. Nieuwe radioprotocolfuncties vallen buiten dit ontwerp.

## Controles

- Volledige `./script/test.sh`: geslaagd, inclusief lokale DMR/C4FM/NXDN RX/TX, beide vocoders, PTT, timers en X-keys.
- Nieuwe presentatietest: bekende/onbekende call en ID, eigen call/ID tijdens TX, actuele ontvangen TG versus volgende TX-bestemming, QRZ, losgekoppeld en fouttekst, alle drie modi.
- Audiometerschaal: −20 dBFS bij RMS 0,1; 0 dBFS bij RMS 1; stilte/NaN/∞ veilig; 40 segmenten begrensd op de schaal.
- Native LCD-renders op 617, 797 en 1177 punten breedte en TX-kleur; de basis blijft lichtblauw.
- Volledige console gerenderd op 1120 × 740, 940 × 640 en 1500 × 950. Call/ID, lange C4FM-call, reflector en meter blijven leesbaar. Op de standaardmaat past de statusbalk; de minimummaat gebruikt verticale scroll voor de onderste bediening.
- GUI-stressproef: 120 geforceerde updates in 4,705 s, proces-CPU 1,958 s. Dit is een zwaardere offline 50Hz-proef, geen meting van vocoderbelasting tijdens echte ontvangst.

De [DMR](Screenshots/LCD-0.7.1-DMR-example.png), [C4FM](Screenshots/LCD-0.7.1-C4FM-example.png), [NXDN](Screenshots/LCD-0.7.1-NXDN-example.png), [minimum](Screenshots/LCD-0.7.1-minimum-example.png) en [brede](Screenshots/LCD-0.7.1-wide-example.png) screenshots gebruiken herkenbaar gemarkeerde testgegevens. Daarbij zijn geen radioverbinding, USB-acties, microfoon of PTT gestart. Hoorbare radiokwaliteit wordt door deze visuele wijziging niet opnieuw vastgesteld; de bestaande audio- en protocolcode is behouden.

Bij de laatste herhaling annuleerde macOS/FileProvider het lezen van een ongewijzigd bronbestand (`Operation canceled`). Voor de definitieve controle en installatie is daarom de reeds succesvol gebouwde, onveranderlijke lokale bronkopie `Project-402c29e53f8be1f603fd` gebruikt. Alle actuele productie-Swiftbestanden en `Package.swift` zijn vooraf byte voor byte met die kopie vergeleken. De testbestanden zijn uit de actuele werkboom overgenomen; de definitieve TX-render gebruikt ook de eigen call en ID. Er is geen wijziging aan het reguliere snapshot/buildproces aangebracht.

De lokaal geïnstalleerde app 0.7.1/build 39 is met geldige lokale ondertekening gestart en native visueel gecontroleerd. De bestaande voorkeuren en voorkeuzes zijn aanwezig; de actuele modus en bestemming veranderen ook in het nieuwe LCD. Verificatie-uitvoer staat in `Docs/TestResults/LCD-20261030-{tests,console,install}.log`.

## 0.7.2 / build 40 — C4FM-reflectornaam

Het veld REFLECTOR toont de naam uit de bestaande YSF-hostcatalogus, bijvoorbeeld US-America Link in plaats van 63.250.41.136:42000. De overeenkomst gebruikt host én poort; voor eigen reflectoren valt de weergave terug op een passende opgeslagen Fusion-voorkeuzenaam. Zonder bekende naam blijft het oorspronkelijke host:poort zichtbaar. De echte endpoint staat ook in de technische onderregel en volledige tooltip. De weergave doet geen reverse-DNS-opvragen en verandert geen netwerkadres of verbindingslogica. Catalogusupdates en gewijzigde voorkeuzenamen werken door in de weergave.

Gewijzigd: RadioLCDView.swift, ReceiverDisplayView.swift, ContentView.swift, RadioLCDTests.swift, script/build_and_run.sh en documentatie. Herstelkopie vooraf: .local-backups/before-reflector-name-20261030/. Nieuwe tests controleren catalogusnaam, afwijkende poort, hoofdletterongevoelige voorkeuzenaam, onbekend endpoint en behoud van het echte IP-adres.
