FROM java:8u45-jdk

RUN echo "deb http://ftp.jp.debian.org/debian/ jessie main contrib non-free"                > /etc/apt/sources.list
RUN echo "deb-src http://ftp.jp.debian.org/debian/ jessie main contrib non-free"            >> /etc/apt/sources.list

RUN echo "deb http://ftp.jp.debian.org/debian/ jessie-backports main contrib non-free"      >> /etc/apt/sources.list
RUN echo "deb-src http://ftp.jp.debian.org/debian/ jessie-backports main contrib non-free"  >> /etc/apt/sources.list

RUN echo "deb http://security.debian.org/ jessie/updates main contrib non-free"             >> /etc/apt/sources.list
RUN echo "deb-src http://security.debian.org/ jessie/updates main contrib non-free"         >> /etc/apt/sources.list

# jessie-updates, previously known as 'volatile'
RUN echo "deb http://ftp.jp.debian.org/debian/ jessie-updates main contrib non-free"        >> /etc/apt/sources.list
RUN echo "deb-src http://ftp.jp.debian.org/debian/ jessie-updates main contrib non-free"    >> /etc/apt/sources.list

#Deb-Multimedia Repositoy
RUN echo "deb http://www.deb-multimedia.org jessie main non-free"                           >> /etc/apt/sources.list
RUN echo "deb-src http://www.deb-multimedia.org jessie main non-free"                       >> /etc/apt/sources.list


RUN apt-get update && apt-get install -y wget git curl zip openssh-server supervisor gcc libssl-dev make libreadline-dev sudo
RUN mkdir -p /var/run/sshd /var/log/supervisor
RUN chmod a+r+w /var/run/sshd /var/log/supervisor


RUN apt-get -y install libxml2 libxml2-dev libxslt-dev libsqlite3-dev g++ libpq-dev
RUN apt-get -y install vim
RUN apt-get -y install tree
RUN apt-get -y install silversearcher-ag
RUN apt-get -y install unzip libnet-ifconfig-wrapper-perl

RUN wget -O- https://toolbelt.heroku.com/install-ubuntu.sh | sh
ENV PATH $PATH:/usr/local/heroku/bin
RUN echo "Host heroku.com"                        >  ~/.ssh/config
RUN echo "    HostName heroku.com"                >> ~/.ssh/config
RUN echo "    IdentityFile ~/.ssh/id_rsa.pub" >> ~/.ssh/config
RUN echo "    User git"                           >> ~/.ssh/config

RUN echo "Asia/Tokyo" > /etc/timezone

ENV JENKINS_HOME /var/jenkins_home

# Jenkins is ran with user `jenkins`, uid = 1000
# If you bind mount a volume from host/vloume from a data container, 
# ensure you use same uid
RUN useradd -d "$JENKINS_HOME" -u 1000 -m -s /bin/bash jenkins

# Jenkins home directoy is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fL https://github.com/krallin/tini/releases/download/v0.5.0/tini-static -o /bin/tini && chmod +x /bin/tini

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

ENV JENKINS_VERSION 1.609.1
ENV JENKINS_SHA 698284ad950bd663c783e99bc8045ca1c9f92159

# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -fL http://mirrors.jenkins-ci.org/war-stable/$JENKINS_VERSION/jenkins.war -o /usr/share/jenkins/jenkins.war \
  && echo "$JENKINS_SHA /usr/share/jenkins/jenkins.war" | sha1sum -c -

ENV JENKINS_UC https://updates.jenkins-ci.org
RUN chown -R jenkins "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

# for sshd
EXPOSE 22

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

# Dockerrun.aws.jsonを利用して、elastic beanstalkにデプロイする時に、rootユーザーになり、コンテナを起動時にjenkins.shを実行すると、権限エラーが発生
# USER jenkins

COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]
#CMD /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf 
COPY services.sh /var/jenkins_home/services.sh
#ENTRYPOINT /var/jenkins_home/services.sh

# from a derived Dockerfile, can use `RUN plugin.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY plugins.txt /plugins.txt
RUN /usr/local/bin/plugins.sh /plugins.txt
