{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hercules-ci-agent;
  user = config.users.users.hercules-ci-agent;
  binaryCachesPathDeployed = cfg.secretsDirectory + "/binary-caches.json";
in {
  imports = [ ./common.nix ];

  options.services.hercules-ci-agent = {
    logFile = mkOption {
      type = types.path;
      default = "/var/log/hercules-ci-agent.log";
      description = "Stdout and sterr of hercules-ci-agent process.";
    };
  };

  config = mkIf cfg.enable {
    launchd.daemons.hercules-ci-agent = {
      script = "exec ${cfg.package}/bin/hercules-ci-agent --config ${cfg.tomlFile}";

      path = [ config.nix.package ];
      environment = {
        NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      };

      serviceConfig.KeepAlive = true;
      serviceConfig.RunAtLoad = true;
      serviceConfig.StandardErrorPath = cfg.logFile;
      serviceConfig.StandardOutPath = cfg.logFile;
      serviceConfig.GroupName = "hercules-ci-agent";
      serviceConfig.UserName = "hercules-ci-agent";
      serviceConfig.WorkingDirectory = user.home;
      serviceConfig.WatchPaths = [
        cfg.secretsDirectory
      ];
    };

    system.activationScripts.preActivation.text = ''
      touch '${cfg.logFile}'
      chown ${toString user.uid}:${toString user.gid} '${cfg.logFile}'

      echo "installing /etc/nix/daemon-netrc"
      if [ -f ${escapeShellArg binaryCachesPathDeployed} ]; then
        ${pkgs.jq}/bin/jq -r <${escapeShellArg binaryCachesPathDeployed} \
            'to_entries[] | .key as $key | .value.authToken | select (. != null) | "machine \($key).cachix.org password \(.)" ' \
            > /etc/nix/daemon-netrc
        chmod 400 /etc/nix/daemon-netrc
        chown root /etc/nix/daemon-netrc
      fi
    '';

    users.knownGroups = [ "hercules-ci-agent" ];
    users.knownUsers = [ "hercules-ci-agent" ];

    users.users.hercules-ci-agent = {
      uid = mkDefault 532;
      gid = mkDefault config.users.groups.hercules-ci-agent.gid;
      home = mkDefault cfg.baseDirectory;
      createHome = true;
      shell = "/bin/bash";
      description = "System user for the Hercules CI Agent";
    };
    users.groups.hercules-ci-agent = {
      gid = mkDefault 532;
      description = "System group for the Hercules CI Agent";
    };
  };
}
