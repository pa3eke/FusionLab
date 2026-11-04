# X-keys XK-24 — ontwerp en verificatie

## Analyse vóór implementatie

FusionLab is Swift/SwiftUI, macOS14+, SwiftPM, AppKit/Carbon voor de bestaande numerieke0. RadioSession is de centrale status; TransmissionLoop en FusionTransmitter draaien op de audioqueue en verzorgen vocoder/netwerk/padding/2–3min harde monotone deadline. GUI en keypad gebruiken PTTKeyState voor edge-/toggle-detectie. RadioSession.toggleTransmit/stopTransmit bewaken toestemming, kanaal, microfoonstart en afronden. UserDefaults bewaart bediening en protocolinstellingen; DMR-wachtwoord blijft in Sleutelhanger.

Hergebruik: één RadioSession, dezelfde start/stop/microfoon/transmitter, PTTKeyState en zendtimer. Nodig: kleine centrale bronregistratie voor gelijktijdige PTT-verzoeken; IOHIDManager-service; edge-parser; action/binding-persistentie; LED-controller en SwiftUI-configuratie. Geen tweede zendketen en geen wijzigingen aan protocollen, codec of andere projecten.

## Bevestigde hardware en referenties

Aangesloten: P.I. Engineering XK-24 HID, VID05F3/PID0405, locatie137506816. Consumer Page000C/Usage0001 heeft IN32/OUT35/reportID0. Keyboard Page1/Usage6 en mouse Page1/Usage2 zijn aparte interfaces en worden niet als HID-toetsinput verwerkt.

Echte descriptor via command214 (hex, macOS zonder leidende report-ID-byte):
`01d6024080600a04064026050400000000000000000000000000000000000000`
Unit1, type214, modebyte2,4kolommen/6rijen, firmware38, PID0405. De modebyte komt niet overeen met alle tekstlabels in de oudere PID-tabel; daarom zijn werkelijke PID/interface, descriptorafmetingen en rapporten leidend. Er wordt geen mode/PID gewijzigd.

Echte Generate Data-response via command177:
`01020000000002cf094400000000000000000000000000000000000000000000`
32bytes, type/PS2, vier toetskolommen op offsets2–5, zes lage bits per kolom. OS-input reportID0 wordt apart geleverd. Type214 is descriptor en geen key-event. Opstart/reconnect neemt de eerste key-state als baseline: reeds ingedrukte toetsen starten geen actie.

Officiële referenties (geraadpleegd29oktober2026):
- https://github.com/piengineering/XkeysOSX — USBConnection.swift / ReadData.swift.
- https://github.com/piengineering/PI-Engineering-SDK/blob/main/Documentation/pages/X-keys%20XK-24%20Data%20Report.htm
- https://piengineering.com/pages/hid-data-reports

SDK-voorbeelden zijn alleen referentie; geen externe dependency. De officiële tabel gebruikt sparse HID-keynummers0–5,8–13,16–21,24–29. De GUI krijgt24 opeenvolgende positienummers per kolom (4kolommen×6rijen) en vermeldt het bijbehorende HID-nummer. LED-command181 gebruikt die sparse indices, met+32 voor rood. De Swift-SDK bevat een verdachte colorBankTotal-berekening; de officiële commandtabel is hier leidend.

## MacDV als basis

Na aanwijzing van de gebruiker zijn MacDVApp/MacDVXKeys.h/.m, de source-owned requestPTT-logica in main.m en de bestaande XKeysHIDTests/HardwareHarness gelezen. De nummering, baseline/blocked-held-beveiliging, onafhankelijke hold/toggle-bronnen, asynchrone35byteLED-uitvoer en verwijderingsafhandeling zijn als ontwerp overgenomen in zelfstandige Swift-componenten. De bestaande Objective-C-engine hangt aan Buster/D-STAR; FusionLab gebruikt Swift en zijn reeds geteste TransmissionLoop/vocoder/protocollen. Daarom is de volledige PTT-bronbediening naar Swift aangesloten in plaats van de D-STAR-audioketen te koppelen. MacDV-code en apparaatinstellingen zijn niet gewijzigd.

## Bediening en instellingen

Setup → X-keys of FusionLab → Instellingen toont24 posities:4kolommen,6rijen, van boven naar beneden genummerd per kolom. Ondersteuning staat bij eerste gebruik uit. Standaard:1 PTT-vasthouden,2 PTT OFF,7verbinden,8ontkoppelen,13volume+,14volume−. Kies een toets en actie; bij PTT kies je per toets Hold/Toggle. Er zijn ook acht bestaande modegebonden voorkeuzes, AGC, EQ-bypass en **Audio mute aan/uit** als acties. De mute-actie schakelt uitsluitend het ontvangstgeluid; het ingestelde volume en de verbinding blijven behouden. Wissen en Standaardindeling herstellen beïnvloeden alleen FusionLab-voorkeuren.

PTT gebruikt één centrale request-set zoals MacDV. Hold vrijgeven verwijdert uitsluitend die bron; Toggle blijft aangevraagd tot dezelfde toets opnieuw wordt ingedrukt. De GUI en numerieke0 hebben dezelfde bronregistratie. PTT OFF (of Radio → PTT aan/uit tijdens TX) wist alle bronnen en annuleert de transmitter. USB-verlies, uitschakelen, toewijzing wijzigen en tests inschakelen geven alleen de betrokken X-keys-bronnen vrij. De bestaande2/3min deadline blijft onafhankelijk op de audioqueue gelden. Een vastgehouden toets mag na een deadline niet vanzelf opnieuw zenden.

Blauw=toegewezen, rood bij een PTT-toets=werkelijke centrale TX, niet alleen de fysieke toets. Een ingedrukte toegewezen toets flitst tijdelijk blauw. Geen functie=uit. LED-feedback kan uit; er wordt nooit een EEPROM-save, macro-, PID- of rebootcommando verstuurd. Andere apps die dezelfde X-keys aansturen kunnen LEDs of macro’s beïnvloeden: gebruik één bedieningsapp tegelijk.

Hardwaremodus PID0404/04E1 heeft geen directe inputrapporten en wordt als incompatibel voor directe bediening gemeld; er is geen keyboard-fallback die hetzelfde event nogmaals verwerkt. Keyboard-/mouse-interfaces worden niet gemonitord. De bestaande numerieke0 op het gewone toetsenbord blijft Carbon gebruiken. Sluit externe macrosoftware die dezelfde HID-input naar toetsenbordmacro’s omzet.

## Achtergrond, sessies en permissies

IOHIDManager is aan de main common-modes runloop gekoppeld, met een callback per Consumer Page-interface. Geen controle op NSApp.isActive voor HID-input, geen globale keyboard-hook, geen daemon. HID-callbacks kopiëren32bytes en dispatchen kleine acties; audiocode blijft op de bestaande onafhankelijke queue en USB-schrijfwerk op een aparte serialqueue. Apple: https://developer.apple.com/documentation/iokit/1438409-iohidmanagerschedulewithrunloop .

Een lock-, sessiewissel-, display-sleep- of systeem-sleepmelding beëindigt TX en blokkeert nieuwe verzoeken tot alle betreffende blokkeringen zijn opgeheven. De gedocumenteerde NSWorkspace-meldingen worden aangevuld met de gebruikelijke distributed screenIsLocked/screenIsUnlocked-meldingen en een initiële CGSession-statuscontrole. Die locknamen zijn geen gegarandeerde publieke Apple-API; fysieke lock/unlock moet per macOS-versie worden getest. Ontgrendelen start geen PTT en neemt de HID-state opnieuw als baseline. De harde zendtijdlimiet blijft ook zonder UI-meldingen actief.

Deze lokale app is adhoc ondertekend en niet App-Sandboxed. De geteste Consumer Page kon zonder Accessibility- of Input Monitoring-prompt worden geopend. De integratie vraagt die permissies niet proactief. Bij een HID-toegangsfout verschijnt de IOReturn-status; apparaatbeheer/privacybeleid kan op een andere Mac verschillen. Voor een toekomstige gesandboxte distributie moet USB-toegang/signing afzonderlijk worden gevalideerd. De bestaande microfoontoestemming blijft nodig voor echte audio-TX.

## Gewijzigde bestanden

| Bestand | Doel |
|---|---|
| Sources/FusionLab/Models/PTTRequests.swift | Centrale PTT-bronregistratie, hergebruik van PTTKeyState |
| Sources/FusionLab/Models/XKeys.swift | Acties,24 bindings, persistentie, HID-decoder, baseline en LED-plan |
| Sources/FusionLab/Services/XKeysDeviceManager.swift | IOHIDManager, hotplug, descriptorvalidatie, asynchrone USB-uitvoer |
| Sources/FusionLab/Services/XKeysController.swift | Mapping, toetsfeedback, reset/interlocks, teststand en LED-coördinatie |
| Sources/FusionLab/Services/RadioSession.swift | Bestaande GUI/keypad plus HID naar één PTT-bronregistratie; sessie-/lockbeveiliging |
| Sources/FusionLab/Views/XKeysSettingsView.swift |4×6 configuratie, Hold/Toggle, wissen, defaults en teststand |
| Sources/FusionLab/Views/ConsoleSettingsView.swift | Radio/X-keys-instellingen |
| Sources/FusionLab/Views/ContentView.swift | Service-lifecycle, versie; alleen werkelijk sluiten beëindigt verbinding, niet minimaliseren |
| Sources/FusionLab/App/FusionLabApp.swift | Native macOS Settings-scene |
| Tests/FusionLabTests/XKeysTests.swift | Softwarefixtures en volledige lokale RadioSession/PTT-integratie |
| Tests/FusionLabTests/ProtocolTests.swift | Testregistratie/rapportage |
| script/xkeys_hardware_probe.swift/.sh | Afzonderlijk fysiek testvenster, lokale endpoints en synthetische microfoon |
| script/build_and_run.sh |0.7.0 build38 |
| README.md, VERIFICATION.md, Docs/XKEYS.md | Gebruikers-/testdocumentatie |
| .gitignore | Lokale herstelkopie uitsluiten |

Geen wijzigingen aan MacDV, netwerkprotocollen, vocodertransport, FusionTransmitter, TransmissionLoop, AGC of EQ.

## Testverslag

Geautomatiseerd, definitieve volledige script/test.sh: **PASS**.

- Alle24 keybits, sparse LED-indices, herhaalde reports, down/up, meerdere gelijktijdige toetsen, baseline met ingedrukte toets en heractivering pas na release.
- Onbekende report-ID/type, ongeldige lengte en ongebruikte keybits; descriptor/customdata worden geen toetsen.
- Opslaan/herladen van24 bindings, aparte Hold/Toggle, defaults herstellen; alleen veranderde edges dispatchen acties.
- LED-plan: geen functie uit, toegewezen blauw, centrale TX rood op alle PTT-toetsen; feedback/tests veranderen geen centrale TX-status.
- Bestaande productie-RadioSession met lokale UDP-reflector/AMBE-fixtures en synthetische microfoon: HID hold + numerieke0 + GUI overlappen zonder tweede stream; laatste bron stopt. Focusverlies behoudt HID-verzoek. Toggle/repeats, USB-verlies met een andere actieve bron, reconnect met keyheld, disable, lock-/sleepinhibitie, noodstop, volume-repeat en foutief report tijdensTX.
- PTT OFF heeft voorrang op een nieuwe PTT in hetzelfde report. Zolang een noodstoptoets ingedrukt is, starten geen nieuwe HID-PTT-verzoeken.
- Bestaande Fusion/DMR/NXDN-pakket-, beide vocoder-, audio-, PTT- en monotone2/3min-deadlinetests slagen. MD380120frames1,703s in de definitieve reeks.

Echt apparaat: VID/PID/interfaces/reportlengtes én descriptor/GenerateData-responses zijn gemeten. Beide USB-opvraagcommando's gaven IOReturn0, zonder een nieuwe privacy-prompt. Dit bewijst geen24 fysieke toetsproeven of visuele LED-kleurtest.

Native app0.7.0 build38: installatie/start en strenge diepe codesign-verificatie geslaagd. Configuratiescherm met24 posities, actie-menu, onafhankelijke PTT-togglekeuze en wissen zijn via de echte UI gecontroleerd. Tijdelijke toets24-toewijzing is weer gewist; oorspronkelijke standaardindeling en ondersteuning-uit zijn behouden.

Bij de softwareoplevering, vóór de fysieke vervolgproef, nog te bevestigen: alle24 werkelijke toetsen en LED-kleuren; PTT met FusionLab/Finder/Safari op de voorgrond; geminimaliseerd; ander bureaublad; unplug/replug tijdens echte fysieke hold/toggle; lock/unlock op deze macOS-versie. MacDV was nog geopend bij de softwarecontroles. Daarom is niet tegelijk met MacDV een nieuwe fysieke bedienings-/LED-sessie gestart; de gebruiker is om een kort testmoment gevraagd.

## Fysieke test uitvoeren

1. Sluit MacDV en eventuele macrosoftware. Laat de normale FusionLab-X-keys-ondersteuning uit tijdens het afzonderlijke testvenster.
2. Start vanuit de repository `./script/xkeys_hardware_probe.sh`. Het testvenster opent uitsluitend AMBE-/reflector-fixtures op127.0.0.1, gebruikt synthetische microfoondata en een afzonderlijk voorkeurendomein. Er is geen publieke reflector/master verbonden en er wordt geen echte microfoon opgenomen.
3. Testvenster:1=vasthouden,2=toggle,3=PTT OFF. Kijk naar echte centrale TEST-TX/TEST-RX en de LEDs; toets1/2 moeten de werkelijke TX-status volgen. Druk alle24 toetsen eenmaal in; het venster/log telt de geziene posities.
4. Herhaal1/2/3 met Finder en Safari actief, daarna geminimaliseerd en op een ander bureaublad. Het log vermeldt de werkelijke voorgrondapp en minimalisatiestatus per event.
5. Trek USB los tijdens hold en tijdens toggle: TEST-TX moet stoppen. Sluit met ingedrukte toets opnieuw aan: geen automatische TX; release en nieuwe druk zijn vereist.
6. Laat TEST-TX aan, vergrendel zelf de Mac en ontgrendel daarna: TX moet zijn beëindigd en mag niet hervatten. Meld deze proef apart, omdat macOS-lockmeldingen per versie kunnen verschillen. De test sluit vanzelf na vijftien minuten; Test stoppen sluit eerder af en geeft PTT vrij.
7. Sluit het testvenster. In de gewone FusionLab kies je Setup → X-keys, schakel ondersteuning in en stel je toetsen in. De optie Testen zonder acties staat onder de matrix (zo nodig scrollen). Schakel die uit voor echte bediening.


### Fysiek vervolg,30oktober2026

Na de limietreset is de echte hardwareproef gestart met MacDV gesloten. De gebruiker had de gewone FusionLab-X-keys-bediening inmiddels zelf ingeschakeld (firmware38,112 events); voor de aparte lokale proef is alleen die ondersteuning tijdelijk uitgeschakeld. De eigen toets24-holdtoewijzing en de verbinding met NXDN-TG7300 zijn behouden. Na de proef moet de ondersteuning terug aan.

Eerste proef: echte down/up-events op toets1 starten en beëindigen de centrale TEST-TX zowel met het testvenster actief als met Codex op de voorgrond. Echte toets2-events houden toggle-TX actief na release; extra toets1-press/release laat de nog actieve toggle-bron intact. De gebruiker bevestigde hold, toggle, stoppen en rood/blauwe kleuren. Het log bevatte fysieke posities1,2,7; alle24-toetsverificatie was daarmee nog niet voltooid. De volgende proef krijgt15min testtijd en alleen acties op1/2/3, zodat de andere21 toetsen gecontroleerd kunnen worden zonder lokale verbindingen te veranderen.


### Afgeronde fysieke proef,30oktober2026

| Controle | Resultaat / bewijs |
|---|---|
| Alle24 echte toetsen, down/up | PASS:24/24 in het venster en fysieke key-events1–24 in het opgeslagen log; gebruiker bevestigt alle toetsen |
| Hold en Toggle | PASS: echte centrale TEST-TX-overgangen; toggle blijft actief na loslaten |
| Onafhankelijke bronnen | PASS: hold-toets1 loslaten onderbreekt de nog actieve toggle-toets2 niet |
| Noodstop | PASS in gecontroleerde proef: toets2 start echte TEST-TX; toets3-event gevolgd door STATE TX false; gebruiker bevestigt stoppen |
| Rode/blauwe LEDs | Door gebruiker fysiek bevestigd |
| Zonder appfocus | Instrumenteel vastgelegd met Codex en Chrome op de voorgrond |
| Finder/Safari, geminimaliseerd, ander bureaublad | Door gebruiker gemeld als werkend; deze specifieke situaties zijn niet afzonderlijk in de bewaarde foreground-/minimized-/spacevelden vastgelegd |
| USB-verlies tijdens hold/toggle en veilige herverbinding | Door gebruiker bevestigd |
| Vergrendelen/ontgrendelen zonder hervatten van TX | Door gebruiker bevestigd |

Een aanvankelijke melding dat toets3 niet stopte is nader gecontroleerd: de fysieke knop kwam correct als3 binnen. Bij een expliciete actieve toggle-uitzending stopte dezelfde toets direct, zowel in het log als volgens de gebruiker. Er was hiervoor geen productiecodewijziging nodig.

De fysieke proef liep door de productie-HID-service, action-mapper, PTTRequests en RadioSession/zendketen. Alleen microfoon en beide UDP-eindpunten waren lokaal/synthetisch; dit is geen on-air-audiotest. Volledige trace: TestResults/XKeys-20261030-initial.log en XKeys-20261030-extended.log.

Na afloop is het afzonderlijke testvenster beëindigd en is de normale X-keys-ondersteuning in FusionLab terug ingeschakeld. Eigen toewijzingen zijn behouden, waaronder hold op1 en24 en PTT OFF op2. De gewone NXDN-verbinding bleek tijdens de proeven verlopen door de bestaande10s-keepalivetimeout; TG7300 is opnieuw verbonden en de gewone PTT-knop is zendklaar, zonder uitzending door de agent. Een netwerkverbinding kan bij slaap/netwerkonderbreking opnieuw verbinden vereisen; de HID-veiligheidsstop geeft geen automatische PTT na herstel.
