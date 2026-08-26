---
name: D-ID embed discovery
description: Required script marker for the D-ID Agent Embed runtime.
---

The D-ID Agent Embed module discovers its configuration by querying for a script whose `data-name` is exactly `did-agent`. A custom marker can let the module load successfully but prevents it from initializing, leaving the target area blank.

**Why:** The runtime does not use its own executing script as configuration; it scans the document for this documented marker.

**How to apply:** Keep `data-name="did-agent"` on every D-ID embed script and ensure the script is connected to the document before it executes.