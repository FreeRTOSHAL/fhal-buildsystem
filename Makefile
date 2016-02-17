###
# scripts contains sources for various helper programs used throughout
# the kernel for the build process.
# ---------------------------------------------------------------------------
# kallsyms:      Find all symbols in vmlinux
# pnmttologo:    Convert pnm files to logo files
# conmakehash:   Create chartable
# conmakehash:	 Create arrays for initializing the kernel console tables
# docproc:       Used in Documentation/DocBook
# check-lc_ctype: Used in Documentation/DocBook

# Let clean descend into subdirs
subdir-	+= basic kconfig package
