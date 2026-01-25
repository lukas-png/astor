# jGenProg Analyse für Bachelorarbeit

**Autor:** Lukas Dönges  
**Datum:** 2025-12-30  
**Astor Version:** 2.0.0  

---

## Inhaltsverzeichnis

1. [Übersicht](#übersicht)
2. [Kritische Bugs](#kritische-bugs)
3. [Mittelschwere Probleme](#mittelschwere-probleme)
4. [Pfad- und Konfigurationsprobleme](#pfad--und-konfigurationsprobleme)
5. [Classpath und Dependencies](#classpath-und-dependencies-der-zu-reparierenden-programme)
6. [Empfehlungen für die Replikationsstudie](#empfehlungen-für-die-replikationsstudie)

---

## Übersicht

Diese Analyse dokumentiert potenzielle Probleme in der jGenProg-Implementierung des Astor-Frameworks, die für die Replikationsstudie und Evaluation auf Defects4J 2.0 relevant sind.

### Analysierte Dateien

| Datei | Pfad |
|-------|------|
| JGenProg.java | `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/JGenProg.java` |
| RemoveOp.java | `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/operators/RemoveOp.java` |
| ReplaceOp.java | `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/operators/ReplaceOp.java` |
| InsertAfterOp.java | `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/operators/InsertAfterOp.java` |
| InsertBeforeOp.java | `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/operators/InsertBeforeOp.java` |
| jGenProgSpace.java | `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/jGenProgSpace.java` |
| astor.properties | `src/main/resources/astor.properties` |
| pom.xml | `pom.xml` |

---

## Kritische Bugs

### 🔴 Bug 1: ArrayIndexOutOfBoundsException im Crossover-Algorithmus

**Datei:** `JGenProg.java` (Zeilen 73-78)

**Fehlerhafter Code:**
```java
// we randomly select the generations to apply
int rgen1index = RandomManager.nextInt(v1.getOperations().keySet().size()) + 1;  // BUG: + 1
int rgen2index = RandomManager.nextInt(v2.getOperations().keySet().size()) + 1;  // BUG: + 1

List<OperatorInstance> ops1 = v1.getOperations((int) v1.getOperations().keySet().toArray()[rgen1index]);
List<OperatorInstance> ops2 = v2.getOperations((int) v2.getOperations().keySet().toArray()[rgen2index]);
```

**Problem:**
- `nextInt(size)` gibt Werte von `0` bis `size-1` zurück
- Mit `+ 1` wird der Bereich zu `1` bis `size`
- Ein Array der Größe `size` hat aber nur Indizes `0` bis `size-1`
- **Ergebnis:** `ArrayIndexOutOfBoundsException` wenn `nextInt()` den maximalen Wert zurückgibt

**Beispiel:**
```
KeySet size = 2 (Keys: [1, 3])
nextInt(2) kann 0 oder 1 zurückgeben
Mit + 1: Index wird 1 oder 2
Array hat nur Indizes 0 und 1 → Index 2 = ArrayIndexOutOfBoundsException
```

**Korrektur:**
```java
int rgen1index = RandomManager.nextInt(v1.getOperations().keySet().size());  // OHNE + 1
int rgen2index = RandomManager.nextInt(v2.getOperations().keySet().size());  // OHNE + 1
```

**Auswirkung:**
- Standardmäßig deaktiviert (`applyCrossover=false` in astor.properties)
- Tritt nur auf, wenn Crossover explizit aktiviert wird
- Kann zu Programmabstürzen während der Evolution führen

---

### 🔴 Bug 2: Fehlende Leerheitsprüfung für Operationslisten

**Datei:** `JGenProg.java` (Zeilen 79-80)

**Fehlerhafter Code:**
```java
OperatorInstance opinst1 = ops1.remove((int) RandomManager.nextInt(ops1.size()));
OperatorInstance opinst2 = ops2.remove((int) RandomManager.nextInt(ops2.size()));
```

**Problem:**
- Wenn `ops1.size() == 0`, führt `RandomManager.nextInt(0)` zu `IllegalArgumentException`
- Die vorherige Prüfung `v1.getOperations().isEmpty()` prüft nur, ob die Map leer ist
- Einzelne Listen in der Map können trotzdem leer sein

**Korrektur:**
```java
if (ops1.isEmpty() || ops2.isEmpty()) {
    log.debug("CO|Empty operation list for crossover");
    return;
}
OperatorInstance opinst1 = ops1.remove((int) RandomManager.nextInt(ops1.size()));
OperatorInstance opinst2 = ops2.remove((int) RandomManager.nextInt(ops2.size()));
```

---

## Mittelschwere Probleme

### 🟡 Problem 1: Instanzvariable statt lokale Variable in InsertBeforeOp

**Datei:** `InsertBeforeOp.java` (Zeile 20)

**Fehlerhafter Code:**
```java
public class InsertBeforeOp extends InsertStatementOp {
    boolean successful = false;  // ⚠️ Instanzvariable!
    
    @Override
    public boolean applyChangesInModel(OperatorInstance operation, ProgramVariant p) {
        // successful wird verwendet...
    }
}
```

**Vergleich mit InsertAfterOp (korrekt):**
```java
public class InsertAfterOp extends InsertStatementOp {
    @Override
    public boolean applyChangesInModel(OperatorInstance operation, ProgramVariant p) {
        boolean successful = false;  // ✓ Lokale Variable
        // ...
    }
}
```

**Problem:**
- Bei Wiederverwendung des Operators behält `successful` den alten Wert
- Kann zu falschen Ergebnissen bei der `undoChangesInModel()` Methode führen
- Race Conditions bei paralleler Ausführung möglich

**Korrektur:**
```java
public class InsertBeforeOp extends InsertStatementOp {
    // Instanzvariable entfernen!
    
    @Override
    public boolean applyChangesInModel(OperatorInstance operation, ProgramVariant p) {
        boolean successful = false;  // Lokale Variable verwenden
        // ...
    }
}
```

---

### 🟡 Problem 2: Nicht-deterministische HashMap-Iteration

**Datei:** `JGenProg.java` (Zeilen 77-78)

**Code:**
```java
List<OperatorInstance> ops1 = v1.getOperations((int) v1.getOperations().keySet().toArray()[rgen1index]);
```

**Problem:**
- `HashMap.keySet()` gibt Keys in **undefinierter Reihenfolge** zurück
- Die Reihenfolge kann zwischen verschiedenen JVM-Starts variieren
- Führt zu **nicht-reproduzierbaren Ergebnissen**
- Besonders problematisch für wissenschaftliche Replikationsstudien!

**Empfehlung:**
```java
// Sortierte Keys verwenden für Reproduzierbarkeit
List<Integer> sortedKeys = new ArrayList<>(v1.getOperations().keySet());
Collections.sort(sortedKeys);
int selectedKey = sortedKeys.get(rgen1index);
List<OperatorInstance> ops1 = v1.getOperations(selectedKey);
```

---

### 🟡 Problem 3: Exception in RemoveOp.undoChangesInModel()

**Datei:** `RemoveOp.java` (Zeilen 57-71)

**Code:**
```java
@Override
public boolean undoChangesInModel(OperatorInstance operation, ProgramVariant p) {
    // ...
    if ((parentBlock.getStatements().isEmpty() && stmtoperator.getLocationInParent() == 0)
            || (parentBlock.getStatements().size() >= stmtoperator.getLocationInParent())) {
        parentBlock.getStatements().add(stmtoperator.getLocationInParent(), ctst);
        // ...
    } else {
        log.error("Problems to recover...");
        throw new IllegalStateException("Undo:Not valid index");  // Unbehandelter Crash!
    }
}
```

**Problem:**
- Bei inkonsistentem Zustand wird eine Exception geworfen
- Keine Möglichkeit zur Wiederherstellung
- Kann die gesamte Reparatursuche abbrechen

---

## Pfad- und Konfigurationsprobleme

### ⚠️ Windows vs. Unix Pfadtrenner

**Datei:** `astor.properties`

Die Konfiguration enthält mehrere Hinweise auf plattformspezifische Pfadtrenner:

```properties
# separated using File.pathSeparator (': in Unix/Linux/Solaris), please, replace it by ';' if you use Windows)
resourcesfolder=/src/main/resources:/src/test/resources:

# Gzoltar configuration
## working directory for Gzoltar (replace it if you use Windows)
location=/tmp

###test cases to Ignore (separated using File.pathSeparator)
ignoredTestCases=
```

**Probleme für Windows-Benutzer:**

| Property | Unix-Default | Windows-Anpassung erforderlich |
|----------|--------------|--------------------------------|
| `resourcesfolder` | `/src/main/resources:/src/test/resources:` | `/src/main/resources;/src/test/resources;` |
| `location` | `/tmp` | `C:\temp` oder Projektpfad |
| `ignoredTestCases` | `:` getrennt | `;` getrennt |

### ⚠️ Hardcodierte Pfade

**Datei:** `astor.properties`

```properties
# Standard-Ordnerstruktur (Maven-Konvention)
srcjavafolder=src/main/java
srctestfolder=src/test/java
binjavafolder=/target/classes
bintestfolder=/target/test-classes

# GZoltar JAR-Dateien
locationGzoltarJar=./lib/

# EvoSuite
evosuitejar=./lib/evosuite-master-1.0.4-SNAPSHOT.jar

# JUnit
lastJUnitVersion=./examples/libs/junit-4.11.jar

# Executor JAR
executorjar=./lib/jtestex7.jar
```

**Potenzielle Probleme:**
1. Relative Pfade (`./lib/`) hängen vom Arbeitsverzeichnis ab
2. `/target/classes` mit führendem `/` kann auf Windows problematisch sein
3. Bei Nicht-Maven-Projekten müssen alle Pfade manuell angepasst werden

---

## Classpath und Dependencies der zu reparierenden Programme

### Wie Astor mit Classpath umgeht

Astor verwaltet den Classpath für zu reparierende Programme über die Klasse `ProjectConfiguration.java`. Der Ablauf ist:

```
1. Benutzer gibt Dependencies via -dependencies Parameter an
2. ProjectConfiguration.setDependencies(String libPath) wird aufgerufen
3. Pfad wird an File.pathSeparator gesplittet (: auf Unix, ; auf Windows)
4. Für jeden Pfadteil wird addLocationToClasspath() aufgerufen
5. Dependencies werden als List<URL> gespeichert
```

#### Relevanter Code (`ProjectConfiguration.java`, Zeilen 121-152):

```java
public void addLocationToClasspath(String path) {
    File location = new File(path);
    try {
        List cp = ((List) this.internalProperties.get(ProjectPropertiesEnum.dependencies));

        if (!location.exists()) {
            return;  // ⚠️ Keine Warnung wenn Dependency nicht existiert!
        }
        if (!location.isDirectory()) {
            if (!cp.contains(location.toURI().toURL())) {
                cp.add(location.toURI().toURL());
            }
        } else {
            cp.add(location.toURI().toURL());
            
            // Alle JARs im Verzeichnis hinzufügen
            for (File file : location.listFiles()) {
                if (file.getName().endsWith(".jar")) {
                    logger.info("Adding to classpath " + file.getName());
                    if (!cp.contains(file.toURI().toURL())) {
                        cp.add(file.toURI().toURL());
                    }
                }
            }
        }
    } catch (MalformedURLException e) {
        throw new IllegalArgumentException(e);
    }
}
```

### ⚠️ Probleme mit verschiedenen Versionen gleicher Dependencies

#### Problem 1: Keine Versionskonflikterkennung

Astor hat **keine Mechanismen zur Erkennung oder Auflösung von Versionskonflikten**:

```java
// Die einzige Duplikatsprüfung ist URL-basiert:
if (!cp.contains(location.toURI().toURL())) {
    cp.add(location.toURI().toURL());
}
```

**Konsequenzen:**
- Wenn ein lib-Ordner mehrere Versionen derselben Library enthält (z.B. `junit-4.11.jar` und `junit-4.12.jar`), werden **beide** zum Classpath hinzugefügt
- Die JVM lädt die **erste gefundene Version** (undefinierte Reihenfolge!)
- Kann zu `NoSuchMethodError`, `ClassNotFoundException` oder subtilen Bugs führen

#### Problem 2: Reihenfolge nicht garantiert

```java
for (File file : location.listFiles()) {  // Reihenfolge ist filesystem-abhängig!
    if (file.getName().endsWith(".jar")) {
        // ...
    }
}
```

`File.listFiles()` gibt Dateien in **filesystem-abhängiger Reihenfolge** zurück:
- Auf manchen Systemen alphabetisch
- Auf anderen nach Erstellungsdatum
- **Nicht reproduzierbar zwischen verschiedenen Systemen!**

#### Problem 3: Fehlende Dependencies werden still ignoriert

```java
if (!location.exists()) {
    return;  // Keine Warnung, keine Exception!
}
```

Wenn eine angegebene Dependency nicht existiert:
- **Kein Fehler** wird geworfen
- Nur stille Rückkehr
- Kann zu schwer zu debuggenden `ClassNotFoundException` während der Laufzeit führen

### Beispiel: Defects4J Dependency-Probleme

Ein typisches Defects4J-Projekt (z.B. Math_70) hat:

```
examples/math_70/lib/
├── junit-4.4.jar          # Test-Framework
└── [weitere libs]

examples/libs/
├── junit-4.11.jar         # Astor's Standard JUnit
└── junit-4.12.jar         # Neuere Version
```

**Was passiert:**
1. Astor fügt `examples/math_70/lib/` zum Classpath hinzu
2. Astor fügt seine eigenen Test-Dependencies hinzu
3. Mehrere JUnit-Versionen sind im Classpath
4. Je nach Reihenfolge wird `junit-4.4.jar` oder `junit-4.11.jar` verwendet
5. **Inkompatible APIs können Testausführung brechen!**

### Empfohlene Lösungen

#### Für Experimente:

1. **Explizite JAR-Pfade angeben** statt Verzeichnisse:
   ```
   -dependencies /path/to/junit-4.11.jar;/path/to/hamcrest-1.3.jar
   ```

2. **Isolierte lib-Verzeichnisse** pro Projekt verwenden

3. **Dependency-Audit vor Experimenten:**
   ```bash
   # Alle JARs im Classpath auflisten
   find . -name "*.jar" | xargs -I{} basename {} | sort | uniq -d
   ```

#### Potenzielle Code-Fixes:

```java
// Verbesserung 1: Warnung bei nicht existierenden Pfaden
if (!location.exists()) {
    logger.warn("Dependency path does not exist: " + path);
    return;
}

// Verbesserung 2: Sortierte, reproduzierbare Reihenfolge
File[] files = location.listFiles();
Arrays.sort(files, Comparator.comparing(File::getName));
for (File file : files) {
    // ...
}

// Verbesserung 3: Versionskonflikterkennung (komplex)
// Würde Parsing von JAR-Manifests erfordern
```

---

## Maven Dependencies (pom.xml) - Astor selbst

| Dependency | Version | Zweck |
|------------|---------|-------|
| **Spoon** | 9.2.0-beta-1 | AST-Manipulation |
| **Flacoco** | 1.0.6 | Fehlerlokalisation |
| **GZoltar CLI** | 1.7.3 | Fehlerlokalisation (Alternative) |
| **GZoltar Core** | 1.7.3 | Fehlerlokalisation |
| **Log4j** | 2.13.3 | Logging |
| **JUnit 4** | 4.13.2 | Test-Framework |
| **JUnit 5** | 5.3.2 | Test-Framework |
| **Guava** | 30.1-jre | Utility-Bibliothek |
| **Gson** | 2.8.2 | JSON-Verarbeitung |
| **Commons Collections** | 3.2.2 | Utility |
| **Commons IO** | 2.5 | I/O Utility |
| **Commons CLI** | 1.4 | Command-Line Parsing |

### Externe JAR-Dateien (lib/)

```
lib/
├── com.gzoltar-0.0.7-jar-with-dependencies.jar
├── com.gzoltar-0.1.1-jar-with-dependencies.jar
├── com.gzoltar-1.5.1-jar-with-dependencies.jar
├── com.gzoltar-1.6.1-java7-jar-with-dependencies.jar
├── com.gzoltar.agent.rt-1.7.4-SNAPSHOT-all.jar
├── com.gzoltar.cli-1.7.4-SNAPSHOT-jar-with-dependencies.jar
├── evosuite-1.0.3.jar
├── evosuite-master-1.0.4-SNAPSHOT.jar
├── evosuite-master-1.0.6-SNAPSHOT.jar
├── evosuite-standalone-runtime-1.0.3.jar
├── hamcrest-core-1.3.jar
├── infra-0.1.jar
├── jtestex7.jar
├── junit-4.11.jar
├── junit-4.12.jar
└── sacha-infra.jar
```

### ⚠️ Bekannte Dependency-Probleme in Astor selbst

1. **GZoltar Versionskonflikt:**
   - pom.xml: `1.7.3`
   - astor.properties: `gzoltarVersion=1.7.4-SNAPSHOT`
   - lib-Ordner: Multiple Versionen (0.0.7, 0.1.1, 1.5.1, 1.6.1, 1.7.4-SNAPSHOT)

2. **Java-Version:**
   - pom.xml properties: `maven.compiler.source=1.9`
   - pom.xml compiler plugin: `source=1.8`, `target=1.8`
   - astor.properties: `javacompliancelevel=8`
   - **Inkonsistenz kann zu Kompilierungsproblemen führen!**

3. **CocoSpoon SNAPSHOT:**
   ```xml
   <dependency>
       <groupId>fil.iagl.cocospoon</groupId>
       <artifactId>CocoSpoon</artifactId>
       <version>1.0.0-SNAPSHOT</version>
   </dependency>
   ```
   - SNAPSHOT-Versionen können sich ändern und zu Reproduzierbarkeitsproblemen führen

---

## Classpath-Konstruktion zur Laufzeit

### Wie der finale Classpath zusammengesetzt wird

Astor konstruiert den Classpath für die **Testausführung** einer Programmvariante wie folgt:

```java
// ProjectRepairFacade.java, Zeilen 171-178
public URL[] getClassPathURLforProgramVariant(String currentMutatorIdentifier) 
        throws MalformedURLException {
    
    // 1. Alle Projekt-Dependencies
    List<URL> classpath = new ArrayList<URL>(getProperties().getDependencies());
    
    // 2. Bytecode-Verzeichnis der mutierten Variante
    URL urlBin = new File(getOutDirWithPrefix(currentMutatorIdentifier)).toURI().toURL();
    classpath.add(urlBin);

    URL[] cp = classpath.toArray(new URL[0]);
    return cp;
}
```

### Classpath-Reihenfolge

| Position | Inhalt | Quelle |
|----------|--------|--------|
| 1-N | Projekt-Dependencies | `-dependencies` Parameter |
| N+1 | Mutierter Bytecode | `workingDirBytecode/variant-X/` |

**Wichtig:** Der mutierte Bytecode kommt **zuletzt** im Classpath. Das bedeutet:
- Wenn eine Klasse sowohl in den Dependencies als auch im mutierten Code existiert
- Wird die Version aus den **Dependencies** geladen (First-Match-Prinzip)
- Der mutierte Code wird **ignoriert**!

### Konsequenz für die Reparatur

Dieses Verhalten ist normalerweise korrekt, da:
- Dependencies externe Libraries sind (z.B. JUnit)
- Der zu reparierende Code im Bytecode-Verzeichnis liegt
- Keine Überlappung erwartet wird

**Aber:** Bei komplexen Projekten mit Abhängigkeiten auf eigene Module kann es zu Problemen kommen.

---

## Defects4J-spezifische Classpath-Probleme

### Problem: Unterschiedliche Library-Versionen pro Bug

Defects4J-Projekte nutzen verschiedene Library-Versionen:

| Projekt | JUnit-Version | Commons-Math | Andere |
|---------|---------------|--------------|--------|
| Math_70 | 4.4 | - | - |
| Math_85 | 4.4 | - | - |
| Lang_55 | 3.8.2 | - | oro-2.0.8 |
| Chart_1 | 4.0 | - | servlet-2.3 |
| Time_11 | 3.8.2 | - | joda-convert |

### Empfehlung für Experimente

```bash
# Vor jedem Experiment: Dependencies prüfen
defects4j export -p cp.compile -w /path/to/buggy/project
defects4j export -p cp.test -w /path/to/buggy/project
```

### Astor-Aufruf mit explizitem Classpath

```bash
java -jar astor.jar \
    -mode jGenProg \
    -location /path/to/Math_70 \
    -dependencies "/path/to/Math_70/lib/junit-4.4.jar;/path/to/other.jar" \
    -javacompliancelevel 7 \
    # ... weitere Parameter
```

---

## Empfehlungen für die Replikationsstudie

### 1. Vor der Replikation prüfen

- [ ] Java-Version konsistent setzen (empfohlen: Java 8)
- [ ] GZoltar-Version fixieren
- [ ] Crossover standardmäßig deaktiviert lassen
- [ ] Windows-Pfadtrenner anpassen (`;` statt `:`)

### 2. Für reproduzierbare Ergebnisse

```properties
# Empfohlene Einstellungen für Replikation
seed=<fester Wert>                    # Zufallsseed fixieren
applyCrossover=false                   # Crossover deaktivieren (Bug!)
maxGeneration=<wie im Paper>          # Generationen wie im Referenzpaper
population=<wie im Paper>             # Populationsgröße wie im Referenzpaper
scope=<wie im Paper>                  # Ingredient Scope wie im Referenzpaper
```

### 3. Bug-Fixes vor Experimenten

Für eine faire Evaluation sollten folgende Bugs gefixt werden:

1. **ArrayIndexOutOfBoundsException in applyCrossover()** - Kritisch wenn Crossover aktiv
2. **Instanzvariable in InsertBeforeOp** - Kann Ergebnisse verfälschen
3. **Fehlende Leerheitsprüfung** - Kann zu Crashes führen

### 4. Dokumentation der Astor-Version

Für die Bachelorarbeit notieren:
- Git-Commit-Hash
- Datum des Checkouts
- Angewandte Patches/Fixes
- Java-Version der Experimente

---

## Zusammenfassung

| Kategorie | Anzahl | Schweregrad |
|-----------|--------|-------------|
| Kritische Bugs | 2 | 🔴 |
| Mittelschwere Probleme | 3 | 🟡 |
| Konfigurationsprobleme | 4 | ⚠️ |
| Dependency/Classpath-Probleme | 5 | ⚠️ |

### Übersicht der Dependency/Classpath-Probleme

| Problem | Auswirkung | Relevanz für Replikation |
|---------|------------|--------------------------|
| Keine Versionskonflikterkennung | Mehrere Versionen gleichzeitig im Classpath | Hoch |
| Undefinierte JAR-Reihenfolge | Nicht-reproduzierbare Ergebnisse | Hoch |
| Stilles Ignorieren fehlender Deps | Runtime-Fehler statt Build-Fehler | Mittel |
| GZoltar Versionsinkonsistenz | Potenzielle API-Inkompatibilität | Mittel |
| SNAPSHOT-Dependencies | Nicht-reproduzierbare Builds | Hoch |

**Diese Analyse zeigt, dass die jGenProg-Implementierung in Astor mehrere Probleme aufweist, die für eine Replikationsstudie relevant sind. Die identifizierten Bugs könnten erklären, warum unterschiedliche Replikationsversuche zu unterschiedlichen Ergebnissen führen.**

**Besonders kritisch für die Bachelorarbeit:**
1. Die Classpath-Reihenfolge ist nicht deterministisch
2. Verschiedene Defects4J-Projekte nutzen unterschiedliche Library-Versionen
3. Astor hat keine Mechanismen zur Erkennung von Versionskonflikten

---

*Generiert für Bachelorarbeit "Automatische Programmreparatur" - Universität Hildesheim*

