# Astor Remote Docker Umgebung – Dokumentation

Diese Dokumentation beschreibt die Einrichtung und Verwendung der **Remote Docker Umgebung** für das Astor-Framework. Diese Umgebung wurde konzipiert, um eine vollständig isolierte, reproduzierbare Ausführung von Astor-Experimenten zu gewährleisten, unabhängig vom Host-Betriebssystem.

## 1. Motivation & Architektur

Für wissenschaftliche Experimente im Bereich *Automated Program Repair* (APR) ist die Reproduzierbarkeit essenziell. Die Standard-Entwicklungsumgebung von Astor nutzt *Volume Mounts*, um den lokalen Quellcode in den Container zu spiegeln. Dies ist ideal für die Entwicklung, birgt jedoch Risiken für Experimente (z.B. Seiteneffekte durch lokale Änderungen während des Laufs).

Der **Remote-Ansatz** verfolgt stattdessen das Prinzip der **Immutable Infrastructure**:
1.  **Quellcode-Integration**: Der aktuelle Stand des Astor-Quellcodes wird zum *Build-Zeitpunkt* in das Docker-Image kopiert.
2.  **Isolierter Build**: Astor wird innerhalb des Containers mit den exakt definierten Java-Versionen und Abhängigkeiten kompiliert (`mvn package`).
3.  **Laufzeit-Isolation**: Der Container enthält zur Laufzeit alles Notwendige. Es bestehen keine Abhängigkeiten zum lokalen Dateisystem mehr.

Dies ermöglicht das einfache Deployment von Experimenten auf Remote-Servern (z.B. Cloud-Instanzen oder Uni-Clustern), ohne dass dort Git-Repositories oder Maven eingerichtet werden müssen.

## 2. Dateien & Struktur

Die Implementierung umfasst folgende Komponenten im `dev/`-Verzeichnis:

*   **`Dockerfile.remote`**:
    *   Basiert auf Ubuntu 22.04.
    *   Installiert Java 7 (für Defects4J Bugs) und Java 8 (für Astor).
    *   Klont und installiert Defects4J v1.1.0.
    *   **Besonderheit**: Kopiert den lokalen Astor-Sourcecode nach `/opt/astor` und baut das Projekt intern.

*   **`compose-remote.yml`**:
    *   Docker Compose Definition für den Dienst `astor-remote`.
    *   Definiert Port-Forwarding (5005) für Debugging.
    *   Verzichtet auf Volume-Mounts des Sourcecodes.

*   **`remote.sh`**:
    *   Ein Abstraktions-Skript (Wrapper), um komplexe Docker-Compose-Befehle zu vereinfachen (`build`, `run`, `debug`, etc.).

## 3. Workflow & Verwendung

Das Skript `dev/remote.sh` dient als zentrale Schnittstelle. Alle Befehle sollten von der Wurzel des Repositories oder aus dem `dev/`-Ordner ausgeführt werden.

### 3.1. Build (Image Erstellung)

Da der Quellcode in das Image "gebacken" wird, muss das Image nach jeder Code-Änderung neu erstellt werden.

```bash
./dev/remote.sh build
```

*Hintergrund*: Dies führt `docker compose build` aus. Dabei wird der Kontext (`..`) an den Docker-Daemon gesendet, der Sourcecode kopiert und `mvn package` im Container ausgeführt.

### 3.2. Experiment ausführen (Produktiv-Modus)

Um einen Reparaturversuch auf einem spezifischen Bug (z.B. `Lang-1` aus Defects4J) zu starten:

```bash
# Syntax: ./dev/remote.sh run <Bug-ID>
./dev/remote.sh run Lang-1
```

*Verhalten*:
*   Der Container startet.
*   Das Skript checkoutet den Bug `Lang-1` temporär im Container.
*   Astor sucht nach Reparaturen.
*   **Wichtig**: Der Debugger ist hier deaktiviert (`suspend=n`), damit das Experiment ohne Interaktion durchläuft.

### 3.3. Debugging (Interaktiver Modus)

Für die Fehlersuche kann Astor im Debug-Modus gestartet werden. Der Prozess wird beim Start der JVM angehalten ("suspended"), bis ein Debugger verbunden wird.

1.  Starten des Containers im Debug-Modus:
    ```bash
    ./dev/remote.sh debug Lang-1
    ```
    *Die Konsole zeigt: `Listening for transport dt_socket at address: 5005`*

2.  Verbinden mit der IDE (z.B. IntelliJ IDEA):
    *   Run Configuration erstellen: **Remote JVM Debug**.
    *   Host: `localhost` (oder IP des Remote-Servers).
    *   Port: `5005`.

### 3.4. Bug-Validierung (Defects4J Tests)

Um zu überprüfen, ob ein Bug im Container korrekt reproduziert wird, können die Tests des Bugs ausgeführt werden, ohne Astor zu starten:

```bash
./dev/remote.sh validate Lang-1
```
*Dies checkt den Bug aus und führt `defects4j test` aus (compiliert und testet das Projekt).*

### 3.5. Validierung (Astor Unit Tests)

Um sicherzustellen, dass der aktuelle Astor-Code-Stand fehlerfrei ist:

```bash
./dev/remote.sh test-all
```
*Dies führt `mvn test` für Astor innerhalb der isolierten Umgebung aus.*

### 3.6. Massenverarbeitung (Ganzes Projekt)

Um Astor auf **allen Bugs** eines bestimmten Projekts (z.B. alle `Lang` Bugs von 1 bis 65) nacheinander auszuführen:

```bash
./dev/remote.sh run-project Lang
```

*Verhalten*:
1.  Ermittelt automatisch alle verfügbaren Bug-IDs für das Projekt.
2.  Startet für jede Bug-ID sequenziell einen neuen Docker-Container.
3.  Fehler bei einem einzelnen Bug brechen die Schleife nicht ab.

### 3.7. Manuelle Analyse (Shell)

Für tiefgehende Analysen:

```bash
./dev/remote.sh shell
```

## 4. Local vs. Remote Docker Execution

Das Skript `remote.sh` wird **lokal** auf deinem Rechner ausgeführt (z.B. in der Git Bash). Wo der Docker-Container tatsächlich läuft, hängt von der Docker-Konfiguration ab:

1.  **Lokal (Standard)**: Wenn kein spezieller Docker-Host konfiguriert ist, läuft der Container in deiner lokalen Docker-Umgebung (Docker Desktop / Docker Engine).
2.  **Remote**: Um Container auf einem entfernten Server zu starten, muss der Docker-Client entsprechend konfiguriert sein.
    *   Setze die Environment Variable `DOCKER_HOST` (z.B. `export DOCKER_HOST=ssh://user@remote-server`).
    *   Oder wechsle den Docker Context: `docker context use my-remote-context`.

Da das `Dockerfile.remote` den Quellcode direkt enthält (durch `COPY`), funktioniert dieser Workflow problemlos auch gegen remote Docker Engines, da keine lokalen Pfade (`-v F:/...`) gemountet werden müssen.

### Neuen Remote-Context anlegen (einmalig)

Falls noch kein Remote-Context existiert, kann er per Docker CLI angelegt werden:

```bash
# Beispiel: Verbindung zu einem Server per SSH
docker context create remote-server --docker "host=ssh://user@192.168.1.100"


## 6. Anpassung der Konfiguration

Die interne Ausführungslogik wird durch `dev/run_astor_on_d4j.sh` gesteuert. Folgende Umgebungsvariablen werden durch `remote.sh` gesetzt:

*   `DEBUG_SUSPEND`: Steuert, ob die JVM auf den Debugger wartet (`y` oder `n`).
*   `MAXTIME`: Maximale Laufzeit für Astor (Standard: 60 Minuten, anpassbar in `run_astor_on_d4j.sh` oder durch Übergeben im Docker-Command).

