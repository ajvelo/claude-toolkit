#!/bin/bash
# Bash Triage Hook - Detects common failure patterns and injects diagnostic hints
# PostToolUse[Bash] hook

trap 'exit 0' ERR

INPUT=$(cat)

EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exitCode // 0' 2>/dev/null)

[ "$EXIT_CODE" = "0" ] && exit 0

STDOUT=$(echo "$INPUT" | jq -r '.tool_result.stdout // empty' 2>/dev/null)
STDERR=$(echo "$INPUT" | jq -r '.tool_result.stderr // empty' 2>/dev/null)
OUTPUT="$STDOUT $STDERR"

# JDK version mismatch (system default JDK 25; gateways/data-fusion/search need 21, wallet needs 25)
if echo "$OUTPUT" | grep -qiE 'unsupported class file|class file version 6[2-9]|has been compiled by a more recent version|UnsupportedClassVersionError|Could not target'; then
  echo '{"systemMessage": "HINT: JDK version mismatch. Check which JDK the project needs: wallet=25, gateways/data-fusion/search=21. Set: export JAVA_HOME=$(/usr/libexec/java_home -v VERSION)"}'
  exit 0
fi

# Gradle daemon issues
if echo "$OUTPUT" | grep -qiE 'could not connect to.*daemon|daemon.*stopped|OutOfMemoryError|GC overhead limit'; then
  echo '{"systemMessage": "HINT: Gradle daemon issue. Run: ./gradlew --stop then retry."}'
  exit 0
fi

# GPG signing failure
if echo "$OUTPUT" | grep -qiE 'gpg failed to sign|failed to sign the data|No secret key|gpg:.*error'; then
  echo '{"systemMessage": "HINT: GPG signing failed. Fix: gpgconf --kill gpg-agent && gpg-agent --daemon && export GPG_TTY=$(tty)"}'
  exit 0
fi

# Flutter pub get needed
if echo "$OUTPUT" | grep -qiE 'pub get has not been run|The pubspec.yaml file has changed|target of uri does.* exist|could not find package'; then
  echo '{"systemMessage": "HINT: Dependencies out of date. Run: fvm flutter pub get"}'
  exit 0
fi

# Dart code generation needed
if echo "$OUTPUT" | grep -qiE '\.g\.dart.*does.* exist|\.freezed\.dart.*does.* exist|part.*not found|build_runner'; then
  echo '{"systemMessage": "HINT: Code generation needed. Run: fvm dart run build_runner build --delete-conflicting-outputs"}'
  exit 0
fi

# Port already in use
if echo "$OUTPUT" | grep -qiE 'EADDRINUSE|address already in use|port.*already.*in use|bind.*failed'; then
  PORT=$(echo "$OUTPUT" | grep -oE ':[0-9]{4,5}' | head -1 | tr -d ':')
  echo "{\"systemMessage\": \"HINT: Port ${PORT:-unknown} in use. Find process: lsof -i :${PORT:-PORT}\"}"
  exit 0
fi

# Docker not running
if echo "$OUTPUT" | grep -qiE 'Cannot connect to the Docker daemon|docker.*not running|Is the docker daemon running'; then
  echo '{"systemMessage": "HINT: Docker daemon not running. Start Docker Desktop first."}'
  exit 0
fi

# FVM issues
if echo "$OUTPUT" | grep -qiE 'fvm:.*command not found|Could not find.*Flutter SDK|SDK version.*not installed'; then
  echo '{"systemMessage": "HINT: FVM/Flutter SDK issue. Run: fvm install && fvm use"}'
  exit 0
fi

# Kotlin compilation errors with detekt suggestion
if echo "$OUTPUT" | grep -qiE 'COMPILATION ERROR|Unresolved reference|Type mismatch'; then
  echo '{"systemMessage": "HINT: Kotlin compilation failed. Fix the errors, then run ./gradlew detekt before committing."}'
  exit 0
fi

# Node modules missing
if echo "$OUTPUT" | grep -qiE 'Cannot find module|ERR_MODULE_NOT_FOUND|MODULE_NOT_FOUND'; then
  echo '{"systemMessage": "HINT: Node modules missing. Run: pnpm install"}'
  exit 0
fi

# Go build errors
if echo "$OUTPUT" | grep -qiE 'undefined:.*|cannot find package|no required module provides'; then
  echo '{"systemMessage": "HINT: Go build/module error. Run: go mod tidy"}'
  exit 0
fi

# Playwright/E2E errors
if echo "$OUTPUT" | grep -qiE 'page\.goto.*timeout|waiting for selector|browser.*closed|Target closed'; then
  echo '{"systemMessage": "HINT: Playwright timeout/browser error. Check if the app is running. Try: pnpm playwright test --debug"}'
  exit 0
fi

# pnpm lockfile issues
if echo "$OUTPUT" | grep -qiE 'ERR_PNPM_OUTDATED_LOCKFILE|lockfile.*not up.to.date|pnpm-lock.*out of sync'; then
  echo '{"systemMessage": "HINT: Lockfile out of date. Run: pnpm install --no-frozen-lockfile"}'
  exit 0
fi

# ktlint errors
if echo "$OUTPUT" | grep -qiE 'ktlint.*error|Lint error|Code style violation'; then
  echo '{"systemMessage": "HINT: Kotlin lint errors. Run: ./gradlew ktlintFormat or ktlint -F"}'
  exit 0
fi

# Permission denied
if echo "$OUTPUT" | grep -qiE 'Permission denied|EACCES'; then
  echo '{"systemMessage": "HINT: Permission denied. Check file permissions or try: chmod +x <file>"}'
  exit 0
fi

# Connection refused (service not running)
if echo "$OUTPUT" | grep -qiE 'ECONNREFUSED|Connection refused|connect ECONNREFUSED'; then
  echo '{"systemMessage": "HINT: Connection refused. Is the target service running? Check with: docker ps or lsof -i :<port>"}'
  exit 0
fi

exit 0
