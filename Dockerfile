FROM bellsoft/alpaquita-linux-gcc:12.2-glibc as builder
LABEL org.opencontainers.image.source="https://github.com/Nikki18977/0303_tomcat"

ARG GPG_KEY_URL='https://github.com/slurmorg/build-containers-trusted/raw/main/key.gpg'
ARG ROOTFS_URL='https://github.com/slurmorg/build-containers-trusted/raw/main/rootfs.tar.gz'
ARG MAVEN_URL='https://github.com/slurmorg/build-containers-trusted/raw/main/apache-maven-3.9.1-bin.tar.gz'
ARG TOMCAT_URL='https://github.com/slurmorg/build-containers-trusted/raw/main/apache-tomcat-10.1.7.tar.gz'

ARG FINGERPRINT="70092656FB28DBB76C3BB42E89619023B6601234"
ENV FINGERPRINT=${FINGERPRINT}

RUN touch url.txt &&\
    echo -e "$GPG_KEY_URL" >> url.txt &&\
    echo -e "$ROOTFS_URL \n$ROOTFS_URL.sha512 \n$ROOTFS_URL.sha512.asc"  >> url.txt &&\
    echo -e "$MAVEN_URL \n$MAVEN_URL.sha512 \n$MAVEN_URL.sha512.asc" >> url.txt &&\
    echo -e "$TOMCAT_URL \n$TOMCAT_URL.sha512 \n$TOMCAT_URL.sha512.asc" >> url.txt &&\
    while IFS= read -r line; do wget $line -P /tmp; done < url.txt

RUN apk update && apk add gnupg

RUN echo $FINGERPRINT > fingerprint &&\
    gpg --dry-run --import --import-options import-show /tmp/key.gpg |  grep  -E "^\s{6}"  |  awk '{print $1}' | tee test_fingerprint &&\
    if [ $(cat fingerprint) == $(cat test_fingerprint) ]; \
    then gpg --import /tmp/key.gpg; \
    else echo "FINGERPRINT ARE NOT EQUAL" && breack; fi

RUN if gpg --list-keys | grep Slurm;\
    then \
    for i in $(ls /tmp | grep -v "512\|gpg"); \
    do \
    if [ $(sha512sum /tmp/$i | awk '{print$1}') = $(cat /tmp/$i.sha512 | awk '{print$1}') ]; \
    then echo "Good"; \
    else echo "SHA 512 SUM ARE NOT EQUAL" && breack; \
    fi; \
    done; \
    fi

RUN for i in $(ls /tmp | grep "asc"); \
    do \
    if echo -e "quit\n" | gpg  --verify /tmp/$i 2>&1 > /dev/null | grep Good > /dev/null; \
    then echo "Good"; \
    else echo "ASC ARE NOT GOOD" && breack; \
    fi; \
    done;

RUN mkdir /tmp/rootfs && tar -zxf /tmp/rootfs.tar.gz --directory /tmp/rootfs && \
    tar -zxf /tmp/apache-maven-3.9.1-bin.tar.gz --directory /tmp/ &&\
    tar -zxf /tmp/apache-tomcat-10.1.7.tar.gz --directory /tmp/


FROM scratch as second_buider

COPY --from=builder /tmp/rootfs/ /
COPY --from=builder /tmp/apache-maven-3.9.1/ /opt/bin/maven

ENV PATH=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64/bin:/opt/bin/maven/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8:en
ENV JAVA_HOME=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64
ENV MAVEN_HOME=/opt/bin/maven

WORKDIR /app
COPY . .
RUN mvn verify

FROM scratch as final_buider

ENV PATH=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64/bin:/opt/bin/tomcat/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8:en
ENV JAVA_HOME=/usr/lib/jvm/jdk-17.0.6-bellsoft-x86_64
ENV CATALINA_HOME=/opt/bin/tomcat

RUN rm -rf $CATALINA_HOME/webapps

COPY --from=builder /tmp/rootfs/ /
COPY --from=builder /tmp/apache-tomcat-10.1.7/ /opt/bin/tomcat
COPY --from=second_buider /app/target/api.war $CATALINA_HOME/webapps/

CMD catalina.sh run
EXPOSE 8080