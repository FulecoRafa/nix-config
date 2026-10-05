{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.liveConfig;

  annotatedPackages = lib.filter (package: package ? liveConfig) config.home.packages;
  annotatedEntriesList = map (package: package.liveConfig) annotatedPackages;
  annotatedEntryNames = map (entry: entry.name) annotatedEntriesList;
  annotatedEntries = builtins.listToAttrs (
    map (entry: {
      inherit (entry) name;
      value = removeAttrs entry [ "name" ];
    }) annotatedEntriesList
  );
  entries = annotatedEntries // cfg.entries;

  isSafeRelativePath =
    value:
    value != ""
    && !lib.hasPrefix "/" value
    && lib.all (
      component:
      !builtins.elem component [
        ""
        "."
        ".."
      ]
    ) (lib.splitString "/" value);

  worktreeFor = name: "${cfg.stateDirectory}/worktrees/${name}";

  manifest = pkgs.writeText "live-config-manifest.json" (
    builtins.toJSON {
      stateDirectory = cfg.stateDirectory;
      entries = lib.mapAttrs (name: entry: {
        baseline = toString entry.source;
        repositoryPath = entry.repositoryPath;
        target = entry.target;
        worktree = worktreeFor name;
      }) entries;
    }
  );

  liveConfig = pkgs.writeShellApplication {
    name = "live-config";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.jq
      pkgs.jujutsu
      pkgs.rsync
    ];
    text = ''
      export LIVE_CONFIG_MANIFEST=${lib.escapeShellArg manifest}
      ${builtins.readFile ./live-config}
    '';
  };

  entryType = lib.types.submodule {
    options = {
      target = lib.mkOption {
        type = lib.types.str;
        example = ".config/quickshell/fuleco";
        description = "Caminho mutável relativo ao diretório home.";
      };

      source = lib.mkOption {
        type = lib.types.path;
        description = "Diretório declarativo usado como baseline.";
      };

      repositoryPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "guiapps/hyprland/quickshell";
        description = ''
          Destino relativo à raiz do repositório para o comando `save`.
          Quando nulo, a configuração pode ser testada e restaurada, mas não
          promovida automaticamente.
        '';
      };
    };
  };
in
{
  options.services.liveConfig = {
    enable = lib.mkEnableOption "configurações mutáveis durante o boot";

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/state/live-config";
      readOnly = true;
      description = "Diretório das cópias de trabalho reinicializadas a cada boot.";
    };

    entries = lib.mkOption {
      type = lib.types.attrsOf entryType;
      default = { };
      description = "Configurações autorizadas a usar uma cópia mutável por boot.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.length annotatedEntryNames == lib.length (lib.unique annotatedEntryNames);
        message = "Dois pacotes em home.packages declaram o mesmo nome de live config.";
      }
    ]
    ++ lib.flatten (
      lib.mapAttrsToList (name: entry: [
        {
          assertion = builtins.match "[A-Za-z0-9._-]+" name != null;
          message = "live config '${name}': o nome contém caracteres inseguros.";
        }
        {
          assertion = isSafeRelativePath entry.target;
          message = "live config '${name}': target deve ser um caminho relativo seguro.";
        }
        {
          assertion = builtins.readFileType entry.source == "directory";
          message = "live config '${name}': source deve ser um diretório.";
        }
        {
          assertion = entry.repositoryPath == null || isSafeRelativePath entry.repositoryPath;
          message = "live config '${name}': repositoryPath deve ser relativo e não conter '..'.";
        }
      ]) entries
    );

    home.packages = [ liveConfig ];

    home.file = lib.mapAttrs' (
      name: entry:
      lib.nameValuePair entry.target {
        force = true;
        source = config.lib.file.mkOutOfStoreSymlink (worktreeFor name);
      }
    ) entries;

    home.activation.initializeLiveConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe liveConfig} __initialize
    '';
  };
}
