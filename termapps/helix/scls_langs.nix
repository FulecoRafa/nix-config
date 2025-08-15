# WARN
# THIS IS HERE FOR FUTURE USE IF NEEDED
# AS OF NOW, HELIX DOES NOT HAVE GOOD CONFIGURATION FOR ADDING A LSP
# TO MULTIPLE LANGUAGES, WITHOUT DECLARING ALL OF THEM AGAIN
{ ... }:

let scls-langs = [
    "rust"
    "c"
    "cpp"
    "go"
    "gomod"
    "gotmpl"
    "gowork"
    "python"
    "toml"
    "fish"
    "json"
    "jsonc"
    "json5"
    "javascript"
    "jsx"
    "typescript"
    "tsx"
    "css"
    "html"
    "nix"
    "bash"
    "lua"
    "yaml"
    "haskel"
    "zig"
    "cmake"
    "make"
    "glsl"
    "markdown"
    "dart"
    "dockerfile"
    "docker-compose"
    "git-commit"
    "git-rebase"
    "git-config"
    "git-attribute"
    "git-ignore"
    "kotlin"
    "swift"
    "hcl"
    "sql"
    "gdscript"
    "godot-resource"
    "nu"
    "env"
    "ini"
    "just"
    "typst"
    "hyprlang"
    "text"
]; in {
  programs.helix.languages.language = map (lang: {
    name = lang;
    language-id = lang;
    scope = "source.${lang}";
    language-servers = [ "scls" ];
  }) scls-langs;
}
