# l3-infrastructure

This repository contains the necessary Infrastructure-as-Code configuration to create a benchmark environment for L3.

## Setup

- `aws`
- `opentofu`
- `go`
- `linkerd` in version `2.11.4`

### Basic temporary steps

Generate certificates with the provided Go program

```shell
$ cd scripts/certificates
$ go run ./...
```

To create the infrastructure with OpenTofu

```shell
$ cd opentofu
$ tofu init
$ tofu plan # check the output
$ tofu apply
```

