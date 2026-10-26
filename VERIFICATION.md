# Verificatie 24 oktober 2026

- `swift build`: geslaagd, native arm64 macOS-app.
- `./script/build_and_run.sh --verify`: geslaagd; de app-bundle start als FusionLab.
- `./script/test.sh`: geslaagd. Wire formats, PCM, FICH, V/D2, repetitiefoutcorrectie en lokale UDP-integratie met volledige AMBE-initialisatie en vijf terugontvangen PCM-blokken.
- Interface visueel gecontroleerd op 760 × 680: instellingen, ontvangststatus, volume, tellers en log zijn zichtbaar. Venster is schaalbaar met minimummaat 660 × 580.
- De actieve gebruikerssessie toonde echte protocolantwoorden: AMBE READY, product AMBE3000R, bevestiging van het 2450-bit/s Fusion DN-profiel en een antwoord van de YSF-reflector. De app bleef in die sessie verbonden.
- Nog niet geverifieerd: hoorbare spraak van een echt ontvangen station, spraakkwaliteit bij pakketverlies, andere YSF/XLX-servers. Geen zendfunctie in deze versie.
- MacDV-broncode en -bundle zijn voor deze testapp niet gewijzigd.

## Versie 0.2 — PTT

- Nieuw: microfoontoegang, zelfstandige niveautest zonder uitzending, native resampling naar 160 samples/20 ms, DVSI-encoding, YSF-start/spraak/eindframes, PTT-knop en toetsen, halfduplex, afronden van de laatste groep met door de vocoder gecodeerde stilte.
- Vijf volledige 155-byte-zendpakketten komen byte voor byte overeen met apart gegenereerde DroidStar-referenties. Zie `Tests/Fixtures/README.md`.
- Lokale UDP-test controleert PTT van microfoonbron tot YSF, geweigerde en geannuleerde microfoontoegang, tien encoded blokken in twee spraakdatagrammen, stoppen en ontkoppelen tijdens zenden. Geen publieke uitzending gebruikt voor deze controles.
- Nieuw getest: 44,1 en 48 kHz stereo → 8 kHz mono, PCM-clipping, encode-time-out, dubbele stop en 180-secondenlimiet.
- Nog met gebruiker te testen: echte microfoontoegang, niveau en hoorbare radio-spraakkwaliteit via de echte AMBEserver en reflector/tegenstation.

- Versie 0.2 is gestart uit `/Users/rob/Applications/FusionLab.app`. Proces en RX/TX-venster met PTT en microfoontest zijn gecontroleerd. `codesign --verify --deep --strict` slaagt ook na het starten. De build verwijdert uitsluitend FinderInfo/ResourceFork uit de eigen app-uitvoer en installeert buiten de bestandsprovider-map Documenten.

## Versie 0.2.1 — PUC2 en AMBE3000R

- De daadwerkelijke macOS-audioinventaris liet Beeldschermaudio als standaardingang zien; YELLOWTEC PUC2 was beschikbaar met twee kanalen op 48 kHz. De vorige app volgde uitsluitend de standaardingang.
- Toegevoegd: eigen CoreAudio-ingangskeuze op stabiele device-UID, PUC2 als eerste voorkeurskeuze, kanaal 1/2, herladen van ingangen en een blokteller in de microfoontest. De keuze wijzigt de macOS-standaardingang niet. Na het instellen van de audio-unit wordt het actieve device-ID teruggelezen en gecontroleerd.
- Een lokale AMBEserverproef zonder YSF-verbinding leverde een geldig 16-byte encoderantwoord op: 7 bytes CHAND met 49 bits plus een aanvullend 3-byte CHANMODE-veld. De oude parser accepteerde alleen de 13-byte variant. Beide formaten worden nu ondersteund; ongeldige/truncaties blijven afgewezen.
- Een tweede lokale proef codeerde PCM-stilte en decodeerde die terug naar een standaard 326-byte PCM-antwoord. Geen uitzending naar een reflector.
- Tests geslaagd: bestaande RX/TX-controles plus de daadwerkelijke 16-byte antwoordvorm, foutieve trailers en onafhankelijke selectie van linker/rechter stereokanaal vóór resampling. Nieuw gebouwde app 0.2.1 gestart met YELLOWTEC PUC2 zichtbaar geselecteerd.
- Bij het starten van de echte microfoontest vroeg macOS opnieuw om toestemming vanwege de gewijzigde lokale ontwikkelbuild. De hardwaretest wachtte op die toestemming. Hoorbaar signaal/het fysiek aangesloten kanaal is daarmee nog niet vastgesteld.

## Versie 0.2.2 — microfoonversterking en piekmeter

- Toegevoegd: softwareversterking van −12 tot +36 dB, onthouden instelling, 0-dB-knop, gemiddelde en piek in dBFS, piekhold van één seconde en een clip-indicator van één seconde. Versterking wordt vóór de AMBE-encoder toegepast; de microfoontest gebruikt exact dezelfde audiobewerking.
- Samples worden begrensd vóór conversie naar 16-bit PCM. Tests controleren neutrale versterking, +6/+20/−6 dB, clipping en ongeldige samples. De lokale PTT-integratietest controleert bovendien de versterkte amplitude in de PCM-pakketten die daadwerkelijk bij de nagebootste vocoder aankomen.
- Een extra integratietest vond recursie in de instelling-opslag door een @Published-setter. Dit is hersteld door alleen bij een afwijkende begrensde waarde opnieuw toe te wijzen. De volledige testreeks slaagt daarna.
- Buildcache naar `/private/tmp/FusionLab-build-<uid>` verplaatst nadat de compiler bleef wachten bij het mappen van modulecachebestanden in de bestandsprovider-map. Bouw en pakketcontrole slagen vanuit deze lokale cache.
- App 0.2.2 geïnstalleerd en geopend. In de UI is de versterking van 0 naar +6 dB gewijzigd en na opnieuw bouwen/starten op +6 dB teruggevonden. PUC2 kanaal 1 is behouden. Alle bediening en meters zijn visueel zichtbaar. Geen publieke uitzending voor deze tests.
- Eerdere daadwerkelijke PUC2-controle na microfoontoestemming: oplopende audioblokteller en niet-nul niveau; de gebruiker bevestigde daarna dat de meter op spraak reageerde. Hoorbare zendkwaliteit met de nieuwe versterking moet door de gebruiker worden beoordeeld.

## Versie 0.2.3 — PTT-bufferpiek verbreekt YSF

- In de daadwerkelijke gebruikerslog trad na PTT `Microfoonbuffer loopt vol; zenden gestopt` op, waarna de app zelf de reflector ontkoppelde. De vorige capaciteit was tien audioblokken (200 ms), terwijl AVAudioEngine meerdere blokken in één callback kan aanleveren. De exacte PUC2-callbackgrootte is nog niet gemeten; de nieuwe versie logt die bij de eerste callback.
- De wachtrij vangt nu maximaal 25 blokken (500 ms) op en slaat bij uitzonderlijke overloop geteld de oudste blokken over. Dit veroorzaakt geen fatale fout. Een vaste 20-ms-planning met maximaal twee invoerblokken per timercallback vangt korte schedulervertraging op zonder onbeperkt naar de vocoder te sturen. De afronddeadline houdt rekening met de werkelijk resterende audio.
- Encoder- en TX-microfoonfouten stoppen de uitzending met een eindframe en herinitialiseren uitsluitend AMBE. De bestaande YSF-socket en keepalives blijven behouden. TX is tijdens vocoderherstel geblokkeerd. Als vocoderherstel mislukt blijft YSF verbonden en verschijnt een gerichte melding.
- Regressietest: twintig gelijktijdig aangeleverde audioblokken (400 ms) blijven zonder verlies zenden; honderd blokken blijven begrensd met getelde overloop. De lokale UDP-integratietest bevestigt twintig gecodeerde blokken, vier spraakdatagrammen en een eindframe zonder YSF-disconnect.
- Een nagebootst ongeldig encoderantwoord herstelt AMBE en houdt exact dezelfde YSF-clientverbinding in stand. Alle overige protocol-, microfoon-, versterkings- en PTT-tests slagen.
- Geen publieke radio-uitzending voor deze controles. Werkelijke PTT met PUC2 en reflector moet opnieuw door de gebruiker worden getest.

## Versie 0.2.4 — audio en UDP buiten de interface

- De echte gebruikerstest van 0.2.3 toonde bij 4–7 seconden PTT slechts 51–63 gecodeerde blokken, veel overgeslagen microfoonaudio en een afrond-time-out. De echo kwam gedeeltelijk terug, maar werd tijdens AMBE-herinitialisatie onderbroken.
- Rechtstreekse UDP-meting met de echte AMBEserver: 50 PCM-invoerpakketten op 20-ms-afstand, 50 geldige 16-byte/49-bit encoderantwoorden in 1,008 seconde; gemeten antwoordvertraging 14,1–30,3 ms, mediaan 18,5 ms. Dit ondersteunt dat de softwareplanning, niet de capaciteit van de vocoder, de vertraging veroorzaakte.
- Toegevoegd: TransmissionLoop met eigen seriële I/O-queue en Dispatch-timer. Microfoongain, encodeerplanning, AMBE-antwoordafhandeling en audioweergave lopen buiten de hoofdthread. Meter- en tellerpublicaties zijn begrensd op 10 Hz. UDPLink en AudioOutput serialiseren hun toegang op dezelfde queue. Main-thread-status blijft op de hoofdthread.
- Regressietest blokkeert de hoofdthread 650 ms bij een gesimuleerde PUC2-aanlevering van vijf blokken per 100 ms. Alle 100 blokken worden gecodeerd, zonder verlies, in twintig spraakpakketten plus start en einde. Ook PCM-aflevering naar de playercallback blijft doorlopen tijdens een geblokkeerde hoofdthread.
- Volledige bestaande testreeks slaagt. De testrunner compileert voortaan een tijdelijke lokale snapshot van de productiebronnen en fixtures, om door FileProvider gewijzigde tijdstempels tijdens het compileren te vermijden.
- Productieketen tegen de echte AMBE3000R, zonder reflectorverbinding: 50 PCM-blokken aangeboden, 50 gecodeerde blokken ontvangen, 0 overgeslagen, 12 YSF-pakketten uitsluitend lokaal opgebouwd, daarna alle 50 teruggewonnen AMBE-blokken weer gedecodeerd naar 50 PCM-blokken. Totale encode/decodeproef 2,111 seconden. `script/ambe_pipeline_probe.swift` bewaart de gebruikte diagnostiek, met expliciete host/poort-argumenten en uitsluitend synthetische stilte.
- De melding 'Geen PCM-audio ontvangen' wordt alleen nog gebruikt voor werkelijk onbeantwoorde decodeerverzoeken; een normale stilte na een afgelopen echo is geen fout.
- Geen publieke radio-uitzending voor deze controles. Hoorbare echo met de nieuwe app moet nog door de gebruiker worden bevestigd.

### Aanvullende 0.2.4-controle

- Ook YSF-spraakextractie en het op 20-ms-afstand voeren van de AMBE-decoder zijn naar de I/O-queue verplaatst. De interface doet hiervoor geen audioplanning meer. De regressietest ontvangt vijftig echo-audioblokken met een bewust 650 ms geblokkeerde hoofdthread; alle vijftig worden naar de playercallback afgeleverd.
- De hardwareproef is met deze volledige ontvangstroute herhaald: 50 invoerblokken, 50 encoded, 0 overgeslagen, 12 lokale YSF-pakketten en 50 gedecodeerde PCM-blokken, in 2,215 seconden. Geen reflectorverbinding en uitsluitend synthetische stilte.
- De uiteindelijke testreeks slaagt zonder compilerwaarschuwingen. Bouwinvoer van de productietargets wordt nu eveneens via een inhoudshash onveranderlijk onder `/private/tmp` gekopieerd. Dit voorkomt door FileProvider veranderde brontijdstempels tijdens het compileren; de oorspronkelijke projectbestanden blijven bewerkbaar in hun eigen map.

- Aanvullende fysieke signaalproef met een synthetisch harmonisch signaal (geen microfoonopname, geen RF/reflectorverbinding): invoer-RMS 0,0648, teruggedecodeerde PCM-RMS 0,070663. Alle 50 blokken zijn gecodeerd en via de volledige lokale YSF-ontvangstroute weer naar 50 PCM-blokken gedecodeerd, zonder verlies; totale proef 2,240 seconden. Hiermee is ook bevestigd dat de keten daadwerkelijke niet-stille geluidsdata teruggeeft.
- De geïnstalleerde app is gecontroleerd als versie 0.2.4 met PUC2 kanaal 1 en de bestaande +15-dB-instelling behouden. De app staat losgekoppeld klaar voor de nieuwe echo-praktijktest.


## Versie 0.2.5 — snelle echo zonder weggegooide spraak

- De gebruikerssessie van 18:25–18:26 liet vier volledige echo’s zien: 805 ontvangen AMBE-spraakblokken, 349 PCM-blokken, nul YSF-sequentieverlies en nul protocolfouten. In de ontvangstroute werd de wachtrij boven 50 blokken stilzwijgend ingekort door oude spraak te verwijderen. Dit is een concrete fout; zonder een pakketregistratie is niet bewezen dat dit alle gehoorde vervorming verklaart.
- De capaciteit is nu 9050 blokken (181 s, passend bij maximaal 180 s PTT). Dat is geen vaste vertraging: de decoder blijft één blok per 20 ms verwerken. Bij de grens blijft bestaande spraak behouden en worden geweigerde nieuwe blokken zichtbaar geteld. De interface toont ontvangen, decoderinvoer, PCM, wachtende en overgeslagen blokken. PTT wacht totdat de ontvangen blokken verwerkt zijn.
- De audioplayer stopt na echte bufferleegloop en bouwt bij hernieuwde aanvoer zijn korte voorbuffer opnieuw op. Een eindstukje van minder dan vier blokken krijgt een startdeadline van 80 ms en blijft niet hangen.
- Vergelijking met originele DroidStar ysf.cpp/mode.cpp/serialambe.cpp op 24 oktober: 160 samples/8 kHz per blok, vijf blokken per YSF-pakket, identiek 2450/0000-rateprofiel en DVSI-interleave. macOS RX-timer 20 ms; TX pollt 19 ms maar vraagt telkens 160 beschikbare samples. Geen reden gevonden om de nominale spraakklok van 20 ms te versnellen.
- Volledige `./script/test.sh` geslaagd. Nieuwe regressie: 315 unieke spraakblokken (6,3 s), als één snelle YSF-echo inclusief eindframe aangeboden, worden allemaal in dezelfde volgorde met nul verlies over minimaal zes seconden gedecodeerd. Bestaande controles voor realtime RX/TX met geblokkeerde interface en onafhankelijke DroidStar-zendvectoren blijven slagen.
- Fysieke lokale AMBE3000R-proef met `--burst-echo`: 315 PCM-invoerblokken → 315 encoded → 65 uitsluitend lokaal bewaarde YSF-pakketten → 315 PCM-terugantwoorden. RX-bufferpiek 315, overgeslagen 0; totale encode/decodeproef 12,718 s. Uitsluitend synthetische stilte, geen YSF-socket of publieke uitzending. Het diagnoseschrift ondersteunt deze herhaalbare burstmodus nu expliciet.
- Hoorbare spraakkwaliteit via de echte echo-reflector blijft door de gebruiker te beoordelen. MacDV is niet gewijzigd.


## Versie 0.3.0 — YSF-reflectorselectie

- De gebruiker heeft hoorbare echo met 0.2.5 bevestigd. In de daaropvolgende appcontrole stonden 765 ontvangen → 765 decoder → 765 PCM, wacht 0, overgeslagen 0 en nul YSF-verlies/fouten.
- Toegevoegd: reflectorselectie op naam/nummer, zoeken in naam/nummer/omschrijving/host, Nederlandfilter, dubbele klik of Kiezen, handmatige host/poort en een vaste Echo · PA7LIM-optie. Kiezen vult host én poort in, onthoudt deze en maakt geen verbinding. Een actieve sessie kan niet van endpoint wisselen.
- Bron: Pi-Star-export opgehaald 2026-10-24 16:17:41 UTC, 1587 bronregels. Na deduplicatie op host/poort en toevoeging van de bekende echo-host: 1574 selecteerbare ingangen. Origineel bestand inclusief Pi-Star/DVRef-attributie meegeleverd; HTTPS-update op verzoek en laatste geldige lijst in Application Support. Geen account nodig voor deze Pi-Star-export.
- Volledige lokale testreeks geslaagd, inclusief nieuwe controles voor geldige/ongeldige bronregels, BOM/CRLF, dubbele endpoints, zoeken op meerdere woorden, afwijkende poort, offline cache, mislukte/ongeldige download zonder overschrijven, corrupte cachefallback, blijvende host/poort-selectie en bescherming van actieve sessies. Bestaande RX/TX-/echo-tests blijven slagen. Geen uitzending voor deze controles.
- De geïnstalleerde app 0.3.0 build 8 is gestart en streng op ondertekening gecontroleerd. Resourcebundle zit in Contents/Resources; de geïnstalleerde app zoekt daar expliciet vóór de SwiftPM-buildlocatie.
- Schermcontrole: meegeleverde lijst met 1574 ingangen zichtbaar; live Lijst bijwerken geslaagd, daarna uit bewaarde lijst heropend. Nederlandfilter toont 21 ingangen. Zoeken op NL-NLCENTRAL, enkele klik + Kiezen vult 90.145.156.242:42000 in zonder verbinden. Dubbelklik op Echo · PA7LIM herstelt c4fm.pa7lim.nl:42000. PUC2 kanaal 1 en de inmiddels door de gebruiker gekozen +13 dB zijn behouden. De app staat losgekoppeld klaar.
- Audiotiming en codecroute zijn voor deze functie niet gewijzigd. Bereikbaarheid of DN-ondersteuning van alle lijstingangen is niet afzonderlijk getest.


## Versie 0.3.1 — globale numerieke PTT en harde time-out (25 oktober 2026)

- Toegevoegd: onthouden keuze voor numerieke 0: Uit, Vasthouden of Aan / uit; standaard Vasthouden. Globale exclusieve Carbon-hotkey voor keypad 0 (code 82), uitsluitend gereserveerd wanneer zendklaar, tijdens PTT of tot loslaten van een bestaande toetsdruk. Geen algemene toetsenbordmonitor of extra toegankelijkheidsrechten. Een bezette toets geeft een duidelijke status in plaats van stil falen.
- Een lokale Cocoa-toetsroute gebruikt dezelfde toestandsmachine. Herhaling/dubbele toetsaanslagen starten geen tweede uitzending; vasthouden stopt bij loslaten, ook tijdens de microfoonaanvraag. Toggle stopt op een volgende druk. Globaal gestarte PTT blijft bij appfocuswissel actief. De muis-/⌘T-route behoudt de bestaande stop bij focusverlies.
- Toegevoegd: zichtbare PTT-schakelaar en resterende seconden. Elke niet-idle zendfase krijgt op de onafhankelijke I/O-klok een harde limiet van 180 seconden op monotone systeemtijd. Bij de grens gaat direct een YSF-eindframe uit en worden resterende zendblokken verwijderd; normale handmatige stop blijft netjes afronden. De interface meldt de time-out. Een vastgehouden toets blijft vergrendeld tot loslaten en kan daardoor niet automatisch opnieuw starten.
- Ontkoppelen, veranderen van bediening en sluimeren stoppen PTT; de globale registratie wordt vrijgegeven bij ontkoppelen/uitschakelen. De PTT-instelling is tijdens zenden vergrendeld in de interface.
- Volledige `./script/test.sh` geslaagd: bestaande audio-/echo-/hostlijsttests plus toetsherhaling, hold/toggle/uit, geen start tijdens ontvangst, annuleren van uitgestelde microfoontoestemming op loslaten, focuswissel, aan/uit-schakelaar en sleutelvrijgave. De harde limiet is met een gestuurde monotone klok exact op 180 s getest, terwijl de wandklok een dag teruggaat en audio/AMBE-antwoorden nog wachten. Alleen het eindframe wordt nog verzonden; late encoderantwoorden hervatten niets. Geen publieke uitzending.
- Losse native proef: de globale hotkey registreerde succesvol. Een via computerautomatisering naar Finder gestuurde KP_0 leverde geen Carbon down/up op en de proef liep na 30 s af. Dit bevestigt geen fysieke werking; die moet de gebruiker nog op zijn numerieke toetsenbord bevestigen. Het lokale diagnoseschrift `script/ptt_key_probe.swift` opent geen microfoon of netwerk.

- 0.3.1 build 9 is in ~/Applications geïnstalleerd en gestart; strenge codesign-verificatie geslaagd. De schermcontrole toonde de keuze Vasthouden, de zichtbare PTT-switch en Time-out · 180 s; host NL-Hobbyscoop, PUC2 kanaal 1 en gebruikersversterking +2 dB bleven behouden. Voor compacte vensters is de hoofdinhoud nu scrollbaar zodat toegevoegde bediening geen koptekst buiten beeld drukt. Na die laatste layoutbouw werkte de native CUA-appverbinding niet meer (pipe closed); de app draaide wel en versie/signering zijn afzonderlijk gecontroleerd. De laatste layout is dus gebouwd, maar niet opnieuw visueel bevestigd. Fysieke keypad-0-proef door de gebruiker blijft nodig.


## Versie 0.3.2 — schakelaar kiest werking van de PTT-knop

- Gebruikerscorrectie verwerkt: de schakelaar is geen tweede zendbediening meer. **Aan/uit-modus** uit betekent indrukken = PTT aan en loslaten = PTT uit; aan betekent één druk = PTT aan en een volgende druk = PTT uit. De keuze wordt onthouden en wijzigen start geen uitzending. De numerieke 0 behoudt zijn eigen instelling.
- Native NSButton-muistracking houdt de druk vast tot release, ook buiten de knop. Druk en release gaan door een afzonderlijke PTT-toestandsmachine; herhalingen en een hard beëindigde uitzending kunnen geen automatische herstart veroorzaken. De knop gebruikt de bestaande microfoonannulering en 180-secondenlimiet. ⌘T is behouden in het Radio-menu.
- Definitieve volledige testreeks geslaagd, inclusief nieuwe lokale UDP-controles die de echte RadioSession-knoproute in beide standen uitvoeren: momentary stopt na release, toggle blijft na release aan en stopt bij de volgende druk. Moduswisselen op zichzelf zendt niet. Bestaande globale-toets-, toestemming-, time-out-, echo- en hostlijsttests blijven slagen. Geen publieke uitzending.
- Native CUA-appverbinding gaf tijdens deze wijziging opnieuw 'pipe closed'; muistracking en visuele plaatsing zijn daarom niet met de echte interface opnieuw gecontroleerd. De productie-app bouwt wel met de native knop en de sessieroutes zijn lokaal getest.


## Versie 0.3.3 — één modus voor knop én numerieke 0

- De gebruiker verduidelijkte dat de numerieke 0 niet reageerde op de Aan/uit-modus. Concrete oorzaak: de muisknop gebruikte `pttButtonToggle`, de numerieke 0 gebruikte een onafhankelijke `pttKeyMode`. Daardoor veranderde de zichtbare schakelaar het toetsenbordgedrag niet.
- Eén effectieve modus toegevoegd: de Aan/uit-schakelaar stuurt zowel muisknop als numerieke 0 aan. Uit = vasthouden/loslaten; aan = eerste druk aan, volgende druk uit. De eerdere drie-keuzemenu voor het toetsenbord is vervangen door een vinkje voor de globale toets. De toetsinstelling bepaalt uitsluitend of numerieke 0 actief is. Moduswisseling stopt bestaande PTT en wist oude toetsstatus voordat opnieuw geregistreerd wordt.
- Regressietest op de werkelijke RadioSession met lokale UDP-servers: de toetsenbordinstelling blijft `.hold`, uitsluitend de zichtbare modus gaat aan, keypad-press/release blijft dan zenden en de volgende druk stopt. Terugschakelen herstelt release = uit. Daarna zijn beide muisknopstanden gecontroleerd. Bestaande muistracking is behouden; er is geen speculatieve wijziging van die route nodig voor deze oorzaak. De 180-secondenbeveiliging blijft ongewijzigd.
- Native CUA-appverbinding bleef niet beschikbaar, zodat geen fysieke numerieke toetsdruk is nagebootst. Geen publieke reflectoruitzending gebruikt voor de regressies.


## Versie 0.3.4 — rode PTT-knop tijdens zenden

De volledige achtergrond van de PTT-knop wordt systeemrood bij actieve uitzending, met witte tekst. In rust blijft de knop in de accentkleur; niet beschikbaar is grijs. Alleen de tekening is veranderd, de PTT-bediening en 180-secondenlimiet zijn behouden.


## Versie 0.3.5 — grotere, rustige PTT-knop

- Hoogte van de PTT-knop verdubbeld van 50 naar 100 punten; breedte 165 behouden.
- `updateNSView` wijzigt titel, enabled en zendkleur uitsluitend als die waarden daadwerkelijk veranderen. Geen onvoorwaardelijke invalidatie meer op elke meter-/ontvangstupdate.
- De bestaande ontvangst-hangtijd van 400 ms geldt nu ook voor echo's van de eigen call. Zonder die hangtijd kon de PTT-beschikbaarheid tussen korte echo-pakketgroepen wisselen, waardoor de kleur tussen accent en grijs heen en weer kon gaan. Rood blijft uitsluitend gekoppeld aan zenden.

- Definitieve volledige lokale tests geslaagd, inclusief eigen-call echo: PTT blijft na de laatste PCM eerst geblokkeerd en wordt na de ontvangst-hangtijd weer beschikbaar. Native schermcontrole bleef niet bereikbaar door de bestaande CUA-pipefout; het verdwijnen van zichtbaar knipperen moet daarom door de gebruiker worden bevestigd.


## Versie 0.3.6 — gemeten native maat en consistente knopcel

- De eerdere SwiftUI-framehoogte vergrootte uitsluitend het buitenkader: een nieuwe integratietest met NSHostingView en de echte representable mat de oude NSButton op 165 × 24 punten. De regressietest faalde op die afwijking vóór de correctie.
- Een expliciete `sizeThatFits`, native intrinsicContentSize en nul alignment-insets geven de knop zelf nu 165 × 48 punten. Dit verdubbelt de daadwerkelijk zichtbare oorspronkelijke hoogte van 24 punten. De omringende framehoogte is hierop afgestemd.
- Kleuren worden nu door een eigen NSButtonCell getekend (bezel en tekst), in plaats van alleen door NSButton.draw. Daardoor gebruikt ook AppKits directe cel-hertekenroute dezelfde achtergrond en kan de standaard knopcel de aangepaste weergave niet vervangen. Rode zendkleur en witte tekst blijven behouden; PTT-afhandeling is niet gewijzigd.
- De renderproef tekent de echte knopcel twintig keer en controleert rode achtergrond nabij zowel boven- als onderkant. Er wordt een lokaal bitmapvoorbeeld opgeslagen als /private/tmp/FusionLab-PTT-render.png. Dit is een gegenereerde testweergave, geen schermafbeelding van de actieve radiosessie. Er is geen radioverbinding of uitzending nodig voor deze controle.


## Versie 0.4.0 — DMR / BrandMeister (25 oktober 2026)

- Toegevoegd: keuze Fusion/DMR, Nederlandse master 2041 op UDP 62031, handmatige master/poort, eigen DMR-ID, optionele SSID, bestemming, privé-/groepsoproep, TS1/TS2 en CC. Bestemming/privé zijn wijzigbaar tijdens een verbinding wanneer niet wordt gezonden. Identiteit/master blijven vergrendeld tijdens de verbinding.
- Homebrew-handshake met salt/SHA-256, volledige vaste RPTC-configuratie, 5-s-pings, master-NAK/close en time-outs. Geen automatische radio-uitzending bij kiezen of verbinden. PTT pas na bevestigde masteraanmelding en AMBE-profiel. Wachtwoord uitsluitend in RAM, of na aanvinken in de macOS-Sleutelhanger; geen log/configdump. Tests injecteren een geheugenstore zodat gebruikerscredentials niet worden gelezen of gewijzigd.
- DMR gebruikt het AMBE3000R 2450/1150-profiel: 72 bits/9 bytes, drie vocoderblokken per 60-ms DMRD-pakket. Header/terminator-LC met Reed-Solomon, Golay-slotcode en BPTC19696; embedded LC met CRC5/Hamming en QR-signalling. Publieke GPL-FEC-bronnen van DroidStar zijn met auteursvermelding toegevoegd. Fusion houdt zijn bestaande 49-bits/100-ms-route.
- De gedeelde audioklok, bufferbewaking, PUC2-keuze, gain, grote rode PTT-knop, globale numerieke 0 en monotone 180-s-limiet blijven in gebruik. De zichtbare afteller krijgt nu ook de periodieke TX-metrics in beide modi.
- Tien complete zendpakketten (header, acht voice met zes superframefasen en terugloop, terminator) komen byte voor byte overeen met originele DroidStar-functies buiten de productie-adapter. Regeneratie uit de bewaarde oorspronkelijke bron levert identieke fixtures. De ongewijzigde FEC-bron is gedeeld; de vectors zijn geen onafhankelijke toets van de DMR-specificatie zelf.
- Volledige lokale testreeks geslaagd: authenticatiedigest, verkeerde/truncate ACK, NAK, aanmelden/time-out/keepalive/afmelden, DMR-wireformat/LC-checks, 60-ms-zendtempo/padding, slot/private-destination-filter, duplicaten/oudere pakketten en 255→0-overloop. Lokale UDP-master plus nep-AMBE en testmicrofoon controleren volledige DMR-aanmelding, 15 gecodeerde blokken in 5 voice-pakketten, drie terugontvangen PCM-blokken en omschakelen naar Fusion met het 49-bits profiel en vier correcte YSF-pakketten. Extra test controleert wisselen van privé-echo naar TG204 zonder heraanmelding en zonder plaintextwachtwoord in de gewone instellingen.
- Echte AMBEserver 192.168.1.111:2460, met FusionLab vooraf afgesloten en MacDV niet actief: 315 synthetische PCM-stilteblokken → 315 encoded 72-bits DMR-blokken → 107 uitsluitend lokaal bewaarde DMR-netwerkpakketten → 315 gedecodeerde PCM-blokken. Overgeslagen 0, RX-bufferpiek 315, totale tijd 12,739 s. Geen master-/reflectorsocket, geen publieke uitzending, geen microfoonopname.
- 0.4.0 build 15 geïnstalleerd en gestart; strenge codesign-verificatie geslaagd. Na reset van de CUA-sessie werkte de schermcontrole weer. Werkelijke app toont beide modi; DMR geselecteerd, Nederland 2041 / 62031, DMR-ID leeg, wachtwoordveld leeg, TS2 / CC1 / privé 9990, optionele Sleutelhangerkeuze en geblokkeerde Verbinden-knop zolang exclusiviteit niet bevestigd is. PUC2 kanaal 1 en +2 dB bleven behouden. De app is niet automatisch verbonden.
- Nog niet geverifieerd: aanmelding op de echte BrandMeister-master en hoorbare DMR-spraak. De gebruiker heeft de Nederlandse master gekozen; DMR-ID volgt en wachtwoord wordt rechtstreeks in de app ingevuld. MacDV blijft ongewijzigd.


## Versie 0.4.1 — PTT geblokkeerd door masterafwijzing

- Werkelijke appstatus gelezen: Fusion kon wel zenden; meerdere DMR-aanmeldingen eindigden met MSTNAK en een gesloten verbinding. AMBE3000R bevestigde het 72-bits DMR-profiel. Op dat moment is geen defect in de PTT-pakketroute aangetoond; er was geen aangemelde DMR-verbinding.
- Nieuwe voortgang en faseafhankelijke afwijzing onderscheiden ID/SSID vóór wachtwoordcontrole, hotspotwachtwoordantwoord en apparaatconfiguratie. Een blijvende rode melding staat naast de verbindingsinstellingen, ook na automatisch sluiten. De SwiftUI-PTT-view krijgt expliciet dezelfde disabled-voorwaarde als de native knop.
- Concrete nevenfout hersteld: Ophalen uit een lege Sleutelhanger maakte de al getypte wachtwoordtekst leeg. De tekst blijft nu behouden als niets is opgeslagen.
- Een externe ID-proef naar België werd eerst door auto-review geweigerd wegens ontbreken van expliciete toestemming voor deze bestemming. Na expliciete gebruikerskeuze België 2061 is één RPTL gestuurd met DMR-ID 2041007: antwoord RPTACK, 10 bytes. Direct RPTCL verstuurd. Geen wachtwoord, authenticatiedigest of spraak verzonden. Dit bewijst uitsluitend dat de eerste aanmeldstap door die master wordt geaccepteerd.
- Nieuwe lokale tests controleren de afzonderlijke NAK-fasen en behouden van ingevulde wachtwoordtekst. De bestaande volledige Fusion/DMR-tests blijven van toepassing. Een oorzaak van de latere live afwijzing is nog niet vastgesteld; de gebruiker bevestigt het aparte Hotspot Security-wachtwoord te gebruiken.

- Volledige tests na de wijziging geslaagd. De lokale mastertest wacht nu op het daadwerkelijk ontvangen eindpakket; eerder kon de UI-stopcallback een fractie vóór de UDP-ontvangst aankomen en een te vroege count-assertie veroorzaken. 0.4.1 build 16 geïnstalleerd en gestart. Werkelijke UI toont België 2061 en ID 2041007 behouden, een leeg niet-opgeslagen wachtwoordveld en nu ook een expliciet uitgeschakelde PTT-knop zolang losgekoppeld. De volgende live aanmeldpoging vereist dat de gebruiker het wachtwoord in de app opnieuw invult.

## Versie 0.4.2 — compatibele softwareclientregistratie

- Gebruiker bevestigt de fase: wachtwoordcontrole geslaagd, daarna apparaatconfiguratie geweigerd. Het 302-byte registratiepakket had de juiste lengte, maar meldde nulfrequenties en `FusionLab` als softwareversie.
- Vergeleken met de publieke bronnen van BrandMeister/DMRHost (`DMRNetwork.cpp`, vaste veldindeling) en nostar/DroidStar (`droidstar.cpp`, standaardregistratie). Nominale RX/TX-metadata nu 438800000 Hz; softwareversie in datumformaat 20261025; pakketidentiteit MMDVM_FusionLab. Geen hardware-identiteit van een bestaande hat overgenomen. Onbekende positie blijft nul, locatienaam leeg en vermogen nul. De nominale frequenties stellen geen RF-hardware af.
- Regressiecontrole op exacte Homebrew-veldposities, padding, ID/call, frequenties, vermogen/CC, nulpositie/hoogte, tijdslotaanduiding en software-identiteit toegevoegd. Een lokale mock alleen kan servervalidatie niet bewijzen.
- De exacte validatieregel van de echte BrandMeister-master is niet vastgesteld. Deze wijziging is een gerichte compatibiliteitsproef; live acceptatie vereist een nieuwe aanmelding door de gebruiker. Er zijn voor deze wijziging geen wachtwoorden gelezen of publieke radio-uitzendingen uitgevoerd.
- Volledige lokale testreeks geslaagd: Fusion/DMR-referentiepakketten, registratievelden, authenticatie/RX/TX/moduswissel, ontvangstfilters, PTT vasthouden/toggle, 180-s-limiet, microfoonrechten, pacing/padding en time-outs. 0.4.2 build 17 geïnstalleerd in ~/Applications en gestart; strenge codesign-verificatie en procescontrole geslaagd. Native UI-inspectie liep tweemaal vast op een time-out; de zichtbare nieuwe vensterstatus is daarom niet gecontroleerd. Er is niet automatisch aangemeld op de master.

## Versie 0.4.3 — één bedieningsroute voor numerieke 0

- Op 26 oktober bevestigt de gebruiker dat BrandMeister nu werkt. Nieuw gemeld: toggle-PTT valt soms na enkele seconden terug, bij gebruik van de numerieke 0.
- Codecontrole toont twee bedieningsroutes: Carbon hotkey en lokale Cocoa keyDown/keyUp-monitor. De bestaande latch voorkomt achtereenvolgende dubbele downs, maar geen volledig lokaal down/up-paar gevolgd door een vertraagd Carbon down/up-paar. Beide paren konden als twee toggle-gebaren worden verwerkt. Daadwerkelijke gebeurtenisvolgorde op deze Mac is niet vastgelegd; dit is een concrete dubbele route met een plausibele foutvolgorde, geen bewezen oorzaak van elke terugval.
- Carbon is nu de enige route die PTT-gebaren afgeeft. De lokale monitor onderschept eventuele gewone keypad-0-events zonder de zendstatus opnieuw aan te sturen. Registratie, toetsrelease, focusgedrag, hold-modus en 180-s-limiet blijven behouden. Het log vermeldt de aanleiding bij handmatig stoppen. Encoder-, microfoon- en netwerkfouten houden hun bestaande meldingen en stopgedrag.
- Lokale PTT-lifecycletest uitgebreid met 25 herhaalde downs in toggle, release/focusbehoud en de stopreden bij de volgende druk. Tests gebruiken een geïnjecteerde toetsregistratie; echte Carbon/Cocoa-aflevering in voor- en achtergrond moet door de gebruiker worden bevestigd.
- Volledige Fusion/DMR-testreeks geslaagd. 0.4.3 build 18 geïnstalleerd en gestart via het bouwscript; strenge codesign-verificatie, procescontrole en geïnstalleerd versienummer gecontroleerd. Native UI-inspectie liep opnieuw vast op een time-out. Geen live aanmelding of radio-uitzending uitgevoerd. De gebruiker moet fysiek toetsenbordgedrag en het verdwijnen van de terugval nog bevestigen.

## Versie 0.4.4 — herstel bij microfoonstart zonder audio

- Gebruikerslog toont herhaaldelijk PTT AAN, na circa twee seconden nul AMBE-blokken/bufferpiek nul, daarna 'Geen microfoonaudio ontvangen'. Tijdens die starts ontbreekt ook de eerste tapcallbackmelding. BrandMeister blijft verbonden. Dit bevestigt voor deze gevallen de microfoon-startbeveiliging als stopreden; de precieze CoreAudio/PUC2-oorzaak is nog niet bewezen. Andere regels met gewone PTT UIT zonder fout geven onvoldoende informatie over hun aanleiding.
- Audio-engine wordt expliciet voorbereid vóór starten. Tijdens PTT controleert een eenmalige timer na één seconde of enig microfoonaudioblok is ontvangen (ook digitale stilte). Zo niet: uitsluitend de microfooningang één keer opnieuw openen. Nieuwe capture-token sluit callbacks van de oude ingang uit. Geen nieuwe netwerkheader of heraanmelding, geen AMBE-reset tijdens deze poging. Bestaande twee-secondenbeveiliging en monotone 180-s-limiet blijven ongewijzigd.
- Stoppen, afronden, herstel van een andere fout of ontkoppelen annuleert de timer. Geen onbeperkte herstelpogingen en geen automatisch opnieuw inschakelen na een beëindigde uitzending.
- Lokale tests bootsen een start zonder callbacks na, leveren na de tweede start audio en controleren doorlopende stream zonder extra header/AMBE-reset en afwijzen van late callbacks. Extra controle voor twee mislukte starts en stoppen op de oorspronkelijke deadline; ontkoppelen voorkomt een late herstart. Geen publieke uitzending of hardwareopname voor deze tests.
- Volledige lokale tests geslaagd. 0.4.4 build 19 geïnstalleerd en gestart via het bouwscript; strenge codesign-verificatie en procescontrole geslaagd. Het verdwijnen van het probleem op de echte PUC2 moet nog worden bevestigd door de gebruiker.

## Versie 0.4.5 — ontvangst-AGC

- Ontvangst-PCM wordt vlak vóór de luidsprekerbuffer geregeld, voor zowel DMR als Fusion. Zend-PCM, AMBE-profielen, PTT en netwerkpakketten blijven buiten deze verwerking. De bestaande luidsprekervolumeregelaar werkt daarna via de player-volume.
- RMS-doelniveau 0,14; snelle gainverlaging 10 ms, gainverhoging 600 ms, maximaal 8× (+18 dB). Per audioblok wordt vooraf de piek bepaald; een veilige gainlimiet houdt alle samples onder 0,85 zonder de golfvorm hard af te kappen. Niet-eindige samples worden nul. Onder RMS 0,0032 wordt gain vastgehouden in plaats van verder verhoogd.
- Keuze 'Ontvangst AGC · automatisch volume' naast de ontvangstinstellingen; standaard aan, onthouden in UserDefaults. Uit omzeilt de verwerking volledig. Gain reset bij wisselen van de keuze, leegmaken/stoppen van playback en een audiogap groter dan 0,5 s. DSP-status blijft op de bestaande seriële audioqueue; geen extra audiotimer of netwerkwerk.
- Signaaltests: twee tonen met 20 dB niveauverschil bereiken circa dezelfde RMS; overgang van zacht naar vol niveau blijft meteen onder het piekplafond; snelle gainverlaging stabiliseert, ruispauzes verhogen de gain niet, digitale stilte blijft nul, versterkingslimiet/reset en NaN/Inf worden gecontroleerd. Hoorbare beoordeling met echte stations volgt door de gebruiker.
- Volledige Fusion/DMR-testreeks inclusief AGC geslaagd. 0.4.5 build 20 geïnstalleerd en gestart; strenge codesign-verificatie, procescontrole en geïnstalleerd versienummer gecontroleerd. Geen publieke uitzending of live radioverbinding voor de verificatie.

## Versie 0.4.6 — DMR-roepnaam tijdens ontvangst

- Roepnaamlookup voor ontvangen DMR-bron-ID via de officiële RadioID-endpoint /api/users?id=. De publieke antwoordindeling gecontroleerd met W1AW: numeriek id en callsign in results. Alleen ID en roepnaam worden verwerkt/bewaard; geen namen, adresvelden of credentials. Geen bulkdownload of meegeleverde database.
- ID staat onmiddellijk in beeld; gevonden call wordt asynchroon 'CALL · ID'. Eigen ID gebruikt de ingestelde eigen call; 9990 wordt 'Echo · 9990'. Onbekende ID's en netwerkfouten behouden het nummer. Netwerklookup staat buiten de audioklok. Een ID-vergelijking en taakannulering voorkomen overschrijven door vertraagde antwoorden van een vorige spreker, andere modus of gesloten verbinding.
- Actor beheert de ID/call-cache in Application Support/FusionLab/DMRCallsigns.json, maximaal 2000 gehoorde stations. Succes zeven dagen geldig; negatieve/ontbrekende lookup één uur terughoudend opnieuw geprobeerd. Oude bekende call blijft bij netwerkfout beschikbaar. HTTP-time-out acht seconden. RadioID-User-Agent identificeert FusionLab en PA3EKE.
- Lokale tests met geïnjecteerde antwoorden controleren parsing, overeenkomend ID, cache/hergebruik na herstart, negatieve cache, uitzonderen van service-ID, snelle wisseling van spreker en laat antwoord na ontkoppelen. Netwerk-/audiotests gebruiken geen live lookup; publieke endpointproef gebruikte alleen W1AW, geen gebruikerscredentials.
- Volledige lokale testreeks geslaagd, inclusief AGC en de bestaande Fusion/DMR-/PTT-tests. 0.4.6 build 21 geïnstalleerd en gestart; strenge codesign-verificatie, procescontrole en geïnstalleerd versienummer gecontroleerd. Weergave tijdens echte DMR-ontvangst volgt door de gebruiker.

## Versie 0.4.7 — ontvangen call naar QRZ

- De ontvangen stationsweergave gebruikt een native SwiftUI Link voor een geldige roepnaam. Opent https://www.qrz.com/db/CALL in de standaardbrowser; portable '/' wordt URL-gecodeerd. De officiële URL-indeling gecontroleerd met de openbare W1AW-pagina.
- Alleen de call vóór het DMR-ID wordt in de URL gebruikt. Een numeriek ID, Echo 9990 en wachttekst blijven gewone tekst. Ook een ontvangen Fusion-call krijgt de link. Tijdens zenden blijft de eigen-callweergave gewone tekst. Geen automatische browseropening of QRZ-aanmelding; geen QRZ-credentials gebruikt.
- 0.4.7 build 22 gebouwd, geïnstalleerd en gestart. Strenge codesign-verificatie, procescontrole en geïnstalleerd versienummer geslaagd. Voor deze kleine weergavewijziging is de volledige radiotestreeks niet opnieuw uitgevoerd.

## Versie 0.4.8 — ontvangst-EQ laag/midden/hoog

- Drie onthouden regelaars −12…+12 dB met Neutraal-knop, standaard 0 dB. Laag: 300-Hz low shelf, midden: 1-kHz peaking met Q=1, hoog: 2,2-kHz high shelf. Shelf slope S=1. Eigen biquadimplementatie op basis van de formules uit het W3C Audio EQ Cookbook (Robert Bristow-Johnson), met double-precision filterstatus en 20-ms-overgang tussen instellingen.
- Verwerking alleen op ontvangen mono 8-kHz-PCM, vóór ontvangst-AGC en luidsprekervolume. Neutrale EQ geeft samples exact door. AGC begrenst EQ-pieken; bij AGC uit beperkt een blokgewijze gainverlaging pieken tot 0,95 zonder hard afkappen. Ook de overgang terug naar neutraal valt onder die bescherming. Geen microfoon-/zendroute aangepast.
- Filterstatus reset na ontvangstgat >0,5 s, playbackreset en stoppen. Regelaars blijven tijdens luisteren instelbaar. UI gebruikt drie kolommen binnen de bestaande scrollbare ontvangstsectie.
- Signaaltests meten boost en cut van elke band en controleren dat verre frequenties nagenoeg ongewijzigd blijven. Verder: exacte neutrale doorgifte, 200 live wijzigingen op uiterste waarden, eindige samples en AGC-piekgrens, terugzetten naar neutraal, veilige grenzen en onthouden instellingen. Geen publieke uitzending voor deze controles.
- Volledige lokale testreeks geslaagd. 0.4.8 build 23 geïnstalleerd en gestart; strenge codesign-verificatie, procescontrole en geïnstalleerd versienummer gecontroleerd. Hoorbare beoordeling met echte stations volgt door de gebruiker.

## Versie 0.4.9 — EQ-bypass

- Bypass-keuze naast Ontvangst EQ, met onthouden status. Bij bypass krijgt de filterbank de neutrale instelling via de bestaande 20-ms-overgang; de bewaarde laag-/midden-/hoogwaarden blijven intact. Na uitschakelen worden de bewaarde waarden opnieuw toegepast.
- EQ-regelaars en Neutraal worden tijdens bypass grijs/inactief; de Bypass-keuze zelf blijft bedienbaar. Ontvangst-AGC en luidsprekervolume blijven onafhankelijk ingesteld. De bestaande neutrale-doorgifte- en overgangstests blijven van toepassing.
- Volledige lokale testreeks geslaagd. Definitieve UI-bron met bedienbare Bypass-keuze gebouwd; 0.4.9 build 24 geïnstalleerd en gestart. Strenge codesign-verificatie, procescontrole en geïnstalleerd versienummer gecontroleerd.
