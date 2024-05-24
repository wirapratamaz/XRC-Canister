let Package = { name : Text, version : Text, repo : Text, dependencies : List Text }

let packages = [
    { name = "base", 
      repo = "https://github.com/dfinity/motoko-base", 
      version = "f8112331eb94dcea41741e59c7e2eaf367721866", 
      dependencies = [] : List Text
    },
    { 
        name = "testing", 
        version = "main", 
        repo = "https://github.com/av1ctor/testing.mo",
        dependencies = [] : List Text
    },
] : List Package

let overrides = [
] : List Package

in  packages # overrides