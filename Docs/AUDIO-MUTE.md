# Ontvangstaudio dempen — 0.7.3 / build 41

Klik op de luidspreker bij **Audio**: oranje/doorgestreept betekent gedempt. Nogmaals klikken schakelt de ontvangst weer in op het gekozen volume. De schuifregelaar en X-keys Volume +/− kunnen het volume tijdens mute wijzigen zonder het geluid in te schakelen. Mute blijft behouden bij een modewissel of nieuwe radioverbinding; na een app-herstart begint mute uitgeschakeld.

De mute is beschikbaar als **Setup → X-keys → Functie → Audio mute aan/uit**. Kies zelf welke toets deze actie krijgt. Iedere nieuwe druk wisselt mute; vasthouden, herhaalde USB-rapporten en loslaten veroorzaken geen extra omschakeling. Bestaande toewijzingen en hun opslag blijven behouden.

De verwerking van ontvangen pakketten, vocoder, audiobuffer, AGC, EQ en niveaumeters loopt door. Alleen de gain van de bestaande AVAudioPlayerNode wordt op nul gezet; unmute gebruikt het laatst gekozen volume. De microfoon en PTT worden niet gewijzigd. Afspelen wordt niet gepauzeerd, zodat mute geen extra achterstand in ontvangen audio opbouwt.

Gewijzigde productiecode: `Services/AudioOutput.swift` (gain op eigen audioqueue), `Services/RadioSession.swift` (gedeelde mute-status en HID-actie), `Models/XKeys.swift` (nieuwe Codable-actie), `Views/AudioControlView.swift` (toegankelijke icoonknop en statusupdates), `Views/ContentView.swift` en `script/build_and_run.sh` (versie). Nieuwe controles in `Tests/FusionLabTests/AudioMuteTests.swift`, geregistreerd in `ProtocolTests.swift`; bediening beschreven in README en XKEYS.md. Vooraf gemaakte herstelkopie: `.local-backups/before-audio-mute-20261030/`.

Tests controleren de werkelijke player-gain op de audioqueue bij mute/unmute, volumeaanpassing terwijl mute actief is, reset en stop; daarnaast opslag van de nieuwe X-keys-actie, behoud van PTT-toewijzing, druk/herhaling/loslaten, modekeuze en uitblijven van een radio-uitzending.

Verificatie: volledige regressiesuite en app-bouw geslaagd. In de geïnstalleerde app is de icoonknop heen en terug getest met behoud van dezelfde volumestand. De nieuwe actie is in de native X-keys-functielijst gecontroleerd zonder een toets te wijzigen. De reflectorverbinding is actief en mute staat uit bij afronden. Logs staan in `Docs/TestResults/Audio-mute-20261030-{tests,build}.log`.
