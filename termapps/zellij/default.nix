{ pkgs, ...}:

{
  users.users.fuleco.packages = with pkgs; [
    zellij
  ];
}
