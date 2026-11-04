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

## Versie 0.4.10 — langdurig luisteren en verbindingsbewaking

- Gebruikerslog toont tot 22:35:11 ontvangst en om 22:35:32 de bestaande melding 'geen keepalive-antwoord binnen 20 seconden'. Geen master-NAK of expliciete master-close in dat fragment. Daarmee staat de time-out vast, maar niet of netwerk/server of een vertraagde client de oorzaak was. Het bestaande log was al tot 250 regels begrensd; onbeperkte groei is dus niet aangetoond.
- BrandMeisterConnection serialiseert handshake, ping, pong en time-outs nu op de bestaande netwerk/audioqueue, met eigen DispatchSourceTimer en monotone tijd. Alleen status-/foutmeldingen gaan naar main. Het venster hoeft geen keepalive-timer meer aan te sturen of pongs te verwerken. Stop/reset/fout beëindigen de timer; generatiecontrole onderdrukt callbacks van een vorige verbinding. Werkelijk wegvallen van antwoorden behoudt de 20-s-stopbeveiliging.
- Log beperkt tot 100 regels en maximaal 512 berichttekens per regel, hergebruik van DateFormatter. Uitklapbare, standaard gesloten logweergave met vaste 140-punt scrollhoogte; Equatable-view tekent alleen opnieuw als de logtekst verandert. Wissen kan tijdens ontvangst zonder verbindingstoestand te wijzigen.
- Regressieproef gebruikt een versnelde monotone protocolklok en blokkeert de echte main-thread langer dan twintig protocolseconden. Ping/pong moeten in die periode doorgaan. Daarna worden antwoorden bewust weggelaten om echte time-out en timerstop te controleren. Logproef met 5000 berichten controleert grens, behoud van de nieuwste regels, lange invoer en wissen tijdens actieve sessie. Geen live netwerkverbinding of uitzending voor deze tests.
- Wijzigingen staan op de lokale tak experimenten; bewaarpunt v0.4.9 en de privérelease blijven intact.
- Volledige lokale testreeks geslaagd, inclusief keepalive bij geblokkeerde main-thread, echte time-out bij ontbrekende pongs, 5000 logmeldingen, Fusion/DMR, PTT en ontvangst-DSP. 0.4.10 build 25 geïnstalleerd en gestart; strenge codesign-verificatie, procescontrole en geïnstalleerd versienummer gecontroleerd. Praktijkgedrag tijdens een lange luistersessie moet nog door de gebruiker worden bevestigd; een netwerk-/masterstoring blijft mogelijk.

## Versie 0.4.11 — lokale MD380-vocoder als alternatief

- Aangeleverde map bevat C-bron, header, README en Makefile; geen firmware. README vereist ARM-platform. Makefile koppelt twee beelden op 0x0800C000 en 0x20000000 en noemt de codec-entrypoints. Native 32-bits Thumb-code kan niet direct in het arm64-Mac-proces worden aangeroepen.
- Geïsoleerde Python/Unicorn-proef op Cortex-M4, met de in de bron beschreven functieargumenten: tien synthetische 440-Hz-frames gecodeerd en gedecodeerd, eerste 49-bits frame f8fe14398c5080, niet-nul PCM, circa 0,070 s totaal. Geen microfoon, AMBEserver, master of radio-uitzending voor die proef.
- Eigen C++-adapter met dynamisch geladen Unicorn 2.1.4 en gescheiden encoder-/decoderinstanties. Uitvoering begrensd op 50 ms / twee miljoen instructies per firmwareaanroep, geldige terugkeer vereist. RAM/ROM/stack alleen binnen emulator gemapt. 49/72-bit framing afgesplitst uit de aangeleverde GPL-bron, met behoud van auteursvermelding.
- Lokale runtime geïnstalleerd in Application Support/FusionLab/MD380. Firmware SHA-256 fw c0351f250a834660641bca3b06be931c80cc1ed0ef808356c550b99cd0f4c632 en ram d40398183e9aa8db6288a62d9a0e0c233cb143ef5633680abd829cc03c719f66. Geen firmware in repo of app, geen nieuwe upload naar GitHub.
- VocoderTransport houdt de bestaande DV3K-grens aan: controles, 160 PCM-samples, 49-bit Fusion en 72-bit DMR. AMBEserver blijft via UDPLink lopen; MD380 opent geen AMBEserversocket. Picker in verbindingen, onthouden keuze, wijziging geblokkeerd tijdens een verbinding. Serveradres/exclusiviteit alleen bij AMBEserver vereist. PTT, klok, netwerkcode, EQ en AGC blijven gedeeld.
- Eerste native C++/Swift-test: 120 encode/decode-frames in 0,775 s (voor 2,4 s audio), gedecodeerde piek 1223. Eerste gecodeerde frame gelijk aan Python-proef. Verder FEC-rondgang en volledige DV3K-controle/spraak heen-en-terug voor beide bitformaten zonder server. Hoorbare kwaliteit op echte stations moet de gebruiker nog bevestigen.
- Definitieve volledige tests geslaagd. MD380 native ronde op deze run 120 frames in 1,687 s, nog binnen 2,4 s audio. Extra volledige RadioSession-proef: lokale DMR-master accepteert aanmelding, MD380 encodeert 15 blokken naar vijf voice-pakketten plus header/einde; dezelfde spraak wordt als privé-echo teruggestuurd en levert 15 gedecodeerde PCM-blokken. Serverhost en -poort zijn bewust ongeldig en exclusiviteit uit, zodat de test geen AMBEserver kan gebruiken. Wisselen van vocoder tijdens verbinding blijft geblokkeerd. Geen publieke master of echte microfoon voor de test.
- 0.4.11 build 26 geïnstalleerd en gestart. Emulatorbibliotheek lokaal in Contents/Frameworks opgenomen en ondertekend; strenge diepe codesign-verificatie geslaagd. Native UI weer bereikbaar: Vocoder-menu toont AMBEserver en MD380 · lokaal; lokale keuze verbergt servervelden/exclusiviteitsvinkje en maakt Verbinden beschikbaar. Alleen de keuze gecontroleerd, niet verbonden of gezonden. Daarna AMBEserver hersteld als oorspronkelijke keuze. België 2061, DMR-ID, bestemming, PUC2-kanaal/gain en EQ-waarden bleven behouden; wachtwoordveld leeg. Hoorbare echo-/stationtest volgt door de gebruiker.

## Versie 0.4.12 — keuze TX-limiet en laatste-tien-secondenlampje

- Keuze 2 of 3 minuten naast PTT, onthouden in UserDefaults, standaard drie. De limiet wordt vóór de microfoonaanvraag vastgelegd en als waarde naar de audioklok doorgegeven. De lopende uitzending kan daardoor niet verlengd worden door een latere wijziging. Bedieningskeuze uitgeschakeld tijdens voorbereiden/zenden/afronden.
- De bestaande monotone deadline gebruikt nu 120 of 180 seconden, voor Fusion en DMR en voor beide vocoderkeuzes. Ook gebufferde audio/afronden eindigt op de grens. Stopmelding vermeldt de werkelijk gekozen duur. Een ingedrukte numerieke toets start na time-out niet vanzelf opnieuw.
- Afzonderlijk rood lampje naast de afteller knippert een keer per seconde (halve seconde aan/uit) als resterende tijd 1–10 seconden is en er wordt gezonden. TimelineView stopt zijn updates buiten de waarschuwing; kleur-/knipperstatus wijzigt de native PTT-knop niet. Toegankelijke tekst meldt de resterende seconden.
- Kloktests dekken beide limieten bij beide netwerkformaten: resterende 10/1/0 seconden, geen vroege stop, harde stop op de grens ondanks teruggezette kalenderklok en resterende encoderbuffer, precies één eindpakket en geen verlenging door een tweede startaanroep. Geen publieke uitzending voor deze tests.
- Volledige lokale testreeks geslaagd, inclusief MD380 en AMBEserver-routes. 0.4.12 build 27 geïnstalleerd en gestart; strenge codesign-verificatie en procescontrole geslaagd. Werkelijke UI toont beide tijdkeuzes; 2 minuten geselecteerd en weergegeven, daarna oorspronkelijke 3 minuten hersteld. Geen verbinding of uitzending gestart voor UI-controle; knipperen tijdens een echte uitzending moet nog door de gebruiker worden beoordeeld. MD380-keuze en bestaande radio-/audioinstellingen bleven behouden. Bewaarpunt v0.4.9 blijft intact.

## Versie 0.4.13 — acht voorkeuzes per mode

- Gebruiker koos zowel Fusion/YSF-reflectoren als DMR-talkgroups. MacDV README en de snelkeuzebediening in MacDVApp/main.m via GitHub geraadpleegd als gedragsvoorbeeld; de nieuwe SwiftUI-implementatie heeft acht vaste posities per mode, onafhankelijk opgeslagen.
- Klik op lege toets bewaart huidige reflector of DMR-bestemming. Menu Bewaar huidige vervangt een gekozen positie; contextmenu heeft naam wijzigen, wissen en bij Fusion de bestaande reflectorzoeklijst. Bekende Echo PA7LIM / TG204 / TG91 / privé9990 als enkele beginwaarden, overige posities leeg. Geen credentials of vocoderinstellingen in de voorkeuzes.
- Losgekoppeld: Fusion vult alleen host/poort in. Gekoppeld: eerst YSF-unlink versturen, daarna netwerkendpoint vervangen en ontvangstbuffer wissen, met behoud van vocoder. Token/closing-controle voorkomt uitvoeren van een oude wisselcallback na ontkoppelen. Een DMR-toets wijzigt alleen destination/privateCall voor de volgende PTT; master/slot/ID blijven staan. Activeren tijdens PTT/voorbereiden/afronden is geblokkeerd.
- Lokale tests: acht posities, opslag/herladen, modes gescheiden, wissen, corrupt/verkeerd-mode-invoer, DMR bestemming wijzigen zonder TX, blokkade tijdens TX. Twee lokale YSF-servers plus fake-AMBE bewijzen één unlink naar de oude reflector, poll naar de nieuwe, geen spraakpakketten, en één behouden vocoderverbinding zonder reset. Volledige bestaande tests geslaagd, inclusief MD380, beide TX-limieten en ontvangst-DSP.
- Bij native schermcontrole bleek build 28 vóór vensteropbouw vast te staan. Een processteekproef wees op RadioSession.init → DMRPasswordStore.read → SecItemCopyMatching → SecurityServer decrypt/wachten. Geen drukke CPU/lange log of voorkeuzelayout: init deed een synchrone Sleutelhangeropvraag. Lezen nu pas na onAppear op een eigen queue; alleen het resultaat gaat naar main en overschrijft nooit inmiddels getypte tekst of een veranderd ID/actieve verbinding. Automatisch ophalen vraagt niet om interactie; expliciet Ophalen kan de normale macOS-toestemming tonen. Het venster blijft ook bij een trage Sleutelhanger bereikbaar. Wachtwoordinhoud niet uitgelezen via tools of gewijzigd.
- Extra regressie met vertraagde geheugenopslag controleert geen leesactie tijdens constructie, één automatische achtergrondpoging, behoud van gelijktijdig getypte tekst en expliciet ophalen. De teststore is voor de nieuwe achtergrondlezing vergrendeld. Definitieve buildnummer 29 binnen versie 0.4.13.
- Bij nog lopend ophalen gebruikt een handmatig ingevuld wachtwoord uitsluitend RAM voor die verbinding; er wordt dan niet tegelijk een tweede Sleutelhangerbewerking op de hoofdthread gestart. Definitieve build verhoogd naar 30. Volledige tests opnieuw geslaagd, inclusief wachtwoordophalen, voorkeuzes, reflectorwissel, DMR/MD380, ontvangst-DSP en beide zendtijdlimieten.
- Native UI met de opstartcorrectie gecontroleerd: acht DMR-toetsen en acht Fusion-toetsen zichtbaar, contextmenu en naamvenster beschikbaar. Naamvenster geannuleerd zonder gegevenswijziging en oorspronkelijke DMR-modus hersteld. Geen echte verbinding of uitzending gestart tijdens deze controle.

## Versie 0.5.0 — transceiverinterface

- Uitgevoerd naar gebruikersprompt en conceptafbeelding, na inventarisatie en volledige reservekopie `FusionLab-backups/before-console-20261027-230542.tar.gz`. Bestaand onvastgelegd werk intact. Gedetailleerd bestandsoverzicht en architectuurkeuzes in UI_IMPLEMENTATION.md.
- Hoofdscherm met modusrail (DMR/C4FM, D-STAR expliciet niet beschikbaar), echt stations-/RX/TX-display, acht bestaande voorkeuzes, geheugenknop met expliciet toepassen, ontvangstvolume/AGC/EQ/bypass, microfoon en grote native PTT. Setup en Engineering apart bereikbaar. Minimaal venster 940×640, standaard 1120×740; scroll bij weinig hoogte.
- Alle bestaande backendmodellen, services en codecbronnen byte voor byte vergeleken met het herstelarchief: geen verschillen. De selector roept uitsluitend bestaande voorkeuzeacties aan; scroll/drag zelf zendt of verbindt niet.
- Volledige lokale regressietests geslaagd; MD380 120 encode/decodeframes in 1,698 s. PTT-renderingregressie behouden plus werkelijke knophoogte 86 en breedte145 in native hostingwindow gecontroleerd. Beide tijdlimieten en alle eerdere netwerk/audio/PTT-tests blijven slagen.
- Native schermcontrole: beide modes, acht toetsen, contextmenu, Setupvelden, Engineering/log en klein venster met bereikbaar footer gecontroleerd. Normale desktopmaat toont dagelijkse bediening zonder verticale scroll. Geen verbinding of uitzending op een publiek netwerk gestart. Hoorbare hardwareverificatie door gebruiker nog nodig.
- 0.5.0 build31 geïnstalleerd en gestart; diepe strenge codesign-verificatie geslaagd. Baseline0.4.9 en MacDV ongewijzigd; geen publicatie naar GitHub.

## Versie 0.5.1 — trage console

- Gebruiker meldde traagheid. Proces 0.5.0 build31 circa120% CPU; sample wees op langdurige SwiftUI-layout/alignments op de hoofdthread. Schermuitlezing liep tegen30s timeout. Alleen verwijderen van een teruggekoppelde minimumhoogte was onvoldoende.
- Rootlayout geeft nu expliciete beschikbare breedtes aan het centrum en beide onderste panelen. Geen hoogte-terugkoppeling via GeometryReader meer. Audiometers/pakkettellers invalidereerden bovendien alle ObservedObject-panelen. Nieuwe ConsoleRenderState/ConsoleRegionView geven paneel-specifieke, onveranderlijke vergelijkingswaarden; alleen relevante paneelwijzigingen gaan door. Bindingen blijven direct naar dezelfde RadioSession schrijven. Geen onafhankelijk radiomodel of vertraagde veiligheidsstatus.
- EQ-subpaneel heeft eigen vergelijkingswaarden, zodat bypass, disable-status en bandwaarden ook na de optimalisatie actueel blijven. Knipperplanning bestaat alleen tijdens de echte laatste-tien-secondenwaarschuwing; daarbuiten geen TimelineView.
- Volledige bestaande lokale regressietests geslaagd; MD380120frames in1,715s. Native UI: 0.5.1, EQ-bypass schakelt de daadwerkelijke regelaarstatus, PTT-mode tekst/schakelaar volgt, oorspronkelijke bypass-uit/toggle-aan hersteld. TG91, EQ-9/0/+7, gain+2, PUC2kanaal1 en 2min bleven behouden. Schermuitlezing doorgaans0,2–0,6s, ook nadat de gebruiker zelf BrandMeister verbond; agent startte geen publieke verbinding of uitzending.
- Rustmeting na paneeloptimalisatie: CPU-tijd0,93→0,94s over6s, ps0%. Dit is geen claim over vocoderbelasting tijdens ontvangst: de gebruiker verbond tussendoor zelf, en een later profiel bevatte tevens echte audio-/codecactiviteit. Geen live ontvangst stilgelegd voor de meetproef.
- Afzonderlijke native consoleproef buiten het scherm, zonder sockets/microfoon/Sleutelhanger:120bursts met pakket-, meter- en stationswijzigingen. Oorspronkelijke bron Project-e01cc3a0f685484859e3 haalde de20s-watchdog; verbeterde UI voltooide in4,770s met2,161s proces-CPU. De opzettelijke50Hz-updatebelasting en geforceerde layout zijn zwaarder dan gewone gebundelde10Hz-meters; geen representatieve hardwarebenchmark.
- Reproduceerbare probe in script/probe_console_ui.py en script/console_performance_probe.swift. Probe wordt niet opgenomen in de app. python3 script/probe_console_ui.py; optioneel --source /pad/naar/onveranderlijke/bron voor vergelijkingen. Tijdmetingen zijn diagnostisch, geen vaste snelheidsassertie.
- FileProvider blokkeerde tijdens bronverzameling ongewijzigde Unicorn-headers. Daarom is gebouwd vanuit de reeds gecontroleerde lokale volledige bronsnapshot met alle actuele UI-bestanden en huidige buildscript/tests eroverheen. De broncorrecties staan ook in de oorspronkelijke werkmap. Geen veranderingen aan services, modellen, DSP, codec- of netwerkbronnen.

## Versie 0.5.2 — Fusion met lokale MD380

- Gebruiker vergeleek dezelfde Fusion/YSF-verbinding: AMBEserver verstaanbaar, MD380 lokaal onverstaanbaar. Bronvergelijking met DroidStar ysf.cpp: decode_dn past dvsi_interleave uitsluitend voor hardware-RX toe; de software/MD380-decoder krijgt de oorspronkelijke A12/B12/C25-bitvolgorde. Voor TX geldt de omgekeerde grens. Onze YSFCodec levert bewust altijd DVSI-volgorde, omdat die route met AMBE3000R werkt; de lokale adapter behandelde die ten onrechte als native MD380-parameters.
- AMBE49BitOrder converteert de 49 bits uitsluitend bij VocoderTransport↔MD380: DVSI naar native vóór decode en native naar DVSI na encode. Ongebruikte zeven paddingbits zijn nul. DMR72 blijft via de bestaande FEC-code lopen; netwerkframing en AMBEserver zijn niet gewijzigd.
- Referentie: https://github.com/nostar/DroidStar/blob/main/ysf.cpp, decode_dn/interleave en encode_dv2 (geraadpleegd 29 oktober 2026). De mapping was al aanwezig in YSFCodec/Bridge.cpp; de noodzakelijke omzetting bij de lokale vocoder ontbrak.
- Nieuwe vaste native/DVSI-vectoren, pad-/lengtecontrole en de onafhankelijk gegenereerde bestaande DroidStarTX voice-fn0-fixture. Die laatste geeft DVSI 0b30557a9fc480, waarvoor MD380 216e9cb3115b80 moet ontvangen. De bestaande native firmwarevector f8fe14398c5080 moet op de DVSI-grens be6841db4be000 worden.
- DV3K-transporttest vergelijkt twintig gedecodeerde frames exact met een afzonderlijke native MD380-referentiedecoder, bij beide bitformaten. Daarnaast wordt gecontroleerd dat de Fusion-encoder DVSI en niet de oorspronkelijke native parameters aanbiedt. Eerdere uitsluitend lokale encode/decode-rondgangen konden de ontbrekende wederzijdse grensomzetting maskeren.
- Herstelkopie van de gewijzigde bestaande bestanden: FusionLab-backups/md380-fusion-20261029-091624. Geen publicatie naar GitHub.
- Ter verduidelijking van de eerdere microfoonproef: gebruiker meldde dat de input fysiek los zat en dat audio daarna weer werkte. De toen waargenomen mono-ingang was daarmee niet aangetoond als oorzaak. Er is geen speculatieve kanaalformaatcorrectie toegepast; build33 bevatte alleen numerieke ingangdiagnostiek.
- Definitieve volledige testreeks geslaagd. In de nieuwe on-air-fixturecontrole was aanvankelijk het significante 49e bit verkeerd overgenomen in de verwachte constante; de vaste fixture toonde dit aan en de verwachting is gecorrigeerd. Productieomzetting bleef gelijk. Native MD380120frames1,670s; nieuwe vaste-vector- en DV3K-referentiecontroles, DMR/FEC, PTT, deadlines, ontvangst-DSP en de overige bestaande regressies slagen.
- 0.5.2 build34 geïnstalleerd en gestart via de bestaande procedure; strenge diepe codesign-controle geslaagd. Native UI bereikbaar, MD380 lokaal / Fusion geselecteerd. Geen echte uitzending door de agent gestart. Hoorbare ontvangstbevestiging door de gebruiker volgt na de correctie.

## Versie 0.5.3 — direct DMR/C4FM wisselen

- DMR/C4FM-knoppen op de modusrail en de modekeuze in SETUP gebruiken requestMode. Losgekoppeld verandert alleen de selectie. Gekoppeld worden doelinstellingen vooraf gevalideerd, vervolgens wordt de oude verbinding afgerond en met dezelfde vocoderkeuze automatisch opnieuw verbonden. De reeds gegeven AMBEserver-exclusiviteitsbevestiging blijft binnen deze overgang behouden. Geen nieuwe PTT of uitzending door de modekeuze.
- Eén gepubliceerde modeSwitchTarget bewaakt de overgang tot netwerk gereed is. Footer toont voortgang en Annuleren. Wisselen is geblokkeerd tijdens voorbereiden/zenden/afronden, ingedrukte PTT, reflectorwissel of een andere modeovergang. Voorkeuzes zijn tijdens de overgang eveneens geblokkeerd. Explicit disconnect/shutdown/failure annuleert elke wachtende herverbinding.
- Disconnect-completion en de bestaande200ms-fallback krijgen een unieke token. finish controleert token/active/closing voordat hij state verandert. Daardoor kan de vertraagde afsluiter van een eerdere YSF/DMR-verbinding geen nieuwe verbinding sluiten of stationsinformatie wissen.
- Bestaande lokale BrandMeister/AMBEserver-test uitgebreid: geblokkeerde wissel tijdens echte gesimuleerde PTT, DMR→Fusion→DMR met profielen72→49→72, één nieuwe aanmelding per mode, behouden serverkeuze/exclusiviteit, geldige audio/TX, ongeldig doel laat bestaande verbinding werken, annuleren voorkomt automatisch verbinden en idle selectie verbindt niet. Wachttijd350ms na elke overgang controleert oude afsluitcallbacks.
- Bestaande echte lokale MD380-emulatortest uitgebreid met DMR→Fusion→DMR tegen een lokale UDP-master/reflector, met behoud van MD380-keuze zonder AMBEserver/exclusiviteit. Beide overgangen worden zendklaar en blijven na350ms actief.
- Volledige regressiereeks geslaagd, inclusief Fusion-bitvolgorde/interoperabiliteit, DMR, beide vocoders, PTT/timers en ontvangst-DSP. MD380120frames1,686s. Geen verbinding met een publieke master/reflector of echte uitzending door de agent nodig voor deze tests.
- Herstelkopie vóór wijziging: FusionLab-backups/mode-switch-20261029-151245. Geen GitHub-publicatie of wijziging aan MacDV.
- 0.5.3 build35 geïnstalleerd en gestart; strenge diepe codesign-controle via de buildprocedure geslaagd. Native hoofdscherm toont0.5.3 en direct bedienbare DMR/C4FM-knoppen. Losgekoppeld beide keuzes gecontroleerd; DMR als oorspronkelijke mode hersteld. Geen publieke verbinding of uitzending gestart voor de schermcontrole.

## Versie 0.6.0 — NXDN4800

- NXDN als derde mode toegevoegd: apart NXDN-ID, TG, host/poort en RAN; geen afleiding van het DMR-ID. Gebruiker gaf NXDN-ID41007. NXDNReflector ondersteunt hier uitsluitend onversleutelde groepsspraak bij4800; private/data/trunking/NXDN9600 zijn niet geïmplementeerd.
- NXDNP/NXDNU17bytes, NXDND43bytes, LICH, dubbele Layer3-header/trailer en SACCH CRC6 gecontroleerd tegen DroidStar nxdn.cpp en G4KLX NXDNNetwork.cpp. Matching poll-echo gecontroleerd tegen nostar/DVReflectors NXDNReflector.cpp. Ontvangst valideert lengte, signatuur, flags, LICH, CRC en bestemming. Header/trailer gaan niet als spraak naar de decoder.
- Netwerk bevat vier AMBE49-blokken per80ms, in native bitvolgorde; de bestaande DVSI/native-permutatie wordt aan de netwerkgrens toegepast. Beide vocoderkeuzes behouden hun bestaande gemeenschappelijke DVSI-grens en2450/49-profiel. Geen verandering aan de codec-emulator, DMR-FEC of Fusion-payloadcode.
- Doorzoekbare reflectorselectie met drie startrecords en handmatig bijwerken via Pi-Star/DVRef. Originele directory met bronvermelding wordt lokaal gecachet. Acht afzonderlijke NXDN-voorkeuzes. Live reflectorwissel gebruikt de bestaande token-beveiligde modeovergang met dezelfde vocoder; unlink blijft het oude TG uit connectionProfile gebruiken. Geen PTT door selecteren of bijwerken.
- Vaste header/end/alle vier SACCH-fases en vier onderling verschillende cross-byte spraakblokken vergeleken met een onafhankelijke bytegeoriënteerde referentiegenerator op basis van DroidStar. Lengte/signatuur/CRC/duplicaatcontroles, foutieve ID-invoer, hostparser/cache/foutafhandeling en gescheiden voorkeuzestorage getest.
- Lokale UDP-reflector plus gesimuleerde AMBEserver: volledige initialisatie, acht ontvangen/gedecodeerde blokken, identieke stilte niet weggefilterd, andere TG en ongeldige data genegeerd; vijf microfoonblokken plus drie paddingblokken leveren header/twee voicepakketten/terminator;80ms-pacing, reflectorwissel, oude-TG-unlink en Fusion↔NXDN getest. Geen publiek netwerk gebruikt.
- Echte lokale MD380-emulatortest uitgebreid: DMR→NXDN, acht encodeblokken in twee voicepakketten en terug naar acht PCM-blokken. De eerste proef stuurde de echo naar de oude DMR-testsocket; test gecorrigeerd naar de nieuwste verbinding. Geen productiecorrectie daarvoor nodig. Beide2/3min monotone deadlines nu ook met NXDN getest.
- Definitieve volledige script/test.sh geslaagd, inclusief alle bestaande DMR/Fusion/audio/PTT-tests. MD380120frames in1,705s. Hoorbare ontvangst/TX via een echte NXDN-reflector moet door de gebruiker nog worden bevestigd.
- Herstelkopie vóór wijziging: FusionLab-backups/before-nxdn-20261029-161053. MacDV en de vastgelegde baseline0.4.9 niet gewijzigd; geen GitHub-publicatie.
- 0.6.0 build36 geïnstalleerd en gestart met geslaagde strenge diepe codesign-verificatie. Bestaande BrandMeister-verbinding vooraf via Ontkoppelen beëindigd. Native UI: NXDN-knop, apart ID41007, TG204/RAN1, acht eigen toetsen, correcte NXDN-tellertekst en Setup gecontroleerd. ID41007 ook in de opgeslagen appvoorkeur bevestigd.
- Native Lijst bijwerken haalde342 reflectoren op; filter en selectie TG204 werken. App staat losgekoppeld op NXDN klaar; AMBEserverkeuze en bestaande audio/PTT-voorkeuren behouden. Geen publieke NXDN-verbinding of echte uitzending gestart.

## Versie 0.6.1 — roepnaam bij NXDN-ontvangst

- Gebruiker bevestigde dat NXDN-audio in0.6.0 goed werkt en vroeg om de call van het tegenstation. NXDNStationSource bewaakt nu het bron-ID onafhankelijk van DMR. Het ID verschijnt direct; de aparte NXDN-lookup vult asynchroon call · ID in. Volgende pakketten van dezelfde spreker wissen de gevonden call niet meer. De bestaande QRZ-link volgt automatisch de gevonden call.
- Aparte RadioID NXDN-export via HTTPS; uitsluitend ID/call-paren behouden in eigen NXDNCallsigns.json. Geen DMR-ID-lookup voor NXDN. Dagcache, gedeelde lopende download voor gelijktijdige aanvragen,15min fout-backoff, bekende calls behouden bij mislukte refresh, geen extra persoonlijke CSV-kolommen in de cache.
- Modewissel en disconnect annuleren de bijbehorende UI-opzoekactie; een later antwoord mag alleen bij dezelfde actieve NXDN-spreker de stationsregel bijwerken. Audioqueue en packet pacing ongewijzigd.
- Productie-opzoekcode afzonderlijk gecompileerd en op de echte openbare bron gecontroleerd: het zojuist ontvangen NXDN-ID4141 werd opgelost naar PA2JM. Deze probe gebruikte een tijdelijke cache en geen reflectorverbinding of uitzending.
- Volledige regressiereeks geslaagd, inclusief nieuwe NXDN-directory/callweergavetests: concurrente lookup deelt één download, onbekende en ongeldige IDs, gecachte calls na herstart, mislukte update bewaart oudere calls, geen persoonlijke extra kolommen in cache, verouderde sprekerreactie en late disconnect-reactie geblokkeerd. NXDN UDP-audiotest toont call/QRZ en behoudt die over meerdere voicepakketten. MD380120frames1,686s.
- 0.6.1 build37 geïnstalleerd en gestart, strenge diepe codesign-verificatie via buildscript geslaagd. FileProvider vertraagde het opnieuw lezen van ongewijzigde YSFConvolution.h; de oorspronkelijke bronkopie voltooide alsnog. Appbronnen zijn bovendien bytegelijk bevonden aan de geteste lokale snapshot; geen alternatieve installatie of bronwijziging nodig.
- Native livecontrole na de update: op TG205 verscheen tijdens echte NXDN-ontvangst de klikbare call PA3EHA · 4163 met QRZ-link naar PA3EHA. App was bij deze controle alweer verbonden, MD380 als eerder gekozen backend. Geen PTT of echte uitzending door de agent gestart. Backup vóór deze wijziging in FusionLab-backups/before-nxdn-calls-20261029-163829; geen GitHub-publicatie.

## Versie0.7.0 — X-keys XK-24 en PTT zoals MacDV

- Uitgevoerde opdracht en gebruikerssturing: MacDV-XKeys-implementatie en volledige PTT request-set als basis onderzocht; zelfstandige Swift-componenten gebruiken dezelfde edge-/baseline-/ownership-principes. FusionLab's bestaande zendketen en protocollen blijven werken. Analyse vóór implementatie en alle details staan in Docs/XKEYS.md.
- Eén PTTRequests-bronregistratie voor GUI, numerieke0, menu en elke HID-toets. Independent source-release, hold/toggle, no repeats, timeout-latch, USB-removal/config-reset, emergency-stopprioriteit en sessie-/lockinhibitie. Geen tweede transmitter. Carbon0 blijft behouden.
- Werkelijke hardware gedetecteerd: XK-24 VID05F3/PID0405, Consumer Page12/Usage1 IN32/OUT35, aparte keyboard/mouse-interfaces. GetDescriptor en GenerateData geven IOReturn0 met echte32byte-responses, firmware38. Geen EEPROM/macro/PID-wijzigingen. Eigen asynchrone LED-queue.
- Setup → X-keys en macOS Settings:24 posities in4kolommen×6rijen; per-toetsactie en Hold/Toggle; defaults/wissen; persistentie; visuele keyfeedback; optionele LED-feedback; teststand zonder acties. Ondersteuning bij eerste gebruik uit.
- Definitieve volledige regressiereeks PASS met expliciete XK-24/ownership/USB/reconnect/inhibitie/emergency-registratie, plus alle bestaande audio/protocoltests; MD380120frames1,703s. Test-RadioSession gebruikte alleen lokale UDP-fixtures en synthetische microfoon. Geen publieke uitzending door de agent.
-0.7.0 build38 geïnstalleerd en gestart, strenge diepe codesign-controle geslaagd. Echte UI: matrix/actie-menu/toets24 PTT-toggle/wissen gecontroleerd en weer naar standaard-none teruggezet. Bestaande NXDN-ID41007, reflector/voorkeuzes, MD380, PUC2, EQ-bypass en PTT/timerinstellingen behouden.
- Een eerdere installatiepoging kreeg een race bij gelijktijdig maken van dezelfde immutable build-snapshot. Daarna test en installatie achter elkaar uitgevoerd; beide geslaagd. Geen productiebron of snapshot-script gewijzigd voor dat tijdelijke buildprobleem.
- Herstelkopie in de repository: .local-backups/before-xkeys-20261029-220519, uitgesloten via .gitignore. Geen wijzigingen aan MacDV/AMBEserver en geen GitHub-publicatie.
- Fysieke24-toets-, achtergrond-, LED- en lock/unlockproeven niet als geverifieerd opgevoerd: MacDV was nog actief en gebruiker is gevraagd die tijdelijk te sluiten voor het apart gebouwde lokale hardwaretestvenster. Testprocedure en gewijzigd-bestandenoverzicht in Docs/XKEYS.md.


### Fysieke acceptatie XK-24,30oktober2026

- Na reset doorgegaan op het verzoek van de gebruiker. MacDV gesloten; gewone FusionLab-X-keys tijdelijk uitgeschakeld om de bestaande echte NXDN-verbinding niet met testacties te bedienen. De eigen toewijzing toets24=hold behouden.
- Echte hardware in het afzonderlijke lokale testvenster: alle24 fysieke posities met down/up geregistreerd,24/24 zichtbaar. Hold/toggle en onafhankelijk bronbezit instrumenteel bevestigd; de gebruiker bevestigde kleuren. Noodstop3 bij actieve toggle-TX instrumenteel en door gebruiker bevestigd na een gerichte vervolgproef. Geen productiecorrectie voor deze melding nodig.
- Achtergrondwerking instrumenteel met Codex/Chrome; gebruiker meldt overige achtergrondgevallen werkend. USB-verlies/reconnect en lock/unlock door gebruiker bevestigd. Bewijsniveau per scenario staat expliciet in Docs/XKEYS.md.
- Het testvenster is met alleen testacties1/2/3 en15min maximale looptijd herbouwd. Productie-Swiftbronnen bytegelijk aan de reeds geteste0.7.0-snapshot; alleen de hardwareprobe en documentatie gewijzigd. Hergebruik van de lokale snapshot voorkwam opnieuw blokkeren op een ongewijzigde FileProvider-header.
- Logs bewaard onder Docs/TestResults/XKeys-20261030-initial.log en XKeys-20261030-extended.log. Testvenster gesloten; normale ondersteuning terug aan, firmware38/PID0405 gereed, indeling1/24 hold en2noodstop behouden. Gewone NXDN-verbinding na bestaande keepalivetimeout opnieuw met TG7300 verbonden; PTT gereed, geen echte uitzending door de agent.

## Versie 0.7.1 — lichtblauw LCD (30 oktober 2026)

- Herstelkopie vooraf: `.local-backups/before-lcd-20261030-124530/`; geen bestaande wijzigingen overschreven of gepubliceerd.
- Alleen visuele/presentatie-aanpassingen aan FusionLab. Nieuwe `RadioLCDView` met afzonderlijke call/ID, mode-afhankelijke informatie, bestaande QRZ-links, echte RX/TX/verbindingsstatus en 40 RMS-audiosegmenten op −60…0 dBFS.
- Kleuren volgens het aangeleverde ontwerp, donkere rand, technische systeemtypografie, vaste displayhoogte 232 punten. Standaard- en minimumvenstermaat behouden. Compactere binnenmarges en tussenruimtes laten op 1120 × 740 ook de onderste verbindingsbalk passen.
- Volledige regressiesuite geslaagd, inclusief nieuwe presentatie- en native LCD-rendertests; geen protocol-, audio-, vocoder-, PTT- of X-keys-code aangepast.
- Native offline consoleproef met alle drie bestaande modi op 1120 × 740, 940 × 640 en 1500 × 950; 120 geforceerde updates: 4,705 s wall / 1,958 s CPU. Voorbeelden staan onder `Docs/Screenshots/LCD-0.7.1-*`; het zijn gemarkeerde testgegevens zonder echte radioverbinding.
- Details, bestandenoverzicht en beperkingen: [Docs/LCD-REDESIGN.md](Docs/LCD-REDESIGN.md). D-STAR blijft gedimd; P25 niet toegevoegd. Op de minimumhoogte is de bestaande verticale scroll nodig.
- Definitieve controle gebruikt dezelfde geverifieerde lokale bronkopie nadat macOS het herlezen van een ongewijzigd bestand annuleerde. Alle productie-Swiftbestanden en Package.swift waren bytegelijk; actuele tests opnieuw geslaagd. Logs: `Docs/TestResults/LCD-20261030-{tests,console,install}.log`.
- Versie 0.7.1 build 39 lokaal geïnstalleerd in `/Users/rob/Applications/FusionLab.app`; ondertekening en starten gecontroleerd. Native venster toont de nieuwe LCD, opgeslagen YSF-host, PUC2/kanaal 1, EQ −12/0/+6, AGC en 2-minutenlimiet. De gebruiker wisselde vervolgens zelf naar DMR/TG4000; het LCD volgde die keuze. Geen publieke PTT gebruikt voor deze visuele controle.

## Versie 0.7.2 — C4FM-reflectornaam (30 oktober 2026)

- REFLECTOR toont de naam uit de huidige YSF-hostcatalogus; matching op host én poort. Een eigen reflector gebruikt zo mogelijk zijn opgeslagen Fusion-voorkeuzenaam. Bij onbekende endpoints blijft host:poort zichtbaar.
- Het echte IP-/DNS-adres en de poort staan in de technische onderregel en tooltip. Geen reverse-DNS, netwerkadreswijziging of wijziging aan de zend-/ontvangstketen.
- Volledige suite geslaagd, inclusief nieuwe naamselectie-/poort-/voorkeuze-/fallbackcontroles en behoud van het echte endpoint.
- App-bundle 0.7.2/build40 succesvol gebouwd en lokaal ondertekend; logs in Docs/TestResults/Reflector-name-20261030-{tests,build}.log.
- Geïnstalleerde app 0.7.2 gestart; native LCD toont daadwerkelijk **US-America Link**, met 63.250.41.136:42000 in de technische regel. Bestaande YSF-sessie voor de herstart netjes ontkoppeld nadat eigen PTT klaar was, daarna dezelfde reflector opnieuw verbonden.

## Versie 0.7.3 — ontvangst-mute en X-keys (30 oktober 2026)

- Luidsprekericoon vervangen door een toegankelijke mute-knop, oranje/doorgestreept bij mute. Centrale receiveMuted-status werkt ook via de nieuwe X-keys-actie Audio mute aan/uit. Bestaande toewijzingen blijven behouden.
- Alleen de gain van de bestaande AVAudioPlayerNode wordt gedempt, op de eigen audioqueue. Volumeaanpassing tijdens mute blijft stil; unmute herstelt het gekozen volume. Audiobuffer, AGC, EQ, meters, protocollen en microfoon/PTT blijven doorlopen zoals voorheen.
- Volledige regressiesuite geslaagd. Nieuwe tests controleren werkelijke player-gain, volume wijzigen tijdens mute, reset/stop, Codable-opslag, X-keys-druk/herhaling/loslaten, behoud van PTT-toewijzing en mute bij modekeuze.
- App 0.7.3/build41 gebouwd en lokaal ondertekend. Verpakken gebruikt de zojuist gebouwde onveranderlijke bronkopie Project-6d2f66e07d5557d592cf na bytevergelijking van alle productie-Swiftbestanden en Package.swift; voorkomt opnieuw laden van ongewijzigde codecbronnen via FileProvider. Logs: Docs/TestResults/Audio-mute-20261030-{tests,build}.log.
- Bedieningsuitleg en gewijzigd-bestandenoverzicht: [Docs/AUDIO-MUTE.md](Docs/AUDIO-MUTE.md). Herstelkopie vooraf in .local-backups/before-audio-mute-20261030/.
- Lokaal geïnstalleerde 0.7.3 native gecontroleerd: luidsprekerknop wisselt tussen Aan en Gedempt/speaker.slash.fill; dezelfde volumestand blijft staan bij unmute. De X-keys-functielijst bevat zichtbaar Audio mute aan/uit. Menu geannuleerd zonder bestaande toewijzingen te wijzigen. YSF-verbinding US-America Link is actief; geluid aan bij afronden. Fysieke mute-toets niet automatisch toegewezen.

## GitHub-publicatie 0.7.3 — 4 november 2026

- Huidige productiecode ongewijzigd; volledige `./script/test.sh` opnieuw geslaagd vóór publicatie. De bestaande protocol-, vocoder-, PCM-, PTT-, X-keys-, mute- en LCD-controles zijn uitgevoerd.
- `python3 script/probe_console_ui.py` bouwde de actuele GUI en genereerde native voorbeeldbeelden voor DMR, C4FM en NXDN. Deze screenshots staan onder `Docs/Screenshots/FusionLab-0.7.3-*.png` en zijn in de README opgenomen. De beelden gebruiken gemarkeerde testgegevens; geen publieke radio-uitzending of fysieke HID-acties gebruikt.
- README aangevuld met clone-/bouwinstructies en de huidige protocolondersteuning. Het bewaarpunt v0.4.9 en de oorspronkelijke commitgeschiedenis blijven behouden.
- Testuitvoer: `Docs/TestResults/Publication-20261104-{tests,console}.log`. Lokale appinstellingen, Sleutelhanger, herstelkopieën en MD380-firmware zijn geen onderdeel van deze publicatie.
