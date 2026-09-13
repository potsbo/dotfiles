# aqua の設定 (aqua.yaml / aqua-policy.yaml / registry.yaml / aqua-checksums.json) を
# store にコピーし、実行時はそちらを読ませる。
#
# dotfiles.nix の原則 (作業ツリーを直接指す) から外す唯一の設定。理由は失敗の仕方:
# aqua の shim は起動のたびに global config を読むので、rebase / merge の conflict
# marker が aqua.yaml に入った瞬間、aqua 管理のコマンドが全部落ちる。nvim も gh も
# lazygit も difftastic も aqua 管理なので、conflict を解く道具が同時に死ぬ。
# store 越しなら、次に rebuild するまで動いている設定は変わらない。
# 「編集してもすぐには効かない」のはここでは欠点ではなく、狙っている性質。
#
# 4 ファイルはセットで 1 ディレクトリごと張る。aqua-policy.yaml の `path: registry.yaml`
# が相対参照で、checksum (require_checksum: true) も config の隣から読まれるため。
#
# 編集するのは repo 側 (home/.config/aquaproj-aqua/) のまま。Renovate と CI
# (.github/workflows の AQUA_CONFIG) と `aqua update-checksum` はそちらを見る。
# store 側は読み取り専用なので、config に書く aqua のサブコマンド (update-checksum,
# g -i) を環境変数任せに打つと失敗する。--config か AQUA_CONFIG で repo 側を明示する。
{ lib, config, ... }:

{
  options.aqua = {
    configDir = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "実行時に aqua が読む設定ディレクトリ (store のコピーへの symlink)。";
    };
    exec = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        activation script から aqua を呼ぶためのコマンド接頭辞。
        activation の PATH に aqua は無く (system 側から呼ばれる)、AQUA_* も
        入っていないので、実体と設定をどちらも明示する必要がある。
      '';
    };
  };

  config = {
    # store path を AQUA_POLICY_CONFIG に直接入れない: allow は絶対パスをキーに
    # 記録される (~/.local/share/aquaproj-aqua/policies/<abs path>/) ので、rebuild の
    # たびにパスが変わると毎回 `aqua policy allow` を打ち直すことになる。~ 側に
    # 固定パスを一枚挟む。
    #
    # ~/.config ではないのは、~/.config が丸ごとこのリポジトリへの symlink だから。
    # そこに置くと生成物がリポジトリのツリーに落ちて gitignore が要る。~/.local は
    # .local/bin しかリンクしていないので、この下なら何も落ちない。
    aqua.configDir = "${config.home.homeDirectory}/.local/share/aqua-config";

    aqua.exec = lib.escapeShellArgs [
      "env"
      "AQUA_GLOBAL_CONFIG=${config.aqua.configDir}/aqua.yaml"
      "AQUA_POLICY_CONFIG=${config.aqua.configDir}/aqua-policy.yaml"
      "${config.home.profileDirectory}/bin/aqua"
    ];

    home = {
      file.".local/share/aqua-config".source = ../../home/.config/aquaproj-aqua;

      # aqua は lazy install なので、aqua.yaml に足しただけでは shim (~/.local/share/
      # aquaproj-aqua/bin/*) が無く、コマンドが PATH に出てこない。-l で shim だけ張る
      # (本体は初回実行時に落ちる)。-a が要るのは、aqua i が既定でカレントディレクトリ側の
      # aqua.yaml しか見ず、ここの設定は global config だから。
      # .zshrc の precmd も同じことをするので、これが無くても次のプロンプトでは揃う。
      # ここでやるのは switch した直後のそのシェルで使えるようにするため。
      #
      # installPackages の後なのは aqua 自身が入っているのを待つため。設定 (上の
      # home.file) は linkGeneration で張られるので、この時点で既にある。
      #
      # 失敗しても activation は落とさない: registry の取得にネットが要り、圏外や GitHub の
      # rate limit で失敗しうる。module mode では boot 時の home-manager-<user>.service でも
      # 走るので、落とすと起動が degraded になる。
      activation.linkAquaShims = lib.hm.dag.entryAfter [ "installPackages" ] ''
        run ${config.aqua.exec} install --only-link --all || \
          warnEcho "aqua i -l -a に失敗した (ネットワーク?)"
      '';
    };
  };
}
