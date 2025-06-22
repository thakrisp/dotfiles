#!/usr/bin/env bash
set -e

# --- HELPER FUNCTION ---
step() {
  echo ""
  echo "========================================"
  echo "  $1"
  echo "========================================"
}

step "🔧 SETTING UP CONFIGURATION"
DOTFILES_REPO="https://github.com/yourusername/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles" # Permanent location

DOTFILES_REPO="$DEFAULT_DOTFILES_REPO"
IS_TEST_RUN="false"
IS_CI_RUN="false"
ANSIBLE_EXTRA_ARGS=""

show_help() {
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo "Bootstrap a workstation by installing dependencies and running the main Ansible playbook."
  echo ""
  echo "Options:"
  echo "  --repo <URL>      Specify a custom dotfiles repository URL."
  echo "                    Default: $DEFAULT_DOTFILES_REPO"
  echo "  --test            Run Ansible in 'test' mode (check mode). No changes will be made."
  echo "  --CI              Run ansible in 'CI' mode for github actions"
  echo "  -h, --help        Show this help message."
}

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --repo) DOTFILES_REPO="$2" shift; shift ;;
    --test) IS_TEST_RUN="true"; shift ;;
    --CI) IS_CI_RUN="true" shift ;;
    -h|--help) show_help exit 0 ;;
    *) echo "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

step "Starting Workstation Bootstrap"
echo "Dotfiles Repository: $DOTFILES_REPO"
if [[ "$IS_TEST_RUN" == "true" ]]; then
  echo "Mode: 🧪 TEST RUN (check mode, no changes will be made)"
  # Add Ansible's check and diff flags for a dry run
  ANSIBLE_EXTRA_ARGS="--check --diff"
fi

# --- Install Homebrew ---
# Idempotent: checks if brew command exists before trying to install.
step "❗ Checking Homebrew Installation"
if ! command -v brew &> /dev/null; then
  echo "🍺 Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to this script's PATH to use it immediately
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
     eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
else
  echo "✅ Homebrew is already installed."
fi

# --- Install Git ---
# Ansible needs Git to clone repositories, so we ensure it's here.
step "❗ Checking Git Installation"
if ! command -v git &> /dev/null; then
    echo "📦 Git not found. Installing via Homebrew..."
    brew install git
else
    echo "✅ Git is already installed."
fi

# --- Install Ansible ---
step "❗ Checking Ansible Installation"
if ! command -v ansible &> /dev/null; then
  echo "🤖 Ansible not found. Installing via Homebrew..."
  brew install ansible
else
  echo "✅ Ansible is already installed."
fi

# --- Clone Dotfiles ---
step "❗ Cloning Dotfiles Repository"
if [ ! -d "$DOTFILES_DIR" ]; then
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  echo "✅ Dotfiles directory already exists. Pulling latest changes..."
  (cd "$DOTFILES_DIR" && git pull)
fi

# --- Run Main Ansible Playbook ---
step "🚀 Handing off to Ansible..."
cd "$DOTFILES_DIR"
# --ask-become-pass prompts for your sudo password, needed for tasks like changing the shell.
ansible-playbook ansible/playbook.yml \
  # --ask-become-pass \ #not needed as github uses passwordless sudo
  -e "dotfiles_repo=$DOTFILES_REPO" \
  -e "is_test_run=$IS_TEST_RUN" \
  -e "is_ci_run=$IS_CI_RUN" \
  $ANSIBLE_EXTRA_ARGS

step "🎉 Bootstrap complete! Ansible has finished."
echo "Please restart your terminal to apply all changes.
