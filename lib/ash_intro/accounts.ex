defmodule AshIntro.Accounts do
  use Ash.Domain, otp_app: :ash_intro, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource AshIntro.Accounts.Token
    resource AshIntro.Accounts.User
  end
end
