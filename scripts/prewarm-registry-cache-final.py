from pathlib import Path
import py_compile

script_path = Path("/mnt/data/prewarm-registry-cache-final.edited.py")
script = script_path.read_text(encoding="utf-8")

# Add gzip/shutil imports back
script = script.replace("import argparse\nimport os\nimport subprocess\nfrom pathlib import Path", 
                        "import argparse\nimport gzip\nimport os\nimport shutil\nimport subprocess\nfrom pathlib import Path")

old_func = '''def create_docker_artifact(image: str, out_dir: str) -> Path:
    artifact_dir = Path(out_dir)
    artifact_dir.mkdir(parents=True, exist_ok=True)

    tar_path = artifact_dir / docker_tar_name(image)

    print(f"Saving Docker image artifact: {tar_path}")

    if tar_path.exists():
        tar_path.unlink()

    run_command_checked(["docker", "save", "-o", str(tar_path), image])

    print(f"Artifact created: {tar_path}")
    return tar_path
'''

new_func = '''def compress_tar(tar_path: Path, gz_path: Path) -> None:
    with tar_path.open("rb") as source:
        with gzip.open(gz_path, "wb") as target:
            shutil.copyfileobj(source, target)


def create_docker_artifact(image: str, out_dir: str) -> Path:
    artifact_dir = Path(out_dir)
    artifact_dir.mkdir(parents=True, exist_ok=True)

    tar_name = docker_tar_name(image)
    tar_path = Path(tar_name)
    gz_path = Path(f"{tar_name}.gz")
    artifact_path = artifact_dir / gz_path.name

    print(f"Saving Docker image artifact: {tar_path}")
    if tar_path.exists():
        tar_path.unlink()

    if gz_path.exists():
        gz_path.unlink()

    run_command_checked(["docker", "save", "-o", str(tar_path), image])

    try:
        print(f"Compressing Docker image artifact: {gz_path}")
        compress_tar(tar_path, gz_path)

        print(f"Moving artifact to: {artifact_path}")
        if artifact_path.exists():
            artifact_path.unlink()
        gz_path.replace(artifact_path)

        print(f"Artifact created: {artifact_path}")
        return artifact_path

    finally:
        if tar_path.exists():
            tar_path.unlink()

        if gz_path.exists():
            gz_path.unlink()
'''

if old_func not in script:
    raise RuntimeError("Expected create_docker_artifact function was not found.")

script = script.replace(old_func, new_func)

out = Path("/mnt/data/prewarm-registry-cache-final.tar-gz.py")
out.write_text(script, encoding="utf-8")
py_compile.compile(str(out), doraise=True)
out
