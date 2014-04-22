sqlDeploy
=========

a PowerShell script that deploys .sql files from TFS to a SQL database


Assumptions
=========

- Assumes `SQLCMD.exe` is in the path.
- Assumes that the target database exists.
- Assumes current user has permissions to perform actions contained in the SQL scripts (ALTER TABLE etc).
- Assumes the scripts do not use transactions (wraps each script into BEGIN TRAN / COMMIT TRAN).
- The strict mode assumes `GPG.exe` is in the path.

Usage
=========

    .\deployFromTFS.ps1 -path . -server [SERVER] -database [DATABASE] -strict -tfsUrl "http://tfs.company.com:8080/tfs" -tfsPath "$/CustomDevelopment/Database/Deltas/2.5.0" -pathToTFexe c:\tf.exe

Strict Mode
=========
The `-strict` mode will try to find and verified a _detached_ signature (.sig or .asc) for each .sql file, using Gpg4win, a GNU clone of PGP.
If signature not found, or the file has been modified since, or the signature key is unknown or untrusted, deployment will be aborted.

