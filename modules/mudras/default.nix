{
  self,
  inputs,
  mudras,
  ...
}: {
  flake-file.inputs = {
    # den.url = "github:denful/den";
    nix-std.url = "github:chessai/nix-std";
  };

  mudras.aspects.default = {
    includes = [
      mudras.aspects.default.policies.to-host
    ];
    ## Add Users to admin groups.
    policies.to-host = {
      user,
      host,
      ...
    }: {
      nixos = {...}: {
        users.groups = {
          input.members = [];
        };
        users.users.${user.userName} = {
          extraGroups = [
            "input"
          ];
        };
      };
    };
    nixos = {...}: {
      imports = [
        self.nixosModules.default
      ];
      services.mudras = {
        enable = true;
        logLevel = "trace";
      };
    };
    homeManager = {...}: {
      imports = [
        self.hmModules.default
      ];
    };
  };

  flake = {
    hmModules = rec {
      default = mudras;
      mudras = {
        lib,
        config,
        pkgs,
        ...
      }: {
        ###################################
        ## Options definition
        options.services."mudras" = with lib; {
          enable = mkEnableOption "Enable mudras.";
          logLevel = mkOption {
            default = "info";
            type = types.enum ["error" "warn" "info" "debug" "trace"];
          };
          settings = mkOption {
            type = types.attrs;
            default = {};
          };
          extraConfig = mkOption {
            type = types.attrs;
            default = {};
          };
        };
      };
    };
    nixosModules = rec {
      default = mudras;
      mudras = {
        lib,
        config,
        pkgs,
        ...
      }: {
        ###################################
        ## Options definition
        options.services."mudras" = with lib; {
          enable = mkEnableOption "Enable mudras.";
          logLevel = mkOption {
            default = "info";
            type = types.enum ["error" "warn" "info" "debug" "trace"];
          };
          settings = mkOption {
            type = types.attrs;
            default = {};
          };
          extraConfig = mkOption {
            type = types.attrs;
            default = {};
          };
        };

        config = with lib; let
          inherit (pkgs.stdenv.hostPlatform) system;
          package = self.packages.${system}.default;
        in
          mkIf config.services."mudras".enable {
            ## Working dir
            systemd.tmpfiles.rules = [
              "d '/var/lib/udev' 2774 root input - -"
              "Z '/var/lib/udev' 2774 root input - -"

              # Mudras/Swhkd
              # No longer need to be root.
              # Members of the **input** group can interact with keyboard.
              "Z /dev/input 0774 root input - -"
              "z /dev/uinput 0774 root input - -"

              "d '/var/lib/mudras' 0770 root input - -"
            ];

            systemd.user.services.mudras = {
              enable = true;
              description = "Mudras - Shinobi hotkey daemon";
              documentation = [
                # "https://github.com/crocuda/mudras"
              ];
              after = [
                # "graphical-session.target"
                "niri.service"
                "ssh-agent.service"
              ];
              wantedBy = [
                "niri.service"
              ];
              serviceConfig = let
                verbosity =
                  {
                    "error" = "";
                    "warn" = "-v";
                    "info" = "-vv";
                    "debug" = "-vvv";
                    "trace" = "-vvvv";
                  }.${
                    config.services."mudras".logLevel
                  };
              in {
                Type = "notify";
                KillMode = "process";
                # User = "root";
                # Group = "input";

                Slice = "session.slice";
                ## FIX: SSH_AUTH_SOCK not in env vars
                # ExecStartPre = ''
                #   systemctl --user import-environment SSH_AUTH_SOCK
                # '';

                ExecStart = let
                  name = "mudras-env-wrapper";
                  text = ''
                    set -e
                    PATH="/run/wrappers/bin:$HOME/.cargo/bin:$HOME/.bun/bin:/run/current-system/sw/bin:/nix/profile/bin:$HOME/.local/state/nix/profile/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:/nix/profile/bin:$HOME/.nix-profile/bin:$PATH"
                    USER_UID="$(${pkgs.coreutils}/bin/id -u $USER)"
                    SSH_AUTH_SOCK="/run/user/$USER_UID/ssh-agent"
                    ${package}/bin/mudras run ${verbosity}
                  '';
                  script = pkgs.writeShellScriptBin name text;
                in "${script}/bin/${name}";
                # WorkingDirectory = "/var/lib/mudras";
                # StandardInput = "null";
                # StandardOutput = "journal+console";
                # StandardError = "journal+console";
                AmbientCapabilities = [];
              };
            };

            # Prepend some configuration to configuration file
            environment.etc = {
              "mudras/config.yml".text = mkMerge [
                (mkBefore (
                  inputs.nix-std.lib.serde.toTOML
                  config.services."mudras".settings
                ))
                (mkAfter (
                  inputs.nix-std.lib.serde.toTOML
                  config.services."mudras".extraConfig
                ))
              ];
            };

            environment.systemPackages = with pkgs; [
              package
              ## Keyboard utils
              wev
            ];
          };
      };
    };
  };
}
