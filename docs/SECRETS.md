# Secrets

Committed secret documents are encrypted with SOPS and age. The age recipient
is public; the age private key is not.

## Fresh-machine onboarding

The normal installer installs Bitwarden first, then offers a hidden terminal
prompt:

1. open Bitwarden;
2. copy the age private key;
3. paste it at the prompt; and
4. press Enter.

The key is not echoed, placed in shell history, or passed as a command-line
argument. Archway validates it against an encrypted document before atomically
installing it at:

```text
~/.config/sops/age/keys.txt
```

The directory uses mode `0700`; the key and decrypted outputs use `0600`.

Skipping is safe:

```bash
just secrets
```

reopens the same onboarding flow later.

## Editing

```bash
just secrets-edit vdirsyncer.env
just secrets-edit ssh_config.local
```

Never create a plaintext copy inside the repository. Check `git diff` before
every push.

## Rotation

Generate or retrieve the replacement key outside the repository, update the
recipient in `.sops.yaml`, and re-encrypt each SOPS document. Retain the old key
until every committed file has been verified with the new key.

