FROM openjdk:8-jdk-alpine

# ----
# Setup Packages
RUN apk add --no-cache bash curl git grep tar python3 py3-lxml unzip wget

# ----
# Setup Maven
ARG MAVEN_VERSION=3.6.3
ENV USER_HOME_DIR="/root"
RUN mkdir -p /usr/share/maven && \
curl -fsSL http://apache.osuosl.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar -xzC /usr/share/maven --strip-components=1 && \
ln -s /usr/share/maven/bin/mvn /usr/bin/mvn
ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"
# speed up Maven JVM a bit
ENV MAVEN_OPTS="-XX:+TieredCompilation -XX:TieredStopAtLevel=1"

# ----
# Setup Uppdatera
ENV UPPD=$USER_HOME_DIR/uppdatera
RUN mkdir $UPPD
RUN cd $UPPD && { wget -O agent.jar https://surfdrive.surf.nl/files/index.php/s/x3vAxfAORrJfgFa/download ; cd -; }
RUN cd $UPPD && { wget -O agent-bootstrap.jar https://surfdrive.surf.nl/files/index.php/s/PS0W6akBfvWV3Gr/download ; cd -; }
ENV MINER=$UPPD/miner
RUN mkdir $MINER
RUN git clone https://github.com/jhejderup/bytecode-miner ${MINER}
RUN cd ${MINER} && mvn install

# ----
# Import script
COPY ./main.sh /
COPY ./inject_pom_profile.py /
ENTRYPOINT ["/main.sh"]





