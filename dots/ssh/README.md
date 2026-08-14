# SSH key setup

Archway keeps a copy of each SSH public key so OpenSSH can ask the Bitwarden
agent for the matching private key. An optional FIDO2 key provides a
hardware-backed fallback.

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

## Client key selection

When `just dotfiles` runs and `dots/ssh/archway-access.pub` exists, Archway:

1. validates the public key;
2. installs it at `~/.ssh/archway-access.pub`; and
3. uses it to select the matching private key from the SSH agent for configured
   hosts.

If the committed public key is absent, deployment prints a warning and
continues. This configures the SSH client; it does not grant incoming access to
the local account.

## Authorizing incoming access

Authorize the key explicitly on each target account. From a machine that can
already authenticate to the target with a password or another key, run:

```bash
ssh-copy-id -i ~/.ssh/archway-access.pub your-user@target-host
```

Alternatively, open a local terminal on the target machine and prepare the
OpenSSH authorization file:

```bash
install -d -m 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
${EDITOR:-vi} ~/.ssh/authorized_keys
```

Paste the complete line from `dots/ssh/archway-access.pub`, save the file, and
confirm that key-based login works before disabling any existing login method.
Repeat with `dots/ssh/archway-fido-access.pub` when the FIDO2 fallback should
also be accepted by the target account.

Review `~/.ssh/authorized_keys` directly when rotating or revoking access.

## Optional FIDO2 fallback (TrustKey T110)

The TrustKey T110 can hold an OpenSSH FIDO2 key whose private material never
leaves the device. SSH requires the key to be plugged in and touched. Keep the
Bitwarden key authorized as the primary login method while setting up this
fallback.

On a current Arch machine, plug in the T110 and generate a resident key. Use
ECDSA-P256 (`ecdsa-sk`): it is the broadly supported FIDO algorithm. The touch
prompt is expected.

```bash
ssh-keygen -t ecdsa-sk -O resident \
    -C "archway-fido-fallback" \
    -f ~/.ssh/archway-fido-access
```

Start without `-O verify-required`, which needs optional FIDO PIN verification
support. Add it when generating a later key if every SSH signature should
require a PIN. The resident key can restore its local SSH handle on another
machine. If resident credentials are unsupported, retry without `-O resident`
and back up the local key-handle file; the T110 cannot restore that file by
itself.

Commit only the generated public key, under this exact name:

```bash
cp ~/.ssh/archway-fido-access.pub dots/ssh/archway-fido-access.pub
```

Do **not** commit `~/.ssh/archway-fido-access`. It is a local FIDO key handle,
not the device-private key, but retaining it locally avoids a recovery step.
When `just dotfiles` runs, Archway installs the public key for client-side
selection. Authorize the FIDO2 key on each intended target using the steps
above.

Add a separate fallback alias to the encrypted `ssh_config.local` for each
managed host (retain the existing Bitwarden-backed host entry):

```sshconfig
Host arch-desktop-fido
    HostName 192.168.1.20
    User your-user
    IdentitiesOnly yes
    IdentityAgent none
    IdentityFile ~/.ssh/archway-fido-access
```

Use `ssh arch-desktop-fido` when Bitwarden is unavailable. `IdentityAgent none`
prevents the unavailable Bitwarden socket from being used; the FIDO key is
contacted directly by OpenSSH. To restore the identity handle on a new machine,
create the `.ssh` directory with mode `0700`, plug in the T110, run
`ssh-keygen -K`, and rename the recovered `id_ecdsa_sk*` files to
`archway-fido-access*` before using the configuration above. Keep a second,
registered FIDO key or another recovery method: losing the only T110 otherwise
removes this login path.
