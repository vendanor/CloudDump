# Vendanor CloudDump [![Publish Status](https://github.com/vendanor/CloudDump/workflows/Publish/badge.svg)](https://github.com/vendanor/CloudDump/actions)

CloudDump is a containerized tool that by cron tab by schedule data dumps from Azure blob storages and PostgreSQL databases. Email reports are generated for each job and SMB shares can be mounted and used as destinations.

While CloudDump can be a useful component of a disaster recovery or backup regime (e.g. from cloud to on premises), it should not be used as a standalone backup tool, as it offers limited or no backup history, retention policies, and archival features. The tool is designed to create a current-state backup, which can then be fed into other tools for fully featured file-level backups.

## Running

```docker 
docker run \
  --name "clouddump"  \
  --mount type=bind,source=config.json,target=/config/config.json,readonly \
  --volume /clouddump/:/mnt/clouddump \
  -d --restart always \
  ghcr.io/vendanor/clouddump:latest
```

To give mount permissions, add capabilities DAC_READ_SEARCH and SYS_ADMIN. Example.:

```docker run --name "clouddump" --cap-add DAC_READ_SEARCH --cap-add SYS_ADMIN --mount type=bind,source=config.json,target=/config/config.json,readonly --volume /clouddump/:/mnt/clouddump -d --restart always ghcr.io/vendanor/clouddump:latest```


### config.json example

    {
      "settings": {
        "HOST": "host.domain.dom",
        "SMTPSERVER": "smtp.domain.dom",
        "SMTPPORT": "465",
        "SMTPUSER": "username",
        "SMTPPASS": "password",
        "MAILFROM": "user@domain.dom",
        "MAILTO": "user@domain.dom",
        "DEBUG": false,
        "mount": [
          {
            "path": "host:/share",
            "mountpoint": "/mnt/smb",
            "username": "user",
            "password": "pass",
            "privkey": ""
          }
        ]
      },
      "jobs": [
        {
          "script": "azdump.sh",
          "id": "azdump1",
          "crontab": "*/5 * * * *",
          "debug": false,
          "blobstorages": [
            {
              "source": "https://example.blob.core.windows.net/test?etc",
              "destination": "/azdump/azdump1",
              "delete_destination": true
            }
          ]
        },
        {
          "script": "pgdump.sh",
          "id": "pgdump1",
          "crontab": "* * * * *",
          "debug": false,
          "servers": [
            {
              "host": "example.azure.com",
              "port": 5432,
              "user": "username",
              "pass": "password",
              "databases": [
                {
                  "mydb": {
                    "tables_included": [],
                    "tables_excluded": [
                      "table1",
                      "table2"
                    ]
                  }
                }
              ],
              "databases_included": [],
              "databases_excluded": [
                "azure_sys",
                "azure_maintenance",
                "template0"
              ],
              "backuppath": "/pgdump",
              "filenamedate": true,
              "compress": true
            }
          ]
        }
      ]
    }
       
## License

This tool is released under the MIT License.
