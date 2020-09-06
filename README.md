[![License](https://img.shields.io/github/license/onox/canberra-ada.svg?color=blue)](https://github.com/onox/canberra-ada/blob/master/LICENSE)
[![Build status](https://img.shields.io/shippable/5f48c98581e85600069326f5/master.svg)](https://app.shippable.com/github/onox/canberra-ada)
[![GitHub release](https://img.shields.io/github/release/onox/canberra-ada.svg)](https://github.com/onox/canberra-ada/releases/latest)
[![IRC](https://img.shields.io/badge/IRC-%23ada%20on%20freenode-orange.svg)](https://webchat.freenode.net/?channels=ada)

# canberra-ada

Ada 2012 bindings for libcanberra.

## Usage

A minimal example to synchronously play an event sound:

```ada
with Canberra;

procedure Example is
   Context : Canberra.Context := Canberra.Create;
begin
   Context.Play ("bell");
end Example;
```

An example that shows how to play sounds asynchronously
and cancel or wait for them to finish playing:

```ada
with Canberra;

procedure Example is
   Context : Canberra.Context := Canberra.Create
     (Name => "Ada",
      ID   => "ada.lovelace",
      Icon => "utilities-terminal");

   S1, S2 : Canberra.Sound;
begin
   Context.Set_Property ("canberra.xdg-theme.name", "ubuntu");

   Context.Play ("phone-outgoing-busy", S1);
   Context.Play ("desktop-login", S2, Canberra.Music, "Login");

   --  Stop playing the music sound
   delay 1.5;
   Context.Cancel (S2);

   --  But wait for the event sound to finish playing
   S1.Await_Finish_Playing;
end Example;
```

## Dependencies

In order to build the bindings for libcanberra, you need to have:

 * An Ada 2012 compiler

 * GPRBuild and `make`

## Installing dependencies on Ubuntu 18.04 LTS

Install the dependencies using apt:

```sh
$ sudo apt install gnat-7 gprbuild make libcanberra-dev
```

For the PulseAudio backend you can install `libcanberra-pulse`.

## Installation

A Makefile is provided to build the source code and tests. Use `make` to build
the source code:

```
$ make
```

You can override CFLAGS if desired. After having compiled the source code,
the bindings can be installed by executing:

```
$ make PREFIX=/usr install
```

Change `PREFIX` to the preferred destination folder, for example `~/.local`.

## Using canberra-ada in your project

Specify the dependency in your \*.gpr project file:

```ada
with "canberra";
```

## Contributing

Read the [contributing guidelines][url-contributing] if you want to add
a bugfix or an improvement.

## License

These bindings are licensed under the [Apache License 2.0][url-apache].
The first line of each Ada file should contain an SPDX license identifier tag that
refers to this license:

    SPDX-License-Identifier: Apache-2.0

  [url-apache]: https://opensource.org/licenses/Apache-2.0
  [url-contributing]: /CONTRIBUTING.md
