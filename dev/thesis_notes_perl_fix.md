# Dokumentation: Build-Fehler durch Perl-Abhängigkeiten (Defects4J auf Ubuntu 22.04)

Dieses Dokument beschreibt das technische Problem beim Bauen des Docker-Images auf neueren Linux-Versionen und die hergeleitete Lösung für die Bachelorarbeit.

## 1. Problembeschreibung

Beim Ausführen von `docker build` auf dem Remote-Server (Ubuntu 22.04) schlug der Schritt `RUN cpanm --installdeps .` fehl.

**Fehlermeldung:**
```text
! Configuring . failed. See /root/.cpanm/work/.../build.log for details.
```

Auf der lokalen Windows-Maschine funktionierte der Build scheinbar, da dort vermutlich ältere Docker-Layer gecached waren oder das Basis-Image zu einem früheren Zeitpunkt gezogen wurde, als das Problem noch nicht auftrat.

## 2. Technische Ursache (Root Cause)

Das Problem liegt an einer **Sicherheitsänderung in Perl v5.26+** (enthalten in Ubuntu 22.04), die `.` (das aktuelle Verzeichnis) aus dem `@INC` Pfad entfernt hat (CVE-2016-1238).

*   **Hintergrund:** Früher suchte Perl standardmäßig im aktuellen Ordner nach Modulen. Dies wurde als Sicherheitslücke eingestuft, da man so Code unterschieben konnte.
*   **Defects4J v1.1.0:** Diese ältere Version von Defects4J verwendet Build-Skripte (`Makefile.PL`), die implizit annehmen, dass Module im aktuellen Verzeichnis gefunden werden.
*   **Konflikt:** `cpanm --installdeps .` versucht, das Projekt zu konfigurieren, um herauszufinden, welche Abhängigkeiten fehlen. Dabei führt es das `Makefile.PL` aus. Da `.` nicht mehr in `@INC` ist, schlägt dieses Skript fehl, bevor `cpanm` überhaupt weiß, was es installieren soll.

## 3. Die Lösung

Statt zu versuchen, die Build-Umgebung so zu patchen, dass das alte Verhalten wieder erlaubt ist (was instabil war), werden die benötigten Abhängigkeiten **explizit** installiert. Dadurch muss `cpanm` nicht mehr das fehlerhafte lokale Build-Skript ausführen.

**Befehl im Dockerfile:**
```dockerfile
RUN cpanm --notest DBI DBD::CSV URI JSON JSON::XS List::MoreUtils version
```

## 4. Herleitung der Abhängigkeiten

Wie wurden die spezifischen Module (`DBI`, `DBD::CSV`, `URI`, `JSON`, etc.) identifiziert?

Die Liste der Abhängigkeiten ergibt sich aus der Analyse des Defects4J-Sourcecodes (speziell `framework/bin/defects4j` und `cpanfile`/`Makefile.PL` im Repository):

1.  **`DBI` & `DBD::CSV`**: Defects4J speichert Metadaten über Bugs und Tests in CSV-Dateien und nutzt das Perl-DBI-Interface, um diese wie eine SQL-Datenbank abzufragen. Dies ist eine Kernkomponente der Defects4J-Architektur.
2.  **`JSON` & `JSON::XS`**: Wird für den Datenaustausch und das Parsen von Konfigurationen oder Ergebnissen (oft von den Java-Tools) benötigt. `XS` ist die schnellere C-Implementierung.
3.  **`URI`**: Wird für das Herunterladen von Repositories und das Handling von URLs in den Setup-Skripten benötigt.
4.  **`List::MoreUtils`**: Enthält Hilfsfunktionen für Listenoperationen, die in den Perl-Skripten des Frameworks intensiv genutzt werden.
5.  **`version`**: Ermöglicht Versionsvergleiche (wichtig für das Versions-Management der Bugs).

Diese Module decken den Laufzeitbedarf von Defects4J ab, ohne dass das Repo selbst kompiliert werden muss.

