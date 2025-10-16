# SSH Keys Directory

Place SSH private keys here if you want to use key-based authentication.

## Usage

1. Copy your SSH private key:
   ```bash
   cp ~/.ssh/id_rsa migration/ssh/
   chmod 600 migration/ssh/id_rsa
   ```

2. The key will be available in the container at `/root/.ssh/id_rsa`

3. When running `pull-from-server.sh`, choose option 3 (SSH key file)

## Security Note

⚠️ **Never commit SSH keys to version control!**

This directory is gitignored by default.
