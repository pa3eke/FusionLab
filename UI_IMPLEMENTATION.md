# FusionLab 0.5.0 — radioconsole

## Uitgangspunt en herstel

Uitgevoerd naar het aangeleverde FusionLab_Codex_UI_Prompt.txt en de DMR-consoleafbeelding. Voor uitvoering Git-status geïnventariseerd: branch experimenten bevatte bestaande gewijzigde en nieuwe bestanden. Geen reset, commit, push of wijzigingen aan MacDV uitgevoerd. Volledige bronreservekopie inclusief niet-gecommitteerd werk: `../FusionLab-backups/before-console-20261027-230542.tar.gz` (123 archiefleden); daarnaast een afzonderlijke kopie van de oorspronkelijke UI in `../FusionLab-backups/before-console-ui`.

## Componenten en bestanden

- `Sources/FusionLab/Views/ContentView.swift`: hoofdcompositie, modusrail, dagelijkse bestemming/verbinding en openen van Setup/Engineering; bestaande levenscyclusacties en toetsen blijven gekoppeld aan dezelfde sessie.
- `ReceiverDisplayView.swift`: echte RX/TX/stand-by-status, huidige bestemming, ontvangen station met bestaande QRZ-link, DMR-slot/color code, echte RX-audioamplitude. Geen fictieve RF-meter of dBm.
- `DestinationControlView.swift`: DMR-bestemming/privé/echo en bestaande YSF-hostzoeker voor een losgekoppelde endpoint. Live reflectorwisselen verloopt via bestaande voorkeuzes.
- `QuickPresetView.swift`: bestaande acht posities per mode, opslag en contextmenu hergebruikt; compactere toetsen met blauw voor de actieve keuze.
- `PresetSelectionView.swift`: metalen selectieknop, afzonderlijke tijdelijke geheugenmarkering (geen tweede radiostatus), slepen/scrollen/plus/min en toegankelijk verhoog/verlaag. Alleen Kiezen roept de bestaande activatePreset-actie aan; een lege positie of lopende TX kan niet worden geactiveerd. Kleine NSViewRepresentable vangt uitsluitend aanwijzerinvoer op.
- `ConsolePanel.swift`: herbruikbare antracietpanelen en toetsstijl.
- `AudioControlView.swift`: bestaande volume/AGC/EQ/bypass/Neutraal-bindings.
- `TransmitView.swift`: bestaande microfoon- en PTT-bediening als afzonderlijke componenten; geen nieuwe zendstate. Netwerkroute-label volgt de gekozen mode.
- `PTTButton.swift`: native tracking en acties behouden, donkere stand-by/oranje rand en rood tijdens TX. Voorgestelde SwiftUI-hoogte wordt nu gevolgd; consoleknop heeft een daadwerkelijke klikhoogte van 86 punten.
- `ConsoleSettingsView.swift`: bestaande ConnectionView met alle netwerk/vocoder/Sleutelhangeropties; apart Engineering-paneel met bestaande cumulatieve tellers, ontvangstbufferinformatie en log (maximaal 100 regels).
- `ConnectionView.swift`: hergebruikt in Setup; globale Cmd-Return uitsluitend op het hoofdscherm geregistreerd om dubbele shortcutregistratie te vermijden.
- `App/FusionLabApp.swift`: standaardvenster 1120 × 740, minimum 940 × 640. Kleiner/laag venster kan verticaal scrollen.
- `Tests/FusionLabTests/PTTRenderTests.swift`: bestaande rode-celregressie en extra controle van de echte 145 × 86 native knopafmetingen.
- `script/build_and_run.sh`: versie 0.5.0 / build 31; bestaande bouw-, installatie- en ondertekenprocedure.
- `README.md`, `VERIFICATION.md`: bediening en verificatie bijgewerkt.

## Architectuurgrens

RadioSession blijft de ene bron voor verbinding, ontvangen audio en TX. Geen nieuwe protocol-, codec-, DSP- of opslagimplementatie. Vergelijking met het volledige herstelarchief vond nul verschillen in alle bestaande modellen/services en beide codecbronmappen. Bestaande numerieke 0, Cmd-T, Escape, PTT hold/toggle en 2/3-minutenstop worden hergebruikt. D-STAR is zichtbaar gedimd; er bestaat geen D-STAR-implementatie in FusionLab.

## Verificatie

- Productie-SwiftPM-target succesvol gebouwd met de projectprocedure.
- Volledige lokale regressiereeks geslaagd: protocolvectoren, lokale BrandMeister-aanmelding/RX/TX, YSF, voorkeuzes en live reflectorwissel, AMBEserver- en MD380-routes, ontvangstfiltering/AGC/EQ, microfoonvoorbereiding, PTT hold/toggle, beide deadlines, buffering/pacing en timeout.
- Nieuwe PTT-afmeting 145 × 86 gecontroleerd in een werkelijk NSHostingView/NSWindow; bestaande 165 × 48- en herhaalde rode-celtekeningtests blijven slagen.
- Native UI: DMR/C4FM, acht aparte geheugenposities, contextmenu, Setup inclusief beveiligd wachtwoordveld, Engineering en uitklapbaar log gecontroleerd. Geen credentials gewijzigd of uitgelezen. Oorspronkelijke DMR-modus en TG91 hersteld; opgeslagen radiokeuzes behouden.
- Normaal venster circa 1120 × 740 zonder verticale scroll; verkleind venster circa 940 × 640 gecontroleerd, inclusief scroll naar onderste bediening.
- Geïnstalleerde app ondertekend en met codesign --verify --deep --strict gecontroleerd; processtart gecontroleerd.

## Grenzen

Geen publieke reflector/BrandMeister-verbinding of echte spraakuitzending tijdens deze UI-opdracht gestart. Hoorbare end-to-end-beoordeling met PUC2, tegenstation/echo en AMBEserver blijft een praktijktest voor de gebruiker. De RX-meter toont relatieve audioamplitude; er is geen RF-signaalsterktebron. D-STAR blijft niet beschikbaar. Op smalle vensters mag een lange apparaatnaam afgekort worden; de native keuzelijst en toegankelijkheidsnaam behouden de volledige naam. Geen nieuwe GitHub-publicatie uitgevoerd.

Aanvullende native controle van de definitieve build: plusknop en toegankelijke verhoogactie markeerden MEM2/MEM3 terwijl de daadwerkelijke DMR-bestemming TG91 bleef. Muisdrag/scroll kon de UI-automatisering door een vensterpositiefout niet bevestigen; de native invoerafhandeling is wel gebouwd, de plus/min- en accessibilityroute zijn visueel bevestigd.

## Update 0.5.1 — prestaties

De nieuwe console bleek bij snelle publicaties te veel layoutwerk te veroorzaken. Centrum/audio/microfoon hebben nu expliciete breedtes; de viewporthoogte wordt niet teruggekoppeld naar scrollinhoud. ConsoleRenderState is uitsluitend een vergelijking van de getoonde paneelgegevens. Regio's observeren niet langer onafhankelijk de gehele RadioSession; de hoofdview bouwt hun relevante waarden en Equatable voorkomt herindeling voor ongerelateerde tellerwijzigingen. Alle bediening schrijft nog rechtstreeks via bindings naar dezelfde sessie. De EQ-deelview heeft ook eigen relevante vergelijkingswaarden. De waarschuwingsklok bestaat alleen wanneer knipperen nodig is.

Rustmeting circa0% CPU na de correctie; native schermcontrole0,2–0,6s in plaats van30s timeout. Afzonderlijke120-burstsproef: oorspronkelijke UI overschreed20s-watchdog, verbeterde UI4,770s. Volledige radioregressietests slagen. Exacte condities en de grenzen van de meting staan in VERIFICATION.md; de probe is reproduceerbaar via python3 script/probe_console_ui.py. 0.5.1 build32 geïnstalleerd.
