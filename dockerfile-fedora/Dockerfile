FROM fedora:38

RUN dnf update --assumeyes
RUN dnf upgrade --assumeyes
RUN dnf install --assumeyes openssh-clients fuse-sshfs cifs-utils which bc tar bzip2 curl jq cronie procmail mailx mutt postfix postfix-lmdb cyrus-sasl-plain postgresql

COPY /VERSION /VERSION
COPY /scripts/*.sh /usr/local/bin/
RUN chmod u+x /usr/local/bin/*.sh

RUN /usr/local/bin/azcopy-install.sh

CMD [ "/usr/local/bin/start.sh" ]
