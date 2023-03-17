# Vendanor CloudDump [![Publish Status](https://github.com/vendanor/CloudDump/workflows/publish/badge.svg)](https://github.com/vendanor/CloudDump/actions)

A tool that runs inside Docker and dumps data from azure data storage and PostgreSQL databases on a configurable schedule sending email reports for each job.

Do note that this tool is not a backup tool and has limited or no retention and archiving features. Its primary purpose is to dump the current state of the data. The reason why pg_dump is used instead of incremental backups for PostgreSQL databases is that this feature is not always available. Azure data storage dumps are differential.

It can also mount SMB shares, and use it as a dump destination.

## Running

```docker 
docker run \
  --name "clouddump"  \
  --mount type=bind,source=config.json,target=/config/config.json,readonly \
  --volume /clouddump/:/mnt/clouddump \
  -d --restart always \
  ghcr.io/vendanor/clouddump:latest
```

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
