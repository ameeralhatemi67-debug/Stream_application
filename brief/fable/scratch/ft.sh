#!/usr/bin/env bash
# Runs flutter test in the Lantern worktree and prints only failures and the summary.
# usage: ft.sh <flutter test args>   (FT_TAIL=<lines> to change the amount shown)
cd "C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app/.claude/worktrees/fable-lantern/project" || exit 1
flutter test --reporter expanded "$@" 2>&1 | tr '\r' '\n' \
  | grep -v -E "Easy Localization|^[[:space:]]*$|Realtime |failed: Bad state|Supabase auth listener|_refreshAcademic|loadVerified|available\)$|^Resolving|^Downloading|^Got dep|newer versions|pub outdated|not initialized|Supabase not init|unhandled element|AppFlags: refresh failed|_refreshTags failed|Once you have called dispose" \
  | awk '!/^[0-9]+:[0-9]+ \+[0-9]+/ || /\[E\]/ || /tests passed|tests failed/' \
  | sed -E 's#C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app/.claude/worktrees/fable-lantern/project/##g; s#file:///C:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/.claude/worktrees/fable-lantern/project/##g' \
  | tail -n "${FT_TAIL:-60}" | cut -c1-500
