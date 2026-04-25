{self, ...}: {
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
      options.services."virshle" = with lib; {
        enable = mkEnableOption "Enable virshle.";
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
          # systemd.tmpfiles.rules = lib.mkDefault [
          #   "d '/var/lib/udev' 2774 ${cfg.user} users - -"
          #   "Z '/var/lib/udev' 2774 ${cfg.user} users - -"
          # ];

          systemd.services.mudras = {
            enable = true;
            description = "Mudras - Shinobi hotkey daemon";
            documentation = [
              # "https://github.com/crocuda/mudras"
            ];
            after = [
              "socket.target"
            ];
            # wantedBy = ["multi-user.target"];
            serviceConfig = {
              Type = "simple";
              User = "root";
              Group = "users";
              Environment = "PATH=/run/current-system/sw/bin";
              ExecStart = ''
                ${package}/bin/mudras tui serve -vvv
              '';
              WorkingDirectory = "/var/lib/crotui";
              # StandardInput = "null";
              StandardOutput = "journal+console";
              StandardError = "journal+console";

              AmbientCapabilities = [
                "CAP_NET_BIND_SERVICE"
                # "CAP_SET_PROC"
                # "CAP_SYS_ADMIN"
                # "CAP_NET_ADMIN"
              ];
            };
          };

          # Prepend tui configuration to configuration file
          environment.etc = {
            "crotui/config.toml".text = mkMerge [
              (mkBefore (inputs.nix-std.lib.serde.toTOML {
                tui = {
                  address = cfg.address;
                  port = cfg.port;
                };
              }))
              (cfg.extraConfig)
            ];
          };

          environment.systemPackages = [
            # Network manager
            package
          ];
        };
    };
  };
}
