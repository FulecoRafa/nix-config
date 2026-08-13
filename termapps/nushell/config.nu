# Completa comandos externos usando a coleção ampla de completions do Fish.
let fish_completer = {|spans: list<string>|
    let cmd = ($spans | str join ' ')
    ^fish --command $"complete --do-complete=\"($cmd | str replace --all '"' '\\"')\"" e>| complete
    | lines
    | each {|line|
        let parts = ($line | split row "\t")
        {
            value: ($parts | first | str trim)
            description: (if ($parts | length) > 1 {
                $parts | skip 1 | str join "\t" | str trim
            } else { '' })
        }
    }
    | where ($it.value | is-not-empty)
}

$env.config = {
    show_banner: false
    edit_mode: vi
    cursor_shape: {
        vi_insert: line
        vi_normal: block
    }
    history: {
        max_size: 100_000
        sync_on_enter: true
        file_format: sqlite
        isolation: false
    }
    completions: {
        algorithm: fuzzy
        case_sensitive: false
        quick: true
        partial: true
        external: {
            enable: true
            max_results: 100
            completer: $fish_completer
        }
    }

    # Ayu Mirage.
    color_config: {
        separator: { fg: '#707A8C' }
        header: { fg: '#39BAE6' attr: 'b' }
        empty: { fg: '#707A8C' }
        bool: { fg: '#E6B450' }
        int: { fg: '#CBCCC6' }
        filesize: { fg: '#59C2FF' }
        duration: { fg: '#59C2FF' }
        date: { fg: '#BAE67E' }
        float: { fg: '#CBCCC6' }
        string: { fg: '#BAE67E' }
        nothing: { fg: '#707A8C' }
        binary: { fg: '#707A8C' }
        cell_path: { fg: '#39BAE6' }
        row_index: { fg: '#39BAE6' attr: 'b' }
        hints: { fg: '#5C6773' }
        search_result: { fg: '#F07178' bg: '#E6B450' }
        shape_and: { fg: '#F07178' attr: 'b' }
        shape_block: { fg: '#39BAE6' attr: 'b' }
        shape_bool: { fg: '#E6B450' }
        shape_closure: { fg: '#95E6CB' attr: 'b' }
        shape_custom: { fg: '#BAE67E' }
        shape_datetime: { fg: '#95E6CB' attr: 'b' }
        shape_directory: { fg: '#59C2FF' }
        shape_external: { fg: '#39BAE6' }
        shape_external_resolved: { fg: '#39BAE6' attr: 'b' }
        shape_externalarg: { fg: '#BAE67E' }
        shape_filepath: { fg: '#59C2FF' }
        shape_flag: { fg: '#E6B450' attr: 'b' }
        shape_float: { fg: '#CBCCC6' }
        shape_garbage: { fg: '#FFFFFF' bg: '#F07178' attr: 'b' }
        shape_globpattern: { fg: '#95E6CB' attr: 'b' }
        shape_int: { fg: '#CBCCC6' attr: 'b' }
        shape_internalcall: { fg: '#39BAE6' attr: 'b' }
        shape_keyword: { fg: '#F07178' attr: 'b' }
        shape_list: { fg: '#CBCCC6' attr: 'b' }
        shape_literal: { fg: '#CBCCC6' }
        shape_match_pattern: { fg: '#BAE67E' }
        shape_nothing: { fg: '#707A8C' }
        shape_operator: { fg: '#E6B450' }
        shape_or: { fg: '#F07178' attr: 'b' }
        shape_pipe: { fg: '#F07178' attr: 'b' }
        shape_range: { fg: '#E6B450' attr: 'b' }
        shape_raw_string: { fg: '#BAE67E' attr: 'b' }
        shape_redirection: { fg: '#FFEE99' }
        shape_signature: { fg: '#BAE67E' attr: 'b' }
        shape_string: { fg: '#BAE67E' }
        shape_string_interpolation: { fg: '#95E6CB' attr: 'b' }
        shape_table: { fg: '#CBCCC6' attr: 'b' }
        shape_vardecl: { fg: '#F07178' attr: 'u' }
        shape_variable: { fg: '#F07178' }
    }

    ls: {
        use_ls_colors: true
        clickable_links: true
    }
    table: {
        mode: rounded
        index_mode: always
        show_empty: true
        padding: { left: 1 right: 1 }
        trim: {
            methodology: wrapping
            wrapping_try_keep_words: true
            truncating_suffix: '...'
        }
        header_on_separator: false
    }
    error_style: fancy
    footer_mode: 25
    float_precision: 2
    use_ansi_coloring: true
    bracketed_paste: true
    shell_integration: {
        osc2: true
        osc7: true
        osc8: true
        osc9_9: false
        osc133: true
        osc633: true
        reset_application_mode: true
    }
}

alias ll = eza --icons -l
alias la = eza --icons -la
alias ls = eza --icons

def --env dev [] {
    cd ~/Documents/Dev
}
