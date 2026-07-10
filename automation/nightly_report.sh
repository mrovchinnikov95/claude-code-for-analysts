#!/usr/bin/env bash
# nightly_report.sh — ночной отчёт: агент собирает цифры, НО сначала самопроверка данных.
# Правило: автоматический отчёт без валидации = доставка мусора точно по расписанию.
set -euo pipefail

STAGE_DIR="/tmp/nightly_report"      # НЕ ~/Downloads и не Documents: macOS TCC не пустит launchd-процесс
LOG="$HOME/.local/log/nightly_report.log"  # логи в служебную папку, НЕ в защищённую
mkdir -p "$STAGE_DIR" "$(dirname "$LOG")"

exec >>"$LOG" 2>&1
echo "=== $(date '+%F %T') start ==="

# 1) Самопроверка данных ДО отчёта (свежесть витрин, контрольные суммы)
if ! psql "$DWH_URL" -qtA -f "$(dirname "$0")/validate_freshness.sql" | grep -q '^OK$'; then
  echo "validation FAILED — отчёт не собираем, шлём алерт"
  # curl -s -X POST "$ALERT_WEBHOOK" -d '{"text":"⚠️ Ночной отчёт: данные не прошли валидацию"}'
  exit 1
fi

# 2) Headless-агент собирает отчёт (промпт — в файле, чтобы версионировался)
claude -p "$(cat "$(dirname "$0")/report_prompt.md")" \
  --allowedTools "mcp__dwh__query" \
  > "$STAGE_DIR/report.md"

# 3) Доставка (подставь свой мессенджер: Telegram bot API / Slack webhook / ...)
# curl -s -X POST "$MESSENGER_WEBHOOK" --data-urlencode "text@$STAGE_DIR/report.md"

echo "=== $(date '+%F %T') done ==="
