# Naomi — SpeakLife ad character

Young woman, early 20s. Deep, rich brown skin, long sleek straight black hair, dark eyes, full lips,
full brows. Small gold cross necklace. Created 2026-10-25. Her skin was deliberately set deeper than
Sofia's (`../latina-girl/`) so the two read as clearly different people in tests.

## Higgsfield IDs (keep these)

| What | ID | Use with |
|---|---|---|
| Soul character "SpeakLife Naomi" | `19564973-fad2-4d8a-a25a-96fc3cedbbaf` | `generate_image` model `soul_2` or `soul_cinematic`, pass as `soul_id` |
| Element "SpeakLife Naomi" | `37822e0b-7d52-4e2d-a191-28c87d409d80` | put `<<<37822e0b-7d52-4e2d-a191-28c87d409d80>>>` in the prompt (Nano Banana, GPT Image 2, Seedream, Seedance, Cinema Studio, Kling 3.0 with a start image) |
| Master portrait image job | `6b3fa90f-bd40-4797-b7cb-2f123f997055` | pass in `medias` as `image_references` (`gpt_image_2_5`), or as the reference for video start frames |

## Files here

- `naomi-master.png` — the master portrait (round 2, option 1 of 4)
- `master-options/` — round 1 (lighter skin, too close to Sofia, not used)
- `master-options-v2/` — round 2, the deeper complexion she was picked from
- `training/` — the 9 photos the Soul was trained on (master + 8 angles)

To keep her consistent, always start from the Soul or the master portrait, never a text-only prompt.
