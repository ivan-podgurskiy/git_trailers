# Third-Party Notices

## Git

The conformance fixtures and tests independently re-express behavior described
by the Git 2.54.0 `git-interpret-trailers(1)` documentation and exercised by
Git's `t/t7513-interpret-trailers.sh` test suite. The implementation was also
checked against the trailer parsing behavior in Git's `trailer.c`.

Git is copyright its contributors and is distributed under the GNU General
Public License version 2. The referenced materials are available from:

- https://git-scm.com/docs/git-interpret-trailers/2.54.0
- https://github.com/git/git/blob/v2.54.0/t/t7513-interpret-trailers.sh
- https://github.com/git/git/blob/v2.54.0/trailer.c
- https://github.com/git/git/blob/v2.54.0/COPYING

No Git production source code or shell test code is included in this package.
The JSON cases use independently chosen messages and literal expected values.
The representative real-world-style commit-message fixtures were authored for
this test suite and are not copied from third-party commits.
