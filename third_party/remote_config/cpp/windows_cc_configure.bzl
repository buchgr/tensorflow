# pylint: disable=g-bad-file-header
# Copyright 2016 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Configuring the C++ toolchain on Windows."""

load(
    "@bazel_tools//tools/cpp:lib_cc_configure.bzl",
    "auto_configure_fail",
    "auto_configure_warning",
    "auto_configure_warning_maybe",
    "escape_string",
)

def raw_exec(repository_ctx, arguments):
    print(arguments)
    result = repository_ctx.execute(arguments)
    print("CMD (%d): stderr=%s, stdout=%s" % (result.return_code, result.stderr, result.stdout))
    return result

def _readdir(repository_ctx, src_dir):
    src_dir = src_dir.replace("/", "\\")

    program = "from os import listdir;"
    program += "from os.path import exists;"
    program += "print(\"\\r\\n\".join(listdir(\"%s\"))) if exists(\"%s\") else print(\"\");" % (src_dir, src_dir)

    result = raw_exec(repository_ctx, ["C:\\Python37\\python.exe", "-c", program])
    print("EXISTS %d: " % result.return_code, result.stderr)

    return [basename.strip() for basename in result.stdout.split("\\r\\n") if len(basename.strip()) > 0] 

def _exists(repository_ctx, path):
    result = raw_exec(repository_ctx, ["C:\\Python37\\python.exe", "-c", "from os.path import exists; print(\"True\") if exists(\"%s\") else print(\"False\");" % path])
    stdout = result.stdout.strip()
    print("EXISTS %d: " % result.return_code, result.stdout)
    return stdout == "True"

def _get_exec_env_var(repository_ctx, name):
    env_name = "%" + name + "%"
    result = raw_exec(repository_ctx,
        ["C:\\Windows\\System32\\cmd.exe", "/c", "echo " + env_name],
    )
    print("ENV (%d):" % result.return_code, result.stderr)
    val = result.stdout.strip()
    if len(val) == 0 or val == env_name:
        return None
    return val

def _escape_path(value, name):
    if value[0] == "\"":
        if len(value) == 1 or value[-1] != "\"":
            auto_configure_fail("'%s' environment variable has no trailing quote" % name)
        value = value[1:-1]
    if "/" in value:
        value = value.replace("/", "\\")
    if value[-1] == "\\":
        value = value.rstrip("\\")
    return value

def _get_path_exec_env_var(repository_ctx, name):
    value = _get_exec_env_var(repository_ctx, name)
    if value == None:
        return None
    return _escape_path(value, name)

def _get_path_env_var(repository_ctx, name):
    """Returns a path from an environment variable.

    Removes quotes, replaces '/' with '\', and strips trailing '\'s."""
    if name in repository_ctx.os.environ:
        value = repository_ctx.os.environ[name]
        return _escape_path(value, name)
    else:
        return None

def _get_temp_env(repository_ctx):
    """Returns the value of TMP, or TEMP, or if both undefined then C:\\Windows."""
    tmp = _get_path_env_var(repository_ctx, "TMP")
    if not tmp:
        tmp = _get_path_env_var(repository_ctx, "TEMP")
    if not tmp:
        tmp = "C:\\Windows\\Temp"
        auto_configure_warning(
            "neither 'TMP' nor 'TEMP' environment variables are set, using '%s' as default" % tmp,
        )
    return tmp

def _get_system_root(repository_ctx):
    """Get System root path on Windows, default is C:\\Windows. Doesn't %-escape the result."""
    systemroot = _get_path_env_var(repository_ctx, "SYSTEMROOT")
    if not systemroot:
        systemroot = "C:\\Windows"
        auto_configure_warning_maybe(
            repository_ctx,
            "SYSTEMROOT is not set, using default SYSTEMROOT=C:\\Windows",
        )
    return escape_string(systemroot)

def _add_system_root(repository_ctx, env):
    """Running VCVARSALL.BAT and VCVARSQUERYREGISTRY.BAT need %SYSTEMROOT%\\\\system32 in PATH."""
    if "PATH" not in env:
        env["PATH"] = ""
    env["PATH"] = env["PATH"] + ";" + _get_system_root(repository_ctx) + "\\system32"
    return env

def find_vc_path(repository_ctx):
    """Find Visual C++ build tools install path. Doesn't %-escape the result."""

    # 1. Check if BAZEL_VC or BAZEL_VS is already set by user.
    bazel_vc = _get_path_exec_env_var(repository_ctx, "BAZEL_VC")
    bazel_vc = bazel_vc.replace("\\", "\\\\")
    if bazel_vc:
        if _exists(repository_ctx, bazel_vc):
            return bazel_vc
        else:
            auto_configure_warning_maybe(
                repository_ctx,
                "%BAZEL_VC% is set to non-existent path, ignoring.",
            )

    bazel_vs = _get_path_env_var(repository_ctx, "BAZEL_VS")
    print("bazel_vs: ", bazel_vs)
    if bazel_vs:
        if _exists(repository_ctx, bazel_vs):
            bazel_vc = bazel_vs + "\\VC"
            if _exists(repository_ctx, bazel_vc):
                return bazel_vc
            else:
                auto_configure_warning_maybe(
                    repository_ctx,
                    "No 'VC' directory found under %BAZEL_VS%, ignoring.",
                )
        else:
            auto_configure_warning_maybe(
                repository_ctx,
                "%BAZEL_VS% is set to non-existent path, ignoring.",
            )

    auto_configure_warning_maybe(
        repository_ctx,
        "Neither %BAZEL_VC% nor %BAZEL_VS% are set, start looking for the latest Visual C++" +
        " installed.",
    )

    # 2. Check if VS%VS_VERSION%COMNTOOLS is set, if true then try to find and use
    # vcvarsqueryregistry.bat / VsDevCmd.bat to detect VC++.
    auto_configure_warning_maybe(repository_ctx, "Looking for VS%VERSION%COMNTOOLS environment variables, " +
                                                 "eg. VS140COMNTOOLS")
    for vscommontools_env, script in [
        ("VS160COMNTOOLS", "VsDevCmd.bat"),
        ("VS150COMNTOOLS", "VsDevCmd.bat"),
        ("VS140COMNTOOLS", "vcvarsqueryregistry.bat"),
        ("VS120COMNTOOLS", "vcvarsqueryregistry.bat"),
        ("VS110COMNTOOLS", "vcvarsqueryregistry.bat"),
        ("VS100COMNTOOLS", "vcvarsqueryregistry.bat"),
        ("VS90COMNTOOLS", "vcvarsqueryregistry.bat"),
    ]:
        vscommontools_env_value = _get_path_exec_env_var(repository_ctx, vscommontools_env)
        if vscommontools_env_value == None:
            continue

        script = vscommontools_env_value + "\\" + script
        print("SCRIPT: " + script)
        if not _exists(repository_ctx, script):
            continue
        print("EXISTS: " + script)

        program = []
        program.append("@echo off\n")
        program.append("call \"" + script + "\" > NUL\n")
        program.append("echo %VCINSTALLDIR%")

        cmd = "from os import linesep;"
        cmd += "f = open('get_vc_dir.bat', 'w');"
        for line in program:
            cmd += "f.write(\"%s\" + linesep);" % line
        cmd += "f.close();"
        cmd += "from os import system;"
        cmd += "system(\"%s /c ./get_vc_dir.bat\");" % "C:\\Windows\\System32\\cmd.exe"

        vc_dir = raw_exec(repository_ctx, ["C:\\Python37\\python.exe", "-c", " ".join(cmd)]).stdout
        print(vc_dir)

        # repository_ctx.file(
        #     "get_vc_dir.bat",
        #     "@echo off\n" +
        #     "call \"" + script + "\" > NUL\n" +
        #     "echo %VCINSTALLDIR%",
        #     True,
        # )

        # env = _add_system_root(repository_ctx, repository_ctx.os.environ)
        # vc_dir = execute(repository_ctx, ["./get_vc_dir.bat"], environment = env)

        auto_configure_warning_maybe(repository_ctx, "Visual C++ build tools found at %s" % vc_dir)
        return vc_dir

    # 3. User might have purged all environment variables. If so, look for Visual C++ in registry.
    # Works for Visual Studio 2017 and older. (Does not work for Visual Studio 2019 Preview.)
    # TODO(laszlocsomor): check if "16.0" also has this registry key, after VS 2019 is released.
    auto_configure_warning_maybe(repository_ctx, "Looking for Visual C++ through registry")
    reg_binary = _get_system_root(repository_ctx) + "\\system32\\reg.exe"
    vc_dir = None
    for key, suffix in (("VC7", ""), ("VS7", "\\VC")):
        for version in ["15.0", "14.0", "12.0", "11.0", "10.0", "9.0", "8.0"]:
            if vc_dir:
                break
            result = raw_exec(repository_ctx, [reg_binary, "query", "HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\Microsoft\\VisualStudio\\SxS\\" + key, "/v", version])
            auto_configure_warning_maybe(repository_ctx, "registry query result for VC %s:\n\nSTDOUT(start)\n%s\nSTDOUT(end)\nSTDERR(start):\n%s\nSTDERR(end)\n" %
                                                         (version, result.stdout, result.stderr))
            if not result.stderr:
                for line in result.stdout.split("\n"):
                    line = line.strip()
                    if line.startswith(version) and line.find("REG_SZ") != -1:
                        vc_dir = line[line.find("REG_SZ") + len("REG_SZ"):].strip() + suffix
    if vc_dir:
        auto_configure_warning_maybe(repository_ctx, "Visual C++ build tools found at %s" % vc_dir)
        return vc_dir

    # 4. Check default directories for VC installation
    auto_configure_warning_maybe(repository_ctx, "Looking for default Visual C++ installation directory")
    program_files_dir = _get_path_env_var(repository_ctx, "PROGRAMFILES(X86)")
    if not program_files_dir:
        program_files_dir = "C:\\Program Files (x86)"
        auto_configure_warning_maybe(
            repository_ctx,
            "'PROGRAMFILES(X86)' environment variable is not set, using '%s' as default" % program_files_dir,
        )
    for path in [
        "Microsoft Visual Studio\\2019\\Preview\\VC",
        "Microsoft Visual Studio\\2019\\BuildTools\\VC",
        "Microsoft Visual Studio\\2019\\Community\\VC",
        "Microsoft Visual Studio\\2019\\Professional\\VC",
        "Microsoft Visual Studio\\2019\\Enterprise\\VC",
        "Microsoft Visual Studio\\2017\\BuildTools\\VC",
        "Microsoft Visual Studio\\2017\\Community\\VC",
        "Microsoft Visual Studio\\2017\\Professional\\VC",
        "Microsoft Visual Studio\\2017\\Enterprise\\VC",
        "Microsoft Visual Studio 14.0\\VC",
    ]:
        path = program_files_dir + "\\" + path
        if _exists(repository_ctx, path):
            vc_dir = path
            break

    if not vc_dir:
        auto_configure_warning_maybe(repository_ctx, "Visual C++ build tools not found.")
        return None
    auto_configure_warning_maybe(repository_ctx, "Visual C++ build tools found at %s" % vc_dir)
    return vc_dir

def _is_vs_2017_or_2019(vc_path):
    """Check if the installed VS version is Visual Studio 2017."""

    # In VS 2017 and 2019, the location of VC is like:
    # C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\VC\
    # In VS 2015 or older version, it is like:
    # C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\
    return vc_path.find("2017") != -1 or vc_path.find("2019") != -1

def _find_vcvars_bat_script(repository_ctx, vc_path):
    """Find batch script to set up environment variables for VC. Doesn't %-escape the result."""
    if _is_vs_2017_or_2019(vc_path):
        vcvars_script = vc_path + "\\Auxiliary\\Build\\VCVARSALL.BAT"
    else:
        vcvars_script = vc_path + "\\VCVARSALL.BAT"

    if not _exists(repository_ctx, vcvars_script):
        return None

    return vcvars_script

def _is_support_vcvars_ver(vc_full_version):
    """-vcvars_ver option is supported from version 14.11.25503 (VS 2017 version 15.3)."""
    version = [int(i) for i in vc_full_version.split(".")]
    min_version = [14, 11, 25503]
    return version >= min_version

def _is_support_winsdk_selection(repository_ctx, vc_path):
    """Windows SDK selection is supported with VC 2017 / 2019 or with full VS 2015 installation."""
    if _is_vs_2017_or_2019(vc_path):
        return True

    # By checking the source code of VCVARSALL.BAT in VC 2015, we know that
    # when devenv.exe or wdexpress.exe exists, VCVARSALL.BAT supports Windows SDK selection.
    vc_common_ide = repository_ctx.path(vc_path).dirname.get_child("Common7").get_child("IDE")
    for tool in ["devenv.exe", "wdexpress.exe"]:
        if _exists(repository_ctx, vc_common_ide.get_child(tool)):
            return True
    return False

def setup_vc_env_vars(repository_ctx, vc_path, envvars = [], allow_empty = False, escape = True):
    """Get environment variables set by VCVARSALL.BAT script. Doesn't %-escape the result!

    Args:
        repository_ctx: the repository_ctx object
        vc_path: Visual C++ root directory
        envvars: list of envvars to retrieve; default is ["PATH", "INCLUDE", "LIB", "WINDOWSSDKDIR"]
        allow_empty: allow unset envvars; if False then report errors for those
        escape: if True, escape "\" as "\\" and "%" as "%%" in the envvar values

    Returns:
        dictionary of the envvars
    """
    if not envvars:
        envvars = ["PATH", "INCLUDE", "LIB", "WINDOWSSDKDIR"]

    vcvars_script = _find_vcvars_bat_script(repository_ctx, vc_path)
    if not vcvars_script:
        auto_configure_fail("Cannot find VCVARSALL.BAT script under %s" % vc_path)

    # Getting Windows SDK version set by user.
    # Only supports VC 2017 & 2019 and VC 2015 with full VS installation.
    winsdk_version = _get_winsdk_full_version(repository_ctx)
    if winsdk_version and not _is_support_winsdk_selection(repository_ctx, vc_path):
        auto_configure_warning(("BAZEL_WINSDK_FULL_VERSION=%s is ignored, " +
                                "because standalone Visual C++ Build Tools 2015 doesn't support specifying Windows " +
                                "SDK version, please install the full VS 2015 or use VC 2017/2019.") % winsdk_version)
        winsdk_version = ""

    # Get VC version set by user. Only supports VC 2017 & 2019.
    vcvars_ver = ""
    if _is_vs_2017_or_2019(vc_path):
        full_version = _get_vc_full_version(repository_ctx, vc_path)

        # Because VCVARSALL.BAT is from the latest VC installed, so we check if the latest
        # version supports -vcvars_ver or not.
        if _is_support_vcvars_ver(_get_latest_subversion(repository_ctx, vc_path)):
            vcvars_ver = "-vcvars_ver=" + full_version

    cmd = "\\\"%s\\\" amd64 %s %s" % (vcvars_script, winsdk_version, vcvars_ver)
    print_envvars = ",".join(["{k}=%{k}%".format(k = k) for k in envvars])
    # repository_ctx.file(
    #     "get_env.bat",
    #     "@echo off\n" +
    #     ("call %s > NUL \n" % cmd) + ("echo %s \n" % print_envvars),
    #     True,
    # )

    program = []
    program.append("@echo off")
    program.append("call %s > NUL" % cmd)
    program.append("echo %s" % print_envvars)

    cmd = "from os import linesep;"
    cmd += "f = open('get_env.bat', 'w');"
    for line in program:
        cmd += "f.write(\"%s\"+ linesep);" % line
    cmd += "f.close();"
    cmd += "from os import system;"
    cmd += "system(\"%s /c get_env.bat\");" % "C:\\\\Windows\\\\System32\\\\cmd.exe"

    envs = raw_exec(repository_ctx, ["C:\\Python37\\python.exe", "-c", cmd]).stdout.split(",")


    # env = _add_system_root(repository_ctx, {k: "" for k in envvars})
    # envs = execute(repository_ctx, ["./get_env.bat"], environment = env).split(",")
    env_map = {}
    for env in envs:
        key, value = env.split("=", 1)
        env_map[key] = escape_string(value.replace("\\", "\\\\")) if escape else value
        print("%s: %s", key, env_map[key])
    if not allow_empty:
        _check_env_vars(env_map, cmd, expected = envvars)
    return env_map

def _check_env_vars(env_map, cmd, expected):
    for env in expected:
        if not env_map.get(env):
            auto_configure_fail(
                "Setting up VC environment variables failed, %s is not set by the following command:\n    %s" % (env, cmd),
            )

def _get_latest_subversion(repository_ctx, vc_path):
    """Get the latest subversion of a VS 2017/2019 installation.

    For VS 2017 & 2019, there could be multiple versions of VC build tools.
    The directories are like:
      <vc_path>\\Tools\\MSVC\\14.10.24930\\bin\\HostX64\\x64
      <vc_path>\\Tools\\MSVC\\14.16.27023\\bin\\HostX64\\x64
    This function should return 14.16.27023 in this case."""
    versions = [basename for basename in _readdir(repository_ctx, vc_path + "\\Tools\\MSVC")]
    print("versions", versions)
    if len(versions) < 1:
        auto_configure_warning_maybe(repository_ctx, "Cannot find any VC installation under BAZEL_VC(%s)" % vc_path)
        return None

    # Parse the version string into integers, then sort the integers to prevent textual sorting.
    version_list = []
    for version in versions:
        parts = [int(i) for i in version.split(".")]
        version_list.append((parts, version))

    version_list = sorted(version_list)
    latest_version = version_list[-1][1]

    auto_configure_warning_maybe(repository_ctx, "Found the following VC verisons:\n%s\n\nChoosing the latest version = %s" % ("\n".join(versions), latest_version))
    return latest_version

def _get_vc_full_version(repository_ctx, vc_path):
    """Return the value of BAZEL_VC_FULL_VERSION if defined, otherwise the latest version."""
    if "BAZEL_VC_FULL_VERSION" in repository_ctx.os.environ:
        return repository_ctx.os.environ["BAZEL_VC_FULL_VERSION"]
    return _get_latest_subversion(repository_ctx, vc_path)

def _get_winsdk_full_version(repository_ctx):
    """Return the value of BAZEL_WINSDK_FULL_VERSION if defined, otherwise an empty string."""
    return repository_ctx.os.environ.get("BAZEL_WINSDK_FULL_VERSION", default = "")

def find_msvc_tool(repository_ctx, vc_path, tool):
    """Find the exact path of a specific build tool in MSVC. Doesn't %-escape the result."""
    tool_path = None
    if _is_vs_2017_or_2019(vc_path):
        full_version = _get_vc_full_version(repository_ctx, vc_path)
        print("FULL VERSION:", full_version)
        if full_version:
            tool_path = r"%s\\Tools\\MSVC\\%s\\bin\\HostX64\\x64\\%s" % (vc_path, full_version, tool)
    else:
        # For VS 2015 and older version, the tools are under:
        # C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin\amd64
        tool_path = vc_path + r"\\bin\\amd64\\" + tool

    if not tool_path or not _exists(repository_ctx, tool_path):
        return None

    return tool_path.replace("\\", "/")
