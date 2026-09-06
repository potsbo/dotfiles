{ config, lib, palette, accentColor, ... }:

{
  programs.starship.settings = {
    format = lib.concatStrings [
      "[ ](bg:accent)"
      "$os"
      "[ ](bg:accent)"
      "\${custom.git_worktree}"
      "\${custom.git_repo_name}"
      "([](fg:accent bg:green)"
      "$git_branch"
      "$git_status"
      "[](bg:red fg:green))"
      "\${custom.directory}"
      "([](fg:accent bg:red)\${custom.directory_no_git})"
      "[ ](fg:red)"
      "$cmd_duration"
      "$line_break"
      "$jobs"
      "$character"
    ];

    right_format = "[](fg:accent)$time";

    palette = "monokai";

    os = {
      disabled = false;
      style = "bg:accent fg:black";
    };

    os.symbols = {
      Ubuntu = "󰕈";
      Macos = "󰀵";
      NixOS = "";
    };

    custom.git_worktree = {
      command = "echo '\\uef81'";
      when = "git rev-parse --git-dir 2>/dev/null | grep -q worktrees";
      format = "[$output ]($style)";
      style = "bg:accent fg:black";
    };

    custom.git_repo_name = {
      style = "bg:accent fg:black";
      command = "git remote get-url origin 2>/dev/null | sed -E 's#.*/([^/]+)(\\.git)?$#\\1#' | sed 's#\\.git$##'";
      when = "git rev-parse --is-inside-work-tree 2>/dev/null";
      format = "[$output ]($style)";
    };

    custom.directory = {
      style = "bold bg:red fg:white";
      command = "git rev-parse --show-prefix 2>/dev/null | sed 's#/$##'";
      when = "git rev-parse --is-inside-work-tree 2>/dev/null";
      format = "[ /$output ]($style)";
    };

    custom.directory_no_git = {
      style = "bold bg:red fg:white";
      command = ''pwd | sed "s#^$HOME#~#"'';
      when = "! git rev-parse --is-inside-work-tree 2>/dev/null";
      format = "[ $output ]($style)";
    };

    git_branch = {
      symbol = "";
      style = "bg:green";
      format = "[[ $symbol $branch ](fg:black bg:green)]($style)";
    };

    git_status = {
      style = "bg:green";
      format = "[[($all_status$ahead_behind )](fg:black bg:green)]($style)";
    };

    time = {
      disabled = false;
      time_format = "%R";
      style = "bg:accent";
      format = "[[  $time ](fg:black bg:accent)]($style)";
    };

    jobs = {
      symbol = "+";
      number_threshold = 2;
      symbol_threshold = 1;
      style = "fg:accent";
    };

    cmd_duration = {
      show_milliseconds = true;
      format = " in $duration ";
      style = "bg:accent";
      disabled = false;
    };

    # 役割名 → パレット。accent はホストごとの色 (flake.nix の hosts)。
    palettes.monokai = {
      inherit (palette) black white red green;
      accent = accentColor;
    };
  };
}
