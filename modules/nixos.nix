{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.programs.argonone;

  package = pkgs.callPackage ../package.nix {};
in {
  options = {
    programs.argonone = {
      enable = lib.mkEnableOption "Enable argonone service";

      package = {
        type = lib.types.package;
        default = package;
      };

      settings = {
        displayUnits = lib.mkOption {
          type = lib.types.enum ["celsius" "fahrenheit"];
          default = "celsius";
        };

        fanspeed = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              temperature = lib.mkOption {
                type = lib.types.ints.unsigned;
                description = "The temperature to activate this fan speed at";
              };

              speed = lib.mkOption {
                type = lib.types.ints.unsigned;
                description = "The speed the fans will be running at (as a percentage)";
              };
            };
          });

          default = [
            {
              temperature = 55;
              speed = 30;
            }
            {
              temperature = 60;
              speed = 55;
            }
            {
              temperature = 65;
              speed = 100;
            }
          ];
        };

        oled = {
          switchDuration = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 30;
          };

          screenList = lib.mkOption {
            type = lib.types.listOf (lib.types.enum ["clock" "cpu" "storage" "raid" "ram" "temp" "ip"]);
            default = ["clock" "cpu" "storage" "raid" "ram" "temp" "ip"];
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    environment.etc = {
      "argonunits.conf" = let
        mappings = {
          "celsius" = "C";
          "fahrenheit" = "F";
        };
      in {
        text = ''
          #
          # Argon Unit Configuration
          # Generated by NixOS
          #
          temperature=${mappings."${cfg.settings.displayUnits}"}
        '';
        mode = "0666";
      };

      "argononed.conf" = {
        text = ''
          #
          # Argon Fan Speed Configuration (CPU)
          # Generated by NixOS
          #
          ${lib.concatMapStringsSep "\n" ({
            speed,
            temperature,
          }: "${toString temperature}=${toString speed}")
          cfg.settings.fanspeed}
        '';
        mode = "0666";
      };

      "argoneonoled.conf" = {
        text = ''
          #
          # Argon OLED Configuration
          # Generated by NixOS
          #
          switchduration=${toString cfg.oled.switchDuration}
          screenlist="${lib.concatStringsSep " " cfg.oled.screenList}"
        '';
        mode = "0666";
      };

      "argoneonrtc.conf" = {
        text = ''
          #
          # Argon RTC Configuration
          # Generated by NixOS
          #
        '';
        mode = "0666";
      };
    };

    systemd.services.argonone = {
      description = "Argon One Fan and Button Service";
      after = ["multi-user.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RemainAfterExit = true;
        ExecStart = "${cfg.package}/bin/argon40 SERVICE";
      };
    };
  };
}
