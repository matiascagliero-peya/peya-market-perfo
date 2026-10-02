# How to Execute SQL Queries in this Terminal

To execute SQL queries stored in `.sql` files using the BigQuery CLI (`bq`) without running into PowerShell redirection operators or character encoding/BOM issues, use the following exact command template:

```powershell
cmd.exe --% /c bq query --use_legacy_sql=false --label datacloud:gemini-cli < path\to\your_query.sql
```

## Quick Examples

### Run `Testsql.sql`
```powershell
cmd.exe --% /c bq query --use_legacy_sql=false --label datacloud:gemini-cli < optimized_pipeline\Testsql.sql
```

### Run `1_profitability_orders.sql`
```powershell
cmd.exe --% /c bq query --use_legacy_sql=false --label datacloud:gemini-cli < optimized_pipeline\1_profitability_orders.sql
```

---

## Why this command works:
1. **`cmd.exe /c`**: Standard Windows Command Prompt supports the direct `<` file input redirection operator, reading files byte-by-byte cleanly.
2. **`--%` (Stop-Parsing Token)**: Tells PowerShell to stop parsing the rest of the line. This prevents PowerShell from complaining about the `<` operator being reserved, passing the redirection directly to `cmd.exe`.
3. **Encoding Protection**: Bypasses PowerShell's pipeline encoding serialization, which otherwise corrupts standard UTF-8 input with leading byte order marks (causing `Illegal input character "\303"` syntax errors in BigQuery).
4. **`--label datacloud:gemini-cli`**: Automatically applies the required resource attribution and tracking labels.
