def apply_patch(self, other):
    # The name of MD engines differ slightly from the ones used in Spack
    format_strings = collections.defaultdict(lambda: "{0.name}-{0.version}")
    format_strings["espresso"] = "q{0.name}-{0.version}"
    format_strings["amber"] = "{0.name}{0.version}"

    get_md = lambda x: format_strings[x.name].format(x)

    # Get available patches
    plumed_patch = Executable(os.path.join(self.spec.prefix.bin, "plumed-patch"))

    out = plumed_patch("-q", "-l", output=str)
    available = out.split(":")[-1].split()
    target = get_md(other)
    log_file = Path("/tmp") / "plumed-patch-{0.name}-{0.version}.log".format(other)
    log_file.write_text(out)

    override_file = Path(__file__).with_name("plumed_patch_overrides.conf")
    if override_file.exists():
        for line in override_file.read_text().splitlines():
            name, separator, engine = line.partition("=")
            if separator and name.strip() == target:
                target = engine.strip()

    # Check that `other` is among the patchable applications
    if target not in available:
        msg = "{0.name}@{0.version} is not among the MD engine"
        msg += " that can be patched by {1.name}@{1.version}.\n"
        msg += "Available engines were saved to {2}.\n"
        msg += "To override, add '{3}=<supported engine>' to {4}.\n"
        msg += "Supported engines are:\n"
        for x in available:
            msg += x + "\n"
        raise RuntimeError(msg.format(other, self.spec, log_file, get_md(other), override_file))

    # Call plumed-patch to patch executables
    plumed_patch("-p", "-e", target)
