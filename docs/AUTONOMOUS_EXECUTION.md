# Concerned Sprint autonomous execution

## Queue
- CS-OPS-001: tracking issue for the small release candidate.
- CS-001: inspect installed runtime, select compatible loader, identify and prove the stamina hook.
- CS-002: implement infinite sprint with enable/disable, local-player scope, fail-safe behavior and meaningful tests.
- CS-003: build/package, reversible install/uninstall, integration validation and owner smoke handoff.

This deliberately uses three leaves, not a multi-version roadmap. Dependencies are explicit in GitHub. Choose the lowest-numbered open unblocked CS leaf, fixing any in-scope critical defect first.

## Issue loop
1. Confirm canonical checkout, current branch/worktree, remote state and no second writer. Claim current issue with session ID and branch.
2. Refresh main without discarding user work; create one dedicated issue branch.
3. Implement the smallest complete change. Record discoveries and evidence. Keep proprietary dumps and private logs local and ignored.
4. Run the relevant available checks. Open a normal PR and request an independent read-only review, including runtime/lifecycle risks and issue acceptance criteria. Fix findings before merge.
5. Merge when the criteria pass; leave issue evidence, close it and continue immediately. Do not silently defer a required criterion to make an issue closable.
6. Finish all independent work before requesting an owner action. If a runtime step truly requires Eren, document the exact remaining action and keep the issue open as appropriate.

## Runtime discovery leads
Licensed game found at C:\\Program Files (x86)\\Steam\\steamapps\\common\\Demonologist, Steam app 1929610, installed build 25123233 at kickoff. Runtime lives under Shivers/Binaries/Win64. Recheck all details. The developer's 2.0 notes report an Unreal 5.6 upgrade; identify the local engine version rather than assuming older UE4SS 3.0.1 works.

Primary sources:
- https://store.steampowered.com/app/1929610/Demonologist/
- https://steamcommunity.com/games/1929610/announcements/detail/510729314639021597
- https://docs.ue4ss.com/
- https://github.com/UE4SS-RE/RE-UE4SS/releases

UE4SS Lua is a candidate, not a confirmed solution. Pin a compatible upstream version only with evidence. Prefer the smallest reliable runtime seam. Record exact class/property/function evidence, local-pawn identification, lifecycle/rebind behavior and config restoration semantics.

## Completion and stops
Claude prepares source, checks, reviewed PRs, candidate ZIP, install/uninstall instructions, exact compatibility evidence and a short owner smoke checklist. Eren owns final in-game acceptance and publication. Do not claim unsupported multiplayer modes, runtime passes or release readiness.

On quota or unavailable tools/dependencies, leave a durable checkpoint on the active issue containing branch/commit, accomplished work, exact blocker and next command/action. Never weaken permissions or validations, invent evidence, or restart/stop Teamster/Evergreen workers. No public release, marketplace upload or account/payment changes.
