FROM opensuse/leap:15.4

RUN zypper -n --gpg-auto-import-keys ref
RUN zypper -n --gpg-auto-import-keys up
RUN zypper -n --gpg-auto-import-keys in sysvinit-tools which bc tar gzip bzip2 curl jq cronie procmail mutt cyrus-sasl-plain postfix postgresql

COPY /scripts/*.sh /usr/local/bin/
RUN chmod u+x /usr/local/bin/*.sh

RUN /usr/local/bin/azcopy-install.sh

CMD [ "/usr/local/bin/vnclouddump-start.sh" ]
