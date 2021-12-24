# dungeon_generator
CLI dungeon generator based on the 5E generator from the Dungeon Master's Guide

## Installation

This application is currently only verified to work on Linux operating systems (Tested with Ubuntu 17.04+), but is expected to work any any operating system that can install Ruby and GTK.

1. Install Ruby. Recommended version is 2.4. View the [official installation guide.](https://www.ruby-lang.org/en/documentation/installation/)
2. Install GTK if necessary. Many Linux operating systems already have it installed by default. View the [official installation guide.](https://www.gtk.org/docs/installations/)
3. Install the required gems in the Gemfile. The easiest way is to use bundler.
```
# Example for GNU/Linux and Unix operating systems
cd <path of dungeon_generator>
bundle install
```

## Usage

Execute the `dungeon_generator` script in the `bin` directory with no arguments. See `conf/dungeon_generator.yaml` for configurable settings.
