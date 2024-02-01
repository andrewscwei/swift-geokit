# GeoKit [![CI](https://github.com/andrewscwei/swift-geokit/workflows/CI/badge.svg?branch=master)](https://github.com/andrewscwei/swift-geokit/actions/workflows/ci.yml?query=branch%3Amaster) [![CD](https://github.com/andrewscwei/swift-geokit/workflows/CD/badge.svg?branch=master)](https://github.com/andrewscwei/swift-geokit/actions/workflows/cd.yml?query=branch%3Amaster)

## Setup

```sh
# Prepare Ruby environment
$ brew install rbenv ruby-build
$ rbenv install
$ rbenv rehash
$ gem install bundler

# Install fastlane
$ bundle install
```

## Usage

### Adding GeoKit to an Existing Xcode App Project

From Xcode, go to **File** > **Swift Packages** > **Add Package Dependency...**, then enter the Git repo url for GeoKit: https://github.com/andrewscwei/swift-geokit.

### Adding GeoKit to an Existing Xcode App Project as a Local Dependency

Adding GeoKit as a local Swift package allows you to modify its source code as you develop your app, having changes take effect immediately during development without the need to commit changes to Git. You are responsible for documenting any API changes you have made to ensure other projects dependent on GeoKit can migrate easily.

1. Add GeoKit as a submodule to your Xcode project repo (it is recommended to add it to a directory called `Submodules` in the project root):
    ```sh
    $ git submodule add https://github.com/andrewscwei/swift-geokit Submodules/GeoKit
    ```
2. In the Xcode project, drag GeoKit (the directory containing its `Package.swift` file) to the project navigator (the left panel). If you've previously created a `Submodules` directory to store GeoKit (and possibly other submodules your project may depend on), drag GeoKit to the `Submodules` group in the navigator.
    > Once dragged, the icon of the GeoKit directory should turn into one resembling a package. If you are unable to expand the GeoKit directory from the navigator, it is possible you have GeoKit open as a project on Xcode in a separate window. In any case, restarting Xcode should resolve the problem.
3. Add GeoKit as a library to your app target:
    1. From project settings, select your target, then go to **Build Phases** > **Link Binary With Libraries**. Click on the `+` button and add the GeoKit library.

### Adding GeoKit to Another Swift Package as a Dependency

In `Package.swift`, add the following to `dependencies` (for all available versions, see [releases](https://github.com/andrewscwei/swift-geokit/releases)):

```swift
dependencies: [
  .package(name: "GeoKit", url: "git@github.com:andrewscwei/swift-geokit", from: "<version>")
]
```

## Testing

> Ensure that you have installed all destinations listed in the `Fastfile`. For example, a destination such as `platform=iOS Simulator,name=iPhone 15 Pro` will require that you have installed the iPhone 15 Pro simulator in Xcode. In the CI environment, all common simulators are already preinstalled.

```sh
$ bundle exec fastlane test
```
