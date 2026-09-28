{
  self,
  den,
  ...
}: {
  flake-file.inputs = {
    # den.url = "github:denful/den";
  };

  mudras.aspects = rec {
    default = mudras;
    mudras = {
      nixos = {...}: {
        imports = [
          self.nixosModules.mudras
        ];
      };
    };
    ## Add Users to admin groups.
    policies.to-host = {user, ...}: {
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
    includes = [
      mudras.policies.to-host
      (den.batteries.unfree [
        "via"
      ])
    ];
  };

  flake.nixosModules = rec {
    default = mudras;
    "mudras" = {
      lib,
      config,
      inputs,
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
      };

      config = with lib; let
        inherit (pkgs.stdenv.hostPlatform) system;
        package = self.packages.${system}.default;
      in
        mkIf config.services."mudras".enable {
          ## Working dir
          systemd.tmpfiles.rules = lib.mkDefault [
            "d '/var/lib/udev' 2774 root input - -"
            "Z '/var/lib/udev' 2774 root input - -"

            # Mudras/Swhkd
            # No longer need to be root.
            # Members of the **input** group can interact with keyboard.
            "z /dev/input 0775 root input - -"
            "z /dev/uinput 0660 root input - -"
          ];

          systemd.services.mudras = {
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
              User = "root";
              Group = "users";
              Environment = "PATH=/run/current-system/sw/bin";
              ExecStart = ''
                ${package}/bin/mudras run ${verbosity}
              '';
              WorkingDirectory = "/var/lib/mudras";
              # StandardInput = "null";
              StandardOutput = "journal+console";
              StandardError = "journal+console";

              AmbientCapabilities = [];
            };
          };

          # Prepend some configuration to configuration file
          environment.etc = {
            "mudras/config.yml".text = mkMerge [
              (mkBefore (inputs.nix-std.lib.serde.toTOML {
                  }))
              (config.services."mudras".extraConfig)
            ];
          };

          environment.systemPackages = [
            package
            ## Keyboard utils
            wev
          ];
        };
    };
  };
}
