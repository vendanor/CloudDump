VnCloudDump [![Build Status](https://github.com/vendanor/VnCloudDump/workflows/shellcheck/badge.svg)](https://github.com/vendanor/VnCloudDump/actions)
====


### Configuration:

Create config/config.json

Example configuration:

    {
      "settings": {
        "SMTPSERVER": "smtp.domain.dom",
        "SMTPPORT": "465",
        "SMTPUSER": "username",
        "SMTPPASS": "password",
        "MAILFROM": "user@domain.dom",
        "MAILTO": "user@domain.dom",
        "DEBUG": false
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
              "destination": "/azdump/azdump1"
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
                  "vendanorstaging2": {
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
              "backuppath": "/pgdump"
            }
          ]
        }
      ]
    }




### Build

    sudo docker-compose build --no-cache vnclouddump-ubuntu


### Start

    sudo docker-compose up -d vnclouddump-ubuntu


### Stop

    sudo docker-compose stop


### Clear

    sudo docker-compose down
