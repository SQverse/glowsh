# ✨ Glowsh

**English** · [Bahasa Indonesia](README.id.md)

Make your Windows terminal glow. Beautify PowerShell & Command Prompt with **one command**.

No admin rights, no Microsoft Store, no winget, and everything can be reverted anytime.

## 🚀 Install

**PowerShell:**

```powershell
irm https://raw.githubusercontent.com/SQverse/glowsh/main/install.ps1 | iex
```

**Command Prompt (CMD):**

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/SQverse/glowsh/main/install.ps1 | iex"
```

Pick a theme with the arrow keys (with live preview), press `Y`, then open **Windows Terminal**. Done! 🎉

> 🌏 The installer and `glowsh` command currently speak **Bahasa Indonesia**. English UI is on the roadmap.

## 🎨 Themes

**Glowsh signature themes**, with a custom-designed prompt:

| Name | Vibe |
|---|---|
| `senja` | *"dusk"*: orange & purple sunset sky |
| `neon` | cyberpunk city lights at night |
| `laut` | *"sea"*: tropical turquoise & coral |

**Classic themes:** `dracula`, `catppuccin`, `tokyonight`

Switch themes anytime, no reinstall needed:

```powershell
glowsh theme          # pick with live preview
glowsh theme neon     # apply directly
```

## 🩺 Glowsh Doctor

Icons showing up as boxes? Font didn't change? Run:

```powershell
glowsh doctor
```

Doctor checks your fonts, Windows Terminal, PowerShell profile, Execution Policy, and Clink, and even catches per-profile settings that silently override your theme. Every issue comes with a plain-language explanation, and most of them **can be fixed automatically** by answering `Y`.

## 🔧 What gets installed?

- **A beautiful prompt** powered by [Oh My Posh](https://ohmyposh.dev): icons, git branch, error status, command duration, clock
- **Nerd Font** (Meslo) so icons render correctly
- **File & folder icons** in `ls` / `dir` via [Terminal-Icons](https://github.com/devblackops/Terminal-Icons)
- **Predictive autocomplete** from your command history (PSReadLine)
- **CMD gets the same treatment**: same prompt + autocomplete via [Clink](https://github.com/chrisant996/clink)
- **Windows Terminal**: installed automatically if missing (official Microsoft release from GitHub), with color scheme, font, and translucency
- **The `glowsh` command** for switching themes, running doctor, and uninstalling

All Glowsh files live in `~\.glowsh`. Your original settings are backed up to `~\.glowsh\backup-original` before anything is changed.

> 💡 Nerd Font icons only render in **Windows Terminal**, not in the classic CMD/PowerShell console window.

## 📋 Commands

| Command | What it does |
|---|---|
| `glowsh theme` | pick a theme with live preview |
| `glowsh theme <name>` | apply a theme directly |
| `glowsh theme list` | list all themes |
| `glowsh doctor` | diagnose & fix display issues |
| `glowsh uninstall` | restore your terminal to how it was |
| `glowsh version` | show Glowsh version |

## ↩️ Uninstall

```powershell
glowsh uninstall
```

Or without the `glowsh` command:

```powershell
irm https://raw.githubusercontent.com/SQverse/glowsh/main/uninstall.ps1 | iex
```

## 🔒 Security

Running a script from the internet always requires trust. That's why Glowsh:

- is plain, readable PowerShell with no obfuscation, so you can read it before running it ([install.ps1](install.ps1), [glowsh.ps1](glowsh.ps1)),
- shows a list of every change and asks for confirmation first,
- never needs admin rights,
- backs up your settings before changing anything,
- only downloads from official sources (Microsoft's GitHub, Oh My Posh, Clink, PowerShell Gallery).

## ✅ Requirements

- Windows 10 (build 19041+) or Windows 11
- Windows PowerShell 5.1 (built in) or PowerShell 7+

## 🛠️ Development

| File | Purpose |
|---|---|
| `install.ps1` | installation flow (thin, calls functions in `glowsh.ps1`) |
| `glowsh.ps1` | themes, theme application, theme picker, doctor, `glowsh` command |
| `uninstall.ps1` | reverts everything (standalone, works via `iex`) |

Test locally without GitHub:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Non-interactive options: `$env:GLOWSH_THEME = 'neon'; $env:GLOWSH_YES = '1'`

## 🗺️ Roadmap

- [ ] English UI (auto-detected from Windows language)
- [ ] `glowsh export` / `glowsh import` to share themes
- [ ] Faster startup with prompt caching
- [ ] More signature themes

## 🙏 Credits

Glowsh stands on the shoulders of [Oh My Posh](https://github.com/JanDeDobbeleer/oh-my-posh), [Nerd Fonts](https://www.nerdfonts.com), [Terminal-Icons](https://github.com/devblackops/Terminal-Icons), [Clink](https://github.com/chrisant996/clink), and [Windows Terminal](https://github.com/microsoft/terminal). Classic color schemes: [Dracula](https://draculatheme.com), [Catppuccin](https://catppuccin.com), [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme).
