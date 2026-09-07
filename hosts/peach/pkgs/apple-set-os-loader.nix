# A ~60 KB EFI application that tells Apple's firmware "I am macOS", then hands
# control to the real boot loader.
#
# Why this exists: on MacBookPro11,x with a discrete GPU, the firmware only
# brings up the Intel iGPU's eDP link when it believes macOS is booting.
# Booting anything else leaves the internal panel wired to the AMD GPU and the
# kernel logs:
#
#   i915 [ENCODER:92:DDI A/PHY A] failed to retrieve link info, disabling eDP
#
# Apple exposes an EFI protocol (GUID c5c5da95-7d5c-45e6-b2f1-3fd52bb10077) with
# SetOsVendor/SetOsVersion. Calling it before the OS loader runs is enough to
# unlock the iGPU. Discovered by Andreas Heider in 2013:
# https://lists.gnu.org/archive/html/grub-devel/2013-12/msg00442.html
#
# Upstream 0xbb/apple_set_os.efi only sets the flag and returns, so it needs a
# boot loader that can chainload it (rEFInd, GRUB). systemd-boot cannot do that
# unattended, so this uses Redecorating's fork, which sets the flag and then
# chainloads the next loader itself. That lets the shim sit at the front of the
# chain and stay invisible.
{
  lib,
  stdenv,
  fetchFromGitHub,
  gnu-efi,

  # Where to hand control once the firmware has been told it is booting macOS.
  # Written the way EFI writes paths: backslash separated, relative to the root
  # of the ESP. C-level escaping is applied below, do not pre-escape it here.
  chainloadPath ? ''\EFI\systemd\systemd-bootx64.efi'',

  # Narrate to the EFI console and pause for six seconds before chainloading.
  # Off for normal use, since the whole point is to be invisible, but it is the
  # only way to find out what the firmware actually said when the iGPU stays
  # locked. Build with this on, reboot, read the screen.
  verbose ? false,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "apple-set-os-loader";
  version = "0-unstable-2021-08-27";

  src = fetchFromGitHub {
    owner = "Redecorating";
    repo = "apple_set_os-loader";
    rev = "9856dc4e6d6105759ef788a473577bcaebb90a89";
    hash = "sha256-hvwqfoF989PfDRrwU0BMi69nFjPeOmSaD6vR6jIRK2Y=";
  };

  strictDeps = true;
  buildInputs = [ gnu-efi ];

  # The fork wraps *both* Apple protocol calls in `if (Version != 0)`, but the
  # call that actually unlocks the iGPU is SetOsVendor, and 0xbb's original
  # makes it unconditionally. On this MacBookPro11,5 the interface reports
  # version 0, so the unpatched fork chainloaded successfully while doing
  # nothing at all, and i915 still logged "failed to retrieve link info,
  # disabling eDP". The patch restores upstream's semantics, stops using the
  # LocateHandleBuffer out-parameters when the call failed, and adds the
  # optional console diagnostics.
  patches = [ ../patches/apple-set-os-loader-always-set-vendor.patch ];

  # Freestanding EFI code. Stack protectors, FORTIFY_SOURCE and RELRO all
  # assume a libc and a normal loader; none of that exists before ExitBootServices.
  hardeningDisable = [ "all" ];

  # The fork hardcodes the fallback loader path, because it is designed to be
  # installed *as* \EFI\Boot\bootx64.efi with the original renamed alongside it.
  # Make the target configurable so the NixOS module can place systemd-boot at
  # a path bootctl maintains without allowing a firmware entry to bypass the
  # shim.
  postPatch = ''
    substituteInPlace bootx64_silent.c \
      --replace-fail '\\EFI\\Boot\\bootx64_original.efi' \
                     '${lib.replaceStrings [ "\\" ] [ "\\\\" ] chainloadPath}'
  '';

  # Not using the upstream Makefile: it hardcodes Debian's /usr/lib paths, links
  # every object including a 1.2 MB PCI id table that the silent variant never
  # calls, and omits libefi.a. That last one matters. libgnuefi.a alone leaves
  # EndDevicePath, EndInstanceDevicePath and _entry undefined, and `ld -shared`
  # resolves undefined symbols to NULL rather than failing, so the result builds
  # and then dereferences NULL in _INT_AppendDevicePath at boot. --no-undefined
  # below turns that class of mistake back into a build failure.
  buildPhase = ''
    runHook preBuild

    inc=${gnu-efi}/include/efi
    lib=${gnu-efi}/lib

    cflags="-I$inc -I$inc/x86_64 -DGNU_EFI_USE_MS_ABI -Dx86_64 \
            -fPIC -fshort-wchar -ffreestanding -fno-stack-protector \
            -maccumulate-outgoing-args -mno-red-zone -m64 -Wall \
            ${lib.optionalString verbose "-DAPPLE_SET_OS_VERBOSE"}"

    for src in bootx64_silent.c lib/int_dpath.c lib/int_mem.c lib/int_event.c; do
      $CC $cflags -c "$src" -o "$(basename "''${src%.c}").o"
    done

    $LD -T "$lib/elf_x86_64_efi.lds" -Bsymbolic -shared -nostdlib \
        -znocombreloc --no-undefined \
        "$lib/crt0-efi-x86_64.o" \
        -o loader.so \
        bootx64_silent.o int_dpath.o int_mem.o int_event.o \
        "$($CC $cflags -print-libgcc-file-name)" \
        "$lib/libefi.a" "$lib/libgnuefi.a"

    # Two deviations from the fork's objcopy line, both required:
    #
    # -j .rodata: gnu-efi's linker script emits .rodata as its own output
    #   section. The fork copied an objcopy invocation from an older gnu-efi
    #   that folded read-only data into .data, so every string literal -- the
    #   "Apple Inc." vendor id and the chainload path itself -- was silently
    #   dropped from the PE. Nothing fails at build time; the shim just reads
    #   garbage at boot. Upstream gnu-efi added -j .rodata to its own
    #   Make.rules for exactly this reason.
    #
    # -I/-O instead of --target: upstream asks for the `efi-app-x86_64` BFD
    #   target, which binutils no longer provides (2.46 knows pei-x86-64 only).
    #   --target= sets the input format too and would reject the ELF input, so
    #   name both ends. Subsystem 10 is EFI_APPLICATION.
    $OBJCOPY -j .text -j .sdata -j .data -j .rodata -j .dynamic \
             -j .rel -j .rela -j .rela.plt -j .reloc \
             -I elf64-x86-64 -O pei-x86-64 --subsystem=10 \
             loader.so apple-set-os-loader.efi

    runHook postBuild
  '';

  # A malformed image here means a machine that does not boot, and the failure
  # would otherwise only show up on real hardware. So assert the things that
  # have actually gone wrong: the output is a PE for the right subsystem, every
  # symbol resolved, and -- the one that bites silently -- the string literals
  # survived section selection. The path is stored as UTF-16, the vendor id as
  # plain bytes, so both encodings get checked.
  doCheck = true;
  checkPhase = ''
    runHook preCheck

    $OBJDUMP -f apple-set-os-loader.efi | grep -q 'pei-x86-64'

    if $NM -D --undefined-only loader.so | grep -q .; then
      echo "unresolved symbols would be relocated to NULL at boot:" >&2
      $NM -D --undefined-only loader.so >&2
      exit 1
    fi

    strings -a -el apple-set-os-loader.efi | grep -qxF '${chainloadPath}'
    strings -a apple-set-os-loader.efi | grep -qxF 'Apple Inc.'

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 apple-set-os-loader.efi \
      "$out/share/apple-set-os-loader/apple-set-os-loader.efi"
    runHook postInstall
  '';

  meta = {
    description = "EFI shim that unlocks the Intel iGPU on dual-GPU MacBook Pros";
    homepage = "https://github.com/Redecorating/apple_set_os-loader";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
})
