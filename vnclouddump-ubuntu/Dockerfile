FROM ubuntu:jammy

RUN echo "postfix postfix/main_mailer_type string 'Local only'" | debconf-set-selections

ENV DEBIAN_FRONTEND=noninteractive
RUN apt -y update
RUN apt -y upgrade
RUN apt -y install openssh-client sshfs cifs-utils bc curl tar bzip2 jq dnsutils mailutils mutt cron procmail postfix postfix-lmdb libsasl2-modules postgresql-client

RUN cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf

COPY /scripts/*.sh /usr/local/bin/
RUN chmod u+x /usr/local/bin/*.sh

RUN /usr/local/bin/azcopy-install.sh

CMD [ "/usr/local/bin/start.sh" ]
