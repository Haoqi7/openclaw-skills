#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SiliconFlow Image Generation & Editing Script
Model: Qwen/Qwen-Image-Edit-2509

Supports:
  - Text-to-Image (pure text prompt)
  - Image Editing (prompt + reference images via URL or local file path)
  - Style Transfer (prompt + reference images)
  - Multi-image input (up to 3 reference images)

API Docs: https://docs.siliconflow.cn/cn/api-reference/images/images-generations
"""

import argparse
import base64
import json
import mimetypes
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path
from urllib.parse import urlparse

API_URL = "https://api.siliconflow.cn/v1/images/generations"
MODEL = "Qwen/Qwen-Image-Edit-2509"

# Image URL expires in 1 hour, so we always download and save locally
IMAGE_URL_EXPIRY_NOTE = "Note: The image URL returned by the API is valid for only 1 hour."


def get_skill_root():
    """Get the skill root directory (parent of scripts/)."""
    return Path(__file__).resolve().parent.parent


def get_default_output_dir():
    """Get the default imageoutput directory under the skill folder."""
    return get_skill_root() / "imageoutput"


def ensure_output_dir(output_dir: str):
    """Ensure the output directory exists."""
    os.makedirs(output_dir, exist_ok=True)


def is_url(s: str) -> bool:
    """Check if a string is a valid URL."""
    if not s:
        return False
    try:
        result = urlparse(s)
        return result.scheme in ("http", "https") and result.netloc
    except Exception:
        return False


def is_local_file(s: str) -> bool:
    """Check if a string is a local file path."""
    if not s or is_url(s):
        return False
    return os.path.isfile(os.path.expanduser(s))


def file_to_base64(filepath: str) -> str:
    """Read a local file and convert to base64 data URI."""
    filepath = os.path.expanduser(filepath)
    if not os.path.isfile(filepath):
        raise FileNotFoundError(f"Local file not found: {filepath}")

    mime_type, _ = mimetypes.guess_type(filepath)
    if not mime_type:
        mime_type = "image/png"

    with open(filepath, "rb") as f:
        data = base64.b64encode(f.read()).decode("utf-8")

    return f"data:{mime_type};base64,{data}"


def process_image_input(image_value: str) -> str:
    """
    Process an image input: if it's a local file path, convert to base64.
    If it's a URL, return as-is.
    """
    if not image_value:
        return None

    image_value = image_value.strip()

    if is_local_file(image_value):
        print(f"[INFO] Reading local file: {image_value}", file=sys.stderr)
        return file_to_base64(image_value)
    elif is_url(image_value):
        # Validate URL is accessible
        try:
            req = urllib.request.Request(
                image_value, method="HEAD"
            )
            req.add_header("User-Agent", "SiliconFlow-ImageSkill/1.0")
            with urllib.request.urlopen(req, timeout=10) as resp:
                content_type = resp.headers.get("Content-Type", "")
                if not content_type.startswith("image/"):
                    print(
                        f"[WARN] URL does not point to an image (Content-Type: {content_type}), "
                        "proceeding anyway...",
                        file=sys.stderr,
                    )
        except urllib.error.HTTPError as e:
            if e.code == 403:
                # Some servers block HEAD requests, try GET but don't download full body
                print(
                    f"[WARN] HEAD request blocked (403), skipping URL validation for: {image_value}",
                    file=sys.stderr,
                )
            elif e.code == 404:
                raise ValueError(f"Image URL not found (404): {image_value}")
            else:
                raise ValueError(
                    f"Cannot access image URL (HTTP {e.code}): {image_value}"
                )
        except urllib.error.URLError as e:
            raise ValueError(f"Cannot access image URL: {image_value} - {e.reason}")
        return image_value
    else:
        raise FileNotFoundError(
            f"Image input is neither a valid URL nor an existing local file: {image_value}"
        )


def download_image(url: str, save_path: str) -> str:
    """Download an image from URL and save to local path. Returns the absolute path."""
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "SiliconFlow-ImageSkill/1.0")

    with urllib.request.urlopen(req, timeout=60) as response:
        data = response.read()

    with open(save_path, "wb") as f:
        f.write(data)

    return os.path.abspath(save_path)


def image_to_base64_from_file(filepath: str) -> str:
    """Read a saved image file and return raw base64 string."""
    with open(filepath, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def generate_image(
    api_key: str,
    prompt: str,
    negative_prompt: str = None,
    image: str = None,
    image2: str = None,
    image3: str = None,
    num_inference_steps: int = 20,
    cfg: float = 4.0,
    seed: int = None,
    output_path: str = None,
):
    """
    Generate or edit an image using SiliconFlow API.

    Args:
        api_key: SiliconFlow API Key
        prompt: Text description of the desired image
        negative_prompt: What to avoid in the image
        image: Reference image 1 (URL or local file path)
        image2: Reference image 2 (URL or local file path)
        image3: Reference image 3 (URL or local file path)
        num_inference_steps: Inference steps (1-100, default 20)
        cfg: CFG value (0.1-20, default 4.0)
        seed: Random seed for reproducibility
        output_path: Custom output file path (auto-generated if None)

    Returns:
        dict with keys: file_path, url, base64, seed, inference_time
    """
    # --- Validate inputs ---
    if not api_key or not api_key.strip():
        raise ValueError("API Key is required. Please provide your SiliconFlow API Key.")

    if not prompt or not prompt.strip():
        raise ValueError("Prompt is required. Please describe the image you want to generate.")

    # Process reference images
    processed_images = []
    for img in [image, image2, image3]:
        if img:
            processed_img = process_image_input(img)
            processed_images.append(processed_img)

    # --- Build request body ---
    body = {
        "model": MODEL,
        "prompt": prompt.strip(),
        "num_inference_steps": num_inference_steps,
        "cfg": cfg,
    }

    if negative_prompt and negative_prompt.strip():
        body["negative_prompt"] = negative_prompt.strip()

    if seed is not None:
        body["seed"] = int(seed)

    # Add processed images
    if len(processed_images) >= 1:
        body["image"] = processed_images[0]
    if len(processed_images) >= 2:
        body["image2"] = processed_images[1]
    if len(processed_images) >= 3:
        body["image3"] = processed_images[2]

    # --- Make API request ---
    print(f"[INFO] Calling SiliconFlow API with model: {MODEL}", file=sys.stderr)
    print(f"[INFO] Prompt: {prompt[:80]}{'...' if len(prompt) > 80 else ''}", file=sys.stderr)
    if processed_images:
        print(f"[INFO] Reference images: {len(processed_images)}", file=sys.stderr)
    print(f"[INFO] num_inference_steps={num_inference_steps}, cfg={cfg}", file=sys.stderr)

    req_data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        API_URL,
        data=req_data,
        headers={
            "Authorization": f"Bearer {api_key.strip()}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    start_time = time.time()

    try:
        with urllib.request.urlopen(req, timeout=300) as response:
            response_body = response.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        error_body = ""
        try:
            error_body = e.read().decode("utf-8")
        except Exception:
            pass

        if e.code == 401:
            raise PermissionError(
                "API Key is invalid or unauthorized. Please check your SiliconFlow API Key. "
                "You can get one at: https://cloud.siliconflow.cn"
            )
        elif e.code == 429:
            raise RuntimeError(
                "Rate limit exceeded. SiliconFlow allows 2 images per minute and 400 per day "
                "on the free tier. Please wait and try again."
            )
        elif e.code == 400:
            error_msg = ""
            try:
                error_json = json.loads(error_body)
                error_msg = error_json.get("message", error_json.get("error", error_body))
            except Exception:
                error_msg = error_body if error_body else "Bad request"
            raise ValueError(f"Request parameter error: {error_msg}")
        elif e.code == 404:
            raise RuntimeError(
                f"Model or endpoint not found (404). The model '{MODEL}' may be temporarily unavailable."
            )
        elif e.code == 503:
            raise RuntimeError(
                "SiliconFlow service is temporarily unavailable (503). Please try again later."
            )
        elif e.code == 504:
            raise RuntimeError(
                "Request timed out (504). The image generation took too long. "
                "Try reducing num_inference_steps or try again later."
            )
        else:
            raise RuntimeError(
                f"API request failed (HTTP {e.code}): {error_body or e.reason}"
            )
    except urllib.error.URLError as e:
        raise RuntimeError(
            f"Network error: Cannot connect to SiliconFlow API. {e.reason}"
        )

    inference_time = round(time.time() - start_time, 2)
    print(f"[INFO] Inference completed in {inference_time}s", file=sys.stderr)

    # --- Parse response ---
    try:
        result = json.loads(response_body)
    except json.JSONDecodeError:
        raise RuntimeError(f"Invalid JSON response from API: {response_body[:500]}")

    if "images" not in result or not result["images"]:
        raise RuntimeError(f"API returned no images. Response: {json.dumps(result, ensure_ascii=False)[:500]}")

    image_url = result["images"][0].get("url")
    if not image_url:
        raise RuntimeError("API returned image without URL.")

    used_seed = result.get("seed")
    timings = result.get("timings", {})
    api_inference_time = timings.get("inference")

    # --- Download and save image ---
    output_dir = get_default_output_dir()
    if output_path:
        output_path = os.path.expanduser(output_path)
        output_dir = os.path.dirname(output_path)
        if output_dir:
            ensure_output_dir(output_dir)
        save_path = output_path
    else:
        ensure_output_dir(str(output_dir))
        timestamp = int(time.time())
        save_path = str(output_dir / f"img_{timestamp}.png")

    print(f"[INFO] Downloading image to: {save_path}", file=sys.stderr)
    try:
        abs_save_path = download_image(image_url, save_path)
    except Exception as download_err:
        raise RuntimeError(
            f"Image generated successfully but failed to download: {download_err}. "
            f"You can manually download from: {image_url}"
        )

    # Read back as base64
    try:
        img_base64 = image_to_base64_from_file(abs_save_path)
    except Exception as read_err:
        raise RuntimeError(f"Image saved but failed to read back: {read_err}")

    print(f"[INFO] Image saved successfully: {abs_save_path}", file=sys.stderr)
    print(f"[INFO] File size: {os.path.getsize(abs_save_path) / 1024:.1f} KB", file=sys.stderr)
    print(f"[INFO] {IMAGE_URL_EXPIRY_NOTE}", file=sys.stderr)

    # --- Return result ---
    return_result = {
        "success": True,
        "file_path": abs_save_path,
        "url": image_url,
        "base64": img_base64,
        "seed": used_seed,
        "inference_time_seconds": inference_time,
        "api_inference_ms": api_inference_time,
        "model": MODEL,
    }

    return return_result


def main():
    parser = argparse.ArgumentParser(
        description="SiliconFlow Image Generation & Editing Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Text-to-Image:
  python generate.py --api-key YOUR_KEY --prompt "A beautiful sunset over the ocean"

  # Image Editing with local file:
  python generate.py --api-key YOUR_KEY --prompt "Add a rainbow" --image ./photo.jpg

  # Style Transfer with URL:
  python generate.py --api-key YOUR_KEY --prompt "Convert to anime style" --image "https://example.com/photo.jpg"

  # Custom output path:
  python generate.py --api-key YOUR_KEY --prompt "A cat" --output-path /tmp/my_cat.png

  # With seed for reproducibility:
  python generate.py --api-key YOUR_KEY --prompt "A castle" --seed 12345
        """,
    )

    parser.add_argument("--api-key", required=True, help="SiliconFlow API Key")
    parser.add_argument("--prompt", required=True, help="Image description prompt")
    parser.add_argument("--negative-prompt", default=None, help="Negative prompt (what to avoid)")
    parser.add_argument("--image", default=None, help="Reference image 1 (URL or local file path)")
    parser.add_argument("--image2", default=None, help="Reference image 2 (URL or local file path)")
    parser.add_argument("--image3", default=None, help="Reference image 3 (URL or local file path)")
    parser.add_argument(
        "--num-inference-steps",
        type=int,
        default=20,
        help="Number of inference steps (1-100, default: 20)",
    )
    parser.add_argument(
        "--cfg",
        type=float,
        default=4.0,
        help="CFG value (0.1-20, default: 4.0)",
    )
    parser.add_argument("--seed", type=int, default=None, help="Random seed for reproducibility (0-9999999999)")
    parser.add_argument("--output-path", default=None, help="Custom output file path")

    args = parser.parse_args()

    try:
        result = generate_image(
            api_key=args.api_key,
            prompt=args.prompt,
            negative_prompt=args.negative_prompt,
            image=args.image,
            image2=args.image2,
            image3=args.image3,
            num_inference_steps=args.num_inference_steps,
            cfg=args.cfg,
            seed=args.seed,
            output_path=args.output_path,
        )

        # Print result as JSON to stdout (only the key info, base64 excluded for cli)
        output = {
            "success": True,
            "file_path": result["file_path"],
            "url": result["url"],
            "seed": result["seed"],
            "inference_time_seconds": result["inference_time_seconds"],
            "api_inference_ms": result["api_inference_ms"],
            "model": result["model"],
        }
        print(json.dumps(output, indent=2, ensure_ascii=False))

    except (ValueError, PermissionError, RuntimeError, FileNotFoundError) as e:
        error_result = {
            "success": False,
            "error": str(e),
            "error_type": type(e).__name__,
        }
        print(json.dumps(error_result, indent=2, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        error_result = {
            "success": False,
            "error": f"Unexpected error: {str(e)}",
            "error_type": type(e).__name__,
        }
        print(json.dumps(error_result, indent=2, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
