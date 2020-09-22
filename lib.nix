# terranix library
# ----------------
# in here are all the code that is terranix

{ stdenv, writeShellScriptBin, writeText, pandoc, ... }:
let
  usage = writeText "usage" ''
    Usage: terranix [-q|--quiet] [--trace|--show-trace] [--with-nulls] [--pkgs path] [path]
           terranix --help

      -q | --quiet   dont print anything except the json

      -h | --help    print help

      -n             do not strip nulls. nulls will stay.
      --with-nulls

      --trace        show trace information if there is an error
      --show-trace
      
      --pkgs         provide path to nixpkgs for pinning

      path           path to the config.nix

  '';

  usageDocJson = writeText "usage" ''
    Usage: terranix-doc-json [-q|--quiet] [--trace|--show-trace] [--pkgs path] [path]
           terranix-doc-json --help

      -q | --quiet   dont print anything except the json

      -h | --help    print help

      --path         string path from declarations.path (default is $PWD)

     --url           prefix declarations.url
     --url-prefix

     --url-suffix    suffix declarations.url

      --trace        show trace information if there is an error
      --show-trace
      
      --pkgs         provide path to nixpkgs for pinning

      path           path to the config.nix

  '';

  usageDocMan = writeText "usage" ''
    Usage: terranix-doc-man [-q|--quiet] [--trace|--show-trace] [--pkgs path] [path]
           terranix --help

      -q | --quiet   dont print anything except the json

      -h | --help    print help

      --trace        show trace information if there is an error
      --show-trace
      
      --pkgs         provide path to nixpkgs for pinning

      path           path to the config.nix

  '';
in {

  terranix = writeShellScriptBin "terranix" # sh
    ''

      set -eu -o pipefail

      QUIET=""
      STRIP_NULLS="true"
      TRACE=""
      FILE="./config.nix"
      PKGS="<nixpkgs>"

      while [[ $# -gt 0 ]]
      do
          case $1 in
              --with-nulls | -n)
                  STRIP_NULLS="false"
                  shift
                  ;;
              --help| -h)
                  cat ${usage}
                  exit 0
                  ;;
              --quiet | -q)
                  QUIET="--quiet"
                  shift
                  ;;
              --show-trace | --trace)
                  TRACE="--show-trace"
                  shift
                  ;;
              --pkgs)
                  shift
                  PKGS=$1
                  shift
                  ;;
              *)
                  FILE=$1
                  shift
                  break
                  ;;
          esac
      done

      if [[ ! -f $FILE ]]
      then
          echo "$FILE does not exist"
          exit 1
      fi

      TERRAFORM_JSON=$( nix-build \
          --no-out-link \
          --attr run \
          $QUIET \
          $TRACE \
          -I config=$FILE \
          --expr "
        let pkgs = import $PKGS {};
        in with pkgs;
        let
          terranix_data = import ${
            toString ./core/default.nix
          } { inherit pkgs; terranix_config = { imports = [ <config> ]; }; strip_nulls = ''${STRIP_NULLS}; };
          terraform_json = builtins.toJSON (terranix_data.config);
        in { run = pkgs.writeText \"config.tf.json\" terraform_json; }
      " )

      NIX_BUILD_EXIT_CODE=$?
      if [[ $NIX_BUILD_EXIT_CODE -eq 0 ]]
      then
          cat $TERRAFORM_JSON
      else
          exit 1
      fi
      exit $NIX_BUILD_EXIT_CODE
    '';

  terranixDocMan = writeShellScriptBin "terranix-doc-man" ''
    set -eu -o pipefail

    FILE="./config.nix"
    OFFLINE=""
    QUIET=""
    TRACE=""
    PKGS="<nixpkgs>"

    while [[ $# -gt 0 ]]
    do
        case $1 in
            --help| -h)
                cat ${usageDocMan}
                exit 0
                ;;
            --quiet | -q)
                QUIET="--quiet"
                shift
                ;;
            --offline)
                OFFLINE="--option substitute false"
                shift
                ;;
            --show-trace | --trace)
                TRACE="--show-trace"
                shift
                ;;
            --pkgs)
                shift
                PKGS=$1
                shift
                ;;
            *)
                FILE=$1
                shift
                break
                ;;
        esac
    done

    if [[ ! -f $FILE ]]
    then
        echo "$FILE does not exist"
        exit 1
    fi

    TERRAFORM_JSON=$( nix-build \
        --no-out-link \
        $QUIET \
        $OFFLINE \
        $TRACE \
        -I config=$FILE \
        --expr "with import $PKGS {}; callPackage ${
          toString ./bin/terranix-doc-man.nix
        } { pkgs = pkgs; }"
    )

    NIX_BUILD_EXIT_CODE=$?
    if [[ $NIX_BUILD_EXIT_CODE -eq 0 ]]
    then
        man $TERRAFORM_JSON/share/man/man5/terranix-doc-man.5
    else
        exit 1
    fi
    exit $NIX_BUILD_EXIT_CODE
  '';

  terranixDocJson = writeShellScriptBin "terranix-doc-json" ''
    set -eu -o pipefail

    FILE="./config.nix"
    OFFLINE=""
    QUIET=""
    TRACE=""
    RELATIVE_PATH=$PWD
    URL_PREFIX="http://example.com/"
    URL_SUFFIX=""
    PKGS="<nixpkgs>"

    while [[ $# -gt 0 ]]
    do
        case $1 in
            --help| -h)
                cat ${usageDocJson}
                exit 0
                ;;
            --quiet | -q)
                QUIET="--quiet"
                shift
                ;;
            --offline)
                OFFLINE="--option substitute false"
                shift
                ;;
            --path)
                shift
                RELATIVE_PATH="$1"
                shift
                ;;
            --url | --url-prefix)
                shift
                URL_PREFIX="$1"
                shift
                ;;

            --url-suffix)
                shift
                URL_SUFFIX="$1"
                shift
                ;;

            --show-trace | --trace)
                TRACE="--show-trace"
                shift
                ;;

            --pkgs)
                shift
                PKGS=$1
                shift
                ;;

            *)
                FILE=$1
                shift
                break
                ;;
        esac
    done

    if [[ ! -f $FILE ]]
    then
        echo "$FILE does not exist"
        exit 1
    fi
    TERRAFORM_JSON=$( nix-build \
        --no-out-link \
        $QUIET \
        $OFFLINE \
        $TRACE \
        -I config=$FILE \
        --expr "with import $PKGS {}; callPackage ${
          toString ./bin/terranix-doc-json.nix
        } { pkgs = pkgs; arguments = { path = $RELATIVE_PATH; urlPrefix = \"$URL_PREFIX\"; urlSuffix = \"$URL_SUFFIX\"; }; }"
    )

    NIX_BUILD_EXIT_CODE=$?
    if [[ $NIX_BUILD_EXIT_CODE -eq 0 ]]
    then
        cat $TERRAFORM_JSON/options.json
    else
        exit 1
    fi
    exit $NIX_BUILD_EXIT_CODE
  '';

}
