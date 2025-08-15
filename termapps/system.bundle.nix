
{pkgs, ...}:

# CLI apps for managing the system.
# Set these here to extend user packages.
{
  users.users.fuleco.packages = with pkgs; [
      btop  # resource monitor
      viddy # watch
      ddh   # duplicate file finder
      dust  # disk usage (du)
      git 
  ];
}
