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

## Pinned commit-message fixtures

`test/fixtures/real_world/linux-signed-off.txt` is an adapted excerpt from
Linux commit `2d66a033864e27ab8d5e44cb36f31d9d2413bee4`. It retains the
subject, final explanatory paragraph, and trailer block needed by the parser
test. Linux is distributed under GPL-2.0-only:

- https://github.com/torvalds/linux/commit/2d66a033864e27ab8d5e44cb36f31d9d2413bee4
- https://github.com/torvalds/linux/blob/2d66a033864e27ab8d5e44cb36f31d9d2413bee4/COPYING

`test/fixtures/real_world/ai-attribution.txt` is an adapted excerpt from
`anthropics/claude-code-action` commit
`4c51250746665e83eb7906f59236c5680910323c`. It retains representative body
text and the complete AI-attribution trailer block. That repository is
distributed under the MIT License:

- https://github.com/anthropics/claude-code-action/commit/4c51250746665e83eb7906f59236c5680910323c
- https://github.com/anthropics/claude-code-action/blob/4c51250746665e83eb7906f59236c5680910323c/LICENSE
