# JUnit-Pfad-Ermittlung in `NovelGZoltarFaultLocalization`

## Problem
- Bisher wurde hart nach `junit-4.12.jar`/`hamcrest-core-1.3.jar` gesucht und angenommen, dass diese JARs separat im `target`-Verzeichnis liegen.
- In `pom.xml` ist jedoch JUnit 4.13.2 (plus JUnit 5 API/Engine) deklariert und Maven legt Standard-Dependencies nicht als Einzel-JAR in `target` ab (sie stecken im Fat-JAR `astor-*-jar-with-dependencies.jar`).
- Folge: Pfad-Suche lieferte leer und GZoltar-Aufrufe bekamen kein JUnit auf den Classpath.

## Lösung (robust statt Workaround)
- Ermittele zuerst den tatsächlichen Ladeort der JUnit-/Hamcrest-Klassen (`org.junit.runner.JUnitCore`, `org.hamcrest.Matcher`) über deren `CodeSource`. Das liefert den realen JAR-Pfad oder das Fat-JAR, unabhängig von Version und Ablageort.
- Fallback: scannt den aktuellen Classpath allgemein nach `junit`/`hamcrest`-Einträgen (ohne Versions-String-Hardcode).
- Letzter Fallback: rekursiver Scan im `target`-Verzeichnis des Projekts (aus `location`-Property), wieder generisch nach `junit`/`hamcrest`.
- Alle Pfade werden dedupliziert und mit `File.pathSeparator` verbunden.

## Auswirkungen
- Funktioniert mit JUnit 4.13.2 (aktueller `pom.xml`) ebenso wie mit anderen Versionen oder dem Fat-JAR.
- Keine Annahme mehr, dass Einzel-JARs im `target` liegen müssen.

## Hinweise
- Wenn JUnit bewusst nicht gepackt werden soll, sicherstellen, dass es zur Laufzeit im Classpath liegt (z.B. über `-cp` oder `mvn dependency:copy-dependencies`).
- Wenn zusätzliche Test-Libs benötigt werden, kann `resolveLibraryLocation` um weitere Klassen ergänzt werden.

# GZoltar Test-Ausführung in Docker & Test-Filterung

## Problem 1: Fehlende Abhängigkeiten im Docker-Container
- **Symptom:** In der Docker-Umgebung lieferte die dynamische Suche nach JUnit und Hamcrest (`retrieveJUnitLibPath`) leere Pfade zurück. Dies führte dazu, dass der GZoltar-Prozess (`listTestMethods`) fehlschlug.
- **Ursache:** Im Docker-Container waren die benötigten JARs unter `/opt/astor/lib/` abgelegt, aber nicht explizit im Java-Classpath des Hauptprozesses sichtbar oder parsbar.
- **Lösung:**
    - Die Hardcoded-Pfade (`/opt/astor/lib/...`) wurden als expliziter Fallback wieder aktiviert, falls die dynamische Suche fehlschlägt.
    - Verwendung von `File.pathSeparator` anstelle von `:` oder `;`, um Plattformunabhängigkeit (Linux/Windows) zu gewährleisten.
    - Hinzufügen von Debugging-Ausgaben und Prüfungen, ob die Dateien an den Hardcoded-Pfaden tatsächlich existieren.

## Problem 2: Fehlerhafte Test-Filterung
- **Symptom:** GZoltar meldete `FaultLocalizationResult{candidates=[], failingTestCases=[]}` und `No suspicious line detected`, obwohl Tests vorhanden waren. Die Datei `outTest.txt` (von GZoltar generiert) enthielt Tests, aber Astor filterte alle heraus ("Filtered []").
- **Ursache:** 
    - Astor vergleicht die von GZoltar gefundenen Tests (in `outTest.txt`) mit einer Liste von Tests, die ausgeführt werden sollen.
    - `outTest.txt` enthielt Einträge wie `JUNIT,pkg.Class#test`.
    - Die interne Liste `allTest` enthielt ebenfalls diese Strings.
    - Beim Erstellen der Filterlisten `testMethodToRun` und `testClassesToRun` wurden jedoch die Präfixe (z.B. `JUNIT,`) nicht korrekt entfernt oder berücksichtigt.
    - Beim Vergleich wurde `pkg.Class#test` (aus Datei) gegen `JUNIT,pkg.Class#test` (aus Liste) geprüft, was fehlschlug.
- **Lösung:**
    - Bereinigung der Listen `testMethodToRun`/`testClassesToRun`: Präfixe werden nun vor dem Speichern in die Liste entfernt (`split(",")[1]`).
    - Bereinigung beim Vergleich: Auch beim Lesen aus der Datei werden Präfixe temporär ignoriert, um einen korrekten String-Vergleich zu ermöglichen.
    - Eingebautes Exception-Handling im Filter-Stream verhindert, dass ein Parsing-Fehler bei einer Zeile den gesamten Prozess abbricht.

## Debugging-Hilfen
- Es wurden umfangreiche `DEBUG`-Ausgaben hinzugefügt, um:
    - Den Inhalt von `allTest` und `outTest.txt` anzuzeigen.
    - Zu prüfen, ob erwartete fehlschlagende Tests (aus Properties) im Filter erhalten bleiben.
