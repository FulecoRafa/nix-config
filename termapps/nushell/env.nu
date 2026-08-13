# Ambiente portátil, baseado na configuração usada no macOS.
$env.EDITOR = 'hx'
$env.VIRTUAL_ENV_DISABLE_PROMPT = 'true'
$env.NU_HOSTNAME = (^hostname | str trim | split row '.' | first)

# Acrescenta apenas diretórios que existem na máquina atual.
let user_paths = [
    ($env.HOME | path join '.nix-profile' 'bin')
    ($env.HOME | path join '.swiftly' 'bin')
    ($env.HOME | path join '.cargo' 'bin')
    ($env.HOME | path join '.local' 'bin')
    ($env.HOME | path join '.ghcup' 'bin')
    ($env.HOME | path join '.pyenv' 'bin')
]
$env.PATH = ($env.PATH | prepend ($user_paths | where {|path| $path | path exists }) | uniq)

# Prompt de duas linhas no estilo "nim" usado neste computador.
$env.PROMPT_COMMAND = {||
    let last_ok = ($env.LAST_EXIT_CODE == 0)
    let retc = if $last_ok { 'green' } else { 'red' }

    let user = (^whoami | str trim)
    let user_color = if ($user == 'root') { 'red_bold' } else { 'yellow_bold' }
    let host_color = if ('SSH_CLIENT' in $env) { 'cyan_bold' } else { 'blue_bold' }
    let short_path = if ($env.PWD | str starts-with $env.HOME) {
        '~' + ($env.PWD | str substring ($env.HOME | str length)..)
    } else {
        $env.PWD
    }
    let time = (date now | format date '%H:%M:%S')

    let git_part = (
        do { ^git branch --show-current } | complete
        | if ($in.exit_code == 0) {
            let branch = ($in.stdout | str trim)
            if ($branch | is-not-empty) {
                let dirty = (
                    do { ^git status --porcelain } | complete
                    | if ($in.exit_code == 0 and ($in.stdout | str trim | is-not-empty)) { '●' } else { '' }
                )
                $"(ansi reset)─(ansi green_bold)[(ansi reset)G:(ansi ($retc))($branch)($dirty)(ansi green_bold)]"
            } else { '' }
        } else { '' }
    )

    let venv_part = if ('VIRTUAL_ENV' in $env) {
        let name = ($env.VIRTUAL_ENV | path basename)
        $"(ansi reset)─(ansi green_bold)[(ansi reset)V:(ansi ($retc))($name)(ansi green_bold)]"
    } else { '' }

    $"(ansi ($retc))┬─(ansi green_bold)[(ansi ($user_color))($user)(ansi white_bold)@(ansi ($host_color))($env.NU_HOSTNAME)(ansi white_bold):($short_path)(ansi green_bold)](ansi reset)─(ansi green_bold)[(ansi reset)($time)(ansi green_bold)]($venv_part)($git_part)\n(ansi ($retc))╰─>(ansi red_bold)$ (ansi reset)"
}

$env.PROMPT_INDICATOR = {|| '' }
$env.PROMPT_COMMAND_RIGHT = {|| '' }
$env.PROMPT_MULTILINE_INDICATOR = {|| '::: ' }
$env.PROMPT_INDICATOR_VI_INSERT = {|| $"(ansi green_bold)[I] (ansi reset)" }
$env.PROMPT_INDICATOR_VI_NORMAL = {|| $"(ansi red_bold)[N] (ansi reset)" }
