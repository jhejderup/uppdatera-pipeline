# uppdatera-docker

A collection of Docker images that systemaitcally creates artifical updates for evaluating how effective user tests are in detecting simple faults in library dependencies.

## Table of Contents

- [astminer](astminer/): Statically mines all function calls to direct dependencies.
- [callgraph](callgraph/): Constructs a static and dynamic call graph per
 discovered Maven module and its dependencies.
- [decompiler](decompiler/): Decompiles java bytecode (.class) to java source
 files (.java)
- [ghuppdatera](ghuppdatera/): Analyzes Dependabot pull requests and directly
 posts an issue with the results.
- [pitest](pitest/): Automatically resolved dependencies of Maven projects and then mutates dependency classes. Requires to run [callgraph](callgraph/) first.
- [cp_extract](cp_extract/): Resolves and saves dependencies of Maven projects.

The `run.sh` in each folder contains instructions on how to run the Docker image.

## Building an image
Inspect the `run.sh` and look for the name of the image, then:

```sh
docker build -t <image name> .
```

## Running an image

```sh
 #sha is optional
 docker run -v  <physical_dir>:/data uppdatera owner/repo sha
```

## Prerequisites

- Docker
- Java 8 projects
