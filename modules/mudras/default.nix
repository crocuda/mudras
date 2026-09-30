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

  mudras.aspects = {
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
    mudras = {
      nixos = {...}: {
        imports = [
          self.nixosModules.mudras
        ];
      };
      includes = [
        mudras.aspects.policies.to-host
      ];
    };
  };

  flake = {
    hmModules = rec {
      # default = mudras;
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
      # default = mudras;
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
                Type = "simple";
                # User = "root";
                # Group = "input";
                Environment = "PATH=/run/current-system/sw/bin";
                ExecStart = ''
                  ${package}/bin/mudras run ${verbosity}
                '';
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
