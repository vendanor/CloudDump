FROM fedora:36

RUN dnf update --assumeyes
RUN dnf upgrade --assumeyes
RUN dnf install --assumeyes which bc tar bzip2 jq cronie procmail mailx mutt postfix postfix-lmdb cyrus-sasl-plain postgresql

COPY /scripts/*.sh /usr/local/bin/
RUN chmod u+x /usr/local/bin/*.sh

RUN /usr/local/bin/azcopy-install.sh

CMD [ "/usr/local/bin/vnclouddump-start.sh" ]
