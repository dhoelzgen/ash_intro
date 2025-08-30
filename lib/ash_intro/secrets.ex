defmodule AshIntro.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        AshIntro.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:ash_intro, :token_signing_secret)
  end
end
