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

def _preset(image_name: str, base: str, setup: str,
            platforms=("linux/amd64", "linux/arm64")):
    """Helper to keep the presets dict concise.

    If `base` looks like an internal short name (no ``:`` tag, no ``/`` path
    component), prepend the internal registry + namespace. Otherwise treat it
    as a fully-qualified reference (e.g. ``ubuntu:24.04``).
    """
    if "/" not in base and ":" not in base:
        base = f"{registry}/{namespace}/{base}"
    return {
        "base_image": base,
        "setup": setup,
        "image_name": image_name,
        "platform": list(platforms),
        "location": ci_images_path,
    }


presets = {
    #
    # UBUNTU 22.04
    #
    "base-ubuntu2204":
        _preset("base-ubuntu2204",             "ubuntu:22.04",         "base/ubuntu2204"),

    "builder-gcc13-ubuntu2204":
        _preset("builder-gcc13-ubuntu2204",    "base-ubuntu2204",      "builder/gcc-13"),
    "builder-clang15-ubuntu2204":
        _preset("builder-clang15-ubuntu2204",  "base-ubuntu2204",      "builder/clang-15"),
    "builder-clang-llvm18-ubuntu2204":
        _preset("builder-clang-llvm18-ubuntu2204", "base-ubuntu2204",  "builder/clang-llvm-18"),

    "devel-gcc13-ubuntu2204":
        _preset("devel-gcc13-ubuntu2204",      "builder-gcc13-ubuntu2204",      "devel/gcc"),
    "devel-clang15-ubuntu2204":
        _preset("devel-clang15-ubuntu2204",    "builder-clang15-ubuntu2204",    "devel/clang-15"),
    "devel-clang-llvm18-ubuntu2204":
        _preset("devel-clang-llvm18-ubuntu2204", "builder-clang-llvm18-ubuntu2204", "devel/clang-llvm-18"),

    #
    # UBUNTU 24.04
    #
    "base-ubuntu2404":
        _preset("base-ubuntu2404",             "ubuntu:24.04",         "base/ubuntu2404"),

    "builder-gcc14-ubuntu2404":
        _preset("builder-gcc14-ubuntu2404",    "base-ubuntu2404",      "builder/gcc-14"),
    "builder-clang18-ubuntu2404":
        _preset("builder-clang18-ubuntu2404",  "base-ubuntu2404",      "builder/clang-18"),

    "devel-gcc14-ubuntu2404":
        _preset("devel-gcc14-ubuntu2404",      "builder-gcc14-ubuntu2404",      "devel/gcc"),
    "devel-clang18-ubuntu2404":
        _preset("devel-clang18-ubuntu2404",    "builder-clang18-ubuntu2404",    "devel/clang-18"),
}


def run_command(cmd: str, output: bool = False, forced: bool = False, try_run: bool = False):
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
                if not try_run:
                    print(f"ERROR: '{cmd}' Error code : {ret.returncode}.", file=stderr)
                    exit(-666)
                else:
                    print(f"WARNING: '{cmd}' Error code : {ret.returncode}.", file=stderr)
            if output:
                return ret.stdout.decode().strip()
    except Exception as err:
        if not try_run:
            print(f"ERROR: Exception during '{cmd}': {err}.", file=stderr)
            exit(-666)
        else:
            print(f"WARNING: Exception during '{cmd}': {err}.", file=stderr)


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
    run_command("docker builder prune -a -f --verbose")
    run_command("docker buildx prune -a -f --verbose")


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
    Aggregates every ``Platforms:`` line (a multi-node buildx builder prints one
    per node), which avoids missing platforms when more than one node is
    registered.
    :return: The list of possible platforms.
    """
    out = run_command("docker buildx inspect --bootstrap", output=True, forced=True)
    platforms = []
    for line in out.splitlines():
        if not line.lstrip().startswith("Platforms"):
            continue
        for p in line.split(":", 1)[-1].split(","):
            p = p.strip()
            if p and p not in platforms:
                platforms.append(p)
    return platforms


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
        # force re-pull base image (in case of updates) ; tolerate failure so that
        # building a private-registry chain for the first time (when the base is not
        # yet published) still proceeds with whatever is already cached locally.
        run_command(f"docker pull {base}", try_run=True)
        # build image
        full_image = f"{registry}/{namespace}/{output}"
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
        "--all-preset", action="store_true",
        default=False, help="Build all known presets, also implies '--push and '--alias-latest'."
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

    if args.all_preset:
        if args.preset not in [None, ""] or args.base_image not in [None, ""] or args.setup_file not in [None, ""] or args.image_name not in [None, ""]:
            print("ERROR: --all-preset cannot be used with other image selection options.", file=stderr)
            return -1



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
    if args.image_name not in [None, ""]:
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
        f"Generating docker image {registry}/{namespace}/{output}:{tag} "
        f"(from base {base_image}) for the platforms {platforms}."
    )

    if args.full_clean:
        clean_docker()
    elif args.clean:
        clean_docker_build()
    start_builder()
    if args.all_preset:
        for preset in presets.keys():
            print(f"Processing preset '{preset}'...")
            base_image = presets[preset]["base_image"]
            setup = presets[preset]["setup"]
            output = presets[preset]["image_name"]
            platforms = presets[preset]["platform"]
            location = presets[preset]["location"].resolve()
            process(base_image, setup, output, tag, platforms, True, True, location)
    else:
        process(base_image, setup, output, tag, platforms, do_push, aliased, location)
    if args.full_clean or args.clean:
        clean_docker_build()
    return 0


if __name__ == "__main__":
    exit(main())
