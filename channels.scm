;; Channel configuration for guix time-machine
;;
;; Usage:
;;   guix time-machine --channels=channels.scm -- build -L . -e '(@ (rust-xous) rust-xous)'
;;
;; Channels:
;;   - guix: rust-team branch (provides rust-1.90 base)
;;   - gluons: provides rust-1.91 through rust-1.93 and rust-sysroot

(list
 (channel
  (name 'guix)
  (url "https://git.savannah.gnu.org/git/guix.git")
  (branch "rust-team")
  (introduction
   (make-channel-introduction
    "9edb3f66fd807b096b48283debdcddccfea34bad"
    (openpgp-fingerprint
     "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
 (channel
  (name 'gluons)
  (url "https://codeberg.org/gluonix/gluons.git")
  (branch "ci-riscv32imac-unknown-none-elf")
  (introduction
   (make-channel-introduction
    "5a83f01b3a1ba461cb38705a8a48a58b5c3ea0c2"
    (openpgp-fingerprint
     "E39D 2B3D 0564 BA43 7BD9  2756 C38A E0EC CAB7 D5C8")))))
