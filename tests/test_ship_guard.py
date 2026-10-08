import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "hooks"))

from ship_guard import check  # noqa: E402


class BlocksGatedActions(unittest.TestCase):
    def test_git_writes(self):
        for cmd in ("git commit -m x", "git -C /repo push origin HEAD", "git add .", "git tag v1"):
            self.assertIsNotNone(check(cmd), cmd)

    def test_gh_writes(self):
        for cmd in ("gh pr create --draft", "gh pr merge 3", "gh issue comment 4 -b hi",
                    "gh api -X POST repos/o/r/labels", "gh api repos/o/r/issues -f title=x"):
            self.assertIsNotNone(check(cmd), cmd)

    def test_jira_writes(self):
        self.assertEqual(check('ship-jira comment API-1 "hi"'), "ship-jira comment")
        self.assertEqual(check("ship-jira transition API-1 Done"), "ship-jira transition")

    def test_database_shells(self):
        for cmd in ("mysql -e 'select 1'", "psql $DSN"):
            self.assertIsNotNone(check(cmd), cmd)

    def test_hidden_inside_wrappers(self):
        for cmd in ("bash -c 'git push'", "eval git commit -m x", "cd /r && git push",
                    "FOO=1 nice -n 10 git push", "env -u GH_TOKEN git push", "sudo -u bob git push",
                    "xargs -I {} git push", "echo ok; gh pr create", "timeout 30 git push"):
            self.assertIsNotNone(check(cmd), cmd)

    def test_multiline_command(self):
        self.assertIsNotNone(check("ls\ngit push"))


class AllowsReads(unittest.TestCase):
    def test_reads_pass(self):
        for cmd in ("git status", "git log --oneline", "git tag -l", "gh pr view 3 --json state",
                    "gh pr checks 3", "gh api repos/o/r/pulls", "gh api -X GET repos/o/r",
                    "ship-jira search 'labels = claude-ready'", "ship-jira view API-1",
                    "ship-state list", "pnpm test"):
            self.assertIsNone(check(cmd), cmd)


if __name__ == "__main__":
    unittest.main()
