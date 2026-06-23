# Extraction Notes

This repository is the extracted standalone home for the former in-repository scaffold.

## Goals

- preserve the clean package boundary created during the 0-1 phase
- avoid making the legacy fork the long-term project root
- initialize a fresh standalone Trellis workspace here

## First-Time Setup

```bash
npm install
npm run build
npm test
trellis init
```

## Why `trellis init` happens here

The original incubation repository had its own `.trellis/` directory and task history. This standalone repository should start with clean workflow state instead of inheriting the old repository's metadata wholesale.
