FROM openjdk:8-jdk-alpine

# ----
# Setup Packages
RUN apk add --no-cache bash curl git grep tar python3 wget

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
RUN cd $UPPD && { wget -O uppdatera.jar https://surfdrive.surf.nl/files/index.php/s/CZyCmxpHg80ujuI/download  ; cd -; }

# ----
# Setup Python
RUN pip3 install PyGithub


# ----
# Import script
COPY ./main.sh /
COPY ./post_issue.py /
ENTRYPOINT ["/main.sh"]





