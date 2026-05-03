#!/usr/bin/env python3
"""
Manage image stability and mirroring to Harbor.
Logic:
1. Parse compose file for images.
2. Part 1: Pull and tag as stable_build_v1_part_1.
3. Part 2: Retry failures and tag as stable_build_v1_part_2.
4. Final: Tag all successful as stable_build_v1.
5. Output metadata env file.
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path

HARBOR_URL = "demo.goharbor.io"
PROJECT_MAPPING = {
    "greenbone": "hq-sec-stack-greenbone",
    "ghcr.io": "hq-sec-stack-gh",
    "docker.io": "hq-sec-stack-dockerio",
    "dockerhub": "hq-sec-stack-dockerhub",
    "default": "hq-sec-stack-gh"
}

def run(cmd, check=True, capture=False):
    print(f"Executing: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=capture, text=True, check=False)
    if check and result.returncode != 0:
        print(f"Error: {result.stderr}")
        return result
    return result

def get_harbor_ref(image_raw):
    # Simplified mapping logic
    ref = image_raw.strip()
    tag = "latest"
    if ":" in ref:
        ref, tag = ref.rsplit(":", 1)
    
    parts = ref.split("/")
    if "ghcr.io" in parts[0]:
        project = PROJECT_MAPPING["ghcr.io"]
        path = "/".join(parts[1:])
    elif "greenbone" in ref:
        project = PROJECT_MAPPING["greenbone"]
        path = parts[-1]
    elif len(parts) > 1 and "." in parts[0]:
        # Other registries
        project = PROJECT_MAPPING["default"]
        path = "/".join(parts[1:])
    else:
        # Docker Hub
        project = PROJECT_MAPPING["dockerhub"]
        path = ref if "/" in ref else f"library/{ref}"
    
    # Sanitize path for Harbor (replace / with - if needed, or keep if Harbor supports nested)
    # Most Harbors support 1 level of nesting in projects.
    sanitized_path = path.replace("/", "-")
    return f"{HARBOR_URL}/{project}/{sanitized_path}", tag

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compose-file", default="security-stack.compose.yml")
    parser.add_argument("--output-env", default="stable-images.env")
    parser.add_argument("--build-version", default="v1")
    args = parser.parse_args()

    if not Path(args.compose_file).exists():
        print(f"Compose file {args.compose_file} not found.")
        sys.exit(1)

    # 1. Extract images
    print("Extracting images from compose file...")
    res = run(["docker", "compose", "-f", args.compose_file, "config", "--images"], capture=True)
    images = [img.strip() for img in res.stdout.splitlines() if img.strip()]
    
    # Filter out local images (e.g., hq-sec/*)
    external_images = [img for img in images if not img.startswith("hq-sec/")]

    results = {
        "part_1": [],
        "part_2": [],
        "failed": []
    }

    # Part 1
    print("\n--- STAGE 1: PART 1 ---")
    for img in external_images:
        harbor_base, _ = get_harbor_ref(img)
        target_tag = f"stable_build_{args.build_version}_part_1"
        target_ref = f"{harbor_base}:{target_tag}"
        
        print(f"Processing {img} -> {target_ref}")
        if run(["docker", "pull", img]).returncode == 0:
            run(["docker", "tag", img, target_ref])
            if run(["docker", "push", target_ref]).returncode == 0:
                results["part_1"].append((img, harbor_base))
                continue
        
        results["failed"].append(img)

    # Part 2: Retry failures
    if results["failed"]:
        print("\n--- STAGE 2: PART 2 (Retrying failures) ---")
        to_retry = results["failed"][:]
        results["failed"] = []
        for img in to_retry:
            harbor_base, _ = get_harbor_ref(img)
            target_tag = f"stable_build_{args.build_version}_part_2"
            target_ref = f"{harbor_base}:{target_tag}"
            
            print(f"Retrying {img} -> {target_ref}")
            # Optional: Add a small delay
            if run(["docker", "pull", img]).returncode == 0:
                run(["docker", "tag", img, target_ref])
                if run(["docker", "push", target_ref]).returncode == 0:
                    results["part_2"].append((img, harbor_base))
                    continue
            
            results["failed"].append(img)

    # Finalize: Merge to stable_build_v1
    print("\n--- FINALIZING: Merging to stable_build_{args.build_version} ---")
    stable_map = {}
    all_success = results["part_1"] + results["part_2"]
    
    for original_img, harbor_base in all_success:
        final_tag = f"stable_build_{args.build_version}"
        final_ref = f"{harbor_base}:{final_tag}"
        
        # Pull the specific part tag to ensure we have the right one
        part_tag = f"stable_build_{args.build_version}_part_1" if (original_img, harbor_base) in results["part_1"] else f"stable_build_{args.build_version}_part_2"
        run(["docker", "tag", f"{harbor_base}:{part_tag}", final_ref])
        run(["docker", "push", final_ref])
        
        # Store for metadata
        env_key = original_img.split("/")[-1].split(":")[0].upper().replace("-", "_") + "_IMAGE"
        stable_map[env_key] = final_ref

    # Write metadata
    print(f"\nWriting metadata to {args.output_env}")
    with open(args.output_env, "w") as f:
        f.write(f"# Stable images for build {args.build_version}\n")
        for key, val in stable_map.items():
            f.write(f"{key}={val}\n")

    if results["failed"]:
        print("\nWARNING: Some images failed all attempts:")
        for img in results["failed"]:
            print(f"  - {img}")
    
    print("\nDone.")

if __name__ == "__main__":
    main()
