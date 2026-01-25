# jGenProg: Technische Dokumentation

**Version:** 3.0 (Iteration 3 - Final)  
**Datum:** 2026-01-04  
**Astor Version:** 2.0.0  
**Zielgruppe:** Entwickler, Forscher, Studierende

---

## Inhaltsverzeichnis

1. [Einleitung](#1-einleitung)
2. [Architekturübersicht](#2-architekturübersicht)
3. [Fehlerlokalisation (Fault Localization)](#3-fehlerlokalisation-fault-localization)
4. [Ingredient Space und Scopes](#4-ingredient-space-und-scopes)
5. [Repair Operators](#5-repair-operators)
6. [Ingredient Search & Transformation Strategies](#6-ingredient-search--transformation-strategies)
7. [Evolutionärer Algorithmus](#7-evolutionärer-algorithmus)
8. [Defects4J Integration](#8-defects4j-integration)
9. [Konfiguration und Parameter](#9-konfiguration-und-parameter)
10. [Ausführungsbeispiel](#10-ausführungsbeispiel)
11. [Bekannte Probleme und Limitationen](#11-bekannte-probleme-und-limitationen)
12. [Referenzen](#12-referenzen)

---

## 1. Einleitung

### Was ist jGenProg?

jGenProg ist eine Java-Implementierung des GenProg-Algorithmus innerhalb des Astor-Frameworks. GenProg wurde ursprünglich von Le Goues et al. (2012) für C-Programme entwickelt und nutzt **genetische Programmierung** zur automatischen Reparatur von Software-Bugs.

> **Kernidee:** Nutze existierenden Code aus dem fehlerhaften Programm als "Spendermaterial" (Ingredients), um Bugs durch Mutation zu reparieren.

### Grundprinzip: Generate-and-Validate

jGenProg folgt dem **Generate-and-Validate**-Paradigma:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Generate-and-Validate Loop                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌───────────┐ │
│  │ 1. LOKALI-  │───►│ 2. GENERATE │───►│ 3. VALIDATE │───►│ 4. REPEAT │ │
│  │    SIEREN   │    │    Patch-   │    │  Kompilieren│    │   oder    │ │
│  │  (FL)       │    │  Kandidaten │    │  + Testen   │    │   STOP    │ │
│  └─────────────┘    └─────────────┘    └─────────────┘    └───────────┘ │
│                                                                          │
│  STOP-Bedingungen:                                                       │
│    • Patch gefunden (alle Tests grün)                                    │
│    • Zeitlimit erreicht (maxtime)                                        │
│    • Generationslimit erreicht (maxGeneration)                           │
│    • Konvergenz (keine Verbesserung mehr)                                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Kernkonzepte

| Begriff | Beschreibung | Beispiel |
|---------|--------------|----------|
| **Modification Point** | Eine verdächtige Code-Stelle, die modifiziert werden kann | Zeile 72 in `BisectionSolver.java` |
| **Ingredient** | Ein Code-Fragment, das zur Reparatur verwendet werden kann | `return solve(f, min, max);` |
| **Operator** | Eine Transformation (Remove, Replace, Insert) | `ReplaceOp` |
| **Program Variant** | Eine modifizierte Version des Programms | `variant-34` |
| **Fitness** | Bewertung einer Variante (Anzahl bestandener Tests) | 0.95 (95% Tests bestanden) |
| **Suspicious Value** | Wahrscheinlichkeit, dass eine Zeile den Bug enthält | 0.87 (sehr verdächtig) |

### Unterschied zu anderen Repair-Ansätzen in Astor

| Ansatz | Operatoren | Ingredients | Besonderheit |
|--------|------------|-------------|--------------|
| **jGenProg** | Remove, Replace, InsertBefore, InsertAfter | Statement-Level | Ingredient-basiert |
| **jKali** | Remove, InsertReturn, ReplaceWithNull | Keine | Nur destruktive Operatoren |
| **jMutRepair** | MutationOperators | Keine | Mutiert Operatoren/Literale |
| **Cardumen** | Replace | Expression-Level | Template-basiert |

---

## 2. Architekturübersicht

### Klassenvererbungshierarchie

```
                    AstorCoreEngine
                          │
                          ▼
                 EvolutionarySearchEngine
                          │
                          ▼
         IngredientBasedEvolutionaryRepairApproachImpl
                          │
                          ▼
                      JGenProg
```

### Datenfluss-Diagramm

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           jGenProg Datenfluss                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────┐                                                          │
│  │ Buggy Program   │                                                          │
│  │ (Source Code)   │                                                          │
│  └────────┬────────┘                                                          │
│           │                                                                   │
│           ▼                                                                   │
│  ┌─────────────────┐    ┌─────────────────┐                                   │
│  │ Spoon Parser    │───►│ AST Model       │                                   │
│  │ (Java→AST)      │    │ (CtClass, etc.) │                                   │
│  └─────────────────┘    └────────┬────────┘                                   │
│                                  │                                            │
│           ┌──────────────────────┴──────────────────────┐                     │
│           ▼                                             ▼                     │
│  ┌─────────────────┐                           ┌─────────────────┐            │
│  │ Fault           │                           │ Ingredient Pool │            │
│  │ Localization    │                           │ Builder         │            │
│  │ (GZoltar/FL)    │                           │                 │            │
│  └────────┬────────┘                           └────────┬────────┘            │
│           │                                             │                     │
│           ▼                                             ▼                     │
│  ┌─────────────────┐                           ┌─────────────────┐            │
│  │ Suspicious      │                           │ Ingredient      │            │
│  │ Locations       │                           │ Space           │            │
│  │ (Line + Score)  │                           │ (Statements)    │            │
│  └────────┬────────┘                           └────────┬────────┘            │
│           │                                             │                     │
│           └──────────────────────┬──────────────────────┘                     │
│                                  ▼                                            │
│                         ┌─────────────────┐                                   │
│                         │ Modification    │                                   │
│                         │ Points          │                                   │
│                         │ (MP + Context)  │                                   │
│                         └────────┬────────┘                                   │
│                                  │                                            │
│                                  ▼                                            │
│                         ┌─────────────────┐                                   │
│                         │ Program Variant │                                   │
│                         │ (Original)      │                                   │
│                         └────────┬────────┘                                   │
│                                  │                                            │
│                    ┌─────────────┴─────────────┐                              │
│                    ▼                           ▼                              │
│           ┌─────────────────┐         ┌─────────────────┐                     │
│           │ Mutation        │         │ Validation      │                     │
│           │ (Operators)     │◄───────►│ (Compile+Test)  │                     │
│           └────────┬────────┘         └────────┬────────┘                     │
│                    │                           │                              │
│                    └───────────┬───────────────┘                              │
│                                ▼                                              │
│                       ┌─────────────────┐                                     │
│                       │ Solution/Patch  │                                     │
│                       │ (Diff + JSON)   │                                     │
│                       └─────────────────┘                                     │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Kern-Datenstrukturen

#### ProgramVariant

Eine `ProgramVariant` repräsentiert eine (möglicherweise modifizierte) Version des Programms:

```java
public class ProgramVariant {
    protected int id;                                    // Eindeutige ID
    protected List<ModificationPoint> modificationPoints; // Alle modifizierbaren Stellen
    protected Map<Integer, List<OperatorInstance>> operations; // Operationen pro Generation
    protected double fitness;                            // Fitness-Wert (0.0-1.0)
    protected ProgramVariant parent;                     // Eltern-Variante
    protected int generationSource;                      // Geburts-Generation
    protected CompilationResult compilationResult;       // Kompilierungsergebnis
    protected boolean isSolution;                        // Ist es ein valider Patch?
    protected List<CtClass> modifiedClasses;             // Geänderte Klassen
    protected VariantValidationResult validationResult;  // Test-Ergebnisse
    protected PatchDiff patchDiff;                       // Diff zum Original
}
```

#### ModificationPoint

Ein `ModificationPoint` repräsentiert eine modifizierbare Code-Stelle:

```java
public class ModificationPoint {
    protected ProgramVariant programVariant;  // Zugehörige Variante
    protected CtElement codeElement;          // Das Spoon-Element (Statement)
    protected CtClass ctClass;                // Die enthaltende Klasse
    protected List<CtVariable> contextOfModificationPoint; // Variablen im Scope
    public int identified;                    // Eindeutige ID
    protected int generation;                 // Wann erstellt
}
```

#### SuspiciousModificationPoint (erweitert ModificationPoint)

```java
public class SuspiciousModificationPoint extends ModificationPoint {
    protected SuspiciousCode suspicious;  // FL-Informationen
    // → Enthält: className, lineNumber, suspiciousValue (0.0-1.0)
}
```

### Schlüsselklassen und ihre Verantwortlichkeiten

#### `AstorCoreEngine.java`
**Pfad:** `src/main/java/fr/inria/astor/core/solutionsearch/AstorCoreEngine.java`

Die Basisklasse für alle Reparaturansätze. Verantwortlich für:
- Initialisierung des Spoon-Modells (AST)
- Verwaltung der Programmvarianten
- Kompilierung und Test-Validierung
- Output-Generierung (Patches, JSON)

```java
public abstract class AstorCoreEngine implements AstorExtensionPoint {
    protected MutationSupporter mutatorSupporter;      // AST-Manipulation
    protected ProjectRepairFacade projectFacade;       // Projektinformationen
    protected FaultLocalizationStrategy faultLocalization;  // Fehlerlokalisation
    protected List<ProgramVariant> variants;           // Aktuelle Population
    protected List<ProgramVariant> solutions;          // Gefundene Patches
    // ...
}
```

#### `EvolutionarySearchEngine.java`
**Pfad:** `src/main/java/fr/inria/astor/core/solutionsearch/EvolutionarySearchEngine.java`

Implementiert den evolutionären Such-Loop:

```java
public void startSearch() throws Exception {
    while (!stopSearch) {
        // Prüfe Abbruchbedingungen
        if (generationsExecuted >= maxGeneration) break;
        if (!belowMaxTime(dateInitEvolution, maxMinutes)) break;
        
        generationsExecuted++;
        boolean solutionFound = processGenerations(generationsExecuted);
        
        if (solutionFound && stopFirst) break;
    }
}
```

#### `IngredientBasedEvolutionaryRepairApproachImpl.java`
**Pfad:** `src/main/java/fr/inria/astor/core/ingredientbased/IngredientBasedEvolutionaryRepairApproachImpl.java`

Erweitert den evolutionären Ansatz um Ingredient-basierte Reparatur:

```java
public abstract class IngredientBasedEvolutionaryRepairApproachImpl 
    extends EvolutionarySearchEngine implements IngredientBasedApproach {
    
    protected IngredientSearchStrategy ingredientSearchStrategy;
    protected IngredientTransformationStrategy ingredientTransformationStrategy;
    protected IngredientPool ingredientPool;
}
```

#### `JGenProg.java`
**Pfad:** `src-jgenprog/main/java/fr/inria/astor/approaches/jgenprog/JGenProg.java`

Die konkrete jGenProg-Implementierung:

```java
public class JGenProg extends IngredientBasedEvolutionaryRepairApproachImpl {

    public JGenProg(MutationSupporter mutatorExecutor, ProjectRepairFacade projFacade) {
        super(mutatorExecutor, projFacade);
        // Standard: Statement-Level Reparatur
        setPropertyIfNotDefined(ExtensionPoints.OPERATORS_SPACE.identifier, "irr-statements");
        setPropertyIfNotDefined(ExtensionPoints.TARGET_CODE_PROCESSOR.identifier, "statements");
    }

    @Override
    public void loadOperatorSpaceDefinition() throws Exception {
        super.loadOperatorSpaceDefinition();
        if (this.getOperatorSpace() == null) {
            this.setOperatorSpace(new jGenProgSpace());  // 4 Operatoren
        }
    }
}
```

---

## 3. Fehlerlokalisation (Fault Localization)

### Überblick

Die Fehlerlokalisation identifiziert **verdächtige Code-Stellen**, die wahrscheinlich den Bug enthalten. Astor unterstützt mehrere Fehlerlokalisation-Strategien:

| Strategie | Beschreibung |
|-----------|--------------|
| **GZoltar** | Spectrum-Based Fault Localization |
| **Flacoco** | Moderne Alternative zu GZoltar |
| **CocoSpoon** | Code-Coverage-basiert |

### Spectrum-Based Fault Localization (SBFL)

SBFL analysiert die **Test-Ausführungs-Coverage** um verdächtige Zeilen zu identifizieren:

```
                    ┌─────────────────────────────────────┐
                    │     Test Suite Execution            │
                    ├─────────────────────────────────────┤
                    │  Test 1: PASS  → Lines covered: A,B │
                    │  Test 2: FAIL  → Lines covered: A,C │
                    │  Test 3: PASS  → Lines covered: B   │
                    │  Test 4: FAIL  → Lines covered: A,C │
                    └─────────────────────────────────────┘
                                    │
                                    ▼
                    ┌─────────────────────────────────────┐
                    │     Suspiciousness Calculation      │
                    ├─────────────────────────────────────┤
                    │  Line A: 0.5  (covered by both)     │
                    │  Line B: 0.0  (only passing tests)  │
                    │  Line C: 1.0  (only failing tests)  │◄─ Höchste Priorität
                    └─────────────────────────────────────┘
```

### Ochiai-Formel

Die Standard-Formel zur Berechnung der Verdächtigkeit:

```
                         failed(s)
Suspiciousness(s) = ─────────────────────────
                    √(totalFailed × (failed(s) + passed(s)))

Wobei:
- failed(s) = Anzahl fehlgeschlagener Tests, die Zeile s ausführen
- passed(s) = Anzahl bestandener Tests, die Zeile s ausführen
- totalFailed = Gesamtanzahl fehlgeschlagener Tests
```

### Integration in Astor

```java
// FaultLocalizationStrategy Interface
public interface FaultLocalizationStrategy {
    FaultLocalizationResult searchSuspicious(ProjectRepairFacade projectToRepair);
}

// Ergebnis enthält Liste verdächtiger Code-Stellen
public class SuspiciousCode {
    private String className;
    private int lineNumber;
    private double suspiciousValue;  // 0.0 bis 1.0
}
```

### Konfiguration

```properties
# astor.properties
faultlocalization=gzoltar       # oder: flacoco, cocospoon
flthreshold=0.1                 # Mindest-Verdächtigkeitswert
skipfaultlocalization=false     # true = alle Statements gleich verdächtig
```

---

## 4. Ingredient Space und Scopes

### Was sind Ingredients?

**Ingredients** sind Code-Fragmente, die zur Reparatur verwendet werden können. jGenProg nutzt existierenden Code aus dem Projekt als "Spendermaterial".

### Ingredient Scopes

Der **Scope** definiert, woher Ingredients stammen können:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GLOBAL SCOPE                                  │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                     PACKAGE SCOPE                               │ │
│  │  ┌──────────────────────────────────────────────────────────┐  │ │
│  │  │                    LOCAL SCOPE                            │  │ │
│  │  │                                                           │  │ │
│  │  │    class BuggyClass {                                     │  │ │
│  │  │        void buggyMethod() {                               │  │ │
│  │  │            // Ingredients von HIER (same file)            │  │ │
│  │  │        }                                                  │  │ │
│  │  │    }                                                      │  │ │
│  │  │                                                           │  │ │
│  │  └──────────────────────────────────────────────────────────┘  │ │
│  │                                                                 │ │
│  │    // + Ingredients aus gleichem Package                        │ │
│  │                                                                 │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│    // + Ingredients aus dem gesamten Projekt                         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

| Scope | Klasse | Beschreibung |
|-------|--------|--------------|
| `local` | `LocalIngredientSpace` | Nur aus derselben Datei |
| `package` | `PackageBasicFixSpace` | Aus dem gleichen Package (Standard) |
| `global` | `GlobalBasicIngredientSpace` | Aus dem gesamten Projekt |

### Implementierung

```java
// IngredientBasedEvolutionaryRepairApproachImpl.java
public static IngredientPool getIngredientPool(List<TargetElementProcessor<?>> ingredientProcessors) {
    String scope = ConfigurationProperties.properties.getProperty("scope");
    
    if ("global".equals(scope)) {
        return new GlobalBasicIngredientSpace(ingredientProcessors);
    } else if ("package".equals(scope)) {
        return new PackageBasicFixSpace(ingredientProcessors);
    } else if ("local".equals(scope) || "file".equals(scope)) {
        return new LocalIngredientSpace(ingredientProcessors);
    }
    // ...
}
```

### Ingredient Search Strategies

| Strategie | Beschreibung |
|-----------|--------------|
| `SimpleRandomSelectionIngredientStrategy` | Zufällige Auswahl |
| `ProbabilisticIngredientStrategy` | Wahrscheinlichkeitsbasiert |
| `CloneIngredientSearchStrategy` | Code-Ähnlichkeit (DeepRepair) |

---

## 5. Repair Operators

### jGenProgSpace - Die vier Operatoren

```java
// jGenProgSpace.java
public class jGenProgSpace extends OperatorSpace {
    public jGenProgSpace() {
        super.register(new RemoveOp());       // Statement entfernen
        super.register(new ReplaceOp());      // Statement ersetzen
        super.register(new InsertAfterOp());  // Statement danach einfügen
        super.register(new InsertBeforeOp()); // Statement davor einfügen
    }
}
```

### Operator-Übersicht

| Operator | Benötigt Ingredient? | Aktion | Typischer Fix |
|----------|---------------------|--------|---------------|
| `RemoveOp` | Nein | Statement löschen | Unreachable Code, falsche Exception |
| `ReplaceOp` | Ja | Statement ersetzen | Falsche Methode, falscher Parameter |
| `InsertAfterOp` | Ja | Statement danach einfügen | Fehlende Initialisierung |
| `InsertBeforeOp` | Ja | Statement davor einfügen | Fehlende Null-Checks |

### Operator 1: RemoveOp

**Aktion:** Entfernt ein Statement komplett aus dem AST

```java
// Vorher:
if (x > 0) {
    doSomething();
    throw new Exception("Error");  // ← Wird entfernt
    doMore();
}

// Nachher:
if (x > 0) {
    doSomething();
    doMore();
}
```

**Implementierung (RemoveOp.java):**
```java
@Override
public boolean applyChangesInModel(OperatorInstance operation, ProgramVariant p) {
    StatementOperatorInstance stmtoperator = (StatementOperatorInstance) operation;
    CtBlock parentBlock = stmtoperator.getParentBlock();
    
    if (parentBlock != null) {
        try {
            // Statement aus dem Parent-Block entfernen
            parentBlock.getStatements().remove(stmtoperator.getLocationInParent());
            successful = true;
            operation.setSuccessfulyApplied(successful);
            // Implizite Block-Markierung aktualisieren
            StatementSupporter.updateBlockImplicitly(parentBlock, false);
        } catch (Exception ex) {
            log.error("Error applying an operation: " + ex.getMessage());
            operation.setExceptionAtApplied(ex);
            operation.setSuccessfulyApplied(false);
        }
    }
    return successful;
}
```

**Einschränkungen (`canBeAppliedToPoint`):**
```java
@Override
public boolean canBeAppliedToPoint(ModificationPoint point) {
    // 1. Muss ein Statement sein
    if (!(point.getCodeElement() instanceof CtStatement))
        return false;
    
    // 2. Keine lokalen Variablendeklarationen entfernen
    //    (es sei denn, sie "shadowen" ein Feld)
    if (point.getCodeElement() instanceof CtLocalVariable) {
        CtLocalVariable lv = (CtLocalVariable) point.getCodeElement();
        CtClass parentC = point.getCodeElement().getParent(CtClass.class);
        boolean shadow = false;
        for (CtField<?> f : parentC.getFields()) {
            if (f.getSimpleName().equals(lv.getSimpleName()))
                shadow = true;
        }
        if (!shadow) return false;
    }
    
    // 3. Nicht das letzte Return-Statement einer Methode entfernen
    CtMethod parentMethod = point.getCodeElement().getParent(CtMethod.class);
    if (point.getCodeElement() instanceof CtReturn
            && parentMethod.getBody().getLastStatement().equals(point.getCodeElement())) {
        return false;
    }
    
    return true;
}
```

### Operator 2: ReplaceOp

**Aktion:** Ersetzt ein Statement durch ein Ingredient

```java
// Vorher (Math_70 Bug):
return solve(min, max);  // ← Buggy: Parameter f fehlt

// Nachher (mit Ingredient aus der Klasse):
return solve(f, min, max);  // ← Fixed
```

**Implementierung (ReplaceOp.java):**
```java
@Override
public boolean applyChangesInModel(OperatorInstance operation, ProgramVariant p) {
    StatementOperatorInstance stmtoperator = (StatementOperatorInstance) operation;
    CtStatement original = (CtStatement) operation.getOriginal();
    CtStatement fix = (CtStatement) operation.getModified();
    CtBlock parentBlock = stmtoperator.getParentBlock();
    
    if (parentBlock != null) {
        try {
            // Spoon's replace() Methode für AST-Ersetzung
            original.replace(fix);
            // Parent-Beziehung aktualisieren
            fix.setParent(parentBlock);
            successful = true;
            operation.setSuccessfulyApplied(successful);
        } catch (Exception ex) {
            log.error("Error applying operation: " + ex.getMessage());
            operation.setExceptionAtApplied(ex);
            operation.setSuccessfulyApplied(false);
        }
    }
    return successful;
}

@Override
public boolean undoChangesInModel(OperatorInstance operation, ProgramVariant p) {
    // Rückgängig machen: fix durch original ersetzen
    CtStatement fix = (CtStatement) operation.getModified();
    CtStatement original = (CtStatement) operation.getOriginal();
    fix.replace(original);
    return true;
}
```

### Operator 3: InsertAfterOp

**Aktion:** Fügt ein Ingredient nach dem Modification Point ein

```java
// Vorher:
public void process(Object input) {
    doProcessing(input);  // ← Modification Point
}

// Nachher:
public void process(Object input) {
    doProcessing(input);
    validate(input);      // ← Eingefügt (Ingredient)
}
```

**Implementierung (InsertAfterOp.java):**
```java
@Override
public boolean applyChangesInModel(OperatorInstance operation, ProgramVariant p) {
    StatementOperatorInstance stmtoperator = (StatementOperatorInstance) operation;
    boolean successful = false;  // ← Lokale Variable (korrekt!)
    CtStatement ctst = (CtStatement) operation.getOriginal();
    CtStatement fix = (CtStatement) operation.getModified();
    CtBlock parentBlock = stmtoperator.getParentBlock();
    
    if (parentBlock != null) {
        // Spoon's insertAfter() fügt fix NACH ctst ein
        ctst.insertAfter((CtStatement) fix);
        fix.setParent(parentBlock);
        successful = true;
        StatementSupporter.updateBlockImplicitly(parentBlock, true);
    }
    return successful;
}

@Override
public boolean canBeAppliedToPoint(ModificationPoint point) {
    boolean apply = super.canBeAppliedToPoint(point);
    if (!apply) return false;
    
    // Nicht nach einem Return einfügen (unreachable code!)
    if (point.getCodeElement() instanceof CtReturn) {
        return false;
    }
    return true;
}
```

### Operator 4: InsertBeforeOp

**Aktion:** Fügt ein Ingredient vor dem Modification Point ein

```java
// Vorher:
public void process(Object input) {
    doProcessing(input);  // ← Modification Point (kann NPE werfen)
}

// Nachher:
public void process(Object input) {
    if (input == null) return;  // ← Eingefügt (Null-Check)
    doProcessing(input);
}
```

**Implementierung (InsertBeforeOp.java):**
```java
@Override
public boolean applyChangesInModel(OperatorInstance operation, ProgramVariant p) {
    CtStatement ctst = (CtStatement) operation.getOriginal();
    CtStatement fix = (CtStatement) operation.getModified();
    StatementOperatorInstance stmtoperator = (StatementOperatorInstance) operation;
    CtBlock parentBlock = stmtoperator.getParentBlock();
    
    if (parentBlock != null) {
        // WICHTIG: Kann nicht vor super() oder this() Aufrufen einfügen!
        if (ctst instanceof CtInvocation && 
            ((CtInvocation<?>) ctst).getExecutable().getSimpleName()
                .startsWith(CtExecutableReference.CONSTRUCTOR_NAME)) {
            log.error("Cannot insert before super or this: " + ctst);
            return false;
        }
        
        ctst.insertBefore((CtStatement) fix);
        fix.setParent(parentBlock);
        successful = true;  // ⚠️ BUG: Instanzvariable statt lokal!
        StatementSupporter.updateBlockImplicitly(parentBlock, true);
    }
    return successful;
}

@Override
public boolean canBeAppliedToPoint(ModificationPoint point) {
    boolean apply = super.canBeAppliedToPoint(point);
    if (!apply) return false;
    
    // Nicht vor Constructor-Calls (super/this)
    if (point.getCodeElement() instanceof CtConstructorCall) {
        return false;
    }
    return true;
}
```

### Operator-Auswahl-Strategie

Die Auswahl des Operators erfolgt durch `OperatorSelectionStrategy`:

```java
// UniformRandomRepairOperatorSpace (Standard)
public AstorOperator getNextOperator(SuspiciousModificationPoint point) {
    List<AstorOperator> operators = getOperatorSpace().getOperators();
    // Filtere Operatoren, die auf diesen Punkt anwendbar sind
    List<AstorOperator> applicable = operators.stream()
        .filter(op -> op.canBeAppliedToPoint(point))
        .collect(Collectors.toList());
    
    if (applicable.isEmpty()) return null;
    
    // Zufällige Auswahl mit gleichverteilter Wahrscheinlichkeit
    int index = RandomManager.nextInt(applicable.size());
    return applicable.get(index);
}
```

**Alternative Strategien:**
- `WeightedRandomOperatorSelection`: Operatoren mit Gewichten
- Benutzerdefinierte via `-customop` Parameter

---

## 6. Ingredient Search & Transformation Strategies

### Ingredient Search Strategies

Die Suche nach geeigneten Ingredients erfolgt durch verschiedene Strategien:

```java
// IngredientBasedEvolutionaryRepairApproachImpl.java
public static IngredientSearchStrategy retrieveIngredientSearchStrategy(IngredientPool ingredientspace) {
    String strategy = ConfigurationProperties.getProperty("ingredientstrategy");
    
    if ("uniform-random".equals(strategy)) {
        return new SimpleRandomSelectionIngredientStrategy(ingredientspace);
    } else if ("name-probability-based".equals(strategy)) {
        return new ProbabilisticIngredientStrategy(ingredientspace);
    } else if ("code-similarity-based".equals(strategy)) {
        return new CloneIngredientSearchStrategy(ingredientspace);
    }
    // Default
    return new SimpleRandomSelectionIngredientStrategy(ingredientspace);
}
```

| Strategie | Klasse | Beschreibung |
|-----------|--------|--------------|
| `uniform-random` | `SimpleRandomSelectionIngredientStrategy` | Zufällige Auswahl (Standard) |
| `name-probability-based` | `ProbabilisticIngredientStrategy` | Wahrscheinlichkeitsbasiert nach Namen |
| `code-similarity-based` | `CloneIngredientSearchStrategy` | Code-Ähnlichkeit (DeepRepair) |

### Ingredient Transformation Strategies

Ingredients können transformiert werden, um bessere Passung zu erreichen:

```java
public static IngredientTransformationStrategy retrieveIngredientTransformationStrategy() {
    String strategy = ConfigurationProperties.getProperty("ingredienttransformstrategy");
    
    if ("no-transformation".equals(strategy)) {
        return new NoIngredientTransformationWithCheck();
    } else if ("random-variable-replacement".equals(strategy)) {
        return new RandomTransformationStrategy();
    } else if ("name-cluster-based".equals(strategy)) {
        return new ClusterIngredientTransformation();
    } else if ("name-probability-based".equals(strategy)) {
        return new ProbabilisticTransformationStrategy();
    }
    // Default: keine Transformation
    return new NoIngredientTransformationWithCheck();
}
```

| Strategie | Beschreibung |
|-----------|--------------|
| `no-transformation` | Ingredient wird 1:1 verwendet (Standard) |
| `random-variable-replacement` | Variablennamen werden zufällig ersetzt |
| `name-cluster-based` | Variablen nach Namens-Cluster ersetzen |
| `name-probability-based` | Variablen nach Namens-Wahrscheinlichkeit ersetzen |

### Beispiel: Ingredient Transformation

```java
// Original Ingredient aus dem Projekt:
if (data == null) {
    throw new IllegalArgumentException("data");
}

// Nach Transformation (random-variable-replacement):
// Variable "data" wird durch "input" ersetzt (aus dem Scope)
if (input == null) {
    throw new IllegalArgumentException("input");
}
```

---

## 7. Evolutionärer Algorithmus

### Gesamtablauf

```
┌────────────────────────────────────────────────────────────────────────┐
│                        jGenProg Main Loop                               │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────┐                                               │
│  │ 1. INITIALISIERUNG   │                                               │
│  │    - Fault Localization                                              │
│  │    - Ingredient Pool aufbauen                                        │
│  │    - Initiale Population (Original-Programm)                         │
│  └──────────┬───────────┘                                               │
│             │                                                           │
│             ▼                                                           │
│  ┌──────────────────────┐                                               │
│  │ 2. GENERATION LOOP   │◄─────────────────────────────────┐            │
│  └──────────┬───────────┘                                  │            │
│             │                                              │            │
│             ▼                                              │            │
│  ┌──────────────────────┐                                  │            │
│  │ 3. Für jede Variante │                                  │            │
│  │    in Population:    │                                  │            │
│  │                      │                                  │            │
│  │    a) Modification   │                                  │            │
│  │       Point wählen   │                                  │            │
│  │                      │                                  │            │
│  │    b) Operator       │                                  │            │
│  │       auswählen      │                                  │            │
│  │                      │                                  │            │
│  │    c) (Optional)     │                                  │            │
│  │       Ingredient     │                                  │            │
│  │       suchen         │                                  │            │
│  │                      │                                  │            │
│  │    d) Mutation       │                                  │            │
│  │       anwenden       │                                  │            │
│  └──────────┬───────────┘                                  │            │
│             │                                              │            │
│             ▼                                              │            │
│  ┌──────────────────────┐                                  │            │
│  │ 4. KOMPILIERUNG      │                                  │            │
│  │    Variante          │                                  │            │
│  │    kompilieren       │                                  │            │
│  └──────────┬───────────┘                                  │            │
│             │                                              │            │
│         ┌───┴───┐                                          │            │
│         │Erfolg?│                                          │            │
│         └───┬───┘                                          │            │
│          Ja │ Nein → Variante verwerfen ──────────────────►│            │
│             ▼                                              │            │
│  ┌──────────────────────┐                                  │            │
│  │ 5. TEST-VALIDIERUNG  │                                  │            │
│  │    Tests ausführen   │                                  │            │
│  └──────────┬───────────┘                                  │            │
│             │                                              │            │
│         ┌───┴────────┐                                     │            │
│         │Alle Tests  │                                     │            │
│         │bestanden?  │                                     │            │
│         └───┬────────┘                                     │            │
│          Ja │ Nein → Fitness berechnen                     │            │
│             │         zur Population hinzufügen ──────────►│            │
│             ▼                                              │            │
│  ┌──────────────────────┐                                  │            │
│  │ 6. LÖSUNG GEFUNDEN!  │                                  │            │
│  │    - Patch speichern │                                  │            │
│  │    - (Optional) Stop │                                  │            │
│  └──────────────────────┘                                  │            │
│             │                                              │            │
│             ▼                                              │            │
│  ┌──────────────────────┐                                  │            │
│  │ 7. POPULATION UPDATE │                                  │            │
│  │    - Selection       │──────────────────────────────────┘            │
│  │    - (Opt.) Crossover│                                               │
│  └──────────────────────┘                                               │
│                                                                         │
│  STOP wenn: maxGeneration erreicht ODER maxTime ODER Lösung gefunden    │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: Initialisierung

```java
// AstorCoreEngine.initPopulation()
public void initPopulation(List<SuspiciousCode> suspicious) throws Exception {
    // 1. Spoon-Modell erstellen (AST des Programms)
    buildModel();
    
    // 2. Modification Points aus verdächtigen Zeilen erstellen
    List<ModificationPoint> modificationPoints = 
        createModificationPoints(suspicious);
    
    // 3. Original-Variante erstellen
    originalVariant = variantFactory.createProgramVariant(modificationPoints);
    
    // 4. Population initialisieren
    variants.add(originalVariant);
}
```

### Phase 2-3: Generation Loop und Mutation

```java
// EvolutionarySearchEngine.processGenerations()
private boolean processGenerations(int generation) {
    List<ProgramVariant> temporalInstances = new ArrayList<>();
    
    for (ProgramVariant parentVariant : variants) {
        // Kind-Variante erstellen
        ProgramVariant newVariant = createNewProgramVariant(parentVariant, generation);
        
        if (newVariant != null) {
            temporalInstances.add(newVariant);
            boolean solution = processCreatedVariant(newVariant, generation);
            
            if (solution) {
                foundSolution = true;
            }
        }
    }
    
    // Population für nächste Generation vorbereiten
    prepareNextGeneration(temporalInstances, generation);
    return foundSolution;
}
```

### Phase 4-5: Kompilierung und Validierung

```java
// AstorCoreEngine.processCreatedVariant()
public boolean processCreatedVariant(ProgramVariant variant, int generation) {
    // 1. Kompilieren
    CompilationResult compilation = compiler.compile(variant);
    
    if (!compilation.compiles()) {
        return false;  // Compile-Fehler
    }
    
    // 2. Tests ausführen
    VariantValidationResult validation = programValidator.validate(variant);
    
    // 3. Fitness berechnen
    variant.setFitness(fitnessFunction.calculateFitness(validation));
    
    // 4. Ist es eine Lösung?
    return validation.isSuccessful();
}
```

### Fitness-Funktion

```java
// Standard: Anzahl bestandener Tests
public double calculateFitness(VariantValidationResult result) {
    return result.getPassingTestCases() / result.getTotalTestCases();
}
```

### Population Control

```java
// prepareNextGeneration() - Selektion der besten Varianten
variants = populationControler.selectProgramVariantsForNextGeneration(
    variants,           // Alte Population
    temporalInstances,  // Neue Varianten dieser Generation
    populationSize,     // Maximale Populationsgröße
    variantFactory,
    originalVariant,
    generation
);
```

---

## 8. Defects4J Integration

### Was ist Defects4J?

**Defects4J** ist ein Benchmark-Dataset mit realen Bugs aus Java-Projekten. Es ist der de-facto Standard für die Evaluation von Java Program Repair Tools.

| Projekt | Bugs | LOC | Beschreibung |
|---------|------|-----|--------------|
| Chart | 26 | ~96k | JFreeChart - Diagramm-Bibliothek |
| Lang | 65 | ~22k | Apache Commons Lang |
| Math | 106 | ~85k | Apache Commons Math |
| Time | 27 | ~28k | Joda-Time Datum/Zeit |
| Closure | 176 | ~90k | Google Closure Compiler |
| Mockito | 38 | ~11k | Mocking-Framework |

**Gesamt (v2.0):** 835 Bugs aus 17 Projekten

### Defects4J Architektur

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        Defects4J Workflow                                 │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────┐         ┌─────────────────┐                          │
│  │ Bug Repository  │────────►│ defects4j       │                          │
│  │ (Git Commits)   │         │ checkout        │                          │
│  └─────────────────┘         └────────┬────────┘                          │
│                                       │                                   │
│                                       ▼                                   │
│                              ┌─────────────────┐                          │
│                              │ Buggy Version   │                          │
│                              │ (Source Code)   │                          │
│                              └────────┬────────┘                          │
│                                       │                                   │
│           ┌───────────────────────────┼───────────────────────────┐       │
│           ▼                           ▼                           ▼       │
│  ┌─────────────────┐         ┌─────────────────┐         ┌─────────────┐  │
│  │ defects4j       │         │ defects4j       │         │ defects4j   │  │
│  │ export -p ...   │         │ compile         │         │ test        │  │
│  └────────┬────────┘         └────────┬────────┘         └──────┬──────┘  │
│           │                           │                         │         │
│           ▼                           ▼                         ▼         │
│  ┌─────────────────┐         ┌─────────────────┐         ┌─────────────┐  │
│  │ Project Info    │         │ Compiled        │         │ Test        │  │
│  │ (dirs, cp)      │         │ Bytecode        │         │ Results     │  │
│  └─────────────────┘         └─────────────────┘         └─────────────┘  │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

### Defects4J Setup

```bash
# 1. Defects4J installieren
git clone https://github.com/rjust/defects4j.git
cd defects4j
./init.sh

# 2. Environment Variables setzen
export D4J_HOME=/path/to/defects4j
export PATH=$D4J_HOME/framework/bin:$PATH

# 3. Installation verifizieren
defects4j info -p Math
```

### Bug auschecken und vorbereiten

```bash
# Bug auschecken (b = buggy, f = fixed)
defects4j checkout -p Math -v 70b -w /tmp/Math_70

cd /tmp/Math_70

# Kompilieren
defects4j compile

# Tests ausführen (zum Verifizieren des Bugs)
defects4j test
# → Sollte mindestens 1 fehlgeschlagenen Test zeigen
```

### Projekt-Informationen für Astor exportieren

```bash
# Verzeichnisse
SRC=$(defects4j export -p dir.src.classes)      # src/main/java
TST=$(defects4j export -p dir.src.tests)        # src/test/java  
BIN=$(defects4j export -p dir.bin.classes)      # target/classes
BINT=$(defects4j export -p dir.bin.tests)       # target/test-classes

# Classpath für Tests
DEPS=$(defects4j export -p cp.test)

# Fehlgeschlagene Tests
FAILING=$(defects4j export -p tests.trigger)
# → org.apache.commons.math.analysis.solvers.BisectionSolverTest::testMath369

# Für Astor: Format anpassen (:: → #)
FAILING_ASTOR=$(echo $FAILING | head -n 1 | sed 's/::#/')
```

### Astor auf Defects4J ausführen

#### Variante 1: Manueller Aufruf

```bash
cd /tmp/Math_70

# Astor ausführen
java -cp /path/to/astor.jar fr.inria.main.evolution.AstorMain \
    -mode jgenprog \
    -location $(pwd) \
    -srcjavafolder $SRC \
    -srctestfolder $TST \
    -binjavafolder $BIN \
    -bintestfolder $BINT \
    -dependencies "$DEPS" \
    -failing "$FAILING_ASTOR" \
    -scope package \
    -maxtime 60 \
    -stopfirst true \
    -seed 12345
```

#### Variante 2: Docker (empfohlen für Reproduzierbarkeit)

```bash
# Einfachster Aufruf
docker run -it --rm tdurieux/astor --id Math_70

# Mit lokaler Ergebnis-Speicherung
docker run -it --rm \
    -v /tmp/results:/results \
    tdurieux/astor \
    -i Math_70 \
    --scope package \
    --parameters maxGeneration:200:stopfirst:true:seed:12345
```

#### Variante 3: Eigenes Docker-Image

```dockerfile
# Dockerfile für Astor + Defects4J
FROM ubuntu:22.04

# ... (siehe docs/astor-docker.md für vollständiges Dockerfile)

# Runner-Skript für jGenProg
RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'BUG="${1:-Math-70}"' \
    '/usr/local/bin/d4j-checkout "$BUG" /work' \
    'cd "/work/${BUG}"' \
    'java -cp "$ASTOR_JAR" fr.inria.main.evolution.AstorMain \' \
    '  -mode jgenprog -location . ...' \
    > /usr/local/bin/astor-jgenprog && chmod +x /usr/local/bin/astor-jgenprog
```

### Beispiel: Vollständige Reparatur von Math_70

**Bug-Beschreibung:** Falsche Methoden-Signatur in `BisectionSolver.solve()`

```java
// Buggy Code (Math_70, BisectionSolver.java:72):
public double solve(final UnivariateRealFunction f, 
                    double min, double max, double initial) {
    return solve(min, max);  // ← BUG: Parameter 'f' fehlt!
}

// Erwarteter Fix:
public double solve(final UnivariateRealFunction f,
                    double min, double max, double initial) {
    return solve(f, min, max);  // ← KORREKT
}
```

**jGenProg Reparatur-Ablauf:**

```
1. Fault Localization:
   → BisectionSolver.java:72 (suspiciousness: 1.0)

2. Ingredient Search (LOCAL scope):
   → Findet: "return solve(f, min, max);" in derselben Klasse

3. Operator Selection:
   → ReplaceOp ausgewählt

4. Mutation anwenden:
   → Original ersetzen durch Ingredient

5. Validierung:
   → Kompiliert: ✓
   → Tests: 1981/1981 bestanden ✓

6. SOLUTION FOUND!
```

**Output:**
```
PATCH_DIFF=
--- BisectionSolver.java (original)
+++ BisectionSolver.java (variant-34)
@@ -69,7 +69,7 @@
 public double solve(final UnivariateRealFunction f,
                     double min, double max, double initial) {
-    return solve(min, max);
+    return solve(f, min, max);
 }
```

### Bekannte Defects4J-Kompatibilitätsprobleme

| Problem | Ursache | Lösung |
|---------|---------|--------|
| Java-Version-Mismatch | Ältere Bugs brauchen Java 7/8 | `JAVA_HOME` setzen |
| Classpath-Konflikte | Unterschiedliche Dependency-Versionen | Explizite JAR-Pfade |
| Flaky Tests | Nicht-deterministische Tests | `ignoredTestCases` Parameter |
| Timeout bei großen Projekten | Zu viele Modification Points | `flthreshold` erhöhen |

---

## 9. Konfiguration und Parameter

### Wichtige Konfigurationsparameter

| Parameter | Standard | Beschreibung |
|-----------|----------|--------------|
| `-mode` | - | Modus: `jgenprog`, `jkali`, `jMutRepair` |
| `-location` | - | **Pflicht:** Absoluter Pfad zum Projekt |
| `-scope` | `package` | Ingredient-Scope: `local`, `package`, `global` |
| `-maxGeneration` | `100` | Maximale Generationen |
| `-maxtime` | `60` | Maximale Zeit in Minuten |
| `-stopfirst` | `true` | Nach erstem Patch stoppen |
| `-population` | `1` | Populationsgröße |
| `-flthreshold` | `0.1` | FL-Schwellwert (0.0-1.0) |
| `-seed` | zufällig | Random Seed für Reproduzierbarkeit |

### Pfad-Parameter

```bash
# Quellcode-Verzeichnisse
-srcjavafolder /src/main/java
-srctestfolder /src/test/java

# Bytecode-Verzeichnisse  
-binjavafolder /target/classes
-bintestfolder /target/test-classes

# Dependencies
-dependencies /path/to/libs:/path/to/junit.jar
```

### Fortgeschrittene Parameter

```properties
# astor.properties

# Crossover (deaktiviert wegen Bug!)
applyCrossover=false

# Ingredient-Strategien
ingredientstrategy=uniform-random
ingredienttransformstrategy=no-transformation

# Fault Localization
faultlocalization=gzoltar
skipfaultlocalization=false

# Multi-Point Mutation
multipointmodification=false
allpoints=false

# Output
saveall=false
workingDirectory=./output_astor
```

### Beispiel-Konfiguration für Reproduzierbarkeit

```bash
java -cp astor.jar fr.inria.main.evolution.AstorMain \
    -mode jgenprog \
    -location /path/to/project \
    -seed 12345 \                    # Fester Seed!
    -maxGeneration 200 \
    -maxtime 120 \
    -population 1 \
    -scope package \
    -flthreshold 0.1 \
    -stopfirst true \
    -javacompliancelevel 8
```

---

## 10. Ausführungsbeispiel

### Schritt-für-Schritt Ablauf

```
$ java -cp astor.jar fr.inria.main.evolution.AstorMain \
    -mode jgenprog \
    -location examples/math_70 \
    -failing org.apache.commons.math.analysis.solvers.BisectionSolverTest

[INFO] ---- Starting Astor ----
[INFO] Loading project: examples/math_70

[INFO] ---- Fault Localization ----
[INFO] Running GZoltar...
[INFO] Found 15 suspicious locations

[INFO] ---- Building Ingredient Pool ----
[INFO] Scope: package
[INFO] Collected 342 ingredients (statements)

[INFO] ---- Starting Solution Search ----
[INFO] Initial population: 1 variant

[INFO] ---------- Generation 1 ----------
[INFO] Variant 2: ReplaceOp at BisectionSolver.java:72
[INFO] Compiling... SUCCESS
[INFO] Running tests... 0 failing (was 1)
[INFO] *** SOLUTION FOUND ***

[INFO] ---- Results ----
[INFO] Solutions: 1
[INFO] Time: 16 seconds
[INFO] Generations: 1

PATCH_DIFF=
--- BisectionSolver.java (original)
+++ BisectionSolver.java (patched)
@@ -69,7 +69,7 @@
 	public double solve(UnivariateRealFunction f, 
 	                    double min, double max, double initial) {
-		return solve(min, max);
+		return solve(f, min, max);
 	}
```

### Output-Struktur

```
output_astor/
├── AstorMain-Math-70/
│   ├── astor_output.json          # Zusammenfassung als JSON
│   ├── src/
│   │   ├── default/               # Original-Code
│   │   │   └── org/apache/...
│   │   └── variant-34/            # Gepatchter Code
│   │       └── org/apache/...
│   └── bin/
│       └── variant-34/            # Kompilierter Patch
└── log/
    └── astor.log
```

### JSON-Output Format

```json
{
  "NR_GENERATIONS": 1,
  "TOTAL_TIME": 16000,
  "NR_RIGHT_COMPILATIONS": 1,
  "NR_FAILLING_COMPILATIONS": 0,
  "patches": [
    {
      "VARIANT_ID": "34",
      "GENERATION": "1",
      "TIME": "16",
      "VALIDATION": "|true|0|1981|[]|",
      "patchhunks": [
        {
          "LOCATION": "org.apache.commons.math.analysis.solvers.BisectionSolver",
          "LINE": "72",
          "OPERATOR": "ReplaceOp",
          "ORIGINAL_CODE": "return solve(min, max)",
          "PATCH_HUNK_CODE": "return solve(f, min, max)",
          "INGREDIENT_SCOPE": "LOCAL"
        }
      ]
    }
  ]
}
```

---

## 11. Bekannte Probleme und Limitationen

### 🔴 Kritische Bugs

#### Bug 1: ArrayIndexOutOfBoundsException im Crossover

**Datei:** `JGenProg.java` (Zeilen 73-78)

```java
// BUGGY:
int rgen1index = RandomManager.nextInt(v1.getOperations().keySet().size()) + 1;  // ← + 1 ist falsch!

// nextInt(size) gibt 0 bis size-1 zurück
// Mit +1 wird der Bereich zu 1 bis size
// Array hat aber nur Indizes 0 bis size-1
// → ArrayIndexOutOfBoundsException wenn nextInt() den maximalen Wert zurückgibt
```

**Beispiel:**
```
KeySet size = 2 (Keys: [1, 3])
nextInt(2) → kann 0 oder 1 sein
Mit +1: Index wird 1 oder 2
Array hat nur Indizes 0 und 1 → Index 2 = CRASH!
```

**Workaround:** Crossover ist standardmäßig deaktiviert (`applyCrossover=false`)

**Korrektur:**
```java
int rgen1index = RandomManager.nextInt(v1.getOperations().keySet().size());  // OHNE + 1
```

---

#### Bug 2: Fehlende Leerheitsprüfung für Operationslisten

**Datei:** `JGenProg.java` (Zeilen 79-80)

```java
// BUGGY:
OperatorInstance opinst1 = ops1.remove(RandomManager.nextInt(ops1.size()));

// Wenn ops1.size() == 0, führt nextInt(0) zu IllegalArgumentException!
```

**Korrektur:**
```java
if (ops1.isEmpty() || ops2.isEmpty()) {
    log.debug("CO|Empty operation list for crossover");
    return;
}
```

---

### 🟡 Mittelschwere Probleme

#### Problem 1: Instanzvariable in InsertBeforeOp

**Datei:** `InsertBeforeOp.java` (Zeile 20)

```java
public class InsertBeforeOp extends InsertStatementOp {
    boolean successful = false;  // ⚠️ INSTANZVARIABLE!
    
    // Bei Wiederverwendung behält sie den alten Wert
    // Kann zu falschen Ergebnissen bei undoChangesInModel() führen
}
```

**Vergleich mit InsertAfterOp (korrekt):**
```java
public boolean applyChangesInModel(...) {
    boolean successful = false;  // ✓ LOKALE Variable
    // ...
}
```

---

#### Problem 2: Nicht-deterministische HashMap-Iteration

**Datei:** `JGenProg.java` (Zeilen 77-78)

```java
v1.getOperations().keySet().toArray()[rgen1index]  
// ↑ HashMap.keySet() gibt Keys in UNDEFINIERTER Reihenfolge zurück!
```

**Auswirkung:** 
- Nicht reproduzierbare Ergebnisse zwischen verschiedenen JVM-Starts
- Problematisch für wissenschaftliche Replikationsstudien

**Empfehlung:**
```java
List<Integer> sortedKeys = new ArrayList<>(v1.getOperations().keySet());
Collections.sort(sortedKeys);  // Deterministische Reihenfolge
int selectedKey = sortedKeys.get(rgen1index);
```

---

### ⚠️ Konfigurationsprobleme

#### Windows-Pfadtrenner

```properties
# Unix (Standard in astor.properties):
resourcesfolder=/src/main/resources:/src/test/resources:

# Windows (manuell anpassen!):
resourcesfolder=/src/main/resources;/src/test/resources;

# location für GZoltar
location=/tmp        # Unix
location=C:\temp     # Windows
```

#### Dependency-Konflikte

Astor hat **keine Mechanismen zur Erkennung von Versionskonflikten**:

```
lib/
├── junit-4.11.jar   ← Astor's Standard
├── junit-4.12.jar   ← Neuere Version
└── junit-4.4.jar    ← Defects4J Projekt
```

**Problem:** Alle drei JARs landen im Classpath!

---

### Limitationen des Ansatzes

| Limitation | Beschreibung |
|------------|--------------|
| **Test-Abhängigkeit** | Patch muss nur die Tests bestehen (kann semantisch falsch sein) |
| **Overfitting** | Patches können spezifisch für die Testsuite sein |
| **Ingredient-Limitation** | Kann nur Code verwenden, der bereits im Projekt existiert |
| **Statement-Granularität** | Kann keine Expression-Level Fixes erzeugen |
| **Single-Line Fokus** | Schwierig bei Multi-Location Bugs |

---

## 12. Referenzen

### Wissenschaftliche Publikationen

#### Astor Framework
1. Martinez, M., & Monperrus, M. (2016). *ASTOR: A Program Repair Library for Java.* 
   In Proceedings of ISSTA, Demonstration Track.
   [[PDF]](https://hal.archives-ouvertes.fr/hal-01321615/document)

2. Martinez, M., & Monperrus, M. (2019). *Astor: Exploring the Design Space of Generate-and-Validate Program Repair beyond GenProg.* 
   Journal of Systems and Software.
   [[PDF]](https://arxiv.org/abs/1802.03365)

#### jGenProg Experimente
3. Martinez, M., Durieux, T., Sommerard, R., Xuan, J., & Monperrus, M. (2017). 
   *Automatic Repair of Real Bugs in Java: A Large-Scale Experiment on the Defects4J Dataset.* 
   Empirical Software Engineering, Vol. 22.
   [[PDF]](https://hal.archives-ouvertes.fr/hal-01387556/document)

#### Original GenProg
4. Le Goues, C., Nguyen, T., Forrest, S., & Weimer, W. (2012).
   *GenProg: A Generic Method for Automatic Software Repair.*
   IEEE Transactions on Software Engineering.

#### Defects4J
5. Just, R., Jalali, D., & Ernst, M. D. (2014).
   *Defects4J: A Database of Existing Faults to Enable Controlled Testing Studies for Java Programs.*
   In Proceedings of ISSTA.

### Links

| Resource | URL |
|----------|-----|
| Astor GitHub | https://github.com/SpoonLabs/astor |
| Defects4J | https://github.com/rjust/defects4j |
| Defects4J-Repair Patches | https://github.com/Spirals-Team/defects4j-repair |
| Spoon (AST Framework) | https://github.com/INRIA/spoon |
| GZoltar (FL) | https://github.com/GZoltar/gzoltar |
| Flacoco (FL) | https://github.com/SpoonLabs/flacoco |

### Repaired Bugs (Auswahl)

jGenProg hat folgende Defects4J-Bugs erfolgreich repariert (Stand: April 2016):

| Projekt | Bug IDs |
|---------|---------|
| Chart | 1, 13, 15, 25 |
| Math | 2, 5, 20, 28, 32, 50, 57, 63, 70, 73, 74, 76, 78, 80, 81, 82, 84, 85 |
| Lang | 6, 55, 57, 59 |
| Time | 4, 11 |

**Gesamt:** 29 Bugs repariert (von 395 in Defects4J v1.0)

---

*Dokument erstellt für technische Referenz und wissenschaftliche Arbeiten.*  
*Letzte Aktualisierung: 2026-01-04 (Iteration 3 - Final)*

---

## Anhang: Dokumentenhistorie

| Iteration | Änderungen |
|-----------|------------|
| **1.0** | Initiale Erstellung: Grundstruktur, Architektur, Algorithmus-Übersicht |
| **2.0** | Erweitert: Detaillierte Operator-Implementierungen, Ingredient Strategies, Konfigurationsabschnitt |
| **3.0 (Final)** | Datenfluss-Diagramm, Datenstrukturen, vollständiges Defects4J-Workflow, bekannte Bug-Korrekturen |

### Kritische Review-Punkte

✅ **Abgedeckt:**
- Vollständige Klassenvererbungshierarchie
- Alle 4 Operatoren mit Implementierungsdetails
- Fault Localization Integration
- Ingredient Scopes und Strategien
- Defects4J End-to-End Workflow
- Bekannte Bugs und Workarounds
- Konfigurationsparameter

⚠️ **Offen für zukünftige Iterationen:**
- Performance-Benchmarks
- Vergleich mit anderen Repair-Tools
- Multi-Location Repair Erweiterungen
- Custom Operator Entwicklung Guide

