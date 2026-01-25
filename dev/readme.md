---title: "Astor + Defects4J – Docker Dev & Debug Setup"
# Astor + Defects4J – Docker Dev & Debug Setup

Dieses Repository beschreibt eine **entwicklerfreundliche Umgebung**, um ein **geforktes Astor**-Projekt:

* lokal in **IntelliJ** zu bearbeiten
* **im Docker-Container** zu bauen
* **Defects4J Bugs & einzelne Tests** auszuführen
* **per Remote Debugging (JDWP)** zu debuggen

Ohne bei jeder Codeänderung Docker Images neu zu bauen.

---

## 🧱 Architektur-Überblick

```
Host (IntelliJ)
│
├── astor/                # dein geforktes Astor (lokal, editierbar)
│
├── docker-compose.yml
├── Dockerfile.dev        # Toolchain + Defects4J (ohne Astor!)
├── scripts/
│   ├── rebuild_and_test.sh
│   ├── debug_astor_build.sh
│   └── debug_d4j_test.sh
│
└── work/                 # Defects4J Checkouts
```

**Wichtiges Prinzip:**

* Astor wird **nicht** ins Image gebaut
* Astor wird **per Volume** nach `/opt/astor` gemountet
* IntelliJ ↔ Docker arbeiten auf **demselben Code**

---

## 🚀 Voraussetzungen

* Docker + Docker Compose
* IntelliJ IDEA (Ultimate oder Community)
* Git
* Linux / macOS / Windows (WSL empfohlen)

---

## 🐳 Docker Setup

### 1. Docker Image bauen & Container starten

```bash
docker compose up -d --build
```

Shell im Container öffnen:

```bash
docker compose exec astor-dev bash
```

---

## 🔁 Entwicklungs-Workflow

### Code ändern (Host)

* Änderungen in IntelliJ im Ordner `astor/`

### Build + Test (Container)

* Astor wird **im Container** neu gebaut
* Defects4J Tests laufen **im Container**
* Kein Image-Rebuild nötig

---

## 🧪 Astor neu bauen + Defects4J Tests ausführen

### Rebuild + Tests (ohne Debug)

```bash
docker compose exec astor-dev bash -lc \
  "scripts/rebuild_and_test.sh Lang-1 org.example.Test::testX"
```

Parameter:

* `Lang-1` → Defects4J Bug
* `org.example.Test::testX` → einzelner Test (optional)

Ohne Test-Parameter läuft das volle relevante Testset:

```bash
docker compose exec astor-dev bash -lc \
  "scripts/rebuild_and_test.sh Lang-1"
```

---

## 🐞 Debugging mit IntelliJ (JDWP)

### 🔌 Freigegebene Ports

| Zweck                | Port   |
| -------------------- | ------ |
| Astor / Maven Debug  | `5005` |
| Defects4J Test Debug | `5006` |

(gesetzt in `docker-compose.yml`)

---

## 🧠 IntelliJ: Remote Debug Konfiguration

**Run → Edit Configurations → + → Remote JVM Debug**

### Astor

* Name: `Docker Astor Debug`
* Host: `localhost`
* Port: `5005`

### Defects4J Tests

* Name: `Docker D4J Debug`
* Host: `localhost`
* Port: `5006`

---

## 🐞 Astor Build debuggen

### 1. Build im Debug-Modus starten

```bash
docker compose exec astor-dev bash -lc \
  "scripts/debug_astor_build.sh"
```

Der Prozess **wartet** jetzt auf einen Debugger.

### 2. IntelliJ → `Docker Astor Debug` starten

* Breakpoints in Astor-Code setzen
* Build läuft weiter sobald IntelliJ verbunden ist

---

## 🧪 Defects4J Test debuggen

### 1. Test im Debug-Modus starten

```bash
docker compose exec astor-dev bash -lc \
  "scripts/debug_d4j_test.sh Lang-1 org.example.Test::testX"
```

### 2. IntelliJ → `Docker D4J Debug` starten

* Breakpoints im Projektcode oder Tests setzen
* JVM stoppt exakt am Breakpoint

---

## 📜 Debug-Skripte (Überblick)

### `debug_astor_build.sh`

* Java 8
* Maven Build
* JDWP Port `5005`

### `debug_d4j_test.sh`

* Java 11/7 (Defects4J)
* Einzeltest oder Suite
* JDWP Port `5006`

---

## ⚠️ Wichtige Hinweise

* **Quellcode-Mapping funktioniert automatisch**, da:

    * IntelliJ den lokalen `astor/` Ordner kennt
    * Docker `/opt/astor` exakt darauf gemountet ist
* Falls IntelliJ nicht in den Code springt:

    * Projekt-Root prüfen
    * Breakpoint wirklich im gemounteten Code setzen

---

## 🛠 Troubleshooting

### Debug-Port offen?

```bash
ss -ltnp | grep 5005
ss -ltnp | grep 5006
```

### Debug-Optionen greifen nicht?

* Alternativ zu `JAVA_TOOL_OPTIONS`:

  ```bash
  export ANT_OPTS="..."
  ```

### Defects4J Bug benötigt andere Java-Version?

* Setup ist vorbereitet (`use-java7`, `use-java8`)
* ggf. an Bug anpassen

---

## ✅ Ergebnis

* ⚡ Schneller Edit–Build–Test Loop
* 🐳 Reproduzierbare Docker-Umgebung
* 🧠 Vollwertiges IntelliJ Debugging
* 🧪 Einzeltests statt kompletter Suiten
* ❌ Kein Image-Rebuild bei Codeänderungen

---

Wenn du willst, kann ich dir als Nächstes:

* eine **IntelliJ One-Click Run/Debug Configuration**
* oder eine **Makefile / Taskfile**
* oder ein **ASCII Architekturdiagramm fürs README**

bauen.
