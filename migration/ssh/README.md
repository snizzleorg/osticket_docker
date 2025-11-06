# SSH Keys Directory

Place SSH private keys here for key-based authentication during migration.

> **Note:** This is primarily for local development. When using Portainer, SSH keys are stored in the `osticket_migration_ssh` volume.

## Usage (Local Development)

1. Copy your SSH private key:
   ```bash
   cp ~/.ssh/id_rsa migration/ssh/
   chmod 600 migration/ssh/id_rsa
   ```

2. The key will be available in the container at `/root/.ssh/id_rsa`

3. When running `pull-from-server.sh`, choose option 3 (SSH key file)

## Usage (Portainer)

SSH keys are stored in the `osticket_migration_ssh` named volume. You can:
- Copy keys via the container console
- Use password authentication instead
- Use the interactive migration script

## Security Note

⚠️ **Never commit SSH keys to version control!**

This directory is gitignored by default.
