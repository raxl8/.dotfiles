{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    gawk
  ];

  programs.password-store = {
    enable = true;
    settings.PASSWORD_STORE_DIR = "${config.home.homeDirectory}/.password-store";
  };

  home.activation = {
    password-store-init =
      let
        gpg = "${pkgs.gnupg}/bin/gpg";
        awk = "${pkgs.gawk}/bin/awk";
        pass = "${pkgs.pass}/bin/pass";

        block = ''
          export KEY_TYPE="rsa4096"
          export IDENTITY="aws-vault"
          run ${gpg} --batch --passphrase-fd 0 --quick-generate-key "$IDENTITY" "$KEY_TYPE" default never || exit 0
          export KEY_ID=$(run ${gpg} -k --with-colons "$IDENTITY" | ${awk} -F: '/^pub:/ { print $5; exit }')
          export KEY_FP=$(run ${gpg} -k --with-colons "$IDENTITY" | ${awk} -F: '/^fpr:/ { print $10; exit }')
          run ${gpg} --batch --pinentry-mode=loopback --passphrase-fd 0 \
            --quick-add-key "$KEY_FP" "$KEY_TYPE" encrypt never
          export PASSWORD_STORE_DIR="${config.programs.password-store.settings.PASSWORD_STORE_DIR}"
          run ${pass} init "$KEY_FP"
        '';
      in
      lib.hm.dag.entryAfter [ "linkGeneration" ] block;
  };

  home.sessionVariables = {
    AWS_VAULT_BACKEND = "pass";
  };
}
