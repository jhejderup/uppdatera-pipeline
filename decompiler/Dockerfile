FROM openjdk:7-jdk-alpine

# ----
# Setup Packages
RUN apk add --no-cache bash curl 

# ----
# Setup Procyon
ENV DECOMP=$USER_HOME_DIR/pit
RUN mkdir $DECOMP
RUN cd $DECOMP && { wget https://bitbucket.org/mstrobel/procyon/downloads/procyon-decompiler-0.5.36.jar; mv procyon-decompiler-*.jar procyon-decompiler.jar; cd -; }

# ----
# Import script
COPY ./run.sh /
ENTRYPOINT ["/run.sh"]





