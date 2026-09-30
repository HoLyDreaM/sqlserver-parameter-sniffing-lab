# Optional: wait until SQL Server accepts connections (run inside container or via docker exec).
# Usage (from host): docker exec sqlserver-parameter-sniffing-lab /bin/bash /lab-scripts/wait-healthy.sh

set -euo pipefail

PASSWORD="${MSSQL_SA_PASSWORD:?MSSQL_SA_PASSWORD is required}"
SQLCMD="${SQLCMD:-/opt/mssql-tools18/bin/sqlcmd}"
RETRIES="${RETRIES:-60}"
SLEEP_SECS="${SLEEP_SECS:-2}"

i=0
until "$SQLCMD" -S localhost -U sa -P "$PASSWORD" -C -Q "SELECT 1" >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge "$RETRIES" ]; then
    echo "SQL Server did not become ready within $((RETRIES * SLEEP_SECS))s" >&2
    exit 1
  fi
  echo "Waiting for SQL Server... ($i/$RETRIES)"
  sleep "$SLEEP_SECS"
done

echo "SQL Server is ready."
