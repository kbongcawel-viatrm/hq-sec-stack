#!/usr/bin/env python3
"""Prewarm Docker image caches, optionally through Harbor proxy cache projects.

Space optimizations included:
- Optionally prune Docker image/build cache before pulls.
- Skip images that already exist locally, unless forced.
- Remove temporary Harbor proxy-cache tags after retagging to the original image name.
- Optionally prune dangling images/build cache after pulls.

Environment variables:
- DOCKER_CACHE_PRUNE_BEFORE_PULL=true
- DOCKER_CACHE_PRUNE_AFTER_PULL=true
- DOCKER_CACHE_FORCE_PULL=true
- HARBOR_CACHE_KEEP_PROXY_TAG=true
"""

from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path


def truthy(value: str | None, default: bool = False) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def run_command(cmd: list[str], *, input_text: str | None = None) -> int:
    proc = subprocess.run(
        cmd,
        input=input_text,
        text=True,
        check=False,
    )
    return proc.returncode


def run_command_with_retry(
    cmd: list[str],
    *,
    input_text: str | None = None,
    attempts: int = 3,
    delay_seconds: int = 5,
) -> int:
    last_code = 0
    for attempt in range(1, attempts + 1):
        last_code = run_command(cmd, input_text=input_text)
        if last_code == 0:
            return 0
        if attempt < attempts:
            print(f"Retrying {' '.join(cmd)} ({attempt}/{attempts})")
            subprocess.run(["sleep", str(delay_seconds * attempt)], check=False)
    return last_code


def capture_command(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, text=True, check=False, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"command failed: {' '.join(cmd)}")
    return proc.stdout


def prune_docker_space_before_pull() -> None:
    if not truthy(os.environ.get("DOCKER_CACHE_PRUNE_BEFORE_PULL"), default=False):
        return

    print("Pruning unused Docker images and build cache before pulls")
    run_command(["docker", "image", "prune", "-af"])
    run_command(["docker", "builder", "prune", "-af"])


def prune_docker_space_after_pull() -> None:
    if not truthy(os.environ.get("DOCKER_CACHE_PRUNE_AFTER_PULL"), default=False):
        return

    print("Pruning dangling Docker images and build cache after pulls")
    run_command(["docker", "image", "prune", "-f"])
    run_command(["docker", "builder", "prune", "-af"])


def image_exists(image: str) -> bool:
    return run_command(["docker", "image", "inspect", image]) == 0


def split_image_ref(image: str) -> tuple[str, str, str | None, str | None]:
    ref = image.strip()
    digest = None
    if "@" in ref:
        ref, digest = ref.split("@", 1)

    last_slash = ref.rfind("/")
    last_colon = ref.rfind(":")
    tag = None
    if last_colon > last_slash:
        tag = ref[last_colon + 1 :]
        ref = ref[:last_colon]

    parts = ref.split("/")
    if len(parts) > 1 and ("." in parts[0] or ":" in parts[0] or parts[0] == "localhost"):
        registry = parts[0]
        path = "/".join(parts[1:])
    else:
        registry = "docker.io"
        path = ref if "/" in ref else f"library/{ref}"

    return registry, path, tag, digest


def harbor_pull_ref(image: str) -> str | None:
    harbor_host = os.environ.get("HARBOR_CACHE_HOST", "").strip().rstrip("/")
    if not harbor_host:
        return None

    registry, path, tag, _digest = split_image_ref(image)
    project_map = {
        "docker.io": os.environ.get("HARBOR_CACHE_PROJECT_DOCKERIO", "").strip()
        or os.environ.get("HARBOR_CACHE_PROJECT_DOCKERHUB", "").strip(),
        "ghcr.io": os.environ.get("HARBOR_CACHE_PROJECT_GHCR", "").strip(),
        "registry.community.greenbone.net": os.environ.get("HARBOR_CACHE_PROJECT_GREENBONE", "").strip(),
    }
    project = project_map.get(registry, "") or os.environ.get("HARBOR_CACHE_PROJECT_DEFAULT", "").strip()
    if not project:
        return None

    ref = f"{harbor_host}/{project}/{path}"
    if tag:
        ref = f"{ref}:{tag}"
    return ref


def load_images(compose_file: str, profiles: list[str], targets_file: str | None) -> list[str]:
    cmd = ["docker", "compose", "-f", compose_file]
    for profile in profiles:
        cmd.extend(["--profile", profile])
    cmd.extend(["config", "--images"])
    compose_images = capture_command(cmd).splitlines()

    images: list[str] = []
    seen: set[str] = set()
    for image in compose_images:
        image = image.strip()
        if image and image not in seen:
            images.append(image)
            seen.add(image)

    if targets_file:
        for raw_line in Path(targets_file).read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line not in seen:
                images.append(line)
                seen.add(line)

    return images


def should_skip_image(image: str) -> bool:
    ref = image.strip()
    if not ref:
        return True
    if ref == "caddy:builder-alpine" or ref.endswith(":builder-alpine"):
        return True
    if ref.startswith("hq-sec/") or ref.startswith("hq-sec-stack-"):
        return True
    return False


def login_harbor_if_needed() -> None:
    harbor_host = os.environ.get("HARBOR_CACHE_HOST", "").strip().rstrip("/")
    harbor_user = os.environ.get("HARBOR_CACHE_USERNAME", "").strip()
    harbor_password = os.environ.get("HARBOR_CACHE_PASSWORD", "").strip()
    if not (harbor_host and harbor_user and harbor_password):
        return

    print(f"Logging in to Harbor cache host {harbor_host}")
    run_command(
        ["docker", "login", harbor_host, "-u", harbor_user, "--password-stdin"],
        input_text=f"{harbor_password}\n",
    )


def pull_and_tag(image: str) -> bool:
    force_pull = truthy(os.environ.get("DOCKER_CACHE_FORCE_PULL"), default=False)
    if not force_pull and image_exists(image):
        print(f"Already present locally, skipping {image}")
        return True

    harbor_ref = harbor_pull_ref(image)

    pull_candidates: list[tuple[str, bool]] = []

    if harbor_ref:
        pull_candidates.append((harbor_ref, True))

        if truthy(os.environ.get("HARBOR_CACHE_FALLBACK_TO_ORIGIN"), default=True):
            pull_candidates.append((image, False))
    else:
        pull_candidates.append((image, False))

    for pull_ref, is_harbor_ref in pull_candidates:
        print(f"Pulling {image} from {pull_ref}")
        code = run_command_with_retry(["docker", "pull", pull_ref], attempts=3, delay_seconds=5)

        if code != 0:
            print(f"Failed to pull {pull_ref}")
            continue

        if is_harbor_ref and pull_ref != image:
            print(f"Tagging {pull_ref} as {image}")
            tag_code = run_command_with_retry(["docker", "tag", pull_ref, image], attempts=2, delay_seconds=2)
            if tag_code != 0:
                print(f"Failed to tag {pull_ref} as {image}")
                continue

            if not truthy(os.environ.get("HARBOR_CACHE_KEEP_PROXY_TAG"), default=False):
                print(f"Removing temporary Harbor proxy-cache tag {pull_ref}")
                run_command(["docker", "rmi", pull_ref])

        return True

    print(f"Broken image: {image}")
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--compose-file", default=os.environ.get("COMPOSE_FILE", "security-stack.compose.yml"))
    parser.add_argument("--profiles", default=os.environ.get("SECSTACK_PROFILES", "all"))
    parser.add_argument("--targets-file", default=os.environ.get("CACHE_TARGETS_FILE", "The Shield/scanner/targets.txt"))
    args = parser.parse_args()

    prune_docker_space_before_pull()
    login_harbor_if_needed()

    profiles = [profile for profile in args.profiles.split() if profile]
    targets_file = args.targets_file if Path(args.targets_file).exists() else None
    images = load_images(args.compose_file, profiles, targets_file)

    failures: list[str] = []
    pulled_or_present = 0

    for image in images:
        if should_skip_image(image):
            print(f"Skipping non-pull image {image}")
            continue
        if pull_and_tag(image):
            pulled_or_present += 1
        else:
            failures.append(image)

    prune_docker_space_after_pull()

    if failures:
        print("\nBroken or unavailable Docker images:")
        for image in failures:
            print(f"- {image}")

        print(f"\nCompleted with {len(failures)} broken image(s).")
        return 1

    print(f"Prewarmed {pulled_or_present} images successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
