# UNSHAKABLE — the eleven 7-day plans

The lead-magnet PDFs delivered by the Storm Audit, one per route.

| | |
|---|---|
| Copy source | `docs/storm-audit-copy.md` (the only place to edit words) |
| Build spec | `docs/storm-audit-web-spec.md` §3 for the route mapping, §8 for filenames |
| Why it exists | `docs/lead-magnet-unshakable.md` |

## Rebuilding

```
pip install reportlab pillow pymupdf
python3 scripts/build_audit_pdfs.py      # renders all eleven
python3 scripts/check_audit_pdfs.py      # proofs them, non-zero exit on a defect
```

**Never hand-edit a PDF.** Edit the copy deck and re-render, or the words in the
reader stop matching the words the app and the ads use.

The renderer refuses to build if a declaration has drifted from
`declarationsv10.json`, if a set is not exactly seven lines, or if an em dash
reaches rendered copy. The checker then proofs the output for text collisions and
anything running past the footer. Both are cheap; run them every time.

## Specs

1080x1350 per page, ten pages, seven shared and three branched. Cover plates are
the app's own theme images. Type is Nunito (standing in for SF Pro Rounded, which
is not redistributable) with Lora Italic carrying scripture, both SIL OFL and
vendored in `scripts/fonts/`.
