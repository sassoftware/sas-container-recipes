## Contributing

#### Compiling the sas-container-recipes binary 
1. The SAS Container Recipes tool is written in the Go programming
  language which can be installed by visiting https://golang.org/doc/install .

```
# CentOS & RHEL
yum install golang

# Ubuntu
apt-get install golang-go

# SUSE
zypper install go
```

2. The package `java-1.8.0-openjdk` or another Java Runtime Environment 
  (1.8.x) must be installed since the SAS Container Recipes tool utilizes
some features of the `sas-orchestration` tool.

```
# CentOS & RHEL
yum install java-1.8.0-openjdk

# Ubuntu
apt-get install openjdk-7-jre

# SUSE
zypper install java-1_8_0-openjdk
```
	
3. Create the directory structure for developing in Go and 
  go into the src/github.com/sassoftware directory:
`mkdir --parents ~/go/{bin,pkg,src/github.com/sassoftware/}`
`cd ~/go/src/github.com/sassoftware/`

4. The package `git`  must be installed so the project files can be cloned from the repository.
```
# CentOS & RHEL
yum install git

# Ubuntu
apt-get install git

# SUSE
zypper install git
```

5. Clone the repository into the src/github.com/sassoftware location: 
  `git clone git@github.com:sassoftware/sas-container-recipes.git`

6. Go into the newly cloned directory: `cd sas-container-recipes`

7. Fetch any dependencies: `go get ./...`

7. Run the build command, which will result in a binary called `sas-container-recipes`: `go build`

#### Reporting Security Issues
We take security seriously. If you discover a security issue then please 
**DO NOT** file a public issue, instead send a report to 
[support@sas.com](mailto:support@sas.com).

#### Reporting Problems or Improvements
Check our [GitHub issues section](https://github.com/sassoftware/sas-container-recipes/issues)
to see if the problem or suggestion exists before submitting a new issue. When creating a new 
issue there are options to select a ticket format: "Flag Security Issue", "Report Problem", 
or "Suggest Improvement". These standard ticket templates assist in communicating all relevant
details, or you can select "Open a regular issue" to skip the ticket formats.

#### Pull Requests
Have something cool to share? SAS gladly accepts pull requests on GitHub!
If you're unsure how to open a pull request then see [GitHub's collaboration
guide](https://help.github.com/categories/collaborating-with-issues-and-pull-requests/).

**Commit Messages**

Git commit messages should follow best practices, with a maximum of 50 characters 
explaining the context of your change and a brief summary of what has changed.

**Code Review Process**

Maintainers and community members will review your changes and possibly make
requests for improvement. Multiple maintainers are required to approve changes
before they are merged into the project.

All code must be properly formatted with any relevant formatting tools.
For example, code written in Go should be formatted by the `gofmt` tool (`gofmt -w *.go`)

Tip: Vim users can add `au BufWritePost *.go !gofmt -w %` to their `~/.vimrc`

**Certificate of Origin**

The contributor agreement for this software is the Developer's Certificate of Origin
1.1 (DCO) as provided with and required for accepting contributions.

```

        By making a contribution to this project, I certify that:

        (a) The contribution was created in whole or in part by me and I
            have the right to submit it under the open source license
            indicated in the file; or

        (b) The contribution is based upon previous work that, to the best
            of my knowledge, is covered under an appropriate open source
            license and I have the right under that license to submit that
            work with modifications, whether created in whole or in part
            by me, under the same open source license (unless I am
            permitted to submit under a different license), as indicated
            in the file; or

        (c) The contribution was provided directly to me by some other
            person who certified (a), (b) or (c) and I have not modified
            it.

        (d) I understand and agree that this project and the contribution
            are public and that a record of the contribution (including all
            personal information I submit with it, including my sign-off) is
            maintained indefinitely and may be redistributed consistent with
            this project or the open source license(s) involved.


```
