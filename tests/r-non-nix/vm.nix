{
  pkgs,
  project,
  rVersion,
}:
pkgs.testers.runNixOSTest {
  name = "r-without-nix";
  nodes.machine = {
    virtualisation = {
      docker.enable = true;
      memorySize = 4096;
      diskSize = 12000;
      cores = 2;
    };
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("docker.service")
    machine.succeed("mkdir -p /tmp/r-test/project /tmp/r-test/image")
    machine.succeed("cp -R ${project}/. /tmp/r-test/project")
    machine.succeed("cp ${./Dockerfile} /tmp/r-test/image/Dockerfile")
    machine.succeed("cp ${./run.sh} /tmp/r-test/run.sh")
    machine.succeed(
        "docker build --progress=plain --build-arg R_VERSION=${rVersion} "
        "-t nullkomma-r-non-nix /tmp/r-test/image",
        timeout=1200,
    )
    machine.succeed(
        "docker run --rm "
        "--mount type=bind,src=/tmp/r-test/project,dst=/fixture,readonly "
        "--mount type=bind,src=/tmp/r-test/run.sh,dst=/test.sh,readonly "
        "nullkomma-r-non-nix bash /test.sh",
        timeout=1200,
    )
  '';
}
