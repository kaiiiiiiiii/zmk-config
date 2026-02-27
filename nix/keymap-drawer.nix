{ lib
, buildPythonApplication
, buildPythonPackage
, callPackage
, fetchFromGitHub
, setuptools
, poetry-core
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
  version = "0.22.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "caksoylar";
    repo = pname;
    rev = "afd87c7268edc26dc293380debeab0b7d3a52cf8";
    hash = "sha256-X3O5yspEdey03YQ6JsYN/DE9NUiq148u1W6LQpUQ3ns=";
  };

  build-system = [ poetry-core ];

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
