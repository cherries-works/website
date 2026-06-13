# cherries.works

Official website for cherries.works.

cherries.works is an open-source software company, that builds efficient developer tools. Our projects emphasize low resource usage, minimal dependencies, and long-term maintainability.

## Philosophy

Modern software has become increasingly complex and resource-intensive. We believe software should respect the machine it runs on.

Every project released under cherries.works aims to be:

* Open source
* Lightweight
* Easy to install
* Easy to understand
* Resource efficient
* Useful in real-world environments

## Projects

### Pulse

Pulse is a lightweight monitoring solution designed for developers, self-hosters, and operators who need immediate visibility into their systems without the overhead of traditional observability stacks.

Features include:

* System metrics
* Built-in web dashboard
* HTTP API
* Raspberry Pi support
* Minimal setup

## Website

This repository contains the source code for the cherries.works website.

The site is generated using a custom static site generator written in C and deployed as static files.

## Building

```bash
$ make
$ ./build/main
```


The generated website will be placed in the `dist/` directory.

## License

MIT License
