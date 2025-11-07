# Portainer SSH Key Configuration Guide

## Quick Start: Using Base64-Encoded SSH Keys

Portainer's environment variable editor doesn't handle multi-line values well, so we use base64 encoding for SSH keys.

### Step 1: Encode Your SSH Key

On your local machine (Mac/Linux):

```bash
# Encode your private key to base64 (single line)
cat ~/.ssh/id_rsa | base64 -w 0
```

On Mac (if `-w 0` doesn't work):
```bash
cat ~/.ssh/id_rsa | base64 | tr -d '\n'
```

This outputs a long single-line string like:
```
LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUJsd0FBQUFkemMyZ3RjbgpOaEFBQUFBd0VBQVFBQUFZRUF5TGtYdlo4bUg1RTdWcU5qS1B2Sjh4S0o5WXFIOHZMNW1OMnBRM3JUNnNVOXdYNHlaMQo...
```

### Step 2: Configure in Portainer

1. **Go to Stacks** → Your osTicket stack → **Editor**
2. **Find the migration service** environment section
3. **Add/uncomment these variables:**

```yaml
environment:
  DB_HOST: db
  DB_NAME: osticket
  DB_USER: osticket
  DB_PASS: osticketpass
  
  # Migration configuration
  OLD_SERVER: your-server.com
  SSH_USER: your-username
  SSH_PORT: "22"
  OSTICKET_PATH: /var/www/html/osticket
  AUTH_METHOD: "2"
  SSH_KEY_B64: LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0K...
```

4. **Update the stack**
5. **Restart the migration container**

### Step 3: Run Migration

1. Go to **Containers** → **osticket-migration** → **Console**
2. Run:
   ```bash
   pull-from-server.sh
   ```

The script will automatically:
- Decode the base64 key
- Use it for SSH authentication
- Pull your osTicket data

## Alternative: Using Portainer Secrets (Advanced)

For better security, you can use Portainer secrets:

1. **Create a secret:**
   - Portainer → Secrets → Add secret
   - Name: `osticket_ssh_key`
   - Content: Your base64-encoded key

2. **Reference in stack:**
   ```yaml
   secrets:
     - osticket_ssh_key
   
   services:
     migration:
       environment:
         SSH_KEY_B64_FILE: /run/secrets/osticket_ssh_key
   ```

## Troubleshooting

### "Failed to decode base64 SSH key"
- Make sure you copied the entire base64 string
- No line breaks or spaces in the middle
- Try encoding again with `tr -d '\n'` to remove newlines

### "Permission denied (publickey)"
- Verify the key is correct: `echo $SSH_KEY_B64 | base64 -d | head -1`
- Should show: `-----BEGIN OPENSSH PRIVATE KEY-----`
- Make sure the public key is in `~/.ssh/authorized_keys` on the old server

### "Connection refused"
- Check OLD_SERVER and SSH_PORT are correct
- Verify firewall allows SSH connections
- Test manually: `ssh -p 22 user@server`

## Security Notes

- ✅ Base64 is encoding, not encryption
- ✅ Still keep keys secure in Portainer
- ✅ Use read-only keys when possible
- ✅ Delete the SSH_KEY_B64 variable after migration
- ✅ Consider using Portainer secrets for production

## Example: Complete Configuration

```yaml
migration:
  image: universaldilettant/osticket-migration:latest
  container_name: osticket-migration
  restart: "no"
  volumes:
    - osticket_migration_data:/migration/data
    - osticket_migration_ssh:/root/.ssh
    - osticket_web:/web
  environment:
    DB_HOST: db
    DB_NAME: osticket
    DB_USER: osticket
    DB_PASS: osticketpass
    OLD_SERVER: support.example.com
    SSH_USER: admin
    SSH_PORT: "22"
    OSTICKET_PATH: /var/www/html/osticket
    AUTH_METHOD: "2"
    SSH_KEY_B64: LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUJsd0FBQUFkemMyZ3RjbgpOaEFBQUFBd0VBQVFBQUFZRUF5TGtYdlo4bUg1RTdWcU5qS1B2Sjh4S0o5WXFIOHZMNW1OMnBRM3JUNnNVOXdYNHlaMQo...
```

After migration is complete, remove the `SSH_KEY_B64` line and update the stack.
