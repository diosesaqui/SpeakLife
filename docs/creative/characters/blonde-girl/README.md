# Grace — SpeakLife ad character

Young white woman, early 20s. Fair skin with light freckles, bright blue eyes, long golden blonde
hair, full lips, soft brows. Small gold cross necklace. Created 2026-10-25.

## Higgsfield IDs (keep these)

| What | ID | Use with |
|---|---|---|
| Soul character "SpeakLife Grace" | `2c8cc992-3181-440e-bb8d-49e926e41cf8` | `generate_image` model `soul_2` or `soul_cinematic`, pass as `soul_id` |
| Element "SpeakLife Grace" | `436f784c-765b-4a7f-9fd0-c83c7c1b1d0b` | put `<<<436f784c-765b-4a7f-9fd0-c83c7c1b1d0b>>>` in the prompt (Nano Banana, GPT Image 2, Seedream, Seedance, Cinema Studio, Kling 3.0 with a start image) |
| Master portrait image job | `10ef258a-0dcc-4ace-9d2d-3ecda957b8d3` | pass in `medias` as `image_references` (`gpt_image_2_5`), or as the reference for video start frames |

## Files here

- `grace-master.png` — the master portrait (option 1 of 4)
- `master-options/` — all 4 first-round options
- `training/` — the 9 photos the Soul was trained on (master + 8 angles)

To keep her consistent, always start from the Soul or the master portrait, never a text-only prompt.
