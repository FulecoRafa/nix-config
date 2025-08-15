{pkgs, lib, ...}:

{
  # This is needed so notifications work on macos.
  home.packages = lib.optional (pkgs.system == "aarch64-darwin") pkgs.terminal-notifier;
  
  programs.fish = {
    plugins = [{
      name = "fish-done";
      src = pkgs.fetchFromGitHub {
        owner = "franciscolourenco";
        repo = "done";
        rev = "0bfe402753681f705a482694fcaf20c2bfc6deb7";
        hash = "sha256-WA6DBrPBuXRIloO05UBunTJ9N01d6tO1K1uqojjO0mo=";
      };
    }];
  };
}
