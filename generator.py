#!/usr/bin/env python3
"""
Simple Wrapper around docker command for image generation
"""
from datetime import datetime
from pathlib import Path
from sys import stderr

registry = "registry.argawaen.net"
namespace = "builder"
dry_run = False

root_path = Path(__file__).resolve().parent
ci_images_path = root_path / "ci_images"

presets = {
    "base-ubuntu2204": {
        "base_image": "ubuntu:22.04",
        "setup": "base/ubuntu2204",
        "image_name": "base-ubuntu2204",
        "platform": ["linux/amd64", "linux/arm64"],
        "location": ci_images_path,
    },
    "base-ubuntu2404": {
        "base_image": "ubuntu:24.04",
        "setup": "base/ubuntu2404",
        "image_name": "base-ubuntu2404",
        "platform": ["linux/amd64", "linux/arm64"],
        "location": ci_images_path,
    },
    "builder-gcc12-ubuntu2204": {
        "base_image": f"{registry}/{namespace}/base-ubuntu2204",
        "setup": "builder/gcc-12",
        "image_name": "builder-gcc12-ubuntu2204",
        "platform": ["linux/amd64", "linux/arm64"],
        "location": ci_images_path,
    },
    "builder-clang15-ubuntu2204": {
        "base_image": f"{registry}/{namespace}/base-ubuntu2204",
        "setup": "builder/clang-15",
        "image_name": "builder-clang15-ubuntu2204",
        "platform": ["linux/amd64", "linux/arm64"],
        "location": ci_images_path,
    },
    "builder-gcc14-ubuntu2404": {
        "base_image": f"{registry}/{namespace}/base-ubuntu2404",
        "setup": "builder/gcc-14",
        "image_name": "builder-gcc14-ubuntu2404",
        "platform": ["linux/amd64", "linux/arm64"],
        "location": ci_images_path,
    },
    "builder-clang18-ubuntu2404": {
        "base_image": f"{registry}/{namespace}/base-ubuntu2404",
        "setup": "builder/clang-18",
        "image_name": "builder-clang18-ubuntu2404",
        "platform": ["linux/amd64", "linux/arm64"],
        "location": ci_images_path,
    },
}


def run_command(cmd: str, output: bool = False, forced: bool = False):
    """
    Simple wrapper to safely run commands.
    :param cmd: The command to execute.
    :param output: If we want the output as string.
    :return: Eventually the output string
    :param forced: Force execution even in dry run
    """
    from subprocess import run, PIPE

    try:
        if dry_run and not forced:
            if output:
                print(f">> {cmd}")
            else:
                print(f">> {cmd}")
        else:
            if output:
                ret = run(cmd, shell=True, stdout=PIPE)
            else:
                ret = run(cmd, shell=True)
            if ret.returncode != 0:
                print(f"ERROR: '{cmd}' Error code : {ret.returncode}.", file=stderr)
                exit(-666)
            if output:
                return ret.stdout.decode().strip()
    except Exception as err:
        print(f"ERROR: Exception during '{cmd}': {err}.", file=stderr)
        exit(-666)


def get_git_hash():
    """
    Check git t get the hash
    :return:
    """
    return run_command("git rev-parse --short HEAD", output=True, forced=True)


def clean_docker_build():
    """
    Clean the build cache of docker
    """
    run_command("docker builder prune -a -f")


def clean_docker():
    """
    Do a full docker clean
    """
    clean_docker_build()
    run_command("docker system prune -a -f --volumes")


def get_host_platform():
    """
    Get the actual docker platform
    :return: The actual docker platform
    """
    from platform import machine

    arch = machine().lower()
    if arch in ["x86_64"]:
        arch = "amd64"
    elif arch in ["aarch64"]:
        arch = "arm64"
    return f"linux/{arch}"


def get_possible_platforms():
    """
    Determine the possible platform for build.
    :return: The list of possible platforms.
    """
    out = run_command("docker buildx inspect --bootstrap", output=True, forced=True)
    for line in out.splitlines():
        if not line.startswith("Platforms"):
            continue
        return [i.strip() for i in line.split(":")[-1].split(",")]
    return []


def get_current_driver():
    """
    Determine the possible platform for build.
    :return: The list of possible platforms.
    """
    out = run_command("docker buildx inspect --bootstrap", output=True, forced=True)
    for line in out.splitlines():
        if not line.startswith("Driver"):
            continue
        return line.split(":")[-1].strip()
    return []


def start_builder():
    """
    Checks current builder's driver. Eventually start a builder that support multi architecture.
    :return: True if multi architecture enabled.
    """
    if get_current_driver() != "docker-container":
        run_command("docker buildx create --use --driver docker-container")
    return get_current_driver() == "docker-container"


def process(
    base: str,
    setup: str,
    output: str,
    tag: str,
    platforms: list,
    do_push: bool,
    aliased: bool,
    dockerfile_path: Path,
):
    """
    Process the docker build command.
    :param base: Base image
    :param setup: Setup file
    :param output: Image Name
    :param tag: The image tag
    :param platforms: The platform to use.
    :param do_push: If we push image to registry.
    :param aliased: If we alias the image to latest.
    :param dockerfile_path: Path to the Dockerfile to use.
    """
    try:
        full_image = f"{registry}/{namespace}/{output}"
        # force re-pull base image (in case of updates)
        if aliased:
            run_command(f"docker image rm {full_image}:latest")
        run_command(f"docker pull {base}")
        # build image
        if tag not in [None, ""]:
            image_tags = f" -t {full_image}:{tag}"
            if aliased:
                image_tags += f" -t {full_image}:latest"
        else:
            image_tags = f" -t {full_image}"
        plat = ""
        if len(platforms) > 0:
            plat = f"--platform={','.join(platforms)} "
        b_args = f"--build-arg BASE_IMAGE={base} --build-arg SETUP={setup}"
        if do_push:
            b_args += " --push"
        cmd = f"docker buildx build --progress=plain {plat}{b_args}{image_tags} {dockerfile_path}"
        run_command(cmd)
    except Exception as err:
        print(f"ERROR: Exception occurs during run: {err}", file=stderr)


def main():
    """
    Main entry Point
    """
    from argparse import ArgumentParser

    global dry_run, registry, namespace
    parser = ArgumentParser()
    parser.add_argument(
        "-b",
        "--base-image",
        type=str,
        default="",
        help="Base image for the generation.",
    )
    parser.add_argument(
        "-s",
        "--setup-file",
        type=str,
        default="",
        help="Setup file for the generation.",
    )
    parser.add_argument(
        "-i",
        "--image-name",
        type=str,
        default="",
        help="Output image for the generation.",
    )
    parser.add_argument(
        "-p", "--platform", type=str, default="", help="Platform for the generation."
    )
    parser.add_argument(
        "-t", "--tag", type=str, default="", help="Tag for the generation."
    )
    parser.add_argument(
        "-l", "--location", type=str, default="", help="Location of the dockerfile."
    )
    parser.add_argument(
        "--registry", type=str, default="", help="Registry for the generation."
    )
    parser.add_argument(
        "--namespace", type=str, default="", help="Namespace for the generation."
    )
    parser.add_argument(
        "--preset", type=str, default="", help="Preset name for the generation."
    )
    parser.add_argument(
        "--push",
        action="store_true",
        default=False,
        help="Push images to the repository.",
    )
    parser.add_argument(
        "--clean", action="store_true", default=False, help="CleanUp build at the end."
    )
    parser.add_argument(
        "--full-clean",
        action="store_true",
        default=False,
        help="Clean everything in docker before and after the build.",
    )
    parser.add_argument(
        "--alias-latest",
        action="store_true",
        default=False,
        help="If the builds should also tag as latest.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Only print command not doing it.",
    )
    args = parser.parse_args()

    base_image = ""
    setup = ""
    output = ""
    platforms = []
    tag = ""
    location = ci_images_path

    if args.preset not in [None, ""]:
        if args.preset in presets.keys():
            base_image = presets[args.preset]["base_image"]
            setup = presets[args.preset]["setup"]
            output = presets[args.preset]["image_name"]
            platforms = presets[args.preset]["platform"]
            if presets[args.preset]["location"].resolve().exists():
                location = presets[args.preset]["location"].resolve()
        else:
            print(f"Invalid preset name {args.preset}, possible are:", file=stderr)
            print("\n".join(presets.keys()), file=stderr)
            return -1
    if args.base_image not in [None, ""]:
        base_image = args.base_image
    if args.setup_file not in [None, ""]:
        setup = args.setup_file
    if args.base_image not in [None, ""]:
        output = args.image_name
    if args.platform not in [None, ""]:
        platforms = args.platform.split(",")
    if args.tag not in [None, ""]:
        tag = args.tag
    if args.registry not in [None, ""]:
        registry = args.registry
    if args.location not in [None, ""]:
        ll = Path(args.location).resolve()
        if ll.exists():
            location = ll
    if args.namespace not in [None, ""]:
        namespace = args.namespace

    nn = datetime.now()
    if tag in [None, ""]:
        tag = f"{nn.year}{['', '0'][nn.month < 10]}{nn.month}{['', '0'][nn.day < 10]}{nn.day}-{['', '0'][nn.hour < 10]}{nn.hour}{['', '0'][nn.minute < 10]}{nn.minute}-{get_git_hash()}"
    do_push = args.push
    dry_run = args.dry_run
    aliased = args.alias_latest

    if len(platforms) == 0:
        platforms = [get_host_platform()]

    p_platforms = get_possible_platforms()
    for platform in platforms:
        if platform not in p_platforms:
            print(
                f"ERROR: Unsupported platform {platform}. possibles are: {p_platforms}",
                file=stderr,
            )
            exit(-666)
    print(
        f"Generating docker images {registry}/{namespace}/{base_image}:{tag} for the platforms {platforms}."
    )

    if args.full_clean:
        clean_docker()
    elif args.clean:
        clean_docker_build()
    start_builder()
    process(base_image, setup, output, tag, platforms, do_push, aliased, location)
    if args.full_clean or args.clean:
        clean_docker_build()
    return 0


if __name__ == "__main__":
    exit(main())
