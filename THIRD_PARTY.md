# Drittanbieter-Bausteine

VD VR selbst steht unter der Eclipse Public License 2.0 (`LICENSE`). © 2026 Philipp Spruck / NEXTPHILM.

Die Lizenztexte liegen im Ordner [`licenses/`](licenses/) und werden mit der App ausgeliefert. In der App stehen sie
unter **Einstellungen → Über VD VR · Lizenzen · Sicherheit**.

## In der App (APK) enthalten

| Baustein | Lizenz | Wofür | Lizenztext |
|---|---|---|---|
| [Godot Engine](https://github.com/godotengine/godot) 4.7.2 (Android-Vorlage, `libgodot_android.so`) | MIT; die mitgebauten Bibliotheken (u. a. MIT, BSD, zlib, Apache-2.0, OFL) stehen in Godots Copyright-Liste | Laufzeit der App, Darstellung (OpenGL ES 3) | `licenses/godot-LICENSE.txt`, `licenses/godot-COPYRIGHT.txt` |
| [Godot OpenXR Vendors](https://github.com/GodotVR/godot_openxr_vendors) 5.1.0 (`libgodotopenxrvendors.so`, Plugin-AARs) | MIT | OpenXR-Anbindung je Hersteller | `licenses/godot_openxr_vendors-MIT.txt` |
| — darin der Pico-Teil (`godotopenxr-pico-release.aar`) | Apache-2.0 | Pico-Erweiterungen; nur Plugin-Code, kein Pico-SDK | `licenses/Apache-2.0.txt` |
| [Khronos OpenXR Loader für Android](https://github.com/KhronosGroup/OpenXR-SDK) (`libopenxr_loader.so`) | Apache-2.0 | Verbindung zur OpenXR-Laufzeit der Brille | `licenses/Apache-2.0.txt` |
| LLVM `libc++_shared.so` (Android NDK) | Apache-2.0 mit LLVM-Ausnahme | C++-Laufzeit | `licenses/LLVM-Apache-2.0-with-LLVM-exception.txt` |
| AndroidX (Core, Activity, Fragment, Lifecycle u. a.), Kotlin-Standardbibliothek und kotlinx.coroutines – aus Godots Android-Vorlage | Apache-2.0 | Android-Grundgerüst der App | `licenses/Apache-2.0.txt` |
| Schrift [Open Sans](https://github.com/googlefonts/opensans) (in Godot eingebaut) | SIL Open Font License 1.1 | Menü und Neon-Schrift | in `licenses/godot-COPYRIGHT.txt` |
| „Chill Out“ von atlasaudio ([Pixabay](https://pixabay.com/music/), ID 621545) | [Pixabay Content License](https://pixabay.com/de/service/license-summary/) | Hintergrundmusik | nur in der fertigen App, siehe `music/README.md` |

Die Pixabay-Lizenz erlaubt die Nutzung in der App, auch ohne Namensnennung (wir nennen den Track trotzdem). Sie
verbietet, den Track für sich allein zu verkaufen oder weiterzugeben – deshalb liegt er nicht in diesem Repository.

## Eigene Arbeit

- **Klänge der Startanimation** (`intro/sound/`): `tools/intro-sound.mjs` erzeugt sie aus Oszillatoren und Rauschen,
  ohne fremde Samples. Der Hall folgt dem gemeinfreien Freeverb-Entwurf (Jezar at Dreampoint), nachprogrammiert.
- **Bilder der Startanimation** (`intro/`): Suite-Zeichen, Suite-Logo und Icons der Programme gehören zur Link-Suite.
  Das App-Icon (`icon.png`, `intro/vr-icon.png`) entsteht wie das VD-Icon mit `scripts/logo/render.cjs --vr` im
  VD-Link-Repo (Schrift Inter Display, SIL OFL 1.1, als Bild gerendert).
- **Demo-Club** (`demo/`): eine Aufnahme der VD-Link-Vorlage „Club“ mit der Demo-Show von VD-Link. Der Raum ist die
  Geometrie, die VD-Link selbst zeichnet.
- Gobo-Bilder, Demo-Bilder der Videowände, die Lounge des Startbildschirms, Menü-Icons und alle Shader.

## Nicht enthalten

- **Meta-SDK:** Für eine Quest-Version kämen Teile von Meta dazu (Loader unter Apache-2.0, SDK-Teile unter der
  proprietären Oculus SDK License). Die Quest-Version wird erst nach einer rechtlichen Prüfung gebaut.
- **Pico-SDK:** nicht enthalten, nur der Apache-2.0-Plugin-Code oben.
- **NDI®:** Videostreams kommen in VD-Link am Computer an, nie in der Brille.

## Nur zum Bauen (nicht in der App)

Godot-Editor 4.7.2 (MIT), Android SDK/NDK und Gradle (Apache-2.0), Node.js (MIT) für `tools/intro-sound.mjs`.

OpenXR™ ist eine Marke der Khronos Group Inc. PICO, Meta Quest und Godot sind Marken ihrer jeweiligen Inhaber. VD VR
ist ein unabhängiges Projekt und kein Produkt dieser Hersteller.
