FROM opensuse/leap:15.6

RUN zypper -n --gpg-auto-import-keys ref && \
    zypper -n --gpg-auto-import-keys up && \
    zypper -n --gpg-auto-import-keys in sysvinit-tools openssh sshfs cifs-utils which bc tar gzip bzip2 curl jq cronie procmail mutt cyrus-sasl-plain postfix postgresql

COPY /VERSION /VERSION
COPY /scripts/*.sh /usr/local/bin/
RUN chmod u+x /usr/local/bin/*.sh

RUN /usr/local/bin/azcopy-install.sh

CMD [ "/usr/local/bin/start.sh" ]
