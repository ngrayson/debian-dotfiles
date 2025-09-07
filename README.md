# 🛠️ Debian Dotfiles

Personal configuration files managed with [chezmoi](https://www.chezmoi.io/).  
This repo contains my dotfiles for **Debian (forky/sid)** with Zsh, WezTerm, and other tools.

---

## ✨ Features
- **Shell**: Zsh + Oh My Zsh, with deferred plugin loading (fast startup 🚀)
- **Terminal**: WezTerm configuration
- **Git**: Opinionated `.gitconfig` + credential management
- **Package Configs**: npm, cargo, dotnet, and more
- **Desktop**: GDM/Sway tweaks (in progress)

---

## 📦 Installation

### 1. Install chezmoi
```bash
sh -c "$(curl -fsLS get.chezmoi.io)"
````

### 2. Initialize my dotfiles

```bash
chezmoi init https://github.com/ngrayson/debian-dotfiles
chezmoi apply
```

This will pull the repo and apply all configs.

---

## 🔄 Workflow

When making changes to configs:

```bash
# Edit files in-place
chezmoi edit ~/.zshrc

# See differences
chezmoi diff

# Apply them
chezmoi apply

# Commit + push to repo
chezpush.sh
```

💡 A helper script [`chezpush.sh`](./bin/chezpush.sh) automates committing and pushing updates.
Run it directly, or inside WezTerm with:

```bash
wezterm start -- ~/bin/chezpush.sh
```

---

## 🖥️ Usage on Other Machines

1. Install chezmoi.
2. Run `chezmoi init https://github.com/ngrayson/debian-dotfiles`.
3. Apply with `chezmoi apply`.

Configs will be synced automatically.

---

## 📋 To-Do / Backlog

* [ ] Migrate plugin management from Oh My Zsh → Zinit
* [ ] Polish GDM login screen (background, logo, default user experience)
* [ ] Document GNOME/Sway tweaks
* [ ] Add more scripts (automation, system bootstrap)

---

## ⚡ System Info

* **OS**: Debian forky/sid
* **Shell**: Zsh 5.9
* **Git**: 2.50.1
* **Terminal**: WezTerm

```
