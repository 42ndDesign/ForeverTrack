# Publishing ForeverTrack to CurseForge

## 1. Test in game (before anything public)
- [ ] Copy the repo folder to `World of Warcraft\_forever_\Interface\AddOns\ForeverTrack`
      (or wherever your Forever install's AddOns folder is). Only the TOC, Lua and `media/` are needed.
- [ ] Log in on a miner (ideally a Dwarf miner) and check:
  - [ ] Both trackings come on at login, `/ftrack status` says ON.
  - [ ] Die, release, run back: both come back on.
  - [ ] Turn one off from the minimap menu: it stays off and the reminder icon appears.
  - [ ] Click the icon: tracking turns on, icon disappears.
  - [ ] Enter combat: icon hides, no Lua errors (`/console scriptErrors 1`).
  - [ ] The icon shows on the AddOns list (TOC `IconTexture`).
- [ ] Take 2–3 screenshots (reminder icon, `/ftrack status` output, minimap with dots) for the CurseForge Images tab.

## 2. Create the CurseForge project
1. Sign in at https://authors.curseforge.com (create an author account if needed).
2. **Create Project** → Game: **World of Warcraft** → Class: **Addons**.
3. Fill in:
   - **Name:** ForeverTrack (search first to make sure it's not taken)
   - **Summary:** from `docs/CURSEFORGE_DESCRIPTION.md`
   - **Description:** paste the rest of `docs/CURSEFORGE_DESCRIPTION.md`
   - **Avatar:** `assets/avatar.png` (400×400) or `assets/avatar-1024.png`
   - **Categories:** Map & Minimap (primary), Professions
   - **License:** MIT
   - **Source:** https://github.com/42ndDesign/ForeverTrack (once public)
4. Submit. New projects go through moderation; the first file upload can wait until it's approved, or go in now.

## 3. Hook up automatic uploads
1. Note the **Project ID** in the project's sidebar ("About Project").
2. Add it to `ForeverTrack.toc`:
   ```
   ## X-Curse-Project-ID: 123456
   ```
3. Create an API token at https://legacy.curseforge.com/account/api-tokens (or Account → API Tokens).
4. In GitHub: repo **Settings → Secrets and variables → Actions → New repository secret**:
   name `CF_API_KEY`, value = the token.
5. Commit, then tag and push:
   ```
   git tag v1.0.0
   git push origin main --tags
   ```
6. Watch **Actions**. The packager builds `ForeverTrack-v1.0.0.zip`, creates a GitHub release and
   uploads to CurseForge with `CHANGELOG.md` as the release notes.
7. On CurseForge, check the file shows **Forever / 1.60.1** as its game version. If the packager
   couldn't map interface 16001, edit the file's game version on CurseForge by hand, or add
   `with: { args: -g 1.60.1 }` to the packager step in `.github/workflows/release.yml`.

## Manual upload instead (no Action)
Zip the folder so the zip contains `ForeverTrack/ForeverTrack.toc`, `ForeverTrack/ForeverTrack.lua`
and `ForeverTrack/media/icon.tga` (leave out `assets/`, `docs/`, `.github/`). Upload it under
**Files → Upload File**, choose game version **1.60.1 (Forever)**, release type **Release**.

## For each new version
1. Add a section to the top of `CHANGELOG.md`.
2. Commit, `git tag vX.Y.Z`, `git push origin main --tags`.
3. When Blizzard bumps the Forever client, update `## Interface:` in the TOC.
