# Codex Switcher

<p align="center">
  <strong>English</strong> | <a href="README.zh-CN.md"><strong>中文</strong></a>
</p>

Codex Switcher is a macOS menu bar app for managing multiple Codex / ChatGPT accounts on one Mac. It adds accounts through OpenAI OAuth, shows remaining hourly and weekly usage, refreshes usage, verifies expired accounts, and switches the active account by updating the standard Codex CLI auth file.

![Codex Switcher panel screenshot](docs/images/codex-switcher-panel.png)

## Features

- macOS menu bar app
- Add accounts through the OpenAI OAuth PKCE flow
- Click an account to switch the active Codex account
- Show remaining hourly and weekly usage
- Refresh one account or all accounts
- Verify an account again when refresh returns HTTP 401, updating its tokens
- Optional auto-refresh when opening the panel
- Optional auto-switching by hourly and weekly remaining quota thresholds
- Language setting for English and Simplified Chinese, defaulting to the system language when supported
- Account auth files are stored locally in Application Support
- The current Codex auth file is backed up before switching accounts

## Requirements

- macOS 13 or later
- Swift 6 toolchain
- Xcode or Apple Command Line Tools
- Network access to OpenAI login and ChatGPT usage endpoints

The Swift package currently targets macOS 13:

```swift
.macOS(.v13)
```

## Build and Run

Run from source:

```bash
swift run --disable-sandbox CodexSwitcher
```

Build only:

```bash
swift build --disable-sandbox
```

## Package a Local App

Generate a local `.app`:

```bash
./scripts/build-app.sh
```

Output path:

```text
dist/Codex Switcher.app
```

The packaging script generates the app icon from source:

```bash
swift scripts/generate-icon.swift
```

The script also applies an ad-hoc signature so macOS can recognize the app identity. If you use launch at login, keep the app in a stable location, for example:

```text
/Applications/Codex Switcher.app
```

Running the app from different paths, or deleting and regenerating it after enabling launch at login, can leave stale macOS login item entries. For public distribution, use a stable Developer ID signature and notarization flow.

Build artifacts, packaged apps, and generated icon files are ignored by Git and should not be committed.

## Data Storage

Accounts are stored locally at:

```text
~/Library/Application Support/Codex Switcher/accounts/
```

Auth backups created before account switching are stored at:

```text
~/Library/Application Support/Codex Switcher/backups/
```

The active Codex account still uses the standard Codex CLI auth file:

```text
~/.codex/auth.json
```

## OAuth Login and Verification

The app includes an OAuth PKCE login flow:

- Generate a PKCE verifier and challenge
- Start a temporary local callback listener
- Open the OpenAI authorization page
- Receive the authorization callback at `http://localhost:1455/auth/callback`
- Exchange the authorization code for tokens
- Save the account to the local account library

If usage refresh fails with HTTP 401, the account card shows a red **Verify** button. Clicking it runs the OAuth flow for that account again and replaces the stored tokens after the returned ChatGPT account id matches the card.

The `1455` port listener is started by Codex Switcher itself in `OAuthLoginService`. It only listens on `localhost` during add-account and verify-account flows, and closes after callback or cancellation.

This flow does not depend on VS Code and does not require installing or running a VS Code extension.

## Security

This app stores OAuth tokens locally so it can switch Codex accounts. Treat your macOS user account and Application Support directory as sensitive. A future production release should move token storage to macOS Keychain.

## License

No license has been selected yet.
