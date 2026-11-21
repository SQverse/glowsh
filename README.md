# ✨ Glowsh

**English** · [Bahasa Indonesia](README.id.md)

Make your Windows terminal glow. Beautify PowerShell & Command Prompt with **one command**, and get a terminal that actually helps you.

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

Choose your language (English or Bahasa Indonesia), pick a theme with the arrow keys (with live preview), press `Y`, then open **Windows Terminal**. Done! 🎉

## ✨ Features

### 🎨 Themes with live preview

```powershell
glowsh theme          # pick with the arrow keys, with live preview
glowsh theme neon     # apply directly
```

| Name | Vibe |
|---|---|
| `senja` | *"dusk"*: orange & purple sunset sky |
| `neon` | cyberpunk city lights at night |
| `laut` | *"sea"*: tropical turquoise & coral |
| `pagi` | *"morning"*: bright & fresh light theme |
| `dracula` · `catppuccin` · `tokyonight` | classics |

### 🖼️ A theme from your wallpaper

```powershell
glowsh wallpaper                 # uses your current desktop wallpaper
glowsh wallpaper .\photo.jpg     # or any image
```

Glowsh reads the dominant colors of the image and builds a matching terminal theme, so everyone gets a unique one.

### 🔗 Share themes with a short code

```powershell
glowsh share
# -> GLW-AQALChrg5v__LogA8P-4Tf__5F49_6L_Lohuap5OZW9u   (copied to clipboard)

glowsh import GLW-AQALChrg5v__LogA8P-4Tf__5F49_6L_Lohuap5OZW9u
```

### 🌗 Themes that follow the clock & the calendar

- `glowsh auto on`: **Pagi** in the morning, **Senja** in the late afternoon, **Neon** at night
- **Seasonal themes** turn on by themselves: red & white for Indonesian Independence Day (Aug 16–18), green & gold during Ramadan, and fireworks for New Year. Pick any theme by hand and Glowsh respects your choice.

### 🧠 Typo help

```
❯ gti status
  Unknown command 'gti'. Did you mean: git
  Run it? [Y/n]
```

Linux habits work too: type `touch`, `grep`, `which`, `nano`, `open`, and more, and Glowsh offers the Windows equivalent. Git typos like `git pusj` get git's own "did you mean `push`?" prompt.

### 🛡️ Guard against dangerous commands

```
❯ rm -rf node_modules
  [!] Deletes a folder and ALL of its contents. Skips the Recycle Bin and cannot be undone.
  Run anyway? [y/N]
```

It covers recursive deletes, `format`, `diskpart`, `git reset --hard`, `git push --force`, `git clean -f`, and shutdowns.

### 📖 Explain any command in plain language

```
❯ glowsh explain git push -u origin main
  git push
  Uploads your commits to the remote (e.g. GitHub).
  Options used:
    -u         set upstream: remember the remote/branch for next time
```

### 🔔 Know when long commands finish

When a command runs for 30 seconds or more, you get a Windows notification such as *"✅ Command finished: npm install (2m 14s)"*. Change the threshold with `glowsh notify 60`.

### 👋 A greeting dashboard

Every new terminal opens with a block-letter **GLOWSH logo** in your theme's gradient, plus panels that arrange themselves to fit the window:

- **System**: Windows version, RAM and disk bars, uptime, and today's command count and streak
- **Prayer times** for your city (Indonesian Ministry of Religious Affairs method: Fajr 20°, Isha 18°, 2-minute safety margin), with the next prayer highlighted and a countdown, calculated offline
- **Calendar**: this month, today highlighted, Sundays and fixed national holidays in red, the **Hijri date** (rolls over at Maghrib) and a **moon drawing** that follows today's phase
- **Quote of the day** in four categories: *fun* (dev humor), *life*, *faith*, *growth*
- **Recent folders** with their git branch; jump back with `glowsh go 1`

```powershell
glowsh lokasi Bandung        # your city for prayer times (or: glowsh lokasi -6.91 107.61 Home)
glowsh sholat                # today's prayer times
glowsh hijri +1              # shift the Hijri date if your local announcement differs
glowsh name Abid             # the name in your prompt & greeting
glowsh quote faith           # a random quote from one category
glowsh quote kinds fun,life  # which categories the daily quote uses
glowsh quote mode random     # a new quote every time a terminal opens (default: daily)
glowsh go                    # list recent folders, then: glowsh go 2 / glowsh go web
glowsh calendar off          # every panel can be turned off: logo, sysinfo, calendar, quote, recent
```

### 🩺 Glowsh Doctor

Icons showing up as boxes? Font didn't change? `glowsh doctor` checks everything: fonts, Windows Terminal, your profile, Execution Policy, Clink, and even per-profile settings that silently override your theme. Most issues **can be fixed automatically** by answering `Y`.

### 🎁 Glowsh Wrapped: your year in the terminal

```powershell
glowsh wrapped
```

Like Spotify Wrapped, but for your terminal: total commands, your top 5, your go-to subcommand, longest streak, most productive hour, success rate, typos Glowsh rescued, and your terminal persona (*Night Coder*, *Commit Royalty*, ...). Glowsh can also save a **1080×1920 image** for your IG story.

> 🔒 Glowsh only records the **command name** (for example `git push` or `curl`), never the arguments, so tokens or passwords typed in a command are never stored. The data stays on your machine in `~\.glowsh\stats.log`. Turn it off with `glowsh stats off`.

### 🩹 `glowsh why`: explain the last error

```
❯ npm start
  Error: listen EADDRINUSE: address already in use :::3000
❯ glowsh why
  Port already in use
  Port 3000 is taken by another program, usually a server still running in another tab.
  Try this:
    1. Find it: Get-NetTCPConnection -LocalPort 3000 | Select-Object OwningProcess
    2. Stop it: Stop-Process -Id <OwningProcess>
```

It knows about 20 common errors: ports in use, missing modules, git push rejected, merge conflicts, auth failures, blocked scripts, network and SSL problems, and more. For errors printed by other programs, copy the message (select + Ctrl+C) and run `glowsh why`, or paste it: `glowsh why "the error"`.

### 🖼️ Community theme gallery

```powershell
glowsh browse          # browse & install community themes, with live preview
glowsh submit          # share your current theme with the gallery
```

`glowsh submit` opens a pre-filled GitHub issue with your theme code. Approved themes are added to [`themes/community.json`](themes/community.json) and show up in everyone's `glowsh browse`.

### 🌏 Bilingual

The whole interface speaks **English** and **Bahasa Indonesia**. Switch anytime with `glowsh lang en` / `glowsh lang id`.

## 📋 All commands

| Command | What it does |
|---|---|
| `glowsh theme [name\|list]` | pick / apply / list themes |
| `glowsh wallpaper [file]` | build a theme from your wallpaper |
| `glowsh share [name]` | share a theme as a code |
| `glowsh import <code> [name]` | install a theme from a code |
| `glowsh explain <command>` | explain what a command does |
| `glowsh why ["error"]` | explain the last error and how to fix it |
| `glowsh wrapped [year]` | your year in the terminal (+ IG story image) |
| `glowsh browse` | community theme gallery |
| `glowsh submit [name]` | share a theme with the gallery |
| `glowsh doctor` | diagnose & fix display issues |
| `glowsh settings` | see every feature and whether it's on |
| `glowsh quote [category]` · `glowsh quote kinds <list>` | random quote / pick the daily quote categories |
| `glowsh go [number\|name]` | jump to a recently visited folder |
| `glowsh lokasi <city>` · `glowsh sholat` | set your location / show today's prayer times |
| `glowsh hijri [+1\|-1\|0]` | Hijri date and correction |
| `glowsh <feature> on\|off` | toggle `greet`, `logo`, `sysinfo`, `sholat`, `calendar`, `moon`, `quote`, `recent`, `auto`, `seasonal`, `notify`, `typo`, `guard`, `stats` |
| `glowsh notify <seconds>` · `glowsh notify test` | notification threshold / send a test notification |
| `glowsh name <name>` · `glowsh name reset` | set the name shown in your prompt & greeting (saved, edit anytime) |
| `glowsh lang en\|id` | switch language |
| `glowsh update` | update to the latest version |
| `glowsh uninstall` | restore your terminal to how it was |

## 🔧 What gets installed?

- **A beautiful prompt** powered by [Oh My Posh](https://ohmyposh.dev): icons, git branch, error status, command duration, clock
- **Nerd Font** (Meslo) so icons render correctly
- **File & folder icons** in `ls` / `dir` via [Terminal-Icons](https://github.com/devblackops/Terminal-Icons)
- **Inline suggestions** from your history ([PSReadLine](https://github.com/PowerShell/PSReadLine), updated if needed)
- **CMD gets the same prompt** + autocomplete via [Clink](https://github.com/chrisant996/clink)
- **Windows Terminal**: installed automatically if missing (official Microsoft release from GitHub), with color scheme, font, and translucency
- **The `glowsh` command**, available in both PowerShell and CMD

All Glowsh files live in `~\.glowsh`. Your original settings are backed up to `~\.glowsh\backup-original` before anything is changed.

> 💡 Nerd Font icons only render in **Windows Terminal**, not in the classic CMD/PowerShell console window.

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
- backs up your settings before changing anything (including your git `help.autocorrect` value),
- only downloads from official sources (Microsoft's GitHub, Oh My Posh, Clink, PowerShell Gallery).

## ✅ Requirements

- Windows 10 (build 19041+) or Windows 11
- Windows PowerShell 5.1 (built in) or PowerShell 7+

## 🛠️ Development

| File | Purpose |
|---|---|
| `install.ps1` | installation flow (thin, calls functions in `glowsh.ps1`) |
| `glowsh.ps1` | everything else: themes, picker, wallpaper, share, explain, doctor, settings, and the template for `~\.glowsh\shell.ps1` |
| `uninstall.ps1` | reverts everything (standalone, works via `iex`) |

`shell.ps1` is generated from `glowsh.ps1` at install time and is what your PowerShell profile loads. It handles the greeting, typo help, guard, notifications, and automatic theme switching.

Test locally without GitHub:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

Non-interactive options: `$env:GLOWSH_LANG = 'en'; $env:GLOWSH_THEME = 'neon'; $env:GLOWSH_YES = '1'`

## 🗺️ Roadmap

- [ ] More signature themes
- [ ] Custom schedule for `glowsh auto`
- [ ] Faster startup with prompt caching

## 🙏 Credits

Glowsh stands on the shoulders of [Oh My Posh](https://github.com/JanDeDobbeleer/oh-my-posh), [Nerd Fonts](https://www.nerdfonts.com), [Terminal-Icons](https://github.com/devblackops/Terminal-Icons), [PSReadLine](https://github.com/PowerShell/PSReadLine), [Clink](https://github.com/chrisant996/clink), and [Windows Terminal](https://github.com/microsoft/terminal). Classic color schemes: [Dracula](https://draculatheme.com), [Catppuccin](https://catppuccin.com), [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme).
