# SpeakLife ad characters

Reusable AI characters for testing which face carries an ad. Each is saved in Higgsfield as a
trained Soul (best identity match, works with `soul_2` / `soul_cinematic`) and as an Element (works
with the other image and video models), with the master portrait and training photos backed up here.

| Character | Look | Soul ID | Element ID | Master image job | Folder |
|---|---|---|---|---|---|
| Sofia | Latina, golden bronze skin, long black hair | `dda4be43-fe1f-4482-b610-0925260ce57c` | `715e401f-55af-4bb6-b6ef-2a991f5a1e38` | `53c3e5a8-4d89-4bde-8768-00006af94781` | `latina-girl/` |
| Grace | White, blue eyes, long blonde hair, freckles | `2c8cc992-3181-440e-bb8d-49e926e41cf8` | `436f784c-765b-4a7f-9fd0-c83c7c1b1d0b` | `10ef258a-0dcc-4ace-9d2d-3ecda957b8d3` | `blonde-girl/` |
| Naomi | Deep brown skin, long straight black hair | `19564973-fad2-4d8a-a25a-96fc3cedbbaf` | `37822e0b-7d52-4e2d-a191-28c87d409d80` | `6b3fa90f-bd40-4797-b7cb-2f123f997055` | `brown-girl/` |
| Ruth (55) | White, salt-and-pepper hair, hazel eyes, freckles, age lines | `634e7854-907f-4cbe-8b40-c6e8a146ec63` | `3471d9d2-6c28-4448-9a94-22da127ebc28` | `88d0da3e-4926-4c2a-8cbf-f9b90b00c12b` | `older-woman/` |

Sofia, Grace and Naomi share the same base styling (early 20s, candid iPhone look, small gold cross) so a test
changes the face, not the production style. Ruth is the deliberate exception: an ordinary
55-year-old (cardigan, gray-streaked hair, real age lines) for the women 55–64 audience.

**How the FaceTime videos are made** (see `../videos/2026-10-25-sofia/facetime/` and the `speaklife-video-ads` skill): generate a clean
front-camera start frame with `gpt_image_2_5` + the master image job as `image_references` (no phone
in frame, no text), then `seedance_2_5`, `mode: omni_reference`, `generate_audio: true`, start frame +
master as references, with the exact script in the prompt. 720p is about 7 credits per second.
Burn captions with `../videos/tools/caption_v2.py` (word-by-word highlight, keyword colour, verse chips; see its docstring). `caption.py` is the older pill style.

These are AI characters: scripts stay in second person or retell someone else's story, never a
first-person claim of a real experience or result.
