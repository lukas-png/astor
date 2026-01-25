# Remote Debugging einer JVM im Docker-Container via SSH

Dieses Dokument beschreibt, wie man eine Java Virtual Machine (JVM), die in einem Docker-Container auf einem Remote-Server läuft, mit einer lokalen IDE (z.B. IntelliJ IDEA oder Eclipse) debuggen kann. Die Verbindung erfolgt dabei sicher über einen SSH-Tunnel.

## Voraussetzungen
- Zugriff auf den Remote-Server per SSH
- Docker und der zu debuggende Container laufen auf dem Remote-Server
- Die JVM im Container ist mit aktiviertem Debug-Port (z.B. 5005) gestartet
- Die lokale IDE unterstützt Remote-Debugging (z.B. IntelliJ IDEA, Eclipse)

## Schritt-für-Schritt-Anleitung: Remote Debugging mit SSH-Tunnel

### 1. Container im Debug-Modus starten

Stelle sicher, dass der Container mit Port-Weiterleitung für den Debug-Port gestartet wird (z.B. 5005):

```bash
docker run -p 5005:5005 <image> <startbefehl-mit-debug-params>
```

Oder mit Docker Compose (Ausschnitt aus `docker-compose.yml`):

```yaml
services:
  myservice:
    image: <image>
    ports:
      - "5005:5005"
    # ... weitere Konfiguration ...
```

Die JVM muss mit folgenden Parametern gestartet werden:

```bash
-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=*:5005  # Java 8 oder neuer erforderlich!
```

Wichtig: Das `*` oder `0.0.0.0` bei `address` sorgt dafür, dass die JVM auf allen Interfaces lauscht und der Port von außen erreichbar ist. 
Achte darauf, dass im Container Java 8 oder neuer verwendet wird (z.B. mit `java -version` prüfen).

### 2. SSH-Tunnel vom lokalen Rechner zum Remote-Server aufbauen

Führe auf deinem lokalen Rechner folgenden Befehl aus:

```bash
ssh -L 5005:localhost:5005 doenges@147.172.177.105
```

- Damit wird der lokale Port 5005 auf den Port 5005 des Remote-Servers weitergeleitet.
- Lasse dieses Terminal-Fenster während der Debug-Session geöffnet!

### 3. IDE für Remote-Debugging konfigurieren

1. Öffne deine IDE (z.B. IntelliJ IDEA oder Eclipse).
2. Erstelle eine neue Remote-Debug-Konfiguration.
3. Setze Host auf `localhost` und Port auf `5005`.
4. Starte die Debug-Konfiguration.

Die IDE verbindet sich nun über den SSH-Tunnel mit der JVM im Container auf dem Remote-Server.

### 4. Fehlerbehebung
- **Connection refused:**
  - Prüfe, ob der Container mit Port 5005 läuft und die JVM auf `0.0.0.0:5005` lauscht.
  - Prüfe, ob der SSH-Tunnel aktiv ist.
- **Connection reset:**
  - Stelle sicher, dass die JVM im Debug-Modus (`suspend=y`) auf Verbindungen wartet.
- **Port nachträglich öffnen:**
  - Docker kann Ports nur beim Start eines Containers weiterleiten. Starte den Container ggf. neu mit `-p 5005:5005`.

## Zusammenfassung
Mit dieser Methode kannst du sicher und komfortabel eine JVM im Docker-Container auf einem Remote-Server debuggen, als würde sie lokal laufen. Die Verbindung erfolgt verschlüsselt über SSH und ist für alle modernen Java-IDEs geeignet.
