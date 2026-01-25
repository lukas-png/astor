# Running Astor on Docker

Astor can be executed on Docker thanks to a Docker image created by [Thomas Durieux](https://durieux.me).
The image allows to execute Astor on Defects4J bugs.

## Setup

First, install Docker ([doc](https://docs.docker.com/)).

Then, execute the command:

```
docker pull tdurieux/astor

```



## Running Astor on Docker

### Basic command

The shortest command to run Astor on a particular defect from Defects4J is: 
```
docker run -it --rm tdurieux/astor --id Chart_5 

```

The parameter `--id` (or `-i`) indicates the buggy version from Defects4J. 
In this example, the command triggers Astor on defect `Chart 5`. 
Other values can be, for instance, `Math_70`.

The result is printed on the screen:

```
Patch stats:

Patch 1
VARIANT_ID=34
TIME=16
VALIDATION=|true|0|2184|[]|
GENERATION=17
FOLDER_SOLUTION_CODE=/script/jGenProg_Defects4J_Math_70/./output_astor/AstorMain-Math-70//bin//variant-34
--Patch Hunk #1
OPERATOR=ReplaceOp

LOCATION=org.apache.commons.math.analysis.solvers.BisectionSolver

PATH=/script/jGenProg_Defects4J_Math_70/output_astor/AstorMain-Math-70/src/default/org/apache/commons/math/analysis/solvers/BisectionSolver.java

MODIFIED_FILE_PATH=/script/jGenProg_Defects4J_Math_70/./output_astor/AstorMain-Math-70//src//variant-34_f/org/apache/commons/math/analysis/solvers/BisectionSolver.java

LINE=72

SUSPICIOUNESS=1

MP_RANKING=0

ORIGINAL_CODE=return solve(min, max)

BUGGY_CODE_TYPE=CtReturnImpl|CtBlockImpl

PATCH_HUNK_CODE=return solve(f, min, max)

PATCH_HUNK_TYPE=CtReturnImpl|CtBlockImpl

INGREDIENT_SCOPE=LOCAL

INGREDIENT_PARENT=return solve(f, min, max)

PATCH_DIFF_ORIG=--- org/apache/commons/math/analysis/solvers/BisectionSolver.java
+++ org/apache/commons/math/analysis/solvers/BisectionSolver.java
@@ -68,8 +68,8 @@
 
 
 	public double solve(final org.apache.commons.math.analysis.UnivariateRealFunction f, double min, double max, double initial) throws 
	org.apache.commons.math.FunctionEvaluationException, org.apache.commons.math.MaxIterationsExceededException {
-		return solve(min, max);
+   return solve(f, min, max);
 	}
 
```


### Arguments

#### Output

Astor writes on disk the solution, if any. 
It stores the patched classes, the diff corresponding to the patch and meta-data.
Please, see in [this document](https://github.com/SpoonLabs/astor/blob/master/docs/getting-starting.md) to get more information about the output.

Now, to store the output obtained from Docker in your disk, add the command `-v`. For instance, the command is now as follows:

```
docker run -it --rm -v <path_to_store_results>:/results tdurieux/astor -i chart-5 --scope package
```

Replace the `<path_to_store_results>` with the folder you want to store the results.
Note that the folder must be previously created and included in the list of Shared Files of Docker (go to `Preferences... -> File Sharing`).

#### Scope

The argument `--scope` allows to specify the type of ingredient space. Three possible values: `file`, `package` and `global`. See our [doc  about ingredients](https://github.com/SpoonLabs/astor/blob/master/docs/extension_points.md#implemented-components-6) for more information.

```
docker run -it --rm -v /tmp:results tdurieux/astor -i chart-5 --scope package
```

#### Parameters:

It is also possible to change any configuration parameter of Astor using the argument named `--parameters`.

```
docker run -it --rm -v /tmp/results:/results tdurieux/astor -i chart-5 --scope package --parameters stopfirst:true:maxGeneration:100
```

The value of `--parameters` has a following format: 
`<property_name_1>:<property_value_1>:<property_name_2>:<property_value_2>:...<property_name_n>:<property_value_n>`

For example, in the previous command `--parameters stopfirst:true:maxGeneration:100`, we have that `stopfirst`is the first parameter which value is `true`, and `maxGeneration` is the second parameter with value `100`.


The list with the most important arguments can be found [here](https://github.com/SpoonLabs/astor/blob/master/docs/arguments.md).


---

## Custom Dockerfile for Astor + Defects4J

If you want to build your own Docker image with Astor and Defects4J, you can use the following Dockerfile.

**Important Notes:**
- Ubuntu 22.04 does not have Java 7 available. Use Java 11 for Defects4J v2.x or Java 8 as a minimum.
- Some older Defects4J bugs require Java 8 for compilation.
- Astor requires Java 8 or higher to run.

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ---------- System deps ----------
RUN apt-get update && apt-get install -y \
    git subversion \
    perl cpanminus \
    gcc g++ make build-essential \
    unzip curl wget ca-certificates \
    ant maven \
    openjdk-8-jdk \
    openjdk-11-jdk \
    && rm -rf /var/lib/apt/lists/*

# Paths to both JDKs
ENV JAVA11_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ENV JAVA8_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# Default to Java 11 (for Defects4J v2.x)
ENV JAVA_HOME=${JAVA11_HOME}
ENV PATH=${JAVA_HOME}/bin:${PATH}

# Helper scripts to switch Java versions inside the container
RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'export JAVA_HOME="'"${JAVA11_HOME}"'"' \
    'export PATH="$JAVA_HOME/bin:${PATH//"$JAVA_HOME\/bin:"/}"' \
    'java -version' \
    > /usr/local/bin/use-java11 && chmod +x /usr/local/bin/use-java11

RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'export JAVA_HOME="'"${JAVA8_HOME}"'"' \
    'export PATH="$JAVA_HOME/bin:${PATH//"$JAVA_HOME\/bin:"/}"' \
    'java -version' \
    > /usr/local/bin/use-java8 && chmod +x /usr/local/bin/use-java8

# ---------- Defects4J Master ----------
WORKDIR /opt
RUN git clone https://github.com/rjust/defects4j.git
WORKDIR /opt/defects4j

# Install perl deps + init with Java 11
RUN cpanm --installdeps .
RUN ./init.sh

ENV D4J_HOME=/opt/defects4j
ENV PATH=/opt/defects4j/framework/bin:${PATH}

# Convenience runner: checkout + compile with Java 8
RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'BUG="${1:-Lang-1}"' \
    'WORK="${2:-/work}"' \
    'PROJECT="${BUG%%-*}"' \
    'BID="${BUG##*-}"' \
    '' \
    'export JAVA_HOME="'"${JAVA8_HOME}"'"' \
    'export PATH="$JAVA_HOME/bin:${PATH//"$JAVA_HOME\/bin:"/}"' \
    '' \
    'mkdir -p "$WORK"' \
    'echo "[*] Java version: $(java -version 2>&1 | head -n 1)"' \
    'echo "[*] Checkout ${PROJECT}-${BID} into ${WORK}/${BUG}"' \
    'defects4j checkout -p "$PROJECT" -v "${BID}b" -w "${WORK}/${BUG}"' \
    'cd "${WORK}/${BUG}"' \
    'echo "[*] Compile..."' \
    'defects4j compile' \
    'echo "[*] Done. Run tests with: defects4j test"' \
    > /usr/local/bin/d4j-checkout && chmod +x /usr/local/bin/d4j-checkout

# ---------- Astor (build & run with Java 8) ----------
WORKDIR /opt
RUN git clone https://github.com/SpoonLabs/astor.git
WORKDIR /opt/astor

# Build Astor with Java 8
RUN export JAVA_HOME="${JAVA8_HOME}" && export PATH="$JAVA_HOME/bin:${PATH}" && \
    mvn -q -DskipTests package

ENV ASTOR_HOME=/opt/astor

# Runner: jGenProg on a checked-out Defects4J bug
RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'BUG="${1:-Lang-1}"' \
    'WORK="${2:-/work}"' \
    '' \
    '# Switch to Java 8 for checkout and compilation' \
    'export JAVA_HOME="'"${JAVA8_HOME}"'"' \
    'export PATH="$JAVA_HOME/bin:${PATH//"$JAVA_HOME\/bin:"/}"' \
    'echo "[*] Java version: $(java -version 2>&1 | head -n 1)"' \
    '' \
    '# Ensure bug is checked out + compiled' \
    '/usr/local/bin/d4j-checkout "$BUG" "$WORK"' \
    '' \
    'cd "${WORK}/${BUG}"' \
    'SRC="$(defects4j export -p dir.src.classes)"' \
    'TST="$(defects4j export -p dir.src.tests)"' \
    'BIN="$(defects4j export -p dir.bin.classes)"' \
    'BINT="$(defects4j export -p dir.bin.tests)"' \
    'DEPS="$(defects4j export -p cp.test)"' \
    '' \
    '# failing test: either provided or first one from defects4j output' \
    'FAILING_TEST="${FAILING_TEST:-$(defects4j export -p tests.trigger | head -n 1 | xargs | sed "s/::/#/")}"' \
    'if [[ -z "$FAILING_TEST" ]]; then' \
    '  echo "[!] No failing test auto-detected. Set FAILING_TEST manually." >&2' \
    '  exit 2' \
    'fi' \
    '' \
    'ASTOR_JAR="$(ls -1 /opt/astor/target/*.jar | head -n 1)"' \
    '' \
    'MAXTIME="${ASTOR_MAXTIME:-60}"' \
    'echo "[*] Failing test: $FAILING_TEST"' \
    'echo "[*] Astor maxtime: ${MAXTIME}s"' \
    '' \
    'java -Xmx4g -cp "$ASTOR_JAR" fr.inria.main.evolution.AstorMain \' \
    '  -location . \' \
    '  -mode jgenprog \' \
    '  -scope package \' \
    '  -failing "$FAILING_TEST" \' \
    '  -dependencies "$DEPS" \' \
    '  -srcjavafolder "$SRC" \' \
    '  -srctestfolder "$TST" \' \
    '  -binjavafolder "$BIN" \' \
    '  -bintestfolder "$BINT" \' \
    '  -maxtime "$MAXTIME" \' \
    '  -stopfirst true' \
    '' \
    'echo "[*] Done. Look for patches in: ${WORK}/${BUG}/output_astor"' \
    > /usr/local/bin/astor-jgenprog && chmod +x /usr/local/bin/astor-jgenprog

WORKDIR /work
CMD ["bash"]
```

### Issues Fixed in This Dockerfile

The original Dockerfile had several issues:

| Problem | Fix |
|---------|-----|
| `JAVA7_HOME` pointed to Java 11 path with typo (`//usr/lib/...`) | Renamed to `JAVA11_HOME` with correct path |
| Ubuntu 22.04 has no Java 7 package | Using Java 8 and Java 11 instead |
| Inconsistent comments about Java versions | Corrected to match actual versions |
| Shell comments used `//` instead of `#` | Dockerfile comments use `#` |
| `-skipfaultlocalization` flag removed normal behavior | Removed to enable fault localization |

### Usage

Build the image:
```bash
docker build -t astor-d4j .
```

Run Astor on a Defects4J bug:
```bash
docker run -it --rm -v /tmp/results:/work astor-d4j astor-jgenprog Math-70
```



