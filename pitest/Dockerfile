FROM openjdk:8-jdk-alpine

# ----
# Setup Packages
RUN apk add --no-cache bash curl git grep tar python3 unzip wget

# ----
# Setup Maven
ARG MAVEN_VERSION=3.6.2
ENV USER_HOME_DIR="/root"
RUN mkdir -p /usr/share/maven && \
curl -fsSL http://apache.osuosl.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar -xzC /usr/share/maven --strip-components=1 && \
ln -s /usr/share/maven/bin/mvn /usr/bin/mvn
ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"
# speed up Maven JVM a bit
ENV MAVEN_OPTS="-XX:+TieredCompilation -XX:TieredStopAtLevel=1"

# ----
# Setup PITest
ENV PIT_RUNTIME=$USER_HOME_DIR/pit
RUN mkdir $PIT_RUNTIME
#Download all PIT Dependencies
RUN cd $PIT_RUNTIME && { wget https://github.com/jhejderup/pitest/releases/download/pitest-1.4.11-2-SNAPSHOT/pitest-1.4.11-SNAPSHOT.jar ; cd -; }
RUN cd $PIT_RUNTIME && { wget https://github.com/jhejderup/pitest/releases/download/pitest-1.4.11-2-SNAPSHOT/pitest-command-line-1.4.11-SNAPSHOT.jar; cd -; }
RUN cd $PIT_RUNTIME && { wget https://github.com/jhejderup/pitest/releases/download/pitest-1.4.11-2-SNAPSHOT/pitest-entry-1.4.11-SNAPSHOT.jar; cd -; }
#Download JUnit 4.6 & TestNG 6.11
ENV PIT_TEST_DEPS=$USER_HOME_DIR/deps
RUN mkdir $PIT_TEST_DEPS
RUN cd $PIT_TEST_DEPS && { wget https://repo1.maven.org/maven2/junit/junit/4.12/junit-4.12.jar ; cd -; }

# ----
# Import script
COPY ./pitest.sh /
COPY ./pit_args.py /
COPY ./pitlog_parsing/fix_pit_args.sh  /
COPY ./pitlog_parsing/parse_failed_tests.py  /
COPY ./pitlog_parsing/extract_failed_tests.py  /
COPY ./prune_deps.py /
ENTRYPOINT ["/pitest.sh"]





