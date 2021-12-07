# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder
using Pkg

name = "pylon_julia_wrapper"

version_string = get(ENV, "GITHUB_REF_NAME", "")
version = tryparse(VersionNumber, version_string)
if version === nothing
    version = v"0.99.0"
end

sources = [
    DirectorySource(joinpath(@__DIR__, "..", "src"))
]

julia_version = v"1.6.0"

pylon_version = "5.1.0.12682"
pylon_sha1sum = "db866bea9d8a8273d8b85cc331fa77b95bae4c83"

# pylon_version = "5.2.0.13457"

pylon_macos_version = "5.1.1.13069"
pylon_macos_sha1sum = "140234a603b5a8b0b9ff0aa725dcaedbdff2908d"

basler_web_time_limit = round(Int, time()) + 24*60*60

# Bash recipe for building across all platforms
script = """
cd \$WORKSPACE

mkdir downloads && cd downloads

if [[ \${target} == *linux* ]]; then
    curl https://www.baslerweb.com/fp-$basler_web_time_limit/media/downloads/software/pylon_software/pylon-$pylon_version-x86_64.tar.gz -O
    echo "$pylon_sha1sum  pylon-$pylon_version-x86_64.tar.gz" | sha1sum -c -w
    tar xfz pylon-$pylon_version-x86_64.tar.gz
    cd pylon-$pylon_version-x86_64
    tar xfz pylonSDK*.tar.gz

    export PYLON_INCLUDE_PATH=`pwd`/pylon5/include
    export PYLON_LIB_PATH=`pwd`/pylon5/lib64

    cp -av \${PYLON_LIB_PATH}/ \$WORKSPACE/destdir/lib64

    install_license pylon5/share/pylon/License.html
    install_license pylon5/share/pylon/pylon_Third-Party_Licenses.html
elif [[ \${target} == *apple* ]]; then
    curl https://www.baslerweb.com/fp-$basler_web_time_limit/media/downloads/software/pylon_software/pylon-$pylon_macos_version.dmg -O
    echo "$pylon_macos_sha1sum  pylon-$pylon_macos_version.dmg" | sha1sum -c -w
    apk update && apk add p7zip && apk add libarchive-tools
    7z x pylon-$pylon_macos_version.dmg
    mv \"pylon 5 Camera Software Suite\" pylon-$(pylon_macos_version)
    cd pylon-$(pylon_macos_version)
    7z x pylon-$pylon_macos_version.pkg
    gunzip -c pylonsdk.pkg/Payload | bsdcpio -i --no-preserve-owner

    cp -av Library/Frameworks/pylon.framework \$WORKSPACE/destdir/lib/

    export PYLON_INCLUDE_PATH=\$WORKSPACE/destdir/lib/pylon.framework/Headers
    export PYLON_LIB_PATH=\$WORKSPACE/destdir/lib/pylon.framework/Libraries

    install_license Library/Frameworks/pylon.framework/Resources/pylon/License.html
    install_license Library/Frameworks/pylon.framework/Resources/pylon/pylon_Third-Party_Licenses.html
fi

cd \$WORKSPACE/srcdir

mkdir build && cd build
cmake \\
    -DCMAKE_BUILD_TYPE=Release \\
    -DCMAKE_TOOLCHAIN_FILE=\${CMAKE_TARGET_TOOLCHAIN} \\
    -DCMAKE_INSTALL_PREFIX=\$prefix \\
    -DCMAKE_FIND_ROOT_PATH=\$prefix \\
    -DJulia_PREFIX=\$prefix \\
    -DPYLON_INCLUDE_PATH=\${PYLON_INCLUDE_PATH} \\
    -DPYLON_LIB_PATH=\${PYLON_LIB_PATH} \\
    ..
VERBOSE=ON cmake --build . --config Release --target install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Platform("x86_64", "linux"; julia_version=string(julia_version)),
    Platform("x86_64", "macos"; julia_version=string(julia_version))
]
platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = [
    LibraryProduct("lib"*name, Symbol(name))
]

# Dependencies that must be installed before this package can be built
dependencies = [
    BuildDependency(PackageSpec(name="libjulia_jll", version=julia_version)),
    Dependency("libcxxwrap_julia_jll")
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version = v"8",
    julia_compat = "$(julia_version.major).$(julia_version.minor)")
