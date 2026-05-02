import argparse
import copy
import hashlib
import io
import json
import os
import posixpath
import re
import tarfile
import time
import urllib.request
from collections import OrderedDict
from pathlib import Path


LAYERS = [
    "sha256:64bac4cf3f772ec1652faf1137942158e75779717645182293d0516b139edb3d",
    "sha256:4c1817b5ea06b879fa7d3588b19c8b5cb4ddf2245c4a9ad13fc671cdc06726cb",
]

WSL_CONF = b"""[user]
default=nobody

[automount]
enabled=false
mountFsTab=false

[interop]
enabled=false
appendWindowsPath=false
"""


def normalize_tar_path(name):
    name = name.replace("\\", "/")
    while name.startswith("./"):
        name = name[2:]
    name = name.lstrip("/")
    name = posixpath.normpath(name)
    if name in ("", "."):
        return ""
    if name == ".." or name.startswith("../"):
        raise ValueError(f"unsafe tar path: {name!r}")
    return name


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download_layer(digest, layer_dir):
    algo, hex_digest = digest.split(":", 1)
    if algo != "sha256":
        raise ValueError(f"unsupported digest algorithm: {algo}")

    layer_path = layer_dir / f"{hex_digest}.tar.gz"
    if layer_path.exists() and sha256_file(layer_path) == hex_digest:
        print(f"using existing verified layer {layer_path.name}")
        return layer_path

    tmp_path = layer_path.with_suffix(layer_path.suffix + ".tmp")
    url = f"https://mcr.microsoft.com/v2/cbl-mariner/base/core/blobs/{digest}"
    request = urllib.request.Request(url, headers={"User-Agent": "Codex"})
    print(f"downloading {digest}")
    with urllib.request.urlopen(request) as response, tmp_path.open("wb") as output:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            output.write(chunk)

    actual = sha256_file(tmp_path)
    if actual != hex_digest:
        tmp_path.unlink(missing_ok=True)
        raise RuntimeError(f"hash mismatch for {digest}: got sha256:{actual}")
    tmp_path.replace(layer_path)
    return layer_path


def remove_entry(entries, path, include_children=True):
    entries.pop(path, None)
    if include_children:
        prefix = path.rstrip("/") + "/"
        for key in list(entries.keys()):
            if key.startswith(prefix):
                del entries[key]


def apply_layer(entries, layer_path):
    print(f"merging {layer_path.name}")
    with tarfile.open(layer_path, "r:gz") as archive:
        for member in archive:
            path = normalize_tar_path(member.name)
            if not path:
                continue

            base = posixpath.basename(path)
            parent = posixpath.dirname(path)
            if base == ".wh..wh..opq":
                prefix = parent.rstrip("/") + "/"
                for key in list(entries.keys()):
                    if key != parent and (not parent or key.startswith(prefix)):
                        del entries[key]
                continue
            if base.startswith(".wh."):
                target_name = base[len(".wh.") :]
                target = f"{parent}/{target_name}" if parent else target_name
                remove_entry(entries, target, include_children=True)
                continue

            remove_entry(entries, path, include_children=not member.isdir())

            tar_info = copy.copy(member)
            tar_info.name = path
            tar_info.pax_headers = dict(getattr(member, "pax_headers", {}) or {})
            tar_info.pax_headers.pop("path", None)
            if tar_info.islnk() and tar_info.linkname:
                tar_info.linkname = normalize_tar_path(tar_info.linkname)
                tar_info.pax_headers.pop("linkpath", None)

            data = None
            if tar_info.isfile():
                extracted = archive.extractfile(member)
                if extracted is None:
                    raise RuntimeError(f"could not read file entry {path}")
                data = extracted.read()
            entries[path] = (tar_info, data)


def make_file(path, data, mode=0o644):
    info = tarfile.TarInfo(path)
    info.size = len(data)
    info.mode = mode
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mtime = int(time.time())
    return info, data


def make_dir(path):
    info = tarfile.TarInfo(path)
    info.type = tarfile.DIRTYPE
    info.mode = 0o755
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mtime = int(time.time())
    return info, None


def sanitize_fstab(entries):
    entry = entries.get("etc/fstab")
    if entry is None:
        return []
    info, data = entry
    if not info.isfile() or data is None:
        return []

    removed = []
    kept = []
    text = data.decode("utf-8", errors="replace")
    for line in text.splitlines():
        stripped = line.strip()
        lowered = stripped.lower()
        unsafe = False
        if stripped and not stripped.startswith("#"):
            unsafe = (
                "drvfs" in lowered
                or "cifs" in lowered
                or "smbfs" in lowered
                or re.search(r"(^|\s)/mnt/[a-z]($|[/\s])", lowered) is not None
                or re.search(r"[a-z]:[\\/]", lowered) is not None
            )
        if unsafe:
            removed.append(line)
        else:
            kept.append(line)

    if removed:
        new_data = ("\n".join(kept).rstrip() + "\n").encode("utf-8")
        new_info = copy.copy(info)
        new_info.size = len(new_data)
        entries["etc/fstab"] = (new_info, new_data)
    return removed


def inject_wsl_conf(entries):
    if "etc" not in entries:
        entries["etc"] = make_dir("etc")
    remove_entry(entries, "etc/wsl.conf", include_children=True)
    entries["etc/wsl.conf"] = make_file("etc/wsl.conf", WSL_CONF)


def write_rootfs(entries, rootfs_tar):
    rootfs_tar.parent.mkdir(parents=True, exist_ok=True)
    tmp_tar = rootfs_tar.with_suffix(rootfs_tar.suffix + ".tmp")
    if tmp_tar.exists():
        tmp_tar.unlink()
    with tarfile.open(tmp_tar, "w", format=tarfile.PAX_FORMAT) as archive:
        for info, data in entries.values():
            if info.isfile():
                archive.addfile(info, io.BytesIO(data))
            else:
                archive.addfile(info)
    tmp_tar.replace(rootfs_tar)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        default=r"D:\codex-workspace\downloads\cbl-mariner-2.0",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    layer_dir = output_dir / "layers"
    rootfs_tar = output_dir / "rootfs.tar"
    report_path = output_dir / "build-report.json"
    layer_dir.mkdir(parents=True, exist_ok=True)

    layer_paths = [download_layer(digest, layer_dir) for digest in LAYERS]

    entries = OrderedDict()
    for layer_path in layer_paths:
        apply_layer(entries, layer_path)

    removed_fstab_lines = sanitize_fstab(entries)
    inject_wsl_conf(entries)
    write_rootfs(entries, rootfs_tar)

    report = {
        "image": "mcr.microsoft.com/cbl-mariner/base/core:2.0",
        "layers": [
            {
                "digest": digest,
                "path": str(path),
                "bytes": path.stat().st_size,
            }
            for digest, path in zip(LAYERS, layer_paths)
        ],
        "rootfs_tar": str(rootfs_tar),
        "rootfs_bytes": rootfs_tar.stat().st_size,
        "entries": len(entries),
        "wsl_conf": WSL_CONF.decode("utf-8"),
        "removed_fstab_lines": removed_fstab_lines,
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
