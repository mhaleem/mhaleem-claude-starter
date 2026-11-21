---
description: Plan, implement, review in a loop until clean, then hand over for final human review
argument-hint: <task description>
---

Run the full delivery flow for: $ARGUMENTS

1. **Plan:** propose a short plan (approach, files, tests) and wait for my approval.
2. **Implement:** use the implementer agent to build it on a new branch with tests, then open a PR.
3. **Review loop** (maximum 3 rounds):
   a. Use the code-reviewer agent to review the PR and post findings.
   b. If the verdict is **Changes required** (any open high or medium finding), use the implementer agent to fix them and push.
   c. Go back to (a) for the next round. The reviewer must check every previous finding and the new changes.
   d. Stop the loop when the verdict is **Approve** or **Approve with minor changes**.
   e. If round 3 still ends with **Changes required**, stop and report the open findings to me. Do not continue on your own.
4. **Hand over:** summarize the PR link, number of review rounds, findings fixed per round, remaining low findings, and test and lint status for my final review. Do not merge.
