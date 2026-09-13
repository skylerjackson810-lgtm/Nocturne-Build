# GitHub IPA build fix

The failed run had two independent configuration problems.

1. The repository was flattened when uploaded, but the generated Xcode project still resolved its application group beneath a `Nocturne/` directory. The corrected project resolves `App/`, `Game/`, `Gameplay/`, `Platform/`, `UI/`, `Resources/` and `Info.plist` directly from the repository root.
2. The old workflow deleted individual `path` lines from `project.pbxproj`. It left the corresponding `PBXBuildFile` entries active. Xcode resolved those damaged references as the `Nocturne` group and tried to copy that group to `Nocturne.app/Nocturne`, the same output path produced by the linker. That caused `Multiple commands produce .../Nocturne.app/Nocturne` and exit code 65.

The replacement workflow does not modify the project. It selects Xcode 16.4, builds an unsigned `iphoneos` application, verifies the executable exists, packages `Payload/Nocturne.app`, validates the ZIP and uploads `Nocturne-unsigned.ipa` for Sideloadly.

## Replace the GitHub repository using Windows

Extract `Nocturne-GitHub-Fixed.zip`. Open PowerShell inside the extracted `Nocturne-GitHub-Fixed` directory and run:

```powershell
git init
git branch -M main
git remote add origin https://github.com/skylerjackson810-lgtm/Nocturne-Buil.git
git add .
git commit -m "Fix Xcode project paths and unsigned IPA workflow"
git fetch origin main
git reset --soft origin/main
git add .
git commit -m "Fix Xcode project paths and unsigned IPA workflow"
git push origin main
```

If Git asks who you are before committing:

```powershell
git config user.name "Skyler Jackson"
git config user.email "YOUR_GITHUB_EMAIL"
```

If `git push` asks you to authenticate, complete the GitHub browser sign-in opened by Git Credential Manager. Do not paste your normal GitHub password into the terminal.

Then open the repository on GitHub:

1. Select **Actions**.
2. Select **Build unsigned iOS IPA**.
3. Select **Run workflow**, choose `main`, then select **Run workflow**.
4. Wait for all steps to turn green.
5. Open the completed run and download **Nocturne-unsigned-IPA** under Artifacts.
6. Extract the downloaded artifact once. Inside it is `Nocturne-unsigned.ipa` and `build.log`.
7. Drag `Nocturne-unsigned.ipa` into Sideloadly. Select the connected iPhone, enter the Apple Account used for sideloading and press **Start**.

Do not unzip `Nocturne-unsigned.ipa` itself.

## If the new workflow fails

Open the failed step and copy the first lines beginning with `error:` plus approximately 20 lines above and below them. The previous `Multiple commands produce` error should be gone. Any following error will be an actual Swift compiler or SDK compatibility issue and can be fixed from those lines.
