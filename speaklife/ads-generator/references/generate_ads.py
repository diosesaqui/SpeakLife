#!/usr/bin/env python3
"""
SpeakLife Static Ad Generator — Nano Banana 2 via FAL API
=========================================================
Reads prompts.json from a brand folder, uploads product images to FAL storage,
and generates static ad images using fal-ai/nano-banana-2.

Usage:
    python generate_ads.py [brand_folder] [options]

Options:
    --resolution    0.5K | 1K | 2K | 4K  (default: 2K)
    --templates     comma-separated template numbers, e.g. 1,3,7  (default: all)

Examples:
    python generate_ads.py brands/speaklife
    python generate_ads.py brands/speaklife --resolution 1K
    python generate_ads.py brands/speaklife --templates 1,3,7,13
    python generate_ads.py brands/speaklife --templates T01,T03 --resolution 4K

Environment:
    FAL_KEY     Required. Your FAL API key.

Cost estimate: $0.12/image at 2K · 4 images/template · 20 templates = ~$9.60 full run
"""

import os
import sys
import json
import time
import argparse
import requests
import mimetypes
from pathlib import Path
from datetime import datetime



# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

FAL_BASE_URL = "https://queue.fal.run/fal-ai/nano-banana-2"
FAL_EDIT_URL = "https://queue.fal.run/fal-ai/nano-banana-2/edit"
FAL_REST_URL = "https://queue.fal.run"  # rest.fal.run doesn't resolve in all envs; queue.fal.run is the same backend
FAL_STATUS_POLL_INTERVAL = 3   # seconds between status polls
FAL_STATUS_TIMEOUT = 300       # seconds before giving up on a request
MAX_RETRIES = 3
IMAGES_PER_PROMPT = 4
COST_PER_IMAGE_2K = 0.12

RESOLUTION_MAP = {
    "0.5K": {"width": 512,  "height": 640},   # 4:5 base; square = 512x512
    "1K":   {"width": 800,  "height": 1000},
    "2K":   {"width": 1280, "height": 1600},
    "4K":   {"width": 2560, "height": 3200},
}

ASPECT_RATIO_MULTIPLIERS = {
    "4:5":  (4, 5),
    "1:1":  (1, 1),
    "9:16": (9, 16),
}


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def get_fal_key() -> str:
    key = os.environ.get("FAL_KEY", "").strip()
    if not key:
        print("ERROR: FAL_KEY environment variable is not set.")
        print("  export FAL_KEY=your_key_here")
        sys.exit(1)
    return key


def fal_headers(key: str) -> dict:
    return {
        "Authorization": f"Key {key}",
        "Content-Type": "application/json",
    }


def resolve_dimensions(resolution: str, aspect_ratio: str) -> dict:
    """Compute width/height for a given resolution key and aspect ratio."""
    base = RESOLUTION_MAP.get(resolution)
    if not base:
        raise ValueError(f"Unknown resolution: {resolution}. Choose from: {list(RESOLUTION_MAP.keys())}")

    # Base is defined for 4:5. Scale for actual aspect ratio.
    w_ratio, h_ratio = ASPECT_RATIO_MULTIPLIERS.get(aspect_ratio, (4, 5))
    base_long = max(base["width"], base["height"])

    if w_ratio >= h_ratio:
        # Landscape or square
        width = base_long
        height = int(base_long * h_ratio / w_ratio)
    else:
        # Portrait
        height = base_long
        width = int(base_long * w_ratio / h_ratio)

    return {"width": width, "height": height}


def slugify(text: str) -> str:
    """Convert template name to a safe directory name."""
    return "".join(c if c.isalnum() or c in "-_" else "-" for c in text.lower()).strip("-")


# ─────────────────────────────────────────────────────────────────────────────
# FAL Storage Upload
# ─────────────────────────────────────────────────────────────────────────────

def upload_file_to_fal(file_path: Path, key: str) -> str:
    """Upload a local file to FAL storage. Returns the FAL storage URL."""
    mime_type, _ = mimetypes.guess_type(str(file_path))
    if not mime_type:
        mime_type = "image/png"

    file_name = file_path.name
    file_size = file_path.stat().st_size

    # Step 1: Initiate upload — get signed URL
    initiate_url = f"{FAL_REST_URL}/storage/upload/initiate"
    initiate_payload = {
        "file_name": file_name,
        "content_type": mime_type,
    }
    resp = requests.post(
        initiate_url,
        headers=fal_headers(key),
        json=initiate_payload,
        timeout=30,
    )
    resp.raise_for_status()
    initiate_data = resp.json()

    upload_url = initiate_data.get("upload_url")
    fal_file_url = initiate_data.get("file_url") or initiate_data.get("url")

    if not upload_url:
        raise RuntimeError(f"FAL storage initiate did not return upload_url: {initiate_data}")

    # Step 2: PUT the file to the signed URL
    with open(file_path, "rb") as f:
        put_resp = requests.put(
            upload_url,
            data=f,
            headers={"Content-Type": mime_type, "Content-Length": str(file_size)},
            timeout=120,
        )
        put_resp.raise_for_status()

    # Some FAL responses return the final URL in the PUT response body
    if not fal_file_url:
        try:
            fal_file_url = put_resp.json().get("url") or put_resp.headers.get("Location")
        except Exception:
            fal_file_url = put_resp.headers.get("Location")

    if not fal_file_url:
        raise RuntimeError(f"Could not determine FAL file URL after upload for {file_name}")

    return fal_file_url


def upload_product_images(product_images_dir: Path, key: str) -> list[str]:
    """Scan product-images/ folder and upload all images to FAL storage.
    Returns empty list (with warning) if storage endpoint is unreachable."""
    supported_exts = {".png", ".jpg", ".jpeg", ".webp"}
    images = [
        f for f in product_images_dir.iterdir()
        if f.is_file() and f.suffix.lower() in supported_exts
    ]

    if not images:
        print(f"  ⚠️  No product images found in {product_images_dir}")
        return []

    print(f"  📤 Uploading {len(images)} product image(s) to FAL storage...")
    urls = []
    for img_path in sorted(images):
        print(f"     Uploading: {img_path.name} ...", end=" ", flush=True)
        try:
            url = upload_file_to_fal(img_path, key)
            urls.append(url)
            print(f"✓  {url[:60]}...")
        except Exception as e:
            print(f"FAILED: {e}")
            # If storage is unreachable, skip gracefully rather than aborting
            print(f"  ⚠️  FAL storage upload failed — product-image templates will fall back to text-to-image.")
            return []

    return urls


# ─────────────────────────────────────────────────────────────────────────────
# FAL Queue: Submit → Poll → Result
# ─────────────────────────────────────────────────────────────────────────────

def fal_submit(endpoint_url: str, payload: dict, key: str) -> tuple[str, str, str]:
    """Submit a job to FAL queue. Returns (request_id, status_url, response_url)."""
    resp = requests.post(
        endpoint_url,
        headers=fal_headers(key),
        json=payload,
        timeout=60,
    )
    resp.raise_for_status()
    data = resp.json()
    request_id = data.get("request_id")
    if not request_id:
        raise RuntimeError(f"FAL submit did not return request_id: {data}")
    # Use the URLs returned by FAL — they include the correct model path
    status_url = data.get("status_url") or f"{endpoint_url}/requests/{request_id}/status"
    response_url = data.get("response_url") or f"{endpoint_url}/requests/{request_id}"
    return request_id, status_url, response_url


def fal_poll_status(request_id: str, key: str, status_url: str) -> dict:
    """
    Poll FAL queue status until completed or failed.
    Returns the full status response dict when status == 'COMPLETED'.
    Raises RuntimeError on failure or timeout.
    """
    headers = fal_headers(key)
    deadline = time.time() + FAL_STATUS_TIMEOUT

    while time.time() < deadline:
        resp = requests.get(status_url, headers=headers, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        status = data.get("status", "").upper()

        if status == "COMPLETED":
            return data
        elif status in ("FAILED", "CANCELLED"):
            raise RuntimeError(f"FAL request {request_id} ended with status: {status}. Response: {data}")
        elif status in ("IN_QUEUE", "IN_PROGRESS", "PROCESSING"):
            position = data.get("queue_position", "?")
            print(f"       ⏳ Status: {status} (queue position: {position}) — waiting {FAL_STATUS_POLL_INTERVAL}s...")
            time.sleep(FAL_STATUS_POLL_INTERVAL)
        else:
            print(f"       ❓ Unknown status: {status} — waiting {FAL_STATUS_POLL_INTERVAL}s...")
            time.sleep(FAL_STATUS_POLL_INTERVAL)

    raise RuntimeError(f"FAL request {request_id} timed out after {FAL_STATUS_TIMEOUT}s")


def fal_get_result(request_id: str, key: str, response_url: str) -> dict:
    """Fetch the final result for a completed FAL request."""
    resp = requests.get(response_url, headers=fal_headers(key), timeout=30)
    resp.raise_for_status()
    return resp.json()


def extract_image_urls(result: dict) -> list[str]:
    """Extract image URLs from a FAL result response."""
    # FAL returns images in result.images[].url
    images = result.get("images") or result.get("result", {}).get("images", [])
    if not images:
        raise RuntimeError(f"No images in FAL result: {result}")
    return [img["url"] for img in images if img.get("url")]


# ─────────────────────────────────────────────────────────────────────────────
# Image Download
# ─────────────────────────────────────────────────────────────────────────────

def download_image(url: str, dest_path: Path) -> None:
    """Download an image from URL to dest_path."""
    resp = requests.get(url, timeout=120, stream=True)
    resp.raise_for_status()
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    with open(dest_path, "wb") as f:
        for chunk in resp.iter_content(chunk_size=8192):
            f.write(chunk)


# ─────────────────────────────────────────────────────────────────────────────
# Core Generation
# ─────────────────────────────────────────────────────────────────────────────

def generate_template(
    template: dict,
    output_dir: Path,
    product_image_urls: list[str],
    key: str,
    resolution: str,
    template_index: int,
    total_templates: int,
    num_images: int = IMAGES_PER_PROMPT,
) -> list[Path]:
    """
    Generate images for a single template. Returns list of saved image paths.
    Retries up to MAX_RETRIES on failure.
    """
    template_id = template.get("id", f"T{template_index:02d}")
    template_name = template.get("name", "unknown")
    prompt = template.get("prompt", "")
    aspect_ratio = template.get("aspect_ratio", "4:5")
    needs_product_images = template.get("needs_product_images", False)

    print(f"\n  Running {template_id}/{total_templates:02d}: {template_name}")
    print(f"  Aspect: {aspect_ratio} | Product images: {needs_product_images} | Resolution: {resolution}")

    dims = resolve_dimensions(resolution, aspect_ratio)
    template_slug = slugify(f"{template_id}-{template_name}")
    template_out_dir = output_dir / template_slug
    template_out_dir.mkdir(parents=True, exist_ok=True)

    # Save the prompt for reference
    prompt_file = template_out_dir / "prompt.txt"
    with open(prompt_file, "w", encoding="utf-8") as f:
        f.write(f"Template: {template_id} — {template_name}\n")
        f.write(f"Aspect ratio: {aspect_ratio}\n")
        f.write(f"Resolution: {resolution} ({dims['width']}x{dims['height']})\n")
        f.write(f"needs_product_images: {needs_product_images}\n")
        f.write(f"Generated: {datetime.now().isoformat()}\n")
        f.write("\n--- PROMPT ---\n\n")
        f.write(prompt)

    saved_paths = []
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            if needs_product_images and product_image_urls:
                # Edit endpoint — image + text
                payload = {
                    "prompt": prompt,
                    "image_urls": product_image_urls,
                    "num_images": num_images,
                    "image_size": dims,
                }
                endpoint = FAL_EDIT_URL
            else:
                # Text-to-image endpoint
                payload = {
                    "prompt": prompt,
                    "num_images": num_images,
                    "image_size": dims,
                }
                endpoint = FAL_BASE_URL

            print(f"  📤 Submitting to FAL ({endpoint.split('/')[-1]})...", end=" ", flush=True)
            request_id, status_url, response_url = fal_submit(endpoint, payload, key)
            print(f"request_id: {request_id}")

            print(f"  ⏳ Polling for completion...")
            status = fal_poll_status(request_id, key, status_url)

            # Fetch full result
            result = fal_get_result(request_id, key, response_url)
            image_urls = extract_image_urls(result)

            print(f"  ✅ Got {len(image_urls)} image(s). Downloading...")
            for i, img_url in enumerate(image_urls, 1):
                ext = "png" if "png" in img_url.lower() else "jpg"
                out_path = template_out_dir / f"image_{i:02d}.{ext}"
                download_image(img_url, out_path)
                saved_paths.append(out_path)
                print(f"     💾 Saved: {out_path.relative_to(output_dir.parent.parent)}")

            break  # Success — exit retry loop

        except Exception as e:
            print(f"\n  ⚠️  Attempt {attempt}/{MAX_RETRIES} failed: {e}")
            if attempt < MAX_RETRIES:
                wait = 5 * attempt
                print(f"  Retrying in {wait}s...")
                time.sleep(wait)
            else:
                print(f"  ❌ All {MAX_RETRIES} attempts failed for {template_id}. Skipping.")

    return saved_paths


# ─────────────────────────────────────────────────────────────────────────────
# Gallery Generation
# ─────────────────────────────────────────────────────────────────────────────

def generate_gallery(output_dir: Path, prompts: list[dict], all_saved: dict) -> Path:
    """Generate an index.html gallery of all generated images."""
    html_parts = [
        """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SpeakLife Ad Generator — Results</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #0D0D1A; color: #fff; font-family: 'Segoe UI', sans-serif; padding: 2rem; }
  h1 { color: #C9A84C; font-size: 1.8rem; margin-bottom: 0.5rem; }
  .meta { color: #9CA3AF; font-size: 0.9rem; margin-bottom: 2rem; }
  .template-block { margin-bottom: 3rem; border-top: 1px solid #C9A84C33; padding-top: 2rem; }
  .template-header { display: flex; align-items: baseline; gap: 1rem; margin-bottom: 0.75rem; }
  .template-id { color: #C9A84C; font-size: 1.1rem; font-weight: bold; }
  .template-name { color: #fff; font-size: 1rem; }
  .template-meta { color: #6B7280; font-size: 0.8rem; }
  details { margin-bottom: 1rem; }
  summary { cursor: pointer; color: #9CA3AF; font-size: 0.85rem; padding: 0.4rem 0; }
  summary:hover { color: #C9A84C; }
  pre { background: #111827; color: #D1D5DB; padding: 1rem; border-radius: 6px;
        font-size: 0.78rem; white-space: pre-wrap; word-break: break-word;
        max-height: 200px; overflow-y: auto; border: 1px solid #1F2937; }
  .image-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 1rem; }
  .image-item { background: #111827; border-radius: 8px; overflow: hidden;
                border: 1px solid #1F2937; }
  .image-item img { width: 100%; display: block; }
  .image-label { padding: 0.5rem; font-size: 0.75rem; color: #9CA3AF; text-align: center; }
  .no-images { color: #EF4444; font-size: 0.85rem; padding: 0.5rem 0; }
  .summary-bar { background: #111827; border-radius: 8px; padding: 1.5rem;
                  margin-bottom: 2rem; border: 1px solid #C9A84C44; }
  .summary-bar h2 { color: #C9A84C; margin-bottom: 0.75rem; font-size: 1rem; }
  .summary-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 0.75rem; }
  .stat-box { text-align: center; padding: 0.75rem; background: #0D0D1A; border-radius: 6px; }
  .stat-number { font-size: 1.5rem; font-weight: bold; color: #fff; }
  .stat-label { font-size: 0.75rem; color: #9CA3AF; margin-top: 0.25rem; }
</style>
</head>
<body>
<h1>🎯 SpeakLife Ad Generator — Results</h1>
"""
    ]

    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M UTC")
    total_images = sum(len(v) for v in all_saved.values())
    total_templates_run = len(all_saved)

    html_parts.append(f'<p class="meta">Generated: {generated_at}</p>\n')

    # Summary bar
    html_parts.append('<div class="summary-bar"><h2>Run Summary</h2><div class="summary-grid">')
    html_parts.append(f'<div class="stat-box"><div class="stat-number">{total_templates_run}</div><div class="stat-label">Templates Run</div></div>')
    html_parts.append(f'<div class="stat-box"><div class="stat-number">{total_images}</div><div class="stat-label">Images Generated</div></div>')
    cost_per_image = COST_PER_IMAGE_2K
    cost = total_images * cost_per_image
    html_parts.append(f'<div class="stat-box"><div class="stat-number">${cost:.2f}</div><div class="stat-label">Estimated Cost</div></div>')
    html_parts.append('</div></div>\n')

    for template in prompts:
        template_id = template.get("id", "")
        template_name = template.get("name", "")
        aspect_ratio = template.get("aspect_ratio", "")
        needs_pi = template.get("needs_product_images", False)
        prompt_text = template.get("prompt", "")
        saved_paths = all_saved.get(template_id, [])

        html_parts.append('<div class="template-block">')
        html_parts.append('<div class="template-header">')
        html_parts.append(f'<span class="template-id">{template_id}</span>')
        html_parts.append(f'<span class="template-name">{template_name}</span>')
        html_parts.append(f'<span class="template-meta">{aspect_ratio} · product_images: {needs_pi} · {len(saved_paths)} images</span>')
        html_parts.append('</div>')

        html_parts.append('<details><summary>View prompt</summary>')
        html_parts.append(f'<pre>{prompt_text[:2000]}{"..." if len(prompt_text) > 2000 else ""}</pre>')
        html_parts.append('</details>')

        if saved_paths:
            html_parts.append('<div class="image-grid">')
            for img_path in saved_paths:
                rel = str(img_path.relative_to(output_dir))
                html_parts.append(f'<div class="image-item"><img src="{rel}" loading="lazy" alt="{template_id}"><div class="image-label">{img_path.name}</div></div>')
            html_parts.append('</div>')
        else:
            html_parts.append('<p class="no-images">⚠️ No images generated for this template.</p>')

        html_parts.append('</div>\n')

    html_parts.append('</body></html>\n')

    gallery_path = output_dir / "index.html"
    with open(gallery_path, "w", encoding="utf-8") as f:
        f.writelines(html_parts)

    return gallery_path


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def parse_template_filter(templates_arg: str) -> set[str]:
    """Parse --templates argument into a set of normalized IDs like 'T01', 'T13'."""
    ids = set()
    for part in templates_arg.split(","):
        part = part.strip().upper()
        if not part:
            continue
        if part.startswith("T") and part[1:].isdigit():
            ids.add(f"T{int(part[1:]):02d}")
        elif part.isdigit():
            ids.add(f"T{int(part):02d}")
        else:
            ids.add(part)
    return ids


def main():
    parser = argparse.ArgumentParser(
        description="SpeakLife Ad Generator — Nano Banana 2 via FAL API",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "brand_folder",
        nargs="?",
        default=".",
        help="Path to brand folder containing prompts.json and product-images/. Default: current directory.",
    )
    parser.add_argument(
        "--resolution",
        choices=list(RESOLUTION_MAP.keys()),
        default="2K",
        help="Image resolution. Default: 2K",
    )
    parser.add_argument(
        "--templates",
        default=None,
        help="Comma-separated template numbers to run (e.g. '1,3,7' or 'T01,T13'). Default: all.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be run without calling the FAL API.",
    )
    parser.add_argument(
        "--num-images",
        type=int,
        default=4,
        help="Number of images per template. Default: 4",
    )

    args = parser.parse_args()

    brand_folder = Path(args.brand_folder).resolve()
    prompts_file = brand_folder / "prompts.json"
    product_images_dir = brand_folder / "product-images"
    output_dir = brand_folder / "outputs"

    print("=" * 60)
    print("  SpeakLife Ad Generator — Nano Banana 2 / FAL API")
    print("=" * 60)
    print(f"  Brand folder:  {brand_folder}")
    print(f"  Prompts file:  {prompts_file}")
    print(f"  Resolution:    {args.resolution}")
    print(f"  Templates:     {args.templates or 'all'}")
    print(f"  Dry run:       {args.dry_run}")
    print()

    # ── Validate inputs ──────────────────────────────────────────────────────

    if not prompts_file.exists():
        print(f"ERROR: prompts.json not found at {prompts_file}")
        print()
        print("  Run Phase 2 first to generate prompts.json:")
        print("  Ask the AI: 'Generate prompts.json for SpeakLife [pillar]'")
        sys.exit(1)

    with open(prompts_file, "r", encoding="utf-8") as f:
        prompts_data = json.load(f)

    # Support both list format and {prompts: [...]} format
    if isinstance(prompts_data, dict):
        prompts = prompts_data.get("prompts", [])
    elif isinstance(prompts_data, list):
        prompts = prompts_data
    else:
        print(f"ERROR: Unexpected prompts.json format. Expected list or {{prompts: [...]}}.")
        sys.exit(1)

    if not prompts:
        print("ERROR: No prompts found in prompts.json")
        sys.exit(1)

    # Apply template filter
    if args.templates:
        template_filter = parse_template_filter(args.templates)
        filtered = [t for t in prompts if t.get("id", "").upper() in template_filter]
        if not filtered:
            print(f"ERROR: No templates matched the filter: {args.templates}")
            print(f"Available IDs: {[t.get('id') for t in prompts]}")
            sys.exit(1)
        prompts = filtered
        print(f"  Filtered to {len(prompts)} template(s): {[t.get('id') for t in prompts]}")

    num_images = args.num_images
    total_images_expected = len(prompts) * num_images
    cost_2k = total_images_expected * COST_PER_IMAGE_2K
    dims = resolve_dimensions(args.resolution, "4:5")  # reference for cost
    scale_factor = (dims["width"] * dims["height"]) / (RESOLUTION_MAP["2K"]["width"] * RESOLUTION_MAP["2K"]["height"])
    estimated_cost = cost_2k * scale_factor

    print(f"  Templates to run: {len(prompts)}")
    print(f"  Images per prompt: {num_images}")
    print(f"  Total images: {total_images_expected}")
    print(f"  Estimated cost: ${estimated_cost:.2f} (at {args.resolution})")
    print()

    if args.dry_run:
        print("DRY RUN — No API calls will be made. Templates to process:")
        for t in prompts:
            print(f"  {t.get('id')} — {t.get('name')} | {t.get('aspect_ratio')} | product_images: {t.get('needs_product_images')}")
        print("\nDry run complete.")
        return

    # ── Load FAL key ─────────────────────────────────────────────────────────
    key = get_fal_key()
    print(f"  ✓ FAL_KEY loaded ({key[:8]}...)")

    # ── Upload product images ────────────────────────────────────────────────
    product_image_urls = []
    has_templates_needing_images = any(t.get("needs_product_images") for t in prompts)

    if has_templates_needing_images:
        if product_images_dir.exists():
            product_image_urls = upload_product_images(product_images_dir, key)
        else:
            print(f"  ⚠️  product-images/ directory not found at {product_images_dir}")
            print(f"  Templates requiring product images will use text-to-image instead.")

    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"\n  Output directory: {output_dir}")

    # ── Run generation ───────────────────────────────────────────────────────
    start_time = time.time()
    all_saved: dict[str, list[Path]] = {}

    for i, template in enumerate(prompts, 1):
        template_id = template.get("id", f"T{i:02d}")
        saved = generate_template(
            template=template,
            output_dir=output_dir,
            product_image_urls=product_image_urls,
            key=key,
            resolution=args.resolution,
            template_index=i,
            total_templates=len(prompts),
            num_images=num_images,
        )
        all_saved[template_id] = saved

    elapsed = time.time() - start_time
    total_generated = sum(len(v) for v in all_saved.values())

    # ── Generate gallery ─────────────────────────────────────────────────────
    print(f"\n  📊 Generating gallery...")
    gallery_path = generate_gallery(output_dir, prompts, all_saved)
    print(f"  ✅ Gallery saved: {gallery_path}")

    # ── Final summary ────────────────────────────────────────────────────────
    print()
    print("=" * 60)
    print("  ✅ Generation Complete")
    print("=" * 60)
    print(f"  Templates run:      {len(prompts)}")
    print(f"  Images generated:   {total_generated}")
    print(f"  Elapsed time:       {elapsed:.1f}s")
    print(f"  Estimated cost:     ${total_generated * COST_PER_IMAGE_2K * scale_factor:.2f}")
    print(f"  Gallery:            {gallery_path}")
    print()

    failed_templates = [tid for tid, paths in all_saved.items() if not paths]
    if failed_templates:
        print(f"  ⚠️  Failed templates (0 images): {failed_templates}")
    print()


if __name__ == "__main__":
    main()
