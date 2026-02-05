;;; GNU Guix package definition for Rust with Xous target support
;;;
;;; This module provides a Rust toolchain that includes the
;;; riscv32imac-unknown-xous-elf target for building Xous applications.

(define-module (rust-xous)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cross-base)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages version-control)
  #:use-module (rust-crates)
  #:use-module (rust)
  #:use-module (rust-sysroot))

;;; Rust 1.93.0 built from source via gluons channel
(define rust-1.93.0 rust-1.93)

;;; The betrusted-io/rust fork with Xous target support
(define rust-xous-source
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/betrusted-io/rust")
          (commit "2ae864f7d4d42c73ab05f5e01265ea31ae81a86e")
          (recursive? #t)))
    (file-name "rust-xous-source")
    ;; nix hash convert --to nix32 sha256-+iLFMy78f5xgw22fHPKmTy5WQonYbsi6Ms9tWeh6uxI=
    (sha256
     (base32 "04mvgbl5jvfg6axchvnqi515cbjglvr1r7vdqdh9qzzw5qrwa8ps"))))

;;; RISC-V 32-bit bare-metal cross toolchain
(define riscv32-none-elf-gcc
  (cross-gcc "riscv32-none-elf"
             #:libc #f))

(define riscv32-none-elf-binutils
  (cross-binutils "riscv32-none-elf"))

;;; All crate origins from rust-crates.scm for the sysroot build
(define sysroot-crate-inputs
  (list
   rust-addr2line-0.25.1
   rust-adler2-2.0.1
   rust-cc-1.2.0
   rust-cfg-if-1.0.4
   rust-dlmalloc-0.2.11
   rust-foldhash-0.2.0
   rust-fortanix-sgx-abi-0.6.1
   rust-getopts-0.2.24
   rust-gimli-0.32.3
   rust-hashbrown-0.16.1
   rust-hermit-abi-0.5.2
   rust-libc-0.2.177
   rust-memchr-2.7.6
   rust-miniz-oxide-0.8.9
   rust-moto-rt-0.15.2
   rust-object-0.37.3
   rust-r-efi-5.3.0
   rust-r-efi-alloc-2.1.0
   rust-rand-0.9.2
   rust-rand-core-0.9.3
   rust-rand-xorshift-0.4.0
   rust-rustc-demangle-0.1.26
   rust-rustc-literal-escaper-0.0.5
   rust-shlex-1.3.0
   rust-unwinding-0.2.8
   rust-vex-sdk-0.27.1
   rust-wasi-0.11.1+wasi-snapshot-preview1
   rust-wasi-0.14.4+wasi-0.2.4
   rust-windows-link-0.2.1
   rust-windows-sys-0.60.2
   rust-windows-targets-0.53.5
   rust-windows-aarch64-gnullvm-0.53.1
   rust-windows-aarch64-msvc-0.53.1
   rust-windows-i686-gnu-0.53.1
   rust-windows-i686-gnullvm-0.53.1
   rust-windows-i686-msvc-0.53.1
   rust-windows-x86-64-gnu-0.53.1
   rust-windows-x86-64-gnullvm-0.53.1
   rust-windows-x86-64-msvc-0.53.1
   rust-wit-bindgen-0.45.1))

;;; Build the Xous sysroot (libstd for riscv32imac-unknown-xous-elf)
(define-public xous-sysroot
  (package
    (name "xous-sysroot")
    (version "1.93.0")
    (source rust-xous-source)
    (build-system gnu-build-system)
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
          (delete 'configure)
          (delete 'check)
          (add-after 'unpack 'setup-vendor
            (lambda* (#:key inputs #:allow-other-keys)
              (use-modules (ice-9 popen)
                           (ice-9 rdelim))
              ;; Create vendor directory and unpack all crates
              (let ((vendor-dir "library/vendor"))
                (mkdir-p vendor-dir)
                (for-each
                 (lambda (input)
                   (let* ((name (car input))
                          (path (cdr input)))
                     ;; Only process crate-* inputs
                     (when (string-prefix? "crate-" name)
                       (let* ((file-name (basename path))
                              ;; Parse rust-memchr-2.7.6.tar.gz -> memchr-2.7.6
                              (crate-name (substring file-name
                                                     5  ; drop "rust-"
                                                     (- (string-length file-name) 7)))  ; drop ".tar.gz"
                              (crate-dir (string-append vendor-dir "/" crate-name))
                              ;; Compute sha256 of the tarball for cargo checksum
                              (port (open-input-pipe (string-append "sha256sum " path)))
                              (checksum-line (read-line port))
                              (_ (close-pipe port))
                              (checksum (car (string-split checksum-line #\space))))
                         (mkdir-p crate-dir)
                         (invoke "tar" "xzf" path
                                 "-C" crate-dir
                                 "--strip-components=1")
                         ;; Create .cargo-checksum.json with actual package checksum
                         (call-with-output-file
                             (string-append crate-dir "/.cargo-checksum.json")
                           (lambda (port)
                             (format port "{\"files\":{},\"package\":\"~a\"}" checksum)))))))
                 inputs))))
          (replace 'build
            (lambda* (#:key native-inputs inputs #:allow-other-keys)
              (let* ((vendor-dir (string-append (getcwd) "/library/vendor"))
                     (riscv-gcc (search-input-file inputs "/bin/riscv32-none-elf-gcc"))
                     (riscv-ar (search-input-file inputs "/bin/riscv32-none-elf-ar"))
                     (host-gcc (search-input-file inputs "/bin/gcc"))
                     (gcc-lib (search-input-file inputs "/lib/libgcc_s.so.1"))
                     (gcc-lib-dir (dirname gcc-lib))
                     (cc-wrapper-dir (string-append (getcwd) "/cc-wrapper")))
                ;; Set up environment
                (setenv "HOME" (getcwd))
                (setenv "CARGO_HOME" (string-append (getcwd) "/.cargo"))
                (mkdir-p (getenv "CARGO_HOME"))

                ;; Create cc symlink so cargo can find it
                (mkdir-p cc-wrapper-dir)
                (symlink host-gcc (string-append cc-wrapper-dir "/cc"))
                (setenv "PATH" (string-append cc-wrapper-dir ":" (getenv "PATH")))

                ;; Set LD_LIBRARY_PATH so build scripts can find libgcc_s.so.1
                (setenv "LD_LIBRARY_PATH" gcc-lib-dir)

                ;; Configure vendored dependencies
                (call-with-output-file ".cargo/config.toml"
                  (lambda (port)
                    (format port "[source.crates-io]~%")
                    (format port "replace-with = \"vendored-sources\"~%")
                    (format port "~%")
                    (format port "[source.vendored-sources]~%")
                    (format port "directory = \"~a\"~%" vendor-dir)))

                ;; Environment for building
                (setenv "CARGO_PROFILE_RELEASE_DEBUG" "0")
                (setenv "CARGO_PROFILE_RELEASE_OPT_LEVEL" "3")
                (setenv "CARGO_PROFILE_RELEASE_DEBUG_ASSERTIONS" "false")
                (setenv "RUSTC_BOOTSTRAP" "1")
                (setenv "RUSTFLAGS"
                        "-Cforce-unwind-tables=yes -Cembed-bitcode=yes -Zforce-unstable-if-unmarked")
                (setenv "__CARGO_DEFAULT_LIB_METADATA" "stablestd")
                ;; Host CC for build scripts (they run on the host)
                (setenv "CC" host-gcc)
                ;; Target-specific CC/AR for cross-compilation (underscores replace hyphens)
                (setenv "CC_riscv32imac_unknown_xous_elf" riscv-gcc)
                (setenv "AR_riscv32imac_unknown_xous_elf" riscv-ar)
                (setenv "RUST_COMPILER_RT_ROOT"
                        (string-append (getcwd) "/src/llvm-project/compiler-rt"))

                ;; Build sysroot
                (invoke "cargo" "build"
                        "--target" "riscv32imac-unknown-xous-elf"
                        "-Zbinary-dep-depinfo"
                        "--release"
                        "--features" "panic-unwind compiler-builtins-c compiler-builtins-mem"
                        "--manifest-path" "library/sysroot/Cargo.toml"))))
          (replace 'install
            (lambda* (#:key outputs #:allow-other-keys)
              (let* ((out (assoc-ref outputs "out"))
                     (lib-dir (string-append out "/lib/rustlib/riscv32imac-unknown-xous-elf/lib")))
                (mkdir-p lib-dir)
                ;; Write version file
                (call-with-output-file
                    (string-append out "/lib/rustlib/riscv32imac-unknown-xous-elf/RUST_VERSION")
                  (lambda (port)
                    (format port "~a~%" #$version)))
                ;; Copy rlib files
                (for-each
                 (lambda (file)
                   (copy-file file (string-append lib-dir "/" (basename file))))
                 (find-files "library/target/riscv32imac-unknown-xous-elf/release/deps"
                             "\\.rlib$"))))))))
    (native-inputs
     `(("rust" ,rust-1.93.0)
       ("rust:cargo" ,rust-1.93.0 "cargo")
       ("gcc-toolchain" ,gcc-toolchain)
       ("git" ,git)
       ("tar" ,tar)
       ("gzip" ,gzip)
       ("coreutils" ,coreutils)
       ("riscv32-none-elf-gcc" ,riscv32-none-elf-gcc)
       ("riscv32-none-elf-binutils" ,riscv32-none-elf-binutils)
       ;; Add all crates as inputs with crate- prefix
       ,@(map (lambda (crate)
                `(,(string-append "crate-" (origin-file-name crate)) ,crate))
              sysroot-crate-inputs)))
    (home-page "https://github.com/betrusted-io/rust")
    (synopsis "Xous sysroot for riscv32imac-unknown-xous-elf target")
    (description "Pre-built standard library (sysroot) for the
riscv32imac-unknown-xous-elf Rust target, enabling compilation of Xous
applications.")
    (license (list license:asl2.0 license:expat))))

;;; Merged sysroot combining base Rust targets with bare-metal and Xous
(define-public rust-sysroot-merged
  (package
    (name "rust-sysroot-merged")
    (version "1.93.0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out (assoc-ref %outputs "out"))
                 (rustlib-out (string-append out "/lib/rustlib"))
                 (base-rust (assoc-ref %build-inputs "rust"))
                 (bare-metal-sysroot
                  (assoc-ref %build-inputs "bare-metal-sysroot"))
                 (xous-sysroot (assoc-ref %build-inputs "xous-sysroot")))
            (mkdir-p rustlib-out)
            ;; Copy base toolchain's rustlib
            (copy-recursively (string-append base-rust "/lib/rustlib")
                              rustlib-out)
            ;; Add bare-metal target
            (copy-recursively
             (string-append bare-metal-sysroot
                            "/lib/rustlib/riscv32imac-unknown-none-elf")
             (string-append rustlib-out
                            "/riscv32imac-unknown-none-elf"))
            ;; Add Xous target
            (copy-recursively
             (string-append xous-sysroot
                            "/lib/rustlib/riscv32imac-unknown-xous-elf")
             (string-append rustlib-out
                            "/riscv32imac-unknown-xous-elf"))))))
    (inputs
     `(("rust" ,rust-1.93.0)
       ("bare-metal-sysroot" ,rust-sysroot-riscv32imac-none-elf)
       ("xous-sysroot" ,xous-sysroot)))
    (home-page "https://github.com/betrusted-io/rust")
    (synopsis "Merged Rust sysroot with Xous target")
    (description "A merged Rust sysroot that combines the standard library
targets with the riscv32imac-unknown-xous-elf target for Xous development.")
    (license (list license:asl2.0 license:expat))))

;;; Final wrapped Rust toolchain with Xous support
(define-public rust-xous
  (package
    (name "rust-xous")
    (version "1.93.0")
    (source #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))
          (let* ((out (assoc-ref %outputs "out"))
                 (bin-dir (string-append out "/bin"))
                 (base-rust (assoc-ref %build-inputs "rust"))
                 (base-rust-cargo (assoc-ref %build-inputs "rust:cargo"))
                 (merged-sysroot (assoc-ref %build-inputs "rust-sysroot-merged"))
                 (gcc-toolchain (assoc-ref %build-inputs "gcc-toolchain"))
                 (bash (assoc-ref %build-inputs "bash"))
                 ;; LD_LIBRARY_PATH for libgcc_s.so.1 needed by build scripts
                 (ld-library-path (string-append gcc-toolchain "/lib")))
            (mkdir-p bin-dir)

            ;; Create cc symlink to gcc (needed by Rust's cc crate)
            (symlink (string-append gcc-toolchain "/bin/gcc")
                     (string-append bin-dir "/cc"))

            ;; Create wrapper for rustc
            (call-with-output-file (string-append bin-dir "/rustc")
              (lambda (port)
                (format port "#!~a/bin/bash~%" bash)
                (format port "export LD_LIBRARY_PATH=\"~a${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\"~%"
                        ld-library-path)
                (format port "exec ~a/bin/rustc --sysroot ~a \"$@\"~%"
                        base-rust merged-sysroot)))
            (chmod (string-append bin-dir "/rustc") #o755)

            ;; Create wrapper for cargo (use cargo output, not main output)
            (call-with-output-file (string-append bin-dir "/cargo")
              (lambda (port)
                (format port "#!~a/bin/bash~%" bash)
                (format port "export LD_LIBRARY_PATH=\"~a${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\"~%"
                        ld-library-path)
                (format port "export RUSTC=~a/bin/rustc~%" out)
                (format port "exec ~a/bin/cargo \"$@\"~%" base-rust-cargo)))
            (chmod (string-append bin-dir "/cargo") #o755)

            ;; Symlink other tools from main rust output
            (for-each
             (lambda (tool)
               (let ((source (string-append base-rust "/bin/" tool))
                     (target (string-append bin-dir "/" tool)))
                 (when (file-exists? source)
                   (symlink source target))))
             '("rustfmt" "cargo-fmt" "clippy-driver" "cargo-clippy"
               "rust-analyzer" "rustdoc"))))))
    (inputs
     `(("rust" ,rust-1.93.0)
       ("rust:cargo" ,rust-1.93.0 "cargo")
       ("rust-sysroot-merged" ,rust-sysroot-merged)
       ("gcc-toolchain" ,gcc-toolchain)
       ("bash" ,bash)))
    (home-page "https://github.com/betrusted-io/rust")
    (synopsis "Rust toolchain with Xous target support")
    (description "A complete Rust toolchain that includes support for the
riscv32imac-unknown-xous-elf target, enabling development of applications
for the Xous operating system on RISC-V hardware.")
    (license (list license:asl2.0 license:expat))))

rust-xous
