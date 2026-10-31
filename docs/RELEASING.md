# Release process

Releases follow semantic versioning. A release is published only when all of
the following pass on the commit to be tagged:

- [ ] Unit, acceptance and integration tests, including the optional groups
      (CI job `full tests`).
- [ ] `R CMD check` on Ubuntu (release, oldrel), Windows and macOS (CI).
- [ ] Documentation regenerated (`devtools::document()`) and pkgdown site
      built without errors.
- [ ] The Cauquenes example runs (`Rscript examples/cauquenes/run.R`).
- [ ] `NEWS.md` has a `# thermify X.Y.Z` section describing the changes.

Steps:

1. On a branch `code/release-vX.Y.Z`, set `Version: X.Y.Z` in `DESCRIPTION`
   and write the `NEWS.md` section. Open a pull request to `main`.
2. After merging, create the tag `vX.Y.Z` on the merge commit of `main`,
   either from the command line:

   ```sh
   git checkout main && git pull
   git tag -a vX.Y.Z -m "thermify X.Y.Z"
   git push origin vX.Y.Z
   ```

   or from GitHub: *Releases → Draft a new release → Choose a tag: vX.Y.Z
   (create on publish), target `main` → Publish release*.
   Alternatively run the `release` workflow manually from `main`
   (*Actions → release → Run workflow*): it creates the tag `vX.Y.Z` from
   `DESCRIPTION` on the current commit.

3. The `release` workflow (triggered by the tag push or the published
   release) checks that the tag matches `DESCRIPTION`, builds and checks the
   package, and creates or updates the GitHub Release with the `NEWS.md`
   section as notes and the source tarball attached.
4. On `main`, bump to the next development version (`X.Y.Z.9000`) and add a
   `# thermify (development version)` heading to `NEWS.md`.

The package is not submitted to CRAN without explicit authorisation of the
maintainer.
