[![Alire dcf](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/canberra_ada.json)](https://alire.ada.dev/crates/canberra_ada.html)
[![License](https://img.shields.io/github/license/onox/canberra-ada.svg?color=blue)](https://github.com/onox/canberra-ada/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/onox/canberra-ada.svg)](https://github.com/onox/canberra-ada/releases/latest)
[![IRC](https://img.shields.io/badge/IRC-%23ada%20on%20freenode-orange.svg)](https://webchat.freenode.net/?channels=ada)
[![Gitter chat](https://badges.gitter.im/gitterHQ/gitter.svg)](https://gitter.im/ada-lang/Lobby)

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

 * [Alire][url-alire]

## Installing dependencies on Ubuntu 18.04 LTS

Install the dependencies using apt:

```sh
$ sudo apt install gnat-7 gprbuild libcanberra-dev
```

and then install Alire. For the PulseAudio backend you can install `libcanberra-pulse`.

## Using the library

Use the library in your crates as follows:

```
alr with canberra_ada
```

## Contributing

Please read the [contributing guidelines][url-contributing] before opening
issues or pull requests.

## License

These bindings are licensed under the [Apache License 2.0][url-apache].
The first line of each Ada file should contain an SPDX license identifier tag that
refers to this license:

    SPDX-License-Identifier: Apache-2.0

  [url-alire]: https://alire.ada.dev/
  [url-apache]: https://opensource.org/licenses/Apache-2.0
  [url-contributing]: /CONTRIBUTING.md
