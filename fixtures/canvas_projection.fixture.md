# Canvas Projection v1

TuringOS canvas derives from Markdown. It is NOT a second source of truth.

## Overview

This fixture exercises all supported block-level node types.

### Detail

A paragraph under a level-3 heading.

> This is a block quote. Plain data — never markup.

- First item
- Second item
  - Nested item (depth 1)

---

```swift
// code fence — contents must NOT be split
let x = 1
let y = x + 2
```

A final paragraph after the code block.

## Security note

A paragraph containing an HTML-like tag: <script>alert(1)</script> and **bold** text.
These are plain data — the parser never interprets them as markup.
