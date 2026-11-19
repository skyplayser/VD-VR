# VD VR – der Club in der VR-Brille

VD VR ist die App für Standalone-Brillen (Pico 4 Ultra, später Meta Quest). Sie zeigt den Club aus VD-Link mit
Lichtkegeln, Lichtflecken, Gobos, Lampenköpfen und Videowänden. Den Raum zeichnet sie so wie VD-Link am Computer:
Bar, Lounge, Traversen, Publikum, Materialien und Raumlicht kommen direkt aus VD-Link.

## Startanimation

Beim Start spielt VD VR die Startanimation der Link-Suite, in 3D um dich herum: Das Suite-Zeichen baut sich vor dir
auf, aus den Reglern schießen Lichtstrahlen, die acht Programme der Suite fliegen heraus und ziehen einmal im Kreis
um dich. Dann wird das Zeichen zum Link-Suite-Logo, die Programme kehren zurück, und VD landet auf dem Zeichen des
Startbildschirms, während die Lounge erscheint. Das dauert etwa 7 Sekunden.

Dazu gibt es Ton: Bässe und Braams, wenn die Lichtstrahlen zünden und das Logo steht, ein Club-Puls, solange die
Programme kreisen, und ein warmer Akkord, wenn die Lounge erscheint. Alles andere klingt räumlich dort, wo es passiert:
Die Regler klicken, die Strahlen zischen, die Programme rauschen um dich herum, und VD landet mit einem Glockenton.

Trigger, A/B/X/Y oder die Leertaste überspringen sie. Unter **Einstellungen → Startanimation der Link-Suite** lässt sie
sich abschalten, der Ton allein ausschalten oder die Animation noch einmal ansehen. Es gibt kein Stroboskop, und nichts
bewegt dich selbst.

## Startbildschirm

VD VR startet in einer kleinen Lounge mit eigener Lichtshow. Davor steht der Startbildschirm, aufgebaut wie der von
VD-Link am Computer:

- **Links**: Logo, darunter die Wege hinein als Kacheln:
  - **Weiter mit <Computer>**: der zuletzt verbundene Computer. Ohne ihn steht hier **Mit VD-Link verbinden**.
  - **Demo-Club**: Lichtshow ohne Computer.
  - **Anderer Computer**: im WLAN suchen und Code eingeben.
  - **Gespeicherte Shows**: abspielen und verwalten.
  - **Einstellungen**: Haze, Grundlicht, Laufen, Drehen, Startanimation, Hintergrundmusik.
  - **Club-Studio**: den echten Club einzeichnen und an VD-Link schicken (siehe unten).
- **Rechts**:
  - die zuletzt gespeicherten Shows, ein Klick spielt sie ab;
  - welche VD-Link-Computer im WLAN zu finden sind;
  - **Hintergrundmusik** an oder aus;
  - die Instagram-Karte.

Mit dem Controller auf den Startbildschirm zeigen und den Trigger ziehen. In der Lounge kannst du dich frei bewegen.
B / Y holt das Menü vor dich und stellt es wieder zurück. Aus jeder Show führt Menü → **Startbildschirm** zurück.

## Hintergrundmusik

Nach der Startanimation blendet ruhige Musik ein und läuft in einer Schleife: auf dem Startbildschirm, im Demo-Club
und bei gespeicherten Shows. Im Live-Betrieb schweigt sie, dort läuft die Musik im echten Raum. An/aus direkt auf dem
Startbildschirm, Lautstärke (Leise, Mittel, Laut, Voll) unter **Einstellungen → Hintergrundmusik**.

Musik: „Chill Out“ von atlasaudio, über [Pixabay](https://pixabay.com/) (Pixabay Content License). Der Track liegt nur in der fertigen App, nicht im Quellcode (siehe `music/README.md`).

## Betriebsarten

| Quelle | Was passiert |
|---|---|
| **Live** | VD-Link am Computer rechnet die Show. VD VR zeigt sie und meldet zurück, wo die Brille steht und wohin sie schaut. VD-Link zeigt die Brille in der 3D-Ansicht. Änderungen in VD-Link sind sofort in der Brille zu sehen. |
| **Gespeichert** | Eine Show, die vorher auf der Brille gespeichert wurde, läuft ohne Computer in einer Schleife. |
| **Demo** | Der mitgelieferte Demo-Club mit Demo-Lichtshow und Demo-Bildern. Er läuft ohne Computer, auch beim ersten Start. |

Pult (Art-Net/sACN) und Videostreams (NDI®) kommen immer am Computer an, nie direkt in der Brille.

Für die beste Grafik unter Windows gibt es den PC-Modus: VD-Link rendert selbst und schickt das Bild per WebXR über
Pico Connect, Steam Link oder Meta Link in die Brille (VERBINDEN → VR-Brille → „In PC-VR öffnen“).

## Verbinden

1. In VD-Link: **VERBINDEN → VR-Brille einschalten**. VD-Link zeigt einen 4-stelligen Code.
2. Brille und Computer im selben WLAN.
3. In VD VR: Menü → **Verbinden …**. VD VR sucht VD-Link im WLAN. Computer wählen und den Code eingeben.

VD VR merkt sich den Computer. Beim nächsten Start steht er auf dem Startbildschirm als **Weiter mit …**. Ist er nach 12 Sekunden
nicht erreichbar, geht VD VR zurück zum Startbildschirm und sagt warum.

## VR-Knopf in VD-Link

Oben rechts in VD-Link, zwischen Bildrate und Einstellungen, steht der Knopf **VR**. Die Zahl daneben zeigt die
verbundenen Brillen. Ein Klick öffnet:

- **Ein/Aus** des VR-Servers und den **Code** für die Brille.
- **Verbundene Brillen** mit Namen. In der 3D-Ansicht steht jede Brille mit Kopf, Blickkegel und Namen.
  - **Mitschauen**: Die 3D-Ansicht zeigt, was die Brille gerade sieht. Ziehen in der Ansicht oder eine Kamera-Taste
    beendet es.
  - **Hierher holen**: Die Brille steht danach dort, wo die 3D-Ansicht steht (auf dem Boden darunter), und schaut in
    dieselbe Richtung – in der Brille ist dann dasselbe zu sehen wie in VD-Link.
- **Welt auf Brillen übertragen**: das offene Projekt zum Begehen ohne Computer (siehe unten).

Adressen für den Browser der Brille und PC-VR stehen weiter unter VERBINDEN → VR-Brille.

## Welt auf die Brille laden

Die Brille kann das offene Projekt als **Welt** speichern: Raum, Lampen, Videowände und das Licht des Moments. Danach
kannst du dich ohne Computer darin bewegen. Es wird nichts abgespielt, das Licht steht so, wie es beim Laden war.

- **In VD-Link:** oben rechts **VR → Welt auf Brillen übertragen** (oder VERBINDEN → VR-Brille). Alle verbundenen
  VD-VR-Brillen laden die Welt. VD-Link zeigt je Brille den Fortschritt und meldet „gespeichert“.
- **In der Brille:** bei verbundenem Computer Menü → **Welt laden** oder Startbildschirm → **Gespeichert** → „Welt von
  <Computer> laden“.

Gespeicherte Welten stehen auf dem Startbildschirm unter **Gespeichert**. Lädt man dasselbe Projekt erneut, ersetzt es
die alte Fassung. Mit Computer ist die Welt wie gewohnt live (**Weiter mit …**).

Weiterhin kann die Brille im Live-Betrieb ein Stück Lichtshow aufnehmen (Menü → „Show aufnehmen (30 s / 60 s)“).

## Club-Studio: den echten Club einzeichnen

Im Club-Studio zeichnest du den echten Club in der Brille nach und siehst ihn dabei durch die Kameras. Das ist
ähnlich wie die Raumeinrichtung bei SteamVR, Oculus und Pico, aber mit Stockwerken, Rundungen, Türen und Fenstern,
Möbeln und den Materialien von VD-Link. VD-Link macht daraus eine Location zum Weiterbauen.

> ⚠️ **Sicherheit:** Im Club-Studio läufst du durch den echten Raum, siehst ihn aber nur durch die Kameras der Brille.
> Langsam gehen, auf Stufen, Treppen, Emporenkanten, Kabel und Menschen achten, nicht rückwärts gehen. Am besten
> mit einer zweiten Person, die aufpasst. Ohne Spielbereich der Pico warnt dich nichts vor Wänden – das ist deine
> Entscheidung und auf eigene Gefahr.

**Vorher in der Pico:** Für freie Bewegung durch den ganzen Club lässt sich der Spielbereich abschalten:
Einstellungen → Entwickler → **Entwickler-Tools Spielbereich** → **Spielbereich deaktivieren** (PICO OS 5.15). Das
Entwicklermenü erscheint nach siebenmal Tippen auf die Softwareversion. Danach den Spielbereich wieder einschalten.
Ohne diese Einstellung geht es Raum für Raum (siehe **Mit Spielbereich** unten).

Startbildschirm → **Club-Studio**. Die Werkzeugkiste sitzt über dem linken Controller und wird mit dem rechten Strahl
bedient. Zu Beginn zur Bühne schauen, diese Seite wird in VD-Link die Rückwand.

| Werkzeug | So geht's |
|---|---|
| **Boden** | Rechten Controller auf den Boden legen, Trigger. Misst die Ebene ein. Auf einem anderen Stockwerk (ab 1,5 m Höhenunterschied) entsteht eine neue Ebene: OG 1, OG 2 … oder UG 1 … |
| **Wand** | Am Boden entlang der echten Wand Punkt für Punkt (Trigger). Rechte Winkel und Ecken rasten ein, an einer vorhandenen Ecke schließt sich der Raum, Grip beendet. |
| **Rundung** | Anfang, Ende, dann ein Punkt auf der Rundung. |
| **Empore** | Auf der Empore selbst: erst mit **Boden** einmessen (wird OG 1), dann den Umriss Punkt für Punkt. Zurück am ersten Punkt oder Grip schließt ihn. Rundungen mit mehr Punkten. Es entsteht eine Platte (0,3 m), deren Oberkante der Emporenboden ist. |
| **Geländer** | Brüstung oder Geländer als Linie, 1,1 m hoch, Glas. Zum Beispiel an der offenen Kante einer Empore oder an einer Treppe. Höhe und Material über Auswahl und Farbe. |
| **Öffnung** | Tür (0,9 × 2,1 m), Doppeltür, Tor, **Durchgang** (in den nächsten Raum), Fenster (Brüstung 0,9 m), Fensterband – auf die Wand am Boden zeigen. Maße gelten ab dem Boden der Ebene. |
| **Möbel** | Tresen, Tisch, Stehtisch, Sofa, DJ-Pult, Bühne, Podest, Säule, Treppe, Block, Lautsprecher, LED-Wand: zwei Ecken am Boden, dann den Controller auf die Höhe heben, Trigger. Beginnt man oben auf einem Podest, einer Bühne oder Empore, steht das Teil darauf. Treppe: unten an der ersten Stufe beginnen, oben enden. L- und U-Treppen: Podest aufziehen, erste Treppe bis zum Podest, zweite Treppe auf dem Podest beginnen. |
| **Auswahl** | Teil anzeigen und Trigger: Halten und Ziehen verschiebt es, an einer Ecke die Wandecke. Rechter Stick dreht. In der Werkzeugkiste: drehen, Breite/Tiefe/Höhe, **Unterkante** (z. B. hängende Teile), Brüstung, duplizieren, löschen. |
| **Farbe** | Material wählen (Schwarz, Grau, Weiß, Marmor, Samt petrol/violett, Metall, Holz, Glas, Beton, LED …), dann auf Wand, Möbel oder Boden zeigen. „Decke“ färbt die Decke der Ebene. |
| **Löschen** | Zeigen, Trigger. **A** oder **Zurück** nimmt den letzten Schritt zurück. |

Unten in der Werkzeugkiste: Ebene wählen, Deckenhöhe −/+, **Modell** (ohne Durchsicht alles in den Materialien
ansehen), **+ Raum**, **Speichern**, **Senden**.

- **Räume:** **+ Raum** beginnt den nächsten Raum an Ort und Stelle. Ebenen und Ausrichtung bleiben, fertige Räume
  sind blass zu sehen, und VD-Link übernimmt alles so, wie es zueinander liegt.
- **Mit Spielbereich:** Die gelbe Linie am Boden ist der Spielbereich. Kurz vor der Grenze warnt VD VR. Zentriert die
  Pico neu oder setzt sie den Spielbereich neu, stimmen die Koordinaten nicht mehr. Dann geht es als neuer Abschnitt
  weiter, und die Tür dorthin wird auf beiden Seiten als **Durchgang** markiert. VD-Link setzt die Abschnitte dort
  zusammen, auch über Stockwerke.
- **Sichern:** Der Entwurf wird laufend gesichert. Im Menü (B/Y) steht **Neu beginnen**.
- **Live am PC mitverfolgen:** Laptop mit VD-Link und Brille im selben WLAN (im Club notfalls beide im Hotspot eines
  Handys), in VD-Link die VR-Brille einschalten. Das Studio findet den zuletzt verbundenen Computer selbst wieder, auch
  mit neuer Adresse, und schickt jede Änderung sofort. In VD-Link: oben rechts **VR → Live ansehen**. Der
  Location-Builder zeigt die Zeichnung mit „LIVE aus VD VR“ und zieht laufend nach, ohne die Ansicht zu verstellen.
  Ändert man dort selbst etwas, pausiert Live. In der Werkzeugkiste steht oben „Live: <Computer>“ oder „kein VD-Link
  im WLAN“.
- **Ohne Computer im Club:** **Speichern** legt den Stand auf der Brille ab, beliebig oft. Zu Hause mit VD-Link im
  WLAN: Club-Studio → Menü (B/Y) → **Gespeicherte Scans → Senden**.
- **Obere Böden:** Böden über dem Erdgeschoss entstehen nur aus Emporen. Einen Raum im OG also mit **Empore**
  (Umriss des Raums) und **Wand** zeichnen.
- **In VD-Link:** oben rechts **VR → Club-Scans → Als Location öffnen**.
  - Wände werden Wandobjekte, Rundungen runde Wände.
  - Türen und Fenster sind echte Öffnungen mit Sturz und Brüstung.
  - Möbel behalten Art und Material, die LED-Wand wird eine Videowand.
  - Obere Stockwerke stehen in ihrer Höhe.
  - Alles bleibt im Location-Builder bearbeitbar.

## Bedienung

| Controller | Funktion |
|---|---|
| Rechter Stick nach vorn, loslassen | Teleport (Bogen zeigt das Ziel, nur auf begehbare Flächen) |
| Rechter Stick links/rechts | Drehen (30°- oder 45°-Schritte oder gleitend) |
| Linker Stick | Laufen (stoppt an Wänden und Möbeln, Stufen bis 40 cm) |
| B / Y | Menü auf und zu (Startbildschirm: vor dich holen und zurückstellen) |
| Zeigen + Trigger | Im Menü wählen |

Im Menü: Quelle, Standort (Publikumsbereiche der Location), Haze, Grundlicht, Laufen an/aus, Drehart, Aufnahme,
Startbildschirm. **Grundlicht „Wie VD-Link“** entspricht dem Raumlicht der 3D-Ansicht am Computer. „Heller“ und
„Hell“ helfen beim Begehen eines dunklen Raums. VD VR läuft mit 72 Bildern pro Sekunde.

## Installieren

VD VR ist noch nicht im Store. Die APK steht unter [Releases](https://github.com/skyplayser/VD-VR/releases).

1. In der Pico den Entwicklermodus einschalten (in den Einstellungen siebenmal auf die Softwareversion tippen) und
   **USB-Debugging** aktivieren.
2. Brille per USB-C an den Computer, in der Brille „USB-Debugging zulassen“ bestätigen.
3. Mit den [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools):

```bash
adb install -r vd-vr-0.1.0-alpha-pico.apk
```

VD VR steht danach in der Bibliothek unter **Unbekannte Quellen**. Die Pico verlangt für seitlich installierte Apps
ein angemeldetes PICO-Konto. Ohne Controller in der Hand legt sie ihren Handtracking-Dialog vor die App.
