# SSH access deployment

Archway can deploy one public key for SSH connections between managed
machines. The private key remains in the Bitwarden SSH agent and must never be
added to this repository.

## One-time setup

List the public keys exposed by Bitwarden:

```bash
ssh-add -L
```

Copy the complete line for the intended key into:

```text
dots/ssh/archway-access.pub
```

The file must contain one OpenSSH public key. Commit it to the repository;
public keys are not secrets.

Then update the encrypted host configuration:

```bash
just secrets-edit ssh_config.local
```

For each managed host, select the committed public key:

```sshconfig
Host arch-desktop
    HostName 192.168.1.20
    User your-user
    IdentitiesOnly yes
    IdentityFile ~/.ssh/archway-access.pub
```

Do not create a plaintext copy of `config.local` inside the repository. Saving
and closing the SOPS editor updates the encrypted
`secrets/ssh_config.local` file.

## Deployment behavior

When `just dotfiles` runs and `dots/ssh/archway-access.pub` exists, Archway:

1. validates the public key;
2. installs it at `~/.ssh/archway-access.pub` for identity selection; and
3. appends it to `~/.ssh/authorized_keys` only if the same key is not already
   present.

Existing authorized keys are preserved. If the committed public key is absent,
deployment prints a warning and continues.

Removing or rotating the committed key does not remove old entries from
`authorized_keys`; remove obsolete keys deliberately after confirming the new
key works.
