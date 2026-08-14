{ lib
, buildPythonApplication
, buildPythonPackage
, callPackage
, fetchFromGitHub
, setuptools
, hatchling
, pydantic
, pyparsing
, pcpp
, pyyaml
, platformdirs
, pydantic-settings
, tree-sitter
}:
let
  tree-sitter-devicetree = callPackage ./tree-sitter-devicetree.nix {};
in
buildPythonApplication rec {
  pname = "keymap-drawer";
  version = "0.23.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "caksoylar";
    repo = pname;
    rev = "e855a57cf6f5851b8235b56a69d46fa0646b26e8";
    hash = "sha256-j5X7ZFlaDAbf6+AtlB/qpD+lX7YDUM/op4BNpSpzapI=";
  };

  build-system = [ hatchling ];

  propagatedBuildInputs = [
    pydantic
    pcpp
    pyyaml
    platformdirs
    pydantic-settings
    pyparsing
    tree-sitter
    tree-sitter-devicetree
  ];

  doCheck = false;

  meta = {
    homepage = "https://github.com/caksoylar/keymap-drawer";
    description = "Parse QMK & ZMK keymaps and draw them as vector graphics";
    license = lib.licenses.mit;
  };
}
