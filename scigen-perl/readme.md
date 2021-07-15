This directory contains the Perl files of [the original SCIgen project](https://github.com/strib/scigen).

Here, they are used merely for the purpose of compiling the original rule files—which have a very legible syntax—to JSON files, which are more easy to process in JavaScript.

The following modifications have been made to the files in this directory:
- `use lib '.'` has been added to some files to fix a breaking bug.
- Some files have been moved to other directories or deleted:
  - Rule files have been moved to `../rules/rules-original`.
  - Style files have been moved to `../resources`.
  - The files `TODO`, `IDEAS` and `COPYING` have been deleted.
  - `LICENSE` (originally with the GPL v2 license) has been moved to the root directory and has been updated to v3.
- The links in the code to these files have been updated accordingly.