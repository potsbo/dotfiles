{ config, ... }:

let
  registryPort = 5000;
  hostname = config.networking.hostName;
in
{
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      insecure-registries = [ "${hostname}:${toString registryPort}" ];
      features.containerd-snapshotter = true;
    };
  };

  # BuildKit config for OCI buildx builder (zstd compression + insecure registry)
  environment.etc."buildkitd/oci-builder.toml".text = ''
    [worker.oci]
      gc = true
      compression = "zstd"
      force-compression = true

    [registry."${hostname}:${toString registryPort}"]
      http = true
      insecure = true
  '';

  # Buildx builder with docker-container driver for OCI output
  systemd.services.docker-buildx-oci = {
    description = "Setup Docker Buildx OCI builder";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.virtualisation.docker.package ];
    environment.HOME = "/home/potsbo";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "potsbo";
      SupplementaryGroups = [ "docker" ];
    };
    script = ''
      docker buildx rm oci-builder 2>/dev/null || true
      docker buildx create \
        --name oci-builder \
        --driver docker-container \
        --config /etc/buildkitd/oci-builder.toml \
        --bootstrap
    '';
  };

  # Default to OCI buildx builder
  environment.sessionVariables.BUILDX_BUILDER = "oci-builder";

  # Docker Registry（Tailscale 経由のみアクセス可）
  # tailscale0 が trustedInterfaces にあり、port が allowedTCPPorts にないことで制限される
  services.dockerRegistry = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = registryPort;
  };

  assertions = [
    {
      assertion = builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces;
      message = "Docker Registry は tailscale0 が trustedInterfaces にある前提で Tailscale 限定にしている";
    }
    {
      assertion = !(builtins.elem registryPort config.networking.firewall.allowedTCPPorts);
      message = "Docker Registry の port 5000 を allowedTCPPorts に追加すると全インターフェースに公開されてしまう";
    }
  ];
}
