# l3-infrastructure

## Setup

- `aws`
- `opentofu`
- `go`
- linkerd `2.11.4`

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

