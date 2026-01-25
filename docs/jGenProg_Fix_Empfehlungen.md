# jGenProg Fix-Empfehlungen

**Autor:** Lukas Dönges  
**Datum:** 2025-12-30  
**Basierend auf:** jGenProg_Analyse_BA.md  

---

## Inhaltsverzeichnis

1. [Kritische Fixes](#kritische-fixes)
2. [Mittelschwere Fixes](#mittelschwere-fixes)
3. [Konfigurationskorrekturen](#konfigurationskorrekturen)
4. [Classpath/Dependency Fixes](#classpathdependency-fixes)
5. [Checkliste für Experimente](#checkliste-für-experimente)

---

## Kritische Fixes

### Fix 1: ArrayIndexOutOfBoundsException im Crossover-Algorithmus

**Datei:** `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/JGenProg.java`  
**Zeilen:** 73-78

#### Vorher (Fehlerhaft):
```java
int rgen1index = RandomManager.nextInt(v1.getOperations().keySet().size()) + 1;
int rgen2index = RandomManager.nextInt(v2.getOperations().keySet().size()) + 1;

List<OperatorInstance> ops1 = v1.getOperations((int) v1.getOperations().keySet().toArray()[rgen1index]);
List<OperatorInstance> ops2 = v2.getOperations((int) v2.getOperations().keySet().toArray()[rgen2index]);
```

#### Nachher (Korrigiert):
```java
int rgen1index = RandomManager.nextInt(v1.getOperations().keySet().size());
int rgen2index = RandomManager.nextInt(v2.getOperations().keySet().size());

List<OperatorInstance> ops1 = v1.getOperations((int) v1.getOperations().keySet().toArray()[rgen1index]);
List<OperatorInstance> ops2 = v2.getOperations((int) v2.getOperations().keySet().toArray()[rgen2index]);
```

#### Begründung:
- `nextInt(size)` gibt bereits Werte von `0` bis `size-1` zurück
- Das `+ 1` verschiebt den Bereich auf `1` bis `size`, was zu Array-Index-Fehlern führt

---

### Fix 2: Fehlende Leerheitsprüfung für Operationslisten

**Datei:** `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/JGenProg.java`  
**Zeilen:** 79-80 (nach Fix 1 einfügen)

#### Vorher (Fehlerhaft):
```java
List<OperatorInstance> ops1 = v1.getOperations((int) v1.getOperations().keySet().toArray()[rgen1index]);
List<OperatorInstance> ops2 = v2.getOperations((int) v2.getOperations().keySet().toArray()[rgen2index]);

OperatorInstance opinst1 = ops1.remove((int) RandomManager.nextInt(ops1.size()));
OperatorInstance opinst2 = ops2.remove((int) RandomManager.nextInt(ops2.size()));
```

#### Nachher (Korrigiert):
```java
List<OperatorInstance> ops1 = v1.getOperations((int) v1.getOperations().keySet().toArray()[rgen1index]);
List<OperatorInstance> ops2 = v2.getOperations((int) v2.getOperations().keySet().toArray()[rgen2index]);

// FIX: Prüfung auf leere Listen hinzufügen
if (ops1 == null || ops1.isEmpty() || ops2 == null || ops2.isEmpty()) {
    log.debug("CO|Empty operation list for crossover - skipping");
    return;
}

OperatorInstance opinst1 = ops1.remove((int) RandomManager.nextInt(ops1.size()));
OperatorInstance opinst2 = ops2.remove((int) RandomManager.nextInt(ops2.size()));
```

#### Begründung:
- `RandomManager.nextInt(0)` wirft `IllegalArgumentException`
- Leere Operationslisten müssen vor dem Zugriff geprüft werden

---

## Mittelschwere Fixes

### Fix 3: Instanzvariable in InsertBeforeOp

**Datei:** `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/operators/InsertBeforeOp.java`  
**Zeile:** 20

#### Vorher (Fehlerhaft):
```java
public class InsertBeforeOp extends InsertStatementOp {
    boolean successful = false;  // Instanzvariable - PROBLEMATISCH!
    
    @Override
    public boolean applyChangesInModel(OperatorInstance operation, ProgramVariant p) {
        // successful wird verwendet ohne lokale Initialisierung
        // ...
    }
}
```

#### Nachher (Korrigiert):
```java
public class InsertBeforeOp extends InsertStatementOp {
    // Instanzvariable ENTFERNT
    
    @Override
    public boolean applyChangesInModel(OperatorInstance operation, ProgramVariant p) {
        boolean successful = false;  // Lokale Variable - KORREKT
        // ...
    }
}
```

#### Begründung:
- Instanzvariablen behalten ihren Wert zwischen Methodenaufrufen
- Kann zu falschen Ergebnissen führen, wenn der Operator wiederverwendet wird
- Konsistenz mit `InsertAfterOp.java` herstellen

---

### Fix 4: Deterministische HashMap-Iteration

**Datei:** `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/JGenProg.java`  
**Zeilen:** 73-78

#### Vorher (Nicht-deterministisch):
```java
int rgen1index = RandomManager.nextInt(v1.getOperations().keySet().size());
List<OperatorInstance> ops1 = v1.getOperations((int) v1.getOperations().keySet().toArray()[rgen1index]);
```

#### Nachher (Deterministisch):
```java
// Sortierte Keys für reproduzierbare Ergebnisse
List<Integer> sortedKeys1 = new ArrayList<>(v1.getOperations().keySet());
Collections.sort(sortedKeys1);
int rgen1index = RandomManager.nextInt(sortedKeys1.size());
int selectedKey1 = sortedKeys1.get(rgen1index);
List<OperatorInstance> ops1 = v1.getOperations(selectedKey1);

List<Integer> sortedKeys2 = new ArrayList<>(v2.getOperations().keySet());
Collections.sort(sortedKeys2);
int rgen2index = RandomManager.nextInt(sortedKeys2.size());
int selectedKey2 = sortedKeys2.get(rgen2index);
List<OperatorInstance> ops2 = v2.getOperations(selectedKey2);
```

#### Begründung:
- `HashMap.keySet().toArray()` gibt Keys in undefinierter Reihenfolge zurück
- Sortierung garantiert gleiche Reihenfolge bei gleichem Seed
- Wichtig für wissenschaftliche Reproduzierbarkeit

---

### Fix 5: Verbesserte Exception-Behandlung in RemoveOp

**Datei:** `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/operators/RemoveOp.java`  
**Zeilen:** 57-71

#### Vorher (Crashes):
```java
} else {
    log.error("Problems to recover...");
    throw new IllegalStateException("Undo:Not valid index");
}
```

#### Nachher (Graceful Degradation):
```java
} else {
    log.error("Problems to recover at index " + stmtoperator.getLocationInParent() 
              + " with parent size " + parentBlock.getStatements().size());
    // Versuch am Ende anzufügen statt abzustürzen
    try {
        parentBlock.getStatements().add(ctst);
        successful = true;
        log.warn("Recovery: Statement added at end of block instead");
    } catch (Exception e) {
        log.error("Recovery failed completely", e);
        return false;
    }
}
```

#### Begründung:
- Exceptions unterbrechen den gesamten Reparaturprozess
- Graceful Degradation ermöglicht Fortsetzung der Suche

---

## Konfigurationskorrekturen

### Fix 6: Windows-kompatible astor.properties

**Datei:** `src/main/resources/astor.properties`

#### Änderungen für Windows:

```properties
# VORHER (Unix):
resourcesfolder=/src/main/resources:/src/test/resources:
location=/tmp

# NACHHER (Windows):
resourcesfolder=/src/main/resources;/src/test/resources;
location=./output_astor
```

#### Empfohlene Properties-Datei für Windows:

```properties
# === WINDOWS-KOMPATIBLE KONFIGURATION ===

# Pfadtrenner: ; statt : auf Windows
resourcesfolder=/src/main/resources;/src/test/resources;

# Arbeitsverzeichnis (relativ zum Projekt statt /tmp)
location=./output_astor
workingDirectory=./output_astor

# GZoltar-Konfiguration
gzoltarVersion=1.7.3
locationGzoltarJar=./lib/

# Java-Compliance (konsistent setzen!)
javacompliancelevel=8

# Reproduzierbarkeit
applyCrossover=false

# Zufallsseed für Replikationsstudien (auskommentieren für normale Nutzung)
# seed=12345
```

---

### Fix 7: Java-Version Inkonsistenz in pom.xml

**Datei:** `pom.xml`

#### Vorher (Inkonsistent):
```xml
<properties>
    <maven.compiler.source>1.9</maven.compiler.source>
    <maven.compiler.target>1.9</maven.compiler.target>
</properties>

<!-- Compiler Plugin -->
<configuration>
    <source>1.8</source>
    <target>1.8</target>
</configuration>
```

#### Nachher (Konsistent):
```xml
<properties>
    <maven.compiler.source>1.8</maven.compiler.source>
    <maven.compiler.target>1.8</maven.compiler.target>
</properties>

<!-- Compiler Plugin -->
<configuration>
    <source>1.8</source>
    <target>1.8</target>
</configuration>
```

#### Begründung:
- Java 8 ist die am besten getestete Version für Astor
- Defects4J Bugs wurden hauptsächlich mit Java 7/8 getestet

---

## Classpath/Dependency Fixes

### Fix 8: Warnung bei fehlenden Dependencies

**Datei:** `src/main/java/fr/inria/astor/core/entities/ProjectConfiguration.java`  
**Methode:** `addLocationToClasspath(String path)`

#### Vorher (Still ignorieren):
```java
if (!location.exists()) {
    return;
}
```

#### Nachher (Mit Warnung):
```java
if (!location.exists()) {
    logger.warn("⚠️ Dependency path does not exist and will be ignored: " + path);
    return;
}
```

---

### Fix 9: Deterministische JAR-Reihenfolge

**Datei:** `src/main/java/fr/inria/astor/core/entities/ProjectConfiguration.java`  
**Methode:** `addLocationToClasspath(String path)`

#### Vorher (Nicht-deterministisch):
```java
for (File file : location.listFiles()) {
    if (file.getName().endsWith(".jar")) {
        // ...
    }
}
```

#### Nachher (Deterministisch):
```java
File[] files = location.listFiles();
if (files != null) {
    // Sortierte Reihenfolge für Reproduzierbarkeit
    Arrays.sort(files, Comparator.comparing(File::getName));
    for (File file : files) {
        if (file.getName().endsWith(".jar")) {
            // ...
        }
    }
}
```

---

### Fix 10: Versionskonflikterkennung (Optional, Fortgeschritten)

**Neue Hilfsmethode für ProjectConfiguration.java:**

```java
/**
 * Prüft auf potenzielle Versionskonflikte im Classpath.
 * Warnt wenn mehrere Versionen derselben Library gefunden werden.
 */
private void checkForVersionConflicts(List<URL> classpath) {
    Map<String, List<URL>> libraryVersions = new HashMap<>();
    
    for (URL url : classpath) {
        String fileName = new File(url.getPath()).getName();
        // Einfache Heuristik: Library-Name ohne Version extrahieren
        String baseName = fileName.replaceAll("-\\d+\\.\\d+.*\\.jar$", "");
        
        libraryVersions.computeIfAbsent(baseName, k -> new ArrayList<>()).add(url);
    }
    
    for (Map.Entry<String, List<URL>> entry : libraryVersions.entrySet()) {
        if (entry.getValue().size() > 1) {
            logger.warn("⚠️ Potential version conflict detected for '" + entry.getKey() + "':");
            for (URL url : entry.getValue()) {
                logger.warn("   - " + url.getPath());
            }
        }
    }
}
```

---

## Checkliste für Experimente

### Vor dem Start der Replikationsstudie:

- [ ] **Java-Version prüfen:** `java -version` sollte Java 8 zeigen
- [ ] **GZoltar-Version fixieren:** Nur eine Version im lib-Ordner
- [ ] **Windows-Pfade anpassen:** `;` statt `:` in astor.properties
- [ ] **Crossover deaktivieren:** `applyCrossover=false`
- [ ] **Seed setzen:** Für reproduzierbare Ergebnisse

### Für jedes Defects4J-Projekt:

- [ ] **Dependencies exportieren:**
  ```bash
  defects4j export -p cp.compile -w /path/to/project
  defects4j export -p cp.test -w /path/to/project
  ```

- [ ] **Explizite JAR-Pfade nutzen:**
  ```bash
  -dependencies "/full/path/to/dep1.jar;/full/path/to/dep2.jar"
  ```

- [ ] **Konfliktprüfung durchführen:**
  ```bash
  # Duplikate finden
  find /path/to/project/lib -name "*.jar" | xargs -I{} basename {} | sort | uniq -d
  ```

### Nach den Experimenten:

- [ ] **Astor-Version dokumentieren:**
  ```bash
  git log -1 --format="%H %ai"
  ```

- [ ] **Angewandte Fixes dokumentieren**

- [ ] **Konfiguration sichern:**
  ```bash
  cp astor.properties experiment_config_$(date +%Y%m%d).properties
  ```

---

## Vollständiger Patch (Diff-Format)

Für die wichtigsten Fixes als Git-Patch:

```diff
diff --git a/src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/JGenProg.java b/src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/JGenProg.java
--- a/src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/JGenProg.java
+++ b/src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/JGenProg.java
@@ -70,14 +70,26 @@ public class JGenProg extends ExhaustiveAstorEngine {
        }

        // we randomly select the generations to apply
-       int rgen1index = RandomManager.nextInt(v1.getOperations().keySet().size()) + 1;
-       int rgen2index = RandomManager.nextInt(v2.getOperations().keySet().size()) + 1;
+       // FIX: Entferne + 1 um ArrayIndexOutOfBoundsException zu vermeiden
+       List<Integer> sortedKeys1 = new ArrayList<>(v1.getOperations().keySet());
+       Collections.sort(sortedKeys1);
+       int rgen1index = RandomManager.nextInt(sortedKeys1.size());
+       int selectedKey1 = sortedKeys1.get(rgen1index);

-       List<OperatorInstance> ops1 = v1.getOperations((int) v1.getOperations().keySet().toArray()[rgen1index]);
-       List<OperatorInstance> ops2 = v2.getOperations((int) v2.getOperations().keySet().toArray()[rgen2index]);
+       List<Integer> sortedKeys2 = new ArrayList<>(v2.getOperations().keySet());
+       Collections.sort(sortedKeys2);
+       int rgen2index = RandomManager.nextInt(sortedKeys2.size());
+       int selectedKey2 = sortedKeys2.get(rgen2index);

-       OperatorInstance opinst1 = ops1.remove((int) RandomManager.nextInt(ops1.size()));
-       OperatorInstance opinst2 = ops2.remove((int) RandomManager.nextInt(ops2.size()));
+       List<OperatorInstance> ops1 = v1.getOperations(selectedKey1);
+       List<OperatorInstance> ops2 = v2.getOperations(selectedKey2);
+
+       // FIX: Prüfung auf leere Listen
+       if (ops1 == null || ops1.isEmpty() || ops2 == null || ops2.isEmpty()) {
+           log.debug("CO|Empty operation list for crossover - skipping");
+           return;
+       }
+
+       OperatorInstance opinst1 = ops1.remove(RandomManager.nextInt(ops1.size()));
+       OperatorInstance opinst2 = ops2.remove(RandomManager.nextInt(ops2.size()));
```

---

## Zusammenfassung

| Fix | Priorität | Aufwand | Auswirkung |
|-----|-----------|---------|------------|
| Fix 1: ArrayIndex Crossover | 🔴 Kritisch | Gering | Verhindert Crashes |
| Fix 2: Leere Listen-Prüfung | 🔴 Kritisch | Gering | Verhindert Crashes |
| Fix 3: InsertBeforeOp Variable | 🟡 Mittel | Gering | Korrekte Ergebnisse |
| Fix 4: Deterministische Iteration | 🟡 Mittel | Mittel | Reproduzierbarkeit |
| Fix 5: RemoveOp Exception | 🟡 Mittel | Mittel | Stabilität |
| Fix 6: Windows Properties | ⚠️ Konfiguration | Gering | Windows-Support |
| Fix 7: Java-Version pom.xml | ⚠️ Konfiguration | Gering | Build-Konsistenz |
| Fix 8: Dependency-Warnung | ⚠️ Verbesserung | Gering | Debugging |
| Fix 9: JAR-Reihenfolge | ⚠️ Verbesserung | Gering | Reproduzierbarkeit |
| Fix 10: Versionskonflikte | 🔵 Optional | Hoch | Prävention |

---

*Generiert für Bachelorarbeit "Automatische Programmreparatur" - Universität Hildesheim*

