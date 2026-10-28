# Security policy

## Report privately

Use [GitHub private vulnerability reporting](https://github.com/macarronesc/invade.io/security/advisories/new).
Do not post keys, passwords, personal data, exploit details, or private logs in public issues or PRs.
Include the affected commit/version, impact, and the smallest safe reproduction. Only the latest
release and current development branch receive fixes; no response-time guarantee is offered.

## Credentials and trust boundaries

Contributors never need the Android upload keystore, its password, store credentials, or Sentry
administration tokens. Aptabase app keys and Sentry DSNs are public ingestion identifiers, not
administrative credentials. Never embed privileged credentials in the client, even through CI.

PRs and non-main builds run without production secrets. Only a trusted push to `main` can request
the `play-release` environment. Signing requires the owner's manual approval and runs on a fresh
GitHub-hosted runner, without checking out or executing the game. Missing credentials fail closed.

If a credential is exposed: revoke/rotate it first, stop affected workflows, remove affected
artifacts/logs, and investigate use. Deleting a file or rewriting Git history does not revoke a key.
Keep encrypted signing-key backups outside Git and review account MFA, recovery codes, OAuth/GitHub
Apps, and Play Console access regularly. Never upload real credentials to test a scanner.

## Current solo-maintainer limitation

`main` and `dev` require PRs and passing builds, prohibit force pushes/deletion, and include admins.
Independent PR approval is not mandatory while there is only one maintainer. CODEOWNERS requests
review but does not itself enforce approval. After appointing a trusted second maintainer, require
one approval, code-owner reviews, stale-approval dismissal, and approval of the latest push; then
disable self-review of deployments. No contributor is promised independent review before then.

## Before approving production signing

Review the exact commit, workflow/script/native-plugin changes, all required checks, artifact
contents, and version changes. Never approve signing for an unexpected commit or workflow.
The public `ANDROID_UPLOAD_CERT_SHA256` environment variable pins the expected upload certificate;
check it against Play Console independently. Google Play's app-signing certificate may differ.
