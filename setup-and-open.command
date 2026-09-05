#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -f "$HOME/Library/Application Support/SpeakLocal/venv/bin/python3" ]]; then chmod +x install.sh && ./install.sh; fi
open Package.swift
