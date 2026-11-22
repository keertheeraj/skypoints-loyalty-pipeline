# Snowflake key pair setup

Python (`ingest.py`) and dbt log in to Snowflake with a key pair instead of a password.
This avoids MFA prompts breaking scripts.

* **Private key** (`rsa_key.p8`): stays on your machine. Never share or commit it.
* **Public key** (`rsa_key.pub`): attached to your Snowflake user.

## 1. Generate the keys

Open **Git Bash** and run:

```bash
mkdir -p ~/.snowflake_keys
cd ~/.snowflake_keys

openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

The keys are saved in `C:\Users\<you>\.snowflake_keys\`, outside the repo.

## 2. Copy the public key as one line

```bash
grep -v "PUBLIC KEY" rsa_key.pub | tr -d '\n'
```

Copy the long line it prints (starts with `MIIBIjAN...`).

## 3. Attach the public key to your Snowflake user

In a Snowsight worksheet:

```sql
USE ROLE ACCOUNTADMIN;

ALTER USER <YOUR_USER> SET RSA_PUBLIC_KEY = '<paste the line here>';
```

## 4. Check it is attached

```sql
DESC USER <YOUR_USER>;
```

`RSA_PUBLIC_KEY_FP` should show a value starting with `SHA256:`.

## 5. Point the project to the private key

**`.env`** (used by `ingest.py`):

```
SNOWFLAKE_PRIVATE_KEY_PATH=C:/Users/<you>/.snowflake_keys/rsa_key.p8
```

**`~/.dbt/profiles.yml`** (used by dbt):

```yaml
private_key_path: C:\Users\<you>\.snowflake_keys\rsa_key.p8
```

No passphrase is needed, because the key was created with `-nocrypt`.

## 6. Test

```powershell
cd dbt
dbt debug
```

`Connection test: [OK connection ok]` means the key works.

## Troubleshooting

| Error | Fix |
|---|---|
| `JWT token is invalid` | Public key pasted with line breaks or the BEGIN and END lines. Repeat steps 2 and 3. |
| `No such file` | Wrong key path in `.env` or `profiles.yml`. |
| `Password was given but private key is not encrypted` | Remove `private_key_passphrase` from `profiles.yml`. |

## Security

* `*.p8` and `*.pem` are in `.gitignore`.
* Keep the keys folder outside the repo.
* If a private key is ever exposed, create a new pair and run `ALTER USER ... SET RSA_PUBLIC_KEY` again.