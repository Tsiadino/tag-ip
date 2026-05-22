defmodule TagIp.Accounts do
  use Ash.Domain,
    otp_app: :tag_ip,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(TagIp.Accounts.User)
    resource(TagIp.Accounts.Token)
  end
end
