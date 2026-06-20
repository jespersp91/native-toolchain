{
  description = "Cmake with webOS toolchain";

  inputs = { 
    
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; 
    
    x86_64-linux = {
      url = "file+https://github.com/openlgtv/buildroot-nc4/releases/latest/download/arm-webos-linux-gnueabi_sdk-buildroot-x86_64.tar.gzz";
      flake = false;
    };

    aarch64-linux = {
      url = "file+https://github.com/webosbrew/native-toolchain/releases/latest/download/arm-webos-linux-gnueabi_sdk-buildroot_linux-aarch64.tar.bz2";
      flake = false;
    };

    x86_64-darwin = {
      url = "file+https://github.com/webosbrew/native-toolchain/releases/latest/download/arm-webos-linux-gnueabi_sdk-buildroot_darwin-x86_64.tar.bz2";
      flake = false;
    };

    aarch64-darwin = {
      url = "file+https://github.com/webosbrew/native-toolchain/releases/latest/download/arm-webos-linux-gnueabi_sdk-buildroot_darwin-arm64.tar.bz2";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      allSystems = [
        "x86_64-linux" # 64bit AMD/Intel x86
        "aarch64-linux" # 64bit ARM
        "x86_64-darwin" # 64bit AMD/Intel macOS
        "aarch64-darwin" # 64bit ARM macOS
      ];

      forAllSystems = fn:
        nixpkgs.lib.genAttrs allSystems
        (system: fn { 
          pkgs = import nixpkgs { 
                  overlays = [
                    (final: prev: {
                      isl23 = prev.callPackage ./nix/isl/0.23.0.nix {};
                      libpkgconfg3 = prev.libpkgconf.overrideAttrs {
                        version = "1.6.3";
                        src = prev.fetchurl {
                          version = "1.6.3";
                          url = "https://distfiles.dereferenced.org/pkgconf/pkgconf-1.6.3.tar.xz";
                          sha256 = "sha256-YfCzGw1eoOhitFSoDBcPV7rUeHnAxCvY3okgD/YuohA=";
                        };
                      };
                      
                    })
                  ];
                      inherit system;   
                     }; 
          inherit system;});

      webOSToolchain = {system, lib, toybox,file,  patchelf, python3, fetchurl, runCommand, isl23, gmp, mpfr, libmpc, gcc, readline, libxml2, stdenv, expat, libpkgconfg3}: 
      let 
         RPATH_LIST = lib.makeLibraryPath [
            "${isl23}"
            "${gmp}"
            "${mpfr}"
            "${libmpc}"
            "${gcc}"
            "${readline}"
            "${libxml2.out}"
            "${stdenv.cc.cc.lib}"
            "${expat}"
            "${libpkgconfg3.lib}"
          ];
      in
        runCommand  "webos-toolchain" {
          buildInputs = [toybox patchelf python3 isl23 gmp mpfr file libmpc gcc readline libxml2 expat libpkgconfg3];
        } ''
          mkdir -p $out
          tar -xf ${inputs."${system}"} -C $out
          mv $out/arm-webos-linux-gnueabi_sdk-buildroot/* $out
          $out/relocate-sdk.sh

          # Patch sdl2-config cflags, most programs use <SDL2/SDL.h> instead of <SDL.h>
          # However, the toolchain include dir goes directly to inside SDL2 folder.
          mkdir SDL2
          ln -s $out/arm-webos-linux-gnueabi/sysroot/usr/include/SDL2 $out/arm-webos-linux-gnueabi/sysroot/usr/include/SDL2/ || true

          for file in $out/bin/*; do
              if [[ ! $(basename "$file") == arm-* && ! $(basename "$file") == python3-config && ! $(basename "$file") == sdl2-config && ! $(basename "$file") == toolchain-wrapper && ! $(basename "$file") == toolchain-wrapper.br_real ]]; then
                  rm "$file"
              fi
          done
          ln -s $out/arm-webos-linux-gnueabi/sysroot/usr/bin/sdl2-config $out/bin/sdl2-config || true
          rm -rf $out/arm-webos-linux-gnueabi_sdk-buildroot

          # remove everything that is not compile-related and can be found in the host pc


          # Patch $out/bin to use the correct RPATH

          for file in $out/bin/*; do
            ${patchelf}/bin/patchelf --set-rpath '${RPATH_LIST}' "$file" || true
          done
          for file in $out/libexec/gcc/arm-webos-linux-gnueabi/12.2.0/*; do
            ${patchelf}/bin/patchelf --set-rpath '${RPATH_LIST}' "$file" || true
          done
        '';
    in {

      defaultPackage = forAllSystems ({ pkgs, system }: pkgs.callPackage webOSToolchain { inherit system; });

      devShells = forAllSystems ({ pkgs, system }: let 
          webOS = (pkgs.callPackage webOSToolchain { inherit system; });
      in
      {
        default = pkgs.mkShell {
          nativeBuildInputs = [ webOS pkgs.cmake pkgs.coreutils-full];
          shellHook = ''
            source ${webOS}/environment-setup
            function webos_cmake_kit {
              mkdir -p .vscode
              echo '${builtins.toJSON [{ name = "webos-toolchain"; toolchainFile = "${webOS}/share/buildroot/toolchainfile.cmake";}]}' > .vscode/cmake-kits.json
            }
          '';
        };
      });
    };
}
