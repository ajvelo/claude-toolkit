"""Gated-command check for the unattended /ship loop (SHIP_UNATTENDED=1).

Usage: python3 -I ship_guard.py "<bash command>"
Exits 1 and prints the reason when the command would commit, push, write to a PR,
issue, Jira or Sentry, or open a database shell. Exits 0 otherwise.
"""
import os
import re
import shlex
import sys

SEPARATORS = set(";&|()<>`")
PREFIXES = {"then", "do", "else", "elif", "if", "while", "until", "!", "{", "}", "time",
            "nohup", "sudo", "command", "exec", "env", "xargs", "builtin", "nice", "$"}
PREFIX_FLAGS_WITH_VALUE = {"-n", "-u", "-g", "-C", "-I", "-L", "-P", "--adjustment", "--user", "--unset", "--chdir"}
SHELLS = {"bash", "sh", "zsh", "dash"}
GIT_GLOBAL_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}
GIT_WRITES = {"commit", "push", "merge", "rebase", "add", "stage", "cherry-pick", "revert", "am"}
GH_SUBCOMMAND_WRITES = {
    "pr": {"create", "merge", "ready", "edit", "comment", "review", "close", "reopen"},
    "issue": {"create", "edit", "comment", "close", "reopen", "delete"},
    "release": {"create", "edit", "delete", "upload"},
    "label": {"create", "edit", "delete"},
}
API_WRITE_FLAGS = ("-f", "-F", "--field", "--raw-field", "--input", "-d", "--data")
JIRA_WRITES = {"comment", "transition"}
DB_SHELLS = {"mysql", "psql", "mongosh", "redis-cli"}
SENTRY_WRITES = {"resolve", "unresolve", "archive", "merge", "delete"}


def tokenize(line):
    lexer = shlex.shlex(line, posix=True, punctuation_chars=";&|()<>`")
    lexer.whitespace_split = True
    try:
        return list(lexer)
    except ValueError:
        return line.replace("$(", " ( ").split()


def segments(command):
    for line in command.splitlines():
        current = []
        for tok in tokenize(line):
            if tok and set(tok) <= SEPARATORS:
                if current:
                    yield current
                current = []
            else:
                current.append(tok)
        if current:
            yield current


def strip_prefixes(tokens):
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", tok) or tok in PREFIXES:
            i += 1
            while i < len(tokens) and tokens[i].startswith("-"):
                i += 2 if tokens[i] in PREFIX_FLAGS_WITH_VALUE else 1
        elif tok == "timeout":
            i += 1
            while i < len(tokens) and (tokens[i].startswith("-") or re.fullmatch(r"[0-9.]+[smhd]?", tokens[i])):
                i += 2 if tokens[i] in ("-s", "-k", "--signal", "--kill-after") else 1
        else:
            break
    return tokens[i:]


def api_writes(args):
    for j, a in enumerate(args):
        if a in API_WRITE_FLAGS or any(a.startswith(f + "=") for f in API_WRITE_FLAGS if f.startswith("--")):
            return True
        if a in ("-X", "--method") and j + 1 < len(args) and args[j + 1].upper() != "GET":
            return True
        if a.startswith("--method=") and a.split("=", 1)[1].upper() != "GET":
            return True
        if a.startswith("-X") and len(a) > 2 and a[2:].upper() != "GET":
            return True
    return False


def check_segment(tokens):
    tokens = strip_prefixes(tokens)
    if not tokens:
        return None
    cmd, args = os.path.basename(tokens[0]), tokens[1:]
    if cmd in SHELLS and "-c" in args:
        idx = args.index("-c")
        return check(args[idx + 1]) if idx + 1 < len(args) else None
    if cmd == "eval":
        return check(" ".join(args))
    if cmd in DB_SHELLS:
        return cmd
    if cmd == "git":
        i = 0
        while i < len(args) and args[i].startswith("-"):
            i += 2 if args[i] in GIT_GLOBAL_WITH_VALUE else 1
        sub = args[i] if i < len(args) else ""
        rest = args[i + 1:]
        if sub in GIT_WRITES:
            return f"git {sub}"
        if sub == "tag" and rest and not any(r in ("-l", "--list", "-n", "--contains", "--points-at") or r.startswith("-n") for r in rest):
            return "git tag"
        return None
    if cmd == "gh" and args:
        if args[0] == "api":
            return "gh api write" if api_writes(args[1:]) else None
        if len(args) > 1 and args[1] in GH_SUBCOMMAND_WRITES.get(args[0], ()):
            return f"gh {args[0]} {args[1]}"
        return None
    if cmd in ("ship-jira", "ship-jira.sh") and args and args[0] in JIRA_WRITES:
        return f"ship-jira {args[0]}"
    if cmd == "sentry" and args:
        if args[0] == "api":
            return "sentry api write" if api_writes(args[1:]) else None
        if args[0] in ("issue", "issues") and len(args) > 1 and args[1] in SENTRY_WRITES:
            return f"sentry issue {args[1]}"
    return None


def check(command):
    for seg in segments(command):
        reason = check_segment(seg)
        if reason:
            return reason
    return None


if __name__ == "__main__":
    reason = check(sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read())
    if reason:
        print(reason)
        sys.exit(1)
